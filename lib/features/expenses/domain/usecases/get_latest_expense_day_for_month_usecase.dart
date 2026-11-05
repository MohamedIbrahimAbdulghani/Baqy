import '../repositories/expense_repository.dart';

class GetLatestExpenseDayForMonthUseCase {
  const GetLatestExpenseDayForMonthUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<DateTime?> call(String yearMonth) {
    return _repository.getLatestExpenseDayForMonth(yearMonth);
  }
}

