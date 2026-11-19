import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/number_formatter.dart';

class DebtSummaryCard extends StatelessWidget {
  const DebtSummaryCard({
    super.key,
    required this.direction,
    required this.totalRemainingPiastres,
  });

  final String direction; // "owe" or "owed"
  final int totalRemainingPiastres;

  @override
  Widget build(BuildContext context) {
    final isOwe = direction == 'owe';
    final title = isOwe ? 'إجمالي اللي عليك' : 'إجمالي اللي ليك';
    final remainingEgp = totalRemainingPiastres ~/ 100;
    final formattedAmount = NumberFormatter.formatCurrency(remainingEgp);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 22.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14.0,
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8.0),
          Text(
            '$formattedAmount جنيه',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 32.0,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

