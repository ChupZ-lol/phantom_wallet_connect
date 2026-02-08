import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurePhantomStorage implements PhantomStorage {
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}

abstract class PhantomStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}
