import '../models/category_total.dart';
import '../repositories/expense_repository.dart';

class GetCategoryTotalsForDayUseCase {
  const GetCategoryTotalsForDayUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<CategoryTotal>> call(DateTime day) {
    return _repository.getCategoryTotalsForDay(day);
  }
}

