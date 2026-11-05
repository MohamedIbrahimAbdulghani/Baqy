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

class CategoryDetailsScreen extends ConsumerWidget {
  const CategoryDetailsScreen({
    super.key,
    required this.args,
  });

  final CategoryDetailsArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TransactionItem>> transactionsAsync = args.isMonthMode
        ? ref.watch(
            categoryTransactionsForMonthProvider((
              categoryId: args.category.id,
              yearMonth: args.yearMonth,
            )),
          )
        : ref.watch(
            categoryTransactionsForDayProvider((
              categoryId: args.category.id,
              day: args.day ?? DateTime.now(),
            )),
          );

    final String dateSubtitle = args.isMonthMode
        ? ArabicDateHelper.formatYearMonthKeyToDisplay(args.yearMonth)
        : (args.day != null
            ? ArabicDateHelper.formatWeekdayDayMonth(args.day!)
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
                        if (dateSubtitle.isNotEmpty)
                          Text(
                            dateSubtitle,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w400,
                              color: AppColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: transactionsAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.mainGreen),
                  ),
                  error: (_, _) => const Center(
                    child: Text(
                      'خطأ في تحميل البيانات',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: Colors.red,
                      ),
                    ),
                  ),
                  data: (transactions) {
                    final int totalPiastres = transactions.fold<int>(
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

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 14.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius:
                                  BorderRadius.circular(AppDimensions.cardRadius),
                              boxShadow: AppDimensions.cardShadow,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Right: Description and Time
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                  '${NumberFormatter.formatCurrency(txAmountEgp)} جنيه',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 16.0,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
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
