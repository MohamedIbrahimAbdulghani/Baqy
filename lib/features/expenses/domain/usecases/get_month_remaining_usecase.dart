import '../models/month_remaining.dart';
import '../repositories/expense_repository.dart';

class GetMonthRemainingUseCase {
  const GetMonthRemainingUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<MonthRemaining> call(String yearMonth) {
    return _repository.getRemainingOfMonth(yearMonth);
  }

  Stream<MonthRemaining> watch(String yearMonth) {
    return _repository.watchRemainingOfMonth(yearMonth);
  }
}

