import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A class for storing sessions in secure storage.
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

/// Base interface for storing Phantom wallet keys and sessions.
///
/// Allows developers to implement a custom secure storage solution
/// if the standard [SecurePhantomStorage] does not meet their needs.
abstract class PhantomStorage {
  /// Reads the value for the given [key].
  /// Returns the stored string or `null` if the key is not found.
  Future<String?> read(String key);

  /// Saves the string value [value] under the key [key].
  Future<void> write(String key, String value);

  /// Removes the value associated with the key [key].
  Future<void> delete(String key);
}
