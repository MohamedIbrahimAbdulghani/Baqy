import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/services/notification_service.dart';
import 'package:baqy/features/backup/data/datasources/backup_remote_data_source.dart';
import 'package:baqy/features/backup/data/repositories/backup_repository_impl.dart';
import 'package:baqy/features/backup/domain/exceptions/backup_exceptions.dart';
import 'package:baqy/features/backup/domain/models/backup_meta.dart';
import 'package:baqy/features/backup/domain/models/backup_snapshot.dart';
import 'package:baqy/features/backup/presentation/controllers/backup_sync_controller.dart';
import 'package:baqy/features/backup/presentation/widgets/restore_prompt_dialog.dart';
import 'package:baqy/features/debts/domain/models/debt_item.dart';
import 'package:baqy/features/reminders/domain/models/reminder_item.dart';

class FakeBackupRemoteDataSource implements BackupRemoteDataSource {
  BackupMeta? storedMeta;
  final Map<int, Uint8List> storedChunks = {};
  int uploadCalls = 0;

  @override
  Future<BackupMeta?> getMeta(String uid) async {
    return storedMeta;
  }

  @override
  Future<List<Uint8List>> getChunks(String uid, int chunkCount) async {
    final list = <Uint8List>[];
    for (int i = 0; i < chunkCount; i++) {
      if (!storedChunks.containsKey(i)) {
        throw Exception('Missing chunk chunk_$i');
      }
      list.add(storedChunks[i]!);
    }
    return list;
  }

  @override
  Future<void> uploadBackup({
    required String uid,
    required BackupMeta meta,
    required List<Uint8List> chunks,
  }) async {
    uploadCalls++;
    storedMeta = meta;
    storedChunks.clear();
    for (int i = 0; i < chunks.length; i++) {
      storedChunks[i] = chunks[i];
    }
    _metaController.add(meta);
  }

  final _metaController = StreamController<BackupMeta?>.broadcast();

  @override
  Stream<BackupMeta?> watchMeta(String uid) => _metaController.stream;
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService() : super.test();

  int rescheduleRemindersCalls = 0;
  int rescheduleDebtsCalls = 0;

  @override
  Future<void> rescheduleReminders(List<ReminderItem> reminders) async {
    rescheduleRemindersCalls++;
  }

  @override
  Future<void> rescheduleDebts(List<DebtItem> debts) async {
    rescheduleDebtsCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PERMANENT TESTS - Step 10B Backup & Restore', () {
    late AppDatabase db;
    late FakeBackupRemoteDataSource fakeRemote;
    late BackupRepositoryImpl repo;
    late FakeNotificationService fakeNotif;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      fakeRemote = FakeBackupRemoteDataSource();
      repo = BackupRepositoryImpl(fakeRemote);
      fakeNotif = FakeNotificationService();
      NotificationService.testInstance = fakeNotif;
    });

    tearDown(() async {
      await db.close();
    });

    test('1. snapshot export then import gives identical data for all tables including goal savings and debt payment links', () async {
      // Seed data into all 9 tables
      // 1. Categories already seeded with 22 default categories. Add 1 custom category:
      await db.customStatement(
        "INSERT INTO categories (id, name, icon, color, is_default, is_archived, sort_order, created_by_ai, created_at) "
        "VALUES (30, 'تصنيف خاص', 'star', '#FF5500', 0, 0, 99, 0, 1716000000);",
      );

      // 2. Month budget
      await db.customStatement(
        "INSERT INTO month_budgets (year_month, amount) VALUES ('2026-11', 2500000);",
      );

      // 3. User rule
      await db.customStatement(
        "INSERT INTO user_rules (id, keyword, category_id, created_at) VALUES (10, 'قهوة خاصة', 2, 1716000000);",
      );

      // 4. Goal
      await db.customStatement(
        "INSERT INTO goals (id, name, target_amount, monthly_saving, created_at, icon) VALUES (5, 'لابتوب جديد', 5000000, 500000, 1716000000, 'laptop');",
      );

      // 5. Goal saving
      await db.customStatement(
        "INSERT INTO goal_savings (id, goal_id, amount, saved_at) VALUES (12, 5, 200000, 1716001000);",
      );

      // 6. Reminder
      await db.customStatement(
        "INSERT INTO reminders (id, name, amount, due_date, repeat, lead_days) VALUES (7, 'فاتورة الكهرباء', 35000, 1716002000, 'monthly', 2);",
      );

      // 7. Transaction (linked to debt payment)
      await db.customStatement(
        "INSERT INTO transactions (id, amount, description, category_id, kind, source, note, created_at) "
        "VALUES (101, 15000, 'سداد دين أحمد', 22, 'expense', 'debt', 'قسط أول', 1716003000);",
      );

      // 8. Debt
      await db.customStatement(
        "INSERT INTO debts (id, person_name, direction, total_amount, lead_days, reminder_enabled, archived, created_at) "
        "VALUES (8, 'أحمد', 'owe', 50000, 2, 1, 0, 1716000000);",
      );

      // 9. Debt payment linked to debt 8 and transaction 101
      await db.customStatement(
        "INSERT INTO debt_payments (id, debt_id, amount, paid_at, transaction_id) VALUES (40, 8, 15000, 1716003000, 101);",
      );

      // Verify hasUserData is true
      final hasData = await repo.hasUserData(db);
      expect(hasData, isTrue);

      // Export snapshot
      final snapshot = await repo.exportSnapshot(db);
      expect(snapshot.schemaVersion, equals(9));
      expect(snapshot.tables['categories']!.length, equals(AppDatabase.defaultCategoryDefinitions.length + 1)); // defaults + 1 custom
      expect(snapshot.tables['month_budgets']!.length, equals(1));
      expect(snapshot.tables['user_rules']!.length, equals(1));
      expect(snapshot.tables['goals']!.length, equals(1));
      expect(snapshot.tables['goal_savings']!.length, equals(1));
      expect(snapshot.tables['reminders']!.length, equals(1));
      expect(snapshot.tables['transactions']!.length, equals(1));
      expect(snapshot.tables['debts']!.length, equals(1));
      expect(snapshot.tables['debt_payments']!.length, equals(1));

      // Now create a completely fresh database
      final newDb = AppDatabase(NativeDatabase.memory());
      // Restore into new database
      await repo.restoreFromSnapshot(snapshot: snapshot, db: newDb);

      // Verify all tables match exactly
      final newCustomCat = await newDb.customSelect('SELECT * FROM categories WHERE id = 30;').getSingle();
      expect(newCustomCat.data['name'], equals('تصنيف خاص'));
      expect(newCustomCat.data['color'], equals('#FF5500'));

      final newBudget = await newDb.customSelect("SELECT * FROM month_budgets WHERE year_month = '2026-11';").getSingle();
      expect(newBudget.data['amount'], equals(2500000));

      final newGoal = await newDb.customSelect('SELECT * FROM goals WHERE id = 5;').getSingle();
      expect(newGoal.data['name'], equals('لابتوب جديد'));

      final newSaving = await newDb.customSelect('SELECT * FROM goal_savings WHERE id = 12;').getSingle();
      expect(newSaving.data['goal_id'], equals(5));
      expect(newSaving.data['amount'], equals(200000));

      final newTx = await newDb.customSelect('SELECT * FROM transactions WHERE id = 101;').getSingle();
      expect(newTx.data['description'], equals('سداد دين أحمد'));
      expect(newTx.data['amount'], equals(15000));
      expect(newTx.data['source'], equals('debt'));

      final newDebt = await newDb.customSelect('SELECT * FROM debts WHERE id = 8;').getSingle();
      expect(newDebt.data['person_name'], equals('أحمد'));

      final newPayment = await newDb.customSelect('SELECT * FROM debt_payments WHERE id = 40;').getSingle();
      expect(newPayment.data['debt_id'], equals(8));
      expect(newPayment.data['transaction_id'], equals(101));
      expect(newPayment.data['amount'], equals(15000));

      // Notifications rescheduled
      expect(fakeNotif.rescheduleRemindersCalls, greaterThanOrEqualTo(1));
      expect(fakeNotif.rescheduleDebtsCalls, greaterThanOrEqualTo(1));

      await newDb.close();
    });

    test('2. chunking splits a snapshot bigger than 700 KB and reassembles it with a matching hash', () async {
      // Create a large snapshot with many transactions (generating > 800 KB of JSON)
      final largeRows = <Map<String, dynamic>>[];
      for (int i = 0; i < 6000; i++) {
        largeRows.add({
          'id': i + 1,
          'amount': 25000,
          'description': 'وصف مصاريف طويلة جداً للتجربة والاختبار رقم $i مع نص إضافي لتكبير الحجم',
          'category_id': 1,
          'kind': 'expense',
          'source': 'text',
          'note': 'ملاحظة طويلة للتجربة بحجم بيانات كبير $i',
          'created_at': 1716000000 + i,
        });
      }

      final largeSnapshot = BackupSnapshot(
        schemaVersion: 9,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [],
          'transactions': largeRows,
        },
      );

      final processed = isolateCompressAndChunk(largeSnapshot.toJson());

      // If raw json was ~1.5 MB, check chunking
      expect(processed.chunks.isNotEmpty, isTrue);
      for (final chunk in processed.chunks) {
        expect(chunk.length, lessThanOrEqualTo(700 * 1024));
      }

      // Reassemble and decompress
      final rawReassembled = gzip.decode(
        processed.chunks.expand((c) => c).toList(),
      );
      final jsonStr = utf8.decode(rawReassembled);
      final computedHash = sha256.convert(utf8.encode(jsonStr)).toString();
      expect(computedHash, equals(processed.contentHash));

      final restoredSnapshot = BackupSnapshot.fromJson(jsonDecode(jsonStr));
      expect(restoredSnapshot.tables['transactions']!.length, equals(6000));
    });

    test('3. meta contains no content, only counts and hashes', () async {
      final meta = BackupMeta(
        schemaVersion: 9,
        chunkCount: 2,
        updatedAt: DateTime.parse('2026-11-23T04:57:00Z'),
        tableCounts: {'transactions': 50, 'debts': 3},
        contentHash: 'abc123hash',
      );

      final json = meta.toJson();
      expect(json.keys, containsAll(['schemaVersion', 'chunkCount', 'updatedAt', 'tableCounts', 'contentHash']));
      expect(json.keys.length, equals(5));

      // No financial content, names or text inside meta
      final serialized = jsonEncode(json);
      expect(serialized.contains('أحمد'), isFalse);
      expect(serialized.contains('مصاريف'), isFalse);
      expect(serialized.contains('piastres'), isFalse);
    });

    test('4. an empty database never overwrites an existing cloud backup', () async {
      // Put existing backup in remote store
      fakeRemote.storedMeta = BackupMeta(
        schemaVersion: 9,
        chunkCount: 1,
        updatedAt: DateTime.now(),
        tableCounts: {'transactions': 10},
        contentHash: 'hash1',
      );
      fakeRemote.storedChunks[0] = Uint8List(10);

      // Fresh empty database
      final emptyDb = AppDatabase(NativeDatabase.memory());
      final hasData = await repo.hasUserData(emptyDb);
      expect(hasData, isFalse);

      // Attempt upload -> MUST throw EmptyDatabaseOverwriteException
      await expectLater(
        repo.uploadBackup(uid: 'user123', db: emptyDb),
        throwsA(isA<EmptyDatabaseOverwriteException>()),
      );

      // Remote store backup remains untouched
      expect(fakeRemote.storedMeta!.contentHash, equals('hash1'));
      expect(fakeRemote.uploadCalls, equals(0));

      await emptyDb.close();
    });

    test('5. restore replaces everything in one transaction and a simulated failure in the middle keeps the old data', () async {
      // Seed initial data in db
      await db.customStatement(
        "INSERT INTO transactions (id, amount, description, category_id, kind, source, created_at) "
        "VALUES (1, 5000, 'سندوتش كبدة قديم', 1, 'expense', 'text', 1716000000);",
      );

      // Corrupted snapshot with missing required column in transactions
      final invalidSnapshot = BackupSnapshot(
        schemaVersion: 9,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [],
          'transactions': [
            {
              'id': 2,
              // Missing required columns: amount, category_id, kind, source!
              'description': 'معاملة ناقصة الأعمدة الإلزامية',
            }
          ],
        },
      );

      // Attempt restore -> fails
      await expectLater(
        repo.restoreFromSnapshot(snapshot: invalidSnapshot, db: db),
        throwsA(isA<CorruptedBackupException>()),
      );

      // Old data remains completely untouched (transaction rolled back)
      final existing = await db.customSelect('SELECT * FROM transactions WHERE id = 1;').getSingle();
      expect(existing.data['description'], equals('سندوتش كبدة قديم'));
    });

    test('6. a newer schemaVersion is refused', () async {
      final newerSnapshot = BackupSnapshot(
        schemaVersion: 99, // Future schema version
        createdAt: DateTime.now().toUtc(),
        tables: {},
      );

      await expectLater(
        repo.restoreFromSnapshot(snapshot: newerSnapshot, db: db),
        throwsA(isA<NewerSchemaVersionException>()),
      );
    });

    test('7. an older snapshot with a missing nullable column imports', () async {
      // Snapshot where nullable column 'note' is missing from transactions
      final olderSnapshot = BackupSnapshot(
        schemaVersion: 8,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {
              'id': 1,
              'name': 'أكل',
              'icon': 'food',
              'color': '#4E8B7A',
              'is_default': 1,
              'is_archived': 0,
              'sort_order': 1,
              'created_by_ai': 0,
              'created_at': 1716000000,
            }
          ],
          'transactions': [
            {
              'id': 50,
              'amount': 2000,
              'description': 'شاي',
              'category_id': 1,
              'kind': 'expense',
              'source': 'text',
              // 'note' and 'foreign_amount' are missing nullable columns
              'created_at': 1716000000,
            }
          ],
        },
      );

      await repo.restoreFromSnapshot(snapshot: olderSnapshot, db: db);

      final row = await db.customSelect('SELECT * FROM transactions WHERE id = 50;').getSingle();
      expect(row.data['description'], equals('شاي'));
      expect(row.data['note'], isNull);
      expect(row.data['foreign_amount'], isNull);
    });

    test('8. ids continue after the highest restored id', () async {
      final snapshot = BackupSnapshot(
        schemaVersion: 9,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {
              'id': 50,
              'name': 'تصنيف 50',
              'icon': 'star',
              'color': '#112233',
              'is_default': 0,
              'is_archived': 0,
              'sort_order': 50,
              'created_by_ai': 0,
              'created_at': 1716000000,
            }
          ],
          'transactions': [
            {
              'id': 100,
              'amount': 3000,
              'description': 'معاملة 100',
              'category_id': 50,
              'kind': 'expense',
              'source': 'text',
              'created_at': 1716000000,
            }
          ],
        },
      );

      await repo.restoreFromSnapshot(snapshot: snapshot, db: db);

      // Insert a new transaction without specifying ID
      await db.customStatement(
        "INSERT INTO transactions (amount, description, category_id, kind, source, created_at) "
        "VALUES (1000, 'معاملة جديدة بعد الاسترجاع', 50, 'expense', 'text', 1716001000);",
      );

      final newTx = await db.customSelect(
        "SELECT id FROM transactions WHERE description = 'معاملة جديدة بعد الاسترجاع';",
      ).getSingle();
      final newId = newTx.data['id'] as int;

      // Auto-generated ID continues after 100
      expect(newId, greaterThan(100));
    });

    test('9. ARB files have identical keys in Arabic and English', () async {
      final arFile = File('lib/l10n/app_ar.arb');
      final enFile = File('lib/l10n/app_en.arb');

      expect(arFile.existsSync(), isTrue);
      expect(enFile.existsSync(), isTrue);

      final arJson = jsonDecode(arFile.readAsStringSync()) as Map<String, dynamic>;
      final enJson = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;

      // Filter out @ metadata keys and @@locale
      final arKeys = arJson.keys.where((k) => !k.startsWith('@')).toSet();
      final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();

      expect(arKeys, equals(enKeys));
    });

    test('10. docs/firestore.rules exists and contains exact security rules', () async {
      final rulesFile = File('docs/firestore.rules');
      expect(rulesFile.existsSync(), isTrue);

      final content = rulesFile.readAsStringSync();
      expect(content.contains("rules_version = '2';"), isTrue);
      expect(content.contains("service cloud.firestore"), isTrue);
      expect(content.contains("match /users/{uid}/backup/{docId}"), isTrue);
      expect(content.contains("docId.matches('meta|chunk_[0-9]{1,3}')"), isTrue);
      expect(content.contains("match /{document=**} { allow read, write: if false; }"), isTrue);
    });

    testWidgets('11. restore dialog on new phone displays correctly and handles ابدأ من جديد flow', (tester) async {
      bool restored = false;
      bool startedFresh = false;

      final meta = BackupMeta(
        schemaVersion: 9,
        chunkCount: 1,
        updatedAt: DateTime.parse('2026-11-23T04:57:00Z'),
        tableCounts: {'transactions': 5},
        contentHash: 'hash',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Consumer(
                    builder: (context, ref, _) {
                      return ElevatedButton(
                        onPressed: () {
                          RestorePromptDialog.showNewPhonePrompt(
                            context: context,
                            ref: ref,
                            uid: 'uid123',
                            meta: meta,
                            onRestoreConfirmed: () => restored = true,
                            onStartFreshConfirmed: () => startedFresh = true,
                          );
                        },
                        child: const Text('Show Dialog'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open prompt
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      // Verify title and buttons
      expect(find.text('لقينا نسخة احتياطية'), findsOneWidget);
      expect(find.text('استرجاع'), findsOneWidget);
      expect(find.text('ابدأ من جديد'), findsOneWidget);

      // Click "ابدأ من جديد" -> opens confirmation dialog
      await tester.tap(find.text('ابدأ من جديد'));
      await tester.pumpAndSettle();

      // Verify confirmation dialog
      expect(find.text('متأكد؟'), findsOneWidget);
      expect(find.text('النسخة القديمة هتتبدّل لما التطبيق يحفظ نسخة جديدة.'), findsOneWidget);
      expect(find.text('رجوع'), findsOneWidget);

      // Confirm "ابدأ من جديد"
      final confirmButtons = find.widgetWithText(ElevatedButton, 'ابدأ من جديد');
      await tester.tap(confirmButtons);
      await tester.pumpAndSettle();

      expect(startedFresh, isTrue);
      expect(restored, isFalse);
    });

    test('12. live sync: when another device uploads a new snapshot, the listening device automatically restores it in the background', () async {
      // 1. Setup Device B with controller listening
      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: 'user123',
      );

      // Verify DB currently has 0 transactions
      final initialTx = await db.customSelect('SELECT COUNT(*) AS c FROM transactions;').getSingle();
      expect(initialTx.data['c'], equals(0));

      // 2. Simulate Device A uploading a new snapshot with 1 transaction
      final newSnapshot = BackupSnapshot(
        schemaVersion: 9,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {
              'id': 1,
              'name': 'أكل',
              'icon': 'food',
              'color': '#4E8B7A',
              'is_default': 1,
              'is_archived': 0,
              'sort_order': 1,
              'created_by_ai': 0,
              'created_at': 1716000000,
            }
          ],
          'transactions': [
            {
              'id': 1,
              'amount': 3500,
              'description': 'شاي من الموبايل',
              'category_id': 1,
              'kind': 'expense',
              'source': 'text',
              'created_at': 1716000000,
            }
          ],
        },
      );

      final processed = isolateCompressAndChunk(newSnapshot.toJson());
      final meta = BackupMeta(
        schemaVersion: 9,
        chunkCount: processed.chunks.length,
        updatedAt: DateTime.now().toUtc(),
        tableCounts: processed.tableCounts,
        contentHash: processed.contentHash,
      );

      // Device A uploads to fakeRemote
      await fakeRemote.uploadBackup(
        uid: 'user123',
        meta: meta,
        chunks: processed.chunks,
      );

      // Give event loop time to process stream notification and auto-restore
      await Future<void>.delayed(const Duration(milliseconds: 300));

      // 3. Verify Device B automatically restored the transaction without user interaction!
      final txRow = await db.customSelect('SELECT * FROM transactions WHERE id = 1;').getSingle();
      expect(txRow.data['description'], equals('شاي من الموبايل'));
      expect(txRow.data['amount'], equals(3500));

      controller.dispose();
    });

    test('13. live sync: when device B already has local data, new snapshot from device A is automatically restored without rejection', () async {
      // Insert Transaction 1 on Device B first so it has local data
      await db.customStatement(
        "INSERT INTO transactions (id, amount, description, category_id, kind, source, created_at) "
        "VALUES (1, 3500, 'شاي من الموبايل', 1, 'expense', 'text', 1716000000);",
      );

      // Setup Device B with controller listening
      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: 'user123',
      );

      // Verify DB already has data
      final txBefore = await db.customSelect('SELECT COUNT(*) AS c FROM transactions;').getSingle();
      expect(txBefore.data['c'], equals(1));

      // Device A uploads a snapshot containing Transaction 1 + Transaction 2
      final newSnapshot = BackupSnapshot(
        schemaVersion: 9,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {
              'id': 1,
              'name': 'أكل',
              'icon': 'food',
              'color': '#4E8B7A',
              'is_default': 1,
              'is_archived': 0,
              'sort_order': 1,
              'created_by_ai': 0,
              'created_at': 1716000000,
            }
          ],
          'transactions': [
            {
              'id': 1,
              'amount': 3500,
              'description': 'شاي من الموبايل',
              'category_id': 1,
              'kind': 'expense',
              'source': 'text',
              'created_at': 1716000000,
            },
            {
              'id': 2,
              'amount': 5000,
              'description': 'قهوة من جهاز تاني',
              'category_id': 1,
              'kind': 'expense',
              'source': 'text',
              'created_at': 1716000100,
            }
          ],
        },
      );

      final processed = isolateCompressAndChunk(newSnapshot.toJson());
      final meta = BackupMeta(
        schemaVersion: 9,
        chunkCount: processed.chunks.length,
        updatedAt: DateTime.now().toUtc(),
        tableCounts: processed.tableCounts,
        contentHash: processed.contentHash,
      );

      // Wait for controller async _init() to subscribe to remote stream
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Device A uploads
      await fakeRemote.uploadBackup(
        uid: 'user123',
        meta: meta,
        chunks: processed.chunks,
      );

      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Verify Device B seamlessly restored and now has 2 transactions
      final txAfter = await db.customSelect('SELECT COUNT(*) AS c FROM transactions;').getSingle();
      expect(txAfter.data['c'], equals(2));

      final tx2 = await db.customSelect('SELECT * FROM transactions WHERE id = 2;').getSingle();
      expect(tx2.data['description'], equals('قهوة من جهاز تاني'));
      expect(tx2.data['amount'], equals(5000));

      controller.dispose();
    });
  });
}
