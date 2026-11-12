import '../models/goal_item.dart';
import '../repositories/goal_repository.dart';

class GetGoalByIdUseCase {
  final GoalRepository _repository;

  GetGoalByIdUseCase(this._repository);

  Future<GoalItem?> call(int id) => _repository.getGoalById(id);
  Stream<GoalItem?> watch(int id) => _repository.watchGoalById(id);
}

