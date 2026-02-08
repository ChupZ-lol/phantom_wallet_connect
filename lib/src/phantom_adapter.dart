import 'dart:typed_data';

import 'package:phantom_wallet_connect/src/desktop_connect/phantom_desktop.dart';
import 'package:phantom_wallet_connect/src/mobile_connect/phantom_mobile.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class PhantomAdapter {
  // Initialization (loading keys for mobile, checking window for desktop)
  Future<void> init();

  // Connecting a wallet
  // Returns the wallet address if the connection was instantaneous (Desktop).
  // Returns null if a redirect occurred (Mobile).
  Future<String?> connect({bool silent = false});

  // Disconnect
  Future<void> disconnect();

  // Returns the signed bytes of the transaction (to be sent to the server).
  Future<Uint8List?> signTransaction(List<int> transaction);

  // Returns a list of signed transactions.
  Future<List<Uint8List>?> signAllTransactions(List<List<int>> transactions);

  // Returns signature bytes (Signature).
  Future<Uint8List?> signMessage(String message);

  // Processing incoming links (only needed for Mobile, Desktop will return null)
  Future<Map<String, dynamic>?> handleDeepLink(Uri uri);

  bool get isInstalled;
  String? get publicKey;
}

//===================================================================
//===================================================================
class PhantomAdapterDesktop implements PhantomAdapter {
  final _service = PhantomDesktop();
  String? _cachedPublicKey;

  @override
  bool get isInstalled => _service.isPhantomInstalled;

  @override
  String? get publicKey => _cachedPublicKey;

  @override
  Future<void> init() async {}

  @override
  Future<String?> connect({bool silent = false}) async {
    final address = await _service.connect(silent: silent);
    _cachedPublicKey = address;
    return address;
  }

  @override
  Future<void> disconnect() async {
    await _service.disconnect();
    _cachedPublicKey = null;
  }

  @override
  Future<Uint8List?> signTransaction(List<int> transactionBytes) async {
    return await _service.signTransaction(transactionBytes);
  }

  @override
  Future<List<Uint8List>?> signAllTransactions(
    List<List<int>> transactions,
  ) async {
    final input = transactions.map((e) => Uint8List.fromList(e)).toList();
    return await _service.signAllTransactions(input);
  }

  @override
  Future<Uint8List?> signMessage(String message) async {
    final messageBytes = Uint8List.fromList(message.codeUnits);
    final signature = await _service.signMessage(messageBytes);
    return signature;
  }

  @override
  Future<Map<String, dynamic>?> handleDeepLink(Uri uri) async {
    return null;
  }
}

//===================================================================
//===================================================================
class PhantomAdapterMobile implements PhantomAdapter {
  final PhantomMobile _service;
  final String redirectLink;
  String? _cachedPublicKey;

  PhantomAdapterMobile({
    required PhantomMobile service,
    required this.redirectLink,
  }) : _service = service;

  @override
  bool get isInstalled => true;

  @override
  String? get publicKey => _cachedPublicKey;

  @override
  Future<void> init() async {
    await _service.init();
  }

  @override
  Future<String?> connect({bool silent = false}) async {
    if (silent) return null;

    final uri = _service.generateConnectUri(redirectLink: redirectLink);
    await _launch(uri);
    return null;
  }

  @override
  Future<void> disconnect() async {
    final uri = _service.generateDisconnectUri(redirectLink: redirectLink);
    if (uri != null) await _launch(uri);
    _cachedPublicKey = null;
  }

  @override
  Future<Uint8List?> signTransaction(List<int> transactionBytes) async {
    final uri = _service.generateSignTransactionUri(
      transactionBytes: transactionBytes,
      redirectLink: redirectLink,
    );

    if (uri != null) await _launch(uri);
    return null;
  }

  @override
  Future<List<Uint8List>?> signAllTransactions(
    List<List<int>> transactions,
  ) async {
    final uri = _service.generateSignAllTransactionsUri(
      transactions: transactions,
      redirectLink: redirectLink,
    );
    if (uri != null) await _launch(uri);
    return null;
  }

  @override
  Future<Uint8List?> signMessage(String message) async {
    final uri = _service.generateSignMessageUri(
      message: message,
      redirectLink: redirectLink,
    );
    if (uri != null) await _launch(uri);
    return null;
  }

  @override
  Future<Map<String, dynamic>?> handleDeepLink(Uri uri) async {
    final data = await _service.handleIncomingUri(uri);

    if (data != null && data.containsKey('public_key')) {
      _cachedPublicKey = data['public_key'];
    }
    return data;
  }
}

Future<void> _launch(Uri uri) async {
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    throw Exception("Could not launch Phantom Wallet");
  }
}
