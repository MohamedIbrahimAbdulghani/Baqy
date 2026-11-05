import '../models/category_item.dart';
import '../models/category_total.dart';
import '../models/day_transactions.dart';
import '../models/month_remaining.dart';
import '../models/transaction_item.dart';

abstract class ExpenseRepository {
  /// Total expenses grouped by category for a specific month (e.g. "2026-11")
  Future<List<CategoryTotal>> getTotalsPerCategoryPerMonth(String yearMonth);

  /// Total expenses grouped by category for a specific day
  Future<List<CategoryTotal>> getCategoryTotalsForDay(DateTime day);

  /// Transactions for a category on a specific day, ordered by createdAt DESC
  Future<List<TransactionItem>> getCategoryTransactionsForDay({
    required int categoryId,
    required DateTime day,
  });

  /// Transactions for a category in a specific month, ordered by createdAt DESC
  Future<List<TransactionItem>> getCategoryTransactionsForMonth({
    required int categoryId,
    required String yearMonth,
  });

  /// Whether any expense transactions exist before the given day
  Future<bool> hasExpensesBefore(DateTime day);

  /// Latest day that has expenses in the given month, or null if month has no expenses
  Future<DateTime?> getLatestExpenseDayForMonth(String yearMonth);

  /// Transactions for a month grouped by day, ordered by date descending
  Future<List<DayTransactions>> getTransactionsPerDay(String yearMonth);

  /// Transactions for a specific UTC calendar day
  Future<List<TransactionItem>> getTransactionsForDay(DateTime day);

  /// The 3 most recent transactions ordered by createdAt DESC
  Future<List<TransactionItem>> getLast3Transactions();

  /// The last [limit] transactions for a specific month (ordered by createdAt DESC)
  Future<List<TransactionItem>> getLastTransactionsForMonth(
    String yearMonth, {
    int limit = 3,
  });

  /// All unique years that have data (transactions or budgets) plus the current year, ascending
  Future<List<int>> getYearsWithData({int? currentYear});

  /// Set of month numbers (1..12) that have transactions or a budget in the given year
  Future<Set<int>> getMonthsWithData(int year);

  /// Calculates:
  /// month money = budget + all income transactions of that month
  /// remaining = month money - sum of that month's expenses
  Future<MonthRemaining> getRemainingOfMonth(String yearMonth);

  /// Add a new transaction (validates input, amounts in integer piastres, UTC date)
  Future<int> addTransaction({
    required int amount,
    required String description,
    required int categoryId,
    required String kind,
    required String source,
    required DateTime createdAt,
  });

  /// Set or update the budget for a specific month (e.g. "2026-11") in integer piastres
  Future<void> setMonthBudget({
    required String yearMonth,
    required int amount,
  });

  /// Get budget for a month in integer piastres, or null if not set
  Future<int?> getMonthBudget(String yearMonth);

  /// Get all categories
  Future<List<CategoryItem>> getCategories();

  /// Add a custom category
  Future<int> addCategory({
    required String name,
    required String icon,
    required String color,
    bool isDefault = false,
  });

  /// Update an existing custom category (default categories are not editable)
  Future<void> updateCategory({
    required int id,
    required String name,
    required String icon,
    required String color,
  });
}
