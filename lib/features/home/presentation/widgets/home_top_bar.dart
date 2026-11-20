import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';

class HomeTopBar extends ConsumerWidget {
  const HomeTopBar({
    super.key,
    required this.selectedMonthText,
    required this.onTapMonthSelector,
    this.customGreeting,
  });

  final String selectedMonthText;
  final VoidCallback onTapMonthSelector;
  final String? customGreeting;

  /// Returns "صباح الخير" (morning: 4:00 AM to 11:59 AM)
  /// or "مساء الخير" (afternoon/evening/night: 12:00 PM to 3:59 AM).
  static String resolveGreeting([DateTime? now]) {
    final current = now ?? DateTime.now();
    final hour = current.hour;
    if (hour >= 4 && hour < 12) {
      return 'صباح الخير';
    }
    return 'مساء الخير';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final greeting = customGreeting ?? resolveGreeting();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: Theme toggle and Settings gear buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    width: 42.0,
                    height: 42.0,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: AppDimensions.cardShadow,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Icon(
                        isDark ? Icons.wb_sunny_rounded : Icons.wb_sunny_outlined,
                        key: ValueKey<bool>(isDark),
                        color: isDark ? AppColors.coinGold : AppColors.darkGreen,
                        size: 22.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8.0),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/settings'),
                  borderRadius: BorderRadius.circular(12.0),
                  child: Container(
                    width: 42.0,
                    height: 42.0,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12.0),
                      boxShadow: AppDimensions.cardShadow,
                    ),
                    child: Icon(
                      Icons.settings_outlined,
                      color: AppColors.darkGreen,
                      size: 22.0,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Right: "صباح الخير" / "مساء الخير" & Month Selector
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mainGreen,
                  ),
                ),
                const SizedBox(height: 2.0),
                InkWell(
                  onTap: onTapMonthSelector,
                  borderRadius: BorderRadius.circular(8.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              selectedMonthText,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 22.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.text,
                          size: 24.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
