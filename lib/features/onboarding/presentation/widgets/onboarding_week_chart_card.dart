import 'package:flutter/material.dart';
import '../theme/onboarding_design_tokens.dart';

/// "YOUR WEEK, FUELED" chart card on the connect-training step — pixel port
/// of the HTML spec's prototype card.
///
/// Spec values (computed styles from the rendered prototype): radius-18
/// container, transparent fill, 1px teal-30% border, padding 15/16, 22px
/// bottom margin; fontLabel 15px cream label; Apercu 11.5px cream-50%
/// caption; then the chart drawn in a 320:156 reference frame (bars,
/// teal carbs curve, S-M-T-W-T-F-S-S axis letters, centered legend), scaled
/// to the card's width.
///
/// The teal carbs curve draws itself in left-to-right on mount, matching the
/// prototype's entrance animation; bars/axis/legend are static.
class OnboardingWeekChartCard extends StatefulWidget {
  const OnboardingWeekChartCard({super.key});

  @override
  State<OnboardingWeekChartCard> createState() =>
      _OnboardingWeekChartCardState();
}

class _OnboardingWeekChartCardState extends State<OnboardingWeekChartCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();
  late final Animation<double> _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OnbTokens.teal30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR WEEK, FUELED',
            style: TextStyle(
              fontFamily: OnbTokens.fontLabel,
              fontSize: 15,
              color: OnbTokens.cream,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'carb rise on heavy days, protein relatively stable but goes up '
            'during recovery',
            style: TextStyle(
              fontFamily: OnbTokens.fontBody,
              fontSize: 11.5,
              color: OnbTokens.creamA(0.5),
            ),
          ),
          const SizedBox(height: 8),
          AspectRatio(
            aspectRatio: 320 / 156,
            child: CustomPaint(painter: _WeekChartPainter(_progress)),
          ),
        ],
      ),
    );
  }
}

/// Data-free week chart. All coordinates below are the spec's own values in
/// a 320x156 reference frame, scaled to the painted size. [progress] (0→1)
/// reveals the teal curve left-to-right; day dots pop in as the curve
/// reaches them.
class _WeekChartPainter extends CustomPainter {
  const _WeekChartPainter(this.progress) : super(repaint: progress);

  final Animation<double> progress;

  /// Reference frame the spec coordinates were measured in.
  static const double _refW = 320;
  static const double _refH = 156;

  /// rgba(178,86,58,.75) — training-load bar fill.
  static const Color _rust = Color(0xBFB2563A);

  /// Bar tops (y); every bar is 20 wide at x = 14 + 38*i, bottom y = 118.
  static const List<double> _barTops = [72, 68, 56, 60, 66, 54, 38, 84];

  static const List<String> _axisLetters = [
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _refW;
    final sy = size.height / _refH;

    // Training-load bars.
    final barPaint = Paint()..color = _rust;
    for (var i = 0; i < _barTops.length; i++) {
      final left = (14 + 38.0 * i) * sx;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, _barTops[i] * sy, left + 20 * sx, 118 * sy),
          Radius.circular(2 * sx),
        ),
        barPaint,
      );
    }

    // Teal carbs curve — spec path:
    // M24 88 C36.7 86.3 49.3 87.7 62 86 C74.7 84.3 87.3 79.7 100 78
    // C112.7 76.3 125.3 75.7 138 76 C150.7 76.3 163.3 80.3 176 80
    // C188.7 79.7 201.3 78 214 74 C226.7 70 239.3 55.3 252 56
    // C264.7 56.7 277.3 74.3 290 78
    final curve = Path()
      ..moveTo(24 * sx, 88 * sy)
      ..cubicTo(36.7 * sx, 86.3 * sy, 49.3 * sx, 87.7 * sy, 62 * sx, 86 * sy)
      ..cubicTo(74.7 * sx, 84.3 * sy, 87.3 * sx, 79.7 * sy, 100 * sx, 78 * sy)
      ..cubicTo(112.7 * sx, 76.3 * sy, 125.3 * sx, 75.7 * sy, 138 * sx, 76 * sy)
      ..cubicTo(150.7 * sx, 76.3 * sy, 163.3 * sx, 80.3 * sy, 176 * sx, 80 * sy)
      ..cubicTo(188.7 * sx, 79.7 * sy, 201.3 * sx, 78 * sy, 214 * sx, 74 * sy)
      ..cubicTo(226.7 * sx, 70 * sy, 239.3 * sx, 55.3 * sy, 252 * sx, 56 * sy)
      ..cubicTo(
        264.7 * sx,
        56.7 * sy,
        277.3 * sx,
        74.3 * sy,
        290 * sx,
        78 * sy,
      );
    // Draw-on reveal: extract the leading fraction of the curve's arc
    // length, so it traces in left-to-right like the prototype.
    final t = progress.value;
    final metric = curve.computeMetrics().first;
    final visible = metric.extractPath(0, metric.length * t);
    canvas.drawPath(
      visible,
      Paint()
        ..color = OnbTokens.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * sx
        ..strokeCap = StrokeCap.round,
    );

    // Teal day-point dots at the curve's day anchors, popping in as the
    // curve front passes each day column.
    const dayPoints = [
      Offset(24, 88),
      Offset(62, 86),
      Offset(100, 78),
      Offset(138, 76),
      Offset(176, 80),
      Offset(214, 74),
      Offset(252, 56),
      Offset(290, 78),
    ];
    final frontX = 24 + (290 - 24) * t;
    final dotPaint = Paint()..color = OnbTokens.teal;
    for (final p in dayPoints) {
      if (p.dx <= frontX + 0.5) {
        canvas.drawCircle(Offset(p.dx * sx, p.dy * sy), 3 * sx, dotPaint);
      }
    }

    // Axis letters, centered under each bar at y ~132.
    for (var i = 0; i < _axisLetters.length; i++) {
      final tp = _layoutText(_axisLetters[i], 10 * sx, OnbTokens.creamA(0.4));
      tp.paint(
        canvas,
        Offset(
          (14 + 38.0 * i + 10) * sx - tp.width / 2,
          132 * sy - tp.height / 2,
        ),
      );
    }

    _paintLegend(canvas, size, sx, sy);
  }

  /// Legend row under the axis: teal 6px dot + "Carbs (g)", 10x10 rx2 rust
  /// square + "Training load" — Apercu 10px cream-55%, centered.
  void _paintLegend(Canvas canvas, Size size, double sx, double sy) {
    final carbs = _layoutText('Carbs (g)', 10 * sx, OnbTokens.creamA(0.55));
    final load = _layoutText('Training load', 10 * sx, OnbTokens.creamA(0.55));
    final dot = 6 * sx;
    final square = 10 * sx;
    final markerGap = 5 * sx; // marker -> its label
    final groupGap = 14 * sx; // between the two legend groups
    final total =
        dot +
        markerGap +
        carbs.width +
        groupGap +
        square +
        markerGap +
        load.width;
    var x = (size.width - total) / 2;
    final cy = 146 * sy;

    canvas.drawCircle(
      Offset(x + dot / 2, cy),
      dot / 2,
      Paint()..color = OnbTokens.teal,
    );
    x += dot + markerGap;
    carbs.paint(canvas, Offset(x, cy - carbs.height / 2));
    x += carbs.width + groupGap;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, cy - square / 2, square, square),
        Radius.circular(2 * sx),
      ),
      Paint()..color = _rust,
    );
    x += square + markerGap;
    load.paint(canvas, Offset(x, cy - load.height / 2));
  }

  TextPainter _layoutText(String text, double fontSize, Color color) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: OnbTokens.fontBody,
          fontSize: fontSize,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant _WeekChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
