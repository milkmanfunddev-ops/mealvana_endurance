import 'package:flutter/material.dart';

/// Design SSOT material — **dotted rounded-rect border** (the planned
/// card's "not yet" edge).
///
/// Spec: `docs/ssot/spec/design/components/workout-card.md` (planned skin)
/// and `docs/ssot/spec/design/surfaces/integrations-data-display.md` D-1b
/// (RATIFIED Xuan 2026-09-11): a BRICK at creation renders the same dashed
/// outline as every planned card — solid only on self-reported/verified
/// completion. Extracted from workout_card.dart per the data-integrations
/// handoff's component-reuse rule (it was private there, which is exactly
/// how the brick tile ended up drawing its own always-solid border — the
/// D-1b divergence).
class DottedBorderDecoration extends Decoration {
  const DottedBorderDecoration({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DottedBorderPainter(this);
}

class _DottedBorderPainter extends BoxPainter {
  _DottedBorderPainter(this.decoration);

  final DottedBorderDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & (configuration.size ?? Size.zero);
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(decoration.strokeWidth / 2),
      Radius.circular(decoration.radius),
    );
    final paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = decoration.strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path()..addRRect(rrect);
    const dash = 2.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }
}
