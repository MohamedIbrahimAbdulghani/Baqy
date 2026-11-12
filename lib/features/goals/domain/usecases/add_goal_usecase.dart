import '../repositories/goal_repository.dart';

class AddGoalUseCase {
  final GoalRepository _repository;

  AddGoalUseCase(this._repository);

  Future<int> call({
    required String name,
    required int targetAmount,
    int monthlySaving = 0,
  }) {
    return _repository.addGoal(
      name: name,
      targetAmount: targetAmount,
      monthlySaving: monthlySaving,
    );
  }
}

