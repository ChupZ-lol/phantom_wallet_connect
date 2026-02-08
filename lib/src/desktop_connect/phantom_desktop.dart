import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

import 'package:phantom_wallet_connect/src/desktop_connect/desktop_connect.dart';

class PhantomDesktop {
  // Private getter for getting provider from window
  PhantomProvider? get _provider {
    final win = web.window as JSObject;
    final winExt = WindowExtension(win);
    return winExt.solana;
  }

  // Checking whether the user has the Phantom extension installed
  bool get isPhantomInstalled {
    return _provider?.isPhantom ?? false;
  }

  //===================================================================
  // Connect wallet
  // Returns the wallet address (String) or null if there was an error/cancellation.
  Future<String?> connect({bool silent = false}) async {
    final provider = _provider;

    if (provider == null || !provider.isPhantom) {
      if (silent) return null;

      // If the user does not have the Phantom extension installed, we redirect them.
      web.window.open('https://phantom.com/download', '_blank');
      return null;
    }

    try {
      final options = silent ? ConnectOptions(onlyIfTrusted: true) : null;
      // Call the JS method connect()
      final response = await provider.connect(options).toDart;

      // Return publicKey (JS object) and cast it to type toBase58 (JS method)
      final address = response.publicKey.toBase58();

      return address;
    } catch (e) {
      return null;
    }
  }

  //===================================================================
  // Disconnect wallet
  Future<void> disconnect() async {
    final provider = _provider;
    if (provider != null) {
      await provider.disconnect().toDart;
    }
  }

  //===================================================================
  // Sign message
  // Accepts a string that you can create on the server side.
  // Returns the signature in bytes (Uint8List), which can be sent to the server for confirmation
  // or null if there was an error/cancellation.
  Future<Uint8List?> signMessage(Uint8List messageBytes) async {
    final provider = _provider;
    if (provider == null) return null;

    try {
      final JSUint8Array jsMessage = messageBytes.toJS;
      final response = await provider.signMessage(jsMessage, 'utf8').toDart;
      final jsSignature = response.signature as JSUint8Array;

      return jsSignature.toDart;
    } catch (e) {
      return null;
    }
  }

  //===================================================================
  // Sign the transaction. Only the signature, your server must send it.
  // Returns the signed transaction as bytes [List<int>] or null if there was an error/cancellation.
  Future<Uint8List?> signTransaction(List<int> transactionBytes) async {
    final provider = _provider;
    if (provider == null || solanaWeb3 == null) return null;

    try {
      final jsData = Uint8List.fromList(transactionBytes).toJS;

      final VersionedMessage message = solanaWeb3!.versionedMessage.deserialize(
        jsData,
      );

      final constructor = solanaWeb3!.versionedTransaction as JSFunction;
      final JSObject txObjJs = constructor.callAsConstructor(message);
      final VersionedTransaction txObj = txObjJs as VersionedTransaction;

      final JSObject signedTxJs = await provider.signTransaction(txObj).toDart;
      final VersionedTransaction signedTx = signedTxJs as VersionedTransaction;
      final JSUint8Array signedBytesJs = signedTx.serialize();

      return signedBytesJs.toDart;
    } catch (e) {
      return null;
    }
  }

  //===================================================================
  // Sign and send one transaction.
  // Returns String signature or null if there was an error/cancellation.
  Future<String?> signAndSendTransaction(List<int> transactionBytes) async {
    final provider = _provider;
    if (provider == null || solanaWeb3 == null) {
      throw Exception('Provider not found or Web3 script missing');
    }

    try {
      final jsData = Uint8List.fromList(transactionBytes).toJS;
      final txObj = solanaWeb3!.transaction.from(jsData);

      final response = await provider.signAndSendTransaction(txObj).toDart;
      return response.signature;
    } catch (e) {
      return null;
    }
  }

  //===================================================================
  // Mass signature. Only the signature, your server must send it.
  // Returns a list of signed transactions as bytes [List<int>] or null if there was an error/cancellation.
  Future<List<Uint8List>?> signAllTransactions(
    List<List<int>> transactionsBytesList,
  ) async {
    final provider = _provider;
    if (provider == null || solanaWeb3 == null) return null;

    try {
      final jsTxArray = JSArray<JSObject>();

      for (final bytes in transactionsBytesList) {
        final jsData = Uint8List.fromList(bytes).toJS;
        final message = solanaWeb3!.versionedMessage.deserialize(jsData);

        final constructor = solanaWeb3!.versionedTransaction as JSFunction;
        final JSObject txObjJs = constructor.callAsConstructor(message);
        final txObj = txObjJs as VersionedTransaction;

        jsTxArray.add(txObj);
      }

      final resultPromise = provider.signAllTransactions(jsTxArray);
      final signedJsTxArray = await resultPromise.toDart;

      final List<Uint8List> resultList = [];
      final dartList = signedJsTxArray.toDart;

      for (final jsObj in dartList) {
        final VersionedTransaction signedTx = jsObj as VersionedTransaction;
        final signedBytes = signedTx.serialize().toDart;

        resultList.add(signedBytes);
      }

      return resultList;
    } catch (e) {
      return null;
    }
  }

  //===================================================================
  // Sending multiple transactions.
  // Returns a list of Strings with signatures or null if there was an error/cancellation.
  Future<List<String>?> signAndSendAllTransactions(
    List<List<int>> transactionsBytesList,
  ) async {
    final provider = _provider;
    if (provider == null || solanaWeb3 == null) return null;

    try {
      final jsTxArray = JSArray<JSObject>();

      // We go through all transactions from Dart
      for (final bytes in transactionsBytesList) {
        final jsData = Uint8List.fromList(bytes).toJS;
        // We wrap each one in JS Transaction
        final txObj = solanaWeb3!.transaction.from(jsData);
        jsTxArray.add(txObj);
      }

      final response = await provider
          .signAndSendAllTransactions(jsTxArray)
          .toDart;

      final signatures = response.signatures.toDart
          .map((jsStr) => jsStr.toDart)
          .toList();

      return signatures;
    } catch (e) {
      return null;
    }
  }
}
