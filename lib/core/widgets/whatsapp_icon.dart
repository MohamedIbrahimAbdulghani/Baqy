import 'package:flutter/material.dart';

/// Authentic WhatsApp vector icon drawn with CustomPainter.
class WhatsAppIcon extends StatelessWidget {
  const WhatsAppIcon({
    super.key,
    this.size = 20,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? const Color(0xFF25D366);
    return CustomPaint(
      size: Size(size, size),
      painter: _WhatsAppPainter(color: iconColor),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  const _WhatsAppPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // Chat bubble with tail
    final path = Path();
    final radius = w * 0.44;
    final center = Offset(w * 0.5, h * 0.46);

    path.addOval(Rect.fromCircle(center: center, radius: radius));

    // Tail on bottom-left
    final tailPath = Path()
      ..moveTo(w * 0.22, h * 0.72)
      ..lineTo(w * 0.12, h * 0.88)
      ..lineTo(w * 0.32, h * 0.84)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(tailPath, paint);

    // Inner phone receiver in white
    final phonePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Handset shape
    final phonePath = Path();
    phonePath.moveTo(w * 0.38, h * 0.32);
    phonePath.cubicTo(w * 0.36, h * 0.32, w * 0.33, h * 0.34, w * 0.32, h * 0.37);
    phonePath.cubicTo(w * 0.30, h * 0.42, w * 0.35, h * 0.52, w * 0.44, h * 0.61);
    phonePath.cubicTo(w * 0.53, h * 0.70, w * 0.63, h * 0.75, w * 0.68, h * 0.73);
    phonePath.cubicTo(w * 0.71, h * 0.72, w * 0.73, h * 0.69, w * 0.73, h * 0.67);
    phonePath.lineTo(w * 0.67, h * 0.60);
    phonePath.cubicTo(w * 0.65, h * 0.58, w * 0.62, h * 0.58, w * 0.60, h * 0.60);
    phonePath.lineTo(w * 0.57, h * 0.63);
    phonePath.cubicTo(w * 0.53, h * 0.60, w * 0.45, h * 0.52, w * 0.42, h * 0.48);
    phonePath.lineTo(w * 0.45, h * 0.45);
    phonePath.cubicTo(w * 0.47, h * 0.43, w * 0.47, h * 0.40, w * 0.45, h * 0.38);
    phonePath.close();

    canvas.drawPath(phonePath, phonePaint);
  }

  @override
  bool shouldRepaint(covariant _WhatsAppPainter oldDelegate) =>
      oldDelegate.color != color;
}
