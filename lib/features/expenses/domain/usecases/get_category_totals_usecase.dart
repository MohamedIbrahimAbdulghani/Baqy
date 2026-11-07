import '../models/category_total.dart';
import '../repositories/expense_repository.dart';

class GetCategoryTotalsUseCase {
  const GetCategoryTotalsUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<CategoryTotal>> call(String yearMonth) {
    return _repository.getTotalsPerCategoryPerMonth(yearMonth);
  }

  Stream<List<CategoryTotal>> watch(String yearMonth) {
    return _repository.watchTotalsPerCategoryPerMonth(yearMonth);
  }
}

