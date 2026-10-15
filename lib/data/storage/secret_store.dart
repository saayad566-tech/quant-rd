/// Abstraction over secure credential storage.
///
/// On Android this is the Keystore-backed encrypted store; on Windows it is the
/// DPAPI-protected store; on web it uses the browser crypto store. Secrets are
/// never written to logs, the database, or the source tree.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

class SecureSecretStore implements SecretStore {
  final FlutterSecureStorage _storage;

  SecureSecretStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    final v = await _storage.read(key: key);
    return (v == null || v.isEmpty) ? null : v;
  }

  @override
  Future<void> write(String key, String value) async {
    if (value.isEmpty) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();
}

/// Non-persistent store used in tests and as a defensive fallback when the
/// platform secure store is unavailable.
class InMemorySecretStore implements SecretStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async {
    if (value.isEmpty) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async => _map.remove(key);

  @override
  Future<Map<String, String>> readAll() async => Map.of(_map);
}
