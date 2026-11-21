import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/baqy_logo.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/exceptions/auth_exceptions.dart';
import '../../domain/models/account_status.dart';
import '../providers/auth_providers.dart';
import '../widgets/account_status_dialog.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  Future<void> _handleGoogleSignIn(BuildContext context, WidgetRef ref) async {
    final success =
        await ref.read(authControllerProvider.notifier).signInWithGoogle();

    if (!context.mounted) return;

    if (success) {
      appAuthNotifier.notifyAuthChanged();
      appRouter.go('/main');
    } else {
      final authState = ref.read(authControllerProvider);
      if (authState.hasError) {
        final error = authState.error;
        if (error is AccountDisabledException) {
          await AccountStatusDialog.show(
            context,
            status: AccountStatus.disabled,
            customReason: error.message,
            userEmail: error.email,
            buttonText: 'حسناً',
            showContactOptions: true,
          );
          return;
        } else if (error is AccountDeletedException) {
          await AccountStatusDialog.show(
            context,
            status: AccountStatus.deleted,
            customReason: error.message,
            userEmail: error.email,
            buttonText: 'حسناً',
            showContactOptions: true,
          );
          return;
        }

        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor: const Color(0xFF2C2C2C),
            content: Text(
              l10n?.signInError ?? 'مقدرتش أسجّلك، جرّب تاني',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authControllerProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Logo in dark green rounded box
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Center(
                    child: BaqyLogo(
                      size: 56,
                      isSplash: false,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Welcome Title
              Text(
                l10n?.signInTitle ?? 'أهلاً بيك في Baqy',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 32,
                  color: AppColors.text,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              Text(
                l10n?.signInSubtitle ?? 'سجّل دخولك وابدأ تتابع مصاريفك بصوتك',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: AppColors.secondaryText,
                ),
              ),

              const Spacer(flex: 2),

              // Google Sign-In Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isLoading ? null : () => _handleGoogleSignIn(context, ref),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                    ),
                    child: Center(
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppColors.mainGreen,
                              ),
                            )
                          : Text(
                              l10n?.signInWithGoogle ?? 'الدخول بحساب جوجل',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: AppColors.text,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Author attribution and Privacy text at the bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  children: [
                    Text(
                      l10n?.madeBy ?? 'صُنع بواسطة محمد إبراهيم',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.privacyLine ??
                          'بياناتك بتتحفظ على موبايلك إنت بس، ومفيش حد في الفريق يقدر يشوفها.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
