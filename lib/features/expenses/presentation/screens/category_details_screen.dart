import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/category_details_args.dart';
import '../../domain/models/transaction_item.dart';
import '../providers/expense_providers.dart';
import '../widgets/transaction_actions_sheet.dart';

class CategoryDetailsScreen extends ConsumerWidget {
  const CategoryDetailsScreen({
    super.key,
    required this.args,
  });

  final CategoryDetailsArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final normalizedDay = args.day != null
        ? DateTime(args.day!.year, args.day!.month, args.day!.day)
        : null;

    final txProvider = args.isMonthMode
        ? categoryTransactionsForMonthProvider((
            categoryId: args.category.id,
            yearMonth: args.yearMonth,
          ))
        : (normalizedDay != null
            ? categoryTransactionsForDayProvider((
                categoryId: args.category.id,
                day: normalizedDay,
              ))
            : null);

    // Auto-pop if category becomes empty after deletions
    if (txProvider != null) {
      ref.listen<AsyncValue<List<TransactionItem>>>(txProvider, (prev, next) {
        if (next.hasValue &&
            next.value!.isEmpty &&
            (prev?.value?.isNotEmpty ?? false)) {
          if (context.mounted) {
            context.pop();
          }
        }
      });
    }

    final AsyncValue<List<TransactionItem>> transactionsAsync =
        txProvider != null
            ? ref.watch(txProvider)
            : const AsyncValue.data([]);

    final AsyncValue<int> categoryTotalAsync = args.isMonthMode
        ? ref.watch(
            categoryTotalForMonthProvider((
              categoryId: args.category.id,
              yearMonth: args.yearMonth,
            )),
          )
        : (normalizedDay != null
            ? ref.watch(
                categoryTotalForDayProvider((
                  categoryId: args.category.id,
                  day: normalizedDay,
                )),
              )
            : const AsyncValue.data(0));

    final String dateSubtitle = args.isMonthMode
        ? ArabicDateHelper.formatYearMonthKeyToDisplay(args.yearMonth)
        : (normalizedDay != null
            ? ArabicDateHelper.formatWeekdayDayMonth(normalizedDay)
            : '');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Back arrow and Category Name + Date
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => context.pop(),
                      borderRadius: BorderRadius.circular(8.0),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 22.0,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          args.category.name,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 22.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                        if (dateSubtitle.isNotEmpty) ...[
                          const SizedBox(height: 2.0),
                          Text(
                            dateSubtitle,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14.0,
                              fontWeight: FontWeight.w400,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8.0),

              Expanded(
                child: transactionsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.mainGreen),
                  ),
                  error: (error, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'حدث خطأ في تحميل البيانات',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(height: 8.0),
                        TextButton.icon(
                          onPressed: () {
                            if (txProvider != null) {
                              ref.invalidate(txProvider);
                            }
                          },
                          icon: const Icon(Icons.refresh, color: AppColors.mainGreen),
                          label: const Text(
                            'إعادة المحاولة',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppColors.mainGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  data: (transactions) {
                    final int totalPiastres = categoryTotalAsync.value ??
                        transactions.fold<int>(
                          0,
                          (sum, item) => sum + item.amount,
                        );
                    final int totalEgp = totalPiastres ~/ 100;

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      children: [
                        const SizedBox(height: 16.0),

                        // Center Summary: "الإجمالي" and huge amount
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'الإجمالي',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 14.0,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              const SizedBox(height: 6.0),
                              Text(
                                '${NumberFormatter.formatCurrency(totalEgp)} جنيه',
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 42.0,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.text,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28.0),

                        // Transactions List
                        ...transactions.map((tx) {
                          final int txAmountEgp = tx.amount ~/ 100;
                          final String timeText = args.isMonthMode
                              ? ArabicDateHelper.formatDateTime(tx.createdAt)
                              : ArabicDateHelper.formatTime(tx.createdAt);
                          final isVirtualSavings = args.category.id == -1 ||
                              args.category.name == 'تحويش' ||
                              tx.categoryId == -1;

                          final String txAmountText = txAmountEgp < 0
                              ? '-${NumberFormatter.formatCurrency(txAmountEgp.abs())} جنيه'
                              : '${NumberFormatter.formatCurrency(txAmountEgp)} جنيه';

                          return InkWell(
                            onTap: isVirtualSavings
                                ? null
                                : () => TransactionActionsHelper.showEditSheet(
                                      context: context,
                                      ref: ref,
                                      transaction: tx,
                                    ),
                            onLongPress: isVirtualSavings
                                ? null
                                : () => TransactionActionsHelper
                                    .showActionsBottomSheet(
                                    context: context,
                                    ref: ref,
                                    transaction: tx,
                                  ),
                            borderRadius: BorderRadius.circular(
                                AppDimensions.cardRadius),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 14.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(
                                    AppDimensions.cardRadius),
                                boxShadow: AppDimensions.cardShadow,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  // Right: Description, Notes, Time & Foreign reference
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          tx.description,
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 16.0,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.text,
                                          ),
                                        ),
                                        if (tx.note != null &&
                                            tx.note!.isNotEmpty) ...[
                                          const SizedBox(height: 2.0),
                                          Text(
                                            tx.note!,
                                            style: const TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w400,
                                              color: AppColors.secondaryText,
                                            ),
                                          ),
                                        ],
                                        if (tx.foreignAmount != null &&
                                            tx.foreignCurrency != null) ...[
                                          const SizedBox(height: 2.0),
                                          Text(
                                            '≈ ${tx.foreignAmount} ${tx.foreignCurrency}',
                                            style: const TextStyle(
                                              fontFamily: AppTheme.fontFamily,
                                              fontSize: 12.0,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.mainGreen,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 4.0),
                                        Text(
                                          timeText,
                                          style: const TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: 13.0,
                                            fontWeight: FontWeight.w400,
                                            color: AppColors.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12.0),

                                  // Left: Amount
                                  Text(
                                    txAmountText,
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 16.0,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24.0),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
