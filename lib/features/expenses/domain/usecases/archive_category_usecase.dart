import '../repositories/expense_repository.dart';

class ArchiveCategoryUseCase {
  const ArchiveCategoryUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<void> archive(int id) {
    return _repository.archiveCategory(id);
  }

  Future<void> unarchive(int id) {
    return _repository.unarchiveCategory(id);
  }

  Future<bool> deleteOrArchive(int id) {
    return _repository.deleteCategory(id);
  }
}

