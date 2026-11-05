import '../models/category_item.dart';
import '../repositories/expense_repository.dart';

class GetCategoriesUseCase {
  const GetCategoriesUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<CategoryItem>> call() {
    return _repository.getCategories();
  }
}

