import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/backup_meta.dart';
import 'backup_remote_data_source.dart';

class FirestoreBackupRemoteDataSource implements BackupRemoteDataSource {
  final FirebaseFirestore _firestore;

  FirestoreBackupRemoteDataSource([FirebaseFirestore? firestore])
      : _firestore = firestore ?? FirebaseFirestore.instance {
    // Disable local Firestore cache as required: no unencrypted data stored outside encrypted DB
    try {
      _firestore.settings = const Settings(persistenceEnabled: false);
    } catch (_) {}
  }

  @override
  Future<BackupMeta?> getMeta(String uid) async {
    try {
      final docRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('backup')
          .doc('meta');

      final snapshot = await docRef.get().timeout(const Duration(seconds: 8));

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      final data = snapshot.data()!;
      DateTime parsedDate;
      final rawUpdated = data['updatedAt'];
      if (rawUpdated is Timestamp) {
        parsedDate = rawUpdated.toDate();
      } else if (rawUpdated is String) {
        parsedDate = DateTime.tryParse(rawUpdated) ?? DateTime.now();
      } else {
        parsedDate = DateTime.now();
      }

      final rawCounts = data['tableCounts'] as Map<String, dynamic>? ?? {};
      final tableCounts = rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

      return BackupMeta(
        schemaVersion: (data['schemaVersion'] as num?)?.toInt() ?? 0,
        chunkCount: (data['chunkCount'] as num?)?.toInt() ?? 0,
        updatedAt: parsedDate,
        tableCounts: tableCounts,
        contentHash: data['contentHash'] as String? ?? '',
      );
    } catch (e, st) {
      debugPrint('[FIRESTORE_REMOTE_ERROR] getMeta failed: $e\n$st');
      return null;
    }
  }

  @override
  Stream<BackupMeta?> watchMeta(String uid) {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('backup')
        .doc('meta');

    return docRef.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      final data = snapshot.data()!;
      DateTime parsedDate;
      final rawUpdated = data['updatedAt'];
      if (rawUpdated is Timestamp) {
        parsedDate = rawUpdated.toDate();
      } else if (rawUpdated is String) {
        parsedDate = DateTime.tryParse(rawUpdated) ?? DateTime.now();
      } else {
        parsedDate = DateTime.now();
      }

      final rawCounts = data['tableCounts'] as Map<String, dynamic>? ?? {};
      final tableCounts = rawCounts.map((k, v) => MapEntry(k, (v as num).toInt()));

      return BackupMeta(
        schemaVersion: (data['schemaVersion'] as num?)?.toInt() ?? 0,
        chunkCount: (data['chunkCount'] as num?)?.toInt() ?? 0,
        updatedAt: parsedDate,
        tableCounts: tableCounts,
        contentHash: data['contentHash'] as String? ?? '',
      );
    }).handleError((e, st) {
      debugPrint('[FIRESTORE_REMOTE_ERROR] watchMeta error: $e\n$st');
      return null;
    });
  }

  @override
  Future<List<Uint8List>> getChunks(String uid, int chunkCount) async {
    final backupCol =
        _firestore.collection('users').doc(uid).collection('backup');

    final docSnaps = await Future.wait([
      for (int i = 0; i < chunkCount; i++)
        backupCol.doc('chunk_$i').get().timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('Timed out fetching chunk_$i from Firestore'),
        ),
    ]);

    final chunks = <Uint8List>[];
    for (int i = 0; i < chunkCount; i++) {
      final docSnap = docSnaps[i];
      if (!docSnap.exists || docSnap.data() == null) {
        throw Exception('Missing chunk chunk_$i in Firestore');
      }
      final data = docSnap.data()!;
      final blob = data['data'];
      if (blob is Blob) {
        chunks.add(blob.bytes);
      } else if (blob is Uint8List) {
        chunks.add(blob);
      } else if (blob is List) {
        chunks.add(Uint8List.fromList(blob.cast<int>()));
      } else {
        throw Exception('Invalid chunk data format for chunk_$i: ${blob?.runtimeType}');
      }
    }

    return chunks;
  }

  @override
  Future<void> uploadBackup({
    required String uid,
    required BackupMeta meta,
    required List<Uint8List> chunks,
  }) async {
    final batch = _firestore.batch();
    final backupCol =
        _firestore.collection('users').doc(uid).collection('backup');

    // 1. Set meta document with server timestamp
    final metaRef = backupCol.doc('meta');
    batch.set(metaRef, {
      'schemaVersion': meta.schemaVersion,
      'chunkCount': chunks.length,
      'updatedAt': FieldValue.serverTimestamp(),
      'tableCounts': meta.tableCounts,
      'contentHash': meta.contentHash,
    });

    // 2. Set chunk documents
    for (int i = 0; i < chunks.length; i++) {
      final chunkRef = backupCol.doc('chunk_$i');
      batch.set(chunkRef, {
        'data': Blob(chunks[i]),
      });
    }

    // 3. Delete any potentially obsolete old chunks directly by id to respect security rules
    for (int i = chunks.length; i < chunks.length + 10; i++) {
      batch.delete(backupCol.doc('chunk_$i'));
    }

    // Commit all in ONE batched write
    try {
      debugPrint('[FIRESTORE_REMOTE] Committing batch for uid: $uid, chunks=${chunks.length}');
      await batch.commit();
      debugPrint('[FIRESTORE_REMOTE] Batch committed successfully!');
    } catch (e, st) {
      debugPrint('[FIRESTORE_REMOTE_ERROR] batch.commit failed: $e\n$st');
      rethrow;
    }
  }
}
