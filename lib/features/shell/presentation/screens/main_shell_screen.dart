import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/services/app_shortcut_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/widget_recording_service.dart';
import '../../../auth/domain/models/account_status.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/account_status_dialog.dart';
import '../../../backup/presentation/providers/backup_providers.dart';
import '../../../backup/presentation/widgets/restore_prompt_dialog.dart';
import '../../../security/presentation/providers/security_providers.dart';
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

  @visibleForTesting
  static bool enableSecurityTimer = true;

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen>
    with WidgetsBindingObserver {
  Timer? _securityCheckTimer;
  bool _isCheckingSecurity = false;
  bool _hasTriggeredSecurityDialog = false;
  String? _cachedUserEmail;
  StreamSubscription<String>? _shortcutSubscription;
  String? _pendingShortcutAction;

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

    AppShortcutService.instance.initialize();
    _shortcutSubscription =
        AppShortcutService.instance.actionStream.listen((action) {
      if (mounted) {
        _onShortcutReceived(action);
      }
    });

    // Listen for instant audio ready event when user finishes recording from widget
    WidgetRecordingService.setAudioReadyHandler((path) {
      if (mounted) {
        _processWidgetAudio(path);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = NotificationService.consumePendingTabSelection();
      if (pending != null && mounted) {
        ref.read(tabIndexProvider.notifier).selectTab(pending);
      }

      // Check for cold start app shortcut action
      AppShortcutService.instance.checkInitialShortcut().then((action) {
        if (action != null && mounted) {
          _onShortcutReceived(action);
        }
      });

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

      // Check for any audio recorded via the home screen widget before the app was opened
      _checkWidgetPendingAudio();
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

  /// Checks if the home screen widget left a pending audio recording.
  /// If yes, feeds it into the existing Gemini processing pipeline (processAudioFile)
  /// which shows the undo snackbar for a clear result, or the review sheet for an
  /// unclear result. Identical to what happens for a shortcut-initiated recording,
  /// except the flag [isFromShortcut] is kept true so auto-save applies.
  Future<void> _checkWidgetPendingAudio() async {
    if (!mounted) return;
    // Only process if user is signed in and app is not locked
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;
    final isLocked = ref.read(isAppLockedProvider);
    if (isLocked) return;

    final path = await WidgetRecordingService.checkWidgetPendingAudio();
    if (path == null || !mounted) return;

    // Clear native side and pending storage so we don't reprocess on next resume
    await WidgetRecordingService.clearWidgetPendingAudio();
    await PendingRecordingStorage.clear();
    ref.read(pendingVoiceAudioPathProvider.notifier).setVal(null);

    // If currently recording something, don't start a second process
    final isRecording = ref.read(voiceRecordingProvider);
    if (isRecording) return;

    final ctx = context;
    if (!ctx.mounted) return;

    // Feed directly into the existing audio processing pipeline (Gemini + auto-save) silently
    await ref.read(voiceRecordingProvider.notifier).processAudioFile(
      path,
      context: ctx,
      isFromShortcut: true, // triggers auto-save on clear result
      showAnalyzingOverlay: false, // silent background processing, no blocking overlay
    );
  }

  /// Processes widget audio immediately when the widget stops recording,
  /// without waiting for the app to open.
  Future<void> _processWidgetAudio(String path) async {
    if (!mounted) return;
    final userId = ref.read(activeUserIdProvider);
    if (userId == null) return;

    // Clear native side and pending storage so we don't reprocess on resume
    await WidgetRecordingService.clearWidgetPendingAudio();
    await PendingRecordingStorage.clear();
    ref.read(pendingVoiceAudioPathProvider.notifier).setVal(null);

    // If currently recording something, don't start a second process
    final isRecording = ref.read(voiceRecordingProvider);
    if (isRecording) return;

    // Feed directly into Gemini auto-save pipeline silently without blocking overlay
    await ref.read(voiceRecordingProvider.notifier).processAudioFile(
      path,
      context: mounted ? context : null,
      isFromShortcut: true,
      showAnalyzingOverlay: false,
    );
  }

  void _startSecurityMonitor() {
    if (!MainShellScreen.enableSecurityTimer) return;
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
      if (_pendingShortcutAction != null && mounted && !isAccountSuspended) {
        final action = _pendingShortcutAction!;
        _pendingShortcutAction = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _executeShortcutAction(action);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _shortcutSubscription?.cancel();
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
      // Check for any recording left behind by the home screen widget
      _checkWidgetPendingAudio();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep background backup sync controller active while user is on the main shell
    ref.watch(backupSyncControllerProvider);

    ref.listen<bool>(isAppLockedProvider, (previous, isLocked) {
      if (previous == true && !isLocked) {
        if (_pendingShortcutAction != null) {
          final action = _pendingShortcutAction!;
          _pendingShortcutAction = null;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _executeShortcutAction(action);
            }
          });
        }
        // Also check if there was an audio recording made via widget while the app was locked
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _checkWidgetPendingAudio();
          }
        });
      }
    });

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
    final isRecording = ref.watch(voiceRecordingProvider);
    final isAnalyzing = ref.watch(voiceIsAnalyzingProvider);

    return Stack(
      children: [
        Scaffold(
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
          floatingActionButton: (isRecording || isAnalyzing)
              ? null
              : (selectedIndex == 0
                  ? const HomeSpeedDialFab()
                  : (selectedIndex == 1
                      ? const GoalsSpeedDialFab()
                      : (selectedIndex == 2
                          ? const RemindersSpeedDialFab()
                          : (selectedIndex == 3 ? const DebtsFab() : null)))),
          floatingActionButtonLocation: const AboveBottomBarFabLocation(gap: 14.0),
          bottomNavigationBar: CustomBottomNavBar(
            currentIndex: selectedIndex,
            onTap: (index) {
              if (isRecording || isAnalyzing) return;
              ref.read(tabIndexProvider.notifier).selectTab(index);
            },
          ),
        ),
        if (isRecording || isAnalyzing)
          VoiceRecordingFocusedOverlay(
            isAnalyzing: isAnalyzing,
            onStop: () {
              if (!isAnalyzing) {
                ref.read(voiceRecordingProvider.notifier).stopRecording(context: context);
              }
            },
            onCancel: () {
              if (!isAnalyzing) {
                ref.read(voiceRecordingProvider.notifier).cancelRecording(context: context);
              }
            },
          ),
      ],
    );
  }

  void _onShortcutReceived(String action) {
    if (action != AppShortcutService.actionRecordVoice) return;

    final user = ref.read(authRepositoryProvider).currentUser;
    final activeUid = ref.read(activeUserIdProvider);
    if (user == null || activeUid == null) {
      // User is not signed in: do not start recording
      return;
    }

    final repo = ref.read(securityRepositoryProvider);
    final settings = ref.read(securitySettingsProvider).value;
    final isLockEnabled =
        settings?.isAppLockEnabled ?? repo.isAppLockEnabledSync;
    final isLocked = ref.read(isAppLockedProvider);

    if (isLockEnabled && isLocked) {
      _pendingShortcutAction = action;
      return;
    }

    if (isCheckingAccountSecurity || _isCheckingSecurity) {
      _pendingShortcutAction = action;
      return;
    }

    _executeShortcutAction(action);
  }

  void _executeShortcutAction(String action) {
    if (action != AppShortcutService.actionRecordVoice) return;
    if (!mounted) return;

    final user = ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    if (ref.read(tabIndexProvider) != 0) {
      ref.read(tabIndexProvider.notifier).selectTab(0);
    }

    final isRecording = ref.read(voiceRecordingProvider);
    final isAnalyzing = ref.read(voiceIsAnalyzingProvider);
    if (isRecording || isAnalyzing) {
      return;
    }

    final syncCtrl = ref.read(backupSyncControllerProvider);
    if (syncCtrl != null &&
        (syncCtrl.isRestoring ||
            syncCtrl.isUploading ||
            syncCtrl.isConflictDialogShowing)) {
      return;
    }
    if (RestorePromptDialog.isShowing) {
      return;
    }
    if (isAccountSuspended ||
        AccountStatusDialog.isShowing ||
        isCheckingAccountSecurity) {
      return;
    }

    ref.read(voiceRecordingProvider.notifier).startRecording(
          context: context,
          isFromShortcut: true,
        );
  }
}
