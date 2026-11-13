import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/routing/app_router.dart';
import 'package:baqy/core/theme/app_theme.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/l10n/app_localizations.dart';
import 'package:drift/native.dart';

class _FakeSelectedYearMonthNotifier extends SelectedYearMonthNotifier {
  _FakeSelectedYearMonthNotifier(this._initial);
  final String _initial;

  @override
  String build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'REPRODUCE BUG: inserting transactions through repository does not update open screens',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final repository = ExpenseRepositoryImpl(db);
      addTearDown(db.close);

      // Set budget for November 2026: 10,000 EGP (1,000,000 piastres)
      await repository.setMonthBudget(
        yearMonth: '2026-11',
        amount: 1000000,
      );

      // Launch app with real router, starting at Home
      appRouter.go('/main');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            expenseRepositoryProvider.overrideWithValue(repository),
            selectedYearMonthProvider.overrideWith(
              () => _FakeSelectedYearMonthNotifier('2026-11'),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: appRouter,
            locale: const Locale('ar'),
            theme: AppTheme.lightTheme,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Home initially shows 10,000 remaining and 0 spent
      expect(find.text('١٠,٠٠٠ جنيه'), findsOneWidget);
      expect(find.text('صرفت ٠ من ١٠,٠٠٠'), findsOneWidget);

      // Navigate to MonthDetailsScreen
      appRouter.push('/month-details', extra: '2026-11');
      await tester.pumpAndSettle();

      // Verify we are on MonthDetailsScreen (shows "نوفمبر ٢٠٢٦" header)
      expect(find.text('نوفمبر ٢٠٢٦'), findsWidgets);

      // Now insert 2 transactions through the repository on the same day in the same category:
      // Category 1 is 'أكل' (Food)
      final day = DateTime(2026, 11, 5, 12, 0); // Nov 5, 2026
      await repository.addTransaction(
        amount: 15000, // 150 EGP
        description: 'غدا كشري',
        categoryId: 1,
        kind: 'expense',
        source: 'text',
        createdAt: day,
      );

      await repository.addTransaction(
        amount: 7000, // 70 EGP
        description: 'عشا شاورما',
        categoryId: 1, // Same category on same day!
        kind: 'expense',
        source: 'text',
        createdAt: day.add(const Duration(hours: 4)),
      );

      // Pump to allow reactive streams to deliver new data
      await tester.pumpAndSettle();

      // In MonthDetailsScreen:
      // Month chart & Day list must reflect the new total of 220 EGP (22,000 piastres)
      // and NOT stale 0 EGP!
      expect(
        find.text('٢٢٠ جنيه'),
        findsAtLeastNWidgets(1),
        reason: 'Month details should show 220 EGP after inserting 150 + 70 EGP',
      );

      // Tap on 'أكل' category in Day list to open CategoryDetailsScreen
      await tester.tap(find.text('أكل').first);
      await tester.pumpAndSettle();

      // Category Details should show total 220 EGP and both transactions
      expect(
        find.text('٢٢٠ جنيه'),
        findsAtLeastNWidgets(1),
        reason: 'Category details should show 220 EGP total',
      );
      expect(find.text('عشا شاورما'), findsOneWidget);
      expect(find.text('غدا كشري'), findsOneWidget);

      // Go back to MonthDetailsScreen
      await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded).first);
      await tester.pumpAndSettle();

      // Go back to Home
      await tester.tap(find.byIcon(Icons.arrow_forward_ios_rounded).first);
      await tester.pumpAndSettle();

      // In Home screen:
      // Remaining must be updated to 9,780 EGP (10,000 - 220) and spent to 220
      expect(
        find.text('٩,٧٨٠ جنيه'),
        findsOneWidget,
        reason: 'Home ring should immediately show 9,780 EGP remaining',
      );
      expect(
        find.text('صرفت ٢٢٠ من ١٠,٠٠٠'),
        findsOneWidget,
        reason: 'Home ring should show spent 220 of 10,000',
      );

      // Recent transactions in Home must show both newly added items
      expect(find.text('عشا شاورما'), findsOneWidget);
      expect(find.text('غدا كشري'), findsOneWidget);

      // Unmount test app cleanly
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
