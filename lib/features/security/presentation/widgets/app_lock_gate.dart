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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initial check: ensure locked if user is already signed in and app lock enabled
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
    final repo = ref.read(securityRepositoryProvider);
    // If the system biometric prompt is actively showing, ignore the temporary inactive transition
    if (repo.isBiometricPromptActive) {
      return;
    }

    final user = ref.read(activeUserIdProvider);
    final settings = ref.read(securitySettingsProvider).value;
    final isLockEnabled = settings?.isAppLockEnabled ?? repo.isAppLockEnabledSync;

    if (user == null || !isLockEnabled) {
      return;
    }

    // Whenever the app leaves the active foreground (answering a phone call,
    // switching apps, pulling down notifications, going home, or locking the screen):
    // Lock immediately so opening the app again strictly requires authentication!
    if (state != AppLifecycleState.resumed) {
      ref.read(isAppLockedProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(isAppLockedProvider);
    final settings = ref.watch(securitySettingsProvider).value;
    final user = ref.watch(activeUserIdProvider);
    final repo = ref.watch(securityRepositoryProvider);

    // Synchronously check lock enabled to guarantee zero-millisecond lag/flicker
    final isLockEnabled = settings?.isAppLockEnabled ?? repo.isAppLockEnabledSync;

    final shouldShowLock = isLocked && user != null && isLockEnabled;

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
