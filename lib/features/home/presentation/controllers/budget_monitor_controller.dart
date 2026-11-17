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
  /// - Only alerts once per monthKey crossing the 25% threshold.
  /// - If the user increases the budget so that remaining > 25%, the flag is reset so that
  ///   subsequent drops can trigger an alert again.
  static Future<void> evaluateAndNotify({
    required double totalBudget,
    required double remainingAmount,
    required String currentMonthKey,
  }) async {
    if (totalBudget <= 0) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String prefKey = 'budget_alert_sent_$currentMonthKey';
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
      // User increased total budget or deleted expenses bringing balance back above 25%
      if (hasAlerted) {
        await prefs.setBool(prefKey, false);
      }
    }
  }

  /// Resets the alert flag for a given month key (e.g. when budget is updated)
  static Future<void> resetAlertFlag(String currentMonthKey) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('budget_alert_sent_$currentMonthKey', false);
  }
}

