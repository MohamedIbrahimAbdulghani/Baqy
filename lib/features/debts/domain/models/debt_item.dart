class DebtItem {
  const DebtItem({
    required this.id,
    required this.personName,
    required this.direction,
    required this.totalAmount,
    this.dueDate,
    this.leadDays = 2,
    required this.reminderEnabled,
    required this.archived,
    required this.createdAt,
    this.updatedAt,
    this.paidAmount = 0,
    this.paymentsCount = 0,
  });

  final int id;
  final String personName;
  final String direction; // "owe" or "owed"
  final int totalAmount; // piastres
  final DateTime? dueDate;
  final int leadDays;
  final bool reminderEnabled;
  final bool archived;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int paidAmount; // piastres
  final int paymentsCount;

  bool get isOwe => direction == 'owe';
  bool get isOwed => direction == 'owed';

  int get remaining {
    final diff = totalAmount - paidAmount;
    return diff > 0 ? diff : 0;
  }

  bool get isSettled => remaining <= 0 || archived;

  double get progress {
    if (totalAmount <= 0) return 0.0;
    return (paidAmount / totalAmount).clamp(0.0, 1.0);
  }

  DebtItem copyWith({
    int? id,
    String? personName,
    String? direction,
    int? totalAmount,
    DateTime? dueDate,
    int? leadDays,
    bool? reminderEnabled,
    bool? archived,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? paidAmount,
    int? paymentsCount,
  }) {
    return DebtItem(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      direction: direction ?? this.direction,
      totalAmount: totalAmount ?? this.totalAmount,
      dueDate: dueDate ?? this.dueDate,
      leadDays: leadDays ?? this.leadDays,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      paidAmount: paidAmount ?? this.paidAmount,
      paymentsCount: paymentsCount ?? this.paymentsCount,
    );
  }
}

