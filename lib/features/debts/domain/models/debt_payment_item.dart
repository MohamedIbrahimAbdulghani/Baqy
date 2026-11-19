class DebtPaymentItem {
  const DebtPaymentItem({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidAt,
    this.transactionId,
  });

  final int id;
  final int debtId;
  final int amount; // piastres
  final DateTime paidAt;
  final int? transactionId;
}

