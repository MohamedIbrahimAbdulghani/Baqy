import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
import '../../features/auth/presentation/widgets/account_status_dialog.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Global security flag: when true or dialog is showing, router guards will NOT force-redirect to /sign-in,
/// ensuring the user can clearly see and read the popup dialog and its details.
bool isAccountSuspended = false;

/// Set to true during an active account security check to prevent race-condition redirects.
bool isCheckingAccountSecurity = false;

/// Listenable that notifies GoRouter whenever auth state changes
class AppAuthNotifier extends ChangeNotifier {
  StreamSubscription? _sub;

  AppAuthNotifier() {
    _init();
  }

  void _init() {
    try {
      if (Firebase.apps.isNotEmpty) {
        _sub = FirebaseAuth.instance.authStateChanges().listen((_) {
          notifyListeners();
        });
      }
    } catch (_) {}
  }

  void notifyAuthChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final AppAuthNotifier appAuthNotifier = AppAuthNotifier();

/// Optional hook to override auth check in widget / unit tests
bool Function()? authCheckOverride;

/// Strict global verification: checks if an authenticated user session is active
bool isUserAuthenticated() {
  if (authCheckOverride != null) {
    return authCheckOverride!();
  }
  // If Firebase is not yet initialized or in pure test env, allow routing
  if (Firebase.apps.isEmpty) {
    return true;
  }
  final user = FirebaseAuth.instance.currentUser;
  return user != null;
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: appAuthNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    // If the account is suspended/disabled or the status dialog is active or security is being verified,
    // DO NOT redirect away automatically! Let the dialog stay visible so the user can read it.
    if (isAccountSuspended || AccountStatusDialog.isShowing || isCheckingAccountSecurity) {
      return null;
    }

    final authenticated = isUserAuthenticated();
    final location = state.matchedLocation;

    // The splash screen handles initial app boot, branding, and status verification
    if (location == '/') {
      return null;
    }

    final isSignIn = location == '/sign-in';

    // STRICT AUTH GUARD: An unauthenticated user CANNOT access any internal screen!
    if (!authenticated) {
      return isSignIn ? null : '/sign-in';
    }

    // Authenticated users should not revisit sign-in
    if (isSignIn) {
      return '/main';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/sign-in',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const SignInScreen(),
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 350),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
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
