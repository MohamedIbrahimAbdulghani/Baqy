import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../models/reminder_item.dart';

/// Pure Dart calculator for reminder due dates, notification moments, and text formatting.
abstract final class ReminderDateCalculator {
  /// Calculates the next due date for a reminder.
  /// For "once", returns the dueDate itself.
  /// For "monthly", moves to the next month automatically after its due date.
  /// If the day does not exist in a month, uses the last day of that month.
  /// [now] can be provided for deterministic testing.
  static DateTime calculateNextDueDate({
    required DateTime dueDate,
    required String repeat,
    DateTime? now,
  }) {
    if (repeat != 'monthly') {
      return DateTime(dueDate.year, dueDate.month, dueDate.day);
    }

    final reference = now ?? DateTime.now();
    final refDay = DateTime(reference.year, reference.month, reference.day);
    final originalDay = dueDate.day;

    int year = dueDate.year;
    int month = dueDate.month;

    while (true) {
      final int daysInMonth = DateTime(year, month + 1, 0).day;
      final int day = originalDay > daysInMonth ? daysInMonth : originalDay;
      final candidate = DateTime(year, month, day);

      // A monthly reminder moves to the next month automatically AFTER its due date.
      // So if candidate is on or after refDay, this is our next due date!
      if (!candidate.isBefore(refDay)) {
        return candidate;
      }

      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }

  /// Returns true if this is a one-time reminder whose due date has passed.
  static bool isPastOneTime({
    required DateTime dueDate,
    required String repeat,
    DateTime? now,
  }) {
    if (repeat != 'once') return false;
    final reference = now ?? DateTime.now();
    final refDay = DateTime(reference.year, reference.month, reference.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDay.isBefore(refDay);
  }

  /// Calculates the next notification schedule for a reminder.
  /// A notification fires at 09:00 on (due date minus lead days).
  /// If the 09:00 moment has already passed:
  /// - for "once": skips it and returns null.
  /// - for "monthly": moves to the next occurrence month-by-month until the 09:00 moment is in the future.
  static ({DateTime notificationMoment, DateTime occurrenceDueDate})?
      calculateNotificationSchedule({
    required DateTime dueDate,
    required String repeat,
    required int leadDays,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final originalDay = dueDate.day;
    int year = dueDate.year;
    int month = dueDate.month;

    while (true) {
      final int daysInMonth = DateTime(year, month + 1, 0).day;
      final int day = originalDay > daysInMonth ? daysInMonth : originalDay;
      final occurrenceDueDate = DateTime(year, month, day);

      // Notification moment is 09:00 on (occurrence due date minus lead days)
      final notifDate = occurrenceDueDate.subtract(Duration(days: leadDays));
      final notificationMoment = DateTime(
        notifDate.year,
        notifDate.month,
        notifDate.day,
        9, // 09:00
        0,
        0,
      );

      if (notificationMoment.isAfter(reference)) {
        return (
          notificationMoment: notificationMoment,
          occurrenceDueDate: occurrenceDueDate,
        );
      }

      // If the 09:00 moment of an occurrence has already passed, skip it.
      // For a one-time reminder, there is no future occurrence.
      if (repeat != 'monthly') {
        return null;
      }

      // For a monthly reminder, move on to the next occurrence
      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }

  /// Formats lead days into standard Arabic text:
  /// 1 -> "يوم"
  /// 2 -> "يومين"
  /// 3 -> "٣ أيام"
  static String formatLeadDaysText(int leadDays) {
    switch (leadDays) {
      case 1:
        return 'يوم';
      case 2:
        return 'يومين';
      case 3:
        return '٣ أيام';
      default:
        return '$leadDays أيام';
    }
  }

  /// Formats notification title and multi-line body exactly matching the specification:
  /// Title: "باقي"
  /// Body:
  /// "`<name>` هيتدفع كمان `<يوم|يومين|٣ أيام>`"
  /// "`<amount>` جنيه · `<weekday>` `<date>`"
  static ({String title, String body}) formatNotificationContent({
    required String name,
    required int amountPiastres,
    required int leadDays,
    required DateTime occurrenceDueDate,
  }) {
    final leadText = formatLeadDaysText(leadDays);
    final line1 = '$name هيتدفع كمان $leadText';

    final int amountEgp = amountPiastres ~/ 100;
    final amountStr = NumberFormatter.formatCurrency(amountEgp);
    final weekday = ArabicDateHelper.getWeekdayName(occurrenceDueDate.weekday);
    final day = occurrenceDueDate.day.toArabicDigits();
    final month = ArabicDateHelper.getMonthName(occurrenceDueDate.month);
    final line2 = '$amountStr جنيه · $weekday $day $month';

    return (
      title: 'باقي',
      body: '$line1\n$line2',
    );
  }

  /// Sorts reminders list:
  /// Active reminders sorted soonest first by next due date.
  /// Past one-time reminders placed faded at the end of the list.
  static List<ReminderItem> sortReminders(
    List<ReminderItem> items, {
    DateTime? now,
  }) {
    final active = <({ReminderItem item, DateTime nextDue})>[];
    final past = <ReminderItem>[];

    for (final item in items) {
      if (isPastOneTime(dueDate: item.dueDate, repeat: item.repeat, now: now)) {
        past.add(item);
      } else {
        final nextDue = calculateNextDueDate(
          dueDate: item.dueDate,
          repeat: item.repeat,
          now: now,
        );
        active.add((item: item, nextDue: nextDue));
      }
    }

    active.sort((a, b) => a.nextDue.compareTo(b.nextDue));
    past.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return [
      ...active.map((e) => e.item),
      ...past,
    ];
  }
}
