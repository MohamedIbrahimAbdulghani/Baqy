import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/models/backup_meta.dart';
import '../../domain/repositories/backup_repository.dart';

class BackupSyncController with WidgetsBindingObserver {
  final BackupRepository repository;
  final AppDatabase db;
  final String? uid;

  Timer? _debounceTimer;
  Timer? _retryTimer;
  StreamSubscription? _tableUpdatesSub;
  StreamSubscription? _remoteMetaSub;
  bool _hasPendingChanges = false;
  bool _isUploading = false;
  bool _isRestoring = false;
  BackupMeta? _pendingRemoteMeta;
  DateTime? _lastUploadTime;
  int _dailyUploadCount = 0;
  String _dailyUploadDate = '';
  String? _lastContentHash;

  final void Function(DateTime? lastBackupTime)? onBackupSuccess;

  BackupSyncController({
    required this.repository,
    required this.db,
    required this.uid,
    this.onBackupSuccess,
  }) {
    debugPrint('[BACKUP_SYNC] Initializing for uid: $uid');
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await _initPreferences();
    _listenToDatabaseUpdates();
    _listenToRemoteUpdates();
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

  void _listenToDatabaseUpdates() {
    _tableUpdatesSub = db.tableUpdates().listen((updates) {
      // If table update was caused by a background auto-restore, do not trigger a re-upload!
      if (_isRestoring) return;
      debugPrint('[BACKUP_SYNC] Local table update detected: $updates');
      _hasPendingChanges = true;
      _scheduleDebounce();
    });
  }

  void _listenToRemoteUpdates() {
    if (uid == null) return;
    _remoteMetaSub = repository.watchCloudBackupMeta(uid!).listen((remoteMeta) async {
      await _handleRemoteMeta(remoteMeta);
    });
  }

  Future<void> _handleRemoteMeta(BackupMeta? remoteMeta) async {
    if (remoteMeta == null) return;

    debugPrint('[BACKUP_SYNC] Remote meta received: chunkCount=${remoteMeta.chunkCount}, hash=${remoteMeta.contentHash}, lastHash=$_lastContentHash');

    if (_isUploading || _isRestoring) {
      debugPrint('[BACKUP_SYNC] Busy (uploading=$_isUploading, restoring=$_isRestoring). Queuing remote meta.');
      _pendingRemoteMeta = remoteMeta;
      return;
    }

    // 1. If remote content hash matches our own current hash, skip!
    if (remoteMeta.contentHash.isNotEmpty && remoteMeta.contentHash == _lastContentHash) {
      debugPrint('[BACKUP_SYNC] Remote hash matches local hash ($_lastContentHash). Skipping restore.');
      return;
    }

    // 2. Check if local database already has data
    final hasData = await repository.hasUserData(db);

    if (hasData) {
      // If we have local uncommitted changes waiting to be uploaded, do NOT overwrite them!
      // Trigger an immediate upload instead to push our changes.
      if (_hasPendingChanges) {
        debugPrint('[BACKUP_SYNC] Local pending changes present, prioritizing local upload.');
        _triggerBackup();
        return;
      }

      // If local database has data but this is a fresh login (_lastContentHash is null):
      // Don't restore if remote backup is empty.
      if (remoteMeta.chunkCount == 0) return;
    } else {
      // Local database is completely empty: only restore if a valid backup exists
      if (remoteMeta.chunkCount == 0) return;
    }

    // Snapshot uploaded from another device OR local database is empty -> auto-restore instantly
    _isRestoring = true;
    try {
      debugPrint('[BACKUP_SYNC] Auto-restoring cloud snapshot (hasLocalData=$hasData, hash=${remoteMeta.contentHash})...');
      await repository.restoreBackup(
        uid: uid!,
        db: db,
        remoteMeta: remoteMeta,
      );
      _lastContentHash = remoteMeta.contentHash;
      _lastUploadTime = remoteMeta.updatedAt;
      _hasPendingChanges = false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('backup_last_upload_time_$uid', _lastUploadTime!.millisecondsSinceEpoch);
      await prefs.setString('backup_last_content_hash_$uid', _lastContentHash!);

      onBackupSuccess?.call(_lastUploadTime);
      debugPrint('[BACKUP_SYNC] Auto-restore completed successfully!');
    } catch (e, st) {
      debugPrint('[BACKUP_SYNC_ERROR] Auto-restore failed: $e\n$st');
    } finally {
      _isRestoring = false;

      // If another remote meta update arrived while restoring, process it now
      if (_pendingRemoteMeta != null) {
        final pending = _pendingRemoteMeta;
        _pendingRemoteMeta = null;
        _handleRemoteMeta(pending);
      }
    }
  }

  Future<void> flush() async {
    _debounceTimer?.cancel();
    if (_hasPendingChanges) {
      await _triggerBackup();
    }
  }

  void _scheduleDebounce() {
    _debounceTimer?.cancel();
    // 1-second debounce for snappy live synchronization across devices
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () {
      _triggerBackup();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      flush();
    }
  }

  String _formatToday() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<bool> _canUploadNow() async {
    if (uid == null || _isUploading) return false;

    // Generous rate limit: at most 500 uploads per day
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

  Future<void> _triggerBackup() async {
    if (uid == null) return;

    if (_isUploading) {
      debugPrint('[BACKUP_SYNC] Already uploading, marking changes pending.');
      _hasPendingChanges = true;
      return;
    }

    if (_isRestoring) {
      debugPrint('[BACKUP_SYNC] Currently restoring, delaying upload.');
      _scheduleDebounce();
      return;
    }

    if (!await _canUploadNow()) {
      return;
    }

    // Safety check: NEVER upload snapshot of empty database while cloud backup exists
    final hasData = await repository.hasUserData(db);
    final backupExists = await repository.hasCloudBackup(uid!);
    debugPrint('[BACKUP_SYNC] _triggerBackup: hasData=$hasData, backupExists=$backupExists');
    if (!hasData && backupExists) {
      final prefs = await SharedPreferences.getInstance();
      final decisionMade = prefs.getBool('backup_start_fresh_$uid') ?? false;
      if (!decisionMade) {
        debugPrint('[BACKUP_SYNC] Skipping upload: empty local DB while cloud backup exists and decision not made');
        return;
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
      } else {
        debugPrint('[BACKUP_SYNC] Upload SUCCEEDED! contentHash: ${meta.contentHash}');
        _lastContentHash = meta.contentHash;
        _lastUploadTime = DateTime.now();
        _dailyUploadCount++;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('backup_last_upload_time_$uid', _lastUploadTime!.millisecondsSinceEpoch);
        await prefs.setString('backup_last_content_hash_$uid', _lastContentHash!);
        await prefs.setString('backup_daily_date_$uid', _dailyUploadDate);
        await prefs.setInt('backup_daily_count_$uid', _dailyUploadCount);

        onBackupSuccess?.call(_lastUploadTime);
      }
    } catch (e, st) {
      debugPrint('[BACKUP_SYNC_ERROR] Upload failed: $e\n$st');
      _hasPendingChanges = true;
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 30), () {
        if (_hasPendingChanges) {
          _triggerBackup();
        }
      });
    } finally {
      _isUploading = false;

      // If new local changes occurred while uploading, schedule upload immediately
      if (_hasPendingChanges) {
        _scheduleDebounce();
      }

      // If a remote meta update arrived while uploading, process it now
      if (_pendingRemoteMeta != null) {
        final pending = _pendingRemoteMeta;
        _pendingRemoteMeta = null;
        _handleRemoteMeta(pending);
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _tableUpdatesSub?.cancel();
    _remoteMetaSub?.cancel();
  }
}
