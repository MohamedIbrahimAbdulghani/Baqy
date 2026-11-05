class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
  });

  final int id;
  final String name;
  final String icon;
  final String color;
  final bool isDefault;
}

