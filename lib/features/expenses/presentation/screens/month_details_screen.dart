import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/category_details_args.dart';
import '../../domain/models/category_item.dart';
import '../providers/expense_providers.dart';
import '../widgets/month_expenses_chart.dart';

class MonthDetailsScreen extends ConsumerStatefulWidget {
  const MonthDetailsScreen({
    super.key,
    this.initialYearMonth,
  });

  final String? initialYearMonth;

  @override
  ConsumerState<MonthDetailsScreen> createState() => _MonthDetailsScreenState();
}

class _MonthDetailsScreenState extends ConsumerState<MonthDetailsScreen> {
  late String _currentYearMonth;
  late DateTime _selectedDay;
  bool _initializedLatestDay = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (widget.initialYearMonth != null &&
        RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(widget.initialYearMonth!)) {
      _currentYearMonth = widget.initialYearMonth!;
    } else {
      _currentYearMonth = ArabicDateHelper.formatYearMonthKey(now.year, now.month);
    }

    final (y, m) = ArabicDateHelper.parseYearMonthKey(_currentYearMonth);
    if (y == now.year && m == now.month) {
      _selectedDay = today;
      _initializedLatestDay = true;
    } else {
      // For a past month, default to the last day of that month initially
      _selectedDay = DateTime(y, m + 1, 0);
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDay.year == now.year &&
        _selectedDay.month == now.month &&
        _selectedDay.day == now.day;
  }

  void _goToPreviousDay() {
    final prevDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day - 1,
    );
    setState(() {
      _selectedDay = prevDay;
      final newYm =
          ArabicDateHelper.formatYearMonthKey(prevDay.year, prevDay.month);
      if (newYm != _currentYearMonth) {
        _currentYearMonth = newYm;
      }
    });
  }

  void _goToNextDay() {
    if (_isToday) return;

    final nextDay = DateTime(
      _selectedDay.year,
      _selectedDay.month,
      _selectedDay.day + 1,
    );
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (nextDay.isAfter(today)) return;

    setState(() {
      _selectedDay = nextDay;
      final newYm =
          ArabicDateHelper.formatYearMonthKey(nextDay.year, nextDay.month);
      if (newYm != _currentYearMonth) {
        _currentYearMonth = newYm;
      }
    });
  }

  void _openCategoryDetails({
    required CategoryItem category,
    required bool isMonthMode,
  }) {
    context.push(
      '/category-details',
      extra: CategoryDetailsArgs(
        category: category,
        yearMonth: _currentYearMonth,
        day: isMonthMode ? null : _selectedDay,
        isMonthMode: isMonthMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If opening a past month and haven't checked latest expense day, check it once
    if (!_initializedLatestDay) {
      final latestDayAsync =
          ref.watch(latestExpenseDayForMonthProvider(_currentYearMonth));
      latestDayAsync.whenData((latestDay) {
        if (!_initializedLatestDay) {
          _initializedLatestDay = true;
          if (latestDay != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedDay = latestDay;
                });
              }
            });
          }
        }
      });
    }

    final (currentYear, currentMonth) =
        ArabicDateHelper.parseYearMonthKey(_currentYearMonth);
    final String monthName = ArabicDateHelper.getMonthName(currentMonth);
    final String pageTitle =
        ArabicDateHelper.formatMonthYear(currentYear, currentMonth);

    final monthTotalsAsync =
        ref.watch(monthCategoryTotalsProvider(_currentYearMonth));
    final dayTotalsAsync =
        ref.watch(dayCategoryTotalsProvider(_selectedDay));
    final hasExpensesBeforeAsync =
        ref.watch(hasExpensesBeforeProvider(_selectedDay));

    final bool canGoBack = hasExpensesBeforeAsync.value ?? false;
    final bool canGoForward = !_isToday;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Back arrow on right, title "<month> <year>"
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
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
                    Text(
                      pageTitle,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 22.0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable body
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  children: [
                    const SizedBox(height: 8.0),

                    // 1. Month Expenses Card with Vertical Bar Chart
                    monthTotalsAsync.when(
                      loading: () => Container(
                        height: 220.0,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.cardRadius),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mainGreen,
                          ),
                        ),
                      ),
                      error: (_, _) => Container(
                        padding: const EdgeInsets.all(20.0),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius:
                              BorderRadius.circular(AppDimensions.cardRadius),
                        ),
                        child: const Center(
                          child: Text(
                            'خطأ في تحميل مصاريف الشهر',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ),
                      data: (categoryTotals) {
                        return MonthExpensesChartCard(
                          monthName: monthName,
                          categoryTotals: categoryTotals,
                          onTapCategory: (category) {
                            _openCategoryDetails(
                              category: category,
                              isMonthMode: true,
                            );
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16.0),

                    // 2. Day Selector Card: Previous Arrow (right), Day in Middle, Next Arrow (left)
                    Container(
                      height: 60.0,
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.cardRadius),
                        boxShadow: AppDimensions.cardShadow,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Right: Previous Day Arrow
                          InkWell(
                            onTap: canGoBack ? _goToPreviousDay : null,
                            borderRadius: BorderRadius.circular(10.0),
                            child: Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: canGoBack
                                    ? AppColors.lightGreen
                                    : const Color(0xFFF0ECE4),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 18.0,
                                color: canGoBack
                                    ? AppColors.darkGreen
                                    : const Color(0xFFC4BFB6),
                              ),
                            ),
                          ),

                          // Center: "<weekday> <day> <month>"
                          Text(
                            ArabicDateHelper.formatWeekdayDayMonth(_selectedDay),
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 16.0,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),

                          // Left: Next Day Arrow (faded and inactive when today)
                          InkWell(
                            onTap: canGoForward ? _goToNextDay : null,
                            borderRadius: BorderRadius.circular(10.0),
                            child: Container(
                              width: 40.0,
                              height: 40.0,
                              decoration: BoxDecoration(
                                color: canGoForward
                                    ? AppColors.lightGreen
                                    : const Color(0xFFF0ECE4),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 18.0,
                                color: canGoForward
                                    ? AppColors.darkGreen
                                    : const Color(0xFFC4BFB6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16.0),

                    // 3. Day's Expenses Grouped by Category
                    dayTotalsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.mainGreen,
                          ),
                        ),
                      ),
                      error: (_, _) => const Center(
                        child: Text(
                          'خطأ في تحميل مصاريف اليوم',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      data: (dayTotals) {
                        if (dayTotals.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: dayTotals.map((item) {
                            final int amountEgp = item.totalAmount ~/ 100;
                            final iconData = CategoryIconHelper.getIcon(
                              item.category.icon,
                            );

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12.0),
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.cardRadius,
                                ),
                                boxShadow: AppDimensions.cardShadow,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _openCategoryDetails(
                                      category: item.category,
                                      isMonthMode: false,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.cardRadius,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                      vertical: 14.0,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Right: Icon chip, Category Name, Count
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 44.0,
                                              height: 44.0,
                                              decoration: BoxDecoration(
                                                color: AppColors.lightGreen,
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              child: Icon(
                                                iconData,
                                                color: AppColors.mainGreen,
                                                size: 22.0,
                                              ),
                                            ),
                                            const SizedBox(width: 12.0),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  item.category.name,
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        AppTheme.fontFamily,
                                                    fontSize: 16.0,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.text,
                                                  ),
                                                ),
                                                const SizedBox(height: 2.0),
                                                Text(
                                                  ArabicDateHelper.formatCount(
                                                    item.transactionCount,
                                                  ),
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        AppTheme.fontFamily,
                                                    fontSize: 13.0,
                                                    fontWeight: FontWeight.w400,
                                                    color:
                                                        AppColors.secondaryText,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Left: Total amount and Small Arrow
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${NumberFormatter.formatCurrency(amountEgp)} جنيه',
                                              style: const TextStyle(
                                                fontFamily: AppTheme.fontFamily,
                                                fontSize: 16.0,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.text,
                                              ),
                                            ),
                                            const SizedBox(width: 6.0),
                                            const Icon(
                                              Icons.arrow_back_ios_new_rounded,
                                              size: 13.0,
                                              color: AppColors.text,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 24.0),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
