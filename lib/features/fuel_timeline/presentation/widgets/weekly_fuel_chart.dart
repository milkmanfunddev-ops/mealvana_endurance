import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../daily_macros/domain/daily_macro_targets.dart';
import '../../../daily_macros/presentation/widgets/macro_palette.dart';
import '../fuel_timeline_type.dart';

/// The "Weekly Overview" periodization chart in the Energy Breakdown sheet —
/// four smoothed lines (Calories / Carbs / Protein / Fat) across the week.
///
/// Each series is normalised to its own max over the week so all four stay
/// visible despite their different units (kcal vs grams); the point is the
/// *shape* — carbs ramping toward a long effort while protein/fat hold steady.
class WeeklyFuelChart extends StatelessWidget {
  const WeeklyFuelChart({super.key, required this.week});

  /// 7 entries, Sunday→Saturday; null where a day hasn't been calculated.
  final List<DailyMacroTargets?> week;

  static const _dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final series = <_Series>[
      _Series('Cal', onSurface, [for (final d in week) d?.totalCalories]),
      _Series('Carbs', kMacroColorCarbs, [for (final d in week) d?.carbG]),
      _Series('Protein', kMacroColorProtein, [for (final d in week) d?.protG]),
      _Series('Fat', kMacroColorFat, [for (final d in week) d?.fatG]),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 300 / 170,
            child: CustomPaint(
              painter: _ChartPainter(
                series: series,
                gridColor: onSurface.withValues(alpha: 0.08),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final label in _dayLabels)
                Text(
                  label,
                  style: FtType.macroLine.copyWith(
                    color: onSurface.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 8,
            children: [for (final s in series) _legend(s, onSurface)],
          ),
        ],
      ),
    );
  }

  Widget _legend(_Series s, Color onSurface) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: s.color),
        ),
        const SizedBox(width: 6),
        Text(
          s.label,
          style: FtType.macroLine.copyWith(
            color: onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _Series {
  _Series(this.label, this.color, this.values);
  final String label;
  final Color color;
  final List<double?> values;

  double get _max {
    var m = 0.0;
    for (final v in values) {
      if (v != null && v > m) m = v;
    }
    return m;
  }

  /// Normalised 0..1 points (null preserved as gaps).
  List<double?> get normalised {
    final max = _max;
    if (max <= 0) return List<double?>.filled(values.length, null);
    return [
      for (final v in values) v == null ? null : (v / max).clamp(0.0, 1.0),
    ];
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.series, required this.gridColor});

  final List<_Series> series;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final p in [0.25, 0.5, 0.75]) {
      final y = size.height * p;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final s in series) {
      final norm = s.normalised;
      final pts = <Offset>[];
      for (var i = 0; i < norm.length; i++) {
        final v = norm[i];
        if (v == null) continue;
        final x = norm.length == 1
            ? size.width / 2
            : (i / (norm.length - 1)) * size.width;
        final y = size.height - v * size.height;
        pts.add(Offset(x, y));
      }
      if (pts.isEmpty) continue;

      final line = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        final prev = pts[i - 1];
        final cur = pts[i];
        final midX = (prev.dx + cur.dx) / 2;
        path.cubicTo(midX, prev.dy, midX, cur.dy, cur.dx, cur.dy);
      }
      canvas.drawPath(path, line);

      final dot = Paint()..color = s.color;
      for (final p in pts) {
        canvas.drawCircle(p, 2.6, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.series != series;
}
