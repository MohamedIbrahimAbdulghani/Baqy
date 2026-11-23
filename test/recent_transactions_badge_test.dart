import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/features/expenses/domain/models/category_item.dart';
import 'package:baqy/features/expenses/domain/models/transaction_item.dart';
import 'package:baqy/features/home/presentation/widgets/recent_transactions_section.dart';

void main() {
  group('TransactionItem isAddition & isDeduction Domain Tests', () {
    test('expense transaction is deduction and not addition', () {
      final tx = TransactionItem(
        id: 1,
        amount: 15000, // 150 EGP
        description: 'غدا',
        categoryId: 1,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.now().toUtc(),
      );

      expect(tx.isAddition, isFalse);
      expect(tx.isDeduction, isTrue);
    });

    test('income transaction is addition and not deduction', () {
      final tx = TransactionItem(
        id: 2,
        amount: 50000, // 500 EGP
        description: 'تحصيل دين',
        categoryId: 99,
        kind: 'income',
        source: 'debt',
        createdAt: DateTime.now().toUtc(),
      );

      expect(tx.isAddition, isTrue);
      expect(tx.isDeduction, isFalse);
    });

    test('goal withdrawal (amount < 0) is addition back to cash', () {
      final tx = TransactionItem(
        id: -1,
        amount: -20000, // -200 EGP
        description: 'ايفون',
        categoryId: -1,
        kind: 'saving',
        source: 'goal',
        createdAt: DateTime.now().toUtc(),
      );

      expect(tx.isAddition, isTrue);
      expect(tx.isDeduction, isFalse);
    });

    test('goal saving (amount > 0) is deduction from cash into savings', () {
      final tx = TransactionItem(
        id: -2,
        amount: 30000, // 300 EGP
        description: 'ايفون',
        categoryId: -1,
        kind: 'saving',
        source: 'goal',
        createdAt: DateTime.now().toUtc(),
      );

      expect(tx.isAddition, isFalse);
      expect(tx.isDeduction, isTrue);
    });
  });

  group('RecentTransactionsSection UI Widget Tests', () {
    testWidgets('renders both deposit (إيداع مضافة) and withdrawal (سحب مخصومة) badges correctly',
        (tester) async {
      final now = DateTime.now().toUtc();
      final expenseTx = TransactionItem(
        id: 10,
        amount: 15000, // 150 EGP
        description: 'غدا',
        categoryId: 1,
        kind: 'expense',
        source: 'text',
        createdAt: now,
        category: const CategoryItem(
          id: 1,
          name: 'طعام',
          icon: 'food',
          color: '0xFF4E8B7A',
        ),
      );

      final incomeTx = TransactionItem(
        id: 11,
        amount: 50000, // 500 EGP
        description: 'تحصيل من سارة',
        categoryId: 2,
        kind: 'income',
        source: 'debt',
        createdAt: now,
        category: const CategoryItem(
          id: 2,
          name: 'ديون',
          icon: 'debts',
          color: '0xFF8FA3BD',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: RecentTransactionsSection(
                transactions: [expenseTx, incomeTx],
              ),
            ),
          ),
        ),
      );

      // Section title
      expect(find.text('آخر المصاريف'), findsOneWidget);

      // Descriptions
      expect(find.text('غدا'), findsOneWidget);
      expect(find.text('تحصيل من سارة'), findsOneWidget);

      // Amounts
      expect(find.text('١٥٠ جنيه'), findsOneWidget);
      expect(find.text('٥٠٠ جنيه'), findsOneWidget);

      // Badges: withdrawal and deposit
      expect(find.text('سحب (مخصومة)'), findsOneWidget);
      expect(find.text('إيداع (مضافة)'), findsOneWidget);

      // Icons: minus for withdrawal, plus for deposit
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
    });
  });
}
