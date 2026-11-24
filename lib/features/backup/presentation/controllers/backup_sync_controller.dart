import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/routing/app_router.dart';
import '../../data/repositories/backup_repository_impl.dart';
import '../../domain/exceptions/backup_exceptions.dart';
import '../../domain/models/backup_meta.dart';
import '../../domain/repositories/backup_repository.dart';
import '../widgets/backup_conflict_dialog.dart';

class BackupSyncController with WidgetsBindingObserver {
  final BackupRepository repository;
  final AppDatabase db;
  final String? uid;
  final DateTime Function() clock;

  Timer? _debounceTimer;
  Timer? _retryTimer;
  Timer? _remotePollTimer;
  StreamSubscription? _tableUpdatesSub;
  StreamSubscription? _remoteMetaSub;
  bool _hasPendingChanges = false;
  bool _hasUnsyncedLocalChanges = false;
  bool _isUploading = false;
  bool _isRestoring = false;
  bool _isExpenseScreenOpen = false;
  bool _isConflictDialogShowing = false;
  bool _isDisposed = false;
  bool _isPolling = false;
  bool _isAppForeground = true;
  DateTime? _fastPulseUntil;
  final bool enablePolling;

  bool get isRestoring => _isRestoring;
  bool get isUploading => _isUploading;
  bool get isExpenseScreenOpen => _isExpenseScreenOpen;
  bool get hasUnsyncedLocalChanges => _hasUnsyncedLocalChanges;
  bool get isAppForeground => _isAppForeground;
  bool get isPollingActive => _remotePollTimer != null && _remotePollTimer!.isActive;
  bool get isFastPulse => _fastPulseUntil != null && clock().isBefore(_fastPulseUntil!);
  Duration get currentPulseInterval => isFastPulse ? const Duration(seconds: 3) : const Duration(seconds: 20);
  DateTime? get fastPulseUntil => _fastPulseUntil;

  BackupMeta? _pendingRemoteMeta;
  DateTime? _lastUploadTime;
  int _dailyUploadCount = 0;
  String _dailyUploadDate = '';
  String? _lastContentHash;
  String? _observedRemoteHash;

  String? get lastContentHash => _lastContentHash;

  final void Function(DateTime? lastBackupTime)? onBackupSuccess;
  final void Function()? onSilentRestoreSuccess;
  final Future<ConflictResolution?> Function()? onConflictDetected;

  BackupSyncController({
    required this.repository,
    required this.db,
    required this.uid,
    this.enablePolling = true,
    this.clock = DateTime.now,
    this.onBackupSuccess,
    this.onSilentRestoreSuccess,
    this.onConflictDetected,
  }) {
    debugPrint('[BACKUP_SYNC] Initializing for uid: $uid');
    WidgetsBinding.instance.addObserver(this);
    if (enablePolling && uid != null) {
      _fastPulseUntil = clock().add(const Duration(seconds: 30));
    }
    _init();
  }

  Future<void> _init() async {
    await _initPreferences();
    _listenToDatabaseUpdates();
    _listenToRemoteUpdates();
    _startRemotePolling();
  }

  Future<void> _initPreferences() async {
    if (uid == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMs = prefs.getInt('backup_last_upload_time_$uid');
      if (lastMs != null) {
        _lastUploadTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
        onBackupSuccess?.call(_lastUploadTime);
      }
      _lastContentHash = prefs.getString('backup_last_content_hash_$uid');
      _dailyUploadDate = prefs.getString('backup_daily_date_$uid') ?? '';
      _dailyUploadCount = prefs.getInt('backup_daily_count_$uid') ?? 0;
      _hasUnsyncedLocalChanges =
          prefs.getBool('backup_has_unsynced_local_changes_$uid') ?? false;

      final todayStr = _formatToday();
      if (_dailyUploadDate != todayStr) {
        _dailyUploadDate = todayStr;
        _dailyUploadCount = 0;
        await prefs.setString('backup_daily_date_$uid', todayStr);
        await prefs.setInt('backup_daily_count_$uid', 0);
      }
    } catch (_) {
      // Ignore preferences errors silently
    }
  }

  Future<void> setHasUnsyncedLocalChanges(bool value) async {
    _hasUnsyncedLocalChanges = value;
    if (value) {
      triggerFastPulse();
    }
    if (uid != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('backup_has_unsynced_local_changes_$uid', value);
      } catch (_) {}
    }
  }

  @visibleForTesting
  void setLastContentHash(String? hash) {
    _lastContentHash = hash;
  }

  Future<void> setExpenseScreenOpen(bool isOpen) async {
    _isExpenseScreenOpen = isOpen;
    if (!isOpen && _pendingRemoteMeta != null && !_isUploading && !_isRestoring && !_isDisposed) {
      final pending = _pendingRemoteMeta;
      _pendingRemoteMeta = null;
      await _handleRemoteMeta(pending);
    }
  }

  void _listenToDatabaseUpdates() {
    _tableUpdatesSub = db.tableUpdates().listen((updates) async {
      // If table update was caused by a background auto-restore, do not trigger a re-upload!
      if (_isRestoring) return;
      final hasUserTable = updates.any(
        (u) => BackupRepositoryImpl.userTableNames.contains(u.table),
      );
      if (!hasUserTable && updates.isNotEmpty) return;

      // Ignore default categories seeding on empty database
      final onlyCategories = updates.every((u) => u.table == 'categories');
      if (onlyCategories) {
        final hasData = await repository.hasUserData(db);
        if (!hasData) return;
      }

      debugPrint('[BACKUP_SYNC] Local table update detected: $updates');
      _hasUnsyncedLocalChanges = true;
      await setHasUnsyncedLocalChanges(true);
      _hasPendingChanges = true;
      triggerFastPulse();
      _scheduleDebounce();
    });
  }

  void _listenToRemoteUpdates() {
    if (uid == null) return;
    _remoteMetaSub = repository.watchCloudBackupMeta(uid!).listen((remoteMeta) async {
      await _handleRemoteMeta(remoteMeta);
    });
  }

  @visibleForTesting
  Future<void> handleRemoteMeta(BackupMeta? remoteMeta) async {
    await _handleRemoteMeta(remoteMeta);
  }

  Future<void> _handleRemoteMeta(BackupMeta? remoteMeta) async {
    if (_isDisposed || remoteMeta == null || uid == null) return;

    debugPrint(
      '[BACKUP_SYNC] Remote meta received: chunkCount=${remoteMeta.chunkCount}, '
      'hash=${remoteMeta.contentHash}, lastHash=$_lastContentHash, '
      'unsyncedLocal=$_hasUnsyncedLocalChanges',
    );

    // 1. If remote content hash matches our own current hash, skip!
    if (remoteMeta.contentHash.isNotEmpty &&
        remoteMeta.contentHash == _lastContentHash) {
      debugPrint('[BACKUP_SYNC] Remote hash matches local hash ($_lastContentHash). Skipping.');
      return;
    }

    // 2. Lock check: Never restore while upload is running, while restoring,
    // or while the user is adding/editing an expense.
    if (_isUploading || _isRestoring || _isExpenseScreenOpen) {
      debugPrint(
        '[BACKUP_SYNC] Busy/locked (uploading=$_isUploading, restoring=$_isRestoring, '
        'expenseOpen=$_isExpenseScreenOpen). Queuing remote meta.',
      );
      _pendingRemoteMeta = remoteMeta;
      return;
    }

    final incomingHash = remoteMeta.contentHash;

    // 2.a) If hasUnsyncedLocalChanges is false: restore SILENTLY in the background,
    // with no dialog and no question, then show small non-blocking snackbar "تم تحديث بياناتك".
    if (!_hasUnsyncedLocalChanges) {
      final hasData = await repository.hasUserData(db);
      if (remoteMeta.chunkCount == 0 && (!hasData || _lastContentHash == null)) {
        return;
      }

      // If local DB is empty and user explicitly chose to start fresh / reset, do NOT restore!
      if (!hasData) {
        final prefs = await SharedPreferences.getInstance();
        final startFresh = prefs.getBool('backup_start_fresh_$uid') ?? false;
        if (startFresh) {
          debugPrint('[BACKUP_SYNC] Local DB is empty and backup_start_fresh is set. Skipping restore.');
          return;
        }
      }

      await _performSilentRestore(remoteMeta);
      return;
    }

    // 2.b) If hasUnsyncedLocalChanges is marked true, verify if local data actually differs
    final localSnapshot = await repository.exportSnapshot(db);
    final localProcessed = isolateCompressAndChunk(localSnapshot.toJson());

    // If local DB already matches incoming remote hash, clear flag and finish
    if (localProcessed.contentHash == incomingHash) {
      debugPrint('[BACKUP_SYNC] Local snapshot already matches incoming remote hash.');
      _lastContentHash = incomingHash;
      await setHasUnsyncedLocalChanges(false);
      _hasPendingChanges = false;
      return;
    }

    // If local DB actually has no real changes (matches last known hash), restore silently!
    if (localProcessed.contentHash == _lastContentHash) {
      debugPrint('[BACKUP_SYNC] Local snapshot has no real changes (matches last known hash). Restoring silently.');
      await setHasUnsyncedLocalChanges(false);
      await _performSilentRestore(remoteMeta);
      return;
    }

    // If hasUnsyncedLocalChanges is true and there are real local edits:
    // First try to upload the local snapshot (respecting the existing limits).
    // If the remote hash changed again meanwhile (a real conflict on two phones), show ONE dialog.
    if (_observedRemoteHash != null && _observedRemoteHash != incomingHash) {
      debugPrint('[BACKUP_SYNC] Remote hash changed again meanwhile ($_observedRemoteHash -> $incomingHash). Real conflict!');
      await _triggerConflictResolution(remoteMeta);
      return;
    }

    _observedRemoteHash = incomingHash;

    final uploadSuccess = await _triggerBackupInternal();

    if (!uploadSuccess && _hasUnsyncedLocalChanges) {
      final currentRemote = await repository.getCloudBackupMeta(uid!);
      if (currentRemote != null &&
          currentRemote.contentHash.isNotEmpty &&
          currentRemote.contentHash != incomingHash &&
          currentRemote.contentHash != _lastContentHash) {
        await _triggerConflictResolution(currentRemote);
      }
    }
  }

  Future<void> _performSilentRestore(BackupMeta remoteMeta) async {
    _isRestoring = true;
    try {
      debugPrint('[BACKUP_SYNC] Auto-restoring cloud snapshot (hash=${remoteMeta.contentHash})...');
      await repository.restoreBackup(
        uid: uid!,
        db: db,
        remoteMeta: remoteMeta,
      );

      _lastContentHash = remoteMeta.contentHash;
      _lastUploadTime = remoteMeta.updatedAt;
      await setHasUnsyncedLocalChanges(false);
      _hasPendingChanges = false;
      _observedRemoteHash = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'backup_last_upload_time_$uid',
        _lastUploadTime!.millisecondsSinceEpoch,
      );
      await prefs.setString('backup_last_content_hash_$uid', _lastContentHash!);

      onBackupSuccess?.call(_lastUploadTime);
      onSilentRestoreSuccess?.call();
      debugPrint('[BACKUP_SYNC] Auto-restore completed successfully!');
    } catch (e, st) {
      debugPrint('[BACKUP_SYNC_ERROR] Auto-restore failed: $e\n$st');
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      _isRestoring = false;

      if (_pendingRemoteMeta != null) {
        final pending = _pendingRemoteMeta;
        _pendingRemoteMeta = null;
        _handleRemoteMeta(pending);
      }
    }
  }

  Future<void> _triggerConflictResolution(BackupMeta remoteMeta) async {
    if (_isConflictDialogShowing) return;
    _isConflictDialogShowing = true;
    try {
      ConflictResolution? resolution;
      if (onConflictDetected != null) {
        resolution = await onConflictDetected!();
      } else {
        final context = rootNavigatorKey.currentContext;
        if (context != null && context.mounted) {
          resolution = await BackupConflictDialog.show(context);
        }
      }

      if (resolution == ConflictResolution.keepLocal) {
        await _forceUploadLocalSnapshot();
      } else if (resolution == ConflictResolution.keepCloud) {
        await _performSilentRestore(remoteMeta);
      }
    } finally {
      _isConflictDialogShowing = false;
      _observedRemoteHash = null;
    }
  }

  Future<void> _forceUploadLocalSnapshot() async {
    if (uid == null) return;
    _isUploading = true;
    try {
      final meta = await repository.uploadBackup(
        uid: uid!,
        db: db,
      );

      _lastContentHash = meta.contentHash;
      _lastUploadTime = clock();
      _dailyUploadCount++;
      await setHasUnsyncedLocalChanges(false);
      _hasPendingChanges = false;
      _observedRemoteHash = null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'backup_last_upload_time_$uid',
        _lastUploadTime!.millisecondsSinceEpoch,
      );
      await prefs.setString('backup_last_content_hash_$uid', _lastContentHash!);
      await prefs.setString('backup_daily_date_$uid', _dailyUploadDate);
      await prefs.setInt('backup_daily_count_$uid', _dailyUploadCount);

      onBackupSuccess?.call(_lastUploadTime);
      triggerFastPulse();
      debugPrint('[BACKUP_SYNC] Forced local upload SUCCEEDED! contentHash: ${meta.contentHash}');
    } catch (e, st) {
      debugPrint('[BACKUP_SYNC_ERROR] Forced upload failed: $e\n$st');
    } finally {
      _isUploading = false;
    }
  }

  Future<void> flush() async {
    _debounceTimer?.cancel();
    if (_hasPendingChanges || _hasUnsyncedLocalChanges) {
      await _triggerBackup();
    }
  }

  /// Handles full data reset: cancels timers, clears sync state, marks start fresh,
  /// and deletes the cloud backup from Firestore if online.
  Future<void> handleDataReset() async {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _pendingRemoteMeta = null;
    _lastContentHash = '';
    _hasPendingChanges = false;
    _isUploading = false;
    _isRestoring = false;

    await setHasUnsyncedLocalChanges(false);

    if (uid != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('backup_last_upload_time_$uid');
        await prefs.remove('backup_last_content_hash_$uid');
        await prefs.setBool('backup_start_fresh_$uid', true);
      } catch (_) {}

      try {
        await repository.deleteCloudBackup(uid!);
      } catch (_) {}
    }
  }

  void _scheduleDebounce() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _triggerBackup();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _isAppForeground = false;
      _stopRemotePolling();
      flush();
    } else if (state == AppLifecycleState.resumed) {
      _isAppForeground = true;
      if (uid != null && enablePolling) {
        triggerFastPulse();
        _pollRemoteMeta();
      }
    }
  }

  void _startRemotePolling() {
    if (!enablePolling || uid == null || !_isAppForeground || _isDisposed) return;
    triggerFastPulse();
  }

  void _stopRemotePolling() {
    _remotePollTimer?.cancel();
    _remotePollTimer = null;
  }

  void triggerFastPulse() {
    _fastPulseUntil = clock().add(const Duration(seconds: 30));
    if (!enablePolling || uid == null || !_isAppForeground || _isDisposed) {
      _stopRemotePolling();
      return;
    }
    _scheduleNextPulse(delay: const Duration(seconds: 3));
  }

  void _scheduleNextPulse({Duration? delay}) {
    if (!enablePolling || uid == null || !_isAppForeground || _isDisposed) {
      _stopRemotePolling();
      return;
    }
    _remotePollTimer?.cancel();
    final interval = delay ?? (isFastPulse ? const Duration(seconds: 3) : const Duration(seconds: 20));
    _remotePollTimer = Timer(interval, () async {
      if (_isDisposed || !_isAppForeground || uid == null) return;
      await _pollRemoteMeta();
      _scheduleNextPulse();
    });
  }

  Future<void> _pollRemoteMeta() async {
    if (_isDisposed ||
        _isPolling ||
        uid == null ||
        !_isAppForeground ||
        _isRestoring ||
        _isUploading ||
        _isExpenseScreenOpen) {
      return;
    }
    _isPolling = true;
    try {
      final remoteMeta = await repository.getCloudBackupMeta(uid!);
      if (_isDisposed || !_isAppForeground) return;
      if (remoteMeta != null &&
          remoteMeta.contentHash.isNotEmpty &&
          remoteMeta.contentHash != _lastContentHash) {
        debugPrint(
          '[BACKUP_SYNC] Live poll detected remote hash change: ${remoteMeta.contentHash} '
          '(current: $_lastContentHash)',
        );
        await _handleRemoteMeta(remoteMeta);
      }
    } catch (e) {
      debugPrint('[BACKUP_SYNC] Live poll check error: $e');
    } finally {
      _isPolling = false;
    }
  }

  String _formatToday() {
    final now = clock();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<bool> _canUploadNow() async {
    if (uid == null || _isUploading) return false;

    final todayStr = _formatToday();
    if (_dailyUploadDate != todayStr) {
      _dailyUploadDate = todayStr;
      _dailyUploadCount = 0;
    }
    if (_dailyUploadCount >= 500) {
      debugPrint('[BACKUP_SYNC] Daily upload limit (500) reached.');
      return false;
    }

    return true;
  }

  Future<bool> _triggerBackupInternal() async {
    if (_isDisposed || uid == null) return false;

    if (_isUploading) {
      debugPrint('[BACKUP_SYNC] Already uploading, marking changes pending.');
      _hasPendingChanges = true;
      return false;
    }

    if (_isRestoring) {
      debugPrint('[BACKUP_SYNC] Currently restoring, delaying upload.');
      _scheduleDebounce();
      return false;
    }

    if (!await _canUploadNow()) {
      return false;
    }

    // Safety check: NEVER upload snapshot of empty database while cloud backup exists
    final hasData = await repository.hasUserData(db);
    if (!hasData) {
      final backupExists = await repository.hasCloudBackup(uid!);
      if (backupExists) {
        final prefs = await SharedPreferences.getInstance();
        final decisionMade = prefs.getBool('backup_start_fresh_$uid') ?? false;
        if (!decisionMade) {
          debugPrint('[BACKUP_SYNC] Skipping upload: empty local DB while cloud backup exists and decision not made');
          return false;
        }
      }
    }

    _isUploading = true;
    _hasPendingChanges = false;

    try {
      debugPrint('[BACKUP_SYNC] Uploading snapshot (knownHash: $_lastContentHash)...');
      final meta = await repository.uploadBackup(
        uid: uid!,
        db: db,
        knownContentHash: _lastContentHash,
      );

      if (meta.contentHash == _lastContentHash) {
        debugPrint('[BACKUP_SYNC] Content hash identical, skipped remote upload: ${meta.contentHash}');
        await setHasUnsyncedLocalChanges(false);
        _hasPendingChanges = false;
      } else {
        debugPrint('[BACKUP_SYNC] Upload SUCCEEDED! contentHash: ${meta.contentHash}');
        _lastContentHash = meta.contentHash;
        _lastUploadTime = clock();
        _dailyUploadCount++;
        await setHasUnsyncedLocalChanges(false);
        _observedRemoteHash = null;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'backup_last_upload_time_$uid',
          _lastUploadTime!.millisecondsSinceEpoch,
        );
        await prefs.setString('backup_last_content_hash_$uid', _lastContentHash!);
        await prefs.setString('backup_daily_date_$uid', _dailyUploadDate);
        await prefs.setInt('backup_daily_count_$uid', _dailyUploadCount);

        onBackupSuccess?.call(_lastUploadTime);
        triggerFastPulse();
      }
      return true;
    } on EmptyDatabaseOverwriteException {
      debugPrint('[BACKUP_SYNC] Prevented overwriting cloud backup with empty database');
      return false;
    } catch (e, st) {
      debugPrint('[BACKUP_SYNC_ERROR] Upload failed: $e\n$st');
      _hasPendingChanges = true;
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 3), () {
        if (_hasPendingChanges || _hasUnsyncedLocalChanges) {
          _triggerBackup();
        }
      });
      return false;
    } finally {
      _isUploading = false;

      if (_hasPendingChanges) {
        _scheduleDebounce();
      }

      if (_pendingRemoteMeta != null) {
        final pending = _pendingRemoteMeta;
        _pendingRemoteMeta = null;
        _handleRemoteMeta(pending);
      }
    }
  }

  Future<void> _triggerBackup() async {
    await _triggerBackupInternal();
  }

  void dispose() {
    _isDisposed = true;
    _stopRemotePolling();
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _tableUpdatesSub?.cancel();
    _tableUpdatesSub = null;
    _remoteMetaSub?.cancel();
    _remoteMetaSub = null;
  }
}
