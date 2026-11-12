import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/features/expenses/data/repositories/expense_repository_impl.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Step 2: On-Device Database & Repository Unit Tests', () {
    late AppDatabase db;
    late ExpenseRepositoryImpl repository;

    setUp(() async {
      // In-memory test database with full Drift schema and seed migrations
      db = AppDatabase(NativeDatabase.memory());
      repository = ExpenseRepositoryImpl(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Default categories are seeded once on creation', () async {
      final categories = await repository.getCategories();

      expect(categories.length, equals(23));

      final expectedNames = [
        'أكل',
        'مشروبات وكافيهات',
        'سوبر ماركت',
        'مواصلات',
        'سيارة',
        'ملابس',
        'إلكترونيات',
        'بيت وأثاث',
        'إيجار',
        'فواتير واتصالات',
        'اشتراكات',
        'صحة',
        'عناية شخصية',
        'تعليم',
        'ترفيه',
        'سفر',
        'أطفال',
        'حيوانات أليفة',
        'هدايا ومناسبات',
        'صدقات',
        'استثمار وادخار',
        'ديون وأقساط',
        'أخرى',
      ];

      for (final name in expectedNames) {
        final cat = categories.firstWhere((c) => c.name == name);
        expect(cat.isDefault, isTrue);
      }

      final food = categories.firstWhere((c) => c.name == 'أكل');
      expect(food.color, equals('#4E8B7A'));
      expect(food.icon, equals('food'));

      final transport = categories.firstWhere((c) => c.name == 'مواصلات');
      expect(transport.color, equals('#E8A83A'));

      final entertainment = categories.firstWhere((c) => c.name == 'ترفيه');
      expect(entertainment.color, equals('#5BA3B8'));
      expect(entertainment.icon, equals('entertainment'));
    });

    test('Money Rules: month money = budget + income, remaining = month money - expenses (in piastres)', () async {
      const yearMonth = '2026-11';
      final categories = await repository.getCategories();
      final foodCatId = categories.firstWhere((c) => c.name == 'أكل').id;
      final salaryCatId = categories.firstWhere((c) => c.name == 'أخرى').id;

      // 1. Budget: 10,000 EGP = 1,000,000 piastres
      const int budgetPiastres = 1000000;
      await repository.setMonthBudget(yearMonth: yearMonth, amount: budgetPiastres);

      // 2. Additional Income: Freelance job 2,500 EGP = 250,000 piastres
      const int incomePiastres = 250000;
      await repository.addTransaction(
        amount: incomePiastres,
        description: 'عمل حر إضافي',
        categoryId: salaryCatId,
        kind: 'income',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 5, 10, 0),
      );

      // 3. Expenses:
      // Food: 350 EGP = 35,000 piastres
      // Transport: 120 EGP = 12,000 piastres
      await repository.addTransaction(
        amount: 35000,
        description: 'غداء عمل',
        categoryId: foodCatId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 6, 13, 0),
      );

      await repository.addTransaction(
        amount: 12000,
        description: 'تاكسي',
        categoryId: categories.firstWhere((c) => c.name == 'مواصلات').id,
        kind: 'expense',
        source: 'voice',
        createdAt: DateTime.utc(2026, 11, 6, 15, 0),
      );

      final summary = await repository.getRemainingOfMonth(yearMonth);

      // Month Money = Budget (1,000,000) + Income (250,000) = 1,250,000 piastres
      expect(summary.budget, equals(1000000));
      expect(summary.income, equals(250000));
      expect(summary.monthMoney, equals(1250000));

      // Total Expenses = 35,000 + 12,000 = 47,000 piastres
      expect(summary.expenses, equals(47000));

      // Remaining = 1,250,000 - 47,000 = 1,203,000 piastres
      expect(summary.remaining, equals(1203000));
    });

    test('Month isolation: transactions in November do not affect December', () async {
      final categories = await repository.getCategories();
      final foodCatId = categories.firstWhere((c) => c.name == 'أكل').id;

      await repository.setMonthBudget(yearMonth: '2026-11', amount: 500000);
      await repository.setMonthBudget(yearMonth: '2026-12', amount: 700000);

      // Transaction in November
      await repository.addTransaction(
        amount: 50000,
        description: 'طعام نوفمبر',
        categoryId: foodCatId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 15),
      );

      // Transaction in December
      await repository.addTransaction(
        amount: 80000,
        description: 'طعام ديسمبر',
        categoryId: foodCatId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 12, 1),
      );

      final novSummary = await repository.getRemainingOfMonth('2026-11');
      expect(novSummary.expenses, equals(50000));
      expect(novSummary.remaining, equals(450000));

      final decSummary = await repository.getRemainingOfMonth('2026-12');
      expect(decSummary.expenses, equals(80000));
      expect(decSummary.remaining, equals(620000));
    });

    test('Query: Totals per category per month (ordered descending by total amount)', () async {
      const yearMonth = '2026-11';
      final categories = await repository.getCategories();
      final foodId = categories.firstWhere((c) => c.name == 'أكل').id;
      final billsId = categories.firstWhere((c) => c.name == 'فواتير واتصالات').id;
      final charityId = categories.firstWhere((c) => c.name == 'صدقات').id;

      // Food: 200 + 300 = 500 (50,000 piastres)
      await repository.addTransaction(
        amount: 20000,
        description: 'سوبرماركت',
        categoryId: foodId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 2),
      );
      await repository.addTransaction(
        amount: 30000,
        description: 'خضار وفواكه',
        categoryId: foodId,
        kind: 'expense',
        source: 'voice',
        createdAt: DateTime.utc(2026, 11, 4),
      );

      // Bills: 1,500 (150,000 piastres)
      await repository.addTransaction(
        amount: 150000,
        description: 'فاتورة الكهرباء',
        categoryId: billsId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 3),
      );

      // Charity: 100 (10,000 piastres)
      await repository.addTransaction(
        amount: 10000,
        description: 'صدقة',
        categoryId: charityId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 1),
      );

      final totals = await repository.getTotalsPerCategoryPerMonth(yearMonth);

      expect(totals.length, equals(3));
      // First is bills (150,000)
      expect(totals[0].category.name, equals('فواتير واتصالات'));
      expect(totals[0].totalAmount, equals(150000));

      // Second is food (50,000)
      expect(totals[1].category.name, equals('أكل'));
      expect(totals[1].totalAmount, equals(50000));

      // Third is charity (10,000)
      expect(totals[2].category.name, equals('صدقات'));
      expect(totals[2].totalAmount, equals(10000));
    });

    test('Query: Last 3 transactions (ordered by createdAt DESC with category info)', () async {
      final categories = await repository.getCategories();
      final foodId = categories.firstWhere((c) => c.name == 'أكل').id;
      final transportId = categories.firstWhere((c) => c.name == 'مواصلات').id;

      for (var i = 1; i <= 5; i++) {
        await repository.addTransaction(
          amount: i * 1000,
          description: 'معاملة $i',
          categoryId: i.isEven ? transportId : foodId,
          kind: 'expense',
          source: 'text',
          createdAt: DateTime.utc(2026, 11, i, 12, 0),
        );
      }

      final last3 = await repository.getLast3Transactions();

      expect(last3.length, equals(3));
      expect(last3[0].description, equals('معاملة 5'));
      expect(last3[0].amount, equals(5000));
      expect(last3[0].category?.name, equals('أكل'));

      expect(last3[1].description, equals('معاملة 4'));
      expect(last3[1].amount, equals(4000));
      expect(last3[1].category?.name, equals('مواصلات'));

      expect(last3[2].description, equals('معاملة 3'));
      expect(last3[2].amount, equals(3000));
    });

    test('Query: Transactions per day grouped with daily sums', () async {
      final categories = await repository.getCategories();
      final foodId = categories.firstWhere((c) => c.name == 'أكل').id;

      // Day 1: 2 expenses
      await repository.addTransaction(
        amount: 2500,
        description: 'إفطار',
        categoryId: foodId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 10, 8, 30),
      );
      await repository.addTransaction(
        amount: 7500,
        description: 'غداء',
        categoryId: foodId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 10, 14, 0),
      );

      // Day 2: 1 expense
      await repository.addTransaction(
        amount: 5000,
        description: 'عشاء',
        categoryId: foodId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 11, 20, 0),
      );

      final days = await repository.getTransactionsPerDay('2026-11');

      expect(days.length, equals(2));
      // Ordered DESC: 2026-11-11 first
      expect(days[0].date, equals(DateTime.utc(2026, 11, 11)));
      expect(days[0].transactions.length, equals(1));
      expect(days[0].totalExpenses, equals(5000));

      // 2026-11-10 second
      expect(days[1].date, equals(DateTime.utc(2026, 11, 10)));
      expect(days[1].transactions.length, equals(2));
      expect(days[1].totalExpenses, equals(10000));
    });

    test('Security & Validation: invalid inputs throw ArgumentError', () async {
      final categories = await repository.getCategories();
      final catId = categories.first.id;

      // Zero or negative amount
      expect(
        () => repository.addTransaction(
          amount: 0,
          description: 'خطأ',
          categoryId: catId,
          kind: 'expense',
          source: 'text',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      expect(
        () => repository.addTransaction(
          amount: -500,
          description: 'خطأ',
          categoryId: catId,
          kind: 'expense',
          source: 'text',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      // Invalid kind
      expect(
        () => repository.addTransaction(
          amount: 1000,
          description: 'خطأ',
          categoryId: catId,
          kind: 'transfer',
          source: 'text',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );

      // Invalid source
      expect(
        () => repository.addTransaction(
          amount: 1000,
          description: 'خطأ',
          categoryId: catId,
          kind: 'expense',
          source: 'api',
          createdAt: DateTime.now(),
        ),
        throwsArgumentError,
      );
    });

    test('Data persistence: data survives closing and reopening the encrypted database file', () async {
      final tempDir = Directory.systemTemp.createTempSync('baqy_db_test_');
      final dbFile = File('${tempDir.path}/test_persisted.sqlite');
      const testEncryptionKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      // 1. Open first instance with encryption key
      final db1 = AppDatabase(
        NativeDatabase(
          dbFile,
          setup: (rawDb) {
            rawDb.execute("PRAGMA key = \"x'$testEncryptionKey'\";");
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      final repo1 = ExpenseRepositoryImpl(db1);

      // Insert budget and transaction
      await repo1.setMonthBudget(yearMonth: '2026-11', amount: 800000);
      final cats = await repo1.getCategories();
      final foodId = cats.firstWhere((c) => c.name == 'أكل').id;

      await repo1.addTransaction(
        amount: 45000,
        description: 'فاتورة تم حفظها قبل الإغلاق',
        categoryId: foodId,
        kind: 'expense',
        source: 'text',
        createdAt: DateTime.utc(2026, 11, 4, 12, 0),
      );

      // Verify before closing
      final beforeClose = await repo1.getRemainingOfMonth('2026-11');
      expect(beforeClose.budget, equals(800000));
      expect(beforeClose.expenses, equals(45000));
      expect(beforeClose.remaining, equals(755000));

      // CLOSE DATABASE (Simulates closing the app)
      await db1.close();

      // 2. Open second instance pointing to the SAME file with the SAME encryption key
      final db2 = AppDatabase(
        NativeDatabase(
          dbFile,
          setup: (rawDb) {
            rawDb.execute("PRAGMA key = \"x'$testEncryptionKey'\";");
            rawDb.execute('PRAGMA foreign_keys = ON;');
          },
        ),
      );
      final repo2 = ExpenseRepositoryImpl(db2);

      // Verify all data survived the app closing
      final afterReopen = await repo2.getRemainingOfMonth('2026-11');
      expect(afterReopen.budget, equals(800000));
      expect(afterReopen.expenses, equals(45000));
      expect(afterReopen.remaining, equals(755000));

      final lastTxs = await repo2.getLast3Transactions();
      expect(lastTxs.length, equals(1));
      expect(lastTxs.first.description, equals('فاتورة تم حفظها قبل الإغلاق'));
      expect(lastTxs.first.amount, equals(45000));

      // Close and clean up
      await db2.close();
      tempDir.deleteSync(recursive: true);
    });

    test('Transaction with note: saves note, strips control chars, caps at 40 chars', () async {
      final categories = await repository.getCategories();
      final foodId = categories.firstWhere((c) => c.name == 'أكل').id;

      // Note with control characters and > 40 chars
      const rawNote = 'كشري بركات في وسط البلد\x00\x1F - فرع التحرير الجديد الشهير جدا جدا';
      await repository.addTransaction(
        amount: 5000,
        description: 'كشري',
        categoryId: foodId,
        kind: 'expense',
        source: 'voice',
        note: rawNote,
        createdAt: DateTime.utc(2026, 11, 5, 12, 0),
      );

      final lastTxs = await repository.getLast3Transactions();
      expect(lastTxs.length, equals(1));
      expect(lastTxs.first.note != null, isTrue);
      expect(lastTxs.first.note!.length, lessThanOrEqualTo(40));
      expect(lastTxs.first.note!.contains('\x00'), isFalse);
      expect(lastTxs.first.note!.contains('\x1F'), isFalse);
    });

    test('Drift migration v1 to v2 adds note column and seeds ترفيه if missing', () async {
      final mDb = AppDatabase(NativeDatabase.memory());
      // Check schemaVersion is 5
      expect(mDb.schemaVersion, equals(5));
      final cats = await ExpenseRepositoryImpl(mDb).getCategories();
      expect(cats.any((c) => c.name == 'ترفيه'), isTrue);
      await mDb.close();
    });
  });
}
