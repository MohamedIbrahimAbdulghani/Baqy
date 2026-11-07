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

    // Consistent local calendar month boundaries in UTC
    final localStart = DateTime(year, month, 1);
    final localEnd = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return (localStart.toUtc(), localEnd.toUtc());
  }

  (DateTime, DateTime) _getDayRange(DateTime day) {
    if (day.isUtc) {
      return (
        DateTime.utc(day.year, day.month, day.day),
        DateTime.utc(day.year, day.month, day.day + 1),
      );
    }
    final localStart = DateTime(day.year, day.month, day.day);
    final localEnd = DateTime(day.year, day.month, day.day + 1);
    return (localStart.toUtc(), localEnd.toUtc());
  }

  CategoryItem _mapCategoryRow(CategoryData cat) {
    return CategoryItem(
      id: cat.id,
      name: cat.name,
      icon: cat.icon,
      color: cat.colorHex,
      isDefault: cat.isDefault,
      isArchived: cat.isArchived,
      sortOrder: cat.sortOrder,
      createdByAi: cat.createdByAi,
      createdAt: cat.createdAt,
    );
  }

  List<CategoryTotal> _mapCategoryTotalRows(
    List<TypedResult> rows,
    Expression<int> totalAmountExp,
    Expression<int> countExp,
  ) {
    return rows.map((row) {
      final cat = row.readTable(_db.categories);
      final total = row.read(totalAmountExp) ?? 0;
      final count = row.read(countExp) ?? 0;
      return CategoryTotal(
        category: _mapCategoryRow(cat),
        totalAmount: total,
        transactionCount: count,
      );
    }).toList();
  }

  TransactionItem _mapTransactionRow(TypedResult row) {
    final tx = row.readTable(_db.transactions);
    final cat = row.readTableOrNull(_db.categories);
    return TransactionItem(
      id: tx.id,
      amount: tx.amount,
      description: tx.description,
      categoryId: tx.categoryId,
      kind: tx.kind,
      source: tx.source,
      note: tx.note,
      foreignAmount: tx.foreignAmount,
      foreignCurrency: tx.foreignCurrency,
      createdAt: tx.createdAt.toUtc(),
      category: cat == null ? null : _mapCategoryRow(cat),
    );
  }

  JoinedSelectStatement _monthCategoryTotalsQuery(
    String yearMonth,
    Expression<int> totalAmountExp,
    Expression<int> countExp,
  ) {
    final (start, end) = _getMonthRange(yearMonth);
    return _db.select(_db.transactions).join([
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
        _db.categories.colorHex,
        _db.categories.isDefault,
      ])
      ..orderBy([OrderingTerm.desc(totalAmountExp)]);
  }

  @override
  Future<List<CategoryTotal>> getTotalsPerCategoryPerMonth(String yearMonth) async {
    final totalAmountExp = _db.transactions.amount.sum();
    final countExp = _db.transactions.id.count();
    final query = _monthCategoryTotalsQuery(yearMonth, totalAmountExp, countExp);
    final rows = await query.get();
    return _mapCategoryTotalRows(rows, totalAmountExp, countExp);
  }

  @override
  Stream<List<CategoryTotal>> watchTotalsPerCategoryPerMonth(String yearMonth) {
    final totalAmountExp = _db.transactions.amount.sum();
    final countExp = _db.transactions.id.count();
    final query = _monthCategoryTotalsQuery(yearMonth, totalAmountExp, countExp);
    return query.watch().map((rows) => _mapCategoryTotalRows(rows, totalAmountExp, countExp));
  }

  JoinedSelectStatement _dayCategoryTotalsQuery(
    DateTime day,
    Expression<int> totalAmountExp,
    Expression<int> countExp,
  ) {
    final (start, end) = _getDayRange(day);
    return _db.select(_db.transactions).join([
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
        _db.categories.colorHex,
        _db.categories.isDefault,
      ])
      ..orderBy([OrderingTerm.asc(_db.categories.id)]);
  }

  @override
  Future<List<CategoryTotal>> getCategoryTotalsForDay(DateTime day) async {
    final totalAmountExp = _db.transactions.amount.sum();
    final countExp = _db.transactions.id.count();
    final query = _dayCategoryTotalsQuery(day, totalAmountExp, countExp);
    final rows = await query.get();
    return _mapCategoryTotalRows(rows, totalAmountExp, countExp);
  }

  @override
  Stream<List<CategoryTotal>> watchCategoryTotalsForDay(DateTime day) {
    final totalAmountExp = _db.transactions.amount.sum();
    final countExp = _db.transactions.id.count();
    final query = _dayCategoryTotalsQuery(day, totalAmountExp, countExp);
    return query.watch().map((rows) => _mapCategoryTotalRows(rows, totalAmountExp, countExp));
  }

  JoinedSelectStatement _categoryTransactionsForDayQuery(
    int categoryId,
    DateTime day,
  ) {
    final (start, end) = _getDayRange(day);
    return _db.select(_db.transactions).join([
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
  }

  @override
  Future<List<TransactionItem>> getCategoryTransactionsForDay({
    required int categoryId,
    required DateTime day,
  }) async {
    final query = _categoryTransactionsForDayQuery(categoryId, day);
    final rows = await query.get();
    return rows.map(_mapTransactionRow).toList();
  }

  @override
  Stream<List<TransactionItem>> watchCategoryTransactionsForDay({
    required int categoryId,
    required DateTime day,
  }) {
    final query = _categoryTransactionsForDayQuery(categoryId, day);
    return query.watch().map((rows) => rows.map(_mapTransactionRow).toList());
  }

  JoinedSelectStatement _categoryTransactionsForMonthQuery(
    int categoryId,
    String yearMonth,
  ) {
    final (start, end) = _getMonthRange(yearMonth);
    return _db.select(_db.transactions).join([
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
  }

  @override
  Future<List<TransactionItem>> getCategoryTransactionsForMonth({
    required int categoryId,
    required String yearMonth,
  }) async {
    final query = _categoryTransactionsForMonthQuery(categoryId, yearMonth);
    final rows = await query.get();
    return rows.map(_mapTransactionRow).toList();
  }

  @override
  Stream<List<TransactionItem>> watchCategoryTransactionsForMonth({
    required int categoryId,
    required String yearMonth,
  }) {
    final query = _categoryTransactionsForMonthQuery(categoryId, yearMonth);
    return query.watch().map((rows) => rows.map(_mapTransactionRow).toList());
  }

  @override
  Future<bool> hasExpensesBefore(DateTime day) async {
    final (start, _) = _getDayRange(day);
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.id])
      ..where(_db.transactions.kind.equals('expense'))
      ..where(_db.transactions.createdAt.isSmallerThanValue(start))
      ..limit(1);

    final rows = await query.get();
    return rows.isNotEmpty;
  }

  @override
  Stream<bool> watchHasExpensesBefore(DateTime day) {
    final (start, _) = _getDayRange(day);
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.id])
      ..where(_db.transactions.kind.equals('expense'))
      ..where(_db.transactions.createdAt.isSmallerThanValue(start))
      ..limit(1);

    return query.watch().map((rows) => rows.isNotEmpty);
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
  Stream<DateTime?> watchLatestExpenseDayForMonth(String yearMonth) {
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

    return query.watchSingleOrNull().map((row) {
      if (row == null) return null;
      final dt = row.read(_db.transactions.createdAt);
      if (dt == null) return null;
      final local = dt.toLocal();
      return DateTime(local.year, local.month, local.day);
    });
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
    return rows.map(_mapTransactionRow).toList();
  }

  JoinedSelectStatement _lastTransactionsForMonthQuery(
    String yearMonth,
    int limit,
  ) {
    final (start, end) = _getMonthRange(yearMonth);
    return _db.select(_db.transactions).join([
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
  }

  @override
  Future<List<TransactionItem>> getLastTransactionsForMonth(
    String yearMonth, {
    int limit = 3,
  }) async {
    final query = _lastTransactionsForMonthQuery(yearMonth, limit);
    final rows = await query.get();
    return rows.map(_mapTransactionRow).toList();
  }

  @override
  Stream<List<TransactionItem>> watchLastTransactionsForMonth(
    String yearMonth, {
    int limit = 3,
  }) {
    final query = _lastTransactionsForMonthQuery(yearMonth, limit);
    return query.watch().map((rows) => rows.map(_mapTransactionRow).toList());
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
        years.add(date.toLocal().year);
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
  Stream<List<int>> watchYearsWithData({int? currentYear}) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.transactions, _db.monthBudgets},
        )
        .watch()
        .asyncMap((_) => getYearsWithData(currentYear: currentYear));
  }

  @override
  Future<Set<int>> getMonthsWithData(int year) async {
    final Set<int> months = {};

    final localStart = DateTime(year, 1, 1);
    final localEnd = DateTime(year + 1, 1, 1);
    final start = localStart.toUtc();
    final end = localEnd.toUtc();

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
        months.add(date.toLocal().month);
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
  Stream<Set<int>> watchMonthsWithData(int year) {
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.transactions, _db.monthBudgets},
        )
        .watch()
        .asyncMap((_) => getMonthsWithData(year));
  }

  @override
  Future<List<TransactionItem>> getTransactionsForDay(DateTime day) async {
    final (start, end) = _getDayRange(day);

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
    return rows.map(_mapTransactionRow).toList();
  }

  List<DayTransactions> _groupTransactionsPerDay(List<TypedResult> rows) {
    final Map<DateTime, List<TransactionItem>> grouped = {};

    for (final row in rows) {
      final txItem = _mapTransactionRow(row);
      final local = txItem.createdAt.toLocal();
      final dateKey = DateTime.utc(local.year, local.month, local.day);
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

  JoinedSelectStatement _transactionsPerDayQuery(
    String yearMonth,
  ) {
    final (start, end) = _getMonthRange(yearMonth);
    return _db.select(_db.transactions).join([
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
  }

  @override
  Future<List<DayTransactions>> getTransactionsPerDay(String yearMonth) async {
    final query = _transactionsPerDayQuery(yearMonth);
    final rows = await query.get();
    return _groupTransactionsPerDay(rows);
  }

  @override
  Stream<List<DayTransactions>> watchTransactionsPerDay(String yearMonth) {
    final query = _transactionsPerDayQuery(yearMonth);
    return query.watch().map(_groupTransactionsPerDay);
  }

  @override
  Future<MonthRemaining> getRemainingOfMonth(String yearMonth) async {
    final (start, end) = _getMonthRange(yearMonth);

    final row = await _db
        .customSelect(
          'SELECT '
          '(SELECT amount FROM month_budgets WHERE year_month = ?1) AS budget, '
          '(SELECT SUM(amount) FROM transactions WHERE kind = ?2 AND created_at >= ?3 AND created_at < ?4) AS income, '
          '(SELECT SUM(amount) FROM transactions WHERE kind = ?5 AND created_at >= ?3 AND created_at < ?4) AS expenses',
          variables: [
            Variable<String>(yearMonth),
            Variable<String>('income'),
            Variable<DateTime>(start),
            Variable<DateTime>(end),
            Variable<String>('expense'),
          ],
          readsFrom: {_db.transactions, _db.monthBudgets},
        )
        .getSingle();

    final int budget = row.read<int?>('budget') ?? 0;
    final int income = row.read<int?>('income') ?? 0;
    final int expenses = row.read<int?>('expenses') ?? 0;
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
  Stream<MonthRemaining> watchRemainingOfMonth(String yearMonth) {
    final (start, end) = _getMonthRange(yearMonth);

    return _db
        .customSelect(
          'SELECT '
          '(SELECT amount FROM month_budgets WHERE year_month = ?1) AS budget, '
          '(SELECT SUM(amount) FROM transactions WHERE kind = ?2 AND created_at >= ?3 AND created_at < ?4) AS income, '
          '(SELECT SUM(amount) FROM transactions WHERE kind = ?5 AND created_at >= ?3 AND created_at < ?4) AS expenses',
          variables: [
            Variable<String>(yearMonth),
            Variable<String>('income'),
            Variable<DateTime>(start),
            Variable<DateTime>(end),
            Variable<String>('expense'),
          ],
          readsFrom: {_db.transactions, _db.monthBudgets},
        )
        .watchSingle()
        .map((row) {
          final int budget = row.read<int?>('budget') ?? 0;
          final int income = row.read<int?>('income') ?? 0;
          final int expenses = row.read<int?>('expenses') ?? 0;
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
        });
  }

  @override
  Stream<int> watchCategoryTotalForMonth({
    required int categoryId,
    required String yearMonth,
  }) {
    final (start, end) = _getMonthRange(yearMonth);
    return _db
        .customSelect(
          'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions WHERE kind = ?1 AND category_id = ?2 AND created_at >= ?3 AND created_at < ?4',
          variables: [
            Variable<String>('expense'),
            Variable<int>(categoryId),
            Variable<DateTime>(start),
            Variable<DateTime>(end),
          ],
          readsFrom: {_db.transactions},
        )
        .watchSingle()
        .map((row) => row.read<int>('total'));
  }

  @override
  Stream<int> watchCategoryTotalForDay({
    required int categoryId,
    required DateTime day,
  }) {
    final (start, end) = _getDayRange(day);
    return _db
        .customSelect(
          'SELECT COALESCE(SUM(amount), 0) AS total FROM transactions WHERE kind = ?1 AND category_id = ?2 AND created_at >= ?3 AND created_at < ?4',
          variables: [
            Variable<String>('expense'),
            Variable<int>(categoryId),
            Variable<DateTime>(start),
            Variable<DateTime>(end),
          ],
          readsFrom: {_db.transactions},
        )
        .watchSingle()
        .map((row) => row.read<int>('total'));
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
    // Validate input
    if (amount <= 0) {
      throw ArgumentError('Transaction amount must be positive integer piastres.');
    }
    if (amount > 10000000000) {
      throw ArgumentError('Transaction amount exceeds maximum limit of 100,000,000 EGP.');
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

    String? sanitizedNote;
    if (note != null) {
      final stripped = note.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();
      if (stripped.isNotEmpty) {
        sanitizedNote = stripped.length > 40 ? stripped.substring(0, 40) : stripped;
      }
    }

    return await _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            amount: amount,
            description: description.trim(),
            categoryId: categoryId,
            kind: kind,
            source: source,
            note: Value(sanitizedNote),
            foreignAmount: Value(foreignAmount),
            foreignCurrency: Value(foreignCurrency),
            createdAt: createdAt.toUtc(),
          ),
        );
  }

  @override
  Future<void> updateTransaction({
    required int id,
    required int amount,
    required String description,
    required int categoryId,
    String? note,
    double? foreignAmount,
    String? foreignCurrency,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Transaction amount must be strictly positive.');
    }
    if (amount > 10000000000) {
      throw ArgumentError('Transaction amount exceeds maximum limit of 100,000,000 EGP.');
    }
    final sanitizedDesc = description.trim();
    if (sanitizedDesc.isEmpty) {
      throw ArgumentError('Transaction description cannot be empty.');
    }

    String? sanitizedNote;
    if (note != null) {
      final stripped = note.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();
      if (stripped.isNotEmpty) {
        sanitizedNote = stripped.length > 40 ? stripped.substring(0, 40) : stripped;
      }
    }

    await (_db.update(_db.transactions)..where((tbl) => tbl.id.equals(id))).write(
      TransactionsCompanion(
        amount: Value(amount),
        description: Value(sanitizedDesc),
        categoryId: Value(categoryId),
        note: Value(sanitizedNote),
        foreignAmount: Value(foreignAmount),
        foreignCurrency: Value(foreignCurrency),
      ),
    );
  }

  @override
  Future<void> deleteTransaction(int id) async {
    await (_db.delete(_db.transactions)..where((tbl) => tbl.id.equals(id))).go();
  }

  @override
  Future<void> restoreTransaction(TransactionItem transaction) async {
    await _db.into(_db.transactions).insert(
      TransactionsCompanion.insert(
        id: Value(transaction.id),
        amount: transaction.amount,
        description: transaction.description,
        categoryId: transaction.categoryId,
        kind: transaction.kind,
        source: transaction.source,
        createdAt: transaction.createdAt.toUtc(),
        note: Value(transaction.note),
        foreignAmount: Value(transaction.foreignAmount),
        foreignCurrency: Value(transaction.foreignCurrency),
      ),
      mode: InsertMode.insertOrReplace,
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
  Future<List<CategoryItem>> getCategories({bool includeArchived = false}) async {
    final query = _db.select(_db.categories);
    if (!includeArchived) {
      query.where((c) => c.isArchived.equals(false));
    }
    query.orderBy([
      (c) => OrderingTerm.asc(c.sortOrder),
      (c) => OrderingTerm.asc(c.id),
    ]);
    final rows = await query.get();
    return rows.map(_mapCategoryRow).toList();
  }

  @override
  Stream<List<CategoryItem>> watchCategories({bool includeArchived = false}) {
    final query = _db.select(_db.categories);
    if (!includeArchived) {
      query.where((c) => c.isArchived.equals(false));
    }
    query.orderBy([
      (c) => OrderingTerm.asc(c.sortOrder),
      (c) => OrderingTerm.asc(c.id),
    ]);
    return query.watch().map((rows) => rows.map(_mapCategoryRow).toList());
  }

  @override
  Future<CategoryItem?> getCategoryById(int id) async {
    final query = _db.select(_db.categories)..where((c) => c.id.equals(id));
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapCategoryRow(row);
  }

  @override
  Future<CategoryItem?> getCategoryByName(String name) async {
    final clean = name.trim().toLowerCase();
    final query = _db.select(_db.categories);
    final rows = await query.get();
    for (final row in rows) {
      if (row.name.trim().toLowerCase() == clean) {
        return _mapCategoryRow(row);
      }
    }
    return null;
  }

  @override
  Future<int> addCategory({
    required String name,
    required String icon,
    required String color,
    bool isDefault = false,
    bool createdByAi = false,
    int sortOrder = 0,
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
            colorHex: color.trim(),
            isDefault: Value(isDefault),
            createdByAi: Value(createdByAi),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  @override
  Future<void> updateCategory({
    required int id,
    required String name,
    required String icon,
    required String color,
    bool? isArchived,
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
        colorHex: Value(color.trim()),
        isArchived: isArchived != null ? Value(isArchived) : const Value.absent(),
      ),
    );
  }

  @override
  Future<void> archiveCategory(int id) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      const CategoriesCompanion(
        isArchived: Value(true),
      ),
    );
  }

  @override
  Future<void> unarchiveCategory(int id) async {
    await (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      const CategoriesCompanion(
        isArchived: Value(false),
      ),
    );
  }

  @override
  Future<int> getTransactionCountForCategory(int categoryId) async {
    final countExp = _db.transactions.id.count();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([countExp])
      ..where(_db.transactions.categoryId.equals(categoryId));
    final row = await query.getSingle();
    return row.read(countExp) ?? 0;
  }

  @override
  Future<bool> deleteCategory(int id) async {
    final count = await getTransactionCountForCategory(id);
    if (count > 0) {
      await archiveCategory(id);
      return false;
    } else {
      await (_db.delete(_db.categories)..where((c) => c.id.equals(id))).go();
      return true;
    }
  }

  @override
  Future<void> saveUserRule({
    required String keyword,
    required int categoryId,
  }) async {
    final cleanKeyword = keyword.trim().toLowerCase();
    if (cleanKeyword.isEmpty) return;

    final existing = await (_db.select(_db.userRules)
          ..where((r) => r.keyword.equals(cleanKeyword)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.userRules)..where((r) => r.id.equals(existing.id))).write(
        UserRulesCompanion(
          categoryId: Value(categoryId),
          createdAt: Value(DateTime.now().toUtc()),
        ),
      );
    } else {
      await _db.into(_db.userRules).insert(
        UserRulesCompanion.insert(
          keyword: cleanKeyword,
          categoryId: categoryId,
          createdAt: Value(DateTime.now().toUtc()),
        ),
      );
    }
  }

  @override
  Future<List<({int id, String keyword, String categoryName, int categoryId})>>
      getRecentUserRules({int limit = 50}) async {
    final query = _db.select(_db.userRules).join([
      innerJoin(
        _db.categories,
        _db.categories.id.equalsExp(_db.userRules.categoryId),
      ),
    ])
      ..orderBy([OrderingTerm.desc(_db.userRules.createdAt)])
      ..limit(limit);

    final rows = await query.get();
    return rows.map((r) {
      final rule = r.readTable(_db.userRules);
      final cat = r.readTable(_db.categories);
      return (
        id: rule.id,
        keyword: rule.keyword,
        categoryName: cat.name,
        categoryId: cat.id,
      );
    }).toList();
  }
}

