import '../models/transaction_item.dart';
import '../repositories/expense_repository.dart';

class GetCategoryTransactionsForMonthUseCase {
  const GetCategoryTransactionsForMonthUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<List<TransactionItem>> call({
    required int categoryId,
    required String yearMonth,
  }) {
    return _repository.getCategoryTransactionsForMonth(
      categoryId: categoryId,
      yearMonth: yearMonth,
    );
  }
}

