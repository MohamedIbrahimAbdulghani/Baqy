import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:baqy/core/database/app_database.dart';
import 'package:baqy/core/services/notification_service.dart';
import 'package:baqy/features/expenses/presentation/providers/expense_providers.dart';
import 'package:baqy/features/reminders/data/repositories/reminder_repository_impl.dart';
import 'package:baqy/features/reminders/domain/models/reminder_item.dart';
import 'package:baqy/features/reminders/domain/utils/reminder_date_calculator.dart';
import 'package:baqy/features/reminders/presentation/providers/reminder_providers.dart';
import 'package:baqy/core/utils/reminder_icon_helper.dart';
import 'package:baqy/features/reminders/presentation/widgets/reminder_card.dart';
import 'package:baqy/features/reminders/presentation/widgets/reminder_success_dialog.dart';
import 'package:baqy/features/shell/presentation/screens/appointments_tab.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super.test();

  int rescheduleCalls = 0;
  List<ReminderItem> lastRescheduledList = [];
  final List<int> cancelledReminderIds = [];

  @override
  Future<void> rescheduleReminders(List<ReminderItem> reminders) async {
    rescheduleCalls++;
    lastRescheduledList = List.from(reminders);
  }

  @override
  Future<void> cancelReminderNotification(int reminderId) async {
    cancelledReminderIds.add(reminderId);
  }
}

void main() {
  setUpAll(() {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
  });

  group('PERMANENT TESTS - ReminderDateCalculator', () {
    test('1. Next due date of a monthly reminder across month ends', () {
      // 31 January gives 28 February (non-leap year: 2026)
      final jan31_2026 = DateTime(2026, 1, 31);
      final feb1_2026 = DateTime(2026, 2, 1);
      final nextFeb2026 = ReminderDateCalculator.calculateNextDueDate(
        dueDate: jan31_2026,
        repeat: 'monthly',
        now: feb1_2026,
      );
      expect(nextFeb2026.year, equals(2026));
      expect(nextFeb2026.month, equals(2));
      expect(nextFeb2026.day, equals(28));

      // 31 January in a leap year gives 29 February (2024)
      final jan31_2024 = DateTime(2024, 1, 31);
      final feb1_2024 = DateTime(2024, 2, 1);
      final nextFeb2024 = ReminderDateCalculator.calculateNextDueDate(
        dueDate: jan31_2024,
        repeat: 'monthly',
        now: feb1_2024,
      );
      expect(nextFeb2024.year, equals(2024));
      expect(nextFeb2024.month, equals(2));
      expect(nextFeb2024.day, equals(29));

      // 31 in 30-day month (April 2026) gives 30 April
      final apr1_2026 = DateTime(2026, 4, 1);
      final nextApr31 = ReminderDateCalculator.calculateNextDueDate(
        dueDate: jan31_2026,
        repeat: 'monthly',
        now: apr1_2026,
      );
      expect(nextApr31.year, equals(2026));
      expect(nextApr31.month, equals(4));
      expect(nextApr31.day, equals(30));

      // 30 in 30-day month (April 2026) gives 30 April
      final jan30_2026 = DateTime(2026, 1, 30);
      final nextApr30 = ReminderDateCalculator.calculateNextDueDate(
        dueDate: jan30_2026,
        repeat: 'monthly',
        now: apr1_2026,
      );
      expect(nextApr30.year, equals(2026));
      expect(nextApr30.month, equals(4));
      expect(nextApr30.day, equals(30));

      // Month after 28 February (March 2026) restores day 31
      final mar1_2026 = DateTime(2026, 3, 1);
      final nextMar31 = ReminderDateCalculator.calculateNextDueDate(
        dueDate: jan31_2026,
        repeat: 'monthly',
        now: mar1_2026,
      );
      expect(nextMar31.year, equals(2026));
      expect(nextMar31.month, equals(3));
      expect(nextMar31.day, equals(31));
    });

    test('2. Notification moment equals 09:00 Africa/Cairo on (due minus lead days) for lead 1, 2 and 3', () {
      final dueDate = DateTime(2026, 11, 10);
      final beforeTime = DateTime(2026, 11, 1, 8, 0, 0);

      // Lead 1: 10 - 1 = 9 November at 09:00:00
      final sched1 = ReminderDateCalculator.calculateNotificationSchedule(
        dueDate: dueDate,
        repeat: 'once',
        leadDays: 1,
        now: beforeTime,
      );
      expect(sched1, isNotNull);
      expect(sched1!.notificationMoment, equals(DateTime(2026, 11, 9, 9, 0, 0)));
      expect(sched1.occurrenceDueDate, equals(DateTime(2026, 11, 10)));

      // Lead 2: 10 - 2 = 8 November at 09:00:00
      final sched2 = ReminderDateCalculator.calculateNotificationSchedule(
        dueDate: dueDate,
        repeat: 'once',
        leadDays: 2,
        now: beforeTime,
      );
      expect(sched2, isNotNull);
      expect(sched2!.notificationMoment, equals(DateTime(2026, 11, 8, 9, 0, 0)));
      expect(sched2.occurrenceDueDate, equals(DateTime(2026, 11, 10)));

      // Lead 3: 10 - 3 = 7 November at 09:00:00
      final sched3 = ReminderDateCalculator.calculateNotificationSchedule(
        dueDate: dueDate,
        repeat: 'once',
        leadDays: 3,
        now: beforeTime,
      );
      expect(sched3, isNotNull);
      expect(sched3!.notificationMoment, equals(DateTime(2026, 11, 7, 9, 0, 0)));
      expect(sched3.occurrenceDueDate, equals(DateTime(2026, 11, 10)));
    });

    test('3. A moment already in the past is skipped (or moves to next month for monthly)', () {
      final dueDate = DateTime(2026, 11, 10);
      // Now is 8 November 2026 at 09:05:00 (5 minutes after the 09:00 notification moment)
      final nowPastMoment = DateTime(2026, 11, 8, 9, 5, 0);

      // Once: moment passed -> skipped (null)
      final schedOnce = ReminderDateCalculator.calculateNotificationSchedule(
        dueDate: dueDate,
        repeat: 'once',
        leadDays: 2,
        now: nowPastMoment,
      );
      expect(schedOnce, isNull);

      // Monthly: moment passed -> moves to next month occurrence (10 December, notif on 8 December 09:00)
      final schedMonthly = ReminderDateCalculator.calculateNotificationSchedule(
        dueDate: dueDate,
        repeat: 'monthly',
        leadDays: 2,
        now: nowPastMoment,
      );
      expect(schedMonthly, isNotNull);
      expect(schedMonthly!.occurrenceDueDate, equals(DateTime(2026, 12, 10)));
      expect(schedMonthly.notificationMoment, equals(DateTime(2026, 12, 8, 9, 0, 0)));
    });

    test('4. A monthly reminder after its date moves to the next month', () {
      final dueDate = DateTime(2026, 11, 10);

      // On 10 November (on its date): does not move yet
      final onDate = DateTime(2026, 11, 10);
      final nextOn = ReminderDateCalculator.calculateNextDueDate(
        dueDate: dueDate,
        repeat: 'monthly',
        now: onDate,
      );
      expect(nextOn, equals(DateTime(2026, 11, 10)));

      // On 11 November (after its date): moves to next month (10 December)
      final afterDate = DateTime(2026, 11, 11);
      final nextAfter = ReminderDateCalculator.calculateNextDueDate(
        dueDate: dueDate,
        repeat: 'monthly',
        now: afterDate,
      );
      expect(nextAfter, equals(DateTime(2026, 12, 10)));
    });

    test('5. List sorting by next due date with past one-time reminders last', () {
      final now = DateTime(2026, 11, 17);

      final r1 = ReminderItem(
        id: 1,
        name: 'فاتورة الغاز',
        amount: 15000,
        dueDate: DateTime(2026, 11, 25),
        repeat: 'once',
        leadDays: 2,
      );

      final r2 = ReminderItem(
        id: 2,
        name: 'اشتراك شهري',
        amount: 60000,
        dueDate: DateTime(2026, 11, 10), // Passed -> moves to 2026-12-10
        repeat: 'monthly',
        leadDays: 2,
      );

      final r3 = ReminderItem(
        id: 3,
        name: 'قسط قريب',
        amount: 200000,
        dueDate: DateTime(2026, 11, 19),
        repeat: 'once',
        leadDays: 1,
      );

      final r4Past = ReminderItem(
        id: 4,
        name: 'موعد منتهي لمرة واحدة',
        amount: 50000,
        dueDate: DateTime(2026, 11, 14), // Once and in past
        repeat: 'once',
        leadDays: 1,
      );

      final sorted = ReminderDateCalculator.sortReminders([r1, r2, r3, r4Past], now: now);

      // Expected order:
      // 1. r3 (due Nov 19)
      // 2. r1 (due Nov 25)
      // 3. r2 (due Dec 10)
      // 4. r4Past (faded at end)
      expect(sorted.map((e) => e.id).toList(), equals([3, 1, 2, 4]));
    });

    test('8. The notification text for lead 1, 2 and 3 matches the exact wording', () {
      // Lead 1: "يوم"
      final n1 = ReminderDateCalculator.formatNotificationContent(
        name: 'فاتورة النت',
        amountPiastres: 35000,
        leadDays: 1,
        occurrenceDueDate: DateTime(2026, 11, 10), // Tuesday
      );
      expect(n1.title, equals('Baqy'));
      expect(n1.body, equals('فاتورة النت هيتدفع كمان يوم\n٣٥٠ جنيه · الثلاثاء ١٠ نوفمبر'));

      // Lead 2: "يومين" (matching Screenshot 3)
      final n2 = ReminderDateCalculator.formatNotificationContent(
        name: 'اشتراك جيم',
        amountPiastres: 60000,
        leadDays: 2,
        occurrenceDueDate: DateTime(2026, 11, 11), // Wednesday
      );
      expect(n2.title, equals('Baqy'));
      expect(n2.body, equals('اشتراك جيم هيتدفع كمان يومين\n٦٠٠ جنيه · الأربعاء ١١ نوفمبر'));

      // Lead 3: "٣ أيام"
      final n3 = ReminderDateCalculator.formatNotificationContent(
        name: 'جمعية',
        amountPiastres: 150000, // 1500 EGP -> ١,٥٠٠ جنيه
        leadDays: 3,
        occurrenceDueDate: DateTime(2026, 11, 20), // Friday
      );
      expect(n3.title, equals('Baqy'));
      expect(n3.body, equals('جمعية هيتدفع كمان ٣ أيام\n١,٥٠٠ جنيه · الجمعة ٢٠ نوفمبر'));
    });

    test('ReminderIconHelper automatically matches appropriate icon to reminder name', () {
      expect(ReminderIconHelper.resolveIcon('اشتراك كلود'), equals(Icons.cloud_outlined));
      expect(ReminderIconHelper.resolveIcon('اشتراك جيم'), equals(Icons.fitness_center_outlined));
      expect(ReminderIconHelper.resolveIcon('فيزا مشتريات'), equals(Icons.credit_card_outlined));
      expect(ReminderIconHelper.resolveIcon('جمعية'), equals(Icons.savings_outlined));
      expect(ReminderIconHelper.resolveIcon('فاتورة نت'), equals(Icons.wifi_outlined));
      expect(ReminderIconHelper.resolveIcon('ايجار الشقة'), equals(Icons.home_outlined));
      expect(ReminderIconHelper.resolveIcon('قسط عربية'), equals(Icons.directions_car_outlined));
      expect(ReminderIconHelper.resolveIcon('حاجة غير معروفة'), equals(Icons.calendar_today_outlined));
    });
  });

  group('PERMANENT TESTS - Repository & Validation', () {
    late AppDatabase db;
    late _FakeNotificationService fakeNotif;
    late ReminderRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      fakeNotif = _FakeNotificationService();
      repo = ReminderRepositoryImpl(db, notificationService: fakeNotif);
    });

    tearDown(() async {
      await db.close();
    });

    test('6. Validation of name and amount', () async {
      final validDate = DateTime(2026, 12, 1);

      // Empty name throws
      expect(
        () => repo.addReminder(
          name: '   ',
          amount: 50000,
          dueDate: validDate,
          repeat: 'once',
          leadDays: 2,
        ),
        throwsArgumentError,
      );

      // Name > 40 characters throws
      final longName = 'أ' * 45;
      expect(
        () => repo.addReminder(
          name: longName,
          amount: 50000,
          dueDate: validDate,
          repeat: 'once',
          leadDays: 2,
        ),
        throwsArgumentError,
      );

      // Amount <= 0 throws
      expect(
        () => repo.addReminder(
          name: 'تست',
          amount: 0,
          dueDate: validDate,
          repeat: 'once',
          leadDays: 2,
        ),
        throwsArgumentError,
      );

      // Amount > 100,000,000 EGP throws
      const overMax = (100000000 * 100) + 1;
      expect(
        () => repo.addReminder(
          name: 'تست',
          amount: overMax,
          dueDate: validDate,
          repeat: 'once',
          leadDays: 2,
        ),
        throwsArgumentError,
      );

      // Control characters stripped safely
      final id = await repo.addReminder(
        name: '\x00اشتراك كلود\x1F',
        amount: 90000,
        dueDate: validDate,
        repeat: 'monthly',
        leadDays: 2,
      );
      final saved = await repo.getReminderById(id);
      expect(saved?.name, equals('اشتراك كلود'));
    });

    test('7. Edit and delete cancel and reschedule', () async {
      final validDate = DateTime(2026, 12, 1);

      // 1. Add
      final id = await repo.addReminder(
        name: 'اشتراك جيم',
        amount: 60000,
        dueDate: validDate,
        repeat: 'monthly',
        leadDays: 2,
      );
      expect(fakeNotif.rescheduleCalls, equals(1));
      expect(fakeNotif.lastRescheduledList.length, equals(1));
      expect(fakeNotif.lastRescheduledList.first.id, equals(id));

      // 2. Edit
      await repo.updateReminder(
        id: id,
        name: 'اشتراك جيم معدل',
        amount: 70000,
        dueDate: validDate,
        repeat: 'monthly',
        leadDays: 3,
      );
      expect(fakeNotif.rescheduleCalls, equals(2));
      final updated = await repo.getReminderById(id);
      expect(updated?.name, equals('اشتراك جيم معدل'));
      expect(updated?.amountEgp, equals(700));
      expect(updated?.leadDays, equals(3));

      // 3. Delete
      await repo.deleteReminder(id);
      expect(fakeNotif.cancelledReminderIds, contains(id));
      expect(fakeNotif.rescheduleCalls, equals(3));
      expect(fakeNotif.lastRescheduledList.isEmpty, isTrue);

      final deleted = await repo.getReminderById(id);
      expect(deleted, isNull);
    });

    test('9. The list updates instantly after save, edit and delete', () async {
      final stream = repo.watchReminders();
      final history = <List<ReminderItem>>[];
      final sub = stream.listen((list) => history.add(list));

      await pumpEventQueue();

      final id = await repo.addReminder(
        name: 'فيزا مشتريات',
        amount: 150000,
        dueDate: DateTime(2026, 11, 15),
        repeat: 'monthly',
        leadDays: 2,
      );
      await pumpEventQueue();

      await repo.updateReminder(
        id: id,
        name: 'فيزا مشتريات البنك',
        amount: 160000,
        dueDate: DateTime(2026, 11, 15),
        repeat: 'monthly',
        leadDays: 2,
      );
      await pumpEventQueue();

      await repo.deleteReminder(id);
      await pumpEventQueue();

      await sub.cancel();

      // Check stream reactions
      expect(history.length, greaterThanOrEqualTo(3));
      // First had 1 item
      expect(history.any((l) => l.isNotEmpty && l.first.name == 'فيزا مشتريات'), isTrue);
      // Second had edited name
      expect(history.any((l) => l.isNotEmpty && l.first.name == 'فيزا مشتريات البنك'), isTrue);
      // Final is empty
      expect(history.last.isEmpty, isTrue);
    });
  });

  group('PERMANENT TESTS - AppointmentsTab Widget', () {
    late AppDatabase db;
    late _FakeNotificationService fakeNotif;
    late ReminderRepositoryImpl repo;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      fakeNotif = _FakeNotificationService();
      repo = ReminderRepositoryImpl(db, notificationService: fakeNotif);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('Empty state shows title "المواعيد" and no cards', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          reminderRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppointmentsTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المواعيد'), findsOneWidget);
      expect(find.byType(ReminderCard), findsNothing);
    });

    testWidgets('Populated list displays reminder card and faded past reminder', (tester) async {
      final now = DateTime.now();

      await repo.addReminder(
        name: 'اشتراك كلود',
        amount: 90000,
        dueDate: now.add(const Duration(days: 5)),
        repeat: 'monthly',
        leadDays: 2,
      );

      await repo.addReminder(
        name: 'موعد منتهي قديم',
        amount: 20000,
        dueDate: now.subtract(const Duration(days: 3)),
        repeat: 'once',
        leadDays: 1,
      );

      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          reminderRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppointmentsTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المواعيد'), findsOneWidget);
      expect(find.text('اشتراك كلود'), findsOneWidget);
      expect(find.text('٩٠٠ جنيه'), findsOneWidget);
      expect(find.text('موعد منتهي قديم'), findsOneWidget);
      expect(find.text('٢٠٠ جنيه'), findsOneWidget);

      // Verify that past one-time reminder card is rendered with Opacity (faded)
      expect(find.byType(Opacity), findsOneWidget);
    });

    testWidgets('ReminderSuccessDialog displays smooth popup with details and action button', (tester) async {
      final reminder = ReminderItem(
        id: 1,
        name: 'اشتراك جيم',
        amount: 60000,
        dueDate: DateTime(2026, 11, 20),
        repeat: 'monthly',
        leadDays: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      ReminderSuccessDialog.show(
                        context: context,
                        reminder: reminder,
                        isEdit: false,
                      );
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('تم حفظ الموعد بنجاح! 🎉'), findsOneWidget);
      expect(find.text('٦٠٠ جنيه'), findsOneWidget);
      expect(find.text('اشتراك جيم'), findsOneWidget);
      expect(find.text('تمام'), findsOneWidget);

      await tester.tap(find.text('تمام'));
      await tester.pumpAndSettle();

      expect(find.text('تم حفظ الموعد بنجاح! 🎉'), findsNothing);
    });
  });
}
