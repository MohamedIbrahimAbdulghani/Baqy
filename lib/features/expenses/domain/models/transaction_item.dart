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
    this.category,
  });

  final int id;
  final int amount; // integer piastres
  final String description;
  final int categoryId;
  final String kind; // "expense" or "income"
  final String source; // "voice" or "text" or "debt"
  final DateTime createdAt; // UTC timestamp
  final CategoryItem? category;
}

