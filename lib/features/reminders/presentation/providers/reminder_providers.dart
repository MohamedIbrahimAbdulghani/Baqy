import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../data/repositories/reminder_repository_impl.dart';
import '../../domain/models/reminder_item.dart';
import '../../domain/repositories/reminder_repository.dart';
import '../../domain/utils/reminder_date_calculator.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReminderRepositoryImpl(db);
});

/// Reactive stream of all reminders sorted by next due date (soonest first, past one-time at the end).
final remindersStreamProvider = StreamProvider<List<ReminderItem>>((ref) {
  final repo = ref.watch(reminderRepositoryProvider);
  return repo
      .watchReminders()
      .map((items) => ReminderDateCalculator.sortReminders(items));
});
