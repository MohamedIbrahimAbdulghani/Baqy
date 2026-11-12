import 'package:go_router/go_router.dart';
import '../utils/arabic_date_helper.dart';
import '../../features/expenses/domain/models/category_details_args.dart';
import '../../features/expenses/domain/models/category_item.dart';
import '../../features/expenses/presentation/screens/add_expense_screen.dart';
import '../../features/expenses/presentation/screens/category_details_screen.dart';
import '../../features/expenses/presentation/screens/category_form_screen.dart';
import '../../features/expenses/presentation/screens/month_details_screen.dart';
import '../../features/goals/domain/models/goal_item.dart';
import '../../features/goals/presentation/screens/add_goal_screen.dart';
import '../../features/goals/presentation/screens/goal_details_screen.dart';
import '../../features/shell/presentation/screens/main_shell_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
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
  ],
);
