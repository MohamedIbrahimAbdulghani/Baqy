class MonthRolloverInfo {
  final String previousYearMonth;
  final String currentYearMonth;
  final int previousMonthNumber;
  final int currentMonthNumber;
  final int leftoverPiastres;
  final int leftoverEgp;

  const MonthRolloverInfo({
    required this.previousYearMonth,
    required this.currentYearMonth,
    required this.previousMonthNumber,
    required this.currentMonthNumber,
    required this.leftoverPiastres,
    required this.leftoverEgp,
  });
}
