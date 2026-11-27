import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service responsible for receiving and handling Android app shortcuts.
///
/// Follows strict security rules:
/// - Accepts only the fixed action name [actionRecordVoice].
/// - Any unknown or missing action is ignored immediately.
/// - Never carries or logs financial data, audio, transcripts, or user identifiers.
class AppShortcutService {
  AppShortcutService._internal();
  static AppShortcutService instance = AppShortcutService._internal();

  @visibleForTesting
  static set testInstance(AppShortcutService service) {
    instance = service;
  }

  @visibleForTesting
  AppShortcutService.test();

  static const String channelName = 'com.mohamedibrahim.baqy/shortcut';
  static const String actionRecordVoice = 'record_voice';

  MethodChannel _channel = const MethodChannel(channelName);

  @visibleForTesting
  set channel(MethodChannel channel) {
    _channel = channel;
  }

  final StreamController<String> _actionController =
      StreamController<String>.broadcast();

  Stream<String> get actionStream => _actionController.stream;

  bool _isInitialized = false;

  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShortcutTriggered') {
        final action = call.arguments as String?;
        _handleAction(action);
      }
    });
  }

  /// Checks if the app was launched cold from an app shortcut.
  /// Consumes the action on the native side so it is returned at most once.
  Future<String?> checkInitialShortcut() async {
    try {
      final action = await _channel.invokeMethod<String>('getInitialShortcut');
      if (_isValidAction(action)) {
        return action;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SHORTCUT] Error checking initial shortcut: $e');
      }
    }
    return null;
  }

  void _handleAction(String? action) {
    if (_isValidAction(action)) {
      _actionController.add(action!);
    }
  }

  /// Security validation: only accept the fixed action name.
  bool _isValidAction(String? action) {
    return action == actionRecordVoice;
  }

  void dispose() {
    _actionController.close();
  }
}
