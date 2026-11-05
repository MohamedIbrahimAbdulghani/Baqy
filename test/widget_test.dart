import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/utils/arabic_date_helper.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/main.dart';

void main() {
  testWidgets('App renders splash then navigates to main shell', (WidgetTester tester) async {
    final db = AppDatabase(NativeDatabase.memory());

    // Seed a budget for current month so auto-open sheet does not overlay the screen
    final now = DateTime.now();
    final ym = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
    await db.into(db.monthBudgets).insert(
          MonthBudgetsCompanion.insert(
            yearMonth: ym,
            amount: 1000000,
          ),
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const BaqyApp(),
      ),
    );

    // Initial frame on splash screen
    expect(find.text('باقي'), findsOneWidget);
    expect(find.text('BAQY'), findsOneWidget);

    // Wait 2 seconds for splash transition and settle
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Now in Main shell screen:
    expect(find.text('الرئيسية'), findsWidgets);
    expect(find.text('الأهداف'), findsOneWidget);
    expect(find.text('المواعيد'), findsOneWidget);
    expect(find.text('الديون'), findsOneWidget);

    // Tap on "الأهداف"
    await tester.tap(find.text('الأهداف'));
    await tester.pumpAndSettle();

    // Verify "الأهداف" is now shown as tab title
    expect(find.text('الأهداف'), findsWidgets);

    await db.close();
  });
}
