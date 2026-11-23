import '../models/month_rollover_info.dart';
import '../repositories/expense_repository.dart';

/// UseCase to verify if the immediately preceding month ended with positive leftover money
/// that has not been handled or allocated yet.
class CheckMonthRolloverUseCase {
  final ExpenseRepository _repository;

  const CheckMonthRolloverUseCase(this._repository);

  Future<MonthRolloverInfo?> call({
    required String currentYearMonth,
    String? userId,
  }) async {
    final parts = currentYearMonth.split('-');
    if (parts.length != 2) return null;
    final int currentYear = int.tryParse(parts[0]) ?? 0;
    final int currentMonth = int.tryParse(parts[1]) ?? 0;
    if (currentYear <= 0 || currentMonth < 1 || currentMonth > 12) return null;

    final int prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;
    final int prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;
    final String prevYm = '$prevYear-${prevMonth.toString().padLeft(2, '0')}';

    final isHandled = await _repository.isMonthRolloverHandled(
      previousYearMonth: prevYm,
      userId: userId,
    );
    if (isHandled) return null;

    final prevRemaining = await _repository.getRemainingOfMonth(prevYm);
    if (prevRemaining.remaining <= 0) {
      // If previous month had zero or negative remaining, mark handled so we don't query again
      await _repository.markMonthRolloverHandled(
        previousYearMonth: prevYm,
        userId: userId,
      );
      return null;
    }

    return MonthRolloverInfo(
      previousYearMonth: prevYm,
      currentYearMonth: currentYearMonth,
      previousMonthNumber: prevMonth,
      currentMonthNumber: currentMonth,
      leftoverPiastres: prevRemaining.remaining,
      leftoverEgp: prevRemaining.remaining ~/ 100,
    );
  }
}
