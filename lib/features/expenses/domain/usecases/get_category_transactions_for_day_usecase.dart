import '../models/transaction_item.dart';
import '../repositories/expense_repository.dart';

class GetCategoryTransactionsForDayUseCase {
  const GetCategoryTransactionsForDayUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<TransactionItem>> call({
    required int categoryId,
    required DateTime day,
  }) {
    return _repository.getCategoryTransactionsForDay(
      categoryId: categoryId,
      day: day,
    );
  }

  Stream<List<TransactionItem>> watch({
    required int categoryId,
    required DateTime day,
  }) {
    return _repository.watchCategoryTransactionsForDay(
      categoryId: categoryId,
      day: day,
    );
  }
}

