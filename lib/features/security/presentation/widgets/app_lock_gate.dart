import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/security_providers.dart';
import '../screens/app_lock_screen.dart';

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial check: if app lock is enabled and user is signed in, lock on cold start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLock();
    });
  }

  void _checkInitialLock() {
    final user = ref.read(activeUserIdProvider);
    final settings = ref.read(securitySettingsProvider).value;
    if (user != null && settings != null && settings.isAppLockEnabled) {
      ref.read(isAppLockedProvider.notifier).lock();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final user = ref.read(activeUserIdProvider);
    final settings = ref.read(securitySettingsProvider).value;

    if (user == null || settings == null || !settings.isAppLockEnabled) {
      return;
    }

    // Check user preference for locking upon leaving the app
    if (!settings.lockOnExit) {
      return;
    }

    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
      ref.read(isAppLockedProvider.notifier).lock();
    } else if (state == AppLifecycleState.resumed) {
      // Lock if paused
      if (_pausedAt != null) {
        ref.read(isAppLockedProvider.notifier).lock();
        _pausedAt = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(isAppLockedProvider);
    final settings = ref.watch(securitySettingsProvider).value;
    final user = ref.watch(activeUserIdProvider);

    final shouldShowLock =
        isLocked && user != null && (settings?.isAppLockEnabled ?? false);

    return Stack(
      children: [
        widget.child,
        if (shouldShowLock)
          Positioned.fill(
            child: Navigator(
              onGenerateRoute: (settings) => MaterialPageRoute(
                builder: (context) => const AppLockScreen(),
              ),
            ),
          ),
      ],
    );
  }
}
