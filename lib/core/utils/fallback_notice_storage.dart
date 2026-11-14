import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Manages daily local persistence for the fallback notice.
/// The notice is shown at most once per day when falling back to the local parser.
class FallbackNoticeStorage {
  static String? _inMemoryDate;

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static Future<File?> _getFile() async {
    try {
      final dir = await getApplicationDocumentsDirectory()
          .timeout(const Duration(milliseconds: 150));
      return File('${dir.path}/baqy_fallback_notice_date.txt');
    } catch (_) {
      try {
        final dir = await getTemporaryDirectory()
            .timeout(const Duration(milliseconds: 150));
        return File('${dir.path}/baqy_fallback_notice_date.txt');
      } catch (_) {
        return null;
      }
    }
  }

  /// Checks if notice should be shown today. Returns true if not yet shown today.
  static Future<bool> shouldShowNoticeToday([DateTime? now]) async {
    final today = _formatDate(now ?? DateTime.now());
    if (_inMemoryDate != null) {
      return _inMemoryDate != today;
    }
    final lastShown = await getLastShownDate();
    return lastShown != today;
  }

  /// Marks the notice as shown today.
  static Future<void> markNoticeShownToday([DateTime? now]) async {
    final today = _formatDate(now ?? DateTime.now());
    _inMemoryDate = today;
    try {
      final file = await _getFile();
      if (file != null) {
        await file.writeAsString(today);
      }
    } catch (_) {}
  }

  /// Retrieves the last date string (YYYY-MM-DD) the notice was shown.
  static Future<String?> getLastShownDate() async {
    if (_inMemoryDate != null) return _inMemoryDate;
    try {
      final file = await _getFile();
      if (file != null && await file.exists()) {
        _inMemoryDate = (await file.readAsString()).trim();
        return _inMemoryDate;
      }
    } catch (_) {}
    return null;
  }

  @visibleForTesting
  static void resetForTesting() {
    _inMemoryDate = null;
  }
}
