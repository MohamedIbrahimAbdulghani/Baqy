import '../models/goal_item.dart';
import '../repositories/goal_repository.dart';

class GetGoalsUseCase {
  final GoalRepository _repository;

  GetGoalsUseCase(this._repository);

  Future<List<GoalItem>> call() => _repository.getGoals();
  Stream<List<GoalItem>> watch() => _repository.watchGoals();
}

