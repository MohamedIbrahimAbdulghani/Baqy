import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_database.dart';
import 'db_connection.dart';
import 'secure_key_storage.dart';
import '../../utils/account_hash_helper.dart';

class AccountDatabaseManager {
  AccountDatabaseManager({
    FlutterSecureStorage? secureStorage,
    this._sharedPreferences,
    Future<Directory> Function()? documentsDirectoryProvider,
  })  : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(resetOnError: true),
            ),
        _docsDirProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final FlutterSecureStorage _secureStorage;
  SharedPreferences? _sharedPreferences;
  final Future<Directory> Function() _docsDirProvider;

  static const String legacyFileName = 'baqy_encrypted.sqlite';
  static const String legacyKeyName = 'baqy_db_encryption_key';
  static const String prefsClaimedBy = 'legacy_db_claimed_by';

  Future<SharedPreferences> _getPrefs() async {
    return _sharedPreferences ??= await SharedPreferences.getInstance();
  }

  String getDatabaseFileName(String accountId) {
    final shortId = AccountHashHelper.deriveIdentifier(accountId);
    return 'baqy_encrypted_$shortId.sqlite';
  }

  String getKeyStorageKey(String accountId) {
    final shortId = AccountHashHelper.deriveIdentifier(accountId);
    return 'baqy_db_encryption_key_$shortId';
  }

  Future<AppDatabase> openDatabaseForAccount(String accountId) async {
    final shortId = AccountHashHelper.deriveIdentifier(accountId);
    final docsDir = await _docsDirProvider();
    final prefs = await _getPrefs();

    final legacyFile = File(p.join(docsDir.path, legacyFileName));
    final accountFile =
        File(p.join(docsDir.path, 'baqy_encrypted_$shortId.sqlite'));
    final accountKeyName = 'baqy_db_encryption_key_$shortId';

    final claimedBy = prefs.getString(prefsClaimedBy);

    // 1. Check if legacy database exists and hasn't been claimed yet and accountFile does not already exist
    if (claimedBy == null && await legacyFile.exists() && !await accountFile.exists()) {
      try {
        final legacyKey = await _secureStorage.read(key: legacyKeyName);
        if (legacyKey != null && legacyKey.isNotEmpty) {
          await _secureStorage.write(key: accountKeyName, value: legacyKey);
          try {
            await _secureStorage.delete(key: legacyKeyName);
          } catch (_) {}
        }

        // Copy legacy database to account database
        await legacyFile.copy(accountFile.path);

        // Verify copy integrity
        if (!await accountFile.exists() ||
            await accountFile.length() != await legacyFile.length()) {
          throw Exception('Failed to verify migrated database file');
        }

        // Mark legacy DB claimed by this account
        await prefs.setString(prefsClaimedBy, shortId);

        // Safely attempt to remove legacy file; if held open, don't fail migration
        try {
          await legacyFile.delete();
        } catch (_) {}
      } catch (e) {
        // Migration safety: keep legacy file completely untouched
        if (await accountFile.exists()) {
          try {
            await accountFile.delete();
          } catch (_) {}
        }
        rethrow;
      }
    }

    final keyStorage = AccountDatabaseKeyStorage(
      storageKey: accountKeyName,
      storage: _secureStorage,
    );

    return AppDatabase(
      openEncryptedConnection(
        file: accountFile,
        keyStorage: keyStorage,
      ),
    );
  }
}

class AccountDatabaseKeyStorage implements DatabaseKeyStorage {
  AccountDatabaseKeyStorage({
    required this._storageKey,
    required this._storage,
  });

  final String _storageKey;
  final FlutterSecureStorage _storage;

  @override
  Future<String> getOrCreateKey() async {
    final existingKey = await _storage.read(key: _storageKey);
    if (existingKey != null && existingKey.isNotEmpty) {
      return existingKey;
    }

    // Generate 32 cryptographically secure random bytes (256-bit key)
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final newKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: _storageKey, value: newKey);
    return newKey;
  }

  @override
  Future<void> clearKey() async {
    await _storage.delete(key: _storageKey);
  }
}
