import '../models/month_insights.dart';

/// Pure Dart utility to calculate monthly budget pacing, daily allowances,
/// and period-over-period financial insights without any Flutter dependencies.
abstract final class MonthInsightsCalculator {
  static String _formatDigits(Object value) {
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = value.toString();
    for (var i = 0; i < englishDigits.length; i++) {
      result = result.replaceAll(englishDigits[i], arabicDigits[i]);
    }
    return result;
  }

  static String _formatWithThousands(int amount) {
    final s = amount.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(s[i]);
    }
    final formatted = (amount < 0 ? '-' : '') + buffer.toString();
    return _formatDigits(formatted);
  }

  static MonthInsights calculate({
    required int year,
    required int month,
    required int remainingPiastres,
    required int spentPiastres,
    required int monthMoneyPiastres,
    required int? prevMonthSpentPiastres,
    int? prevMonthBudgetPiastres,
    required String currMonthName,
    required String prevMonthName,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final isCurrentMonth = current.year == year && current.month == month;
    final isPastMonth =
        (year < current.year) || (year == current.year && month < current.month);

    final int remainingEgp = remainingPiastres ~/ 100;
    final int spentEgp = spentPiastres ~/ 100;
    final int monthMoneyEgp = monthMoneyPiastres ~/ 100;
    final int daysInMonth = DateTime(year, month + 1, 0).day;

    // --- 1. Burn Rate / Expected Days Until Budget Depletion ---
    String burnRateText;
    bool isBurnRateWarning = false;

    if (monthMoneyEgp <= 0) {
      burnRateText = 'حدد ميزانيتك لحساب توقعات استهلاك الشهر';
    } else if (isPastMonth) {
      burnRateText = spentEgp <= monthMoneyEgp
          ? 'أنهيت شهر $currMonthName بنجاح ضمن حدود الميزانية'
          : 'تجاوزت ميزانية شهر $currMonthName بمبلغ ${_formatWithThousands(spentEgp - monthMoneyEgp)} جنيه';
      isBurnRateWarning = spentEgp > monthMoneyEgp;
    } else if (!isCurrentMonth) {
      burnRateText = 'شهر قادم لم يبدأ بعد';
    } else {
      // Active current month:
      final int currentDay = current.day;
      if (remainingEgp <= 0) {
        burnRateText = 'تم استهلاك الميزانية بالكامل لهذا الشهر';
        isBurnRateWarning = true;
      } else if (spentEgp <= 0) {
        burnRateText = 'لم تبدأ الصرف بعد، ميزانيتك تكفي لنهاية الشهر';
      } else {
        final double dailyBurnRate = spentEgp / currentDay;
        final double daysLeft = remainingEgp / dailyBurnRate;
        final int daysLeftCount = daysLeft.round();
        final int expectedExhaustionDay = currentDay + daysLeftCount;

        if (expectedExhaustionDay <= daysInMonth) {
          final daysFormatted = daysLeftCount <= 1
              ? 'خلال يوم واحد'
              : daysLeftCount == 2
                  ? 'خلال يومين'
                  : daysLeftCount >= 3 && daysLeftCount <= 10
                      ? 'خلال ${_formatDigits(daysLeftCount)} أيام'
                      : 'خلال ${_formatDigits(daysLeftCount)} يوم';

          burnRateText =
              'على معدل صرفك، الميزانية هتخلص $daysFormatted (يوم ${_formatDigits(expectedExhaustionDay)})';
          isBurnRateWarning = true;
        } else {
          final int totalDays = (currentDay + daysLeftCount);
          burnRateText =
              'على معدل صرفك، الميزانية هتكفيك ${_formatDigits(totalDays)} يوم (لنهاية الشهر وزيادة)';
        }
      }
    }

    // --- 2. Daily Allowed Budget ---
    String dailyAllowanceText;
    if (monthMoneyEgp <= 0) {
      dailyAllowanceText = 'المتوسط اليومي المسموح: غير محدد';
    } else if (isPastMonth) {
      final double actualDailyAverage = spentEgp / daysInMonth;
      dailyAllowanceText =
          'المتوسط اليومي الفعلي لشهر $currMonthName:\n${_formatWithThousands(actualDailyAverage.round())} جنيه';
    } else if (!isCurrentMonth) {
      final int allowance = (monthMoneyEgp / daysInMonth).round();
      dailyAllowanceText =
          'المتوسط اليومي المسموح:\n${_formatWithThousands(allowance)} جنيه';
    } else {
      // Active current month:
      final int remainingDays = (daysInMonth - current.day + 1);
      if (remainingDays <= 0 || remainingEgp <= 0) {
        dailyAllowanceText = 'المتوسط اليومي المسموح لحد آخر الشهر:\n٠ جنيه';
      } else {
        final int allowance = (remainingEgp / remainingDays).round();
        dailyAllowanceText =
            'المتوسط اليومي المسموح لحد آخر الشهر:\n${_formatWithThousands(allowance)} جنيه';
      }
    }

    // --- 3. Comparison with Previous Month ---
    String comparisonText;
    bool isSpendingLess = true;

    final int? prevSpentEgp =
        prevMonthSpentPiastres != null ? prevMonthSpentPiastres ~/ 100 : null;
    final int? prevBudgetEgp =
        prevMonthBudgetPiastres != null ? prevMonthBudgetPiastres ~/ 100 : null;

    if (prevSpentEgp != null && prevSpentEgp > 0) {
      if (spentEgp < prevSpentEgp) {
        final double diff = ((prevSpentEgp - spentEgp) / prevSpentEgp) * 100.0;
        final int pct = diff.round().clamp(1, 99);
        comparisonText =
            'صرفك في شهر $currMonthName أقل من شهر $prevMonthName بنسبة ${_formatDigits(pct)}٪';
        isSpendingLess = true;
      } else if (spentEgp > prevSpentEgp) {
        final double diff = ((spentEgp - prevSpentEgp) / prevSpentEgp) * 100.0;
        final int pct = diff.round().clamp(1, 999);
        comparisonText =
            'صرفك في شهر $currMonthName أكبر من شهر $prevMonthName بنسبة ${_formatDigits(pct)}٪';
        isSpendingLess = false;
      } else {
        comparisonText =
            'صرفك في شهر $currMonthName مساوٍ تماماً لشهر $prevMonthName';
        isSpendingLess = true;
      }
    } else if (prevBudgetEgp != null && prevBudgetEgp > 0 && monthMoneyEgp > 0) {
      if (monthMoneyEgp < prevBudgetEgp) {
        final double diff = ((prevBudgetEgp - monthMoneyEgp) / prevBudgetEgp) * 100.0;
        final int pct = diff.round().clamp(1, 99);
        comparisonText =
            'ميزانية شهر $currMonthName أقل من شهر $prevMonthName بنسبة ${_formatDigits(pct)}٪';
        isSpendingLess = true;
      } else if (monthMoneyEgp > prevBudgetEgp) {
        final double diff = ((monthMoneyEgp - prevBudgetEgp) / prevBudgetEgp) * 100.0;
        final int pct = diff.round().clamp(1, 999);
        comparisonText =
            'ميزانية شهر $currMonthName أكبر من شهر $prevMonthName بنسبة ${_formatDigits(pct)}٪';
        isSpendingLess = false;
      } else {
        comparisonText =
            'ميزانية شهر $currMonthName مساوية لميزانية شهر $prevMonthName';
        isSpendingLess = true;
      }
    } else {
      if (monthMoneyEgp > 0) {
        final int pct = ((spentEgp / monthMoneyEgp) * 100).round().clamp(0, 100);
        comparisonText =
            'استهلكت ${_formatDigits(pct)}٪ من ميزانية شهر $currMonthName حتى الآن';
        isSpendingLess = pct <= 75;
      } else {
        comparisonText =
            'بداية جديدة في شهر $currMonthName! تابع مصاريفك بانتظام';
        isSpendingLess = true;
      }
    }

    return MonthInsights(
      burnRateText: burnRateText,
      dailyAllowanceText: dailyAllowanceText,
      comparisonText: comparisonText,
      isBurnRateWarning: isBurnRateWarning,
      isSpendingLess: isSpendingLess,
    );
  }
}
