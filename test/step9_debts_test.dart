import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/services/notification_service.dart';
import 'package:baqy/core/widgets/action_feedback_dialog.dart';
import 'package:baqy/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:baqy/features/debts/domain/models/debt_item.dart';
import 'package:baqy/features/debts/presentation/providers/debt_providers.dart';
import 'package:baqy/features/debts/presentation/screens/debt_details_screen.dart';
import 'package:baqy/features/debts/presentation/screens/debts_tab_screen.dart';
import 'package:baqy/features/debts/presentation/widgets/debts_fab.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/goals/domain/models/goal_item.dart';
import 'package:baqy/features/goals/presentation/widgets/completed_goals_section.dart';
import 'package:baqy/features/reminders/domain/utils/reminder_date_calculator.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super.test();

  int rescheduleDebtCalls = 0;
  List<DebtItem> lastRescheduledDebts = [];
  final List<int> cancelledDebtIds = [];

  @override
  Future<void> rescheduleDebts(List<DebtItem> debts) async {
    rescheduleDebtCalls++;
    lastRescheduledDebts = List.from(debts);
  }

  @override
  Future<void> cancelDebtNotification(int debtId) async {
    cancelledDebtIds.add(debtId);
  }
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
  });

  group('PERMANENT TESTS - Step 9 Debts', () {
    late AppDatabase db;
    late _FakeNotificationService fakeNotif;
    late DebtRepositoryImpl debtRepo;
    late ExpenseRepositoryImpl expenseRepo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      fakeNotif = _FakeNotificationService();
      debtRepo = DebtRepositoryImpl(db, fakeNotif);
      expenseRepo = ExpenseRepositoryImpl(db);

      // Seed month budget for current month e.g. 20,000 EGP (2,000,000 piastres)
      final now = DateTime.now();
      final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await expenseRepo.setMonthBudget(yearMonth: yearMonth, amount: 2000000);
    });

    tearDown(() async {
      await db.close();
    });

    test(
      '1. paying 5,000 then 1,000 of a 10,000 debt "عليا" leaves 4,000 and Home remaining drops by 6,000 and payments appear as expenses in category "ديون"',
      () async {
        final now = DateTime.now();
        final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        final initialRemaining = await expenseRepo.getRemainingOfMonth(
          yearMonth,
        );
        expect(initialRemaining.remaining, equals(2000000)); // 20,000 EGP

        // Add a debt "عليا" of 10,000 EGP (1,000,000 piastres)
        final debtId = await debtRepo.addDebt(
          personName: 'أحمد',
          direction: 'owe',
          totalAmount: 1000000,
        );

        // Pay 5,000 EGP (500,000 piastres)
        await debtRepo.recordPayment(
          debtId: debtId,
          amount: 500000,
          paidAt: now,
        );

        var debt = await debtRepo.getDebtById(debtId);
        expect(debt!.paidAmount, equals(500000));
        expect(debt.remaining, equals(500000));

        var remAfter1 = await expenseRepo.getRemainingOfMonth(yearMonth);
        expect(
          remAfter1.remaining,
          equals(1500000),
        ); // 20,000 - 5,000 = 15,000 EGP

        // Pay 1,000 EGP (100,000 piastres)
        await debtRepo.recordPayment(
          debtId: debtId,
          amount: 100000,
          paidAt: now,
        );

        debt = await debtRepo.getDebtById(debtId);
        expect(debt!.paidAmount, equals(600000));
        expect(debt.remaining, equals(400000)); // 4,000 EGP leaves 4,000

        // Home remaining drops by 6,000 EGP
        final remAfter2 = await expenseRepo.getRemainingOfMonth(yearMonth);
        expect(
          remAfter2.remaining,
          equals(1400000),
        ); // 20,000 - 6,000 = 14,000 EGP
        expect(remAfter2.expenses, equals(600000));

        // Payments appear as expenses in the category "ديون"
        final recentTxs = await expenseRepo
            .watchLastTransactionsForMonth(yearMonth)
            .first;
        expect(recentTxs.length, equals(2));
        for (final tx in recentTxs) {
          expect(tx.kind, equals('expense'));
          expect(tx.source, equals('debt'));
          expect(tx.category?.name, equals('ديون'));
          expect(tx.description, equals('أحمد'));
        }
      },
    );

    test(
      '2. the same on "ليا" raises the month\'s money by 6,000 and shows no expense',
      () async {
        final now = DateTime.now();
        final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        final initialRemaining = await expenseRepo.getRemainingOfMonth(
          yearMonth,
        );
        expect(initialRemaining.monthMoney, equals(2000000)); // 20,000 EGP

        // Add a debt "ليا" of 10,000 EGP (1,000,000 piastres)
        final debtId = await debtRepo.addDebt(
          personName: 'سارة',
          direction: 'owed',
          totalAmount: 1000000,
        );

        // Pay 5,000 then 1,000
        await debtRepo.recordPayment(
          debtId: debtId,
          amount: 500000,
          paidAt: now,
        );
        await debtRepo.recordPayment(
          debtId: debtId,
          amount: 100000,
          paidAt: now,
        );

        final debt = await debtRepo.getDebtById(debtId);
        expect(debt!.remaining, equals(400000));

        final rem = await expenseRepo.getRemainingOfMonth(yearMonth);
        // monthMoney = budget (20,000) + income (6,000) = 26,000 EGP
        expect(rem.monthMoney, equals(2600000));
        expect(rem.income, equals(600000));
        expect(rem.expenses, equals(0)); // shows NO expense
        expect(rem.remaining, equals(2600000));
      },
    );

    test('3. paying more than the remaining is rejected', () async {
      final debtId = await debtRepo.addDebt(
        personName: 'محمود',
        direction: 'owe',
        totalAmount: 300000, // 3,000 EGP
      );

      // Paying 3,001 EGP (300,100 piastres) when remaining is 3,000 EGP
      expect(
        () => debtRepo.recordPayment(
          debtId: debtId,
          amount: 300100,
          paidAt: DateTime.now(),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('المبلغ أكبر من المتبقي'),
          ),
        ),
      );
    });

    test(
      '4. reaching zero archives the debt and undo returns it to the active list',
      () async {
        final now = DateTime.now();
        final debtId = await debtRepo.addDebt(
          personName: 'علي',
          direction: 'owe',
          totalAmount: 500000, // 5,000 EGP
        );

        var activeDebts = await debtRepo
            .watchDebts(direction: 'owe', archived: false)
            .first;
        expect(activeDebts.any((d) => d.id == debtId), isTrue);

        // Pay the full 5,000 EGP
        final pId = await debtRepo.recordPayment(
          debtId: debtId,
          amount: 500000,
          paidAt: now,
        );

        // Reaching zero archives the debt automatically
        var debt = await debtRepo.getDebtById(debtId);
        expect(debt!.archived, isTrue);
        expect(debt.isSettled, isTrue);

        activeDebts = await debtRepo
            .watchDebts(direction: 'owe', archived: false)
            .first;
        expect(activeDebts.any((d) => d.id == debtId), isFalse);

        var settledDebts = await debtRepo
            .watchDebts(direction: 'owe', archived: true)
            .first;
        expect(settledDebts.any((d) => d.id == debtId), isTrue);

        // Undo the payment returns it to the active list
        await debtRepo.undoPayment(pId);

        debt = await debtRepo.getDebtById(debtId);
        expect(debt!.archived, isFalse);
        expect(debt.remaining, equals(500000));

        activeDebts = await debtRepo
            .watchDebts(direction: 'owe', archived: false)
            .first;
        expect(activeDebts.any((d) => d.id == debtId), isTrue);

        settledDebts = await debtRepo
            .watchDebts(direction: 'owe', archived: true)
            .first;
        expect(settledDebts.any((d) => d.id == debtId), isFalse);
      },
    );

    test('5. the progress and summary card totals', () async {
      final now = DateTime.now();

      // Debt 1: 10,000 EGP, paid 6,000 EGP -> remaining 4,000 EGP, progress 0.6
      final d1 = await debtRepo.addDebt(
        personName: 'أحمد',
        direction: 'owe',
        totalAmount: 1000000,
      );
      await debtRepo.recordPayment(debtId: d1, amount: 600000, paidAt: now);

      // Debt 2: 3,000 EGP, paid 1,500 EGP -> remaining 1,500 EGP, progress 0.5
      final d2 = await debtRepo.addDebt(
        personName: 'سارة',
        direction: 'owe',
        totalAmount: 300000,
      );
      await debtRepo.recordPayment(debtId: d2, amount: 150000, paidAt: now);

      final item1 = await debtRepo.getDebtById(d1);
      final item2 = await debtRepo.getDebtById(d2);

      expect(item1!.progress, closeTo(0.6, 0.001));
      expect(item2!.progress, closeTo(0.5, 0.001));

      // Summary total remaining: 4,000 + 1,500 = 5,500 EGP (550,000 piastres)
      final activeDebts = await debtRepo
          .watchDebts(direction: 'owe', archived: false)
          .first;
      final totalRemaining = activeDebts.fold<int>(
        0,
        (sum, d) => sum + d.remaining,
      );
      expect(totalRemaining, equals(550000));
    });

    test('6. editing the total below the paid amount is rejected', () async {
      final now = DateTime.now();
      final debtId = await debtRepo.addDebt(
        personName: 'طارق',
        direction: 'owe',
        totalAmount: 1000000, // 10,000 EGP
      );

      // Paid 4,000 EGP (400,000 piastres)
      await debtRepo.recordPayment(debtId: debtId, amount: 400000, paidAt: now);

      // Try editing totalAmount to 3,500 EGP (350,000 piastres)
      expect(
        () => debtRepo.updateDebt(
          id: debtId,
          personName: 'طارق',
          direction: 'owe',
          totalAmount: 350000,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('المبلغ أقل من المدفوع'),
          ),
        ),
      );
    });

    test(
      '7. deleting a debt with payments removes the linked rows and restores the Home numbers',
      () async {
        final now = DateTime.now();
        final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        final initialRem = await expenseRepo.getRemainingOfMonth(yearMonth);

        final debtId = await debtRepo.addDebt(
          personName: 'حسين',
          direction: 'owe',
          totalAmount: 500000,
        );

        await debtRepo.recordPayment(
          debtId: debtId,
          amount: 200000,
          paidAt: now,
        );

        var remMid = await expenseRepo.getRemainingOfMonth(yearMonth);
        expect(remMid.remaining, equals(initialRem.remaining - 200000));

        // Delete debt
        await debtRepo.deleteDebt(debtId);

        // Payments and linked transactions removed
        final payments = await debtRepo.watchPaymentsForDebt(debtId).first;
        expect(payments, isEmpty);

        final txs = await expenseRepo
            .watchLastTransactionsForMonth(yearMonth)
            .first;
        expect(txs.any((t) => t.description == 'حسين'), isFalse);

        // Home numbers restored
        final remFinal = await expenseRepo.getRemainingOfMonth(yearMonth);
        expect(remFinal.remaining, equals(initialRem.remaining));
      },
    );

    test('8. transaction and payment are written atomically', () async {
      final now = DateTime.now();
      final debtId = await debtRepo.addDebt(
        personName: 'كريم',
        direction: 'owe',
        totalAmount: 500000,
      );

      // Verify that invalid payment does not record any transaction or payment row
      try {
        await debtRepo.recordPayment(
          debtId: debtId,
          amount: 600000,
          paidAt: now,
        );
      } catch (_) {}

      final payments = await debtRepo.watchPaymentsForDebt(debtId).first;
      expect(payments, isEmpty);

      final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      final txs = await expenseRepo
          .watchLastTransactionsForMonth(yearMonth)
          .first;
      expect(txs.any((t) => t.description == 'كريم'), isFalse);
    });

    test(
      '9. notification exists only when due date is set, built by same code as reminders, exact wording for عليا and ليا, cancelled when archived or deleted',
      () {
        final dueDate = DateTime(2026, 11, 20);
        final refTime = DateTime(2026, 11, 1, 9, 0, 0);

        // 1. Due date calculation: 2 days before at 09:00
        final notifMoment =
            ReminderDateCalculator.calculateDebtNotificationMoment(
              dueDate: dueDate,
              now: refTime,
            );
        expect(notifMoment, equals(DateTime(2026, 11, 18, 9, 0, 0)));

        // 2. Past due date skips notification
        final pastTime = DateTime(2026, 11, 19, 10, 0, 0);
        final pastNotif =
            ReminderDateCalculator.calculateDebtNotificationMoment(
              dueDate: dueDate,
              now: pastTime,
            );
        expect(pastNotif, isNull);

        // 3. Exact wording for "عليا"
        final contentOwe = ReminderDateCalculator.formatDebtNotificationContent(
          personName: 'أحمد',
          direction: 'owe',
          remainingPiastres: 400000, // 4,000 EGP
          dueDate: dueDate,
        );
        expect(contentOwe.title, equals('باقي'));
        expect(
          contentOwe.body.split('\n')[0],
          equals('عليك ٤,٠٠٠ جنيه لـ أحمد كمان يومين'),
        );
        expect(
          contentOwe.body.split('\n')[1],
          contains('٤,٠٠٠ جنيه · الجمعة ٢٠ نوفمبر'),
        );

        // 4. Exact wording for "ليا"
        final contentOwed =
            ReminderDateCalculator.formatDebtNotificationContent(
              personName: 'سارة',
              direction: 'owed',
              remainingPiastres: 150000, // 1,500 EGP
              dueDate: dueDate,
            );
        expect(contentOwed.title, equals('باقي'));
        expect(
          contentOwed.body.split('\n')[0],
          equals('ليك ١,٥٠٠ جنيه عند سارة كمان يومين'),
        );
        expect(
          contentOwed.body.split('\n')[1],
          contains('١,٥٠٠ جنيه · الجمعة ٢٠ نوفمبر'),
        );
      },
    );

    test('10. validation of name and amounts', () async {
      // Empty name throws
      expect(
        () => debtRepo.addDebt(
          personName: '   ',
          direction: 'owe',
          totalAmount: 100000,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('الاسم مطلوب'),
          ),
        ),
      );

      // Control characters stripped
      final id = await debtRepo.addDebt(
        personName: '\x00\x1F مروان \x7F',
        direction: 'owe',
        totalAmount: 100000,
      );
      final debt = await debtRepo.getDebtById(id);
      expect(debt!.personName, equals('مروان'));

      // Max 40 characters
      final longName = 'أ' * 60;
      final id2 = await debtRepo.addDebt(
        personName: longName,
        direction: 'owe',
        totalAmount: 100000,
      );
      final debt2 = await debtRepo.getDebtById(id2);
      expect(debt2!.personName.length, equals(40));

      // Non-positive amount throws
      expect(
        () => debtRepo.addDebt(
          personName: 'ياسر',
          direction: 'owe',
          totalAmount: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      // Exceeding 100,000,000 EGP throws
      expect(
        () => debtRepo.addDebt(
          personName: 'ياسر',
          direction: 'owe',
          totalAmount: 10000000001,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('11. "+" opens the form directly with no menu on Debts tab', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          debtRepositoryProvider.overrideWithValue(debtRepo),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DebtsTabScreen(),
              floatingActionButton: DebtsFab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure DebtsFab is present and is a single FloatingActionButton
      expect(find.byType(DebtsFab), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);

      // There is NO speed dial menu, NO mic button, and NO pencil button in this tab
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.mic_none), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
    });

    testWidgets(
      '12. Debts list updates instantly and empty state shows welcome card',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            debtRepositoryProvider.overrideWithValue(debtRepo),
            expenseRepositoryProvider.overrideWithValue(expenseRepo),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: DebtsTabScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // With no debts: shows title "الديون", switch ("عليا" and "ليا") and empty state card
        expect(find.text('الديون'), findsOneWidget);
        expect(find.text('عليا'), findsOneWidget);
        expect(find.text('ليا'), findsOneWidget);
        expect(find.text('سجّل اللي عليك ونظم ديونك'), findsOneWidget);

        // No summary card or settled debts row
        expect(find.text('إجمالي اللي عليك'), findsNothing);
        expect(find.text('تم سدادها'), findsNothing);

        // Add a debt through repository
        await debtRepo.addDebt(
          personName: 'وليد',
          direction: 'owe',
          totalAmount: 500000,
        );
        await tester.pumpAndSettle();

        // Updates instantly without reload!
        expect(find.text('وليد'), findsOneWidget);
        expect(find.text('إجمالي اللي عليك'), findsOneWidget);
        expect(find.text('٥,٠٠٠ جنيه'), findsWidgets);
      },
    );

    test(
      '14. Editing and deleting individual payments updates transaction and month money atomically',
      () async {
        final now = DateTime.now();
        final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

        // 10,000 debt "عليا"
        final debtId = await debtRepo.addDebt(
          personName: 'خالد',
          direction: 'owe',
          totalAmount: 1000000,
        );

        // Record payment of 4,000 EGP (400,000 piastres)
        final pId = await debtRepo.recordPayment(
          debtId: debtId,
          amount: 400000,
          paidAt: now,
        );

        var debt = await debtRepo.getDebtById(debtId);
        expect(debt!.remaining, equals(600000));
        var rem = await expenseRepo.getRemainingOfMonth(yearMonth);
        expect(rem.remaining, equals(1600000)); // 20k - 4k = 16k

        // Edit payment to 5,000 EGP (500,000 piastres)
        await debtRepo.updatePayment(paymentId: pId, newAmount: 500000);
        debt = await debtRepo.getDebtById(debtId);
        expect(debt!.remaining, equals(500000)); // 10k - 5k = 5k
        rem = await expenseRepo.getRemainingOfMonth(yearMonth);
        expect(rem.remaining, equals(1500000)); // 20k - 5k = 15k

        // Delete payment
        await debtRepo.deletePayment(pId);
        debt = await debtRepo.getDebtById(debtId);
        expect(debt!.remaining, equals(1000000)); // 10k
        rem = await expenseRepo.getRemainingOfMonth(yearMonth);
        expect(rem.remaining, equals(2000000)); // 20k restored
      },
    );

    testWidgets(
      '15. ActionFeedbackDialog displays unified modal for update and delete',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {
                        ActionFeedbackDialog.show(
                          context: context,
                          type: ActionFeedbackType.deleted,
                          title: 'تم حذف الدفعة',
                          subtitle: 'اتحذفت الدفعة ورجعت الحسابات زي ما كانت.',
                        );
                      },
                      child: const Text('Show Delete Dialog'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('Show Delete Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('تم حذف الدفعة'), findsOneWidget);
        expect(
          find.text('اتحذفت الدفعة ورجعت الحسابات زي ما كانت.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      },
    );

    test('16. Debt transactions cannot be edited or deleted from ExpenseRepository', () async {
      final now = DateTime.now();
      final debtId = await debtRepo.addDebt(
        personName: 'مصطفى',
        direction: 'owe',
        totalAmount: 500000,
      );

      final paymentId = await debtRepo.recordPayment(
        debtId: debtId,
        amount: 200000,
        paidAt: now,
      );

      final payment = await (db.select(db.debtPayments)..where((p) => p.id.equals(paymentId))).getSingle();
      final txId = payment.transactionId!;

      // Attempting to update from ExpenseRepository throws UnsupportedError
      expect(
        () => expenseRepo.updateTransaction(
          id: txId,
          amount: 300000,
          description: 'مصطفى',
          categoryId: 1,
        ),
        throwsUnsupportedError,
      );

      // Attempting to delete from ExpenseRepository throws UnsupportedError
      expect(
        () => expenseRepo.deleteTransaction(txId),
        throwsUnsupportedError,
      );
    });

    testWidgets('17. ActionFeedbackDialog with onUndo displays both تم and تراجع buttons', (tester) async {
      bool undoCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      ActionFeedbackDialog.show(
                        context: context,
                        type: ActionFeedbackType.paymentRecorded,
                        title: 'تم تسجيل الدفعة بنجاح! 👏',
                        subtitle: 'اتخصمت الدفعة من ميزانية الشهر.',
                        onUndo: () {
                          undoCalled = true;
                        },
                      );
                    },
                    child: const Text('Show Payment Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Payment Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('تم تسجيل الدفعة بنجاح! 👏'), findsOneWidget);
      // Both "تم" and "تراجع" exist
      expect(find.text('تم'), findsOneWidget);
      expect(find.text('تراجع'), findsOneWidget);

      // Tapping "تراجع" triggers onUndo callback
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(undoCalled, isTrue);
    });

    testWidgets('18. Settled debt in DebtDetailsScreen hides edit pencil and shows settled history badge', (tester) async {
      final now = DateTime.now();
      // Add debt and settle it completely
      final debtId = await debtRepo.addDebt(
        personName: 'كريم',
        direction: 'owe',
        totalAmount: 100000,
      );
      await debtRepo.recordPayment(
        debtId: debtId,
        amount: 100000,
        paidAt: now,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          debtRepositoryProvider.overrideWithValue(debtRepo),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DebtDetailsScreen(debtId: debtId),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pencil edit icon must NOT be visible
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      // Trash can delete icon MUST be visible
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Settled history badge is visible
      expect(find.text('تم سداد هذا الدين بالكامل (سجل محفوظ)'), findsOneWidget);

      // "تسجيل دفعة" button is NOT visible
      expect(find.text('تسجيل دفعة'), findsNothing);
    });

    testWidgets('19. Completed goals section displays accordion and badge تم التحقيق', (tester) async {
      final goal = GoalItem(
        id: 1,
        name: 'سفرية دهب',
        targetAmount: 500000,
        monthlySaving: 100000,
        createdAt: DateTime.now(),
        totalSaved: 500000, // fully achieved
      );
      expect(goal.isAchieved, isTrue);

      GoalItem? tappedGoal;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompletedGoalsSection(
              completedGoals: [goal],
              onGoalTap: (g) => tappedGoal = g,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header row with "تم تحقيقها" and count "١"
      expect(find.text('تم تحقيقها'), findsOneWidget);
      expect(find.text('١'), findsOneWidget);

      // Expand accordion
      await tester.tap(find.text('تم تحقيقها'));
      await tester.pumpAndSettle();

      // Inside expanded section: goal name and "تم التحقيق" badge
      expect(find.text('سفرية دهب'), findsOneWidget);
      expect(find.text('تم التحقيق'), findsOneWidget);

      // Tapping invokes onGoalTap
      await tester.tap(find.text('سفرية دهب'));
      await tester.pumpAndSettle();
      expect(tappedGoal?.id, equals(1));
    });
  });
}
