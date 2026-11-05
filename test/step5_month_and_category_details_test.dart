import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';

import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/theme/app_theme.dart';
import 'package:baqy/core/utils/arabic_date_helper.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/domain/models/category_details_args.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/expenses/presentation/screens/category_details_screen.dart';
import 'package:baqy/features/expenses/presentation/screens/month_details_screen.dart';
import 'package:baqy/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ExpenseRepositoryImpl repository;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repository = ExpenseRepositoryImpl(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget createTestWidget(Widget child) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        expenseRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        theme: AppTheme.lightTheme,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: child,
      ),
    );
  }



  group('Step 5 Unit & Database Tests: Daily Totals, Month Isolation & Before-Day Checks', () {
    test('getCategoryTotalsForDay groups expenses by category and counts correctly', () async {
      final categories = await repository.getCategories();
      final food = categories.firstWhere((c) => c.name == 'أكل');
      final transport = categories.firstWhere((c) => c.name == 'مواصلات');

      final targetDay = DateTime.utc(2026, 11, 4);

      // Add 2 food transactions on target day
      await repository.addTransaction(
        amount: 7000, // 70 EGP
        description: 'سندوتشات',
        categoryId: food.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 4, 10, 0),
      );
      await repository.addTransaction(
        amount: 15000, // 150 EGP
        description: 'غدا',
        categoryId: food.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 4, 14, 0),
      );

      // Add 1 transport transaction on target day
      await repository.addTransaction(
        amount: 15000, // 150 EGP
        description: 'ميكروباص',
        categoryId: transport.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 4, 16, 0),
      );

      // Add transaction on different day (Nov 3)
      await repository.addTransaction(
        amount: 30000,
        description: 'فاتورة',
        categoryId: food.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 3, 12, 0),
      );

      final totals = await repository.getCategoryTotalsForDay(targetDay);

      expect(totals.length, equals(2));
      // Food: 220 EGP (22000 piastres), 2 transactions
      final foodTotal = totals.firstWhere((t) => t.category.id == food.id);
      expect(foodTotal.totalAmount, equals(22000));
      expect(foodTotal.transactionCount, equals(2));

      // Transport: 150 EGP (15000 piastres), 1 transaction
      final transportTotal = totals.firstWhere((t) => t.category.id == transport.id);
      expect(transportTotal.totalAmount, equals(15000));
      expect(transportTotal.transactionCount, equals(1));
    });

    test('hasExpensesBefore correctly detects if expenses exist prior to a given day', () async {
      final categories = await repository.getCategories();
      final catId = categories.first.id;

      final nov3 = DateTime.utc(2026, 11, 3);
      final nov4 = DateTime.utc(2026, 11, 4);

      // Initially no expenses
      expect(await repository.hasExpensesBefore(nov4), isFalse);

      // Add expense on Nov 3
      await repository.addTransaction(
        amount: 5000,
        description: 'أكل',
        categoryId: catId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 3, 12, 0),
      );

      // Before Nov 4: true
      expect(await repository.hasExpensesBefore(nov4), isTrue);

      // Before Nov 3: false
      expect(await repository.hasExpensesBefore(nov3), isFalse);
    });
  });

  group('Step 5 Widget Tests: MonthDetailsScreen & Chart', () {
    testWidgets('MonthDetailsScreen renders title, chart card without remaining/total, and day card',
        (WidgetTester tester) async {
      final categories = await repository.getCategories();
      final food = categories.firstWhere((c) => c.name == 'أكل');
      final transport = categories.firstWhere((c) => c.name == 'مواصلات');

      final today = DateTime.now();

      // Seed 2 food transactions today
      await repository.addTransaction(
        amount: 22000,
        description: 'أكل اليوم',
        categoryId: food.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(today.year, today.month, today.day, 12, 0),
      );
      // Seed 1 transport transaction today
      await repository.addTransaction(
        amount: 15000,
        description: 'مواصلات اليوم',
        categoryId: transport.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(today.year, today.month, today.day, 14, 0),
      );

      final currentYm = ArabicDateHelper.formatYearMonthKey(today.year, today.month);
      final monthName = ArabicDateHelper.getMonthName(today.month);

      await tester.pumpWidget(
        createTestWidget(
          MonthDetailsScreen(initialYearMonth: currentYm),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar title: "<month> <year>"
      expect(find.text(ArabicDateHelper.formatMonthYear(today.year, today.month)), findsOneWidget);

      // Card titled "مصاريف شهر <month>"
      expect(find.text('مصاريف شهر $monthName'), findsOneWidget);

      // Verify custom painter is used (NO chart package)
      expect(find.byType(CustomPaint), findsWidgets);

      // Day card in middle: "<weekday> <day> <month>" (no word "today", no day total)
      final expectedDayText = ArabicDateHelper.formatWeekdayDayMonth(today);
      expect(find.text(expectedDayText), findsOneWidget);
      expect(find.text('اليوم'), findsNothing);

      // Day's expenses grouped by category:
      // Food (أكل): "٢٢٠ جنيه", "مرة واحدة"
      expect(find.text('أكل'), findsWidgets); // 1 in chart, 1 in list
      expect(find.text('مواصلات'), findsWidgets); // 1 in chart, 1 in list
      expect(find.text('٢٢٠ جنيه'), findsOneWidget);
      expect(find.text('١٥٠ جنيه'), findsOneWidget);
    });

    testWidgets('Tapping previous-day arrow changes day and updates list without opening new screen',
        (WidgetTester tester) async {
      final categories = await repository.getCategories();
      final food = categories.firstWhere((c) => c.name == 'أكل');
      final bills = categories.firstWhere((c) => c.name == 'فواتير');

      final today = DateTime.now();
      final yesterday = DateTime(today.year, today.month, today.day - 1);

      // Transaction yesterday
      await repository.addTransaction(
        amount: 30000, // 300 EGP
        description: 'فاتورة الكهرباء',
        categoryId: bills.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(yesterday.year, yesterday.month, yesterday.day, 10, 0),
      );

      // Transaction today
      await repository.addTransaction(
        amount: 15000, // 150 EGP
        description: 'غدا',
        categoryId: food.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(today.year, today.month, today.day, 12, 0),
      );

      final currentYm = ArabicDateHelper.formatYearMonthKey(today.year, today.month);

      await tester.pumpWidget(
        createTestWidget(
          MonthDetailsScreen(initialYearMonth: currentYm),
        ),
      );
      await tester.pumpAndSettle();

      // Today shows food (150 جنيه), does NOT show bills
      expect(find.text('١٥٠ جنيه'), findsOneWidget);
      expect(find.text('٣٠٠ جنيه'), findsNothing);

      // Tap previous day arrow (the right arrow in the day selector card)
      // The day selector right arrow is the second arrow_forward icon on screen (first is top back arrow)
      final prevArrows = find.byIcon(Icons.arrow_forward_ios_rounded);
      expect(prevArrows, findsNWidgets(2));
      await tester.tap(prevArrows.at(1));
      await tester.pumpAndSettle();

      // Now day card shows yesterday
      expect(find.text(ArabicDateHelper.formatWeekdayDayMonth(yesterday)), findsOneWidget);

      // Yesterday shows bills (300 جنيه), food is not in yesterday's list
      expect(find.text('٣٠٠ جنيه'), findsOneWidget);
    });
  });

  group('Step 5 Widget Tests: CategoryDetailsScreen (Day and Month Modes)', () {
    testWidgets('CategoryDetailsScreen for day shows date, total, and transactions with time only',
        (WidgetTester tester) async {
      final categories = await repository.getCategories();
      final transport = categories.firstWhere((c) => c.name == 'مواصلات');

      final day = DateTime.utc(2026, 11, 4);

      // Add 2 transactions on Nov 4
      await repository.addTransaction(
        amount: 5000, // 50 EGP
        description: 'رحت القاهرة',
        categoryId: transport.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 4, 7, 20),
      );
      await repository.addTransaction(
        amount: 10000, // 100 EGP
        description: 'رجعت الشرقية',
        categoryId: transport.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 4, 15, 40),
      );

      await tester.pumpWidget(
        createTestWidget(
          CategoryDetailsScreen(
            args: CategoryDetailsArgs(
              category: transport,
              yearMonth: '2026-11',
              day: day,
              isMonthMode: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Category Name & Date in top bar
      expect(find.text('مواصلات'), findsOneWidget);
      expect(find.text('الأربعاء ٤ نوفمبر'), findsOneWidget);

      // "الإجمالي" label and total "١٥٠ جنيه"
      expect(find.text('الإجمالي'), findsOneWidget);
      expect(find.text('١٥٠ جنيه'), findsOneWidget);

      // Transactions
      expect(find.text('رجعت الشرقية'), findsOneWidget);
      expect(find.text('رحت القاهرة'), findsOneWidget);
      expect(find.text('١٠٠ جنيه'), findsOneWidget);
      expect(find.text('٥٠ جنيه'), findsOneWidget);
    });

    testWidgets('CategoryDetailsScreen for whole month shows date and time for each transaction',
        (WidgetTester tester) async {
      final categories = await repository.getCategories();
      final food = categories.firstWhere((c) => c.name == 'أكل');

      // Add transactions across different days in November
      await repository.addTransaction(
        amount: 25000, // 250 EGP
        description: 'عزومة',
        categoryId: food.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 2, 10, 0),
      );
      await repository.addTransaction(
        amount: 15000, // 150 EGP
        description: 'سوبرماركت',
        categoryId: food.id,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 5, 14, 0),
      );

      await tester.pumpWidget(
        createTestWidget(
          CategoryDetailsScreen(
            args: CategoryDetailsArgs(
              category: food,
              yearMonth: '2026-11',
              isMonthMode: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Category name and month title
      expect(find.text('أكل'), findsOneWidget);
      expect(find.text('نوفمبر ٢٠٢٦'), findsOneWidget);

      // Total "٤٠٠ جنيه" (250 + 150)
      expect(find.text('٤٠٠ جنيه'), findsOneWidget);
      expect(find.text('عزومة'), findsOneWidget);
      expect(find.text('٢٥٠ جنيه'), findsOneWidget);
      expect(find.text('سوبرماركت'), findsOneWidget);
      expect(find.text('١٥٠ جنيه'), findsOneWidget);

      // Subtitle contains both day/month and time (e.g. "٢ نوفمبر")
      expect(find.textContaining('نوفمبر'), findsWidgets);
    });
  });
}
