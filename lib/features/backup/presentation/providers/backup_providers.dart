import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../data/datasources/backup_remote_data_source.dart';
import '../../data/datasources/firestore_backup_remote_data_source.dart';
import '../../data/repositories/backup_repository_impl.dart';
import '../../domain/repositories/backup_repository.dart';
import '../controllers/backup_sync_controller.dart';

final backupRemoteDataSourceProvider = Provider<BackupRemoteDataSource>((ref) {
  return FirestoreBackupRemoteDataSource();
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  final remote = ref.watch(backupRemoteDataSourceProvider);
  return BackupRepositoryImpl(remote);
});

class LastBackupTimeNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() {
    _loadFromPrefs();
    return null;
  }

  Future<void> _loadFromPrefs() async {
    final uid = ref.watch(activeUserIdProvider);
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt('backup_last_upload_time_$uid');
      if (lastMs != null) {
        state = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }
    } catch (_) {}
  }

  void update(DateTime? time) {
    state = time;
  }
}

final lastBackupTimeProvider =
    NotifierProvider<LastBackupTimeNotifier, DateTime?>(LastBackupTimeNotifier.new);

final backupSyncControllerProvider = Provider<BackupSyncController?>((ref) {
  final uid = ref.watch(activeUserIdProvider);
  final db = ref.watch(appDatabaseProvider);
  final repo = ref.watch(backupRepositoryProvider);

  if (uid == null) return null;

  final controller = BackupSyncController(
    repository: repo,
    db: db,
    uid: uid,
    onBackupSuccess: (time) {
      ref.read(lastBackupTimeProvider.notifier).update(time);
    },
  );

  ref.onDispose(() => controller.dispose());
  return controller;
});
