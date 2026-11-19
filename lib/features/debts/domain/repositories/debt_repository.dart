import '../models/debt_item.dart';
import '../models/debt_payment_item.dart';

abstract class DebtRepository {
  /// Watches all debts for a direction ("owe" or "owed"), optionally filtered by archived status.
  Stream<List<DebtItem>> watchDebts({required String direction, bool? archived});

  /// Watches a single debt with its latest paid amount and remaining.
  Stream<DebtItem?> watchDebtById(int id);

  /// Watches all payments for a specific debt, newest first.
  Stream<List<DebtPaymentItem>> watchPaymentsForDebt(int debtId);

  /// Gets all debts.
  Future<List<DebtItem>> getDebts();

  /// Gets a single debt by ID.
  Future<DebtItem?> getDebtById(int id);

  /// Adds a new debt.
  Future<int> addDebt({
    required String personName,
    required String direction,
    required int totalAmount,
    DateTime? dueDate,
    int leadDays = 2,
  });

  /// Updates an existing debt. Cannot set totalAmount below paidAmount.
  Future<void> updateDebt({
    required int id,
    required String personName,
    required String direction,
    required int totalAmount,
    DateTime? dueDate,
    int leadDays = 2,
  });

  /// Deletes a debt, all its payments, and any linked transactions.
  Future<void> deleteDebt(int id);

  /// Records a payment for a debt in one atomic transaction together with its linked transaction row.
  Future<int> recordPayment({
    required int debtId,
    required int amount,
    required DateTime paidAt,
  });

  /// Updates an existing payment amount atomically with its linked transaction row.
  Future<void> updatePayment({
    required int paymentId,
    required int newAmount,
  });

  /// Deletes a single payment and its linked transaction row, restoring the money.
  Future<void> deletePayment(int paymentId);

  /// Undoes a payment, restoring the money to the month and unarchiving if settled.
  Future<void> undoPayment(int paymentId);
}

