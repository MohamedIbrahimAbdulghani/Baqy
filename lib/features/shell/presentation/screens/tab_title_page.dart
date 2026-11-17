import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/empty_state_welcome_card.dart';

class TabTitlePage extends ConsumerWidget {
  const TabTitlePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 26.0,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                ),
              ),
              const Expanded(
                child: Center(
                  child: EmptyStateWelcomeCard(
                    icon: Icons.handshake_rounded,
                    title: 'سجل ديونك والتزاماتك',
                    subtitle:
                        'تابع اللي ليك واللي عليك بكل سهولة ووضوح، عشان حساباتك تفضل دايماً مضبوطة وخالية من اللخبطة.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

