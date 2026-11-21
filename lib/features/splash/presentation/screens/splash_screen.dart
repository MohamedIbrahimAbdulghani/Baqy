import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/baqy_logo.dart';
import '../../../auth/domain/models/account_status.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/account_status_dialog.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Show splash for at least 1.5 seconds for instant branding feel
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final repo = ref.read(authRepositoryProvider);
    final user = repo.currentUser;

    if (user != null) {
      // First verify account status with Firebase
      final status = await repo.checkAccountStatus();
      if (!mounted) return;

      if (status == AccountStatus.disabled || status == AccountStatus.deleted) {
        if (mounted) {
          // Show pop-up FIRST on the splash screen
          await AccountStatusDialog.show(
            context,
            status: status,
            buttonText: 'تسجيل الخروج',
            onDismissed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              ref.read(hasAutoOpenedBudgetForMonthProvider.notifier).reset();
              if (mounted) {
                context.go('/sign-in');
              }
            },
          );
        }
        return;
      }

      // User is already signed in and active: initialize account database and go straight to app
      try {
        final dbManager = ref.read(accountDatabaseManagerProvider);
        final db = await dbManager.openDatabaseForAccount(user.uid);
        ref.read(activeDatabaseProvider.notifier).setDatabase(db);
        ref.read(activeUserIdProvider.notifier).setUserId(user.uid);
      } catch (e, stack) {
        debugPrint('[AUTH_ERROR] SplashScreen failed to open account DB: $e\n$stack');
      }

      if (mounted) {
        context.go('/main');
      }
    } else {
      if (mounted) {
        context.go('/sign-in');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const BaqyLogo(
              size: 100,
              isSplash: true,
            ),
            const SizedBox(height: 28),
            Text(
              'باقي',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 44,
                color: AppColors.background,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'BAQY',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.categoryTransport,
                letterSpacing: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
