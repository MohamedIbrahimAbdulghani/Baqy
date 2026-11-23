import '../../../goals/domain/repositories/goal_repository.dart';
import '../models/month_rollover_info.dart';
import '../repositories/expense_repository.dart';

/// Pure Dart month names helper for domain layer
const List<String> _domainArabicMonthNames = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// UseCase to execute the user's rollover choice:
/// 1. Save leftover money to an active goal.
/// 2. Transfer leftover money to current month's budget as income.
class ExecuteRolloverUseCase {
  final ExpenseRepository expenseRepository;
  final GoalRepository goalRepository;

  const ExecuteRolloverUseCase({
    required this.expenseRepository,
    required this.goalRepository,
  });

  String _getMonthName(int monthNumber) {
    if (monthNumber < 1 || monthNumber > 12) return '';
    return _domainArabicMonthNames[monthNumber - 1];
  }

  /// Saves leftover money into a chosen goal and marks rollover handled
  Future<void> saveToGoal({
    required int goalId,
    required MonthRolloverInfo info,
    String? userId,
  }) async {
    final now = DateTime.now().toUtc();

    // 1. Record the saving in the goal
    await goalRepository.addGoalSaving(
      goalId: goalId,
      amount: info.leftoverPiastres,
      savedAt: now,
    );

    // 2. Mark rollover handled for the previous month
    await expenseRepository.markMonthRolloverHandled(
      previousYearMonth: info.previousYearMonth,
      userId: userId,
    );
  }

  /// Transfers leftover money to current month's money as an income transaction
  Future<void> transferToCurrentMonth({
    required MonthRolloverInfo info,
    String? userId,
  }) async {
    final categories = await expenseRepository.getCategories();
    final catId = categories.isNotEmpty ? categories.first.id : 1;
    final prevMonthName = _getMonthName(info.previousMonthNumber);

    final parts = info.currentYearMonth.split('-');
    final year = int.tryParse(parts[0]) ?? DateTime.now().year;
    final month = int.tryParse(parts[1]) ?? DateTime.now().month;
    final now = DateTime.now();
    final createdAt = (now.year == year && now.month == month)
        ? now.toUtc()
        : DateTime(year, month, 1, 12, 0).toUtc();

    await expenseRepository.addTransaction(
      amount: info.leftoverPiastres,
      description: 'باقي من شهر $prevMonthName',
      categoryId: catId,
      kind: 'income',
      source: 'text',
      createdAt: createdAt,
    );

    await expenseRepository.markMonthRolloverHandled(
      previousYearMonth: info.previousYearMonth,
      userId: userId,
    );
  }
}
