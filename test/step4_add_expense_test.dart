import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:baqy/features/expenses/domain/usecases/add_category_usecase.dart';
import 'package:baqy/features/expenses/domain/usecases/add_expense_usecase.dart';
import 'package:baqy/features/expenses/domain/usecases/get_categories_usecase.dart';
import 'package:baqy/features/expenses/domain/usecases/update_category_usecase.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:baqy/features/expenses/presentation/screens/category_form_screen.dart';
import 'package:baqy/features/home/presentation/widgets/home_speed_dial_fab.dart';
import 'package:baqy/features/shell/presentation/screens/main_shell_screen.dart';

void main() {
  group('Step 4 Unit Tests: Expense & Category Validation & UseCases', () {
    late AppDatabase db;
    late ExpenseRepositoryImpl repository;
    late AddExpenseUseCase addExpenseUseCase;
    late AddCategoryUseCase addCategoryUseCase;
    late UpdateCategoryUseCase updateCategoryUseCase;
    late GetCategoriesUseCase getCategoriesUseCase;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = ExpenseRepositoryImpl(db);
      addExpenseUseCase = AddExpenseUseCase(repository);
      addCategoryUseCase = AddCategoryUseCase(repository);
      updateCategoryUseCase = UpdateCategoryUseCase(repository);
      getCategoriesUseCase = GetCategoriesUseCase(repository);
    });

    tearDown(() async {
      await db.close();
    });

    test('AddExpenseUseCase validates positive amount up to 100,000,000 EGP', () async {
      final categories = await getCategoriesUseCase();
      final foodCategory = categories.firstWhere((c) => c.name == 'أكل');

      // Amount <= 0 should throw
      expect(
        () => addExpenseUseCase(
          amountInPiastres: 0,
          description: 'غدا',
          categoryId: foodCategory.id,
        ),
        throwsArgumentError,
      );

      expect(
        () => addExpenseUseCase(
          amountInPiastres: -500,
          description: 'غدا',
          categoryId: foodCategory.id,
        ),
        throwsArgumentError,
      );

      // Amount exceeding 100,000,000 EGP (10,000,000,000 piastres) should throw
      expect(
        () => addExpenseUseCase(
          amountInPiastres: 100000001 * 100,
          description: 'غدا',
          categoryId: foodCategory.id,
        ),
        throwsArgumentError,
      );

      // Valid amount up to 100,000,000 EGP succeeds
      final id = await addExpenseUseCase(
        amountInPiastres: 15000, // 150 EGP
        description: 'غدا',
        categoryId: foodCategory.id,
      );
      expect(id, isPositive);
    });

    test('AddExpenseUseCase strips control characters and limits name to 60 chars', () async {
      final categories = await getCategoriesUseCase();
      final catId = categories.first.id;

      final longName = 'A' * 80;
      final withControlChars = '\x00\x1F\x07Hello\x7F World';

      final txId = await addExpenseUseCase(
        amountInPiastres: 10000,
        description: withControlChars,
        categoryId: catId,
      );

      final transactions = await repository.getLast3Transactions();
      final tx = transactions.firstWhere((t) => t.id == txId);
      expect(tx.description, equals('Hello World'));

      // Test length cap at 60 chars
      final longTxId = await addExpenseUseCase(
        amountInPiastres: 20000,
        description: longName,
        categoryId: catId,
      );
      final longTx = (await repository.getLast3Transactions()).firstWhere((t) => t.id == longTxId);
      expect(longTx.description.length, equals(60));
    });

    test('AddCategoryUseCase validates required name, length <= 30 and no duplicates', () async {
      // Empty name throws
      expect(
        () => addCategoryUseCase(name: '   ', icon: 'trending_up', color: '#4E8B7A'),
        throwsArgumentError,
      );

      // Name exceeding 30 characters throws
      expect(
        () => addCategoryUseCase(
          name: 'اسم طويل جدا جدا جدا جدا جدا يتجاوز ثلاثين حرف',
          icon: 'trending_up',
          color: '#4E8B7A',
        ),
        throwsArgumentError,
      );

      // Adding duplicate name of existing seeded default category throws
      expect(
        () => addCategoryUseCase(name: 'أكل', icon: 'trending_up', color: '#4E8B7A'),
        throwsArgumentError,
      );

      // Adding custom category succeeds
      final customId = await addCategoryUseCase(
        name: 'استثمار',
        icon: 'trending_up',
        color: '#4E8B7A',
      );
      expect(customId, isPositive);

      final allCategories = await getCategoriesUseCase();
      final customCat = allCategories.firstWhere((c) => c.id == customId);
      expect(customCat.name, equals('استثمار'));
      expect(customCat.isDefault, isFalse);

      // Adding same custom category again throws duplicate error
      expect(
        () => addCategoryUseCase(name: 'استثمار', icon: 'home', color: '#E8A83A'),
        throwsArgumentError,
      );
    });

    test('UpdateCategoryUseCase updates custom category but prevents editing default categories', () async {
      final categories = await getCategoriesUseCase();
      final defaultFood = categories.firstWhere((c) => c.name == 'أكل');

      // Attempting to edit a default category throws StateError
      expect(
        () => updateCategoryUseCase(
          id: defaultFood.id,
          name: 'طعام',
          icon: 'food',
          color: '#4E8B7A',
        ),
        throwsStateError,
      );

      // Add a custom category
      final customId = await addCategoryUseCase(
        name: 'استثمار',
        icon: 'trending_up',
        color: '#4E8B7A',
      );

      // Update custom category succeeds
      await updateCategoryUseCase(
        id: customId,
        name: 'استثمارات مالية',
        icon: 'home',
        color: '#E8A83A',
      );

      final updatedCats = await getCategoriesUseCase();
      final updatedCat = updatedCats.firstWhere((c) => c.id == customId);
      expect(updatedCat.name, equals('استثمارات مالية'));
      expect(updatedCat.icon, equals('home'));
      expect(updatedCat.color, equals('#E8A83A'));
    });
  });

  group('Step 4 Widget Tests: Add Expense & Custom Category Screens', () {
    late AppDatabase db;
    late ExpenseRepositoryImpl repository;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      repository = ExpenseRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('AddExpenseScreen renders exact fields, chips and handles default description', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddExpenseScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('مصروف جديد'), findsOneWidget);

      // Check fields
      expect(find.text('الاسم'), findsOneWidget);
      expect(find.text('المبلغ'), findsOneWidget);
      expect(find.text('النوع'), findsOneWidget);
      expect(find.text('تعديل'), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);

      // Check categories from DB are shown
      expect(find.text('أكل'), findsOneWidget);
      expect(find.text('مواصلات'), findsOneWidget);
      expect(find.text('نوع جديد'), findsOneWidget); // dashed chip

      // Find amount input and enter 150 (leaving name empty)
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      // Enter 150 in the amount field (second textfield)
      await tester.enterText(textFields.at(1), '150');
      await tester.pumpAndSettle();

      // Tap "حفظ"
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      // Since name was left empty, description must equal selected category name ("أكل")
      final txs = await repository.getLast3Transactions();
      expect(txs.length, equals(1));
      expect(txs.first.description, equals('أكل'));
      expect(txs.first.amount, equals(15000)); // 150 * 100
      expect(txs.first.source, equals('text'));
    });

    testWidgets('CategoryFormScreen renders 8 icons and 6 colors and adds a custom category', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: CategoryFormScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title and labels
      expect(find.text('نوع جديد'), findsOneWidget);
      expect(find.text('اسم النوع'), findsOneWidget);
      expect(find.text('الأيقونة'), findsOneWidget);
      expect(find.text('اللون'), findsOneWidget);
      expect(find.text('حفظ'), findsOneWidget);

      // Enter category name "استثمار"
      await tester.enterText(find.byType(TextField), 'استثمار');
      await tester.pumpAndSettle();

      // Tap "حفظ"
      await tester.tap(find.text('حفظ'));
      await tester.pumpAndSettle();

      // Category should be created in DB
      final categories = await repository.getCategories();
      expect(categories.any((c) => c.name == 'استثمار' && !c.isDefault), isTrue);
    });

    testWidgets('Tapping "تعديل" allows editing custom category pre-filled but not default categories', (tester) async {
      // Seed a custom category in DB
      final customId = await repository.addCategory(
        name: 'استثمار',
        icon: 'trending_up',
        color: '#4E8B7A',
      );
      expect(customId, isPositive);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AddExpenseScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Custom category "استثمار" is visible
      expect(find.text('استثمار'), findsOneWidget);

      // Tap "تعديل" link
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();

      // Link text changes to "إلغاء" in edit mode
      expect(find.text('إلغاء'), findsOneWidget);

      // Default category "أكل" is not editable
      await tester.tap(find.text('أكل'));
      await tester.pumpAndSettle();
      // Still on AddExpenseScreen, didn't navigate
      expect(find.text('مصروف جديد'), findsOneWidget);

      // Tapping "إلغاء" toggles back to "تعديل"
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.text('تعديل'), findsOneWidget);
    });

    testWidgets('Full flow: Home -> Speed Dial Pencil -> Add Expense -> Updates Home Ring & Last Expenses', (tester) async {
      // Set initial budget for the current month: 10,000 EGP (1,000,000 piastres)
      final now = DateTime.now();
      final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      await repository.setMonthBudget(yearMonth: yearMonth, amount: 1000000);

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          expenseRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: MainShellScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial ring displays 10,000 EGP
      expect(find.textContaining('١٠,٠٠٠'), findsWidgets);

      // Tap FAB "+"
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Speed dial is open with pencil button
      expect(
        find.descendant(
          of: find.byType(HomeSpeedDialFab),
          matching: find.byIcon(Icons.edit_outlined),
        ),
        findsOneWidget,
      );

      // Directly insert an expense through AddExpenseUseCase as in AddExpenseScreen
      await container.read(addExpenseUseCaseProvider)(
        amountInPiastres: 15000, // 150 EGP
        description: 'غدا',
        categoryId: 1,
        createdAt: DateTime.now().toUtc(),
      );

      // Invalidate providers
      container.invalidate(currentMonthRemainingProvider);
      container.invalidate(recentTransactionsProvider);
      await tester.pumpAndSettle();

      // Home updates: remaining is now 9,850 EGP, spent is 150 EGP, and "غدا" is in last expenses!
      expect(find.text('غدا'), findsOneWidget);
      expect(find.textContaining('١٥٠'), findsWidgets);
    });
  });
}
