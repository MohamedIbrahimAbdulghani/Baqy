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
