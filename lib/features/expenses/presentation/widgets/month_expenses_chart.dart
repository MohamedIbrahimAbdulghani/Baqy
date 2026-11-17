import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/category_icon_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../domain/models/category_item.dart';
import '../../domain/models/category_total.dart';

class MonthExpensesChartCard extends StatelessWidget {
  const MonthExpensesChartCard({
    super.key,
    required this.monthName,
    required this.categoryTotals,
    required this.onTapCategory,
  });

  final String monthName;
  final List<CategoryTotal> categoryTotals;
  final void Function(CategoryItem category) onTapCategory;

  @override
  Widget build(BuildContext context) {
    final totalSum =
        categoryTotals.fold<int>(0, (sum, e) => sum + e.totalAmount);

    final List<CategoryTotal> displayTotals = [];
    int otherSum = 0;
    int otherCount = 0;

    for (final item in categoryTotals) {
      final double ratio = totalSum > 0 ? (item.totalAmount / totalSum) : 0.0;
      // Group categories that are very small (< 4% of total) under 'أخرى' when there are > 5 categories
      // "تحويش" is a virtual category that is never grouped under 'أخرى'
      if (categoryTotals.length > 5 &&
          ratio < 0.04 &&
          item.category.name != 'أخرى' &&
          item.category.name != 'تحويش' &&
          item.category.id >= 0) {
        otherSum += item.totalAmount;
        otherCount += item.transactionCount;
      } else {
        displayTotals.add(item);
      }
    }

    if (otherSum > 0) {
      final existingOtherIndex =
          displayTotals.indexWhere((e) => e.category.name == 'أخرى');
      if (existingOtherIndex >= 0) {
        final existing = displayTotals[existingOtherIndex];
        displayTotals[existingOtherIndex] = CategoryTotal(
          category: existing.category,
          totalAmount: existing.totalAmount + otherSum,
          transactionCount: existing.transactionCount + otherCount,
        );
      } else {
        displayTotals.add(
          CategoryTotal(
            category: const CategoryItem(
              id: 999999,
              name: 'أخرى',
              icon: 'other',
              color: '#9A9488',
            ),
            totalAmount: otherSum,
            transactionCount: otherCount,
          ),
        );
      }
    }

    final sortedTotals = [...displayTotals]
      ..sort((a, b) => a.category.id.compareTo(b.category.id));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: AppDimensions.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card Title: "مصاريف شهر <month>"
          Text(
            'مصاريف شهر $monthName',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 18.0,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16.0),

          // Bar Chart with Icons & Grid or Empty Message
          if (sortedTotals.isEmpty)
            SizedBox(
              height: 150.0,
              child: Center(
                child: Text(
                  'لا توجد مصاريف لهذا الشهر',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14.0,
                    fontWeight: FontWeight.w500,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final count = sortedTotals.length;
                final maxAmount =
                    sortedTotals.map((e) => e.totalAmount).reduce(max);
                final slotWidth = constraints.maxWidth / count;
                final barWidth = (slotWidth * 0.38).clamp(16.0, 32.0);
                final circleSize = count > 5 ? 30.0 : 34.0;
                final iconSize = count > 5 ? 15.0 : 17.0;
                final amountFontSize =
                    count > 5 ? 11.0 : (count > 4 ? 12.0 : 13.5);
                final nameFontSize =
                    count > 5 ? 9.5 : (count > 4 ? 10.5 : 12.0);

                const barAreaHeight = 105.0;

                return Stack(
                  children: [
                    // 1. Background Grid Lines & Baseline
                    Positioned(
                      top: 26.0, // After amount text (22) + gap (4)
                      left: 0,
                      right: 0,
                      height: barAreaHeight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            height: 1.0,
                            color: AppColors.dividers.withValues(alpha: 0.5),
                          ),
                          Container(
                            height: 1.0,
                            color: AppColors.dividers.withValues(alpha: 0.5),
                          ),
                          Container(
                            height: 1.0,
                            color: AppColors.dividers.withValues(alpha: 0.5),
                          ),
                          // Solid horizontal baseline line
                          Container(
                            height: 1.5,
                            color: AppColors.dividers,
                          ),
                        ],
                      ),
                    ),

                    // 2. Interactive Category Columns
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sortedTotals.map((item) {
                        final color = CategoryIconHelper.parseColor(
                            item.category.color);
                        final double ratio = maxAmount > 0
                            ? (item.totalAmount / maxAmount)
                            : 0.0;
                        final double barHeight = max(
                            ratio * barAreaHeight, 6.0);
                        final int amountEgp = item.totalAmount ~/ 100;
                        final amountText = amountEgp.toArabicDigits();

                        // Multi-line word splitting for longer labels
                        String formattedName = item.category.name;
                        if (count >= 4 && formattedName.contains(' ')) {
                          formattedName =
                              formattedName.replaceFirst(' ', '\n');
                        }

                        return Expanded(
                          child: InkWell(
                            onTap: () => onTapCategory(item.category),
                            borderRadius: BorderRadius.circular(10.0),
                            splashColor: color.withValues(alpha: 0.1),
                            highlightColor: color.withValues(alpha: 0.05),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Amount text above bar
                                  SizedBox(
                                    height: 22.0,
                                    child: Center(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          amountText,
                                          style: TextStyle(
                                            fontFamily: AppTheme.fontFamily,
                                            fontSize: amountFontSize,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),

                                  // Bar area pinned to bottom baseline
                                  SizedBox(
                                    height: barAreaHeight,
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        width: barWidth,
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: color,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(6.0),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Connector notch from baseline to icon circle
                                  Container(
                                    width: 1.5,
                                    height: 6.0,
                                    color: AppColors.dividers,
                                  ),

                                  // Circular Icon Badge
                                  Container(
                                    width: circleSize,
                                    height: circleSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.subtleBox,
                                      border: Border.all(
                                        color: color.withValues(alpha: 0.35),
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x0A000000),
                                          blurRadius: 3,
                                          offset: Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Icon(
                                        CategoryIconHelper.getIcon(
                                            item.category.icon),
                                        size: iconSize,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4.0),

                                  // Category Name Label below icon
                                  SizedBox(
                                    height: 30.0,
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Text(
                                        formattedName,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: AppTheme.fontFamily,
                                          fontSize: nameFontSize,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text,
                                          height: 1.15,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
