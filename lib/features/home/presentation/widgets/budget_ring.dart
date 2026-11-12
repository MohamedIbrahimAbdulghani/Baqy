import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/number_formatter.dart';

class BudgetRing extends StatelessWidget {
  const BudgetRing({
    super.key,
    required this.remainingPiastres,
    required this.spentPiastres,
    required this.monthMoneyPiastres,
    this.savedPiastres = 0,
    required this.onTap,
  });

  final int remainingPiastres;
  final int spentPiastres;
  final int monthMoneyPiastres;
  final int savedPiastres;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final int remainingEgp = remainingPiastres ~/ 100;
    final int spentEgp = spentPiastres ~/ 100;
    final int monthMoneyEgp = monthMoneyPiastres ~/ 100;
    final int savedEgp = savedPiastres ~/ 100;

    final String spentSummaryText = savedPiastres > 0
        ? 'صرفت ${NumberFormatter.formatCurrency(spentEgp)} وحوّشت ${NumberFormatter.formatCurrency(savedEgp)} من ${NumberFormatter.formatCurrency(monthMoneyEgp)}'
        : 'صرفت ${NumberFormatter.formatCurrency(spentEgp)} من ${NumberFormatter.formatCurrency(monthMoneyEgp)}';

    // Ring progress = remaining / month money (limited between 0 and 1)
    final double progress = monthMoneyPiastres > 0
        ? (remainingPiastres / monthMoneyPiastres).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: SizedBox(
          width: 250.0,
          height: 250.0,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(250.0, 250.0),
                painter: _RingProgressPainter(progress: progress),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Remaining amount (e.g. "٩,٠٠٠ جنيه")
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${NumberFormatter.formatCurrency(remainingEgp)} جنيه',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 34.0,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4.0),

                    // "الباقي لك الشهر ده"
                    const Text(
                      'الباقي لك الشهر ده',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14.0,
                        fontWeight: FontWeight.w400,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6.0),

                    // "صرفت X من Y" followed by small pencil icon
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            spentSummaryText,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13.0,
                              fontWeight: FontWeight.w400,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(width: 4.0),
                          const Icon(
                            Icons.edit_outlined,
                            size: 14.0,
                            color: AppColors.mainGreen,
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
    );
  }
}

class _RingProgressPainter extends CustomPainter {
  const _RingProgressPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double strokeWidth = 16.0;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    // Background grey/beige track
    final Paint trackPaint = Paint()
      ..color = AppColors.progressTrack
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, trackPaint);

    // Green progress arc starting at 12 o'clock (-pi / 2) sweeping clockwise
    if (progress > 0.0) {
      final Paint progressPaint = Paint()
        ..color = AppColors.mainGreen
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final Rect rect = Rect.fromCircle(center: center, radius: radius);
      final double sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
