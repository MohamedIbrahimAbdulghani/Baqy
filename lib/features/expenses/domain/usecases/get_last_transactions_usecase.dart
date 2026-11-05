import '../models/transaction_item.dart';
import '../repositories/expense_repository.dart';

class GetLastTransactionsUseCase {
  const GetLastTransactionsUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<TransactionItem>> call() {
    return _repository.getLast3Transactions();
  }
}

