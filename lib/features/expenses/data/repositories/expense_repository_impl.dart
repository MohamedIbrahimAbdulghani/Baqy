import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../domain/models/category_item.dart';
import '../../domain/models/category_total.dart';
import '../../domain/models/day_transactions.dart';
import '../../domain/models/month_remaining.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  ExpenseRepositoryImpl(this._db);

  final AppDatabase _db;

  static final RegExp _yearMonthRegex = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

  (DateTime, DateTime) _getMonthRange(String yearMonth) {
    if (!_yearMonthRegex.hasMatch(yearMonth)) {
      throw ArgumentError('Invalid yearMonth format. Expected YYYY-MM (e.g. 2026-11).');
    }
    final parts = yearMonth.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);

    final start = DateTime.utc(year, month, 1);
    final end = month == 12 ? DateTime.utc(year + 1, 1, 1) : DateTime.utc(year, month + 1, 1);
    return (start, end);
  }

  @override
  Future<List<CategoryTotal>> getTotalsPerCategoryPerMonth(String yearMonth) async {
    final (start, end) = _getMonthRange(yearMonth);

    final totalAmountExp = _db.transactions.amount.sum();
    final countExp = _db.transactions.id.count();

    final query = _db.select(_db.transactions).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
      ..where(_db.transactions.kind.equals('expense'))
      ..where(
        _db.transactions.createdAt.isBiggerOrEqualValue(start) &
            _db.transactions.createdAt.isSmallerThanValue(end),
      )
      ..addColumns([totalAmountExp, countExp])
      ..groupBy([
        _db.categories.id,
        _db.categories.name,
        _db.categories.icon,
        _db.categories.color,
        _db.categories.isDefault,
      ])
      ..orderBy([OrderingTerm.desc(totalAmountExp)]);

    final rows = await query.get();

    return rows.map((row) {
      final cat = row.readTable(_db.categories);
      final total = row.read(totalAmountExp) ?? 0;
      final count = row.read(countExp) ?? 0;
      return CategoryTotal(
        category: CategoryItem(
          id: cat.id,
          name: cat.name,
          icon: cat.icon,
          color: cat.color,
          isDefault: cat.isDefault,
        ),
        totalAmount: total,
        transactionCount: count,
      );
    }).toList();
  }

  @override
  Future<List<CategoryTotal>> getCategoryTotalsForDay(DateTime day) async {
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    final nextDay = utcDay.add(const Duration(days: 1));

    final totalAmountExp = _db.transactions.amount.sum();
    final countExp = _db.transactions.id.count();

    final query = _db.select(_db.transactions).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
      ..where(_db.transactions.kind.equals('expense'))
      ..where(
        _db.transactions.createdAt.isBiggerOrEqualValue(utcDay) &
            _db.transactions.createdAt.isSmallerThanValue(nextDay),
      )
      ..addColumns([totalAmountExp, countExp])
      ..groupBy([
        _db.categories.id,
        _db.categories.name,
        _db.categories.icon,
        _db.categories.color,
        _db.categories.isDefault,
      ])
      ..orderBy([OrderingTerm.asc(_db.categories.id)]);

    final rows = await query.get();

    return rows.map((row) {
      final cat = row.readTable(_db.categories);
      final total = row.read(totalAmountExp) ?? 0;
      final count = row.read(countExp) ?? 0;
      return CategoryTotal(
        category: CategoryItem(
          id: cat.id,
          name: cat.name,
          icon: cat.icon,
          color: cat.color,
          isDefault: cat.isDefault,
        ),
        totalAmount: total,
        transactionCount: count,
      );
    }).toList();
  }

  @override
  Future<List<TransactionItem>> getCategoryTransactionsForDay({
    required int categoryId,
    required DateTime day,
  }) async {
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    final nextDay = utcDay.add(const Duration(days: 1));

    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
      ..where(_db.transactions.kind.equals('expense'))
      ..where(_db.transactions.categoryId.equals(categoryId))
      ..where(
        _db.transactions.createdAt.isBiggerOrEqualValue(utcDay) &
            _db.transactions.createdAt.isSmallerThanValue(nextDay),
      )
      ..orderBy([OrderingTerm.desc(_db.transactions.createdAt)]);

    final rows = await query.get();

    return rows.map((row) {
      final tx = row.readTable(_db.transactions);
      final cat = row.readTableOrNull(_db.categories);
      return TransactionItem(
        id: tx.id,
        amount: tx.amount,
        description: tx.description,
        categoryId: tx.categoryId,
        kind: tx.kind,
        source: tx.source,
        createdAt: tx.createdAt.toUtc(),
        category: cat == null
            ? null
            : CategoryItem(
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                color: cat.color,
                isDefault: cat.isDefault,
              ),
      );
    }).toList();
  }

  @override
  Future<List<TransactionItem>> getCategoryTransactionsForMonth({
    required int categoryId,
    required String yearMonth,
  }) async {
    final (start, end) = _getMonthRange(yearMonth);

    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
      ..where(_db.transactions.kind.equals('expense'))
      ..where(_db.transactions.categoryId.equals(categoryId))
      ..where(
        _db.transactions.createdAt.isBiggerOrEqualValue(start) &
            _db.transactions.createdAt.isSmallerThanValue(end),
      )
      ..orderBy([OrderingTerm.desc(_db.transactions.createdAt)]);

    final rows = await query.get();

    return rows.map((row) {
      final tx = row.readTable(_db.transactions);
      final cat = row.readTableOrNull(_db.categories);
      return TransactionItem(
        id: tx.id,
        amount: tx.amount,
        description: tx.description,
        categoryId: tx.categoryId,
        kind: tx.kind,
        source: tx.source,
        createdAt: tx.createdAt.toUtc(),
        category: cat == null
            ? null
            : CategoryItem(
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                color: cat.color,
                isDefault: cat.isDefault,
              ),
      );
    }).toList();
  }

  @override
  Future<bool> hasExpensesBefore(DateTime day) async {
    final utcDay = DateTime.utc(day.year, day.month, day.day);

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.id])
      ..where(_db.transactions.kind.equals('expense'))
      ..where(_db.transactions.createdAt.isSmallerThanValue(utcDay))
      ..limit(1);

    final rows = await query.get();
    return rows.isNotEmpty;
  }

  @override
  Future<DateTime?> getLatestExpenseDayForMonth(String yearMonth) async {
    final (start, end) = _getMonthRange(yearMonth);

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.createdAt])
      ..where(_db.transactions.kind.equals('expense'))
      ..where(
        _db.transactions.createdAt.isBiggerOrEqualValue(start) &
            _db.transactions.createdAt.isSmallerThanValue(end),
      )
      ..orderBy([OrderingTerm.desc(_db.transactions.createdAt)])
      ..limit(1);

    final rows = await query.get();
    if (rows.isEmpty) return null;
    final dt = rows.first.read(_db.transactions.createdAt);
    if (dt == null) return null;
    final local = dt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  @override
  Future<List<TransactionItem>> getLast3Transactions() async {
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
      ..orderBy([OrderingTerm.desc(_db.transactions.createdAt)])
      ..limit(3);

    final rows = await query.get();

    return rows.map((row) {
      final tx = row.readTable(_db.transactions);
      final cat = row.readTableOrNull(_db.categories);
      return TransactionItem(
        id: tx.id,
        amount: tx.amount,
        description: tx.description,
        categoryId: tx.categoryId,
        kind: tx.kind,
        source: tx.source,
        createdAt: tx.createdAt.toUtc(),
        category: cat == null
            ? null
            : CategoryItem(
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                color: cat.color,
                isDefault: cat.isDefault,
              ),
      );
    }).toList();
  }

  @override
  Future<List<TransactionItem>> getLastTransactionsForMonth(
    String yearMonth, {
    int limit = 3,
  }) async {
    final (start, end) = _getMonthRange(yearMonth);
    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
      ..where(
        _db.transactions.createdAt.isBiggerOrEqualValue(start) &
            _db.transactions.createdAt.isSmallerThanValue(end),
      )
      ..orderBy([OrderingTerm.desc(_db.transactions.createdAt)])
      ..limit(limit);

    final rows = await query.get();

    return rows.map((row) {
      final tx = row.readTable(_db.transactions);
      final cat = row.readTableOrNull(_db.categories);
      return TransactionItem(
        id: tx.id,
        amount: tx.amount,
        description: tx.description,
        categoryId: tx.categoryId,
        kind: tx.kind,
        source: tx.source,
        createdAt: tx.createdAt.toUtc(),
        category: cat == null
            ? null
            : CategoryItem(
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                color: cat.color,
                isDefault: cat.isDefault,
              ),
      );
    }).toList();
  }

  @override
  Future<List<int>> getYearsWithData({int? currentYear}) async {
    final nowYear = currentYear ?? DateTime.now().year;
    final Set<int> years = {nowYear};

    // 1. Years from transactions
    final txDates = await (_db.selectOnly(_db.transactions, distinct: true)
          ..addColumns([_db.transactions.createdAt]))
        .get();
    for (final row in txDates) {
      final date = row.read(_db.transactions.createdAt);
      if (date != null) {
        years.add(date.toUtc().year);
      }
    }

    // 2. Years from month budgets
    final budgetRows = await (_db.selectOnly(_db.monthBudgets, distinct: true)
          ..addColumns([_db.monthBudgets.yearMonth]))
        .get();
    for (final row in budgetRows) {
      final ym = row.read(_db.monthBudgets.yearMonth);
      if (ym != null && _yearMonthRegex.hasMatch(ym)) {
        final y = int.tryParse(ym.split('-')[0]);
        if (y != null) {
          years.add(y);
        }
      }
    }

    final list = years.toList()..sort();
    return list;
  }

  @override
  Future<Set<int>> getMonthsWithData(int year) async {
    final Set<int> months = {};

    final start = DateTime.utc(year, 1, 1);
    final end = DateTime.utc(year + 1, 1, 1);

    // 1. Months from transactions
    final txRows = await (_db.selectOnly(_db.transactions, distinct: true)
          ..addColumns([_db.transactions.createdAt])
          ..where(
            _db.transactions.createdAt.isBiggerOrEqualValue(start) &
                _db.transactions.createdAt.isSmallerThanValue(end),
          ))
        .get();
    for (final row in txRows) {
      final date = row.read(_db.transactions.createdAt);
      if (date != null) {
        months.add(date.toUtc().month);
      }
    }

    // 2. Months from budgets
    final yearPrefix = '$year-';
    final budgetRows = await (_db.selectOnly(_db.monthBudgets)
          ..addColumns([_db.monthBudgets.yearMonth])
          ..where(_db.monthBudgets.yearMonth.like('$yearPrefix%')))
        .get();
    for (final row in budgetRows) {
      final ym = row.read(_db.monthBudgets.yearMonth);
      if (ym != null && ym.length >= 7) {
        final m = int.tryParse(ym.substring(5, 7));
        if (m != null && m >= 1 && m <= 12) {
          months.add(m);
        }
      }
    }

    return months;
  }

  @override
  Future<List<TransactionItem>> getTransactionsForDay(DateTime day) async {
    final utcDay = DateTime.utc(day.year, day.month, day.day);
    final nextDay = utcDay.add(const Duration(days: 1));

    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
      ..where(
        _db.transactions.createdAt.isBiggerOrEqualValue(utcDay) &
            _db.transactions.createdAt.isSmallerThanValue(nextDay),
      )
      ..orderBy([OrderingTerm.desc(_db.transactions.createdAt)]);

    final rows = await query.get();

    return rows.map((row) {
      final tx = row.readTable(_db.transactions);
      final cat = row.readTableOrNull(_db.categories);
      return TransactionItem(
        id: tx.id,
        amount: tx.amount,
        description: tx.description,
        categoryId: tx.categoryId,
        kind: tx.kind,
        source: tx.source,
        createdAt: tx.createdAt.toUtc(),
        category: cat == null
            ? null
            : CategoryItem(
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                color: cat.color,
                isDefault: cat.isDefault,
              ),
      );
    }).toList();
  }

  @override
  Future<List<DayTransactions>> getTransactionsPerDay(String yearMonth) async {
    final (start, end) = _getMonthRange(yearMonth);

    final query = _db.select(_db.transactions).join([
      leftOuterJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.transactions.categoryId),
      ),
    ])
      ..where(
        _db.transactions.createdAt.isBiggerOrEqualValue(start) &
            _db.transactions.createdAt.isSmallerThanValue(end),
      )
      ..orderBy([OrderingTerm.desc(_db.transactions.createdAt)]);

    final rows = await query.get();

    final Map<DateTime, List<TransactionItem>> grouped = {};

    for (final row in rows) {
      final tx = row.readTable(_db.transactions);
      final cat = row.readTableOrNull(_db.categories);
      final txItem = TransactionItem(
        id: tx.id,
        amount: tx.amount,
        description: tx.description,
        categoryId: tx.categoryId,
        kind: tx.kind,
        source: tx.source,
        createdAt: tx.createdAt.toUtc(),
        category: cat == null
            ? null
            : CategoryItem(
                id: cat.id,
                name: cat.name,
                icon: cat.icon,
                color: cat.color,
                isDefault: cat.isDefault,
              ),
      );

      final dateKey = DateTime.utc(
        tx.createdAt.year,
        tx.createdAt.month,
        tx.createdAt.day,
      );

      grouped.putIfAbsent(dateKey, () => []).add(txItem);
    }

    final List<DayTransactions> result = [];
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final date in sortedKeys) {
      final items = grouped[date]!;
      var expenses = 0;
      var income = 0;

      for (final item in items) {
        if (item.kind == 'expense') {
          expenses += item.amount;
        } else if (item.kind == 'income') {
          income += item.amount;
        }
      }

      result.add(
        DayTransactions(
          date: date,
          transactions: items,
          totalExpenses: expenses,
          totalIncome: income,
        ),
      );
    }

    return result;
  }

  @override
  Future<MonthRemaining> getRemainingOfMonth(String yearMonth) async {
    final (start, end) = _getMonthRange(yearMonth);

    // 1. Get budget for this month
    final budgetRow = await (_db.select(_db.monthBudgets)
          ..where((tbl) => tbl.yearMonth.equals(yearMonth)))
        .getSingleOrNull();
    final int budget = budgetRow?.amount ?? 0;

    // 2. Sum income for this month
    final incomeExp = _db.transactions.amount.sum();
    final incomeQuery = _db.selectOnly(_db.transactions)
      ..addColumns([incomeExp])
      ..where(
        _db.transactions.kind.equals('income') &
            _db.transactions.createdAt.isBiggerOrEqualValue(start) &
            _db.transactions.createdAt.isSmallerThanValue(end),
      );
    final incomeRow = await incomeQuery.getSingle();
    final int income = incomeRow.read(incomeExp) ?? 0;

    // 3. Sum expenses for this month
    final expenseExp = _db.transactions.amount.sum();
    final expenseQuery = _db.selectOnly(_db.transactions)
      ..addColumns([expenseExp])
      ..where(
        _db.transactions.kind.equals('expense') &
            _db.transactions.createdAt.isBiggerOrEqualValue(start) &
            _db.transactions.createdAt.isSmallerThanValue(end),
      );
    final expenseRow = await expenseQuery.getSingle();
    final int expenses = expenseRow.read(expenseExp) ?? 0;

    // Rules of money:
    // month money = that month's budget + all income transactions of that month.
    // Remaining = month money - sum of that month's expenses.
    final int monthMoney = budget + income;
    final int remaining = monthMoney - expenses;

    return MonthRemaining(
      yearMonth: yearMonth,
      budget: budget,
      income: income,
      monthMoney: monthMoney,
      expenses: expenses,
      remaining: remaining,
    );
  }

  @override
  Future<int> addTransaction({
    required int amount,
    required String description,
    required int categoryId,
    required String kind,
    required String source,
    required DateTime createdAt,
  }) async {
    // Validate input
    if (amount <= 0) {
      throw ArgumentError('Transaction amount must be positive integer piastres.');
    }
    if (kind != 'expense' && kind != 'income') {
      throw ArgumentError('Transaction kind must be "expense" or "income".');
    }
    if (source != 'voice' && source != 'text' && source != 'debt') {
      throw ArgumentError('Transaction source must be "voice", "text", or "debt".');
    }
    if (description.trim().isEmpty) {
      throw ArgumentError('Transaction description cannot be empty.');
    }

    return await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: amount,
            description: description.trim(),
            categoryId: categoryId,
            kind: kind,
            source: source,
            createdAt: createdAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> setMonthBudget({
    required String yearMonth,
    required int amount,
  }) async {
    if (!_yearMonthRegex.hasMatch(yearMonth)) {
      throw ArgumentError('Invalid yearMonth format. Expected YYYY-MM (e.g. 2026-11).');
    }
    if (amount < 0) {
      throw ArgumentError('Budget amount cannot be negative.');
    }

    await _db.into(_db.monthBudgets).insertOnConflictUpdate(
          MonthBudgetsCompanion.insert(
            yearMonth: yearMonth,
            amount: amount,
          ),
        );
  }

  @override
  Future<int?> getMonthBudget(String yearMonth) async {
    if (!_yearMonthRegex.hasMatch(yearMonth)) {
      throw ArgumentError('Invalid yearMonth format. Expected YYYY-MM.');
    }
    final row = await (_db.select(_db.monthBudgets)
          ..where((tbl) => tbl.yearMonth.equals(yearMonth)))
        .getSingleOrNull();
    return row?.amount;
  }

  @override
  Future<List<CategoryItem>> getCategories() async {
    final rows = await _db.select(_db.categories).get();
    return rows
        .map(
          (c) => CategoryItem(
            id: c.id,
            name: c.name,
            icon: c.icon,
            color: c.color,
            isDefault: c.isDefault,
          ),
        )
        .toList();
  }

  @override
  Future<int> addCategory({
    required String name,
    required String icon,
    required String color,
    bool isDefault = false,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }
    if (trimmedName.length > 30) {
      throw ArgumentError('Category name cannot exceed 30 characters.');
    }

    final existing = await (_db.select(_db.categories)
          ..where((tbl) => tbl.name.lower().equals(trimmedName.toLowerCase())))
        .get();
    if (existing.isNotEmpty) {
      throw ArgumentError('Category name already exists.');
    }

    return await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: trimmedName,
            icon: icon.trim(),
            color: color.trim(),
            isDefault: Value(isDefault),
          ),
        );
  }

  @override
  Future<void> updateCategory({
    required int id,
    required String name,
    required String icon,
    required String color,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError('Category name cannot be empty.');
    }
    if (trimmedName.length > 30) {
      throw ArgumentError('Category name cannot exceed 30 characters.');
    }

    final category = await (_db.select(_db.categories)
          ..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
    if (category == null) {
      throw StateError('Category not found.');
    }
    if (category.isDefault) {
      throw StateError('Default categories are not editable.');
    }

    final duplicates = await (_db.select(_db.categories)
          ..where((tbl) =>
              tbl.name.lower().equals(trimmedName.toLowerCase()) &
              tbl.id.equals(id).not()))
        .get();
    if (duplicates.isNotEmpty) {
      throw ArgumentError('Category name already exists.');
    }

    await (_db.update(_db.categories)..where((tbl) => tbl.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(trimmedName),
        icon: Value(icon.trim()),
        color: Value(color.trim()),
      ),
    );
  }
}

