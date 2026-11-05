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
    // Sort columns by category ID (matching order in Screenshots 1 and 2: أكل, مواصلات, فواتير, صدقات)
    final sortedTotals = [...categoryTotals]
      ..sort((a, b) => a.category.id.compareTo(b.category.id));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppDimensions.cardRadius),
        boxShadow: AppDimensions.cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card Title: "مصاريف شهر <month>"
          Text(
            'مصاريف شهر $monthName',
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 18.0,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16.0),

          // Bar Chart or Empty Message
          if (sortedTotals.isEmpty)
            const SizedBox(
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
            SizedBox(
              height: 180.0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) {
                      final width = constraints.maxWidth;
                      final count = sortedTotals.length;
                      if (count == 0 || width <= 0) return;
                      final slotWidth = width / count;
                      // RTL: slot 0 is on the right
                      final tapX = details.localPosition.dx;
                      final rtlIndex = ((width - tapX) / slotWidth).floor();
                      if (rtlIndex >= 0 && rtlIndex < count) {
                        onTapCategory(sortedTotals[rtlIndex].category);
                      }
                    },
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, 180.0),
                      painter: _VerticalBarChartPainter(
                        categoryTotals: sortedTotals,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _VerticalBarChartPainter extends CustomPainter {
  _VerticalBarChartPainter({
    required this.categoryTotals,
  });

  final List<CategoryTotal> categoryTotals;

  @override
  void paint(Canvas canvas, Size size) {
    if (categoryTotals.isEmpty) return;

    final count = categoryTotals.length;
    final slotWidth = size.width / count;

    // Max amount in piastres (guaranteed > 0 if there are items)
    final maxAmount = categoryTotals.map((e) => e.totalAmount).reduce(max);

    // Vertical spacing
    const topPadding = 26.0; // Space for amount text + gap
    const bottomPadding = 28.0; // Space for category name text + gap
    final maxBarHeight = size.height - topPadding - bottomPadding;

    final barWidth = (slotWidth * 0.42).clamp(24.0, 34.0);

    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;

    for (var i = 0; i < count; i++) {
      final item = categoryTotals[i];
      final color = CategoryIconHelper.parseColor(item.category.color);
      paint.color = color;

      // In RTL, column 0 is on the far right
      final centerX = size.width - (i + 0.5) * slotWidth;

      // Bar height proportional to biggest category
      final double ratio = maxAmount > 0 ? (item.totalAmount / maxAmount) : 0.0;
      final double barHeight = max(ratio * maxBarHeight, barWidth * 0.5);

      final barBottom = size.height - bottomPadding;
      final barTop = barBottom - barHeight;

      // Draw rounded capsule bar
      final barRect = Rect.fromCenter(
        center: Offset(centerX, barTop + barHeight / 2),
        width: barWidth,
        height: barHeight,
      );
      final rrect = RRect.fromRectAndRadius(
        barRect,
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rrect, paint);

      // 1. Draw Amount Text above bar in category color
      final int amountEgp = item.totalAmount ~/ 100;
      final amountText = amountEgp.toArabicDigits();

      final amountPainter = TextPainter(
        text: TextSpan(
          text: amountText,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 14.0,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout();

      amountPainter.paint(
        canvas,
        Offset(
          centerX - amountPainter.width / 2,
          barTop - amountPainter.height - 4.0,
        ),
      );

      // 2. Draw Category Name Text below bar in category color
      final namePainter = TextPainter(
        text: TextSpan(
          text: item.category.name,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 13.0,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout();

      namePainter.paint(
        canvas,
        Offset(
          centerX - namePainter.width / 2,
          barBottom + 6.0,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalBarChartPainter oldDelegate) {
    if (oldDelegate.categoryTotals.length != categoryTotals.length) return true;
    for (var i = 0; i < categoryTotals.length; i++) {
      if (oldDelegate.categoryTotals[i].category.id != categoryTotals[i].category.id ||
          oldDelegate.categoryTotals[i].totalAmount != categoryTotals[i].totalAmount) {
        return true;
      }
    }
    return false;
  }
}
