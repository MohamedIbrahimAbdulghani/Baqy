import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/models/debt_item.dart';
import '../../domain/models/debt_payment_item.dart';
import '../../domain/repositories/debt_repository.dart';

class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(this._db, [NotificationService? notificationService])
      : _notificationService = notificationService ?? NotificationService.instance;

  final AppDatabase _db;
  final NotificationService _notificationService;

  Future<int> _getOrCreateDebtCategoryId() async {
    // 1. Look for existing category named 'ديون'
    final cat = await (_db.select(_db.categories)
          ..where((c) => c.name.equals('ديون')))
        .getSingleOrNull();
    if (cat != null) return cat.id;

    // 2. Insert category 'ديون'
    return await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            name: 'ديون',
            icon: 'debts',
            colorHex: '#C0644B',
            isDefault: const Value(true),
            sortOrder: const Value(22),
            createdAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  String _sanitizeName(String name) {
    final stripped = name.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();
    if (stripped.isEmpty) {
      throw ArgumentError('الاسم مطلوب');
    }
    return stripped.length > 40 ? stripped.substring(0, 40) : stripped;
  }

  void _validateAmount(int amountPiastres) {
    if (amountPiastres <= 0) {
      throw ArgumentError('المبلغ يجب أن يكون أكبر من الصفر');
    }
    // Max 100,000,000 EGP = 10,000,000,000 piastres
    if (amountPiastres > 10000000000) {
      throw ArgumentError('المبلغ يتجاوز الحد الأقصى 100,000,000 جنيه');
    }
  }

  @override
  Stream<List<DebtItem>> watchDebts({required String direction, bool? archived}) {
    final query = '''
      SELECT 
        d.id,
        d.person_name,
        d.direction,
        d.total_amount,
        d.due_date,
        d.lead_days,
        d.reminder_enabled,
        d.archived,
        d.created_at,
        COALESCE(SUM(p.amount), 0) AS paid_amount,
        COUNT(p.id) AS payments_count
      FROM debts d
      LEFT JOIN debt_payments p ON p.debt_id = d.id
      WHERE d.direction = ?1
        ${archived != null ? 'AND d.archived = ?2' : ''}
      GROUP BY d.id
      ORDER BY d.created_at DESC, d.id DESC;
    ''';

    final variables = <Variable>[
      Variable<String>(direction),
      if (archived != null) Variable<bool>(archived),
    ];

    return _db
        .customSelect(
          query,
          variables: variables,
          readsFrom: {_db.debts, _db.debtPayments},
        )
        .watch()
        .map((rows) {
          return rows.map((row) {
            final dueDateSec = row.read<int?>('due_date');
            final createdAtSec = row.read<int>('created_at');
            return DebtItem(
              id: row.read<int>('id'),
              personName: row.read<String>('person_name'),
              direction: row.read<String>('direction'),
              totalAmount: row.read<int>('total_amount'),
              dueDate: dueDateSec != null
                  ? DateTime.fromMillisecondsSinceEpoch(dueDateSec * 1000, isUtc: true)
                  : null,
              leadDays: row.read<int?>('lead_days') ?? 2,
              reminderEnabled: row.read<bool>('reminder_enabled'),
              archived: row.read<bool>('archived'),
              createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000, isUtc: true),
              paidAmount: row.read<int>('paid_amount'),
              paymentsCount: row.read<int>('payments_count'),
            );
          }).toList();
        });
  }

  @override
  Stream<DebtItem?> watchDebtById(int id) {
    const query = '''
      SELECT 
        d.id,
        d.person_name,
        d.direction,
        d.total_amount,
        d.due_date,
        d.lead_days,
        d.reminder_enabled,
        d.archived,
        d.created_at,
        COALESCE(SUM(p.amount), 0) AS paid_amount,
        COUNT(p.id) AS payments_count
      FROM debts d
      LEFT JOIN debt_payments p ON p.debt_id = d.id
      WHERE d.id = ?1
      GROUP BY d.id
      LIMIT 1;
    ''';

    return _db
        .customSelect(
          query,
          variables: [Variable<int>(id)],
          readsFrom: {_db.debts, _db.debtPayments},
        )
        .watchSingleOrNull()
        .map((row) {
          if (row == null) return null;
          final dueDateSec = row.read<int?>('due_date');
          final createdAtSec = row.read<int>('created_at');
          return DebtItem(
            id: row.read<int>('id'),
            personName: row.read<String>('person_name'),
            direction: row.read<String>('direction'),
            totalAmount: row.read<int>('total_amount'),
            dueDate: dueDateSec != null
                ? DateTime.fromMillisecondsSinceEpoch(dueDateSec * 1000, isUtc: true)
                : null,
            leadDays: row.read<int?>('lead_days') ?? 2,
            reminderEnabled: row.read<bool>('reminder_enabled'),
            archived: row.read<bool>('archived'),
            createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000, isUtc: true),
            paidAmount: row.read<int>('paid_amount'),
            paymentsCount: row.read<int>('payments_count'),
          );
        });
  }

  @override
  Stream<List<DebtPaymentItem>> watchPaymentsForDebt(int debtId) {
    return (_db.select(_db.debtPayments)
          ..where((p) => p.debtId.equals(debtId))
          ..orderBy([
            (p) => OrderingTerm(expression: p.paidAt, mode: OrderingMode.desc),
            (p) => OrderingTerm(expression: p.id, mode: OrderingMode.desc),
          ]))
        .watch()
        .map((rows) {
          return rows.map((r) {
            return DebtPaymentItem(
              id: r.id,
              debtId: r.debtId,
              amount: r.amount,
              paidAt: r.paidAt,
              transactionId: r.transactionId,
            );
          }).toList();
        });
  }

  @override
  Future<List<DebtItem>> getDebts() async {
    const query = '''
      SELECT 
        d.id,
        d.person_name,
        d.direction,
        d.total_amount,
        d.due_date,
        d.lead_days,
        d.reminder_enabled,
        d.archived,
        d.created_at,
        COALESCE(SUM(p.amount), 0) AS paid_amount,
        COUNT(p.id) AS payments_count
      FROM debts d
      LEFT JOIN debt_payments p ON p.debt_id = d.id
      GROUP BY d.id
      ORDER BY d.created_at DESC, d.id DESC;
    ''';

    final rows = await _db.customSelect(query).get();
    return rows.map((row) {
      final dueDateSec = row.read<int?>('due_date');
      final createdAtSec = row.read<int>('created_at');
      return DebtItem(
        id: row.read<int>('id'),
        personName: row.read<String>('person_name'),
        direction: row.read<String>('direction'),
        totalAmount: row.read<int>('total_amount'),
        dueDate: dueDateSec != null
            ? DateTime.fromMillisecondsSinceEpoch(dueDateSec * 1000, isUtc: true)
            : null,
        leadDays: row.read<int?>('lead_days') ?? 2,
        reminderEnabled: row.read<bool>('reminder_enabled'),
        archived: row.read<bool>('archived'),
        createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000, isUtc: true),
        paidAmount: row.read<int>('paid_amount'),
        paymentsCount: row.read<int>('payments_count'),
      );
    }).toList();
  }

  @override
  Future<DebtItem?> getDebtById(int id) async {
    const query = '''
      SELECT 
        d.id,
        d.person_name,
        d.direction,
        d.total_amount,
        d.due_date,
        d.lead_days,
        d.reminder_enabled,
        d.archived,
        d.created_at,
        COALESCE(SUM(p.amount), 0) AS paid_amount,
        COUNT(p.id) AS payments_count
      FROM debts d
      LEFT JOIN debt_payments p ON p.debt_id = d.id
      WHERE d.id = ?1
      GROUP BY d.id
      LIMIT 1;
    ''';

    final row = await _db
        .customSelect(query, variables: [Variable<int>(id)])
        .getSingleOrNull();

    if (row == null) return null;
    final dueDateSec = row.read<int?>('due_date');
    final createdAtSec = row.read<int>('created_at');
    return DebtItem(
      id: row.read<int>('id'),
      personName: row.read<String>('person_name'),
      direction: row.read<String>('direction'),
      totalAmount: row.read<int>('total_amount'),
      dueDate: dueDateSec != null
          ? DateTime.fromMillisecondsSinceEpoch(dueDateSec * 1000, isUtc: true)
          : null,
      leadDays: row.read<int?>('lead_days') ?? 2,
      reminderEnabled: row.read<bool>('reminder_enabled'),
      archived: row.read<bool>('archived'),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtSec * 1000, isUtc: true),
      paidAmount: row.read<int>('paid_amount'),
      paymentsCount: row.read<int>('payments_count'),
    );
  }

  @override
  Future<int> addDebt({
    required String personName,
    required String direction,
    required int totalAmount,
    DateTime? dueDate,
    int leadDays = 2,
  }) async {
    final sanitizedName = _sanitizeName(personName);
    _validateAmount(totalAmount);
    if (direction != 'owe' && direction != 'owed') {
      throw ArgumentError('Direction must be "owe" or "owed"');
    }

    final id = await _db.into(_db.debts).insert(
          DebtsCompanion.insert(
            personName: sanitizedName,
            direction: direction,
            totalAmount: totalAmount,
            dueDate: Value(dueDate?.toUtc()),
            leadDays: Value(leadDays),
            reminderEnabled: Value(dueDate != null),
            archived: const Value(false),
            createdAt: DateTime.now().toUtc(),
          ),
        );

    // Schedule notification if due date set
    if (dueDate != null) {
      final debts = await getDebts();
      await _notificationService.rescheduleDebts(debts);
    }

    return id;
  }

  @override
  Future<void> updateDebt({
    required int id,
    required String personName,
    required String direction,
    required int totalAmount,
    DateTime? dueDate,
    int leadDays = 2,
  }) async {
    final sanitizedName = _sanitizeName(personName);
    _validateAmount(totalAmount);
    if (direction != 'owe' && direction != 'owed') {
      throw ArgumentError('Direction must be "owe" or "owed"');
    }

    final existing = await getDebtById(id);
    if (existing == null) {
      throw ArgumentError('الدين غير موجود');
    }

    if (totalAmount < existing.paidAmount) {
      throw ArgumentError('المبلغ أقل من المدفوع');
    }

    final isSettled = (totalAmount - existing.paidAmount) <= 0;

    await _db.transaction(() async {
      await (_db.update(_db.debts)..where((d) => d.id.equals(id))).write(
        DebtsCompanion(
          personName: Value(sanitizedName),
          direction: Value(direction),
          totalAmount: Value(totalAmount),
          dueDate: Value(dueDate?.toUtc()),
          leadDays: Value(leadDays),
          reminderEnabled: Value(dueDate != null),
          archived: Value(isSettled),
        ),
      );

      // If name or direction changed, update linked transactions
      final payments = await (_db.select(_db.debtPayments)..where((p) => p.debtId.equals(id))).get();
      for (final p in payments) {
        if (p.transactionId != null) {
          await (_db.update(_db.transactions)..where((t) => t.id.equals(p.transactionId!))).write(
            TransactionsCompanion(
              description: Value(sanitizedName),
              kind: Value(direction == 'owe' ? 'expense' : 'income'),
            ),
          );
        }
      }
    });

    final debts = await getDebts();
    await _notificationService.rescheduleDebts(debts);
  }

  @override
  Future<void> deleteDebt(int id) async {
    await _db.transaction(() async {
      final payments = await (_db.select(_db.debtPayments)..where((p) => p.debtId.equals(id))).get();
      final txIds = payments.map((p) => p.transactionId).whereType<int>().toList();

      await (_db.delete(_db.debtPayments)..where((p) => p.debtId.equals(id))).go();
      for (final txId in txIds) {
        await (_db.delete(_db.transactions)..where((t) => t.id.equals(txId))).go();
      }
      await (_db.delete(_db.debts)..where((d) => d.id.equals(id))).go();
    });

    await _notificationService.cancelDebtNotification(id);
    final debts = await getDebts();
    await _notificationService.rescheduleDebts(debts);
  }

  @override
  Future<int> recordPayment({
    required int debtId,
    required int amount,
    required DateTime paidAt,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('المبلغ يجب أن يكون أكبر من الصفر');
    }

    final debt = await getDebtById(debtId);
    if (debt == null) {
      throw ArgumentError('الدين غير موجود');
    }

    if (amount > debt.remaining) {
      throw ArgumentError('المبلغ أكبر من المتبقي');
    }

    final int paymentId = await _db.transaction(() async {
      final catId = await _getOrCreateDebtCategoryId();

      // 1. Linked transaction
      // For "عليا" -> expense in category "ديون" with source "debt"
      // For "ليا" -> income with source "debt"
      final isOwe = debt.direction == 'owe';
      final txId = await _db.into(_db.transactions).insert(
            TransactionsCompanion.insert(
              amount: amount,
              description: debt.personName,
              categoryId: catId,
              kind: isOwe ? 'expense' : 'income',
              source: 'debt',
              createdAt: paidAt.toUtc(),
            ),
          );

      // 2. Debt payment row
      final pId = await _db.into(_db.debtPayments).insert(
            DebtPaymentsCompanion.insert(
              debtId: debtId,
              amount: amount,
              paidAt: paidAt.toUtc(),
              transactionId: Value(txId),
            ),
          );

      // 3. Check remaining: if <= 0, automatically archive debt
      final newRemaining = debt.remaining - amount;
      if (newRemaining <= 0) {
        await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
          const DebtsCompanion(archived: Value(true)),
        );
      }

      return pId;
    });

    final debts = await getDebts();
    await _notificationService.rescheduleDebts(debts);

    return paymentId;
  }

  @override
  Future<void> updatePayment({
    required int paymentId,
    required int newAmount,
  }) async {
    if (newAmount <= 0) {
      throw ArgumentError('المبلغ يجب أن يكون أكبر من الصفر');
    }

    int? debtId;
    await _db.transaction(() async {
      final payment = await (_db.select(_db.debtPayments)..where((p) => p.id.equals(paymentId))).getSingleOrNull();
      if (payment == null) {
        throw ArgumentError('الدفعة غير موجودة');
      }
      debtId = payment.debtId;

      final debt = await getDebtById(debtId!);
      if (debt == null) {
        throw ArgumentError('الدين غير موجود');
      }

      final maxAllowed = debt.remaining + payment.amount;
      if (newAmount > maxAllowed) {
        throw ArgumentError('المبلغ أكبر من المتبقي');
      }

      // Update debt_payments row
      await (_db.update(_db.debtPayments)..where((p) => p.id.equals(paymentId))).write(
        DebtPaymentsCompanion(amount: Value(newAmount)),
      );

      // Update linked transactions row if exists
      if (payment.transactionId != null) {
        await (_db.update(_db.transactions)..where((t) => t.id.equals(payment.transactionId!))).write(
          TransactionsCompanion(amount: Value(newAmount)),
        );
      }

      // Recalculate remaining
      final newRemaining = maxAllowed - newAmount;
      await (_db.update(_db.debts)..where((d) => d.id.equals(debtId!))).write(
        DebtsCompanion(archived: Value(newRemaining <= 0)),
      );
    });

    if (debtId != null) {
      final debts = await getDebts();
      await _notificationService.rescheduleDebts(debts);
    }
  }

  @override
  Future<void> deletePayment(int paymentId) async {
    await undoPayment(paymentId);
  }

  @override
  Future<void> undoPayment(int paymentId) async {
    int? debtId;
    await _db.transaction(() async {
      final payment = await (_db.select(_db.debtPayments)..where((p) => p.id.equals(paymentId))).getSingleOrNull();
      if (payment == null) return;
      debtId = payment.debtId;
      final txId = payment.transactionId;

      await (_db.delete(_db.debtPayments)..where((p) => p.id.equals(paymentId))).go();
      if (txId != null) {
        await (_db.delete(_db.transactions)..where((t) => t.id.equals(txId))).go();
      }

      // Check debt's updated remaining: if > 0, unarchive it
      final currentDebt = await getDebtById(debtId!);
      if (currentDebt != null && currentDebt.remaining > 0 && currentDebt.archived) {
        await (_db.update(_db.debts)..where((d) => d.id.equals(debtId!))).write(
          const DebtsCompanion(archived: Value(false)),
        );
      }
    });

    if (debtId != null) {
      final debts = await getDebts();
      await _notificationService.rescheduleDebts(debts);
    }
  }
}

