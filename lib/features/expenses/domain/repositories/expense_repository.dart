import '../models/category_item.dart';
import '../models/category_total.dart';
import '../models/day_transactions.dart';
import '../models/month_remaining.dart';
import '../models/transaction_item.dart';

abstract class ExpenseRepository {
  /// Total expenses grouped by category for a specific month (e.g. "2026-11")
  Future<List<CategoryTotal>> getTotalsPerCategoryPerMonth(String yearMonth);
  Stream<List<CategoryTotal>> watchTotalsPerCategoryPerMonth(String yearMonth);

  /// Total expenses grouped by category for a specific day
  Future<List<CategoryTotal>> getCategoryTotalsForDay(DateTime day);
  Stream<List<CategoryTotal>> watchCategoryTotalsForDay(DateTime day);

  /// Transactions for a category on a specific day, ordered by createdAt DESC
  Future<List<TransactionItem>> getCategoryTransactionsForDay({
    required int categoryId,
    required DateTime day,
  });
  Stream<List<TransactionItem>> watchCategoryTransactionsForDay({
    required int categoryId,
    required DateTime day,
  });

  /// Transactions for a category in a specific month, ordered by createdAt DESC
  Future<List<TransactionItem>> getCategoryTransactionsForMonth({
    required int categoryId,
    required String yearMonth,
  });
  Stream<List<TransactionItem>> watchCategoryTransactionsForMonth({
    required int categoryId,
    required String yearMonth,
  });

  /// Whether any expense transactions exist before the given day
  Future<bool> hasExpensesBefore(DateTime day);
  Stream<bool> watchHasExpensesBefore(DateTime day);

  /// Latest day that has expenses in the given month, or null if month has no expenses
  Future<DateTime?> getLatestExpenseDayForMonth(String yearMonth);
  Stream<DateTime?> watchLatestExpenseDayForMonth(String yearMonth);

  /// Transactions for a month grouped by day, ordered by date descending
  Future<List<DayTransactions>> getTransactionsPerDay(String yearMonth);
  Stream<List<DayTransactions>> watchTransactionsPerDay(String yearMonth);

  /// Transactions for a specific UTC calendar day
  Future<List<TransactionItem>> getTransactionsForDay(DateTime day);

  /// The 3 most recent transactions ordered by createdAt DESC
  Future<List<TransactionItem>> getLast3Transactions();

  /// The last [limit] transactions for a specific month (ordered by createdAt DESC)
  Future<List<TransactionItem>> getLastTransactionsForMonth(
    String yearMonth, {
    int limit = 3,
  });
  Stream<List<TransactionItem>> watchLastTransactionsForMonth(
    String yearMonth, {
    int limit = 3,
  });

  /// All unique years that have data (transactions or budgets) plus the current year, ascending
  Future<List<int>> getYearsWithData({int? currentYear});
  Stream<List<int>> watchYearsWithData({int? currentYear});

  /// Set of month numbers (1..12) that have transactions or a budget in the given year
  Future<Set<int>> getMonthsWithData(int year);
  Stream<Set<int>> watchMonthsWithData(int year);

  /// Calculates:
  /// month money = budget + all income transactions of that month
  /// remaining = month money - sum of that month's expenses
  Future<MonthRemaining> getRemainingOfMonth(String yearMonth);
  Stream<MonthRemaining> watchRemainingOfMonth(String yearMonth);

  /// Total expenses for a specific category in a month in integer piastres
  Stream<int> watchCategoryTotalForMonth({
    required int categoryId,
    required String yearMonth,
  });

  /// Total expenses for a specific category on a specific day in integer piastres
  Stream<int> watchCategoryTotalForDay({
    required int categoryId,
    required DateTime day,
  });

  /// Add a new transaction (validates input, amounts in integer piastres, UTC date)
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
  });

  /// Update an existing transaction (amount in integer piastres)
  Future<void> updateTransaction({
    required int id,
    required int amount,
    required String description,
    required int categoryId,
    String? note,
    double? foreignAmount,
    String? foreignCurrency,
  });

  /// Delete a transaction by ID
  Future<void> deleteTransaction(int id);

  /// Restore a previously deleted transaction
  Future<void> restoreTransaction(TransactionItem transaction);

  /// Set or update the budget for a specific month (e.g. "2026-11") in integer piastres
  Future<void> setMonthBudget({
    required String yearMonth,
    required int amount,
  });

  /// Get budget for a month in integer piastres, or null if not set
  Future<int?> getMonthBudget(String yearMonth);

  /// Get categories, optionally including archived ones
  Future<List<CategoryItem>> getCategories({bool includeArchived = false});
  Stream<List<CategoryItem>> watchCategories({bool includeArchived = false});

  /// Get category by ID
  Future<CategoryItem?> getCategoryById(int id);

  /// Get category by Name (case and whitespace insensitive)
  Future<CategoryItem?> getCategoryByName(String name);

  /// Add a category
  Future<int> addCategory({
    required String name,
    required String icon,
    required String color,
    bool isDefault = false,
    bool createdByAi = false,
    int sortOrder = 0,
  });

  /// Update a category
  Future<void> updateCategory({
    required int id,
    required String name,
    required String icon,
    required String color,
    bool? isArchived,
  });

  /// Archive a category
  Future<void> archiveCategory(int id);

  /// Unarchive a category
  Future<void> unarchiveCategory(int id);

  /// Delete category if it has no transactions, or archive it if it does
  Future<bool> deleteCategory(int id);

  /// Count of transactions assigned to a category
  Future<int> getTransactionCountForCategory(int categoryId);

  /// Save or update a user rule (keyword -> categoryId)
  Future<void> saveUserRule({
    required String keyword,
    required int categoryId,
  });

  /// Retrieve the most recent user rules (up to limit)
  Future<List<({int id, String keyword, String categoryName, int categoryId})>>
      getRecentUserRules({int limit = 50});
}
