import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../data/repositories/expense_repository_impl.dart';
import '../../domain/models/category_item.dart';
import '../../domain/models/category_total.dart';
import '../../domain/models/month_remaining.dart';
import '../../domain/models/transaction_item.dart';
import '../../domain/repositories/expense_repository.dart';
import '../../domain/usecases/add_category_usecase.dart';
import '../../domain/usecases/add_expense_usecase.dart';
import '../../domain/usecases/get_category_totals_for_day_usecase.dart';
import '../../domain/usecases/get_category_totals_usecase.dart';
import '../../domain/usecases/get_category_transactions_for_day_usecase.dart';
import '../../domain/usecases/get_category_transactions_for_month_usecase.dart';
import '../../domain/usecases/get_categories_usecase.dart';
import '../../domain/usecases/get_daily_transactions_usecase.dart';
import '../../domain/usecases/get_last_transactions_for_month_usecase.dart';
import '../../domain/usecases/get_last_transactions_usecase.dart';
import '../../domain/usecases/get_latest_expense_day_for_month_usecase.dart';
import '../../domain/usecases/get_month_budget_usecase.dart';
import '../../domain/usecases/get_month_remaining_usecase.dart';
import '../../domain/usecases/get_months_with_data_usecase.dart';
import '../../domain/usecases/get_years_with_data_usecase.dart';
import '../../domain/usecases/has_expenses_before_usecase.dart';
import '../../domain/usecases/set_month_budget_usecase.dart';
import '../../domain/usecases/update_category_usecase.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ExpenseRepositoryImpl(db);
});

// Domain UseCases Providers
final getMonthRemainingUseCaseProvider = Provider<GetMonthRemainingUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetMonthRemainingUseCase(repo);
});

final getCategoryTotalsUseCaseProvider = Provider<GetCategoryTotalsUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetCategoryTotalsUseCase(repo);
});

final getCategoryTotalsForDayUseCaseProvider =
    Provider<GetCategoryTotalsForDayUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetCategoryTotalsForDayUseCase(repo);
});

final getCategoryTransactionsForDayUseCaseProvider =
    Provider<GetCategoryTransactionsForDayUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetCategoryTransactionsForDayUseCase(repo);
});

final getCategoryTransactionsForMonthUseCaseProvider =
    Provider<GetCategoryTransactionsForMonthUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetCategoryTransactionsForMonthUseCase(repo);
});

final hasExpensesBeforeUseCaseProvider = Provider<HasExpensesBeforeUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return HasExpensesBeforeUseCase(repo);
});

final getLatestExpenseDayForMonthUseCaseProvider =
    Provider<GetLatestExpenseDayForMonthUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetLatestExpenseDayForMonthUseCase(repo);
});

final getLastTransactionsUseCaseProvider = Provider<GetLastTransactionsUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetLastTransactionsUseCase(repo);
});

final getLastTransactionsForMonthUseCaseProvider =
    Provider<GetLastTransactionsForMonthUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetLastTransactionsForMonthUseCase(repo);
});

final getYearsWithDataUseCaseProvider = Provider<GetYearsWithDataUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetYearsWithDataUseCase(repo);
});

final getMonthsWithDataUseCaseProvider = Provider<GetMonthsWithDataUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetMonthsWithDataUseCase(repo);
});

final setMonthBudgetUseCaseProvider = Provider<SetMonthBudgetUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return SetMonthBudgetUseCase(repo);
});

final getMonthBudgetUseCaseProvider = Provider<GetMonthBudgetUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetMonthBudgetUseCase(repo);
});

final getDailyTransactionsUseCaseProvider = Provider<GetDailyTransactionsUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetDailyTransactionsUseCase(repo);
});

final getCategoriesUseCaseProvider = Provider<GetCategoriesUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return GetCategoriesUseCase(repo);
});

final addCategoryUseCaseProvider = Provider<AddCategoryUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return AddCategoryUseCase(repo);
});

final updateCategoryUseCaseProvider = Provider<UpdateCategoryUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return UpdateCategoryUseCase(repo);
});

final addExpenseUseCaseProvider = Provider<AddExpenseUseCase>((ref) {
  final repo = ref.watch(expenseRepositoryProvider);
  return AddExpenseUseCase(repo);
});

/// List of all categories from DB
final categoriesProvider = FutureProvider<List<CategoryItem>>((ref) async {
  final useCase = ref.watch(getCategoriesUseCaseProvider);
  return useCase();
});

// Presentation State Providers

/// Notifier for the currently selected month in format "YYYY-MM" (e.g. "2026-11")
class SelectedYearMonthNotifier extends Notifier<String> {
  @override
  String build() {
    final now = DateTime.now();
    return ArabicDateHelper.formatYearMonthKey(now.year, now.month);
  }

  void selectYearMonth(String yearMonth) {
    state = yearMonth;
  }
}

final selectedYearMonthProvider =
    NotifierProvider<SelectedYearMonthNotifier, String>(SelectedYearMonthNotifier.new);

/// Month remaining calculation (budget, expenses, income, remaining) for the selected month
final currentMonthRemainingProvider = FutureProvider<MonthRemaining>((ref) async {
  final yearMonth = ref.watch(selectedYearMonthProvider);
  final useCase = ref.watch(getMonthRemainingUseCaseProvider);
  return useCase(yearMonth);
});

/// Last 3 transactions for the currently selected month
final recentTransactionsProvider = FutureProvider<List<TransactionItem>>((ref) async {
  final yearMonth = ref.watch(selectedYearMonthProvider);
  final useCase = ref.watch(getLastTransactionsForMonthUseCaseProvider);
  return useCase(yearMonth, limit: 3);
});

/// Ascending list of years that have data plus the current year
final yearsWithDataProvider = FutureProvider<List<int>>((ref) async {
  final useCase = ref.watch(getYearsWithDataUseCaseProvider);
  return useCase();
});

/// Set of month numbers (1..12) that have transactions or budgets in the specified year
final monthsWithDataProvider = FutureProvider.family<Set<int>, int>((ref, year) async {
  final useCase = ref.watch(getMonthsWithDataUseCaseProvider);
  return useCase(year);
});

/// Category totals for a specific month (for Month Details bar chart)
final monthCategoryTotalsProvider =
    FutureProvider.family<List<CategoryTotal>, String>((ref, yearMonth) async {
  final useCase = ref.watch(getCategoryTotalsUseCaseProvider);
  return useCase(yearMonth);
});

/// Category totals for a specific calendar day (for Month Details day list)
final dayCategoryTotalsProvider =
    FutureProvider.family<List<CategoryTotal>, DateTime>((ref, day) async {
  final useCase = ref.watch(getCategoryTotalsForDayUseCaseProvider);
  return useCase(day);
});

/// Whether any expenses exist prior to the given day
final hasExpensesBeforeProvider =
    FutureProvider.family<bool, DateTime>((ref, day) async {
  final useCase = ref.watch(hasExpensesBeforeUseCaseProvider);
  return useCase(day);
});

/// Transactions for a category on a specific day (for Category Details)
final categoryTransactionsForDayProvider = FutureProvider.family<
    List<TransactionItem>,
    ({int categoryId, DateTime day})>((ref, arg) async {
  final useCase = ref.watch(getCategoryTransactionsForDayUseCaseProvider);
  return useCase(categoryId: arg.categoryId, day: arg.day);
});

/// Transactions for a category in a specific month (for Category Details)
final categoryTransactionsForMonthProvider = FutureProvider.family<
    List<TransactionItem>,
    ({int categoryId, String yearMonth})>((ref, arg) async {
  final useCase = ref.watch(getCategoryTransactionsForMonthUseCaseProvider);
  return useCase(categoryId: arg.categoryId, yearMonth: arg.yearMonth);
});

/// Latest expense day for a month
final latestExpenseDayForMonthProvider =
    FutureProvider.family<DateTime?, String>((ref, yearMonth) async {
  final useCase = ref.watch(getLatestExpenseDayForMonthUseCaseProvider);
  return useCase(yearMonth);
});

/// Tracks which months have already triggered the automatic budget sheet during this session
class HasAutoOpenedBudgetNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void markOpened(String yearMonth) {
    state = {...state, yearMonth};
  }
}

final hasAutoOpenedBudgetForMonthProvider =
    NotifierProvider<HasAutoOpenedBudgetNotifier, Set<String>>(
        HasAutoOpenedBudgetNotifier.new);
