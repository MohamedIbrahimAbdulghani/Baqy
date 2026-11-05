import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final List<String> tabTitles = [
      l10n?.tabHome ?? 'الرئيسية',
      l10n?.tabGoals ?? 'الأهداف',
      l10n?.tabAppointments ?? 'المواعيد',
      l10n?.tabDebts ?? 'الديون',
    ];

    return Container(
      height: 60.0,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.dividers,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Row(
          children: List.generate(tabTitles.length, (index) {
            final bool isActive = currentIndex == index;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(index),
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
                child: Center(
                  child: Text(
                    tabTitles[index],
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13.0,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                      color: isActive ? AppColors.darkGreen : AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

