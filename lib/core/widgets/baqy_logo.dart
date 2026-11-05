import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Pixel-perfect vector implementation of Baqy Logo according to SVG spec:
/// 100x100 rounded square rx 28
/// 3 stacked coins at y = 60, 48, 36
/// Each coin:
///   path d="M28 Y v9 a22 8 0 0 0 44 0 v-9z" fill="#D9941F" stroke=outline stroke-width="2"
///   ellipse cx="50" cy="Y" rx="22" ry="8" fill="#F2BE5A" stroke=outline stroke-width="2"
class BaqyLogo extends StatelessWidget {
  const BaqyLogo({
    super.key,
    this.size = 100.0,
    this.isSplash = false,
  });

  final double size;
  final bool isSplash;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BaqyLogoPainter(isSplash: isSplash),
      ),
    );
  }
}

class _BaqyLogoPainter extends CustomPainter {
  const _BaqyLogoPainter({required this.isSplash});

  final bool isSplash;

  static const Color coinRimFill = Color(0xFFD9941F);
  static const Color coinTopFill = Color(0xFFF2BE5A);

  @override
  void paint(Canvas canvas, Size size) {
    // Scale canvas to match target size from 100x100 viewBox
    final double scale = size.width / 100.0;
    canvas.save();
    canvas.scale(scale, scale);

    final Color bgColor = isSplash ? AppColors.background : AppColors.darkGreen;
    final Color outlineColor = isSplash ? AppColors.background : AppColors.darkGreen;

    // 1. Draw rounded square (100x100, rx: 28)
    final RRect rrect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(0, 0, 100, 100),
      const Radius.circular(28),
    );
    final Paint bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    // Coin paints
    final Paint rimFillPaint = Paint()
      ..color = coinRimFill
      ..style = PaintingStyle.fill;

    final Paint rimStrokePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint topFillPaint = Paint()
      ..color = coinTopFill
      ..style = PaintingStyle.fill;

    final Paint topStrokePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // 3 stacked coins at y = 60, 48, 36
    const List<double> coinYs = [60.0, 48.0, 36.0];

    for (final double y in coinYs) {
      // Coin rim path: M28 Y v9 a22 8 0 0 0 44 0 v-9z
      final Path rimPath = Path()
        ..moveTo(28, y)
        ..lineTo(28, y + 9)
        ..arcToPoint(
          Offset(72, y + 9),
          radius: const Radius.elliptical(22, 8),
          clockwise: false,
        )
        ..lineTo(72, y)
        ..close();

      canvas.drawPath(rimPath, rimFillPaint);
      canvas.drawPath(rimPath, rimStrokePaint);

      // Coin top ellipse: cx=50, cy=y, rx=22, ry=8
      final Rect topRect = Rect.fromCenter(
        center: Offset(50, y),
        width: 44,
        height: 16,
      );

      canvas.drawOval(topRect, topFillPaint);
      canvas.drawOval(topRect, topStrokePaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BaqyLogoPainter oldDelegate) {
    return oldDelegate.isSplash != isSplash;
  }
}

