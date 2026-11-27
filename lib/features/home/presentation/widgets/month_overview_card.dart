import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/models/month_insights.dart';

class MonthOverviewCard extends StatelessWidget {
  const MonthOverviewCard({
    super.key,
    required this.insights,
  });

  final MonthInsights insights;

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16.0,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? AppColors.dividers
                : AppColors.dividers.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Section Title: "نظرة على شهرك"
            Text(
              'نظرة على شهرك',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 17.0,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 16.0),

            // 1. Burn Rate Pacing
            _buildInsightRow(
              text: insights.burnRateText,
              icon: Icons.error_outline_rounded,
              badgeBg: isDark
                  ? const Color(0xFF2D2316)
                  : const Color(0xFFFDF4E3),
              badgeFg: isDark
                  ? const Color(0xFFF2BE5A)
                  : const Color(0xFFB88226),
            ),

            _buildDivider(),

            // 2. Daily Allowed Average
            _buildInsightRow(
              text: insights.dailyAllowanceText,
              icon: Icons.calendar_today_outlined,
              badgeBg: isDark
                  ? const Color(0xFF142B22)
                  : const Color(0xFFE2F0EC),
              badgeFg: isDark
                  ? const Color(0xFF5CA390)
                  : const Color(0xFF2F6B5A),
            ),

            _buildDivider(),

            // 3. Comparison with previous period
            _buildInsightRow(
              text: insights.comparisonText,
              icon: insights.isSpendingLess
                  ? Icons.trending_down_rounded
                  : Icons.trending_up_rounded,
              badgeBg: isDark
                  ? const Color(0xFF152D1E)
                  : const Color(0xFFE6F4EA),
              badgeFg: isDark
                  ? const Color(0xFF66BB6A)
                  : const Color(0xFF2E7D32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightRow({
    required String text,
    required IconData icon,
    required Color badgeBg,
    required Color badgeFg,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Insight Text (Right side in RTL)
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(width: 14.0),

        // Circular Icon Badge (Left side in RTL)
        Container(
          width: 38.0,
          height: 38.0,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: badgeBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20.0,
            color: badgeFg,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Divider(
        height: 1.0,
        thickness: 1.0,
        color: AppColors.dividers.withValues(alpha: 0.5),
      ),
    );
  }
}
