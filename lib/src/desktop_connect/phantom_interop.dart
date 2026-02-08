import 'dart:js_interop';

@JS('window')
external JSObject get window;

extension type WindowExtension(JSObject o) {
  @JS('solana')
  external PhantomProvider? get solana;
}

@JS('solanaWeb3')
external SolanaWeb3Namespace? get solanaWeb3;

@JS()
extension type SolanaWeb3Namespace(JSObject o) implements JSObject {
  @JS('Transaction')
  external TransactionClass get transaction;

  @JS('VersionedTransaction')
  external VersionedTransactionClass get versionedTransaction;

  @JS('VersionedMessage')
  external VersionedMessageClass get versionedMessage;
}

@JS()
extension type VersionedMessageClass(JSObject o) implements JSObject {
  external VersionedMessage deserialize(JSUint8Array data);
}

@JS()
extension type VersionedMessage(JSObject o) implements JSObject {}

@JS()
extension type VersionedTransactionClass(JSObject o) implements JSObject {
  external VersionedTransaction deserialize(JSUint8Array data);
  external VersionedTransaction call(VersionedMessage message);
}

@JS()
extension type VersionedTransaction(JSObject o) implements JSObject {
  external JSUint8Array serialize();
}

@JS()
extension type PhantomProvider(JSObject o) implements JSObject {
  external bool get isPhantom;
  external bool get isConnected;

  external JSPromise<ConnectResponse> connect([ConnectOptions? options]);
  external JSPromise<JSAny?> disconnect();

  external JSPromise<SignMessageResponse> signMessage(
    JSObject message,
    String encoding,
  );

  external JSPromise<JSObject> signTransaction(JSObject transaction);

  external JSPromise<SignAndSendTransactionResponse> signAndSendTransaction(
    JSObject transaction, [
    SignAndSendOptions? options,
  ]);

  external JSPromise<JSArray<JSObject>> signAllTransactions(
    JSArray<JSObject> transactions,
  );

  external JSPromise<SignAndSendAllResponse> signAndSendAllTransactions(
    JSArray<JSObject> transactions, [
    SignAndSendOptions? options,
  ]);
}

@JS()
extension type ConnectOptions._(JSObject o) implements JSObject {
  external factory ConnectOptions({bool? onlyIfTrusted});
}

@JS()
extension type ConnectResponse(JSObject o) implements JSObject {
  external PublicKey get publicKey;
}

@JS()
extension type SignMessageResponse(JSObject o) implements JSObject {
  external JSObject get signature;
}

@JS()
extension type TransactionClass(JSObject o) implements JSObject {
  external JSObject from(JSUint8Array data);
  external JSUint8Array serialize([SerializeConfig? config]);
}

@JS()
extension type SerializeConfig._(JSObject o) implements JSObject {
  external factory SerializeConfig({bool? verifySignatures});
}

@JS()
extension type SignAndSendOptions._(JSObject o) implements JSObject {
  external factory SignAndSendOptions({bool? skipPreflight});
}

@JS()
extension type SignAndSendTransactionResponse(JSObject o) implements JSObject {
  external String get signature;
  external PublicKey get publicKey;
}

@JS()
extension type SignAndSendAllResponse(JSObject o) implements JSObject {
  external JSArray<JSString> get signatures;
  external PublicKey get publicKey;
}

@JS()
extension type PublicKey(JSObject o) implements JSObject {
  external String toBase58();
}
