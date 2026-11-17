import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

/// A sleek, welcoming empty-state card displayed when a page or section has no items yet.
class EmptyStateWelcomeCard extends StatelessWidget {
  const EmptyStateWelcomeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isCompact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final double iconContainerSize = isCompact ? 56.0 : 68.0;
    final double iconSize = isCompact ? 28.0 : 34.0;
    final double titleSize = isCompact ? 16.0 : 17.0;
    final double subtitleSize = isCompact ? 13.0 : 13.5;
    final EdgeInsets padding = isCompact
        ? const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0)
        : const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(isCompact ? 20.0 : 24.0),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.55),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10.0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconContainerSize,
            height: iconContainerSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.mainGreen.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.mainGreen.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: AppColors.mainGreen,
            ),
          ),
          SizedBox(height: isCompact ? 12.0 : 16.0),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: subtitleSize,
              fontWeight: FontWeight.w400,
              color: AppColors.secondaryText,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

