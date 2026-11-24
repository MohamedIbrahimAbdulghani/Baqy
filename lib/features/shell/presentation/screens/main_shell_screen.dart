import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/notification_service.dart';
import '../../../auth/domain/models/account_status.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/account_status_dialog.dart';
import '../../../backup/presentation/providers/backup_providers.dart';
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
  String? _cachedUserEmail;

  @override
  void initState() {
    super.initState();
    _cachedUserEmail = ref.read(authRepositoryProvider).currentUser?.email;
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

      // Request notification permissions so budget threshold warnings and reminders work on Android 13+
      NotificationService.instance.requestPermissions();

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

      // Check if this is a new phone with empty local DB and an existing cloud backup
      _checkCloudBackupOnLaunch();
    });
  }

  Future<void> _checkCloudBackupOnLaunch() async {
    final user = ref.read(currentUserProvider);
    if (user == null || !mounted) return;
    final uid = user.uid;

    try {
      final prefs = await SharedPreferences.getInstance();
      final decisionMade = prefs.getBool('backup_start_fresh_$uid') ?? false;
      if (decisionMade) return;

      final db = ref.read(appDatabaseProvider);
      final repo = ref.read(backupRepositoryProvider);
      final hasData = await repo.hasUserData(db);
      if (hasData) return;

      // Local database has no user data rows. Check cloud backup with 8-second timeout
      final meta = await repo.getCloudBackupMeta(uid);
      if (meta == null || meta.chunkCount == 0 || !mounted) return;

      debugPrint('[BACKUP_AUTO_RESTORE] Empty local DB found for $uid. Auto-restoring cloud backup...');
      await repo.restoreBackup(uid: uid, db: db);
      ref.read(lastBackupTimeProvider.notifier).update(meta.updatedAt);
      await prefs.setInt('backup_last_upload_time_$uid', meta.updatedAt.millisecondsSinceEpoch);
      await prefs.setString('backup_last_content_hash_$uid', meta.contentHash);
      debugPrint('[BACKUP_AUTO_RESTORE] Cloud backup restored silently and successfully.');
    } catch (e, st) {
      debugPrint('[BACKUP_AUTO_RESTORE_ERROR] Failed to auto-restore cloud backup on launch: $e\n$st');
      // Offline or timed out: continue normally and check again at the next app opening
    }
  }

  void _startSecurityMonitor() {
    _securityCheckTimer?.cancel();
    _securityCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkSecurityStatus();
    });
  }

  Future<void> _checkSecurityStatus() async {
    if (!mounted || isSigningOut || _isCheckingSecurity || _hasTriggeredSecurityDialog) return;
    final repo = ref.read(authRepositoryProvider);
    if (repo.currentUser == null || ref.read(activeUserIdProvider) == null) {
      _securityCheckTimer?.cancel();
      _securityCheckTimer = null;
      return;
    }
    _isCheckingSecurity = true;
    isCheckingAccountSecurity = true;
    try {
      final status = await repo.checkAccountStatus();
      if (!mounted || isSigningOut || repo.currentUser == null) return;

      if (status == AccountStatus.disabled || status == AccountStatus.deleted) {
        _hasTriggeredSecurityDialog = true;
        isAccountSuspended = true;
        _securityCheckTimer?.cancel();
        _securityCheckTimer = null;

        // Pop up the dialog FIRST on the current screen without navigating away
        final targetContext = rootNavigatorKey.currentContext ?? (context.mounted ? context : null);
        if (targetContext != null && targetContext.mounted) {
          final userEmail = _cachedUserEmail ?? repo.currentUser?.email;
          await AccountStatusDialog.show(
            targetContext,
            status: status,
            userEmail: userEmail,
            buttonText: 'خروج',
            buttonColor: AppColors.errorRed,
            showContactOptions: false,
            onDismissed: () {
              isAccountSuspended = false;
              // 1. Instantly transition smoothly to /sign-in so user NEVER sees the screen behind
              appRouter.go('/sign-in');

              // 2. Perform sign out and cleanup in parallel
              ref.read(authControllerProvider.notifier).signOut();
              ref.read(hasAutoOpenedBudgetForMonthProvider.notifier).reset();
              appAuthNotifier.notifyAuthChanged();
            },
          );
        }
      }
    } catch (_) {
    } finally {
      _isCheckingSecurity = false;
      isCheckingAccountSecurity = false;
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
    // Keep background backup sync controller active while user is on the main shell
    ref.watch(backupSyncControllerProvider);

    ref.listen<AsyncValue<MonthRemaining>>(currentMonthRemainingProvider, (prev, next) {
      // Ignore initial load or when account is switching / mounting:
      // A threshold notification must ONLY trigger when an active transaction drops balance from > 25% to <= 25%,
      // NEVER when opening the app or switching to another Gmail account!
      final prevRemaining = prev?.asData?.value;
      final nextRemaining = next.asData?.value;
      if (prevRemaining == null || nextRemaining == null) return;

      final userId = ref.read(activeUserIdProvider);
      if (userId == null || userId.isEmpty) return;

      final double prevBudget = prevRemaining.monthMoney / 100.0;
      final double prevRemainingEgp = prevRemaining.remaining / 100.0;
      final double newBudget = nextRemaining.monthMoney / 100.0;
      final double newRemainingEgp = nextRemaining.remaining / 100.0;

      if (prevBudget <= 0 && newBudget <= 0) return;

      final bool wasAbove = !BudgetMonitorController.isThresholdReached(
        totalBudget: prevBudget,
        remainingAmount: prevRemainingEgp,
      );
      final bool isNowBelow = BudgetMonitorController.isThresholdReached(
        totalBudget: newBudget,
        remainingAmount: newRemainingEgp,
      );

      // Trigger alert ONLY if user explicitly transitioned from above 25% to <= 25%
      if (wasAbove && isNowBelow) {
        BudgetMonitorController.evaluateAndNotify(
          totalBudget: newBudget,
          remainingAmount: newRemainingEgp,
          currentMonthKey: nextRemaining.yearMonth,
          userId: userId,
        );
      } else if (!isNowBelow) {
        // Balance rose back above 25% (income added or budget increased): re-arm
        BudgetMonitorController.evaluateAndNotify(
          totalBudget: newBudget,
          remainingAmount: newRemainingEgp,
          currentMonthKey: nextRemaining.yearMonth,
          userId: userId,
        );
      }
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
