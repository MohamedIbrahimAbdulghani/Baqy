import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/debt_item.dart';

class DebtCard extends StatelessWidget {
  const DebtCard({
    super.key,
    required this.debt,
    required this.onTap,
  });

  final DebtItem debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final remainingEgp = debt.remaining ~/ 100;
    final totalEgp = debt.totalAmount ~/ 100;

    final remainingFormatted = NumberFormatter.formatCurrency(remainingEgp);
    final totalFormatted = NumberFormatter.formatCurrency(totalEgp);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: AppColors.inputBorder.withValues(alpha: 0.5),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Person name & Remaining amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    debt.personName,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Text(
                  '$remainingFormatted جنيه',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    color: AppColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6.0),

            // Second Row: "المتبقي من X جنيه"
            Text(
              'المتبقي من $totalFormatted جنيه',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.0,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12.0),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6.0),
              child: SizedBox(
                height: 8.0,
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: LinearProgressIndicator(
                    value: debt.progress,
                    backgroundColor: const Color(0xFFE2DDD5),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF4A7C59),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

