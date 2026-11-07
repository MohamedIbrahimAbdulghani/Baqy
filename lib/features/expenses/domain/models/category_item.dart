class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
    this.isArchived = false,
    this.sortOrder = 0,
    this.createdByAi = false,
    this.createdAt,
  });

  final int id;
  final String name;
  final String icon;
  final String color;
  final bool isDefault;
  final bool isArchived;
  final int sortOrder;
  final bool createdByAi;
  final DateTime? createdAt;

  String get colorHex => color;

  CategoryItem copyWith({
    int? id,
    String? name,
    String? icon,
    String? color,
    bool? isDefault,
    bool? isArchived,
    int? sortOrder,
    bool? createdByAi,
    DateTime? createdAt,
  }) {
    return CategoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      sortOrder: sortOrder ?? this.sortOrder,
      createdByAi: createdByAi ?? this.createdByAi,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
