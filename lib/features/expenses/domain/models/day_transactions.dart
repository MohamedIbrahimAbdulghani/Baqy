import 'transaction_item.dart';

class DayTransactions {
  const DayTransactions({
    required this.date, // UTC day (year, month, day)
    required this.transactions,
    required this.totalExpenses,
    required this.totalIncome,
  });

  final DateTime date;
  final List<TransactionItem> transactions;
  final int totalExpenses; // integer piastres
  final int totalIncome; // integer piastres
}

