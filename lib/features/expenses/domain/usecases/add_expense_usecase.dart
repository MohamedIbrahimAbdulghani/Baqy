import '../repositories/expense_repository.dart';

class AddExpenseUseCase {
  const AddExpenseUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<int> call({
    required int amountInPiastres,
    required String description,
    required int categoryId,
    DateTime? createdAt,
  }) {
    if (amountInPiastres <= 0) {
      throw ArgumentError('Amount must be positive.');
    }
    // 100,000,000 EGP = 10,000,000,000 piastres
    if (amountInPiastres > 100000000 * 100) {
      throw ArgumentError('Amount exceeds maximum limit of 100,000,000 EGP.');
    }

    // Strip control characters and cap at 60 chars
    final sanitizedDescription = description
        .replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '')
        .trim();

    if (sanitizedDescription.isEmpty) {
      throw ArgumentError('Description cannot be empty.');
    }

    final finalDescription = sanitizedDescription.length > 60
        ? sanitizedDescription.substring(0, 60)
        : sanitizedDescription;

    return _repository.addTransaction(
      amount: amountInPiastres,
      description: finalDescription,
      categoryId: categoryId,
      kind: 'expense',
      source: 'text',
      createdAt: createdAt ?? DateTime.now().toUtc(),
    );
  }
}

