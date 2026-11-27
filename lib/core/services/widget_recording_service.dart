import 'package:flutter/services.dart';

/// Service that communicates with the native Android widget channel.
///
/// When the user records from the home screen widget, the audio file path
/// is stored natively (SharedPreferences + pointer file). When the app opens,
/// [checkWidgetPendingAudio] is called to retrieve and process the file.
class WidgetRecordingService {
  static const _channel = MethodChannel('com.mohamedibrahim.baqy/widget');
  static void Function(String path)? _onAudioReadyCallback;

  /// Registers a callback to receive instant notification when widget recording stops.
  static void setAudioReadyHandler(void Function(String path) handler) {
    _onAudioReadyCallback = handler;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onWidgetAudioReady') {
        final path = call.arguments as String?;
        if (path != null && path.isNotEmpty) {
          _onAudioReadyCallback?.call(path);
        }
      }
    });
  }

  /// Returns the audio file path recorded by the widget, or null if none.
  /// Also clears the native pending state so we don't process it twice.
  static Future<String?> checkWidgetPendingAudio() async {
    try {
      final path = await _channel.invokeMethod<String?>('getWidgetPendingAudioPath');
      if (path != null && path.isNotEmpty) {
        return path;
      }
    } catch (_) {}
    return null;
  }

  /// Tells the native side that Flutter finished processing the widget recording.
  static Future<void> clearWidgetPendingAudio() async {
    try {
      await _channel.invokeMethod<void>('clearWidgetPendingAudio');
    } catch (_) {}
  }

  /// Returns true if there is a pending widget recording waiting to be processed.
  static Future<bool> hasWidgetPendingRecording() async {
    try {
      return await _channel.invokeMethod<bool>('hasWidgetPendingRecording') ?? false;
    } catch (_) {
      return false;
    }
  }
}
