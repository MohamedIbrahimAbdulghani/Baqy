import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/arabic_date_helper.dart';
import '../../../../core/utils/number_formatter.dart';
import '../controllers/budget_monitor_controller.dart';

class BudgetRing extends StatelessWidget {
  const BudgetRing({
    super.key,
    required this.remainingPiastres,
    required this.spentPiastres,
    required this.monthMoneyPiastres,
    this.savedPiastres = 0,
    this.year,
    this.month,
    required this.onTap,
    this.isReadOnly = false,
  });

  final int remainingPiastres;
  final int spentPiastres;
  final int monthMoneyPiastres;
  final int savedPiastres;
  final int? year;
  final int? month;
  final VoidCallback onTap;
  final bool isReadOnly;

  static String calculateRemainingDaysText({
    int? year,
    int? month,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final targetYear = year ?? current.year;
    final targetMonth = month ?? current.month;

    final currentYm = ArabicDateHelper.formatYearMonthKey(current.year, current.month);
    final targetYm = ArabicDateHelper.formatYearMonthKey(targetYear, targetMonth);

    if (targetYm.compareTo(currentYm) < 0) {
      return 'انتهى هذا الشهر';
    } else if (targetYm.compareTo(currentYm) > 0) {
      final daysInMonth = DateTime(targetYear, targetMonth + 1, 0).day;
      return 'يبدأ بعد ${NumberFormatter.formatCurrency(daysInMonth)} يوم';
    }

    final lastDay = DateTime(targetYear, targetMonth + 1, 0).day;
    final remainingDays = lastDay - current.day;

    if (remainingDays <= 0) {
      return 'اليوم هو آخر يوم في الشهر';
    } else if (remainingDays == 1) {
      return 'فاضل يوم على آخر الشهر';
    } else if (remainingDays == 2) {
      return 'فاضل يومين على آخر الشهر';
    } else if (remainingDays >= 3 && remainingDays <= 10) {
      return 'فاضل ${NumberFormatter.formatCurrency(remainingDays)} أيام على آخر الشهر';
    } else {
      return 'فاضل ${NumberFormatter.formatCurrency(remainingDays)} يوم على آخر الشهر';
    }
  }

  @override
  Widget build(BuildContext context) {
    final int remainingEgp = remainingPiastres ~/ 100;
    final int spentEgp = spentPiastres ~/ 100;
    final int monthMoneyEgp = monthMoneyPiastres ~/ 100;
    final int savedEgp = savedPiastres ~/ 100;

    final bool isOverBudget = remainingEgp < 0;

    // Remaining progress = remaining / total budget (0.0 to 1.0)
    // When nothing is spent, remaining == monthMoney -> progress = 1.0 (complete circle)
    // As expenses increase, remaining decreases -> ring decreases (empties)
    final double progress = monthMoneyPiastres > 0
        ? (remainingPiastres / monthMoneyPiastres).clamp(0.0, 1.0)
        : 0.0;

    // Dynamic color: turns warningRed if remaining <= 25% of total budget (or overbudget), reverts to defaultGreen otherwise
    final Color progressColor = BudgetMonitorController.getIndicatorColor(
      totalBudget: monthMoneyEgp.toDouble(),
      remainingAmount: remainingEgp.toDouble(),
    );

    final String remainingDaysText = calculateRemainingDaysText(
      year: year,
      month: month,
    );

    final String spentText = savedPiastres > 0
        ? '${NumberFormatter.formatCurrency(spentEgp)} جنيه (وحوّشت ${NumberFormatter.formatCurrency(savedEgp)})'
        : '${NumberFormatter.formatCurrency(spentEgp)} جنيه';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: AppColors.isDark ? 0.2 : 0.04),
                  blurRadius: 16.0,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: AppColors.isDark
                    ? AppColors.dividers
                    : AppColors.dividers.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Info Column (Right side in RTL)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "الميزانية"
                      Text(
                        'الميزانية',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 3.0),

                      // Budget Amount with edit / archive icon
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              monthMoneyEgp > 0
                                  ? '${NumberFormatter.formatCurrency(monthMoneyEgp)} جنيه'
                                  : 'غير محددة',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 21.0,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                                height: 1.2,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Icon(
                            isReadOnly ? Icons.archive_outlined : Icons.edit_outlined,
                            size: 15.0,
                            color: isReadOnly
                                ? Colors.amber.shade700
                                : AppColors.mainGreen.withValues(alpha: 0.75),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12.0),

                      // "صرفت"
                      Text(
                        'صرفت',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13.0,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 3.0),

                      // Spent Amount
                      Text(
                        spentText,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 21.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          height: 1.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12.0),

                      // Days remaining until end of month
                      Text(
                        remainingDaysText,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16.0),

                // Circular Progress Indicator (Left side in RTL)
                SizedBox(
                  width: 126.0,
                  height: 126.0,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(126.0, 126.0),
                        painter: _RingProgressPainter(
                          progress: progress,
                          progressColor: progressColor,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                isOverBudget
                                    ? '-${NumberFormatter.formatCurrency(remainingEgp.abs())}'
                                    : NumberFormatter.formatCurrency(remainingEgp),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 24.0,
                                  fontWeight: FontWeight.w700,
                                  color: progressColor,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Text(
                              isOverBudget ? 'تجاوز الميزانية' : 'جنيه متبقي',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.0,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingProgressPainter extends CustomPainter {
  const _RingProgressPainter({
    required this.progress,
    required this.progressColor,
  });

  final double progress;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 12.5;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    // Background grey/beige track
    final Paint trackPaint = Paint()
      ..color = AppColors.progressTrack
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc starting at 12 o'clock (-pi / 2) sweeping clockwise with dynamic color
    if (progress > 0.0) {
      final Paint progressPaint = Paint()
        ..color = progressColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (progress >= 1.0) {
        canvas.drawCircle(center, radius, progressPaint);
      } else {
        final Rect rect = Rect.fromCircle(center: center, radius: radius);
        final double sweepAngle = 2 * math.pi * progress;
        canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor;
  }
}
