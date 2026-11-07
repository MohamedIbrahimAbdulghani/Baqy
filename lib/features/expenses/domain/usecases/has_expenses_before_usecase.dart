import '../repositories/expense_repository.dart';

class HasExpensesBeforeUseCase {
  const HasExpensesBeforeUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<bool> call(DateTime day) {
    return _repository.hasExpensesBefore(day);
  }

  Stream<bool> watch(DateTime day) {
    return _repository.watchHasExpensesBefore(day);
  }
}

