import 'dart:convert';

import 'package:phantom_wallet_connect/src/mobile_connect/mobile_connect.dart';
import 'package:pinenacl/x25519.dart';
import 'package:pinenacl/tweetnacl.dart';
import 'package:solana/base58.dart';

class PhantomMobile {
  final PhantomStorage storage;
  final String appUrl;
  final String? appId;
  final Cluster cluster;

  PrivateKey? _dAppSecretKey;
  PublicKey? _dAppPublicKey;
  PublicKey? _phantomPublicKey;
  String? _sessionToken;
  Box? _sharedSecretBox;

  static const String _scheme = "https";
  static const String _host = "phantom.app";

  PhantomMobile({
    required this.storage,
    required this.appUrl,
    this.appId,
    this.cluster = Cluster.mainnetBeta,
  });

  //===================================================================
  // Initialization. We restore keys and session or generate new ones.
  Future<void> init() async {
    final savedSecretKey = await storage.read('dAppSecretKey');
    if (savedSecretKey != null) {
      try {
        final keyBytes = base58decode(savedSecretKey);
        _dAppSecretKey = PrivateKey(Uint8List.fromList(keyBytes));
      } catch (e) {
        _generateNewKeys();
      }
    } else {
      _generateNewKeys();
    }
    _dAppPublicKey = _dAppSecretKey!.publicKey;

    final savedPhantomKey = await storage.read('phantomEncryptionPublicKey');
    final savedSession = await storage.read('sessionToken');

    if (savedPhantomKey != null && savedSession != null) {
      _phantomPublicKey = PublicKey(
        Uint8List.fromList(base58decode(savedPhantomKey)),
      );
      _sessionToken = savedSession;
      _createSharedSecretBox();
    }
  }

  //===================================================================
  // Generating new application keys and saving them in secure storage.
  void _generateNewKeys() {
    _dAppSecretKey = PrivateKey.generate();
    _dAppPublicKey = _dAppSecretKey!.publicKey;
    storage.write('dAppSecretKey', base58encode(_dAppSecretKey!.asTypedList));
  }

  //===================================================================
  // Creating a shared secret.
  void _createSharedSecretBox() {
    if (_dAppSecretKey != null && _phantomPublicKey != null) {
      _sharedSecretBox = Box(
        myPrivateKey: _dAppSecretKey!,
        theirPublicKey: _phantomPublicKey!,
      );
    }
  }

  //===================================================================
  // Generating links.
  //===================================================================

  //===================================================================
  // Generating a connection link.
  Uri generateConnectUri({required String redirectLink}) {
    if (_dAppPublicKey == null) _generateNewKeys();

    final params = {
      'dapp_encryption_public_key': base58encode(_dAppPublicKey!.asTypedList),
      'cluster': cluster.value,
      'app_url': appUrl,
      'redirect_link': redirectLink,
    };

    if (appId != null) {
      params['app_id'] = appId!;
    }

    return Uri(
      scheme: _scheme,
      host: _host,
      path: '/ul/v1/connect',
      queryParameters: params,
    );
  }

  //===================================================================
  // Generating a disconnection link.
  Uri? generateDisconnectUri({required String redirectLink}) {
    if (_sessionToken == null || _sharedSecretBox == null) return null;

    final payload = {'session': _sessionToken};
    final encrypted = _encryptPayload(payload);

    _clearSession();

    return Uri(
      scheme: _scheme,
      host: _host,
      path: '/ul/v1/disconnect',
      queryParameters: {
        'dapp_encryption_public_key': base58encode(_dAppPublicKey!.asTypedList),
        'nonce': base58encode(encrypted['nonce']!),
        'payload': base58encode(encrypted['payload']!),
        'redirect_link': redirectLink,
      },
    );
  }

  //===================================================================
  // Sign message
  // Accepts a string that you can create on the server side.
  Uri? generateSignMessageUri({
    required String message,
    required String redirectLink,
  }) {
    if (_sessionToken == null || _sharedSecretBox == null) return null;

    final messageBytes = Uint8List.fromList(utf8.encode(message));
    final payload = {
      'session': _sessionToken,
      'message': base58encode(messageBytes),
      'display': 'utf8',
    };

    final encrypted = _encryptPayload(payload);

    return Uri(
      scheme: _scheme,
      host: _host,
      path: '/ul/v1/signMessage',
      queryParameters: {
        'dapp_encryption_public_key': base58encode(_dAppPublicKey!.asTypedList),
        'nonce': base58encode(encrypted['nonce']!),
        'payload': base58encode(encrypted['payload']!),
        'redirect_link': redirectLink,
      },
    );
  }

  //===================================================================
  // Sign the transaction. Only the signature, your server must send it.
  Uri? generateSignTransactionUri({
    required List<int> transactionBytes,
    required String redirectLink,
  }) {
    if (_sessionToken == null || _sharedSecretBox == null) return null;

    final payload = {
      'session': _sessionToken,
      'transaction': base58encode(Uint8List.fromList(transactionBytes)),
    };

    final encrypted = _encryptPayload(payload);

    return Uri(
      scheme: _scheme,
      host: _host,
      path: '/ul/v1/signTransaction',
      queryParameters: {
        'dapp_encryption_public_key': base58encode(_dAppPublicKey!.asTypedList),
        'nonce': base58encode(encrypted['nonce']!),
        'payload': base58encode(encrypted['payload']!),
        'redirect_link': redirectLink,
      },
    );
  }

  //===================================================================
  // Mass signature. Only the signature, your server must send it.
  Uri? generateSignAllTransactionsUri({
    required List<List<int>> transactions,
    required String redirectLink,
  }) {
    if (_sessionToken == null || _sharedSecretBox == null) return null;

    final encodedTransactions = transactions.map((tx) {
      return base58encode(Uint8List.fromList(tx));
    }).toList();

    final payload = {
      'session': _sessionToken,
      'transactions': encodedTransactions,
    };

    final encrypted = _encryptPayload(payload);

    return Uri(
      scheme: _scheme,
      host: _host,
      path: '/ul/v1/signAllTransactions',
      queryParameters: {
        'dapp_encryption_public_key': base58encode(_dAppPublicKey!.asTypedList),
        'nonce': base58encode(encrypted['nonce']!),
        'payload': base58encode(encrypted['payload']!),
        'redirect_link': redirectLink,
      },
    );
  }

  //===================================================================
  // Processing responses.
  //===================================================================

  //===================================================================
  // Main method: parses the URL the user returned with.
  // Returns Map with data (for example public_key) or null if error.
  // If the response is the result of the Connect method, it will create and save a session.
  // If this was a transaction, decrypted will have the 'transaction' key.
  // If the message is 'signature'.
  Future<Map<String, dynamic>?> handleIncomingUri(Uri uri) async {
    final params = uri.queryParameters;

    // If there is an error, we return null.
    if (params.containsKey('errorCode')) {
      return null;
    }

    // If the response contains phantom_encryption_public_key, we process the connection.
    if (params.containsKey('phantom_encryption_public_key')) {
      final phantomKeyStr = params['phantom_encryption_public_key']!;

      final phantomKeyBytes = Uint8List.fromList(base58decode(phantomKeyStr));

      _phantomPublicKey = PublicKey(phantomKeyBytes);
      await storage.write('phantomEncryptionPublicKey', phantomKeyStr);

      _createSharedSecretBox();
    }

    // Decrypting the data (nonce + data)
    if (params.containsKey('nonce') && params.containsKey('data')) {
      final nonce = Uint8List.fromList(base58decode(params['nonce']!));
      final encryptedData = Uint8List.fromList(base58decode(params['data']!));

      final decrypted = _decryptPayload(encryptedData, nonce);
      if (decrypted == null) return null;

      // If this is CONNECT, save the session and user key.
      if (decrypted.containsKey('session')) {
        _sessionToken = decrypted['session'];
        await storage.write('sessionToken', _sessionToken!);
      }

      if (decrypted.containsKey('public_key')) {
        await storage.write('userPublicKey', decrypted['public_key']);
      }

      // RETURN DATA (Signature, Transaction or Session)
      return decrypted;
    }

    return null;
  }

  //===================================================================
  // Session clearing.
  Future<void> _clearSession() async {
    _sessionToken = null;
    _phantomPublicKey = null;
    _sharedSecretBox = null;
    await storage.delete('sessionToken');
    await storage.delete('phantomEncryptionPublicKey');
    await storage.delete('userPublicKey');
  }

  //===================================================================
  // PRIVATE CRYPTO HELPERS
  //===================================================================

  Map<String, Uint8List> _encryptPayload(Map<String, dynamic> jsonPayload) {
    if (_sharedSecretBox == null) {
      throw Exception("Shared secret not established");
    }

    final nonce = TweetNaCl.randombytes(24);
    final jsonStr = jsonEncode(jsonPayload);
    final messageBytes = Uint8List.fromList(utf8.encode(jsonStr));
    final encrypted = _sharedSecretBox!
        .encrypt(messageBytes, nonce: nonce)
        .cipherText;

    return {'nonce': nonce, 'payload': encrypted.asTypedList};
  }

  Map<String, dynamic>? _decryptPayload(
    Uint8List encryptedData,
    Uint8List nonce,
  ) {
    if (_sharedSecretBox == null) return null;

    try {
      final decryptedBytes = _sharedSecretBox!.decrypt(
        ByteList(encryptedData),
        nonce: nonce,
      );

      final jsonStr = utf8.decode(decryptedBytes);
      return jsonDecode(jsonStr);
    } catch (e) {
      return null;
    }
  }
}
