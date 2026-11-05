import '../repositories/expense_repository.dart';

class GetMonthBudgetUseCase {
  const GetMonthBudgetUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<int?> call(String yearMonth) {
    return _repository.getMonthBudget(yearMonth);
  }
}

