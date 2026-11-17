import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service responsible for managing local push notifications and permissions.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'budget_alerts_channel';
  static const String channelName = 'تنبيهات الميزانية';
  static const String channelDescription =
      'إشعارات تنبيه اقتراب نفاد الميزانية الشهرية';

  /// Initializes notification settings for Android and iOS.
  Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Can route to budget sheet or details screen if needed
      },
    );

    // Create high-importance notification channel on Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
        playSound: true,
      );

      await androidImplementation?.createNotificationChannel(channel);
    }
  }

  /// Requests notification permissions for Android 13+ (API 33) and iOS.
  Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final bool? granted =
            await androidImplementation?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
            _notificationsPlugin.resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();
        final bool? granted = await iosImplementation?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NOTIFICATION_SERVICE] Error requesting permissions: $e');
      }
    }
    return true;
  }

  /// Dispatches an immediate local push notification warning that remaining budget is low.
  Future<void> showBudgetWarningNotification() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF4E8B7A),
      showWhen: true,
      enableVibration: true,
      playSound: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Show notification with the app name included in the title
    await _notificationsPlugin.show(
      101, // Constant ID for budget threshold warnings
      'تنبيه الميزانية - BAQY',
      'خد بالك انت قربت تخلص مصاريف الشهر ده',
      notificationDetails,
    );
  }
}
