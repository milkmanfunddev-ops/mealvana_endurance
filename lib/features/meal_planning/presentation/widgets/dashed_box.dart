import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A rounded box drawn with a dashed outline — the prototype's `.v-dashed`:
/// used for empty states and the "add your own directions" prompt.
class DashedBox extends StatelessWidget {
  const DashedBox({
    super.key,
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(12),
    this.radius = 15,
  });

  final Widget child;

  /// Stroke colour; defaults to the theme foreground at 25% opacity.
  final Color? color;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fg = Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(
        color: color ?? fg.withValues(alpha: 0.25),
        radius: radius,
      ),
      child: Padding(
        padding: padding,
        child: Center(child: child),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const dash = 6.0;
    const gap = 4.0;

    // Rounded-rect path walked in dashes.
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + dash, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color || radius != oldDelegate.radius;
}
