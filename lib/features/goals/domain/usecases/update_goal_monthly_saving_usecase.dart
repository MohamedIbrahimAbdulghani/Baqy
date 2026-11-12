import '../repositories/goal_repository.dart';

class UpdateGoalMonthlySavingUseCase {
  final GoalRepository _repository;

  UpdateGoalMonthlySavingUseCase(this._repository);

  Future<void> call({
    required int id,
    required int monthlySaving,
  }) {
    return _repository.updateMonthlySaving(
      id: id,
      monthlySaving: monthlySaving,
    );
  }
}

