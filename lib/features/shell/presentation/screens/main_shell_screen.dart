import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/domain/models/account_status.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/account_status_dialog.dart';
import '../../../expenses/domain/models/month_remaining.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../goals/presentation/widgets/goals_speed_dial_fab.dart';
import '../../../home/presentation/controllers/budget_monitor_controller.dart';
import '../../../home/presentation/widgets/home_speed_dial_fab.dart';
import '../../../reminders/presentation/providers/reminder_providers.dart';
import '../../../reminders/presentation/widgets/reminders_speed_dial_fab.dart';
import '../../../debts/presentation/providers/debt_providers.dart';
import '../../../debts/presentation/widgets/debts_fab.dart';
import '../providers/tab_provider.dart';
import '../widgets/custom_bottom_nav_bar.dart';
import '../../../../core/theme/theme_provider.dart';
import 'appointments_tab.dart';
import 'debts_tab.dart';
import 'goals_tab.dart';
import 'home_tab.dart';

/// FloatingActionButtonLocation that keeps the bottom of the FAB
/// at a fixed gap directly ABOVE the top edge of the bottom navigation bar.
class AboveBottomBarFabLocation extends FloatingActionButtonLocation {
  const AboveBottomBarFabLocation({this.gap = 14.0});

  final double gap;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = (scaffoldGeometry.scaffoldSize.width -
            scaffoldGeometry.floatingActionButtonSize.width) /
        2.0;
    final double fabY = scaffoldGeometry.contentBottom -
        gap -
        scaffoldGeometry.floatingActionButtonSize.height;
    return Offset(fabX, fabY);
  }
}

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  Timer? _securityCheckTimer;
  bool _isCheckingSecurity = false;
  bool _hasTriggeredSecurityDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.onSelectTab = (int tabIndex) {
      if (mounted) {
        ref.read(tabIndexProvider.notifier).selectTab(tabIndex);
      }
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = NotificationService.consumePendingTabSelection();
      if (pending != null && mounted) {
        ref.read(tabIndexProvider.notifier).selectTab(pending);
      }

      // Reschedule reminders and debts when app opens
      if (mounted) {
        ref.read(reminderRepositoryProvider).getReminders().then((reminders) {
          NotificationService.instance.rescheduleReminders(reminders);
        });
        ref.read(debtRepositoryProvider).getDebts().then((debts) {
          NotificationService.instance.rescheduleDebts(debts);
        });
      }

      // Check security status on launch and start periodic monitor
      _checkSecurityStatus();
      _startSecurityMonitor();
    });
  }

  void _startSecurityMonitor() {
    _securityCheckTimer?.cancel();
    _securityCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkSecurityStatus();
    });
  }

  Future<void> _checkSecurityStatus() async {
    if (!mounted || _isCheckingSecurity || _hasTriggeredSecurityDialog) return;
    _isCheckingSecurity = true;
    try {
      final repo = ref.read(authRepositoryProvider);
      final status = await repo.checkAccountStatus();
      if (!mounted) return;

      if (status == AccountStatus.disabled || status == AccountStatus.deleted) {
        _hasTriggeredSecurityDialog = true;
        _securityCheckTimer?.cancel();
        _securityCheckTimer = null;

        // Dismiss any existing bottom sheet or open popup first
        final navState = rootNavigatorKey.currentState;
        if (navState != null && navState.canPop()) {
          navState.popUntil((route) => route.isFirst);
        }

        // Pop up the dialog FIRST on the current screen without navigating away
        final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
        if (targetContext != null && targetContext.mounted) {
          await AccountStatusDialog.show(
            targetContext,
            status: status,
            buttonText: 'تسجيل الخروج',
            onDismissed: () async {
              // Sign out and redirect to sign-in ONLY when the user taps "تسجيل الخروج"
              await ref.read(authControllerProvider.notifier).signOut();
              ref.read(hasAutoOpenedBudgetForMonthProvider.notifier).reset();
              final exitNav = rootNavigatorKey.currentState;
              if (exitNav != null && exitNav.canPop()) {
                exitNav.popUntil((route) => route.isFirst);
              }
              final navContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
              if (navContext != null && navContext.mounted) {
                navContext.go('/sign-in');
              }
            },
          );
        }
      }
    } catch (_) {
    } finally {
      _isCheckingSecurity = false;
    }
  }

  @override
  void dispose() {
    _securityCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.onSelectTab = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _checkSecurityStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<MonthRemaining>>(currentMonthRemainingProvider, (prev, next) {
      next.whenData((remaining) {
        final double totalBudget = remaining.monthMoney / 100.0;
        final double remainingEgp = remaining.remaining / 100.0;
        BudgetMonitorController.evaluateAndNotify(
          totalBudget: totalBudget,
          remainingAmount: remainingEgp,
          currentMonthKey: remaining.yearMonth,
        );
      });
    });

    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final int selectedIndex = ref.watch(tabIndexProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: selectedIndex,
        children: [
          HomeTab(key: ValueKey('home_${isDark ? 'dark' : 'light'}')),
          GoalsTab(key: ValueKey('goals_${isDark ? 'dark' : 'light'}')),
          AppointmentsTab(key: ValueKey('appts_${isDark ? 'dark' : 'light'}')),
          DebtsTab(key: ValueKey('debts_${isDark ? 'dark' : 'light'}')),
        ],
      ),
      floatingActionButton: selectedIndex == 0
          ? const HomeSpeedDialFab()
          : (selectedIndex == 1
              ? const GoalsSpeedDialFab()
              : (selectedIndex == 2
                  ? const RemindersSpeedDialFab()
                  : (selectedIndex == 3 ? const DebtsFab() : null))),
      floatingActionButtonLocation: const AboveBottomBarFabLocation(gap: 14.0),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          ref.read(tabIndexProvider.notifier).selectTab(index);
        },
      ),
    );
  }
}
