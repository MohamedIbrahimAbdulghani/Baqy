import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class DatabaseKeyStorage {
  Future<String> getOrCreateKey();
  Future<void> clearKey();
}

class SecureDatabaseKeyStorage implements DatabaseKeyStorage {
  SecureDatabaseKeyStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
            );

  final FlutterSecureStorage _storage;
  static const String _keyName = 'baqy_db_encryption_key';

  @override
  Future<String> getOrCreateKey() async {
    final existingKey = await _storage.read(key: _keyName);
    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    // Generate 32 cryptographically secure random bytes (256-bit key)
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final newKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: _keyName, value: newKey);
    return newKey;
  }

  @override
  Future<void> clearKey() async {
    await _storage.delete(key: _keyName);
  }
}

