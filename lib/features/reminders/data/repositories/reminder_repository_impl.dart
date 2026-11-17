import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/models/reminder_item.dart';
import '../../domain/repositories/reminder_repository.dart';

/// Concrete implementation of [ReminderRepository] backed by Drift SQLite [AppDatabase].
class ReminderRepositoryImpl implements ReminderRepository {
  final AppDatabase _db;
  final NotificationService _notificationService;

  ReminderRepositoryImpl(
    this._db, {
    NotificationService? notificationService,
  }) : _notificationService =
            notificationService ?? NotificationService.instance;

  ReminderItem _toEntity(ReminderData data) {
    return ReminderItem(
      id: data.id,
      name: data.name,
      amount: data.amount,
      dueDate: data.dueDate,
      repeat: data.repeat,
      leadDays: data.leadDays,
    );
  }

  @override
  Stream<List<ReminderItem>> watchReminders() {
    return _db.select(_db.reminders).watch().map(
          (rows) => rows.map(_toEntity).toList(),
        );
  }

  @override
  Future<List<ReminderItem>> getReminders() async {
    final rows = await _db.select(_db.reminders).get();
    return rows.map(_toEntity).toList();
  }

  @override
  Future<ReminderItem?> getReminderById(int id) async {
    final query = _db.select(_db.reminders)
      ..where((tbl) => tbl.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _toEntity(row) : null;
  }

  @override
  Future<int> addReminder({
    required String name,
    required int amount,
    required DateTime dueDate,
    required String repeat,
    required int leadDays,
  }) async {
    final sanitizedName = _validateAndSanitizeName(name);
    _validateAmount(amount);
    _validateRepeat(repeat);
    _validateLeadDays(leadDays);

    final companion = RemindersCompanion.insert(
      name: sanitizedName,
      amount: amount,
      dueDate: dueDate,
      repeat: repeat,
      leadDays: leadDays,
    );

    final id = await _db.into(_db.reminders).insert(companion);

    // Reschedule notifications after save
    final allReminders = await getReminders();
    await _notificationService.rescheduleReminders(allReminders);

    return id;
  }

  @override
  Future<void> updateReminder({
    required int id,
    required String name,
    required int amount,
    required DateTime dueDate,
    required String repeat,
    required int leadDays,
  }) async {
    final sanitizedName = _validateAndSanitizeName(name);
    _validateAmount(amount);
    _validateRepeat(repeat);
    _validateLeadDays(leadDays);

    final companion = RemindersCompanion(
      id: Value(id),
      name: Value(sanitizedName),
      amount: Value(amount),
      dueDate: Value(dueDate),
      repeat: Value(repeat),
      leadDays: Value(leadDays),
    );

    await (_db.update(_db.reminders)..where((tbl) => tbl.id.equals(id)))
        .write(companion);

    // Reschedule notifications after edit
    final allReminders = await getReminders();
    await _notificationService.rescheduleReminders(allReminders);
  }

  @override
  Future<void> deleteReminder(int id) async {
    await (_db.delete(_db.reminders)..where((tbl) => tbl.id.equals(id))).go();

    // Cancel deleted reminder notification and reschedule remaining
    await _notificationService.cancelReminderNotification(id);
    final allReminders = await getReminders();
    await _notificationService.rescheduleReminders(allReminders);
  }

  String _validateAndSanitizeName(String raw) {
    // Strip control characters
    final stripped = raw.replaceAll(RegExp(r'[\x00-\x1F\x7F-\x9F]'), '').trim();
    if (stripped.isEmpty) {
      throw ArgumentError('الاسم مطلوب ولا يمكن تركه فارغاً');
    }
    if (stripped.length > 40) {
      throw ArgumentError('اسم الموعد يجب ألا يتجاوز ٤٠ حرفاً');
    }
    return stripped;
  }

  void _validateAmount(int amountPiastres) {
    if (amountPiastres <= 0) {
      throw ArgumentError('المبلغ يجب أن يكون رقماً موجباً أكبر من صفر');
    }
    const maxPiastres = 100000000 * 100; // 100,000,000 EGP in piastres
    if (amountPiastres > maxPiastres) {
      throw ArgumentError('الحد الأقصى للمبلغ ١٠٠,٠٠٠,٠٠٠ جنيه');
    }
  }

  void _validateRepeat(String repeat) {
    if (repeat != 'once' && repeat != 'monthly') {
      throw ArgumentError('التكرار يجب أن يكون إما "مرة واحدة" أو "شهري"');
    }
  }

  void _validateLeadDays(int leadDays) {
    if (leadDays != 1 && leadDays != 2 && leadDays != 3) {
      throw ArgumentError('أيام التنبيه يجب أن تكون ١ أو ٢ أو ٣ أيام');
    }
  }
}
