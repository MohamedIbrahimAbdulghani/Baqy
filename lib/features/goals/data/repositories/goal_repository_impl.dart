import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/goal_icon_helper.dart';
import '../../domain/models/goal_item.dart';
import '../../domain/repositories/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  final AppDatabase _db;

  GoalRepositoryImpl(this._db);

  static final RegExp _controlCharsRegex = RegExp(r'[\x00-\x1F\x7F-\x9F]');

  /// Strips control characters, trims, and truncates to max 40 chars
  static String sanitizeName(String raw) {
    var cleaned = raw.replaceAll(_controlCharsRegex, '').trim();
    if (cleaned.length > 40) {
      cleaned = cleaned.substring(0, 40).trim();
    }
    return cleaned;
  }

  GoalItem _mapJoinedToGoalItem(TypedResult row, Expression<int> totalSavedExpr) {
    final goalData = row.readTable(_db.goals);
    final totalSaved = row.read(totalSavedExpr) ?? 0;
    return GoalItem(
      id: goalData.id,
      name: goalData.name,
      targetAmount: goalData.targetAmount,
      monthlySaving: goalData.monthlySaving,
      createdAt: goalData.createdAt,
      totalSaved: totalSaved,
      icon: goalData.icon,
    );
  }

  @override
  Future<List<GoalItem>> getGoals() async {
    final totalSavedExpr = _db.goalSavings.amount.sum();
    final query = _db.select(_db.goals).join([
      leftOuterJoin(
        _db.goalSavings,
        _db.goalSavings.goalId.equalsExp(_db.goals.id),
      ),
    ])
      ..addColumns([totalSavedExpr])
      ..groupBy([_db.goals.id])
      ..orderBy([
        OrderingTerm(expression: _db.goals.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map((r) => _mapJoinedToGoalItem(r, totalSavedExpr)).toList();
  }

  @override
  Stream<List<GoalItem>> watchGoals() {
    final totalSavedExpr = _db.goalSavings.amount.sum();
    final query = _db.select(_db.goals).join([
      leftOuterJoin(
        _db.goalSavings,
        _db.goalSavings.goalId.equalsExp(_db.goals.id),
      ),
    ])
      ..addColumns([totalSavedExpr])
      ..groupBy([_db.goals.id])
      ..orderBy([
        OrderingTerm(expression: _db.goals.createdAt, mode: OrderingMode.desc),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => _mapJoinedToGoalItem(r, totalSavedExpr)).toList());
  }

  @override
  Future<GoalItem?> getGoalById(int id) async {
    final totalSavedExpr = _db.goalSavings.amount.sum();
    final query = _db.select(_db.goals).join([
      leftOuterJoin(
        _db.goalSavings,
        _db.goalSavings.goalId.equalsExp(_db.goals.id),
      ),
    ])
      ..where(_db.goals.id.equals(id))
      ..addColumns([totalSavedExpr])
      ..groupBy([_db.goals.id]);
    final row = await query.getSingleOrNull();
    return row == null ? null : _mapJoinedToGoalItem(row, totalSavedExpr);
  }

  @override
  Stream<GoalItem?> watchGoalById(int id) {
    final totalSavedExpr = _db.goalSavings.amount.sum();
    final query = _db.select(_db.goals).join([
      leftOuterJoin(
        _db.goalSavings,
        _db.goalSavings.goalId.equalsExp(_db.goals.id),
      ),
    ])
      ..where(_db.goals.id.equals(id))
      ..addColumns([totalSavedExpr])
      ..groupBy([_db.goals.id]);
    return query
        .watchSingleOrNull()
        .map((row) => row == null ? null : _mapJoinedToGoalItem(row, totalSavedExpr));
  }

  @override
  Future<int> addGoal({
    required String name,
    required int targetAmount,
    int monthlySaving = 0,
    String? icon,
  }) async {
    final sanitizedName = sanitizeName(name);
    if (sanitizedName.isEmpty) {
      throw ArgumentError('Goal name is required and cannot be empty.');
    }

    // Target amount must be positive and <= 100,000,000 EGP (in piastres)
    const maxTargetPiastres = 100000000 * 100;
    if (targetAmount <= 0 || targetAmount > maxTargetPiastres) {
      throw ArgumentError(
        'Target amount must be a positive number up to 100,000,000 EGP.',
      );
    }

    if (monthlySaving < 0 || monthlySaving > targetAmount) {
      throw ArgumentError(
        'Monthly saving cannot be negative or exceed the target amount.',
      );
    }

    final resolvedIcon = GoalIconHelper.validateOrResolve(
      icon,
      goalName: sanitizedName,
    );

    return await _db.into(_db.goals).insert(
      GoalsCompanion.insert(
        name: sanitizedName,
        targetAmount: targetAmount,
        monthlySaving: monthlySaving,
        createdAt: DateTime.now().toUtc(),
        icon: Value(resolvedIcon),
      ),
    );
  }

  @override
  Future<void> updateMonthlySaving({
    required int id,
    required int monthlySaving,
  }) async {
    if (monthlySaving < 0) {
      throw ArgumentError('Monthly saving cannot be negative.');
    }

    final goal = await getGoalById(id);
    if (goal == null) {
      throw ArgumentError('Goal with ID $id not found.');
    }

    if (monthlySaving > goal.targetAmount) {
      throw ArgumentError(
        'Monthly saving cannot exceed the target amount.',
      );
    }

    await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(
        monthlySaving: Value(monthlySaving),
      ),
    );
  }

  @override
  Future<void> updateGoal({
    required int id,
    required String name,
    required int targetAmount,
    int? monthlySaving,
    String? icon,
  }) async {
    final sanitizedName = sanitizeName(name);
    if (sanitizedName.isEmpty) {
      throw ArgumentError('Goal name is required and cannot be empty.');
    }

    const maxTargetPiastres = 100000000 * 100;
    if (targetAmount <= 0 || targetAmount > maxTargetPiastres) {
      throw ArgumentError(
        'Target amount must be a positive number up to 100,000,000 EGP.',
      );
    }

    final totalSaved = await getTotalSavedForGoal(id);
    if (targetAmount < totalSaved) {
      throw ArgumentError('المبلغ لا يمكن أن يقل عن المحوّش');
    }

    final goal = await getGoalById(id);
    if (goal == null) {
      throw ArgumentError('Goal with ID $id not found.');
    }

    final saving = monthlySaving ?? goal.monthlySaving;
    if (saving < 0 || saving > targetAmount) {
      throw ArgumentError(
        'Monthly saving cannot be negative or exceed the target amount.',
      );
    }

    final resolvedIcon = icon != null
        ? GoalIconHelper.validateOrResolve(icon, goalName: sanitizedName)
        : GoalIconHelper.resolveIconKeyFromName(sanitizedName);

    await (_db.update(_db.goals)..where((g) => g.id.equals(id))).write(
      GoalsCompanion(
        name: Value(sanitizedName),
        targetAmount: Value(targetAmount),
        monthlySaving: Value(saving),
        icon: Value(resolvedIcon),
      ),
    );
  }

  @override
  Future<void> deleteGoalSaving(int id) async {
    await (_db.delete(_db.goalSavings)..where((s) => s.id.equals(id))).go();
  }

  @override
  Future<void> deleteGoal(int id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.goalSavings)..where((s) => s.goalId.equals(id))).go();
      await (_db.delete(_db.goals)..where((g) => g.id.equals(id))).go();
    });
  }

  @override
  Future<int> addGoalSaving({
    required int goalId,
    required int amount,
    DateTime? savedAt,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Saving amount must be a positive number.');
    }

    final goal = await getGoalById(goalId);
    if (goal == null) {
      throw ArgumentError('Goal with ID $goalId not found.');
    }

    return await _db.into(_db.goalSavings).insert(
      GoalSavingsCompanion.insert(
        goalId: goalId,
        amount: amount,
        savedAt: (savedAt ?? DateTime.now()).toUtc(),
      ),
    );
  }

  @override
  Future<int> addGoalWithdrawal({
    required int goalId,
    required int amount,
    DateTime? withdrawnAt,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Withdrawal amount must be a positive number.');
    }

    final totalSaved = await getTotalSavedForGoal(goalId);
    if (amount > totalSaved) {
      throw ArgumentError('المبلغ أكبر من المحوّش في الهدف');
    }

    return await _db.into(_db.goalSavings).insert(
      GoalSavingsCompanion.insert(
        goalId: goalId,
        amount: -amount,
        savedAt: (withdrawnAt ?? DateTime.now()).toUtc(),
      ),
    );
  }

  @override
  Future<int> getTotalSavedForGoal(int goalId) async {
    final sumCol = _db.goalSavings.amount.sum();
    final query = _db.selectOnly(_db.goalSavings)
      ..addColumns([sumCol])
      ..where(_db.goalSavings.goalId.equals(goalId));
    final result = await query.map((row) => row.read(sumCol)).getSingleOrNull();
    return result ?? 0;
  }
}

