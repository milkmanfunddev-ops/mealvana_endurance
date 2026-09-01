/// Meal icon glyphs — port of the prototype's `components/vana/meal-icons.tsx`.
///
/// One hand-drawn stroke glyph per [MealIcon], authored on a 24-unit grid with
/// a 2px round-capped stroke (same grid as the prototype's `icons.tsx`). The
/// SVG `d` strings are kept verbatim from the prototype so the two stay in
/// lockstep; the `<circle>`/`<ellipse>`/`<rect>` primitives it used for egg,
/// baked and snack are expressed here as equivalent arc paths so everything is
/// a single path-data form.
///
/// No `flutter_svg` — a tiny parser ([parseSvgPath]) turns each `d` string into
/// a [Path] once (cached) and [MealIconGlyph] strokes it scaled to `size`.
/// [MealIconTile] is the 36px circle tile used on meal rows (the meal-planning
/// analogue of `KyleFoodIcon`).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../meal_logging/domain/meal_slot.dart';
import '../../../meal_logging/presentation/widgets/slot_palette.dart';
import '../../domain/meal_icon.dart';
import '../../domain/meal_type.dart';

// ---------------------------------------------------------------------------
// Path data (24-unit grid)
// ---------------------------------------------------------------------------

/// SVG path data per icon — one string per `<path d>` of the prototype glyph.
///
/// Keep byte-for-byte with `meal-icons.tsx` (except the three primitives
/// converted to arcs, noted inline).
const Map<MealIcon, List<String>> mealIconPathData = {
  // bowl of rice: bowl + mound + steam
  MealIcon.bowl: [
    'M3 12h18a9 9 0 0 1-18 0z',
    'M6 12a6 3 0 0 1 12 0',
    'M9 4c0 1.5 1 1.5 1 3M13 4c0 1.5 1 1.5 1 3',
  ],
  // oats: bowl + spoon + grains
  MealIcon.oats: [
    'M3 12h18a9 9 0 0 1-18 0z',
    'M8 9l1-2M12 9l1-3M16 9l1-2',
    'M14 20l6-8',
  ],
  // drumstick
  MealIcon.chicken: [
    'M14.5 3.5a5 5 0 0 1 4 8l-6 6-4-4 6-6a5 5 0 0 1 0-4z',
    'M8.5 13.5l-3 3a2 2 0 1 0 2 2l3-3',
  ],
  // steak
  MealIcon.meat: [
    'M4 9c0-3 3-5 7-5 5 0 9 3 9 7s-4 8-9 8c-3 0-5-2-5-4s2-3 2-5S4 11 4 9z',
    'M11 8c2 0 4 1 4 3s-2 4-4 4',
  ],
  // fish
  MealIcon.fish: [
    'M3 12c3-5 7-7 12-7 2 0 4 3 4 7s-2 7-4 7c-5 0-9-2-12-7z',
    'M3 12l-1-4M3 12l-1 4M15 11h.01',
  ],
  // fried egg (prototype: <circle cx=12 cy=12 r=3> → two half-arcs)
  MealIcon.egg: [
    'M12 3c4 0 8 4 8 8 0 5-4 10-8 10S4 16 4 11c0-4 4-8 8-8z',
    'M9 12a3 3 0 1 0 6 0a3 3 0 1 0-6 0',
  ],
  // leaf / salad
  MealIcon.salad: [
    'M4 20c0-8 5-14 16-16-1 11-7 16-16 16z',
    'M4 20c4-4 7-7 11-11',
  ],
  // toast / bread slice
  MealIcon.bread: ['M6 10a4 4 0 0 1 0-6h12a4 4 0 0 1 0 6v10H6z', 'M9 14h6'],
  // wrap / burrito
  MealIcon.wrap: ['M6 8l10-4 4 4-10 12-4-4z', 'M6 8c2 1 3 3 4 4M13 5l-2 4'],
  // pasta / noodles: bowl + strands
  MealIcon.pasta: [
    'M3 13h18a9 9 0 0 1-18 0z',
    'M6 13c1-4 1-6 0-9M10 13c1-4 1-6 0-9M14 13c1-4 1-6 0-9M18 13c1-4 1-6 0-9',
  ],
  // soup: pot with handles + steam
  MealIcon.soup: [
    'M4 11h16v4a6 6 0 0 1-6 6h-4a6 6 0 0 1-6-6z',
    'M2 11h20M9 7c0-2 1-2 1-4M14 7c0-2 1-2 1-4',
  ],
  // pizza slice
  MealIcon.pizza: [
    'M3 4l18 8-8 9z',
    'M3 4c6 0 12 6 10 17',
    'M9 9h.01M11 13h.01M8 14h.01',
  ],
  // glass with straw
  MealIcon.drink: ['M6 4h12l-1.5 16h-9z', 'M7 9h10M14 4l3-2'],
  // apple
  MealIcon.fruit: [
    'M12 8c-4-3-8 0-8 5s3 8 5 8 2-1 3-1 1 1 3 1 5-3 5-8-4-8-8-5z',
    'M12 8c0-2 1-4 3-5',
  ],
  // nut / almond
  MealIcon.nuts: [
    'M12 3c4 0 7 5 7 10a7 7 0 0 1-14 0c0-5 3-10 7-10z',
    'M12 7c-2 3-2 6 0 10',
  ],
  // yogurt cup
  MealIcon.yogurt: ['M5 8h14l-1 12H6z', 'M4 8a8 3 0 0 1 16 0', 'M8 13h8'],
  // potato
  MealIcon.potato: [
    'M5 10c1-4 5-6 9-6s6 3 6 7-3 9-8 9-8-3-7-10z',
    'M9 10h.01M14 9h.01M12 14h.01M8 15h.01',
  ],
  // beans
  MealIcon.beans: [
    'M5 14a5 5 0 0 1 7-6c2 1 3 4 6 4a3 3 0 0 1 0 6c-4 0-4-3-7-3a5 5 0 0 1-6-1z',
    'M14 4c2 0 4 2 4 4',
  ],
  // tofu cube
  MealIcon.tofu: ['M4 9l8-4 8 4-8 4z', 'M4 9v7l8 4 8-4V9M12 13v7'],
  // pancake stack (prototype: <ellipse cx=12 cy=8 rx=8 ry=3> → two half-arcs)
  MealIcon.baked: [
    'M4 8a8 3 0 1 0 16 0a8 3 0 1 0-16 0',
    'M4 8v4c0 1.7 3.6 3 8 3s8-1.3 8-3V8',
    'M4 12v4c0 1.7 3.6 3 8 3s8-1.3 8-3v-4',
  ],
  // bar (prototype: <rect x=3 y=8 width=18 height=8 rx=3> → rounded rect path)
  MealIcon.snack: [
    'M6 8h12a3 3 0 0 1 3 3v2a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3v-2a3 3 0 0 1 3-3z',
    'M8 8v8M12 8v8M16 8v8',
  ],
  // cookie
  MealIcon.sweet: [
    'M12 3a9 9 0 1 0 9 9 4 4 0 0 1-4-4 4 4 0 0 1-5-5z',
    'M8 10h.01M9 15h.01M14 15h.01M12 12h.01',
  ],
  MealIcon.utensils: [
    'M5 3v7a3 3 0 0 0 6 0V3M8 3v18M17 3c-2 2-2 6-2 9h4v9M19 3v9',
  ],
};

/// Size of the authoring grid the path data is drawn on.
const double mealIconGridSize = 24;

/// Stroke width on the 24-unit grid (matches the prototype's `icons.tsx`).
const double mealIconGridStroke = 2;

final Map<MealIcon, Path> _pathCache = {};

/// The combined, cached [Path] for [icon] in 24-unit grid coordinates.
Path mealIconPath(MealIcon icon) => _pathCache.putIfAbsent(icon, () {
  final path = Path();
  for (final d in mealIconPathData[icon]!) {
    path.addPath(parseSvgPath(d), Offset.zero);
  }
  return path;
});

// ---------------------------------------------------------------------------
// SVG path-data parser
// ---------------------------------------------------------------------------

/// Parses an SVG path `d` string into a [Path].
///
/// Supports the commands the glyph set uses plus the obvious neighbours:
/// `M/m L/l H/h V/v C/c S/s Q/q T/t A/a Z/z`, with implicit command repetition
/// (`l1 2 3 4`) and the `M` → `L` implicit-lineto rule. Arc flags are read as
/// single digits so `a9 9 0 0 1-18 0` tokenises correctly.
///
/// Throws [FormatException] on an unknown command letter or malformed number.
Path parseSvgPath(String d) => _SvgPathParser(d).parse();

class _SvgPathParser {
  _SvgPathParser(this._d);

  final String _d;
  int _i = 0;

  final Path _path = Path();
  double _x = 0, _y = 0; // current point
  double _sx = 0, _sy = 0; // subpath start
  double? _cx, _cy; // last cubic control point (for S/s)
  double? _qx, _qy; // last quadratic control point (for T/t)
  String? _lastCmd;

  Path parse() {
    _skipSeparators();
    while (_i < _d.length) {
      final c = _d[_i];
      if (_isCommand(c)) {
        _i++;
        _run(c);
      } else if (_lastCmd != null && (_isNumberStart(c))) {
        // Implicit repeat of the previous command; M/m repeats as L/l.
        final repeat = switch (_lastCmd) {
          'M' => 'L',
          'm' => 'l',
          // Z takes no operands, so a number after it can never be consumed.
          'Z' ||
          'z' => throw FormatException('Operands after Z at $_i in "$_d"'),
          final other => other!,
        };
        _run(repeat);
      } else {
        throw FormatException('Unexpected "$c" at $_i in "$_d"');
      }
      _skipSeparators();
    }
    return _path;
  }

  void _run(String cmd) {
    _lastCmd = cmd;
    final rel = cmd.toLowerCase() == cmd;
    switch (cmd.toUpperCase()) {
      case 'M':
        final x = _num(), y = _num();
        _x = rel ? _x + x : x;
        _y = rel ? _y + y : y;
        _sx = _x;
        _sy = _y;
        _path.moveTo(_x, _y);
        _resetControls();
      case 'L':
        final x = _num(), y = _num();
        _lineTo(rel ? _x + x : x, rel ? _y + y : y);
      case 'H':
        final x = _num();
        _lineTo(rel ? _x + x : x, _y);
      case 'V':
        final y = _num();
        _lineTo(_x, rel ? _y + y : y);
      case 'C':
        final x1 = _num(), y1 = _num(), x2 = _num(), y2 = _num();
        final x = _num(), y = _num();
        _cubicTo(
          rel ? _x + x1 : x1,
          rel ? _y + y1 : y1,
          rel ? _x + x2 : x2,
          rel ? _y + y2 : y2,
          rel ? _x + x : x,
          rel ? _y + y : y,
        );
      case 'S':
        final x2 = _num(), y2 = _num(), x = _num(), y = _num();
        // Reflect the previous cubic control point; fall back to the current
        // point when the previous command was not a cubic.
        final x1 = _cx == null ? _x : 2 * _x - _cx!;
        final y1 = _cy == null ? _y : 2 * _y - _cy!;
        _cubicTo(
          x1,
          y1,
          rel ? _x + x2 : x2,
          rel ? _y + y2 : y2,
          rel ? _x + x : x,
          rel ? _y + y : y,
        );
      case 'Q':
        final x1 = _num(), y1 = _num(), x = _num(), y = _num();
        _quadTo(
          rel ? _x + x1 : x1,
          rel ? _y + y1 : y1,
          rel ? _x + x : x,
          rel ? _y + y : y,
        );
      case 'T':
        final x = _num(), y = _num();
        final x1 = _qx == null ? _x : 2 * _x - _qx!;
        final y1 = _qy == null ? _y : 2 * _y - _qy!;
        _quadTo(x1, y1, rel ? _x + x : x, rel ? _y + y : y);
      case 'A':
        final rx = _num(), ry = _num(), rot = _num();
        final large = _flag(), sweep = _flag();
        final x = _num(), y = _num();
        final ex = rel ? _x + x : x, ey = rel ? _y + y : y;
        _path.arcToPoint(
          Offset(ex, ey),
          radius: Radius.elliptical(rx.abs(), ry.abs()),
          rotation: rot,
          largeArc: large,
          clockwise: sweep,
        );
        _x = ex;
        _y = ey;
        _resetControls();
      case 'Z':
        _path.close();
        _x = _sx;
        _y = _sy;
        _resetControls();
      default:
        throw FormatException('Unsupported path command "$cmd" in "$_d"');
    }
  }

  void _lineTo(double x, double y) {
    _path.lineTo(x, y);
    _x = x;
    _y = y;
    _resetControls();
  }

  void _cubicTo(
    double x1,
    double y1,
    double x2,
    double y2,
    double x,
    double y,
  ) {
    _path.cubicTo(x1, y1, x2, y2, x, y);
    _x = x;
    _y = y;
    _cx = x2;
    _cy = y2;
    _qx = _qy = null;
  }

  void _quadTo(double x1, double y1, double x, double y) {
    _path.quadraticBezierTo(x1, y1, x, y);
    _x = x;
    _y = y;
    _qx = x1;
    _qy = y1;
    _cx = _cy = null;
  }

  void _resetControls() {
    _cx = _cy = null;
    _qx = _qy = null;
  }

  // -- tokenising ----------------------------------------------------------

  static bool _isCommand(String c) => 'MmLlHhVvCcSsQqTtAaZz'.contains(c);

  static bool _isNumberStart(String c) =>
      c == '-' || c == '+' || c == '.' || (c.codeUnitAt(0) ^ 0x30) <= 9;

  void _skipSeparators() {
    while (_i < _d.length) {
      final c = _d[_i];
      if (c == ' ' || c == ',' || c == '\n' || c == '\t' || c == '\r') {
        _i++;
      } else {
        break;
      }
    }
  }

  /// Reads a single-digit arc flag (`0`/`1`).
  bool _flag() {
    _skipSeparators();
    if (_i >= _d.length) {
      throw FormatException('Expected arc flag at end of "$_d"');
    }
    final c = _d[_i++];
    if (c == '0') return false;
    if (c == '1') return true;
    throw FormatException('Bad arc flag "$c" at ${_i - 1} in "$_d"');
  }

  double _num() {
    _skipSeparators();
    final start = _i;
    if (_i < _d.length && (_d[_i] == '-' || _d[_i] == '+')) _i++;
    var sawDigit = false, sawDot = false;
    while (_i < _d.length) {
      final c = _d[_i];
      if ((c.codeUnitAt(0) ^ 0x30) <= 9) {
        sawDigit = true;
        _i++;
      } else if (c == '.' && !sawDot) {
        sawDot = true;
        _i++;
      } else {
        break;
      }
    }
    // Optional exponent.
    if (_i < _d.length && (_d[_i] == 'e' || _d[_i] == 'E')) {
      var j = _i + 1;
      if (j < _d.length && (_d[j] == '-' || _d[j] == '+')) j++;
      if (j < _d.length && (_d[j].codeUnitAt(0) ^ 0x30) <= 9) {
        _i = j;
        while (_i < _d.length && (_d[_i].codeUnitAt(0) ^ 0x30) <= 9) {
          _i++;
        }
      }
    }
    if (!sawDigit) {
      throw FormatException('Expected number at $start in "$_d"');
    }
    return double.parse(_d.substring(start, _i));
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// A single stroked meal glyph, scaled from the 24-unit grid to [size].
///
/// [strokeWidth] is in grid units (the prototype uses 2 standalone and 1.8
/// inside the tile) and scales with [size].
class MealIconGlyph extends StatelessWidget {
  const MealIconGlyph({
    super.key,
    required this.icon,
    this.size = mealIconGridSize,
    this.color,
    this.strokeWidth = mealIconGridStroke,
    this.semanticLabel,
  });

  final MealIcon icon;
  final double size;

  /// Stroke colour; defaults to the ambient [IconTheme] colour.
  final Color? color;

  /// Stroke width in 24-grid units.
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved =
        color ?? IconTheme.of(context).color ?? AppColors.electrolyte;
    return Semantics(
      label: semanticLabel,
      image: semanticLabel != null,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: MealIconGlyphPainter(
            icon: icon,
            color: resolved,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

/// Strokes [mealIconPath] for [icon] scaled to the canvas size.
class MealIconGlyphPainter extends CustomPainter {
  const MealIconGlyphPainter({
    required this.icon,
    required this.color,
    this.strokeWidth = mealIconGridStroke,
  });

  final MealIcon icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / mealIconGridSize;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    canvas.save();
    // Centre the 24-grid inside a non-square canvas.
    canvas.translate(
      (size.width - mealIconGridSize * scale) / 2,
      (size.height - mealIconGridSize * scale) / 2,
    );
    canvas.scale(scale);
    canvas.drawPath(mealIconPath(icon), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(MealIconGlyphPainter old) =>
      old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}

/// Visual treatment of a [MealIconTile].
enum MealIconTone {
  /// Filled circle in the accent colour with a contrasting glyph.
  solid,

  /// 18% tint of the accent colour with the glyph in the accent colour — the
  /// translucent variant used on dark cards.
  soft,
}

/// Accent colour for a [MealType] — shares the Nutrition Diary slot palette
/// so a "dinner" tile is the same colour on the plan and in the diary.
Color mealTypeColor(MealType type) =>
    slotColor(MealSlot.values.firstWhere((s) => s.wireValue == type.wire));

/// 36px circular meal tile (port of the prototype's `MealIcon`; the
/// meal-planning analogue of `KyleFoodIcon`).
///
/// Colour resolution: explicit [color] > [mealType]'s slot colour > brand
/// electrolyte. In [MealIconTone.solid] the glyph colour is [glyphColor] if
/// given, otherwise picked for contrast — blackberry on light accents
/// (electrolyte/yolk, as the prototype and `KyleFoodIcon` do) and cream on
/// dark ones (dragonfruit, violet, blackberry).
class MealIconTile extends StatelessWidget {
  const MealIconTile({
    super.key,
    required this.icon,
    this.size = 36,
    this.tone = MealIconTone.soft,
    this.color,
    this.mealType,
    this.glyphColor,
    this.semanticLabel,
  });

  final MealIcon icon;
  final double size;
  final MealIconTone tone;

  /// Explicit accent colour; wins over [mealType].
  final Color? color;

  /// Slot whose palette colour to use when [color] is null.
  final MealType? mealType;

  /// Explicit glyph colour (overrides the tone's default).
  final Color? glyphColor;
  final String? semanticLabel;

  /// Soft-tone background alpha.
  static const double softTintAlpha = 0.18;

  /// Glyph size relative to the tile, as in the prototype.
  static const double glyphRatio = 0.55;

  /// Stroke width (grid units) inside the tile, as in the prototype.
  static const double tileStroke = 1.8;

  Color get _accent =>
      color ??
      (mealType != null ? mealTypeColor(mealType!) : AppColors.electrolyte);

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final solid = tone == MealIconTone.solid;
    final background = solid ? accent : accent.withValues(alpha: softTintAlpha);
    final glyph =
        glyphColor ?? (solid ? _contrastingGlyphColor(accent) : accent);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: MealIconGlyph(
        icon: icon,
        size: size * glyphRatio,
        color: glyph,
        strokeWidth: tileStroke,
        semanticLabel: semanticLabel,
      ),
    );
  }

  static Color _contrastingGlyphColor(Color accent) =>
      accent.computeLuminance() > 0.4 ? AppColors.blackberry : AppColors.cream;
}
