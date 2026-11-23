import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/features/auth/presentation/providers/auth_providers.dart';
import 'package:baqy/features/expenses/domain/models/category_item.dart';
import 'package:baqy/features/expenses/domain/models/month_remaining.dart';
import 'package:baqy/features/expenses/domain/models/month_rollover_info.dart';
import 'package:baqy/features/expenses/domain/models/transaction_item.dart';
import 'package:baqy/features/expenses/domain/repositories/expense_repository.dart';
import 'package:baqy/features/expenses/domain/usecases/check_month_rollover_usecase.dart';
import 'package:baqy/features/expenses/domain/usecases/execute_rollover_usecase.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/expenses/presentation/widgets/month_rollover_dialog.dart';
import 'package:baqy/features/goals/domain/models/goal_item.dart';
import 'package:baqy/features/goals/domain/repositories/goal_repository.dart';
import 'package:baqy/features/goals/presentation/providers/goal_providers.dart';

class _FakeExpenseRepository extends Fake implements ExpenseRepository {
  final Map<String, bool> handledRollovers = {};
  final Map<String, MonthRemaining> monthRemainingMap = {};
  final List<TransactionItem> addedTransactions = [];

  @override
  Future<bool> isMonthRolloverHandled({
    required String previousYearMonth,
    String? userId,
  }) async {
    return handledRollovers['${userId}_$previousYearMonth'] ?? false;
  }

  @override
  Future<void> markMonthRolloverHandled({
    required String previousYearMonth,
    String? userId,
  }) async {
    handledRollovers['${userId}_$previousYearMonth'] = true;
  }

  @override
  Future<MonthRemaining> getRemainingOfMonth(String yearMonth) async {
    return monthRemainingMap[yearMonth] ??
        MonthRemaining(
          yearMonth: yearMonth,
          budget: 0,
          income: 0,
          monthMoney: 0,
          expenses: 0,
          remaining: 0,
        );
  }

  @override
  Future<List<CategoryItem>> getCategories({bool includeArchived = false}) async {
    return [
      const CategoryItem(
        id: 1,
        name: 'استثمار وادخار',
        icon: 'investment',
        color: '0xFF3D7A68',
      ),
    ];
  }

  @override
  Future<int> addTransaction({
    required int amount,
    required String description,
    required int categoryId,
    required String kind,
    required String source,
    required DateTime createdAt,
    String? note,
    double? foreignAmount,
    String? foreignCurrency,
  }) async {
    final tx = TransactionItem(
      id: addedTransactions.length + 1,
      amount: amount,
      description: description,
      categoryId: categoryId,
      kind: kind,
      source: source,
      createdAt: createdAt,
    );
    addedTransactions.add(tx);
    return tx.id;
  }
}

class _FakeGoalRepository extends Fake implements GoalRepository {
  final List<GoalItem> goals = [];
  final List<({int goalId, int amount, DateTime? savedAt})> savings = [];

  @override
  Future<List<GoalItem>> getGoals() async => goals;

  @override
  Future<int> addGoalSaving({
    required int goalId,
    required int amount,
    DateTime? savedAt,
  }) async {
    savings.add((goalId: goalId, amount: amount, savedAt: savedAt));
    return savings.length;
  }
}

class FakeActiveUserIdNotifier extends ActiveUserIdNotifier {
  @override
  String? build() => 'user1';
}

void main() {
  late _FakeExpenseRepository fakeExpenseRepo;
  late _FakeGoalRepository fakeGoalRepo;

  setUp(() {
    fakeExpenseRepo = _FakeExpenseRepository();
    fakeGoalRepo = _FakeGoalRepository();
    MonthRolloverHelper.resetSession();
  });

  group('CheckMonthRolloverUseCase Unit Tests', () {
    test('returns null if already handled', () async {
      final useCase = CheckMonthRolloverUseCase(fakeExpenseRepo);
      fakeExpenseRepo.handledRollovers['user1_2026-10'] = true;

      final result = await useCase(
        currentYearMonth: '2026-11',
        userId: 'user1',
      );
      expect(result, isNull);
    });

    test('returns null and marks handled if previous month has zero remaining', () async {
      final useCase = CheckMonthRolloverUseCase(fakeExpenseRepo);
      fakeExpenseRepo.monthRemainingMap['2026-10'] = const MonthRemaining(
        yearMonth: '2026-10',
        budget: 1000000,
        income: 0,
        monthMoney: 1000000,
        expenses: 1000000,
        remaining: 0,
      );

      final result = await useCase(
        currentYearMonth: '2026-11',
        userId: 'user1',
      );
      expect(result, isNull);
      expect(fakeExpenseRepo.handledRollovers['user1_2026-10'], isTrue);
    });

    test('returns MonthRolloverInfo when previous month has positive remaining', () async {
      final useCase = CheckMonthRolloverUseCase(fakeExpenseRepo);
      // 2,500 EGP remaining (250,000 piastres)
      fakeExpenseRepo.monthRemainingMap['2026-10'] = const MonthRemaining(
        yearMonth: '2026-10',
        budget: 1000000,
        income: 0,
        monthMoney: 1000000,
        expenses: 750000,
        remaining: 250000,
      );

      final result = await useCase(
        currentYearMonth: '2026-11',
        userId: 'user1',
      );

      expect(result, isNotNull);
      expect(result!.previousYearMonth, equals('2026-10'));
      expect(result.currentYearMonth, equals('2026-11'));
      expect(result.previousMonthNumber, equals(10));
      expect(result.currentMonthNumber, equals(11));
      expect(result.leftoverPiastres, equals(250000));
      expect(result.leftoverEgp, equals(2500));
    });

    test('handles year rollover transition (January back to December)', () async {
      final useCase = CheckMonthRolloverUseCase(fakeExpenseRepo);
      fakeExpenseRepo.monthRemainingMap['2026-12'] = const MonthRemaining(
        yearMonth: '2026-12',
        budget: 500000,
        income: 0,
        monthMoney: 500000,
        expenses: 400000,
        remaining: 100000,
      );

      final result = await useCase(
        currentYearMonth: '2027-01',
        userId: 'user1',
      );

      expect(result, isNotNull);
      expect(result!.previousYearMonth, equals('2026-12'));
      expect(result.currentYearMonth, equals('2027-01'));
      expect(result.previousMonthNumber, equals(12));
      expect(result.currentMonthNumber, equals(1));
      expect(result.leftoverEgp, equals(1000));
    });
  });

  group('ExecuteRolloverUseCase Unit Tests', () {
    const sampleInfo = MonthRolloverInfo(
      previousYearMonth: '2026-10',
      currentYearMonth: '2026-11',
      previousMonthNumber: 10,
      currentMonthNumber: 11,
      leftoverPiastres: 250000,
      leftoverEgp: 2500,
    );

    test('transferToCurrentMonth adds income transaction to current month', () async {
      final useCase = ExecuteRolloverUseCase(
        expenseRepository: fakeExpenseRepo,
        goalRepository: fakeGoalRepo,
      );

      await useCase.transferToCurrentMonth(
        info: sampleInfo,
        userId: 'user1',
      );

      expect(fakeExpenseRepo.addedTransactions.length, equals(1));
      expect(fakeExpenseRepo.addedTransactions.first.amount, equals(250000));
      expect(fakeExpenseRepo.addedTransactions.first.kind, equals('income'));
      expect(fakeExpenseRepo.addedTransactions.first.description, equals('باقي من شهر أكتوبر'));
      expect(fakeExpenseRepo.handledRollovers['user1_2026-10'], isTrue);
    });

    test('scenario: leftover from November 2000 EGP added to December, budget 8000 EGP makes total 10000 EGP', () async {
      const novInfo = MonthRolloverInfo(
        previousYearMonth: '2026-11',
        currentYearMonth: '2026-12',
        previousMonthNumber: 11,
        currentMonthNumber: 12,
        leftoverPiastres: 200000, // 2000 EGP
        leftoverEgp: 2000,
      );

      final useCase = ExecuteRolloverUseCase(
        expenseRepository: fakeExpenseRepo,
        goalRepository: fakeGoalRepo,
      );

      await useCase.transferToCurrentMonth(
        info: novInfo,
        userId: 'user1',
      );

      expect(fakeExpenseRepo.addedTransactions.length, equals(1));
      final tx = fakeExpenseRepo.addedTransactions.first;
      expect(tx.amount, equals(200000));
      expect(tx.kind, equals('income'));
      expect(tx.description, equals('باقي من شهر نوفمبر'));

      // Now December budget is set to 8000 EGP (800,000 piastres)
      const int decBudgetPiastres = 800000;
      final int totalIncomePiastres = tx.amount; // 200,000 piastres
      final int totalMonthMoneyPiastres = decBudgetPiastres + totalIncomePiastres;
      expect(totalMonthMoneyPiastres ~/ 100, equals(10000));
    });
  });

  group('MonthRolloverDialog Widget Tests', () {
    const sampleInfo = MonthRolloverInfo(
      previousYearMonth: '2026-10',
      currentYearMonth: '2026-11',
      previousMonthNumber: 10,
      currentMonthNumber: 11,
      leftoverPiastres: 250000,
      leftoverEgp: 2500,
    );

    testWidgets('displays transfer announcement and button "تم" calls onConfirm',
        (tester) async {
      bool confirmCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeUserIdProvider.overrideWith(() => FakeActiveUserIdNotifier()),
            expenseRepositoryProvider.overrideWithValue(fakeExpenseRepo),
            goalRepositoryProvider.overrideWithValue(fakeGoalRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MonthRolloverDialog(
                info: sampleInfo,
                onConfirm: () async {
                  confirmCalled = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify notification content
      expect(find.text('ترحيل متبقي الشهر السابق'), findsOneWidget);
      expect(find.text('٢,٥٠٠ جنيه'), findsOneWidget);
      expect(find.text('متبقي من شهر أكتوبر'), findsOneWidget);
      expect(
        find.textContaining('فيه مبلغ ٢,٥٠٠ جنيه من الشهر اللي فات (أكتوبر) هيتم نقلهم للشهر الجديد (نوفمبر)'),
        findsOneWidget,
      );

      // Verify button "تم"
      final okButton = find.text('تم');
      expect(okButton, findsOneWidget);

      await tester.tap(okButton);
      await tester.pumpAndSettle();

      expect(confirmCalled, isTrue);
    });
  });
}
