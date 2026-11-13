import '../models/goal_item.dart';

abstract class GoalRepository {
  /// Fetches all goals ordered by creation date descending
  Future<List<GoalItem>> getGoals();

  /// Reactive stream of all goals
  Stream<List<GoalItem>> watchGoals();

  /// Fetches a single goal by its ID
  Future<GoalItem?> getGoalById(int id);

  /// Reactive stream of a single goal by its ID
  Stream<GoalItem?> watchGoalById(int id);

  /// Creates a new goal. Validates name and target amount.
  Future<int> addGoal({
    required String name,
    required int targetAmount, // in piastres
    int monthlySaving = 0, // in piastres
    String? icon,
  });

  /// Updates monthly saving for a goal. Validates amount.
  Future<void> updateMonthlySaving({
    required int id,
    required int monthlySaving, // in piastres
  });

  /// Updates goal name, target amount, and optionally monthly saving and icon.
  Future<void> updateGoal({
    required int id,
    required String name,
    required int targetAmount, // in piastres
    int? monthlySaving, // in piastres
    String? icon,
  });

  /// Deletes a goal and all its savings within a database transaction.
  Future<void> deleteGoal(int id);

  /// Saves money into a goal.
  Future<int> addGoalSaving({
    required int goalId,
    required int amount, // in piastres
    DateTime? savedAt,
  });

  /// Withdraws money from a goal (stored as negative amount).
  Future<int> addGoalWithdrawal({
    required int goalId,
    required int amount, // in piastres (positive number)
    DateTime? withdrawnAt,
  });

  /// Deletes a specific goal saving (used for Undo / تراجع).
  Future<void> deleteGoalSaving(int id);

  /// Fetches total saved amount for a goal in piastres.
  Future<int> getTotalSavedForGoal(int goalId);
}

