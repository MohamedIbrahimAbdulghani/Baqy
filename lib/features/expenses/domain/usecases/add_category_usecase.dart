import '../repositories/expense_repository.dart';

class AddCategoryUseCase {
  const AddCategoryUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<int> call({
    required String name,
    required String icon,
    required String color,
    bool createdByAi = false,
    int sortOrder = 0,
  }) {
    return _repository.addCategory(
      name: name,
      icon: icon,
      color: color,
      isDefault: false,
      createdByAi: createdByAi,
      sortOrder: sortOrder,
    );
  }
}

