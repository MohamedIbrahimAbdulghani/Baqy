import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart' show TableUpdate;
import '../../../../core/database/app_database.dart';
import '../../../../core/services/notification_service.dart';
import '../../../debts/domain/models/debt_item.dart';
import '../../../reminders/domain/models/reminder_item.dart';
import '../../domain/exceptions/backup_exceptions.dart';
import '../../domain/models/backup_meta.dart';
import '../../domain/models/backup_snapshot.dart';
import '../../domain/repositories/backup_repository.dart';
import '../datasources/backup_remote_data_source.dart';

const int kMaxChunkSizeBytes = 700 * 1024; // 700 KB per chunk

class ProcessedBackupData {
  final String contentHash;
  final List<Uint8List> chunks;
  final Map<String, int> tableCounts;

  const ProcessedBackupData({
    required this.contentHash,
    required this.chunks,
    required this.tableCounts,
  });
}

/// Top-level function for background isolate compression & chunking
ProcessedBackupData isolateCompressAndChunk(Map<String, dynamic> rawJson) {
  final jsonString = jsonEncode(rawJson, toEncodable: (nonEncodable) {
    if (nonEncodable is DateTime) {
      return nonEncodable.toUtc().toIso8601String();
    }
    return nonEncodable.toString();
  });
  final uncompressedBytes = utf8.encode(jsonString);
  final contentHash = sha256.convert(uncompressedBytes).toString();

  final compressedBytes = Uint8List.fromList(gzip.encode(uncompressedBytes));

  final chunks = <Uint8List>[];
  int offset = 0;
  while (offset < compressedBytes.length) {
    final end = (offset + kMaxChunkSizeBytes < compressedBytes.length)
        ? offset + kMaxChunkSizeBytes
        : compressedBytes.length;
    chunks.add(Uint8List.sublistView(compressedBytes, offset, end));
    offset = end;
  }

  if (chunks.isEmpty) {
    chunks.add(Uint8List(0));
  }

  final tablesMap = rawJson['tables'] as Map<String, dynamic>? ?? {};
  final tableCounts = <String, int>{};
  tablesMap.forEach((k, v) {
    tableCounts[k] = (v is List) ? v.length : 0;
  });

  return ProcessedBackupData(
    contentHash: contentHash,
    chunks: chunks,
    tableCounts: tableCounts,
  );
}

/// Top-level function for background isolate reassembly, decompression & verification
BackupSnapshot _isolateReassembleAndDecompress(({List<Uint8List> chunks, String expectedHash}) args) {
  final totalLength = args.chunks.fold<int>(0, (sum, c) => sum + c.length);
  final combined = Uint8List(totalLength);
  int offset = 0;
  for (final chunk in args.chunks) {
    combined.setRange(offset, offset + chunk.length, chunk);
    offset += chunk.length;
  }

  final decompressedBytes = gzip.decode(combined);
  final jsonString = utf8.decode(decompressedBytes);

  final calculatedHash = sha256.convert(utf8.encode(jsonString)).toString();
  if (calculatedHash != args.expectedHash) {
    throw const CorruptedBackupException('Content hash mismatch between chunks and meta');
  }

  final json = jsonDecode(jsonString) as Map<String, dynamic>;
  return BackupSnapshot.fromJson(json);
}

class BackupRepositoryImpl implements BackupRepository {
  final BackupRemoteDataSource _remoteDataSource;

  static const List<String> userTableNames = [
    'categories',
    'transactions',
    'user_rules',
    'month_budgets',
    'goals',
    'goal_savings',
    'reminders',
    'debts',
    'debt_payments',
  ];

  BackupRepositoryImpl(this._remoteDataSource);

  @override
  Future<BackupSnapshot> exportSnapshot(AppDatabase db) async {
    final tables = <String, List<Map<String, dynamic>>>{};

    for (final table in userTableNames) {
      final rows = await db.customSelect('SELECT * FROM $table;').get();
      tables[table] = rows.map((r) => Map<String, dynamic>.from(r.data)).toList();
    }

    return BackupSnapshot(
      schemaVersion: db.schemaVersion,
      createdAt: DateTime.now().toUtc(),
      tables: tables,
    );
  }

  @override
  Future<bool> hasUserData(AppDatabase db) async {
    // Check if any non-default data exists
    final txRow = await db.customSelect('SELECT COUNT(*) AS c FROM transactions;').getSingle();
    if ((txRow.data['c'] as num? ?? 0) > 0) return true;

    final goalsRow = await db.customSelect('SELECT COUNT(*) AS c FROM goals;').getSingle();
    if ((goalsRow.data['c'] as num? ?? 0) > 0) return true;

    final budgetsRow = await db.customSelect('SELECT COUNT(*) AS c FROM month_budgets;').getSingle();
    if ((budgetsRow.data['c'] as num? ?? 0) > 0) return true;

    final remindersRow = await db.customSelect('SELECT COUNT(*) AS c FROM reminders;').getSingle();
    if ((remindersRow.data['c'] as num? ?? 0) > 0) return true;

    final debtsRow = await db.customSelect('SELECT COUNT(*) AS c FROM debts;').getSingle();
    if ((debtsRow.data['c'] as num? ?? 0) > 0) return true;

    final rulesRow = await db.customSelect('SELECT COUNT(*) AS c FROM user_rules;').getSingle();
    if ((rulesRow.data['c'] as num? ?? 0) > 0) return true;

    // Check custom categories or changed category counts
    final customCats = await db.customSelect('SELECT COUNT(*) AS c FROM categories WHERE is_default = 0;').getSingle();
    if ((customCats.data['c'] as num? ?? 0) > 0) return true;

    final allCats = await db.customSelect('SELECT COUNT(*) AS c FROM categories;').getSingle();
    if ((allCats.data['c'] as num? ?? 0) != AppDatabase.defaultCategoryDefinitions.length) return true;

    return false;
  }

  @override
  Future<BackupMeta?> getCloudBackupMeta(String uid) async {
    return _remoteDataSource.getMeta(uid);
  }

  @override
  Stream<BackupMeta?> watchCloudBackupMeta(String uid) {
    return _remoteDataSource.watchMeta(uid);
  }

  @override
  Future<bool> hasCloudBackup(String uid) async {
    final meta = await _remoteDataSource.getMeta(uid);
    return meta != null && meta.chunkCount > 0;
  }

  @override
  Future<BackupMeta> uploadBackup({
    required String uid,
    required AppDatabase db,
    String? knownContentHash,
  }) async {
    final hasData = await hasUserData(db);
    final cloudMeta = await _remoteDataSource.getMeta(uid);
    final backupExists = cloudMeta != null && cloudMeta.chunkCount > 0;

    // Rule: NEVER upload snapshot of an empty database if a cloud backup exists!
    if (!hasData && backupExists) {
      throw const EmptyDatabaseOverwriteException();
    }

    final snapshot = await exportSnapshot(db);
    final jsonMap = snapshot.toJson();

    // Run heavy compression & chunking in a background isolate via compute
    final processed = await compute(isolateCompressAndChunk, jsonMap);

    final meta = BackupMeta(
      schemaVersion: snapshot.schemaVersion,
      chunkCount: processed.chunks.length,
      updatedAt: DateTime.now().toUtc(),
      tableCounts: processed.tableCounts,
      contentHash: processed.contentHash,
    );

    // Skip network upload if content has not changed compared to known hash
    if (knownContentHash != null && meta.contentHash == knownContentHash) {
      return meta;
    }

    await _remoteDataSource.uploadBackup(
      uid: uid,
      meta: meta,
      chunks: processed.chunks,
    );

    return meta;
  }

  @override
  Future<void> restoreBackup({
    required String uid,
    required AppDatabase db,
    BackupMeta? remoteMeta,
  }) async {
    try {
      final meta = remoteMeta ?? await _remoteDataSource.getMeta(uid);
      if (meta == null || meta.chunkCount == 0) {
        throw const BackupNotFoundException();
      }

      final chunks = await _remoteDataSource.getChunks(uid, meta.chunkCount);
      if (chunks.length != meta.chunkCount) {
        throw const CorruptedBackupException('Chunk count mismatch');
      }

      // Reassemble, decompress, and verify SHA-256 in isolate via compute
      final snapshot = await compute(
        _isolateReassembleAndDecompress,
        (chunks: chunks, expectedHash: meta.contentHash),
      );

      await restoreFromSnapshot(snapshot: snapshot, db: db);
    } catch (e, st) {
      debugPrint('[BACKUP_REPO_ERROR] restoreBackup failed: $e\n$st');
      rethrow;
    }
  }

  @override
  Future<void> restoreFromSnapshot({
    required BackupSnapshot snapshot,
    required AppDatabase db,
  }) async {
    // 1. Check schemaVersion
    if (snapshot.schemaVersion > db.schemaVersion) {
      throw NewerSchemaVersionException(
        snapshotVersion: snapshot.schemaVersion,
        currentVersion: db.schemaVersion,
      );
    }

    // 2. Perform restore in ONE database transaction
    await db.transaction(() async {
      // Delete in topological dependency order (children first)
      await db.customStatement('DELETE FROM debt_payments;');
      await db.customStatement('DELETE FROM debts;');
      await db.customStatement('DELETE FROM reminders;');
      await db.customStatement('DELETE FROM goal_savings;');
      await db.customStatement('DELETE FROM goals;');
      await db.customStatement('DELETE FROM month_budgets;');
      await db.customStatement('DELETE FROM user_rules;');
      await db.customStatement('DELETE FROM transactions;');
      await db.customStatement('DELETE FROM categories;');

      // Insert order (parents first)
      const insertOrder = [
        'categories',
        'month_budgets',
        'transactions',
        'user_rules',
        'goals',
        'goal_savings',
        'reminders',
        'debts',
        'debt_payments',
      ];

      for (final tableName in insertOrder) {
        final rows = snapshot.tables[tableName] ?? [];
        if (rows.isEmpty) continue;

        // Inspect existing schema columns for this table
        final colInfo = await db.customSelect("PRAGMA table_info('$tableName');").get();
        final existingCols = <String, ({bool notNull, String? dfltValue, bool isPk})>{};
        for (final row in colInfo) {
          final colName = row.data['name'] as String;
          final notNull = (row.data['notnull'] as num? ?? 0) == 1;
          final dflt = row.data['dflt_value'] as String?;
          final isPk = (row.data['pk'] as num? ?? 0) == 1;
          existingCols[colName] = (notNull: notNull, dfltValue: dflt, isPk: isPk);
        }

        for (final row in rows) {
          // Check for missing required columns
          for (final entry in existingCols.entries) {
            final col = entry.key;
            final info = entry.value;
            if (info.notNull && info.dfltValue == null && !info.isPk) {
              if (!row.containsKey(col) || row[col] == null) {
                throw CorruptedBackupException(
                  'Missing required column $col in table $tableName',
                );
              }
            }
          }

          // Build parameterized query for columns present in existing schema
          final insertKeys = <String>[];
          final insertValues = <dynamic>[];

          for (final key in row.keys) {
            if (existingCols.containsKey(key)) {
              insertKeys.add(key);
              insertValues.add(row[key]);
            }
          }

          if (insertKeys.isNotEmpty) {
            final colNames = insertKeys.join(', ');
            final placeholders = List.filled(insertKeys.length, '?').join(', ');
            await db.customStatement(
              'INSERT INTO $tableName ($colNames) VALUES ($placeholders);',
              insertValues,
            );
          }
        }

        // Update sqlite_sequence so auto-generated ids continue after highest id
        final hasIdCol = existingCols.containsKey('id');
        if (hasIdCol) {
          final maxRow = await db.customSelect('SELECT MAX(id) AS m FROM $tableName;').getSingle();
          final maxId = maxRow.data['m'] as int?;
          if (maxId != null) {
            try {
              await db.customStatement(
                'INSERT OR REPLACE INTO sqlite_sequence (name, seq) VALUES (?, ?);',
                [tableName, maxId],
              );
            } catch (_) {
              // sqlite_sequence might not be created yet if no autoincrement rows were inserted
            }
          }
        }
      }
    });

    // 3. Notify Drift of table updates for all 9 tables so reactive UI updates immediately
    db.notifyUpdates({
      TableUpdate.onTable(db.categories),
      TableUpdate.onTable(db.transactions),
      TableUpdate.onTable(db.userRules),
      TableUpdate.onTable(db.monthBudgets),
      TableUpdate.onTable(db.goals),
      TableUpdate.onTable(db.goalSavings),
      TableUpdate.onTable(db.reminders),
      TableUpdate.onTable(db.debts),
      TableUpdate.onTable(db.debtPayments),
    });

    // 4. Reschedule all reminders and debts notifications with existing notification code
    try {
      final reminderRows = await db.customSelect('SELECT * FROM reminders;').get();
      final reminderItems = reminderRows.map((r) {
        final d = r.data;
        DateTime dueDate;
        final rawDue = d['due_date'];
        if (rawDue is int) {
          dueDate = DateTime.fromMillisecondsSinceEpoch(rawDue * 1000, isUtc: true);
        } else if (rawDue is DateTime) {
          dueDate = rawDue;
        } else {
          dueDate = DateTime.now();
        }

        return ReminderItem(
          id: d['id'] as int,
          name: d['name'] as String,
          amount: d['amount'] as int,
          dueDate: dueDate,
          repeat: d['repeat'] as String? ?? 'once',
          leadDays: d['lead_days'] as int? ?? 2,
        );
      }).toList();
      await NotificationService.instance.rescheduleReminders(reminderItems);

      final debtRows = await db.customSelect('SELECT * FROM debts;').get();
      final paymentRows = await db.customSelect('SELECT * FROM debt_payments;').get();

      final paymentsByDebt = <int, List<Map<String, dynamic>>>{};
      for (final p in paymentRows) {
        final dId = p.data['debt_id'] as int;
        paymentsByDebt.putIfAbsent(dId, () => []).add(p.data);
      }

      final debtItems = debtRows.map((dr) {
        final d = dr.data;
        final dId = d['id'] as int;
        final payments = paymentsByDebt[dId] ?? [];
        final paidAmount = payments.fold<int>(0, (sum, p) => sum + (p['amount'] as int? ?? 0));

        DateTime? dueDate;
        final rawDue = d['due_date'];
        if (rawDue is int) {
          dueDate = DateTime.fromMillisecondsSinceEpoch(rawDue * 1000, isUtc: true);
        } else if (rawDue is DateTime) {
          dueDate = rawDue;
        }

        DateTime createdAt;
        final rawCreated = d['created_at'];
        if (rawCreated is int) {
          createdAt = DateTime.fromMillisecondsSinceEpoch(rawCreated * 1000, isUtc: true);
        } else if (rawCreated is DateTime) {
          createdAt = rawCreated;
        } else {
          createdAt = DateTime.now();
        }

        return DebtItem(
          id: dId,
          personName: d['person_name'] as String,
          direction: d['direction'] as String,
          totalAmount: d['total_amount'] as int,
          dueDate: dueDate,
          leadDays: d['lead_days'] as int? ?? 2,
          reminderEnabled: (d['reminder_enabled'] as num? ?? 0) == 1,
          archived: (d['archived'] as num? ?? 0) == 1,
          createdAt: createdAt,
          paidAmount: paidAmount,
          paymentsCount: payments.length,
        );
      }).toList();
      await NotificationService.instance.rescheduleDebts(debtItems);
    } catch (_) {
      // Notification rescheduling error should not prevent restore completion
    }
  }
}
