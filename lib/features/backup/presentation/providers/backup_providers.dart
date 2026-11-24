import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
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
    final uid = ref.watch(activeUserIdProvider);
    if (uid != null) {
      _loadFromPrefs(uid);
    }
    return null;
  }

  Future<void> _loadFromPrefs(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt('backup_last_upload_time_$uid');
      if (lastMs != null) {
        update(DateTime.fromMillisecondsSinceEpoch(lastMs));
      }
    } catch (_) {}
  }

  void update(DateTime? time) {
    if (state == time) return;
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks ||
        binding.schedulerPhase == SchedulerPhase.midFrameMicrotasks) {
      binding.addPostFrameCallback((_) {
        state = time;
      });
    } else {
      state = time;
    }
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
    onSilentRestoreSuccess: () {
      final context = rootNavigatorKey.currentContext;
      if (context != null && context.mounted) {
        final l10n = AppLocalizations.of(context);
        final msg = l10n?.backupDataUpdatedSnackbar ?? 'تم تحديث بياناتك';
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: const TextStyle(fontFamily: AppTheme.fontFamily),
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    },
  );

  ref.onDispose(() => controller.dispose());
  return controller;
});
