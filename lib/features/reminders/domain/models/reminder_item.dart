/// Domain entity representing a reminder item.
class ReminderItem {
  final int id;
  final String name;
  final int amount; // in piastres
  final DateTime dueDate; // stored due date (UTC/local)
  final String repeat; // "once" or "monthly"
  final int leadDays; // 1, 2, or 3

  const ReminderItem({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDate,
    required this.repeat,
    required this.leadDays,
  });

  /// Target amount in Egyptian Pounds (EGP)
  int get amountEgp => amount ~/ 100;

  /// Whether this reminder repeats monthly
  bool get isMonthly => repeat == 'monthly';

  /// Whether this reminder is one-time
  bool get isOnce => repeat == 'once';

  /// Copy with modifications
  ReminderItem copyWith({
    int? id,
    String? name,
    int? amount,
    DateTime? dueDate,
    String? repeat,
    int? leadDays,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      repeat: repeat ?? this.repeat,
      leadDays: leadDays ?? this.leadDays,
    );
  }
}
