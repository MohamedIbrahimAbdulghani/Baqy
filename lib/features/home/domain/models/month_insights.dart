/// Domain model representing analytical insights for the selected month.
/// Pure Dart - zero Flutter dependencies.
class MonthInsights {
  final String burnRateText;
  final String dailyAllowanceText;
  final String comparisonText;
  final bool isBurnRateWarning;
  final bool isSpendingLess;

  const MonthInsights({
    required this.burnRateText,
    required this.dailyAllowanceText,
    required this.comparisonText,
    this.isBurnRateWarning = false,
    this.isSpendingLess = true,
  });
}
