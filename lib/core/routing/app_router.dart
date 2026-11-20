import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../utils/arabic_date_helper.dart';
import '../../features/debts/domain/models/debt_item.dart';
import '../../features/debts/presentation/screens/add_debt_screen.dart';
import '../../features/debts/presentation/screens/debt_details_screen.dart';
import '../../features/expenses/domain/models/category_details_args.dart';
import '../../features/expenses/domain/models/category_item.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/expenses/presentation/screens/category_details_screen.dart';
import '../../features/expenses/presentation/screens/category_form_screen.dart';
import '../../features/expenses/presentation/screens/month_details_screen.dart';
import '../../features/goals/domain/models/goal_item.dart';
import '../../features/goals/presentation/screens/add_goal_screen.dart';
import '../../features/goals/presentation/screens/goal_details_screen.dart';
import '../../features/reminders/domain/models/reminder_item.dart';
import '../../features/reminders/presentation/screens/add_reminder_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/shell/presentation/screens/main_shell_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/sign_in_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (context, state) => const MainShellScreen(),
    ),
    GoRoute(
      path: '/month-details',
      builder: (context, state) {
        final extra = state.extra;
        String? yearMonth;
        if (extra is String) {
          if (extra.contains('-')) {
            yearMonth = extra;
          } else {
            yearMonth = ArabicDateHelper.tryParseDisplayToYearMonth(extra);
          }
        }
        return MonthDetailsScreen(initialYearMonth: yearMonth);
      },
    ),
    GoRoute(
      path: '/category-details',
      builder: (context, state) {
        final args = state.extra as CategoryDetailsArgs;
        return CategoryDetailsScreen(args: args);
      },
    ),
    GoRoute(
      path: '/add-expense',
      builder: (context, state) => const AddExpenseScreen(),
    ),
    GoRoute(
      path: '/category-form',
      builder: (context, state) {
        final category = state.extra as CategoryItem?;
        return CategoryFormScreen(categoryToEdit: category);
      },
    ),
    GoRoute(
      path: '/add-goal',
      builder: (context, state) {
        final goalToEdit = state.extra as GoalItem?;
        return AddGoalScreen(goalToEdit: goalToEdit);
      },
    ),
    GoRoute(
      path: '/goal-details',
      builder: (context, state) {
        final goalId = state.extra as int;
        return GoalDetailsScreen(goalId: goalId);
      },
    ),
    GoRoute(
      path: '/add-reminder',
      builder: (context, state) {
        final reminderToEdit = state.extra as ReminderItem?;
        return AddReminderScreen(reminderToEdit: reminderToEdit);
      },
    ),
    GoRoute(
      path: '/add-debt',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is DebtItem) {
          return AddDebtScreen(debtToEdit: extra);
        } else if (extra is String) {
          return AddDebtScreen(initialDirection: extra);
        }
        return const AddDebtScreen();
      },
    ),
    GoRoute(
      path: '/debt-details',
      builder: (context, state) {
        final debtId = state.extra as int;
        return DebtDetailsScreen(debtId: debtId);
      },
    ),
  ],
);
