import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/widgets/empty_state_welcome_card.dart';
import '../../../expenses/domain/models/transaction_item.dart';
import '../../../expenses/presentation/widgets/transaction_actions_sheet.dart';

class RecentTransactionsSection extends StatelessWidget {
  const RecentTransactionsSection({
    super.key,
    required this.transactions,
  });

  final List<TransactionItem> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
        child: EmptyStateWelcomeCard(
          icon: Icons.receipt_long_rounded,
          title: 'لسه مبدأتش مصاريفك الشهر ده',
          subtitle:
              'سجل أول عملية بالضغط على (+) أو بالصوت، وشوف مصاريفك بتترتب وتتحسب تلقائياً.',
          isCompact: true,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
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

class _TransactionCard extends ConsumerWidget {
  const _TransactionCard({required this.transaction});

  final TransactionItem transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int amountEgp = transaction.amount ~/ 100;
    final iconData = CategoryIconHelper.getIcon(transaction.category?.icon);
    final categoryColor =
        CategoryIconHelper.parseColor(transaction.category?.color);
    final String amountText = amountEgp < 0
        ? '-${NumberFormatter.formatCurrency(amountEgp.abs())} جنيه'
        : '${NumberFormatter.formatCurrency(amountEgp)} جنيه';

    return InkWell(
      onTap: () => TransactionActionsHelper.showEditSheet(
        context: context,
        ref: ref,
        transaction: transaction,
      ),
      onLongPress: () => TransactionActionsHelper.showActionsBottomSheet(
        context: context,
        ref: ref,
        transaction: transaction,
      ),
      borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
      child: Container(
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
            // Left: Amount, Deposit/Withdrawal badge & foreign reference
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w700,
                    color: transaction.isAddition
                        ? AppColors.mainGreen
                        : AppColors.text,
                  ),
                ),
                const SizedBox(height: 4.0),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7.0,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: transaction.isAddition
                        ? AppColors.mainGreen.withValues(alpha: 0.12)
                        : AppColors.errorRed.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        transaction.isAddition
                            ? Icons.add_rounded
                            : Icons.remove_rounded,
                        size: 13.0,
                        color: transaction.isAddition
                            ? AppColors.mainGreen
                            : AppColors.errorRed,
                      ),
                      const SizedBox(width: 2.0),
                      Text(
                        transaction.isAddition
                            ? 'إيداع (مضافة)'
                            : 'سحب (مخصومة)',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: transaction.isAddition
                              ? AppColors.mainGreen
                              : AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                ),
                if (transaction.foreignAmount != null &&
                    transaction.foreignCurrency != null) ...[
                  const SizedBox(height: 3.0),
                  Text(
                    '≈ ${transaction.foreignAmount} ${transaction.foreignCurrency}',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12.0,
                      color: AppColors.mainGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),

            // Right: Description & Category chip
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      transaction.description,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16.0,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    if (transaction.note != null &&
                        transaction.note!.isNotEmpty) ...[
                      const SizedBox(height: 2.0),
                      Text(
                        transaction.note!,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.0,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: 12.0),
                Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Icon(
                    iconData,
                    color: categoryColor,
                    size: 24.0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
