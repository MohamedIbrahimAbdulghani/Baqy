import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/utils/account_hash_helper.dart';
import 'package:baqy/core/database/connection/account_database_manager.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeSecureStorage fakeStorage;
  late SharedPreferences prefs;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('baqy_account_test_');
    fakeStorage = FakeSecureStorage();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    try {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    } catch (_) {}
  });

  test('per-account database name is a stable 16-character hex hash and never contains raw id or email', () {
    const rawAccountId = 'user_12345_google_id';
    const email = 'user@example.com';

    final id1 = AccountHashHelper.deriveIdentifier(rawAccountId);
    final id2 = AccountHashHelper.deriveIdentifier(rawAccountId);

    expect(id1.length, equals(16));
    expect(id1, equals(id2)); // Stable
    expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(id1), isTrue); // Hex only

    expect(id1.contains(rawAccountId), isFalse);
    expect(id1.contains(email), isFalse);

    final manager = AccountDatabaseManager(
      secureStorage: fakeStorage,
      sharedPreferences: prefs,
      documentsDirectoryProvider: () async => tempDir,
    );

    final fileName = manager.getDatabaseFileName(rawAccountId);
    expect(fileName, equals('baqy_encrypted_$id1.sqlite'));
    expect(fileName.contains(rawAccountId), isFalse);
    expect(fileName.contains(email), isFalse);
  });

  test('old database is claimed only by the first account', () async {
    final legacyFile = File('${tempDir.path}/baqy_encrypted.sqlite');
    await legacyFile.writeAsString('LEGACY_DATABASE_PAYLOAD');
    await fakeStorage.write(
      key: 'baqy_db_encryption_key',
      value: 'legacy_key_1234567890abcdef',
    );

    final manager = AccountDatabaseManager(
      secureStorage: fakeStorage,
      sharedPreferences: prefs,
      documentsDirectoryProvider: () async => tempDir,
    );

    const firstAccountId = 'account_one_uid';
    final firstShortId = AccountHashHelper.deriveIdentifier(firstAccountId);

    // First account signs in
    final db1 = await manager.openDatabaseForAccount(firstAccountId);
    await db1.close();

    // Verification: legacy file moved to account 1 file
    expect(await legacyFile.exists(), isFalse);
    final firstAccountFile = File('${tempDir.path}/baqy_encrypted_$firstShortId.sqlite');
    expect(await firstAccountFile.exists(), isTrue);
    expect(await firstAccountFile.readAsString(), equals('LEGACY_DATABASE_PAYLOAD'));
    expect(
      fakeStorage.values['baqy_db_encryption_key_$firstShortId'],
      equals('legacy_key_1234567890abcdef'),
    );
    expect(prefs.getString('legacy_db_claimed_by'), equals(firstShortId));
  });

  test('second account gets a fresh empty database with default categories', () async {
    final legacyFile = File('${tempDir.path}/baqy_encrypted.sqlite');
    await legacyFile.writeAsString('LEGACY_DATABASE_PAYLOAD');
    await fakeStorage.write(
      key: 'baqy_db_encryption_key',
      value: 'legacy_key_1234567890abcdef',
    );

    final manager = AccountDatabaseManager(
      secureStorage: fakeStorage,
      sharedPreferences: prefs,
      documentsDirectoryProvider: () async => tempDir,
    );

    const firstAccountId = 'account_first';
    final firstDb = await manager.openDatabaseForAccount(firstAccountId);
    await firstDb.close();

    // Second account signs in
    const secondAccountId = 'account_second';
    final secondShortId = AccountHashHelper.deriveIdentifier(secondAccountId);

    final secondDb = await manager.openDatabaseForAccount(secondAccountId);

    // Check default categories seeded for account 2 (triggers lazy database creation)
    final categories = await secondDb.select(secondDb.categories).get();
    expect(categories.length, equals(23));

    // Second account file exists separately
    final secondAccountFile = File('${tempDir.path}/baqy_encrypted_$secondShortId.sqlite');
    expect(await secondAccountFile.exists(), isTrue);

    // And second account key is newly created
    expect(fakeStorage.values['baqy_db_encryption_key_$secondShortId'], isNotNull);
    expect(
      fakeStorage.values['baqy_db_encryption_key_$secondShortId'],
      isNot(equals('legacy_key_1234567890abcdef')),
    );

    await secondDb.close();
  });

  test('signing out keeps the data and signing in again restores it', () async {
    final manager = AccountDatabaseManager(
      secureStorage: fakeStorage,
      sharedPreferences: prefs,
      documentsDirectoryProvider: () async => tempDir,
    );

    const accountId = 'user_persistent_data';
    final shortId = AccountHashHelper.deriveIdentifier(accountId);

    // 1. Sign in and insert a custom category
    final db1 = await manager.openDatabaseForAccount(accountId);
    final countBefore = (await db1.select(db1.categories).get()).length;
    await db1.into(db1.categories).insert(
      CategoriesCompanion.insert(
        name: 'تصنيف إضافي للتجربة',
        icon: 'test_icon',
        colorHex: '#123456',
      ),
    );
    final countAfter = (await db1.select(db1.categories).get()).length;
    expect(countAfter, equals(countBefore + 1));
    await db1.close();

    // 2. Simulate Sign-Out (nothing deleted)
    final file = File('${tempDir.path}/baqy_encrypted_$shortId.sqlite');
    expect(await file.exists(), isTrue);

    // 3. Sign in again with same account
    final db2 = await manager.openDatabaseForAccount(accountId);
    final restoredCategories = await db2.select(db2.categories).get();
    expect(restoredCategories.length, equals(countAfter));
    expect(
      restoredCategories.any((c) => c.name == 'تصنيف إضافي للتجربة'),
      isTrue,
    );
    await db2.close();
  });
}
