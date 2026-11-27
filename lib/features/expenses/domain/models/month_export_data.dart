class MonthExportCategory {
  final int categoryId;
  final String name;
  final String colorHex;
  final int totalAmount; // integer piastres
  final int transactionCount;
  final double percentage; // percentage of total month expenses

  const MonthExportCategory({
    required this.categoryId,
    required this.name,
    required this.colorHex,
    required this.totalAmount,
    required this.transactionCount,
    required this.percentage,
  });
}

class MonthExportDay {
  final DateTime date;
  final int dayNumber;
  final String dayName;
  final int totalAmount; // integer piastres

  const MonthExportDay({
    required this.date,
    required this.dayNumber,
    required this.dayName,
    required this.totalAmount,
  });
}

class MonthExportTransaction {
  final int id;
  final DateTime createdAt;
  final String dateText;
  final String dayName;
  final String timeText;
  final String categoryName;
  final String categoryColorHex;
  final String description;
  final String? note;
  final String kind; // expense / income / saving
  final String typeText; // localized string
  final int amount; // integer piastres

  const MonthExportTransaction({
    required this.id,
    required this.createdAt,
    required this.dateText,
    required this.dayName,
    required this.timeText,
    required this.categoryName,
    required this.categoryColorHex,
    required this.description,
    this.note,
    required this.kind,
    required this.typeText,
    required this.amount,
  });
}

class MonthExportData {
  final String yearMonth;
  final String monthTitle;
  final int budget; // integer piastres
  final int income; // integer piastres
  final int expenses; // integer piastres
  final int remaining; // integer piastres
  final int operationsCount;
  final DateTime createdAt;
  final List<MonthExportCategory> categories;
  final List<MonthExportDay> dailyExpenses;
  final List<MonthExportTransaction> transactions;

  const MonthExportData({
    required this.yearMonth,
    required this.monthTitle,
    required this.budget,
    required this.income,
    required this.expenses,
    required this.remaining,
    required this.operationsCount,
    required this.createdAt,
    required this.categories,
    required this.dailyExpenses,
    required this.transactions,
  });
}
