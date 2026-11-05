import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/baqy_logo.dart';
import '../../../../l10n/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        context.go('/main');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final String title = l10n?.appTitle ?? 'باقي';
    final String subTitle = l10n?.appNameSub ?? 'BAQY';

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
              title,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700,
                fontSize: 44,
                color: AppColors.background,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subTitle,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: AppColors.categoryTransport, // #E8A83A
                letterSpacing: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

