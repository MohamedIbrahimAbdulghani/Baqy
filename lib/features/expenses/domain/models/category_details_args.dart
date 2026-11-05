import 'category_item.dart';

class CategoryDetailsArgs {
  const CategoryDetailsArgs({
    required this.category,
    required this.yearMonth,
    this.day,
    required this.isMonthMode,
  });

  final CategoryItem category;
  final String yearMonth;
  final DateTime? day;
  final bool isMonthMode;
}

