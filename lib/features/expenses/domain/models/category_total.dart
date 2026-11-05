import 'category_item.dart';

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.totalAmount, // integer piastres
    this.transactionCount = 0,
  });

  final CategoryItem category;
  final int totalAmount;
  final int transactionCount;
}
