import '../models/day_transactions.dart';
import '../repositories/expense_repository.dart';

class GetDailyTransactionsUseCase {
  const GetDailyTransactionsUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<DayTransactions>> call(String yearMonth) {
    return _repository.getTransactionsPerDay(yearMonth);
  }
}

