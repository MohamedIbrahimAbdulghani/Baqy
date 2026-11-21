import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/notification_service.dart';

/// Controller responsible for monitoring monthly budget thresholds,
/// determining dynamic UI indicator colors, and managing anti-spam notification triggers.
abstract final class BudgetMonitorController {
  /// Harmonious red shade for budget warnings
  static const Color warningRed = Color(0xFFE53935);

  /// Default calm green shade
  static const Color defaultGreen = AppColors.mainGreen;

  /// Evaluates whether the remaining budget is less than or equal to 25% of total budget.
  /// Safely handles null, zero, and negative values to prevent division-by-zero or false alerts.
  static bool isThresholdReached({
    required double? totalBudget,
    required double? remainingAmount,
  }) {
    if (totalBudget == null || totalBudget <= 0) return false;
    if (remainingAmount == null) return false;

    // Trigger condition: remaining budget <= 25% of total budget
    return remainingAmount <= (totalBudget * 0.25);
  }

  /// Returns the reactive indicator color: Red if <= 25%, else default Green.
  static Color getIndicatorColor({
    required double? totalBudget,
    required double? remainingAmount,
  }) {
    if (isThresholdReached(
      totalBudget: totalBudget,
      remainingAmount: remainingAmount,
    )) {
      return warningRed;
    }
    return defaultGreen;
  }

  /// Evaluates the budget status and dispatches a local push notification once per budget cycle.
  /// Anti-spam logic:
  /// - Only alerts once per month crossing the 25% threshold.
  /// - Once sent, it will NEVER send again for that month, even if the app or account is closed and reopened.
  static Future<void> evaluateAndNotify({
    required double totalBudget,
    required double remainingAmount,
    required String currentMonthKey,
    String? userId,
  }) async {
    if (totalBudget <= 0) return;

    final now = DateTime.now();
    final actualCurrentMonthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    // Only alert for the active current month, never past historical months
    if (currentMonthKey != actualCurrentMonthKey) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String userPrefix = (userId != null && userId.isNotEmpty) ? '${userId}_' : '';
    final String prefKey = 'budget_alert_sent_$userPrefix$currentMonthKey';
    final bool hasAlerted = prefs.getBool(prefKey) ?? false;

    final bool reached = isThresholdReached(
      totalBudget: totalBudget,
      remainingAmount: remainingAmount,
    );

    if (reached) {
      if (!hasAlerted) {
        await prefs.setBool(prefKey, true);
        await NotificationService.instance.showBudgetWarningNotification();
      }
    } else {
      // If the remaining balance rises back above 25% (extra money/income received or budget increased):
      // re-arm the alert flag so that when remaining drops to 25% again, a new alert is sent!
      if (hasAlerted) {
        await prefs.setBool(prefKey, false);
      }
    }
  }

  /// Resets the alert flag for a given month key only when the user explicitly modifies the budget
  static Future<void> resetAlertFlag(String currentMonthKey, {String? userId}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String userPrefix = (userId != null && userId.isNotEmpty) ? '${userId}_' : '';
    await prefs.setBool('budget_alert_sent_$userPrefix$currentMonthKey', false);
  }
}
