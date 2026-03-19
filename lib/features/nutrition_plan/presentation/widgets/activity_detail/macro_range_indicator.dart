import 'package:flutter/material.dart';

/// Visual range indicator showing where an actual value falls within a min-max range.
///
/// Renders a thin track spanning [min, max] with a diamond-shaped marker
/// at the value position. No left-fill — clearly a position indicator, not a progress bar.
class MacroRangeIndicator extends StatelessWidget {
  const MacroRangeIndicator({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.color,
    this.trackColor,
  });

  final int value;
  final int min;
  final int max;
  final Color color;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      child: CustomPaint(
        painter: _RangePositionPainter(
          value: value,
          min: min,
          max: max,
          markerColor: color,
          trackColor: trackColor ??
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.25),
        ),
        size: const Size(double.infinity, 12),
      ),
    );
  }
}

class _RangePositionPainter extends CustomPainter {
  _RangePositionPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.markerColor,
    required this.trackColor,
  });

  final int value;
  final int min;
  final int max;
  final Color markerColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final trackHeight = 2.0;
    final markerSize = 4.5;
    final centerY = size.height / 2;
    final padding = markerSize + 1;
    final trackLeft = padding;
    final trackRight = size.width - padding;
    final trackWidth = trackRight - trackLeft;

    // Draw track line
    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = trackHeight
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(trackLeft, centerY),
      Offset(trackRight, centerY),
      trackPaint,
    );

    // Draw small tick marks at min and max ends
    final tickPaint = Paint()
      ..color = trackColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(trackLeft, centerY - 3),
      Offset(trackLeft, centerY + 3),
      tickPaint,
    );
    canvas.drawLine(
      Offset(trackRight, centerY - 3),
      Offset(trackRight, centerY + 3),
      tickPaint,
    );

    // Calculate marker position
    final range = max - min;
    if (range <= 0) return;

    final fraction = ((value - min) / range).clamp(0.0, 1.0);
    final markerX = trackLeft + (trackWidth * fraction);

    // Draw diamond marker at value position
    final markerPaint = Paint()
      ..color = markerColor
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(markerX, centerY - markerSize)
      ..lineTo(markerX + markerSize, centerY)
      ..lineTo(markerX, centerY + markerSize)
      ..lineTo(markerX - markerSize, centerY)
      ..close();
    canvas.drawPath(path, markerPaint);
  }

  @override
  bool shouldRepaint(_RangePositionPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.markerColor != markerColor;
  }
}
