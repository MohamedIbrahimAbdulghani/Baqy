import '../repositories/expense_repository.dart';

class GetYearsWithDataUseCase {
  const GetYearsWithDataUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<int>> call({int? currentYear}) {
    return _repository.getYearsWithData(currentYear: currentYear);
  }

  Stream<List<int>> watch({int? currentYear}) {
    return _repository.watchYearsWithData(currentYear: currentYear);
  }
}

