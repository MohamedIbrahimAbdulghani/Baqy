import '../models/month_export_data.dart';
import '../repositories/expense_repository.dart';

class BuildMonthExportDataUseCase {
  final ExpenseRepository _repository;

  const BuildMonthExportDataUseCase(this._repository);

  Future<MonthExportData?> call({
    required String yearMonth,
    required String Function(DateTime) formatDayName,
    required String Function(DateTime) formatTime,
    required String typeExpenseLabel,
    required String typeIncomeLabel,
    required String typeSavingLabel,
    required String monthTitle,
  }) async {
    // 1. Fetch MonthRemaining
    final remaining = await _repository.getRemainingOfMonth(yearMonth);

    // 2. Fetch category totals (filtered to active > 0)
    final catTotals = await _repository.getTotalsPerCategoryPerMonth(yearMonth);
    final validCatTotals =
        catTotals.where((c) => c.totalAmount > 0 && c.transactionCount > 0).toList();

    // 3. Fetch all transactions (ordered oldest first)
    final transactions = await _repository.getAllTransactionsForMonth(yearMonth);

    if (transactions.isEmpty) {
      return null;
    }

    final totalExpensesPiastres =
        validCatTotals.fold<int>(0, (sum, c) => sum + c.totalAmount);

    // Map categories with percentage
    final categories = validCatTotals.map((cat) {
      final double pct = totalExpensesPiastres > 0
          ? (cat.totalAmount * 100.0) / totalExpensesPiastres
          : 0.0;
      return MonthExportCategory(
        categoryId: cat.category.id,
        name: cat.category.name,
        colorHex: cat.category.color,
        totalAmount: cat.totalAmount,
        transactionCount: cat.transactionCount,
        percentage: double.parse(pct.toStringAsFixed(1)),
      );
    }).toList();

    // Map daily expenses (only expense operations, grouped by day)
    final Map<int, int> daySums = {};
    final Map<int, DateTime> dayDates = {};

    for (final tx in transactions) {
      if (tx.kind == 'expense') {
        final local = tx.createdAt.toLocal();
        daySums[local.day] = (daySums[local.day] ?? 0) + tx.amount;
        dayDates[local.day] = DateTime(local.year, local.month, local.day);
      }
    }

    final sortedDays = daySums.keys.toList()..sort();
    final dailyExpenses = sortedDays.map((d) {
      final date = dayDates[d]!;
      return MonthExportDay(
        date: date,
        dayNumber: d,
        dayName: formatDayName(date),
        totalAmount: daySums[d]!,
      );
    }).toList();

    // Map transactions
    final exportTransactions = transactions.map((tx) {
      final local = tx.createdAt.toLocal();
      final dateText =
          '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      final typeText = tx.kind == 'income'
          ? typeIncomeLabel
          : (tx.kind == 'saving' ? typeSavingLabel : typeExpenseLabel);

      return MonthExportTransaction(
        id: tx.id,
        createdAt: tx.createdAt,
        dateText: dateText,
        dayName: formatDayName(local),
        timeText: formatTime(local),
        categoryName:
            tx.category?.name ?? (tx.kind == 'saving' ? 'تحويش' : 'أخرى'),
        categoryColorHex: tx.category?.color ?? '#4E8B7A',
        description: tx.description,
        note: tx.note,
        kind: tx.kind,
        typeText: typeText,
        amount: tx.amount,
      );
    }).toList();

    return MonthExportData(
      yearMonth: yearMonth,
      monthTitle: monthTitle,
      budget: remaining.budget,
      income: remaining.income,
      expenses: remaining.expenses,
      remaining: remaining.remaining,
      operationsCount: transactions.length,
      createdAt: DateTime.now(),
      categories: categories,
      dailyExpenses: dailyExpenses,
      transactions: exportTransactions,
    );
  }
}
