class MonthRemaining {
  const MonthRemaining({
    required this.yearMonth,
    required this.budget, // integer piastres
    required this.income, // integer piastres
    required this.monthMoney, // integer piastres: budget + income
    required this.expenses, // integer piastres
    required this.remaining, // integer piastres: monthMoney - expenses - goalSavings
    this.goalSavings = 0, // integer piastres
  });

  final String yearMonth;
  final int budget;
  final int income;
  final int monthMoney;
  final int expenses;
  final int remaining;
  final int goalSavings;
}

