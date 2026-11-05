import '../repositories/expense_repository.dart';

class GetMonthsWithDataUseCase {
  const GetMonthsWithDataUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<Set<int>> call(int year) {
    return _repository.getMonthsWithData(year);
  }
}

