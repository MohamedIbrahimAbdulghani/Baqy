import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/debt_item.dart';

class SettledDebtsSection extends StatefulWidget {
  const SettledDebtsSection({
    super.key,
    required this.settledDebts,
    required this.onDebtTap,
  });

  final List<DebtItem> settledDebts;
  final ValueChanged<DebtItem> onDebtTap;

  @override
  State<SettledDebtsSection> createState() => _SettledDebtsSectionState();
}

class _SettledDebtsSectionState extends State<SettledDebtsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.settledDebts.isEmpty) {
      return const SizedBox.shrink();
    }

    final countStr = widget.settledDebts.length.toArabicDigits();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Settled debts header row
        InkWell(
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          borderRadius: BorderRadius.circular(16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: AppColors.inputBorder.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تم سدادها',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15.0,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      countStr,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 15.0,
                        fontWeight: FontWeight.w500,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    Icon(
                      _isExpanded ? Icons.expand_more : Icons.chevron_left,
                      size: 20.0,
                      color: AppColors.secondaryText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Expanded settled debts list under it inside the same screen
        if (_isExpanded) ...[
          const SizedBox(height: 8.0),
          ...widget.settledDebts.map((debt) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: InkWell(
                onTap: () => widget.onDebtTap(debt),
                borderRadius: BorderRadius.circular(14.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                  decoration: BoxDecoration(
                    color: AppColors.card.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(14.0),
                    border: Border.all(
                      color: AppColors.inputBorder.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        debt.personName,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 16.0,
                          fontWeight: FontWeight.bold,
                          color: AppColors.text,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10.0,
                          vertical: 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2EFEA),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Text(
                          'تم السداد',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13.0,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2A5949),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

