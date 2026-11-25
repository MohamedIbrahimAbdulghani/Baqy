import 'dart:async';
import 'dart:io';

typedef OnlineCheckerFn = Future<bool> Function();

abstract final class NetworkChecker {
  static OnlineCheckerFn? customChecker;

  /// Returns true if device has an active internet connection.
  static Future<bool> isOnline() async {
    if (customChecker != null) {
      return customChecker!();
    }
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
