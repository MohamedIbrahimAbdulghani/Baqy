import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../data/repositories/debt_repository_impl.dart';
import '../../domain/models/debt_item.dart';
import '../../domain/models/debt_payment_item.dart';
import '../../domain/repositories/debt_repository.dart';

final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DebtRepositoryImpl(db);
});

/// Current active tab switch: "owe" ("عليا") or "owed" ("ليا")
class DebtDirectionNotifier extends Notifier<String> {
  @override
  String build() => 'owe';

  void setDirection(String dir) {
    state = dir;
  }
}

final debtDirectionProvider =
    NotifierProvider<DebtDirectionNotifier, String>(DebtDirectionNotifier.new);

/// Stream of active (unsettled) debts for a direction
final activeDebtsStreamProvider =
    StreamProvider.family<List<DebtItem>, String>((ref, direction) {
  final repo = ref.watch(debtRepositoryProvider);
  return repo.watchDebts(direction: direction, archived: false);
});

/// Stream of settled debts for a direction
final settledDebtsStreamProvider =
    StreamProvider.family<List<DebtItem>, String>((ref, direction) {
  final repo = ref.watch(debtRepositoryProvider);
  return repo.watchDebts(direction: direction, archived: true);
});

/// Stream of all debts (active + settled) for a direction
final allDebtsForDirectionStreamProvider =
    StreamProvider.family<List<DebtItem>, String>((ref, direction) {
  final repo = ref.watch(debtRepositoryProvider);
  return repo.watchDebts(direction: direction);
});

/// Stream of single debt details by ID
final debtDetailsStreamProvider =
    StreamProvider.family<DebtItem?, int>((ref, debtId) {
  final repo = ref.watch(debtRepositoryProvider);
  return repo.watchDebtById(debtId);
});

/// Stream of payments for a debt by debtId
final debtPaymentsStreamProvider =
    StreamProvider.family<List<DebtPaymentItem>, int>((ref, debtId) {
  final repo = ref.watch(debtRepositoryProvider);
  return repo.watchPaymentsForDebt(debtId);
});

/// Total remaining amount for active debts of the selected direction
final selectedDirectionTotalRemainingProvider = Provider<int>((ref) {
  final direction = ref.watch(debtDirectionProvider);
  final activeDebtsAsync = ref.watch(activeDebtsStreamProvider(direction));
  return activeDebtsAsync.when(
    data: (debts) => debts.fold<int>(0, (sum, item) => sum + item.remaining),
    loading: () => 0,
    error: (e, s) => 0,
  );
});
