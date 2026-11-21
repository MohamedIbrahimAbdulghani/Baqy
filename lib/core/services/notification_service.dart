import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../features/debts/domain/models/debt_item.dart';
import '../../features/reminders/domain/models/reminder_item.dart';
import '../../features/reminders/domain/utils/reminder_date_calculator.dart';

/// Service responsible for managing local push notifications, reminder scheduling, and permissions.
class NotificationService {
  NotificationService._internal();
  static NotificationService instance = NotificationService._internal();

  /// Visible setter for unit testing
  @visibleForTesting
  static set testInstance(NotificationService service) {
    instance = service;
  }

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
        } else if (response.payload == 'debts') {
          if (onSelectTab != null) {
            onSelectTab!(3);
          } else {
            pendingTabSelection = 3;
          }
        }
      },
    );

    // Check if app was launched directly by tapping a notification
    try {
      final launchDetails = await _notificationsPlugin
          .getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        if (launchDetails.notificationResponse?.payload == 'reminders') {
          pendingTabSelection = 2;
        } else if (launchDetails.notificationResponse?.payload == 'debts') {
          pendingTabSelection = 3;
        }
      }
    } catch (_) {}

    // Create notification channels on Android
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

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
            _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >();
        final bool? granted = await androidImplementation
            ?.requestNotificationsPermission();
        return granted ?? false;
      } else if (Platform.isIOS) {
        final IOSFlutterLocalNotificationsPlugin? iosImplementation =
            _notificationsPlugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >();
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

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    for (final reminder in reminders) {
      final nextDue = ReminderDateCalculator.calculateNextDueDate(
        dueDate: reminder.dueDate,
        repeat: reminder.repeat,
        now: nowDateTime,
      );
      final catchupKey =
          'reminder_catchup_sent_${reminder.id}_${nextDue.year}_${nextDue.month}_${nextDue.day}';
      final alreadySentCatchup = prefs?.getBool(catchupKey) ?? false;

      // 1. Calculate schedule, allowing catch-up today if not already sent for this occurrence
      var schedule = ReminderDateCalculator.calculateNotificationSchedule(
        dueDate: reminder.dueDate,
        repeat: reminder.repeat,
        leadDays: reminder.leadDays,
        now: nowDateTime,
        allowCatchupToday: !alreadySentCatchup,
      );

      // If scheduled moment is within 10 seconds (catch-up), mark as sent so it won't re-trigger on subsequent syncs today
      if (schedule != null &&
          schedule.notificationMoment.difference(nowDateTime).inSeconds <= 10 &&
          prefs != null) {
        await prefs.setBool(catchupKey, true);
      }

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
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: Color(0xFF2F6B5A),
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
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'reminders',
          );

          scheduledDetails.add((id: reminder.id, dateTime: moment));
        } catch (e) {
          // Fallback to inexact if exact alarms are restricted
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
          } catch (e2) {
            if (kDebugMode) {
              debugPrint(
                '[NOTIFICATION] Error scheduling reminder ${reminder.id}: $e2',
              );
            }
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
      debugPrint(
        '[REMINDERS] Scheduled $count notifications${count > 0 ? ': [$detailsStr]' : ''}',
      );
    }
  }

  /// Cancels notification for a specific debt ID.
  Future<void> cancelDebtNotification(int debtId) async {
    try {
      await _notificationsPlugin.cancel(200000 + debtId);
      await _notificationsPlugin.cancel(debtId);
    } catch (_) {}
  }

  /// Reschedules all debt notifications.
  /// A debt notification exists if (and only if) a due date is set: no due date means no notification.
  /// It fires at 09:00 Africa/Cairo, 2 days before the due date (fixed), with the standard inexact scheduling.
  /// If the 09:00 moment has already passed, it is skipped.
  /// Cancelled when the debt is archived or deleted.
  /// DEBUG ONLY (kDebugMode): prints one line with the number of scheduled notifications
  /// and, for each one, only its id and the scheduled date and time. Never print names or amounts.
  Future<void> rescheduleDebts(List<DebtItem> debts) async {
    final scheduledDetails = <({int id, DateTime dateTime})>[];
    tz.Location cairoLocation;
    try {
      tz.initializeTimeZones();
      cairoLocation = tz.getLocation('Africa/Cairo');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[NOTIFICATION] Timezone not available for scheduling debts: $e');
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

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}

    for (final debt in debts) {
      if (debt.archived || debt.dueDate == null || debt.remaining <= 0) {
        try {
          await _notificationsPlugin.cancel(200000 + debt.id);
          await _notificationsPlugin.cancel(debt.id);
        } catch (_) {}
        continue;
      }

      final dueDate = debt.dueDate!;
      final catchupKey =
          'debt_catchup_sent_${debt.id}_${dueDate.year}_${dueDate.month}_${dueDate.day}';
      final alreadySentCatchup = prefs?.getBool(catchupKey) ?? false;

      final notifMoment = ReminderDateCalculator.calculateDebtNotificationMoment(
        dueDate: dueDate,
        leadDays: debt.leadDays,
        now: nowDateTime,
        allowCatchupToday: !alreadySentCatchup,
      );

      if (notifMoment == null) {
        try {
          await _notificationsPlugin.cancel(200000 + debt.id);
          await _notificationsPlugin.cancel(debt.id);
        } catch (_) {}
        continue;
      }

      if (notifMoment.difference(nowDateTime).inSeconds <= 10 && prefs != null) {
        await prefs.setBool(catchupKey, true);
      }

      final tzMoment = tz.TZDateTime(
        cairoLocation,
        notifMoment.year,
        notifMoment.month,
        notifMoment.day,
        notifMoment.hour,
        notifMoment.minute,
        notifMoment.second,
      );

      final content = ReminderDateCalculator.formatDebtNotificationContent(
        personName: debt.personName,
        direction: debt.direction,
        remainingPiastres: debt.remaining,
        dueDate: dueDate,
        leadDays: debt.leadDays,
      );

      final androidDetails = AndroidNotificationDetails(
        remindersChannelId,
        remindersChannelName,
        channelDescription: remindersChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        color: const Color(0xFF2F6B5A),
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

      final notifId = 200000 + debt.id;
      try {
        await _notificationsPlugin.zonedSchedule(
          notifId,
          content.title,
          content.body,
          tzMoment,
          NotificationDetails(android: androidDetails, iOS: iosDetails),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: 'debts',
        );
        scheduledDetails.add((id: debt.id, dateTime: notifMoment));
      } catch (e) {
        try {
          await _notificationsPlugin.zonedSchedule(
            notifId,
            content.title,
            content.body,
            tzMoment,
            NotificationDetails(android: androidDetails, iOS: iosDetails),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: 'debts',
          );
          scheduledDetails.add((id: debt.id, dateTime: notifMoment));
        } catch (_) {}
      }
    }

    if (kDebugMode) {
      final count = scheduledDetails.length;
      final detailsStr = scheduledDetails
          .map((e) => 'id: ${e.id}, date: ${e.dateTime.toString()}')
          .join('; ');
      debugPrint(
        '[DEBTS] Scheduled $count notifications${count > 0 ? ': [$detailsStr]' : ''}',
      );
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
          largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          color: Color(0xFF2F6B5A),
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

    try {
      await _notificationsPlugin.cancel(101);
    } catch (_) {}

    await _notificationsPlugin.show(
      101, // Constant ID for budget threshold warnings
      'تنبيه الميزانية - BAQY',
      'خد بالك انت قربت تخلص مصاريف الشهر ده',
      notificationDetails,
    );
  }
}
