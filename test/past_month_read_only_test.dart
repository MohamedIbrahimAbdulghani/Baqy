import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/core/utils/arabic_date_helper.dart';
import 'package:baqy/features/expenses/domain/models/transaction_item.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/expenses/presentation/widgets/transaction_actions_sheet.dart';
import 'package:baqy/features/home/presentation/widgets/budget_ring.dart';

void main() {
  group('Past Month Read-Only Rules Tests', () {
    test('isViewingPastMonthProvider correctly identifies past months', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final now = DateTime.now();
      final currentYm = ArabicDateHelper.formatYearMonthKey(now.year, now.month);

      // Initially on current month
      expect(container.read(selectedYearMonthProvider), equals(currentYm));
      expect(container.read(isViewingPastMonthProvider), isFalse);

      // Switch to a previous year/month (e.g. 2020-01)
      container.read(selectedYearMonthProvider.notifier).selectYearMonth('2020-01');
      expect(container.read(isViewingPastMonthProvider), isTrue);

      // Switch to future month (e.g. 2099-12)
      container.read(selectedYearMonthProvider.notifier).selectYearMonth('2099-12');
      expect(container.read(isViewingPastMonthProvider), isFalse);
    });

    test('TransactionActionsHelper.isTransactionFromPastMonth identifies past transactions', () {
      final now = DateTime.now();
      final currentTx = TransactionItem(
        id: 1,
        amount: 5000,
        description: 'غداء اليوم',
        categoryId: 1,
        kind: 'expense',
        source: 'manual',
        createdAt: now,
      );

      final pastTx = TransactionItem(
        id: 2,
        amount: 15000,
        description: 'فاتورة قديمة',
        categoryId: 1,
        kind: 'expense',
        source: 'manual',
        createdAt: DateTime(2020, 1, 15),
      );

      expect(TransactionActionsHelper.isTransactionFromPastMonth(currentTx), isFalse);
      expect(TransactionActionsHelper.isTransactionFromPastMonth(pastTx), isTrue);
    });

    testWidgets('BudgetRing shows archive icon and disables edit icon when isReadOnly is true',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BudgetRing(
              remainingPiastres: 50000,
              spentPiastres: 25000,
              monthMoneyPiastres: 75000,
              isReadOnly: true,
              onTap: () {},
            ),
          ),
        ),
      );

      // Edit pencil icon should NOT be visible
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      // Archive lock/archive icon SHOULD be visible
      expect(find.byIcon(Icons.archive_outlined), findsOneWidget);
    });

    testWidgets('TransactionActionsHelper.showActionsBottomSheet shows archive card for past transaction',
        (tester) async {
      final pastTx = TransactionItem(
        id: 99,
        amount: 30000,
        description: 'شراء قديم',
        categoryId: 1,
        kind: 'expense',
        source: 'manual',
        createdAt: DateTime(2021, 5, 10),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  return ElevatedButton(
                    onPressed: () {
                      TransactionActionsHelper.showActionsBottomSheet(
                        context: context,
                        ref: ref,
                        transaction: pastTx,
                      );
                    },
                    child: const Text('افتح'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('افتح'));
      await tester.pumpAndSettle();

      // Verify the archive read-only card is shown
      expect(find.text('شهر مؤرشف (للاطلاع فقط)'), findsOneWidget);
      expect(
        find.textContaining('هذه المعاملة تنتمي لشهر سابق تم قفله وأرشفته'),
        findsOneWidget,
      );

      // Edit and Delete actions must NOT be present
      expect(find.text('تعديل العملية'), findsNothing);
      expect(find.text('حذف العملية'), findsNothing);
    });
  });
}
