import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/reminders/domain/models/reminder_item.dart';
import '../../features/reminders/domain/utils/reminder_date_calculator.dart';

/// Service responsible for managing local push notifications, reminder scheduling, and permissions.
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  /// Visible constructor for unit testing
  @visibleForTesting
  NotificationService.test();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String budgetChannelId = 'budget_alerts_channel';
  static const String budgetChannelName = 'تنبيهات الميزانية';
  static const String budgetChannelDescription =
      'إشعارات تنبيه اقتراب نفاد الميزانية الشهرية';

  static const String remindersChannelId = 'reminders_channel';
  static const String remindersChannelName = 'المواعيد';
  static const String remindersChannelDescription =
      'إشعارات مواعيد الدفع والالتزامات';

  /// Navigation hook to open the desired tab (e.g. index 2 for Appointments/المواعيد)
  static void Function(int tabIndex)? onSelectTab;

  /// Holds tab index when app was launched from a notification before UI is ready
  static int? pendingTabSelection;

  /// Resets and returns the pending tab selection if any
  static int? consumePendingTabSelection() {
    final tab = pendingTabSelection;
    pendingTabSelection = null;
    return tab;
  }

  /// Initializes notification settings, timezone (Africa/Cairo), and channels.
  Future<void> initialize() async {
    // Initialize timezones for Africa/Cairo
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NOTIFICATION] Error setting Africa/Cairo location: $e');
      }
    }

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
        if (response.payload == 'reminders') {
          if (onSelectTab != null) {
            onSelectTab!(2);
          } else {
            pendingTabSelection = 2;
          }
        }
      },
    );

    // Check if app was launched directly by tapping a notification
    try {
      final launchDetails =
          await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails != null &&
          launchDetails.didNotificationLaunchApp &&
          launchDetails.notificationResponse?.payload == 'reminders') {
        pendingTabSelection = 2;
      }
    } catch (_) {}

    // Create notification channels on Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      const AndroidNotificationChannel budgetChannel =
          AndroidNotificationChannel(
        budgetChannelId,
        budgetChannelName,
        description: budgetChannelDescription,
        importance: Importance.high,
        playSound: true,
      );

      const AndroidNotificationChannel remindersChannel =
          AndroidNotificationChannel(
        remindersChannelId,
        remindersChannelName,
        description: remindersChannelDescription,
        importance: Importance.high,
        playSound: true,
      );

      await androidImplementation?.createNotificationChannel(budgetChannel);
      await androidImplementation?.createNotificationChannel(remindersChannel);
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

  /// Cancels notification for a specific reminder ID
  Future<void> cancelReminderNotification(int reminderId) async {
    try {
      await _notificationsPlugin.cancel(reminderId);
    } catch (_) {}
  }

  /// Reschedules all reminder notifications.
  /// Schedules only the next occurrence of each reminder.
  /// Uses inexact standard scheduling without exact alarm permissions.
  /// DEBUG ONLY (kDebugMode): prints one line with the number of scheduled notifications
  /// and, for each one, only its id and the scheduled date and time. Never print names or amounts.
  Future<void> rescheduleReminders(List<ReminderItem> reminders) async {
    final scheduledDetails = <({int id, DateTime dateTime})>[];
    tz.Location cairoLocation;
    try {
      tz.initializeTimeZones();
      cairoLocation = tz.getLocation('Africa/Cairo');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NOTIFICATION] Timezone not available for scheduling: $e');
      }
      return;
    }

    final nowInCairo = tz.TZDateTime.now(cairoLocation);
    final nowDateTime = DateTime(
      nowInCairo.year,
      nowInCairo.month,
      nowInCairo.day,
      nowInCairo.hour,
      nowInCairo.minute,
      nowInCairo.second,
    );

    for (final reminder in reminders) {
      final schedule = ReminderDateCalculator.calculateNotificationSchedule(
        dueDate: reminder.dueDate,
        repeat: reminder.repeat,
        leadDays: reminder.leadDays,
        now: nowDateTime,
      );

      if (schedule != null) {
        final moment = schedule.notificationMoment;
        final tzMoment = tz.TZDateTime(
          cairoLocation,
          moment.year,
          moment.month,
          moment.day,
          moment.hour,
          moment.minute,
          moment.second,
        );

        final content = ReminderDateCalculator.formatNotificationContent(
          name: reminder.name,
          amountPiastres: reminder.amount,
          leadDays: reminder.leadDays,
          occurrenceDueDate: schedule.occurrenceDueDate,
        );

        final androidDetails = AndroidNotificationDetails(
          remindersChannelId,
          remindersChannelName,
          channelDescription: remindersChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF4E8B7A),
          showWhen: true,
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(
            content.body,
            contentTitle: content.title,
          ),
        );

        const iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

        try {
          await _notificationsPlugin.zonedSchedule(
            reminder.id,
            content.title,
            content.body,
            tzMoment,
            NotificationDetails(android: androidDetails, iOS: iosDetails),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'reminders',
          );

          scheduledDetails.add((id: reminder.id, dateTime: moment));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[NOTIFICATION] Error scheduling reminder ${reminder.id}: $e');
          }
        }
      } else {
        // If this is a one-time reminder whose due date has already passed,
        // cancel any remaining scheduled notification.
        if (reminder.isOnce &&
            ReminderDateCalculator.isPastOneTime(
              dueDate: reminder.dueDate,
              repeat: reminder.repeat,
              now: nowDateTime,
            )) {
          try {
            await _notificationsPlugin.cancel(reminder.id);
          } catch (_) {}
        }
      }
    }

    // DEBUG ONLY (kDebugMode): print one line with the number of scheduled notifications
    // and, for each one, only its id and the scheduled date and time. Never print names or amounts.
    if (kDebugMode) {
      final count = scheduledDetails.length;
      final detailsStr = scheduledDetails
          .map((e) => 'id: ${e.id}, date: ${e.dateTime.toString()}')
          .join('; ');
      debugPrint('[REMINDERS] Scheduled $count notifications${count > 0 ? ': [$detailsStr]' : ''}');
    }
  }

  /// Dispatches an immediate local push notification warning that remaining budget is low.
  Future<void> showBudgetWarningNotification() async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      budgetChannelId,
      budgetChannelName,
      channelDescription: budgetChannelDescription,
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

    await _notificationsPlugin.show(
      101, // Constant ID for budget threshold warnings
      'تنبيه الميزانية - BAQY',
      'خد بالك انت قربت تخلص مصاريف الشهر ده',
      notificationDetails,
    );
  }
}
