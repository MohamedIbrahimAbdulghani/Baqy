import '../repositories/expense_repository.dart';

class UpdateTransactionUseCase {
  const UpdateTransactionUseCase(this._repository);

  final ExpenseRepository _repository;

  Future<void> call({
    required int id,
    required int amountInPiastres,
    required String description,
    required int categoryId,
    String? note,
    double? foreignAmount,
    String? foreignCurrency,
  }) {
    if (amountInPiastres <= 0) {
      throw ArgumentError('Amount must be positive.');
    }
    if (amountInPiastres > 100000000 * 100) {
      throw ArgumentError('Amount exceeds maximum limit of 100,000,000 EGP.');
    }

    final sanitizedDescription = description
        .replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '')
        .trim();

    if (sanitizedDescription.isEmpty) {
      throw ArgumentError('Description cannot be empty.');
    }

    final finalDescription = sanitizedDescription.length > 60
        ? sanitizedDescription.substring(0, 60)
        : sanitizedDescription;

    String? sanitizedNote;
    if (note != null) {
      final stripped = note
          .replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '')
          .trim();
      if (stripped.isNotEmpty) {
        sanitizedNote =
            stripped.length > 40 ? stripped.substring(0, 40) : stripped;
      }
    }

    return _repository.updateTransaction(
      id: id,
      amount: amountInPiastres,
      description: finalDescription,
      categoryId: categoryId,
      note: sanitizedNote,
      foreignAmount: foreignAmount,
      foreignCurrency: foreignCurrency,
    );
  }
}

