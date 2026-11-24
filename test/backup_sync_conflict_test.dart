import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show TableUpdate, UpdateKind;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/services/notification_service.dart';
import 'package:baqy/features/backup/data/datasources/backup_remote_data_source.dart';
import 'package:baqy/features/backup/data/repositories/backup_repository_impl.dart';
import 'package:baqy/features/backup/domain/models/backup_meta.dart';
import 'package:baqy/features/backup/domain/models/backup_snapshot.dart';
import 'package:baqy/features/backup/presentation/controllers/backup_sync_controller.dart';
import 'package:baqy/features/backup/presentation/widgets/backup_conflict_dialog.dart';
import 'package:baqy/features/debts/domain/models/debt_item.dart';
import 'package:baqy/features/reminders/domain/models/reminder_item.dart';

class FakeBackupRemoteDataSource implements BackupRemoteDataSource {
  BackupMeta? storedMeta;
  final Map<int, Uint8List> storedChunks = {};
  int uploadCalls = 0;
  int getMetaCalls = 0;
  final _metaController = StreamController<BackupMeta?>.broadcast();

  @override
  Future<BackupMeta?> getMeta(String uid) async {
    getMetaCalls++;
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
    Map<String, dynamic>? readableSummary,
  }) async {
    uploadCalls++;
    storedMeta = meta;
    storedChunks.clear();
    for (int i = 0; i < chunks.length; i++) {
      storedChunks[i] = chunks[i];
    }
    _metaController.add(meta);
  }

  @override
  Stream<BackupMeta?> watchMeta(String uid) => _metaController.stream;

  @override
  Future<void> deleteBackup(String uid) async {
    storedMeta = null;
    storedChunks.clear();
    _metaController.add(null);
  }

  void emitMeta(BackupMeta? meta) {
    storedMeta = meta;
    _metaController.add(meta);
  }

  void storeSnapshot(BackupSnapshot snapshot) {
    final processed = isolateCompressAndChunk(snapshot.toJson());
    final meta = BackupMeta(
      schemaVersion: snapshot.schemaVersion,
      chunkCount: processed.chunks.length,
      updatedAt: DateTime.now().toUtc(),
      tableCounts: processed.tableCounts,
      contentHash: processed.contentHash,
    );
    storedMeta = meta;
    storedChunks.clear();
    for (int i = 0; i < processed.chunks.length; i++) {
      storedChunks[i] = processed.chunks[i];
    }
  }
}

class FakeNotificationService extends NotificationService {
  FakeNotificationService() : super.test();

  @override
  Future<void> rescheduleReminders(List<ReminderItem> reminders) async {}

  @override
  Future<void> rescheduleDebts(List<DebtItem> debts) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Backup Sync & Conflict Resolution Tests', () {
    late AppDatabase db;
    late FakeBackupRemoteDataSource fakeRemote;
    late BackupRepositoryImpl repo;
    const testUid = 'user_conflict_test_123';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      db = AppDatabase(NativeDatabase.memory());
      fakeRemote = FakeBackupRemoteDataSource();
      repo = BackupRepositoryImpl(fakeRemote);
      NotificationService.testInstance = FakeNotificationService();
    });

    tearDown(() async {
      await db.close();
    });

    test('1. silent restore happens when there are no unsynced local changes', () async {
      // 1. Prepare remote backup containing 1 expense
      final remoteSnapshot = BackupSnapshot(
        schemaVersion: db.schemaVersion,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {'id': 1, 'name': 'أكل', 'icon': 'food', 'color': '#4E8B7A', 'is_default': 1, 'is_archived': 0, 'sort_order': 1, 'created_by_ai': 0, 'created_at': 1716000000}
          ],
          'transactions': [
            {'id': 1, 'amount': 15000, 'description': 'غداء عمل', 'category_id': 1, 'kind': 'expense', 'source': 'manual', 'created_at': 1716000000}
          ],
        },
      );
      fakeRemote.storeSnapshot(remoteSnapshot);
      final remoteMeta = fakeRemote.storedMeta!;

      bool silentRestoreCalled = false;
      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: false,
        onSilentRestoreSuccess: () {
          silentRestoreCalled = true;
        },
      );

      // Verify initial state has no unsynced changes
      expect(controller.hasUnsyncedLocalChanges, isFalse);

      // Handle remote meta
      await controller.handleRemoteMeta(remoteMeta);

      // Local DB now has the restored transaction
      final rows = await db.customSelect('SELECT * FROM transactions WHERE id = 1;').get();
      expect(rows, isNotEmpty);
      expect(rows.first.data['description'], 'غداء عمل');

      expect(silentRestoreCalled, isTrue);
      expect(controller.hasUnsyncedLocalChanges, isFalse);
      expect(controller.lastContentHash, remoteMeta.contentHash);

      controller.dispose();
    });

    test('2. no restore when there are unsynced local changes and local data is uploaded first', () async {
      // Local has a local expense written
      await db.customStatement(
        "INSERT INTO transactions (id, amount, description, category_id, kind, source, created_at) "
        "VALUES (99, 25000, 'تعديل محلي غير محفوظ', 1, 'expense', 'manual', 1716000000);",
      );

      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: false,
      );

      await controller.setHasUnsyncedLocalChanges(true);
      expect(controller.hasUnsyncedLocalChanges, isTrue);

      // Prepare a dummy remote meta with a different hash
      const dummyRemoteHash = 'sha256_remote_incoming_hash_abc';
      final remoteMeta = BackupMeta(
        schemaVersion: db.schemaVersion,
        chunkCount: 1,
        updatedAt: DateTime.now().toUtc(),
        tableCounts: {'transactions': 1},
        contentHash: dummyRemoteHash,
      );

      final initialUploadCalls = fakeRemote.uploadCalls;

      // Handle remote meta
      await controller.handleRemoteMeta(remoteMeta);

      // Verify NO RESTORE happened: local edit is preserved
      final localRows = await db.customSelect('SELECT * FROM transactions WHERE id = 99;').get();
      expect(localRows, isNotEmpty);
      expect(localRows.first.data['description'], 'تعديل محلي غير محفوظ');

      // Verify local data was uploaded first to remote
      expect(fakeRemote.uploadCalls, greaterThan(initialUploadCalls));
      expect(controller.hasUnsyncedLocalChanges, isFalse);

      controller.dispose();
    });

    test('3. the conflict dialog appears only on a real conflict and never chooses automatically', () async {
      ConflictResolution? userChoice;
      int conflictDialogCallCount = 0;

      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: false,
        onConflictDetected: () async {
          conflictDialogCallCount++;
          return userChoice;
        },
      );

      // Local has an expense written that is not uploaded yet
      await db.customStatement(
        "INSERT INTO transactions (id, amount, description, category_id, kind, source, created_at) "
        "VALUES (101, 30000, 'تعديل أوفلاين', 1, 'expense', 'manual', 1716000000);",
      );
      await controller.setHasUnsyncedLocalChanges(true);

      // 1. First incoming remote meta (observed)
      final remoteMeta1 = BackupMeta(
        schemaVersion: db.schemaVersion,
        chunkCount: 1,
        updatedAt: DateTime.now().toUtc(),
        tableCounts: {'transactions': 1},
        contentHash: 'remote_hash_phone_A_version_1',
      );

      // 2. Second incoming remote meta with changed hash while local changes are unsynced
      // (the remote hash changed again meanwhile - a real conflict on two phones!)
      final remoteMeta2 = BackupMeta(
        schemaVersion: db.schemaVersion,
        chunkCount: 1,
        updatedAt: DateTime.now().toUtc(),
        tableCounts: {'transactions': 2},
        contentHash: 'remote_hash_phone_A_version_2',
      );

      // Lock controller from auto-uploading so changes remain unsynced while remote changes
      controller.setExpenseScreenOpen(true);
      await controller.handleRemoteMeta(remoteMeta1);
      expect(conflictDialogCallCount, 0);

      // Now while local changes are still unsynced, remote changed again meanwhile!
      controller.setExpenseScreenOpen(false);
      userChoice = null; // User did not choose anything yet

      // Trigger conflict with remoteMeta2 (hash changed again from remoteMeta1)
      await controller.handleRemoteMeta(remoteMeta2);

      // Dialog was triggered!
      expect(conflictDialogCallCount, 1);
      // Because userChoice is null, it NEVER chooses automatically!
      expect(controller.hasUnsyncedLocalChanges, isTrue);

      controller.dispose();
    });

    test('4. no restore during an upload or while an expense screen is open', () async {
      final remoteSnapshot = BackupSnapshot(
        schemaVersion: db.schemaVersion,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {'id': 1, 'name': 'أكل', 'icon': 'food', 'color': '#4E8B7A', 'is_default': 1, 'is_archived': 0, 'sort_order': 1, 'created_by_ai': 0, 'created_at': 1716000000}
          ],
          'transactions': [
            {'id': 77, 'amount': 10000, 'description': 'شراء من الخارج', 'category_id': 1, 'kind': 'expense', 'source': 'manual', 'created_at': 1716000000}
          ],
        },
      );
      fakeRemote.storeSnapshot(remoteSnapshot);
      final remoteMeta = fakeRemote.storedMeta!;

      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: false,
      );

      // Lock: user is in the middle of adding or editing an expense
      controller.setExpenseScreenOpen(true);
      expect(controller.isExpenseScreenOpen, isTrue);

      // Remote meta arrives
      await controller.handleRemoteMeta(remoteMeta);

      // Must NOT restore while expense screen is open
      final rowsWhileOpen = await db.customSelect('SELECT * FROM transactions WHERE id = 77;').get();
      expect(rowsWhileOpen, isEmpty);

      // Screen is closed: now the queued restore runs!
      await controller.setExpenseScreenOpen(false);
      expect(controller.isExpenseScreenOpen, isFalse);

      final rowsAfterClose = await db.customSelect('SELECT * FROM transactions WHERE id = 77;').get();
      expect(rowsAfterClose, isNotEmpty);
      expect(rowsAfterClose.first.data['description'], 'شراء من الخارج');

      controller.dispose();
    });

    test('5. no loop after a restore', () async {
      final remoteSnapshot = BackupSnapshot(
        schemaVersion: db.schemaVersion,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {'id': 1, 'name': 'أكل', 'icon': 'food', 'color': '#4E8B7A', 'is_default': 1, 'is_archived': 0, 'sort_order': 1, 'created_by_ai': 0, 'created_at': 1716000000}
          ],
          'transactions': [
            {'id': 55, 'amount': 5000, 'description': 'قهوة', 'category_id': 1, 'kind': 'expense', 'source': 'manual', 'created_at': 1716000000}
          ],
        },
      );
      fakeRemote.storeSnapshot(remoteSnapshot);
      final remoteMeta = fakeRemote.storedMeta!;

      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: false,
      );

      await controller.handleRemoteMeta(remoteMeta);

      // Stored restored hash as the last uploaded hash
      expect(controller.lastContentHash, remoteMeta.contentHash);
      final initialUploadCalls = fakeRemote.uploadCalls;

      // Another remote meta event with identical hash arrives
      await controller.handleRemoteMeta(remoteMeta);

      // Does not trigger any upload of the same content
      expect(fakeRemote.uploadCalls, initialUploadCalls);

      controller.dispose();
    });

    test('6. an empty database never overwrites a cloud backup', () async {
      // Fake remote has an existing cloud backup
      final existingSnapshot = BackupSnapshot(
        schemaVersion: db.schemaVersion,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {'id': 1, 'name': 'أكل', 'icon': 'food', 'color': '#4E8B7A', 'is_default': 1, 'is_archived': 0, 'sort_order': 1, 'created_by_ai': 0, 'created_at': 1716000000}
          ],
          'transactions': [
            {'id': 1, 'amount': 15000, 'description': 'سحابي سابق', 'category_id': 1, 'kind': 'expense', 'source': 'manual', 'created_at': 1716000000}
          ],
        },
      );
      fakeRemote.storeSnapshot(existingSnapshot);

      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: false,
      );

      final callsBefore = fakeRemote.uploadCalls;

      // Local db is empty: flush/upload must never overwrite cloud backup
      await controller.flush();

      expect(fakeRemote.uploadCalls, callsBefore);

      controller.dispose();
    });

    test('7. the flag is set after a write and cleared after a successful upload or restore', () async {
      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: false,
      );

      expect(controller.hasUnsyncedLocalChanges, isFalse);

      // 1. Committed local write to a user table
      await db.customStatement(
        "INSERT INTO transactions (id, amount, description, category_id, kind, source, created_at) "
        "VALUES (123, 50000, 'تجربة كتابة', 1, 'expense', 'manual', 1716000000);",
      );
      db.notifyUpdates({const TableUpdate('transactions', kind: UpdateKind.insert)});

      // Wait a microtask for Drift tableUpdates stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.hasUnsyncedLocalChanges, isTrue);

      // 2. Upload succeeds
      await controller.flush();
      expect(controller.hasUnsyncedLocalChanges, isFalse);

      // 3. Another write
      await db.customStatement(
        "INSERT INTO goals (id, name, target_amount, monthly_saving, created_at) "
        "VALUES (10, 'هدف جديد', 1000000, 100000, 1716000000);",
      );
      db.notifyUpdates({const TableUpdate('goals', kind: UpdateKind.insert)});
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.hasUnsyncedLocalChanges, isTrue);

      // 4. Restore succeeds
      final remoteSnapshot = BackupSnapshot(
        schemaVersion: db.schemaVersion,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {'id': 1, 'name': 'أكل', 'icon': 'food', 'color': '#4E8B7A', 'is_default': 1, 'is_archived': 0, 'sort_order': 1, 'created_by_ai': 0, 'created_at': 1716000000}
          ],
          'transactions': [],
        },
      );
      fakeRemote.storeSnapshot(remoteSnapshot);

      await controller.handleRemoteMeta(fakeRemote.storedMeta!);
      expect(controller.hasUnsyncedLocalChanges, isFalse);

      controller.dispose();
    });

    test('8. ARB files have the same keys and contain new keys', () async {
      final arFile = File('lib/l10n/app_ar.arb');
      final enFile = File('lib/l10n/app_en.arb');

      expect(arFile.existsSync(), isTrue);
      expect(enFile.existsSync(), isTrue);

      final arJson = jsonDecode(await arFile.readAsString()) as Map<String, dynamic>;
      final enJson = jsonDecode(await enFile.readAsString()) as Map<String, dynamic>;

      final arKeys = arJson.keys.where((k) => !k.startsWith('@')).toSet();
      final enKeys = enJson.keys.where((k) => !k.startsWith('@')).toSet();

      expect(arKeys, equals(enKeys));

      // Verify specific new required keys exist
      expect(arKeys.contains('backupDataUpdatedSnackbar'), isTrue);
      expect(arKeys.contains('backupConflictDialogTitle'), isTrue);
      expect(arKeys.contains('backupConflictDialogBody'), isTrue);
      expect(arKeys.contains('backupConflictKeepLocal'), isTrue);
      expect(arKeys.contains('backupConflictKeepCloud'), isTrue);
    });

    testWidgets('9. pulse schedule: 3s for 30s after foreground/save, then 20s thereafter with fake clock', (tester) async {
      var simulatedTime = DateTime(2026, 1, 1, 12, 0, 0);
      DateTime fakeClock() => simulatedTime;

      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: true,
        clock: fakeClock,
      );
      await tester.pump();

      // Initially in fast pulse window (3s interval)
      expect(controller.isAppForeground, isTrue);
      expect(controller.isFastPulse, isTrue);
      expect(controller.currentPulseInterval, const Duration(seconds: 3));

      // Advance 3s -> first pulse tick
      simulatedTime = simulatedTime.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(fakeRemote.getMetaCalls, 1);
      expect(controller.isFastPulse, isTrue);

      // Advance another 27s (total 30s elapsed from start)
      // Pulses at 6s, 9s, 12s, 15s, 18s, 21s, 24s, 27s, 30s
      for (int i = 0; i < 9; i++) {
        simulatedTime = simulatedTime.add(const Duration(seconds: 3));
        await tester.pump(const Duration(seconds: 3));
      }
      expect(fakeRemote.getMetaCalls, 10);

      // After 30s has elapsed, fast pulse window has ended
      expect(controller.isFastPulse, isFalse);
      expect(controller.currentPulseInterval, const Duration(seconds: 20));

      // Advance 10s -> no new pulse should fire (interval is now 20s)
      simulatedTime = simulatedTime.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(fakeRemote.getMetaCalls, 10);

      // Advance another 10s (total 20s from previous pulse at t=30s)
      simulatedTime = simulatedTime.add(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 10));
      expect(fakeRemote.getMetaCalls, 11);

      // Advance another 20s -> fires next pulse at t=70s
      simulatedTime = simulatedTime.add(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 20));
      expect(fakeRemote.getMetaCalls, 12);
      expect(controller.isFastPulse, isFalse);

      // Local save occurs -> triggers fast pulse again
      controller.triggerFastPulse();
      expect(controller.isFastPulse, isTrue);
      expect(controller.currentPulseInterval, const Duration(seconds: 3));

      // Next pulse fires in 3s
      simulatedTime = simulatedTime.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(fakeRemote.getMetaCalls, 13);

      controller.dispose();
    });

    testWidgets('10. pulse stops completely in background and skips during upload/restore', (tester) async {
      var simulatedTime = DateTime(2026, 1, 1, 12, 0, 0);
      DateTime fakeClock() => simulatedTime;

      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: true,
        clock: fakeClock,
      );

      // Pulse fires at 3s
      simulatedTime = simulatedTime.add(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 3));
      expect(fakeRemote.getMetaCalls, 1);

      // Background app
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(controller.isAppForeground, isFalse);
      expect(controller.isPollingActive, isFalse);

      final callsBefore = fakeRemote.getMetaCalls;
      // In background, even if 100 seconds pass, zero reads occur!
      simulatedTime = simulatedTime.add(const Duration(seconds: 100));
      await tester.pump(const Duration(seconds: 100));
      expect(fakeRemote.getMetaCalls, equals(callsBefore));

      // App comes back to foreground
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(controller.isAppForeground, isTrue);
      expect(controller.isPollingActive, isTrue);
      expect(controller.isFastPulse, isTrue);

      // Verify chunks were never requested during any pulse checks
      expect(fakeRemote.storedChunks.isEmpty, isTrue);

      controller.dispose();
    });

    test('11. when receiving phone has unsynced flag set but local DB matches last hash, incoming changes are restored silently', () async {
      bool silentRestoreCalled = false;
      final controller = BackupSyncController(
        repository: repo,
        db: db,
        uid: testUid,
        enablePolling: false,
        onSilentRestoreSuccess: () {
          silentRestoreCalled = true;
        },
      );

      // 1. Initial state: calculate local hash and save as lastContentHash
      final initialSnapshot = await repo.exportSnapshot(db);
      final initialProcessed = isolateCompressAndChunk(initialSnapshot.toJson());
      controller.setLastContentHash(initialProcessed.contentHash);

      // 2. Simulate false positive flag (e.g. from background category notification)
      await controller.setHasUnsyncedLocalChanges(true);
      expect(controller.hasUnsyncedLocalChanges, isTrue);

      // 3. Remote snapshot arrives from Phone B with a new transaction
      final remoteSnapshot = BackupSnapshot(
        schemaVersion: db.schemaVersion,
        createdAt: DateTime.now().toUtc(),
        tables: {
          'categories': [
            {'id': 1, 'name': 'أكل', 'icon': 'food', 'color': '#4E8B7A', 'is_default': 1, 'is_archived': 0, 'sort_order': 1, 'created_by_ai': 0, 'created_at': 1716000000}
          ],
          'transactions': [
            {'id': 99, 'amount': 7500, 'description': 'قهوة على الطريق', 'category_id': 1, 'kind': 'expense', 'source': 'manual', 'created_at': 1716000000}
          ],
        },
      );
      fakeRemote.storeSnapshot(remoteSnapshot);

      await controller.handleRemoteMeta(fakeRemote.storedMeta!);

      // 4. Verify silent restore took place, transaction 99 is now in local DB, and flag is cleared
      expect(silentRestoreCalled, isTrue);
      expect(controller.hasUnsyncedLocalChanges, isFalse);
      final rows = await db.customSelect('SELECT * FROM transactions WHERE id = 99;').get();
      expect(rows, isNotEmpty);

      controller.dispose();
    });
  });
}
