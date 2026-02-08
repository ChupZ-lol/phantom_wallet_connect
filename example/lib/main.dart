import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:phantom_wallet_connect/phantom_wallet_connect.dart';
import 'package:solana/base58.dart';
import 'package:web/web.dart' as web;

import 'server.dart';

final _manager = PhantomWalletManager();
final _storage = SecurePhantomStorage();
final _server = Server();

String _status = 'Ready';

void main() {
  runApp(
    const MaterialApp(debugShowCheckedModeBanner: false, home: WalletScreen()),
  );
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? _address;
  bool _loading = false;

  static const String _timestampKey = 'login_timestamp';

  @override
  void initState() {
    super.initState();
    _initWallet();
  }

  Future<void> _initWallet() async {
    await _manager.initialize(
      appUrl: "https://my-app.com",
      appId: "my_app_id",
      storage: _storage,
      cluster: Cluster.devnet,
    );

    final restoreConnect = await _manager.adapter.connect(silent: true);

    if (restoreConnect != null) {
      setState(() {
        _address = restoreConnect;
      });
    }

    // For Mobile: Check if we have returned the link.
    // Desktop Adapter will just return null, so it's always safe to call.
    final uri = Uri.base;
    final data = await _manager.adapter.handleDeepLink(uri);

    if (data != null) {
      // Scenario 1: Connection.
      if (data.containsKey('public_key')) {
        setState(() => _address = data['public_key']);

        await _sign();
      }

      // Scenario 2: Signature.
      if (data.containsKey('signature')) {
        String signature = data['signature'];

        final timestampStr = await _storage.read(_timestampKey);

        if (timestampStr != null) {
          final timestamp = int.parse(timestampStr);

          // Send to the server for verification.
          final isVerify = await _server.verifySign(
            _address!,
            signature,
            timestamp,
          );

          await _storage.delete(_timestampKey);

          setState(() => _status = 'Sign Ok!: $isVerify');
        }
      }

      // Scenario 3: Signed transaction.
      if (data.containsKey('transaction')) {
        String signedTxBase58 = data['transaction'];

        setState(() => _status = 'Transaction received: $signedTxBase58');

        try {
          final txBytes = base58decode(signedTxBase58);
          final txBase64 = base64Encode(txBytes);

          // You send a transaction to the server
          final signature = await _server.sendTx(txBase64);

          setState(() => _status = 'Transaction sent! Sign: $signature');
        } catch (e) {
          setState(() => _status = 'Error sending transaction: $e');
        }
      }

      // Scenario 4: List of signed transactions.
      if (data.containsKey('transactions')) {
        List<dynamic> rawList = data['transactions'];
        List<String> base58List = rawList.cast<String>();

        List<String> base64List = base58List.map((txBase58) {
          final bytes = base58decode(txBase58);
          return base64Encode(bytes);
        }).toList();

        // Send to the server for processing.
        final signature = await _server.sendMultipleTxs(base64List);

        setState(
          () => _status = 'Multiple transactions sent! Sign: $signature',
        );
      }
    }
    try {
      _clearUrlParams();
    } catch (_) {}
  }

  void _clearUrlParams() {
    web.window.history.replaceState(null, '', web.window.location.pathname);
  }

  Future<void> _connect() async {
    setState(() => _loading = true);

    final result = await _manager.adapter.connect();

    if (result != null) {
      setState(() {
        _address = result;
      });

      await _sign();
      setState(() => _loading = false);
    }
  }

  Future<void> _sign() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    await _storage.write(_timestampKey, timestamp.toString());

    final message = "Sign in to MyApp: $timestamp";
    final signatureBytes = await _manager.adapter.signMessage(message);

    if (signatureBytes != null) {
      final signatureBase58 = base58encode(signatureBytes);

      final isVerify = await _server.verifySign(
        _address!,
        signatureBase58,
        timestamp,
      );

      await _storage.delete(_timestampKey);

      setState(() => _status = 'Sign Ok!: $isVerify');
    }
  }

  Future<void> _disconnect() async {
    await _manager.adapter.disconnect();

    await _storage.delete(_timestampKey);
    if (mounted) {
      setState(() {
        _address = null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InputForm(),
            const SizedBox(height: 30),
            Text(
              _status,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 10),
            // 1. Default(Purple, square, white logo)
            PhantomConnectButton(
              walletAddress: _address,
              isLoading: _loading,
              onConnect: _connect,
              onDisconnect: _disconnect,
            ),

            const SizedBox(height: 20),

            // 2. Custom (Blue, rounded, black logo)
            PhantomConnectButton(
              walletAddress: _address,
              isLoading: _loading,
              onConnect: _connect,
              onDisconnect: _disconnect,
              backgroundColor: Colors.blue,
              foregroundColor: Colors.black,
              logoColor: PhantomLogoColor.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),

            const SizedBox(height: 20),

            // 3. Custom (Black, rounded, purple logo)
            PhantomConnectButton(
              walletAddress: _address,
              isLoading: _loading,
              onConnect: _connect,
              onDisconnect: _disconnect,
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              logoColor: PhantomLogoColor.purple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InputForm extends StatefulWidget {
  const InputForm({super.key});

  @override
  InputFormState createState() => InputFormState();
}

class InputFormState extends State<InputForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _walletController = TextEditingController();

  bool _isMultipleMode = false;
  bool _loading = false;
  double _batchCount = 2;

  Future<void> _submitForm(
    String userPublicKey,
    double amount,
    String toWallet,
  ) async {
    setState(() {
      _loading = true;
      _status = "Creating transaction...";
    });

    try {
      // Create a transaction on the server
      final txBase64 = await _server.createUnsignedTx(
        userPublicKey,
        amount,
        toWallet,
      );
      final txBytes = base64Decode(txBase64);

      print("Client: Bytes decoded. Length: ${txBytes.length}");

      print("Client: Calling adapter.signTransaction...");

      // If Desktop: returns the bytes immediately.
      // If Mobile: will return null and open the application.
      Uint8List? signedBytes = await _manager.adapter.signTransaction(txBytes);

      print("Client: Adapter returned result. Is null? ${signedBytes == null}");

      if (signedBytes != null) {
        setState(() => _status = "Sending Solana...");

        final signedBase64 = base64Encode(signedBytes);
        final signature = await _server.sendTx(signedBase64);

        setState(() {
          _status = 'Transaction sent! Sign: $signature';
          _loading = false;
        });
      } else {
        setState(() => _status = "Redirecting to Phantom...");
      }
    } catch (e) {
      _status = 'Error _submitForm: $e';
      print("Error _submitForm: $e");
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _submitMultipleForm(
    String userPublicKey,
    double baseAmount,
    String baseRecipient,
    int count,
  ) async {
    setState(() {
      _loading = true;
      _status = "Creating $count transactions...";
    });

    try {
      List<String> recipients = [];
      List<double> amounts = [];

      // It's just a simulation. Different amounts will be sent to one address.
      for (int i = 0; i < count; i++) {
        recipients.add(baseRecipient);
        double amount = baseAmount + (i * 0.00001);
        amounts.add(amount);
      }

      // Create a Multiple transaction on the server
      final txsBase64 = await _server.createMultipleUnsignedTxs(
        userPublicKey,
        recipients,
        amounts,
      );

      final List<List<int>> txsBytes = txsBase64
          .map((tx) => base64Decode(tx))
          .toList();

      final List<Uint8List>? signedTxsBytes = await _manager.adapter
          .signAllTransactions(txsBytes);

      if (signedTxsBytes != null) {
        setState(() => _status = "Sending Multiple Solana...");

        final List<String> signedBase64List = signedTxsBytes
            .map((bytes) => base64Encode(bytes))
            .toList();

        final signatures = await _server.sendMultipleTxs(signedBase64List);

        setState(() {
          _status = 'Multiple transactions sent! Sign: $signatures';
          _loading = false;
        });
      } else {
        setState(() => _status = "Redirecting to Phantom...");
      }
    } catch (e) {
      _status = 'Error _submitMultipleForm: $e';
      print("Error _submitMultipleForm: $e");
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 600,
      child: Form(
        key: _formKey,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount (SOL)'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) => value!.isEmpty ? 'Enter amount' : null,
              ),
              TextFormField(
                controller: _walletController,
                decoration: const InputDecoration(
                  labelText: 'Recipient Address',
                ),
                validator: (value) => value!.isEmpty ? 'Enter address' : null,
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Switch(
                    value: _isMultipleMode,
                    onChanged: (val) => setState(() => _isMultipleMode = val),
                  ),
                  Text(
                    _isMultipleMode
                        ? "Send Multiple (${_batchCount.toInt()})"
                        : "Send Single",
                  ),
                ],
              ),

              if (_isMultipleMode)
                Slider(
                  value: _batchCount,
                  min: 2,
                  max: 5,
                  divisions: 3,
                  label: _batchCount.toInt().toString(),
                  onChanged: (val) => setState(() => _batchCount = val),
                ),

              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    if (_manager.adapter.publicKey == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Wallet not connected!")),
                      );
                      return;
                    }

                    double amount = double.parse(_amountController.text);
                    String toWallet = _walletController.text;
                    String userWallet = _manager.adapter.publicKey!;

                    if (_isMultipleMode) {
                      await _submitMultipleForm(
                        userWallet,
                        amount,
                        toWallet,
                        _batchCount.toInt(),
                      );
                    } else {
                      await _submitForm(userWallet, amount, toWallet);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMultipleMode
                      ? Colors.orange
                      : Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }

    return Text(
      _isMultipleMode
          ? 'Sign ${_batchCount.toInt()} Transactions'
          : 'Send Transaction',
    );
  }
}
