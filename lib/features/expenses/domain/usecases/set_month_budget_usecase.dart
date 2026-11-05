import '../repositories/expense_repository.dart';

class SetMonthBudgetUseCase {
  const SetMonthBudgetUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<void> call({required String yearMonth, required int amount}) {
    return _repository.setMonthBudget(yearMonth: yearMonth, amount: amount);
  }
}

