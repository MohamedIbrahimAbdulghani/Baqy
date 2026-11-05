import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../expenses/domain/models/transaction_item.dart';

class RecentTransactionsSection extends StatelessWidget {
  const RecentTransactionsSection({
    super.key,
    required this.transactions,
  });

  final List<TransactionItem> transactions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              'آخر المصاريف',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18.0,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              return _TransactionCard(transaction: tx);
            },
          ),
        ),
      ],
    );
  }
}

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({required this.transaction});

  final TransactionItem transaction;

  @override
  Widget build(BuildContext context) {
    final int amountEgp = transaction.amount ~/ 100;
    final iconData = CategoryIconHelper.getIcon(transaction.category?.icon);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: AppDimensions.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Amount (e.g. "١٥٠ جنيه")
          Text(
            '${NumberFormatter.formatCurrency(amountEgp)} جنيه',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16.0,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),

          // Right: Description & Category chip
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                transaction.description,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(width: 12.0),
              Container(
                width: 44.0,
                height: 44.0,
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(
                  iconData,
                  color: AppColors.mainGreen,
                  size: 22.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

