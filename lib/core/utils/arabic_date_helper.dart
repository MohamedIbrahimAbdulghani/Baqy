import 'number_formatter.dart';

/// Helper methods for Arabic month names, keys, and date conversions
abstract final class ArabicDateHelper {
  static const List<String> monthNames = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  /// Arabic names for weekdays (1 = Monday .. 7 = Sunday)
  static const List<String> weekdayNames = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  /// Returns Arabic name for month index (1..12).
  static String getMonthName(int month) {
    if (month < 1 || month > 12) return '';
    return monthNames[month - 1];
  }

  /// Returns Arabic name for weekday index (1..7, Monday = 1).
  static String getWeekdayName(int weekday) {
    if (weekday < 1 || weekday > 7) return '';
    return weekdayNames[weekday - 1];
  }

  /// Formats date into `"<weekday> <day> <month>"`, e.g. "الأربعاء ٤ نوفمبر"
  static String formatWeekdayDayMonth(DateTime date) {
    final weekday = getWeekdayName(date.weekday);
    final day = date.day.toArabicDigits();
    final month = getMonthName(date.month);
    return '$weekday $day $month';
  }

  /// Formats time into 12-hour Arabic format with period, e.g. "٩:٢٠ ص" or "٥:٤٠ م"
  static String formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour < 12 ? 'ص' : 'م';
    return '${hour12.toArabicDigits()}:${minute.toArabicDigits()} $period';
  }

  /// Formats date and time into `"<day> <month> - <time>"`, e.g. "٤ نوفمبر - ٩:٢٠ ص"
  static String formatDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toArabicDigits();
    final month = getMonthName(local.month);
    final time = formatTime(local);
    return '$day $month - $time';
  }

  /// Formats transaction count into Arabic text, e.g. "مرة واحدة", "٢ مرات", "٣ مرات"
  static String formatCount(int count) {
    if (count == 1) {
      return 'مرة واحدة';
    }
    return '${count.toArabicDigits()} مرات';
  }

  /// Formats year and month into display string, e.g. "نوفمبر ٢٠٢٦"
  static String formatMonthYear(int year, int month) {
    final name = getMonthName(month);
    final yearArabic = year.toArabicDigits();
    return '$name $yearArabic';
  }

  /// Converts year and month to standardized database key "YYYY-MM" (e.g. "2026-11")
  static String formatYearMonthKey(int year, int month) {
    return '$year-${month.toString().padLeft(2, '0')}';
  }

  /// Parses a "YYYY-MM" string into (year, month) record
  static (int year, int month) parseYearMonthKey(String yearMonth) {
    final parts = yearMonth.split('-');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Returns the "YYYY-MM" key for the month immediately preceding [yearMonth]
  static String getPreviousYearMonth(String yearMonth) {
    final (year, month) = parseYearMonthKey(yearMonth);
    if (month == 1) {
      return formatYearMonthKey(year - 1, 12);
    } else {
      return formatYearMonthKey(year, month - 1);
    }
  }

  /// Returns the "YYYY-MM" key for the month immediately succeeding [yearMonth]
  static String getNextYearMonth(String yearMonth) {
    final (year, month) = parseYearMonthKey(yearMonth);
    if (month == 12) {
      return formatYearMonthKey(year + 1, 1);
    } else {
      return formatYearMonthKey(year, month + 1);
    }
  }

  /// Returns display title from a "YYYY-MM" string, e.g. "2026-11" -> "نوفمبر ٢٠٢٦"
  static String formatYearMonthKeyToDisplay(String yearMonth) {
    final (year, month) = parseYearMonthKey(yearMonth);
    return formatMonthYear(year, month);
  }

  /// Tries to parse a display title like "نوفمبر ٢٠٢٦" back into "YYYY-MM"
  static String? tryParseDisplayToYearMonth(String display) {
    final trimmed = display.trim();
    if (RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(trimmed)) {
      return trimmed;
    }
    for (var m = 0; m < monthNames.length; m++) {
      final name = monthNames[m];
      if (trimmed.startsWith(name)) {
        final rest = trimmed.substring(name.length).trim();
        final englishYear = rest
            .replaceAll('٠', '0')
            .replaceAll('١', '1')
            .replaceAll('٢', '2')
            .replaceAll('٣', '3')
            .replaceAll('٤', '4')
            .replaceAll('٥', '5')
            .replaceAll('٦', '6')
            .replaceAll('٧', '7')
            .replaceAll('٨', '8')
            .replaceAll('٩', '9');
        final year = int.tryParse(englishYear);
        if (year != null) {
          return formatYearMonthKey(year, m + 1);
        }
      }
    }
    return null;
  }
}
