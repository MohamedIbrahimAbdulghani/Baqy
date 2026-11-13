class GoalItem {
  final int id;
  final String name;
  final int targetAmount; // in piastres
  final int monthlySaving; // in piastres
  final DateTime createdAt; // UTC
  final int totalSaved; // in piastres
  final String? icon;

  const GoalItem({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.monthlySaving,
    required this.createdAt,
    this.totalSaved = 0,
    this.icon,
  });

  /// Target amount in Egyptian Pounds (EGP)
  int get targetEgp => targetAmount ~/ 100;

  /// Monthly saving amount in Egyptian Pounds (EGP)
  int get monthlySavingEgp => monthlySaving ~/ 100;

  /// Total saved amount in Egyptian Pounds (EGP)
  int get totalSavedEgp => totalSaved ~/ 100;

  /// Remaining amount needed to reach the target (in piastres)
  int get remainingToTarget =>
      (targetAmount - totalSaved) > 0 ? (targetAmount - totalSaved) : 0;

  /// Remaining amount needed to reach the target in EGP
  int get remainingToTargetEgp => remainingToTarget ~/ 100;

  /// Percentage of target saved (0 to 100+)
  int get percentage =>
      targetAmount > 0 ? ((totalSaved / targetAmount) * 100).round() : 0;

  /// Progress ratio clamped between 0.0 and 1.0 for progress bars
  double get progress =>
      targetAmount > 0 ? (totalSaved / targetAmount).clamp(0.0, 1.0) : 0.0;

  /// Number of months to reach the goal: target ÷ monthly saving (rounded up)
  int? get monthsToGoal {
    if (monthlySavingEgp <= 0) return null;
    return (targetEgp / monthlySavingEgp).ceil();
  }
}

