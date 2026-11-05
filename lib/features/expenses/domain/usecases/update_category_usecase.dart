import '../repositories/expense_repository.dart';

class UpdateCategoryUseCase {
  const UpdateCategoryUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<void> call({
    required int id,
    required String name,
    required String icon,
    required String color,
  }) {
    return _repository.updateCategory(
      id: id,
      name: name,
      icon: icon,
      color: color,
    );
  }
}

