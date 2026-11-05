import '../models/transaction_item.dart';
import '../repositories/expense_repository.dart';

class GetLastTransactionsForMonthUseCase {
  const GetLastTransactionsForMonthUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<TransactionItem>> call(String yearMonth, {int limit = 3}) {
    return _repository.getLastTransactionsForMonth(yearMonth, limit: limit);
  }
}

