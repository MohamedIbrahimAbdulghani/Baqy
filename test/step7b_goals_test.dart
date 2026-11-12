// ignore_for_file: depend_on_referenced_packages
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/theme/app_theme.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:baqy/features/goals/domain/parser/egyptian_goal_parser.dart';
import 'package:baqy/features/goals/domain/repositories/goal_repository.dart';
import 'package:baqy/features/goals/presentation/providers/goal_providers.dart';
import 'package:baqy/features/goals/presentation/screens/goal_details_screen.dart';
import 'package:baqy/features/shell/presentation/screens/main_shell_screen.dart';
import 'package:baqy/l10n/app_localizations.dart';

Widget createTestApp(ProviderContainer container, {Widget? home}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.lightTheme,
      home: home ?? const MainShellScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A) Egyptian Goal Voice Parser Tests (10 Egyptian Sentences)', () {
    test('1. "عايز اجيب ايفون بمية الف" -> name: "ايفون", target: 100,000', () {
      final res = EgyptianGoalParser.parse('عايز اجيب ايفون بمية الف');
      expect(res, isNotNull);
      expect(res!.name, 'ايفون');
      expect(res.targetAmount, 100000);
    });

    test('2. "نفسي اشتري عربية ب 300 الف" -> name: "عربية", target: 300,000', () {
      final res = EgyptianGoalParser.parse('نفسي اشتري عربية ب 300 الف');
      expect(res, isNotNull);
      expect(res!.name, 'عربية');
      expect(res.targetAmount, 300000);
    });

    test('3. "عايز احوش ميتين الف للشقة" -> name: "شقة" / "الشقة", target: 200,000', () {
      final res = EgyptianGoalParser.parse('عايز احوش ميتين الف للشقة');
      expect(res, isNotNull);
      expect(res!.name.contains('شقة'), isTrue);
      expect(res.targetAmount, 200000);
    });

    test('4. "لابتوب جديد باربعين الف" -> name: "لابتوب جديد", target: 40,000', () {
      final res = EgyptianGoalParser.parse('لابتوب جديد باربعين الف');
      expect(res, isNotNull);
      expect(res!.name, 'لابتوب جديد');
      expect(res.targetAmount, 40000);
    });

    test('5. "بلايستيشن 5 بخمسة وتلاتين الف جنيه" -> name: "بلايستيشن 5", target: 35,000', () {
      final res = EgyptianGoalParser.parse('بلايستيشن 5 بخمسة وتلاتين الف جنيه');
      expect(res, isNotNull);
      expect(res!.name, 'بلايستيشن 5');
      expect(res.targetAmount, 35000);
    });

    test('6. "عايز اسافر دهب ب 8000" -> name: "دهب" or "اسافر دهب", target: 8,000', () {
      final res = EgyptianGoalParser.parse('عايز اسافر دهب ب 8000');
      expect(res, isNotNull);
      expect(res!.name.contains('دهب'), isTrue);
      expect(res.targetAmount, 8000);
    });

    test('7. "غسالة بعشرين الف" -> name: "غسالة", target: 20,000', () {
      final res = EgyptianGoalParser.parse('غسالة بعشرين الف');
      expect(res, isNotNull);
      expect(res!.name, 'غسالة');
      expect(res.targetAmount, 20000);
    });

    test('8. "تلفزيون سامسونج بخمستاشر الف" -> name: "تلفزيون سامسونج", target: 15,000', () {
      final res = EgyptianGoalParser.parse('تلفزيون سامسونج بخمستاشر الف');
      expect(res, isNotNull);
      expect(res!.name, 'تلفزيون سامسونج');
      expect(res.targetAmount, 15000);
    });

    test('9. "ساعة ابل بعشرين الف جنيه" -> name: "ساعة ابل", target: 20,000', () {
      final res = EgyptianGoalParser.parse('ساعة ابل بعشرين الف جنيه');
      expect(res, isNotNull);
      expect(res!.name, 'ساعة ابل');
      expect(res.targetAmount, 20000);
    });

    test('10. "عجلة ب 5000 جنيه" -> name: "عجلة", target: 5,000', () {
      final res = EgyptianGoalParser.parse('عجلة ب 5000 جنيه');
      expect(res, isNotNull);
      expect(res!.name, 'عجلة');
      expect(res.targetAmount, 5000);
    });

    test('Negative: Sentence without amount returns null', () {
      final res = EgyptianGoalParser.parse('صباح الخير ازيكم جميعا');
      expect(res, isNull);
    });

    test('Negative: Category name alone is rejected (never use expense category)', () {
      final res = EgyptianGoalParser.parse('ملابس ب 5000');
      expect(res, isNull);
    });
  });

  group('D) Financial Invariants: Saving into Goal & Reactive Remaining', () {
    late AppDatabase db;
    late GoalRepository goalRepo;
    late ExpenseRepositoryImpl expenseRepo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      goalRepo = GoalRepositoryImpl(db);
      expenseRepo = ExpenseRepositoryImpl(db);

      // Seed current month budget: 10,000 EGP (1,000,000 piastres)
      await expenseRepo.setMonthBudget(
        yearMonth: '2026-11',
        amount: 1000000,
      );

      // Seed an expense: 1,000 EGP (100,000 piastres)
      await expenseRepo.addTransaction(
        amount: 100000,
        description: 'غداء',
        categoryId: 1,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 5, 12, 0),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Saving 2,000 into a goal reduces this month remaining immediately and updates goal percentage', () async {
      // 1. Initial state check: monthMoney = 10,000 EGP, expenses = 1,000 EGP -> remaining = 9,000 EGP
      final initialRem = await expenseRepo.getRemainingOfMonth('2026-11');
      expect(initialRem.budget, 1000000);
      expect(initialRem.expenses, 100000);
      expect(initialRem.goalSavings, 0);
      expect(initialRem.remaining, 900000); // 9,000 EGP

      // 2. Add goal: "ايفون", target 5,000 EGP (500,000 piastres)
      final goalId = await goalRepo.addGoal(
        name: 'ايفون',
        targetAmount: 500000,
      );

      var goal = await goalRepo.getGoalById(goalId);
      expect(goal, isNotNull);
      expect(goal!.totalSaved, 0);
      expect(goal.percentage, 0);
      expect(goal.progress, 0.0);

      // 3. Save 2,000 EGP (200,000 piastres) into the goal
      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 200000,
        savedAt: DateTime.utc(2026, 11, 10, 10, 0),
      );

      // 4. Remaining reduces immediately by 2,000 EGP (200,000 piastres)
      final updatedRem = await expenseRepo.getRemainingOfMonth('2026-11');
      expect(updatedRem.budget, 1000000);
      expect(updatedRem.expenses, 100000); // Expenses remain ONLY 1,000 EGP
      expect(updatedRem.goalSavings, 200000); // Goal savings tracked
      expect(updatedRem.remaining, 700000); // 7,000 EGP remaining (10,000 - 1,000 - 2,000)

      // 5. Goal percentage & progress updated immediately
      goal = await goalRepo.getGoalById(goalId);
      expect(goal!.totalSaved, 200000);
      expect(goal.totalSavedEgp, 2000);
      expect(goal.percentage, 40); // 2,000 / 5,000 = 40%
      expect(goal.progress, 0.4);
    });

    test('Savings appear as virtual category "تحويش" in recent transactions but never counted as expenses in X', () async {
      final goalId = await goalRepo.addGoal(
        name: 'شقة',
        targetAmount: 10000000,
      );

      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 300000, // 3,000 EGP
        savedAt: DateTime.utc(2026, 11, 12, 10, 0),
      );

      // Transactions list contains both the expense and the goal saving
      final txs = await expenseRepo.getLastTransactionsForMonth('2026-11');
      expect(txs.length, 2);
      expect(txs.any((t) => t.description == 'غداء' && t.amount == 100000), isTrue);
      expect(txs.any((t) => t.description == 'شقة' && t.amount == 300000 && t.category?.name == 'تحويش'), isTrue);

      // Total expenses remain strictly 1,000 EGP (savings are not expenses)
      final rem = await expenseRepo.getRemainingOfMonth('2026-11');
      expect(rem.expenses, 100000);
      expect(rem.goalSavings, 300000);
      expect(rem.remaining, 600000); // 10,000 - 1,000 - 3,000 = 6,000 EGP
    });

    test('Deleting a goal with savings returns the money to the remaining immediately', () async {
      final goalId = await goalRepo.addGoal(
        name: 'رحلة',
        targetAmount: 500000,
      );

      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 200000, // 2,000 EGP
        savedAt: DateTime.utc(2026, 11, 10),
      );

      var rem = await expenseRepo.getRemainingOfMonth('2026-11');
      expect(rem.remaining, 700000); // 7,000 EGP

      // Delete the goal
      await goalRepo.deleteGoal(goalId);

      // Goal is deleted
      final deletedGoal = await goalRepo.getGoalById(goalId);
      expect(deletedGoal, isNull);

      // Savings are removed and remaining immediately returns to 9,000 EGP
      rem = await expenseRepo.getRemainingOfMonth('2026-11');
      expect(rem.goalSavings, 0);
      expect(rem.remaining, 900000); // 9,000 EGP restored!
    });

    test('Editing target below already saved amount throws ArgumentError', () async {
      final goalId = await goalRepo.addGoal(
        name: 'موبايل',
        targetAmount: 500000, // 5,000 EGP
      );

      await goalRepo.addGoalSaving(
        goalId: goalId,
        amount: 300000, // 3,000 EGP saved
      );

      // Attempting to reduce target to 2,000 EGP (< 3,000 EGP saved) must throw
      expect(
        () => goalRepo.updateGoal(
          id: goalId,
          name: 'موبايل',
          targetAmount: 200000, // 2,000 EGP
        ),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          'المبلغ لا يمكن أن يقل عن المحوّش',
        )),
      );

      // Valid update (>= 3,000 EGP) succeeds
      await goalRepo.updateGoal(
        id: goalId,
        name: 'موبايل جديد',
        targetAmount: 400000, // 4,000 EGP
      );

      final updated = await goalRepo.getGoalById(goalId);
      expect(updated!.name, 'موبايل جديد');
      expect(updated.targetEgp, 4000);
      expect(updated.totalSavedEgp, 3000);
      expect(updated.percentage, 75); // 3,000 / 4,000 = 75%
    });
  });

  group('Migration Test (v4 -> v5)', () {
    test('Drift migration preserves all existing data and creates goal_savings', () async {
      final tempDir = await Directory.systemTemp.createTemp('baqy_mig_v5_');
      final dbFile = File('${tempDir.path}/test_v4.sqlite');

      // 1. Build a real v4 SQLite database
      final raw = sqlite3.open(dbFile.path);
      raw.execute('PRAGMA user_version = 4;');
      raw.execute('''
        CREATE TABLE categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL,
          icon TEXT NOT NULL,
          color TEXT NOT NULL,
          is_default INTEGER NOT NULL DEFAULT 0,
          is_archived INTEGER NOT NULL DEFAULT 0
        );
      ''');
      raw.execute('''
        CREATE TABLE transactions (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          amount INTEGER NOT NULL,
          description TEXT NOT NULL,
          category_id INTEGER NOT NULL REFERENCES categories (id),
          kind TEXT NOT NULL,
          source TEXT NOT NULL,
          note TEXT,
          created_at INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE month_budgets (
          year_month TEXT NOT NULL PRIMARY KEY,
          amount INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE goals (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          name TEXT NOT NULL,
          target_amount INTEGER NOT NULL,
          monthly_saving INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        );
      ''');
      raw.execute('''
        CREATE TABLE user_rules (
          id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
          pattern TEXT NOT NULL,
          category_id INTEGER NOT NULL REFERENCES categories (id),
          created_at INTEGER NOT NULL
        );
      ''');

      // Seed v4 data
      raw.execute('''
        INSERT INTO categories (id, name, icon, color, is_default, is_archived) VALUES
        (1, 'أكل', 'food', '#4E8B7A', 1, 0);
      ''');
      raw.execute('''
        INSERT INTO transactions (id, amount, description, category_id, kind, source, note, created_at) VALUES
        (1, 5000, 'فطار', 1, 'expense', 'manual', NULL, 1730900000);
      ''');
      raw.execute('''
        INSERT INTO month_budgets (year_month, amount) VALUES ('2026-11', 800000);
      ''');
      raw.execute('''
        INSERT INTO goals (id, name, target_amount, monthly_saving, created_at) VALUES
        (1, 'ايفون', 10000000, 200000, 1730900000);
      ''');

      raw.close();

      // 2. Open with AppDatabase (v5) - executes onUpgrade from 4 to 5
      final v5Db = AppDatabase(NativeDatabase(dbFile));

      // Verify PRAGMA user_version is 5
      expect(v5Db.schemaVersion, 5);

      // Check existing goal is preserved
      final goals = await v5Db.select(v5Db.goals).get();
      expect(goals.length, 1);
      expect(goals.first.name, 'ايفون');
      expect(goals.first.targetAmount, 10000000);
      expect(goals.first.monthlySaving, 200000);

      // Check existing transactions & budgets are preserved
      final txs = await v5Db.select(v5Db.transactions).get();
      expect(txs.length, 1);
      expect(txs.first.description, 'فطار');

      final budgets = await v5Db.select(v5Db.monthBudgets).get();
      expect(budgets.length, 1);
      expect(budgets.first.amount, 800000);

      // Check goal_savings table was created and can be queried
      final savings = await v5Db.select(v5Db.goalSavings).get();
      expect(savings, isEmpty);

      // Can insert into goal_savings
      await v5Db.into(v5Db.goalSavings).insert(
        GoalSavingsCompanion.insert(
          goalId: 1,
          amount: 50000,
          savedAt: DateTime.now().toUtc(),
        ),
      );

      final updatedSavings = await v5Db.select(v5Db.goalSavings).get();
      expect(updatedSavings.length, 1);
      expect(updatedSavings.first.amount, 50000);

      await v5Db.close();
      tempDir.deleteSync(recursive: true);
    });
  });

  group('B & C) UI Widget Tests: Edit, Delete, and "حوّشت" Bottom Sheet', () {
    late AppDatabase db;
    late GoalRepository repository;
    late ExpenseRepositoryImpl expenseRepo;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = GoalRepositoryImpl(db);
      expenseRepo = ExpenseRepositoryImpl(db);

      // Seed month budget: 10,000 EGP, 0 expenses -> remaining = 10,000 EGP
      await expenseRepo.setMonthBudget(
        yearMonth: '2026-11',
        amount: 1000000,
      );
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Goal Details: top bar has pencil (edit) and trash (delete) icons', (tester) async {
      final goalId = await repository.addGoal(
        name: 'ايفون',
        targetAmount: 10000000,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createTestApp(
          container,
          home: GoalDetailsScreen(goalId: goalId),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar icons
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);

      // Button "حوّشت" is visible
      expect(find.widgetWithText(ElevatedButton, 'حوّشت'), findsOneWidget);
    });

    testWidgets('Delete Goal: shows dialog with exact texts, cancels or deletes and navigates back', (tester) async {
      final goalId = await repository.addGoal(
        name: 'لابتوب',
        targetAmount: 5000000,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createTestApp(
          container,
          home: GoalDetailsScreen(goalId: goalId),
        ),
      );
      await tester.pumpAndSettle();

      // Tap trash icon
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Dialog opens with exact texts
      expect(find.text('حذف الهدف؟'), findsOneWidget);
      expect(find.text('هيتحذف الهدف وكل اللي حوّشته فيه هيرجع للباقي.'), findsOneWidget);
      expect(find.text('إلغاء'), findsOneWidget);
      expect(find.text('حذف'), findsOneWidget);

      // Tap "إلغاء"
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // Dialog closed, goal still exists
      expect(find.text('حذف الهدف؟'), findsNothing);
      expect(await repository.getGoalById(goalId), isNotNull);

      // Tap trash icon again and confirm delete
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();

      // Goal is removed from repository
      expect(await repository.getGoalById(goalId), isNull);
    });

    testWidgets('"حوّشت" button opens bottom sheet, validates errors, and saves saving', (tester) async {
      // Month remaining: 10,000 EGP. Goal target: 5,000 EGP.
      final goalId = await repository.addGoal(
        name: 'ساعة',
        targetAmount: 500000, // 5,000 EGP
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          goalRepositoryProvider.overrideWithValue(repository),
          expenseRepositoryProvider.overrideWithValue(expenseRepo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        createTestApp(
          container,
          home: GoalDetailsScreen(goalId: goalId),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "حوّشت"
      await tester.tap(find.widgetWithText(ElevatedButton, 'حوّشت'));
      await tester.pumpAndSettle();

      // Bottom sheet is displayed with exact title and fields
      expect(find.text('حوّشت في ساعة'), findsOneWidget);
      expect(find.text('المبلغ بالجنيه'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'حفظ'), findsOneWidget);

      // 1. Test validation: saving > target gap (e.g. 6,000 > 5,000)
      await tester.enterText(find.byType(TextField).last, '6000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'حفظ'));
      await tester.pumpAndSettle();
      expect(find.text('المبلغ أكبر من المتبقي للهدف'), findsOneWidget);

      // 2. Test valid saving of 2,000 EGP
      await tester.enterText(find.byType(TextField).last, '2000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'حفظ'));
      await tester.pumpAndSettle();

      // Bottom sheet closed
      expect(find.text('حوّشت في ساعة'), findsNothing);

      // Check updated goal
      final updated = await repository.getGoalById(goalId);
      expect(updated!.totalSavedEgp, 2000);
      expect(updated.percentage, 40);

      // Remaining in screen shows 8,000 EGP (10,000 - 2,000)
      final rem = await expenseRepo.getRemainingOfMonth('2026-11');
      expect(rem.remaining, 800000);
    });
  });
}
