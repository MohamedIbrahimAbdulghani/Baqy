import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/core/utils/number_formatter.dart';
import 'package:baqy/features/home/domain/models/month_insights.dart';
import 'package:baqy/features/home/domain/utils/month_insights_calculator.dart';
import 'package:baqy/features/home/presentation/widgets/month_overview_card.dart';

void main() {
  group('MonthInsightsCalculator Unit Tests', () {
    test('Calculates burn rate days count and exhaustion day matching User scenario', () {
      // User image scenario:
      // November 2026 (30 days total)
      // Today is day 27
      // 10,000 total budget, 9,300 spent -> 700 remaining
      // Daily burn rate = 9,300 / 27 = 344.44
      // Remaining 700 / 344.44 = 2.03 days -> 2 days left!
      // Expected exhaustion day = 27 + 2 = 29!
      final now = DateTime(2026, 11, 27);
      final insights = MonthInsightsCalculator.calculate(
        year: 2026,
        month: 11,
        remainingPiastres: 700 * 100,
        spentPiastres: 9300 * 100,
        monthMoneyPiastres: 10000 * 100,
        prevMonthSpentPiastres: 10100 * 100, // October spent 10,100 -> current 9,300 is 8% less!
        currMonthName: 'نوفمبر',
        prevMonthName: 'أكتوبر',
        now: now,
      );

      // Verify burn rate says: "خلال يومين (يوم ٢٩)"
      expect(
        insights.burnRateText,
        equals('على معدل صرفك، الميزانية هتخلص خلال يومين (يوم ${NumberFormatter.formatCurrency(29)})'),
      );
      expect(insights.isBurnRateWarning, isTrue);

      // Verify daily allowance
      expect(insights.dailyAllowanceText, contains('المتوسط اليومي المسموح لحد آخر الشهر'));

      // Verify comparison with October: (10,100 - 9,300) / 10,100 = 7.92% ~ 8%!
      expect(
        insights.comparisonText,
        equals('صرفك في شهر نوفمبر أقل من شهر أكتوبر بنسبة ${NumberFormatter.formatCurrency(8)}٪'),
      );
      expect(insights.isSpendingLess, isTrue);
    });

    test('Calculates when spending is greater than previous month', () {
      final now = DateTime(2026, 11, 15);
      final insights = MonthInsightsCalculator.calculate(
        year: 2026,
        month: 11,
        remainingPiastres: 4000 * 100,
        spentPiastres: 6000 * 100,
        monthMoneyPiastres: 10000 * 100,
        prevMonthSpentPiastres: 5000 * 100, // 6,000 is 20% more than 5,000!
        currMonthName: 'نوفمبر',
        prevMonthName: 'أكتوبر',
        now: now,
      );

      expect(
        insights.comparisonText,
        equals('صرفك في شهر نوفمبر أكبر من شهر أكتوبر بنسبة ${NumberFormatter.formatCurrency(20)}٪'),
      );
      expect(insights.isSpendingLess, isFalse);
    });

    test('Handles stable budget that lasts until end of month', () {
      final now = DateTime(2026, 11, 10);
      final insights = MonthInsightsCalculator.calculate(
        year: 2026,
        month: 11,
        remainingPiastres: 8000 * 100,
        spentPiastres: 2000 * 100,
        monthMoneyPiastres: 10000 * 100,
        prevMonthSpentPiastres: null,
        currMonthName: 'نوفمبر',
        prevMonthName: 'أكتوبر',
        now: now,
      );

      expect(insights.burnRateText, contains('لنهاية الشهر وزيادة'));
      expect(insights.isBurnRateWarning, isFalse);
    });
  });

  group('MonthOverviewCard Widget Tests', () {
    testWidgets('Renders all 3 insight rows and title', (tester) async {
      const sampleInsights = MonthInsights(
        burnRateText: 'على معدل صرفك، الميزانية هتخلص خلال يومين (يوم ٢٩)',
        dailyAllowanceText: 'المتوسط اليومي المسموح لحد آخر الشهر:\n٢٣٣ جنيه',
        comparisonText: 'صرفك في شهر نوفمبر أقل من شهر أكتوبر بنسبة ٨٪',
        isBurnRateWarning: true,
        isSpendingLess: true,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MonthOverviewCard(insights: sampleInsights),
          ),
        ),
      );

      // Verify Title
      expect(find.text('نظرة على شهرك'), findsOneWidget);

      // Verify Rows
      expect(find.text('على معدل صرفك، الميزانية هتخلص خلال يومين (يوم ٢٩)'), findsOneWidget);
      expect(find.text('المتوسط اليومي المسموح لحد آخر الشهر:\n٢٣٣ جنيه'), findsOneWidget);
      expect(find.text('صرفك في شهر نوفمبر أقل من شهر أكتوبر بنسبة ٨٪'), findsOneWidget);

      // Verify Icons
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(find.byIcon(Icons.trending_down_rounded), findsOneWidget);
    });
  });
}
