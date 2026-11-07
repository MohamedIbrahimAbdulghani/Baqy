import '../repositories/expense_repository.dart';

class SaveUserRuleUseCase {
  const SaveUserRuleUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<void> call({
    required String keyword,
    required int categoryId,
  }) {
    return _repository.saveUserRule(
      keyword: keyword,
      categoryId: categoryId,
    );
  }

  Future<List<({int id, String keyword, String categoryName, int categoryId})>>
      getRecentRules({int limit = 50}) {
    return _repository.getRecentUserRules(limit: limit);
  }
}

