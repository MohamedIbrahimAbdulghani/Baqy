import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/routing/app_router.dart';
import 'package:baqy/core/theme/app_theme.dart';
import 'package:baqy/core/utils/arabic_date_helper.dart';
import 'package:baqy/core/utils/number_formatter.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/goals/domain/models/goal_item.dart';
import 'package:baqy/features/goals/presentation/providers/goal_providers.dart';
import 'package:baqy/features/home/presentation/widgets/home_speed_dial_fab.dart';
import 'package:baqy/features/shell/presentation/widgets/custom_bottom_nav_bar.dart';
import 'package:baqy/l10n/app_localizations.dart';

class _FakeSelectedYearMonthNotifier extends SelectedYearMonthNotifier {
  _FakeSelectedYearMonthNotifier(this._initial);
  final String _initial;

  @override
  String build() => _initial;
}

void main() {
  group('Step 3 Unit Tests: NumberFormatter & ArabicDateHelper', () {
    test('NumberFormatter formats currency with Arabic-Indic digits and commas', () {
      expect(NumberFormatter.formatCurrency(9000), equals('٩,٠٠٠'));
      expect(NumberFormatter.formatCurrency(10000), equals('١٠,٠٠٠'));
      expect(NumberFormatter.formatCurrency(150), equals('١٥٠'));
      expect(NumberFormatter.formatCurrency(0), equals('٠'));
    });

    test('NumberFormatter parses positive integers safely from Arabic and English input', () {
      expect(NumberFormatter.parsePositiveInteger('١٠,٠٠٠'), equals(10000));
      expect(NumberFormatter.parsePositiveInteger('10,000'), equals(10000));
      expect(NumberFormatter.parsePositiveInteger('150'), equals(150));
      expect(NumberFormatter.parsePositiveInteger('١٥٠'), equals(150));
      expect(NumberFormatter.parsePositiveInteger('0'), isNull);
      expect(NumberFormatter.parsePositiveInteger('٠'), isNull);
      expect(NumberFormatter.parsePositiveInteger('-50'), isNull);
      expect(NumberFormatter.parsePositiveInteger(''), isNull);
      expect(NumberFormatter.parsePositiveInteger('abc'), isNull);
    });

    test('ArabicDateHelper formats and parses dates correctly', () {
      expect(ArabicDateHelper.getMonthName(11), equals('نوفمبر'));
      expect(ArabicDateHelper.getMonthName(1), equals('يناير'));
      expect(ArabicDateHelper.formatMonthYear(2026, 11), equals('نوفمبر ٢٠٢٦'));
      expect(ArabicDateHelper.formatYearMonthKey(2026, 11), equals('2026-11'));
      expect(ArabicDateHelper.getPreviousYearMonth('2026-11'), equals('2026-10'));
      expect(ArabicDateHelper.getPreviousYearMonth('2026-01'), equals('2025-12'));
    });
  });

  group('Step 3 Database Queries: Month-Specific Transactions & Available Years/Months', () {
    late AppDatabase db;
    late ExpenseRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = ExpenseRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('getLastTransactionsForMonth isolates queries to the requested month', () async {
      final categories = await repository.getCategories();
      final foodId = categories.firstWhere((c) => c.name == 'أكل').id;

      // Add 2 transactions in November 2026
      await repository.addTransaction(
        amount: 15000, // 150 EGP
        description: 'غدا',
        categoryId: foodId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 2, 14, 0),
      );
      await repository.addTransaction(
        amount: 12000, // 120 EGP
        description: 'مواصلات',
        categoryId: foodId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 3, 16, 0),
      );

      // Add 1 transaction in October 2026
      await repository.addTransaction(
        amount: 8000,
        description: 'سوبرماركت',
        categoryId: foodId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 10, 15, 10, 0),
      );

      final novTransactions = await repository.getLastTransactionsForMonth('2026-11', limit: 3);
      expect(novTransactions.length, equals(2));
      expect(novTransactions.first.description, equals('مواصلات'));
      expect(novTransactions[1].description, equals('غدا'));

      final octTransactions = await repository.getLastTransactionsForMonth('2026-10', limit: 3);
      expect(octTransactions.length, equals(1));
      expect(octTransactions.first.description, equals('سوبرماركت'));
    });

    test('getYearsWithData returns unique years ascending including current year', () async {
      final categories = await repository.getCategories();
      final catId = categories.first.id;

      // Add transaction in 2024
      await repository.addTransaction(
        amount: 5000,
        description: 'قديم',
        categoryId: catId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2024, 5, 1),
      );

      // Add budget in 2025
      await repository.setMonthBudget(yearMonth: '2025-06', amount: 500000);

      final years = await repository.getYearsWithData(currentYear: 2026);
      expect(years, equals([2024, 2025, 2026]));
    });

    test('getMonthsWithData returns months that have data in a given year', () async {
      final categories = await repository.getCategories();
      final catId = categories.first.id;

      await repository.addTransaction(
        amount: 5000,
        description: 'سبتمبر',
        categoryId: catId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 9, 10),
      );
      await repository.setMonthBudget(yearMonth: '2026-11', amount: 1000000);

      final months = await repository.getMonthsWithData(2026);
      expect(months.contains(9), isTrue);
      expect(months.contains(11), isTrue);
      expect(months.contains(1), isFalse);
    });
  });

  group('Step 3 Widget Tests: Home Screen, Ring, Popups, Speed Dial & Budget Sheet', () {
    late AppDatabase db;
    late ExpenseRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = ExpenseRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    Widget createTestApp({String? initialMonth}) {
      return ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          expenseRepositoryProvider.overrideWithValue(repository),
          goalsStreamProvider.overrideWith((ref) => Stream.value(<GoalItem>[])),
          if (initialMonth != null)
            selectedYearMonthProvider
                .overrideWith(() => _FakeSelectedYearMonthNotifier(initialMonth)),
        ],
        child: MaterialApp.router(
          routerConfig: appRouter,
          locale: const Locale('ar'),
          theme: AppTheme.lightTheme,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      );
    }

    testWidgets('Home displays exact top row texts, center ring, and last 3 transactions',
        (WidgetTester tester) async {
      final categories = await repository.getCategories();
      final foodId = categories.firstWhere((c) => c.name == 'أكل').id;
      final transportId = categories.firstWhere((c) => c.name == 'مواصلات').id;
      final charityId = categories.firstWhere((c) => c.name == 'صدقات').id;

      // Seed budget: 10,000 EGP
      await repository.setMonthBudget(yearMonth: '2026-11', amount: 1000000);

      // Seed 3 transactions matching screenshot:
      // 1. غدا: 150 EGP
      // 2. مواصلات: 120 EGP
      // 3. صدقة: 50 EGP
      await repository.addTransaction(
        amount: 5000, // 50 EGP
        description: 'صدقة',
        categoryId: charityId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 1, 10, 0),
      );
      await repository.addTransaction(
        amount: 12000, // 120 EGP
        description: 'مواصلات',
        categoryId: transportId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 2, 11, 0),
      );
      await repository.addTransaction(
        amount: 15000, // 150 EGP
        description: 'غدا',
        categoryId: foodId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 3, 14, 0),
      );

      // Total expenses = 320 EGP -> Remaining = 9,680 EGP
      await tester.pumpWidget(createTestApp(initialMonth: '2026-11'));
      await tester.pump(const Duration(seconds: 2)); // splash to main
      await tester.pumpAndSettle();

      // Verify exact Top Row items:
      expect(find.text('صباح الخير'), findsOneWidget);
      expect(find.text('نوفمبر ٢٠٢٦'), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);

      // Verify Center Ring content:
      expect(find.text('٩,٦٨٠ جنيه'), findsOneWidget);
      expect(find.text('الباقي لك الشهر ده'), findsOneWidget);
      expect(find.text('صرفت ٣٢٠ من ١٠,٠٠٠'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);

      // Verify "آخر المصاريف" section:
      expect(find.text('آخر المصاريف'), findsOneWidget);
      expect(find.text('غدا'), findsOneWidget);
      expect(find.text('١٥٠ جنيه'), findsOneWidget);
      expect(find.text('مواصلات'), findsOneWidget);
      expect(find.text('١٢٠ جنيه'), findsOneWidget);
      expect(find.text('صدقة'), findsOneWidget);
      expect(find.text('٥٠ جنيه'), findsOneWidget);
    });

    testWidgets('"+" speed dial expands to mic and pencil without text and "+" becomes "x"',
        (WidgetTester tester) async {
      await repository.setMonthBudget(yearMonth: '2026-11', amount: 1000000);

      await tester.pumpWidget(createTestApp(initialMonth: '2026-11'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Initially closed: "+" icon is visible
      expect(find.byIcon(Icons.add), findsOneWidget);

      // Tap "+" button to open
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Now expanded: mic and pencil icons are present, NO text
      expect(find.byIcon(Icons.mic_none_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);

      // Tap mic button
      await tester.tap(find.byIcon(Icons.mic_none_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byIcon(Icons.stop_rounded).evaluate().isNotEmpty) {
        await tester.tap(find.byIcon(Icons.stop_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
    });

    testWidgets('Years and Months popup flow and navigation to blank page',
        (WidgetTester tester) async {
      // Seed data in 2025 and 2026
      await repository.setMonthBudget(yearMonth: '2025-10', amount: 500000);
      await repository.setMonthBudget(yearMonth: '2026-11', amount: 1000000);

      await tester.pumpWidget(createTestApp(initialMonth: '2026-11'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Tap month selector "نوفمبر ٢٠٢٦"
      await tester.tap(find.text('نوفمبر ٢٠٢٦'));
      await tester.pumpAndSettle();

      // Years popup opens: shows 2025 and 2026
      expect(find.text('٢٠٢٥'), findsOneWidget);
      expect(find.text('٢٠٢٦'), findsOneWidget);

      // Tap year 2026 to open months grid
      await tester.tap(find.text('٢٠٢٦'));
      await tester.pumpAndSettle();

      // Months popup: shows grid with 12 months
      expect(find.text('يناير'), findsOneWidget);
      expect(find.text('فبراير'), findsOneWidget);
      expect(find.text('نوفمبر'), findsOneWidget);

      // Tap active month "نوفمبر"
      await tester.tap(find.text('نوفمبر'));
      await tester.pumpAndSettle();

      // Month details opens with title "نوفمبر ٢٠٢٦" and back arrow
      expect(find.text('نوفمبر ٢٠٢٦'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsWidgets);

      // Tap back arrow returns to home
      await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('صباح الخير'), findsOneWidget);
    });

    testWidgets('Budget bottom sheet auto-opens when month has no budget and validates input',
        (WidgetTester tester) async {
      // Previous month (2026-10) had budget 8,000 EGP
      await repository.setMonthBudget(yearMonth: '2026-10', amount: 800000);
      // Current month (2026-11) has NO budget

      await tester.pumpWidget(createTestApp(initialMonth: '2026-11'));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pumpAndSettle();

      // Auto-opened bottom sheet: "ميزانية شهر نوفمبر"
      expect(find.text('ميزانية شهر نوفمبر'), findsOneWidget);
      expect(
        find.text('اكتب مرتبك أو دخلك المتاح الشهر ده، تقدر تغيّره في أي وقت بالضغط على الحلقة.'),
        findsOneWidget,
      );
      expect(find.text('المبلغ المتاح بالجنيه'), findsOneWidget);

      // Pre-filled with last month's budget: "٨,٠٠٠"
      expect(find.text('٨,٠٠٠'), findsOneWidget);

      // Tap "حفظ"
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      // Bottom sheet dismissed, ring now shows 8,000 EGP budget
      final budget = await repository.getMonthBudget('2026-11');
      expect(budget, equals(800000));
      expect(find.text('٨,٠٠٠ جنيه'), findsOneWidget);
    });

    testWidgets('"+" button sits completely ABOVE the bottom bar with clear gap on small and large screens',
        (WidgetTester tester) async {
      await repository.setMonthBudget(yearMonth: '2026-11', amount: 1000000);

      for (final screenSize in [const Size(320, 568), const Size(430, 932)]) {
        tester.view.physicalSize = screenSize;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestApp(initialMonth: '2026-11'));
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Find the plus icon and the bottom navigation bar
        final fabFinder = find.byType(HomeSpeedDialFab);
        final navBarFinder = find.byType(CustomBottomNavBar);

        expect(fabFinder, findsOneWidget);
        expect(navBarFinder, findsOneWidget);

        final Rect fabRect = tester.getRect(fabFinder);
        final Rect navBarRect = tester.getRect(navBarFinder);

        // 1. The "+" button must be horizontally centered
        final double screenCenter = screenSize.width / 2.0;
        expect((fabRect.center.dx - screenCenter).abs(), lessThan(1.0));

        // 2. The "+" button must sit ABOVE the bottom bar with a clear gap
        expect(fabRect.bottom, lessThan(navBarRect.top));
        final double gap = navBarRect.top - fabRect.bottom;
        expect(gap, greaterThanOrEqualTo(10.0)); // clear visible gap

        // 3. Tab text in the bottom bar must be completely unobstructed
        for (final tabTitle in ['الرئيسية', 'الأهداف', 'المواعيد', 'الديون']) {
          final tabRect = tester.getRect(find.text(tabTitle));
          expect(fabRect.overlaps(tabRect), isFalse);
        }

        // 4. Tap "+" to expand: mic and pencil buttons must also sit completely ABOVE the bottom bar
        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();

        final Rect openFabRect = tester.getRect(fabFinder);
        // The bottom of the main "x" button must still be ABOVE the bottom bar with clear gap
        expect(openFabRect.bottom, lessThan(navBarRect.top));
        final double openGap = navBarRect.top - openFabRect.bottom;
        expect(openGap, greaterThanOrEqualTo(10.0));

        // Close it again
        await tester.tap(find.byIcon(Icons.mic_none_rounded));
        await tester.pumpAndSettle();
      }
    });
  });
}
