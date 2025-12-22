import 'dart:math' show cos, sin;
import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Geometric Pattern Painter for Hero Section
/// Draws a decorative geometric star/polygon pattern
class GeometricPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blackberry.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw geometric star/polygon pattern similar to Kyle's design
    final center = Offset(size.width / 2, size.height / 2);
    final radius = 120.0;

    // Draw multiple polygons at different sizes
    for (int i = 0; i < 3; i++) {
      final currentRadius = radius + (i * 30);
      final path = Path();
      const sides = 12; // 12-sided polygon for star effect

      for (int j = 0; j <= sides; j++) {
        final angle = (j * 2 * 3.14159) / sides;
        final x = center.dx + currentRadius * cos(angle);
        final y = center.dy + currentRadius * sin(angle);

        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, paint);
    }

    // Draw connecting lines for star effect
    paint.color = AppColors.electrolyte.withValues(alpha: 0.15);
    for (int i = 0; i < 12; i++) {
      final angle = (i * 2 * 3.14159) / 12;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawLine(center, Offset(x, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
