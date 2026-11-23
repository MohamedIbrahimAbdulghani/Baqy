import '../../../../core/database/app_database.dart';
import '../models/backup_meta.dart';
import '../models/backup_snapshot.dart';

abstract class BackupRepository {
  /// Exports all 9 user tables into a BackupSnapshot.
  Future<BackupSnapshot> exportSnapshot(AppDatabase db);

  /// Checks if the database contains any user-created rows.
  Future<bool> hasUserData(AppDatabase db);

  /// Retrieves cloud backup metadata for [uid] with an 8-second timeout.
  Future<BackupMeta?> getCloudBackupMeta(String uid);

  /// Streams real-time metadata changes for [uid].
  Stream<BackupMeta?> watchCloudBackupMeta(String uid);

  /// Checks if a cloud backup exists for [uid].
  Future<bool> hasCloudBackup(String uid);

  /// Uploads a snapshot of [db] to Cloud Firestore under users/[uid]/backup.
  /// If [knownContentHash] matches the exported snapshot hash, skips network upload.
  Future<BackupMeta> uploadBackup({
    required String uid,
    required AppDatabase db,
    String? knownContentHash,
  });

  /// Restores cloud backup for [uid] into [db].
  /// If [remoteMeta] is provided, skips fetching metadata again from the network.
  Future<void> restoreBackup({
    required String uid,
    required AppDatabase db,
    BackupMeta? remoteMeta,
  });

  /// Restores a given [snapshot] directly into [db] in one database transaction.
  Future<void> restoreFromSnapshot({
    required BackupSnapshot snapshot,
    required AppDatabase db,
  });
}
