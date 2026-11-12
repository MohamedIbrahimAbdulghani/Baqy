import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../data/repositories/goal_repository_impl.dart';
import '../../domain/models/goal_item.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../domain/usecases/add_goal_usecase.dart';
import '../../domain/usecases/get_goal_by_id_usecase.dart';
import '../../domain/usecases/get_goals_usecase.dart';
import '../../domain/usecases/update_goal_monthly_saving_usecase.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return GoalRepositoryImpl(db);
});

final getGoalsUseCaseProvider = Provider<GetGoalsUseCase>((ref) {
  final repo = ref.watch(goalRepositoryProvider);
  return GetGoalsUseCase(repo);
});

final getGoalByIdUseCaseProvider = Provider<GetGoalByIdUseCase>((ref) {
  final repo = ref.watch(goalRepositoryProvider);
  return GetGoalByIdUseCase(repo);
});

final addGoalUseCaseProvider = Provider<AddGoalUseCase>((ref) {
  final repo = ref.watch(goalRepositoryProvider);
  return AddGoalUseCase(repo);
});

final updateGoalMonthlySavingUseCaseProvider =
    Provider<UpdateGoalMonthlySavingUseCase>((ref) {
  final repo = ref.watch(goalRepositoryProvider);
  return UpdateGoalMonthlySavingUseCase(repo);
});

/// Reactive stream of all goals
final goalsStreamProvider = StreamProvider<List<GoalItem>>((ref) {
  final useCase = ref.watch(getGoalsUseCaseProvider);
  return useCase.watch();
});

/// Reactive stream of a single goal
final goalByIdProvider =
    StreamProvider.family<GoalItem?, int>((ref, id) {
  final useCase = ref.watch(getGoalByIdUseCaseProvider);
  return useCase.watch(id);
});

void showGoalsFeedbackSnackBar({
  required BuildContext context,
  required String message,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 84.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
