import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/core/utils/number_formatter.dart';
import 'package:baqy/features/home/presentation/controllers/budget_monitor_controller.dart';
import 'package:baqy/features/home/presentation/widgets/budget_ring.dart';

void main() {
  group('BudgetRing New Card Layout & Color Dynamic Tests', () {
    testWidgets('Renders all labels, amounts, and remaining days correctly', (tester) async {
      // 10,000 budget, 9,300 spent -> 700 remaining (Scenario from User Image 1)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 700 * 100,
              spentPiastres: 9300 * 100,
              monthMoneyPiastres: 10000 * 100,
              year: 2026,
              month: 11,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify labels
      expect(find.text('الميزانية'), findsOneWidget);
      expect(find.text('صرفت'), findsOneWidget);
      expect(find.text('جنيه متبقي'), findsOneWidget);

      // Verify amounts
      expect(find.text('${NumberFormatter.formatCurrency(10000)} جنيه'), findsOneWidget);
      expect(find.text('${NumberFormatter.formatCurrency(9300)} جنيه'), findsOneWidget);
      expect(find.text(NumberFormatter.formatCurrency(700)), findsOneWidget);

      // Verify edit icon
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    });

    testWidgets('Ring is complete (1.0) when nothing is spent, and decreases as money is spent', (tester) async {
      // 1. Zero spent -> 10,000 remaining of 10,000 -> progress = 1.0 (complete circle)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 10000 * 100,
              spentPiastres: 0,
              monthMoneyPiastres: 10000 * 100,
              onTap: () {},
            ),
          ),
        ),
      );

      var budgetRing = find.byType(BudgetRing);
      var customPaints = tester.widgetList<CustomPaint>(
        find.descendant(of: budgetRing, matching: find.byType(CustomPaint)),
      );
      var ringPaint = customPaints.firstWhere((cp) => cp.painter != null);
      dynamic painter = ringPaint.painter;
      expect(painter.progress, equals(1.0));

      // 2. 4,000 spent -> 6,000 remaining of 10,000 -> progress = 0.6 (ring decreased)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 6000 * 100,
              spentPiastres: 4000 * 100,
              monthMoneyPiastres: 10000 * 100,
              onTap: () {},
            ),
          ),
        ),
      );

      budgetRing = find.byType(BudgetRing);
      customPaints = tester.widgetList<CustomPaint>(
        find.descendant(of: budgetRing, matching: find.byType(CustomPaint)),
      );
      ringPaint = customPaints.firstWhere((cp) => cp.painter != null);
      painter = ringPaint.painter;
      expect(painter.progress, closeTo(0.6, 0.001));
    });

    testWidgets('Turns red when remaining budget is at or below 25% of total budget', (tester) async {
      // Total 10,000 EGP, spent 7,500 EGP, remaining 2,500 EGP (exactly 25%)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 2500 * 100,
              spentPiastres: 7500 * 100,
              monthMoneyPiastres: 10000 * 100,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify remaining text widget uses warningRed
      final remainingTextWidget = tester.widget<Text>(find.text(NumberFormatter.formatCurrency(2500)));
      expect(remainingTextWidget.style?.color, equals(BudgetMonitorController.warningRed));

      // Verify CustomPaint inside BudgetRing has warningRed painter
      final budgetRing = find.byType(BudgetRing);
      final customPaints = tester.widgetList<CustomPaint>(
        find.descendant(of: budgetRing, matching: find.byType(CustomPaint)),
      );
      final ringPaint = customPaints.firstWhere((cp) => cp.painter != null);
      final dynamic painter = ringPaint.painter;
      expect(painter.progressColor, equals(BudgetMonitorController.warningRed));
      expect(painter.progress, closeTo(0.25, 0.001));
    });

    testWidgets('Turns red when budget passes 75% spending (700 EGP remaining out of 10,000)', (tester) async {
      // Total 10,000 EGP, spent 9,300 EGP, remaining 700 EGP (7% remaining)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 700 * 100,
              spentPiastres: 9300 * 100,
              monthMoneyPiastres: 10000 * 100,
              onTap: () {},
            ),
          ),
        ),
      );

      final budgetRing = find.byType(BudgetRing);
      final customPaints = tester.widgetList<CustomPaint>(
        find.descendant(of: budgetRing, matching: find.byType(CustomPaint)),
      );
      final ringPaint = customPaints.firstWhere((cp) => cp.painter != null);
      final dynamic painter = ringPaint.painter;
      expect(painter.progressColor, equals(BudgetMonitorController.warningRed));
      expect(painter.progress, closeTo(0.07, 0.001));
    });

    testWidgets('Stays green when remaining budget is above 25%', (tester) async {
      // Total 10,000 EGP, spent 3,000 EGP, remaining 7,000 EGP (70% remaining)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 7000 * 100,
              spentPiastres: 3000 * 100,
              monthMoneyPiastres: 10000 * 100,
              onTap: () {},
            ),
          ),
        ),
      );

      // Verify remaining text widget uses defaultGreen
      final remainingTextWidget = tester.widget<Text>(find.text(NumberFormatter.formatCurrency(7000)));
      expect(remainingTextWidget.style?.color, equals(BudgetMonitorController.defaultGreen));

      // Verify CustomPaint uses defaultGreen painter
      final budgetRing = find.byType(BudgetRing);
      final customPaints = tester.widgetList<CustomPaint>(
        find.descendant(of: budgetRing, matching: find.byType(CustomPaint)),
      );
      final ringPaint = customPaints.firstWhere((cp) => cp.painter != null);
      final dynamic painter = ringPaint.painter;
      expect(painter.progressColor, equals(BudgetMonitorController.defaultGreen));
      expect(painter.progress, closeTo(0.70, 0.001));
    });

    test('calculateRemainingDaysText formats Arabic text properly', () {
      final now = DateTime(2026, 11, 27); // 30 days in November, 30 - 27 = 3 days remaining

      final daysText = BudgetRing.calculateRemainingDaysText(
        year: 2026,
        month: 11,
        now: now,
      );

      expect(daysText, equals('فاضل ${NumberFormatter.formatCurrency(3)} أيام على آخر الشهر'));

      // 1 day remaining
      final oneDayNow = DateTime(2026, 11, 29);
      expect(
        BudgetRing.calculateRemainingDaysText(year: 2026, month: 11, now: oneDayNow),
        equals('فاضل يوم على آخر الشهر'),
      );

      // Last day
      final lastDayNow = DateTime(2026, 11, 30);
      expect(
        BudgetRing.calculateRemainingDaysText(year: 2026, month: 11, now: lastDayNow),
        equals('اليوم هو آخر يوم في الشهر'),
      );

      // Past month
      expect(
        BudgetRing.calculateRemainingDaysText(year: 2026, month: 10, now: now),
        equals('انتهى هذا الشهر'),
      );
    });

    testWidgets('Tapping the card fires onTap callback', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 5000 * 100,
              spentPiastres: 5000 * 100,
              monthMoneyPiastres: 10000 * 100,
              onTap: () {
                tapped = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(InkWell));
      expect(tapped, isTrue);
    });
  });
}
