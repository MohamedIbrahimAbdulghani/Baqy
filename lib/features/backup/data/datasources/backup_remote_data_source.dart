import 'dart:typed_data';
import '../../domain/models/backup_meta.dart';

abstract class BackupRemoteDataSource {
  /// Fetches backup metadata for [uid] with an 8-second timeout.
  Future<BackupMeta?> getMeta(String uid);

  /// Fetches [chunkCount] chunk documents for [uid].
  Future<List<Uint8List>> getChunks(String uid, int chunkCount);

  /// Streams real-time metadata changes for [uid] so other devices update instantaneously.
  Stream<BackupMeta?> watchMeta(String uid);

  /// Atomically writes [meta] and [chunks] in one WriteBatch and deletes old chunks.
  Future<void> uploadBackup({
    required String uid,
    required BackupMeta meta,
    required List<Uint8List> chunks,
  });
}
