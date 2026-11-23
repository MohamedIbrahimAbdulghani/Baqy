import 'category_item.dart';

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.amount,
    required this.description,
    required this.categoryId,
    required this.kind,
    required this.source,
    required this.createdAt,
    this.note,
    this.foreignAmount,
    this.foreignCurrency,
    this.category,
  });

  final int id;
  final int amount; // integer piastres in EGP
  final String description;
  final int categoryId;
  final String kind; // "expense" or "income"
  final String source; // "voice" or "text" or "debt"
  final String? note; // optional place note
  final double? foreignAmount;
  final String? foreignCurrency;
  final DateTime createdAt; // UTC timestamp
  final CategoryItem? category;

  /// Whether this transaction originates from debts or goals, and therefore
  /// cannot be edited or deleted from general expense views (Home or Month/Category Details).
  bool get isLockedFromExpenses =>
      id < 0 ||
      source == 'debt' ||
      source == 'goal' ||
      kind == 'saving' ||
      categoryId < 0 ||
      category?.name == 'تحويش' ||
      (category?.id != null && category!.id < 0);

  /// Whether this transaction represents an addition/deposit to the user's money
  /// (e.g. income, collecting a debt owed to the user).
  bool get isAddition {
    if (kind == 'income') return amount >= 0;
    if (kind == 'saving') return amount < 0; // withdrawal from goal back to cash
    if (kind == 'expense') return amount < 0; // refund back to cash
    return false;
  }

  /// Whether this transaction represents a deduction/withdrawal from the user's money
  /// (e.g. regular expense, paying a debt owed by the user, or saving into a goal).
  bool get isDeduction => !isAddition;

  TransactionItem copyWith({
    int? id,
    int? amount,
    String? description,
    int? categoryId,
    String? kind,
    String? source,
    String? note,
    double? foreignAmount,
    String? foreignCurrency,
    DateTime? createdAt,
    CategoryItem? category,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      kind: kind ?? this.kind,
      source: source ?? this.source,
      note: note ?? this.note,
      foreignAmount: foreignAmount ?? this.foreignAmount,
      foreignCurrency: foreignCurrency ?? this.foreignCurrency,
      createdAt: createdAt ?? this.createdAt,
      category: category ?? this.category,
    );
  }
}
