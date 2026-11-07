import '../models/transaction_item.dart';
import '../repositories/expense_repository.dart';

class RestoreTransactionUseCase {
  const RestoreTransactionUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<void> call(TransactionItem transaction) {
    return _repository.restoreTransaction(transaction);
  }
}

