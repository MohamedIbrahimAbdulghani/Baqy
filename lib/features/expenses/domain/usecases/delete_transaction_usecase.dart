import '../repositories/expense_repository.dart';

class DeleteTransactionUseCase {
  const DeleteTransactionUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<void> call(int id) {
    return _repository.deleteTransaction(id);
  }
}

