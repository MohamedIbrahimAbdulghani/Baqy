import 'package:baqy/core/services/notification_service.dart';
import 'package:baqy/features/home/presentation/controllers/budget_monitor_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService extends NotificationService {
  _FakeNotificationService() : super.test();
  int showCount = 0;

  @override
  Future<void> showBudgetWarningNotification() async {
    showCount++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeNotificationService fakeNotif;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeNotif = _FakeNotificationService();
    NotificationService.testInstance = fakeNotif;
  });

  group('BudgetMonitorController Threshold & Anti-Spam Unit Tests', () {
    test('isThresholdReached correctly triggers at exactly 25% or below', () {
      const double totalBudget = 10000;

      // 25% of 10,000 = 2,500
      expect(
        BudgetMonitorController.isThresholdReached(
          totalBudget: totalBudget,
          remainingAmount: 2501,
        ),
        isFalse,
      );

      expect(
        BudgetMonitorController.isThresholdReached(
          totalBudget: totalBudget,
          remainingAmount: 2500,
        ),
        isTrue,
      );

      expect(
        BudgetMonitorController.isThresholdReached(
          totalBudget: totalBudget,
          remainingAmount: 1000,
        ),
        isTrue,
      );

      expect(
        BudgetMonitorController.isThresholdReached(
          totalBudget: totalBudget,
          remainingAmount: 0,
        ),
        isTrue,
      );
    });

    test('isThresholdReached safely handles null and zero total budget', () {
      expect(
        BudgetMonitorController.isThresholdReached(
          totalBudget: 0,
          remainingAmount: 0,
        ),
        isFalse,
      );

      expect(
        BudgetMonitorController.isThresholdReached(
          totalBudget: null,
          remainingAmount: 500,
        ),
        isFalse,
      );

      expect(
        BudgetMonitorController.isThresholdReached(
          totalBudget: 1000,
          remainingAmount: null,
        ),
        isFalse,
      );
    });

    test('evaluateAndNotify alerts once and NEVER alerts again on reopen for same month', () async {
      final now = DateTime.now();
      final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      const userId = 'user_abc';

      // 1. First trigger when budget drops to 25% (2,500 out of 10,000)
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 2500,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );

      expect(fakeNotif.showCount, equals(1));

      final prefs = await SharedPreferences.getInstance();
      final prefKey = 'budget_alert_sent_${userId}_$currentMonthKey';
      expect(prefs.getBool(prefKey), isTrue);

      // 2. Simulate user closing app/account and opening it again (multiple evaluations on restart)
      // The flag MUST remain true and no additional alert should be dispatched!
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 2000,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );

      expect(fakeNotif.showCount, equals(1), reason: 'Notification must not trigger again on reopen');

      // 3. Even if balance drops further to 500 or 0, it NEVER alerts again
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 500,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );

      expect(fakeNotif.showCount, equals(1));
    });

    test('evaluateAndNotify ignores historical/past months', () async {
      const userId = 'user_abc';

      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 1000,
        currentMonthKey: '2020-01',
        userId: userId,
      );

      expect(fakeNotif.showCount, equals(0));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('budget_alert_sent_${userId}_2020-01'), isNull);
    });

    test('resetAlertFlag enables alert again if budget is explicitly modified', () async {
      final now = DateTime.now();
      final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      const userId = 'user_abc';
      final prefKey = 'budget_alert_sent_${userId}_$currentMonthKey';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, true);
      expect(prefs.getBool(prefKey), isTrue);

      // User modifies budget
      await BudgetMonitorController.resetAlertFlag(currentMonthKey, userId: userId);
      expect(prefs.getBool(prefKey), isFalse);

      // Now it can alert once more
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 2500,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );

      expect(fakeNotif.showCount, equals(1));
    });

    test('re-arms and alerts again when money increases above 25% and falls back down to 25%', () async {
      final now = DateTime.now();
      final currentMonthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
      const userId = 'user_abc';
      final prefKey = 'budget_alert_sent_${userId}_$currentMonthKey';

      // 1. Initial spend down to 25% (2,500 / 10,000)
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 2500,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );
      expect(fakeNotif.showCount, equals(1));
      expect(BudgetMonitorController.getIndicatorColor(totalBudget: 10000, remainingAmount: 2500), equals(BudgetMonitorController.warningRed));

      // 2. User reopens app - initial 0/0 followed by 2,500/10,000:
      // must NOT alert again!
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 0,
        remainingAmount: 0,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 2500,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );
      expect(fakeNotif.showCount, equals(1));

      // 3. User receives extra money in the same month! Balance becomes 5,000 (> 25% of 10,000)
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 5000,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );
      // Red indicator goes away
      expect(BudgetMonitorController.getIndicatorColor(totalBudget: 10000, remainingAmount: 5000), equals(BudgetMonitorController.defaultGreen));
      // Alert flag is re-armed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(prefKey), isFalse);
      expect(fakeNotif.showCount, equals(1));

      // 4. User spends from the 5,000 and reaches 25% again (e.g. 2,500)
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 2500,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );
      // Alert triggers AGAIN!
      expect(fakeNotif.showCount, equals(2));
      expect(prefs.getBool(prefKey), isTrue);
      expect(BudgetMonitorController.getIndicatorColor(totalBudget: 10000, remainingAmount: 2500), equals(BudgetMonitorController.warningRed));

      // 5. User reopens again while remaining is 2,500 -> must NOT alert again!
      await BudgetMonitorController.evaluateAndNotify(
        totalBudget: 10000,
        remainingAmount: 2500,
        currentMonthKey: currentMonthKey,
        userId: userId,
      );
      expect(fakeNotif.showCount, equals(2));
    });
  });
}
