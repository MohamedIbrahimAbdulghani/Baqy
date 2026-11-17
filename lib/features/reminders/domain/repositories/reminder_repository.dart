import '../models/reminder_item.dart';

/// Abstract repository defining operations for reminders.
abstract class ReminderRepository {
  /// Reactive stream of all reminders from local storage
  Stream<List<ReminderItem>> watchReminders();

  /// Fetches all reminders once
  Future<List<ReminderItem>> getReminders();

  /// Fetches a single reminder by ID
  Future<ReminderItem?> getReminderById(int id);

  /// Adds a new reminder
  Future<int> addReminder({
    required String name,
    required int amount, // in piastres
    required DateTime dueDate,
    required String repeat, // "once" or "monthly"
    required int leadDays, // 1, 2, or 3
  });

  /// Updates an existing reminder
  Future<void> updateReminder({
    required int id,
    required String name,
    required int amount, // in piastres
    required DateTime dueDate,
    required String repeat, // "once" or "monthly"
    required int leadDays, // 1, 2, or 3
  });

  /// Deletes a reminder by ID
  Future<void> deleteReminder(int id);
}
