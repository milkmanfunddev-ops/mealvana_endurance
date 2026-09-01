/// Stroke glyphs used by the pre-workout fueling components — the reference
/// rendering's SVG paths, verbatim (`spec/design/renderings/pre-workout@v2.html`,
/// ratified Xuan 2026-08-26). Rendered through `flutter_svg` so the port keeps
/// the exact path geometry, stroke widths and caps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// The four food-row icon paths (`ICONS` in the rendering).
abstract final class FuelingGlyphPaths {
  static const String drop =
      'M12 3c3.2 4.2 5 7.2 5 9.7a5 5 0 0 1-10 0C7 10.2 8.8 7.2 12 3z';
  static const String bowl =
      'M4 12h16a8 8 0 0 1-16 0z M8 12V9 M12 12V8 M16 12V9';
  static const String bar =
      'M7 5h10l2 3v10a1 1 0 0 1-1 1H6a1 1 0 0 1-1-1V8l2-3z M5 8h14';
  static const String chew =
      'M12 4a8 8 0 1 1 0 16 8 8 0 0 1 0-16z M8.5 12h7 M12 8.5v7';

  /// The card / check chevron (`M6 9l6 6 6-6`).
  static const String chevron = 'M6 9l6 6 6-6';
}

/// A 24-unit stroke glyph at [size] px: `fill:none`, round caps and joins.
class FuelingGlyph extends StatelessWidget {
  const FuelingGlyph({
    super.key,
    required this.path,
    required this.size,
    required this.color,
    required this.strokeWidth,
  });

  final String path;
  final double size;
  final Color color;
  final double strokeWidth;

  static String _rgb(Color c) =>
      'rgb(${(c.r * 255).round()},${(c.g * 255).round()},${(c.b * 255).round()})';

  @override
  Widget build(BuildContext context) {
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" width="$size" height="$size" '
        'viewBox="0 0 24 24" fill="none" stroke="${_rgb(color)}" '
        'stroke-opacity="${color.a}" stroke-width="$strokeWidth" '
        'stroke-linecap="round" stroke-linejoin="round">'
        '<path d="$path"/></svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// The rendering's chevron: rotates from pointing right (collapsed, −90°) to
/// pointing down (expanded, 0°) over 220 ms.
class FuelingChevron extends StatelessWidget {
  const FuelingChevron({
    super.key,
    required this.expanded,
    required this.size,
    required this.color,
    required this.strokeWidth,
  });

  final bool expanded;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: expanded ? 0 : -0.25,
      duration: const Duration(milliseconds: 220),
      child: FuelingGlyph(
        path: FuelingGlyphPaths.chevron,
        size: size,
        color: color,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

/// Cream at an opacity — the rendering's `rgba(248,246,235,.x)`.
Color creamAlpha(double a) => AppColors.cream.withValues(alpha: a);

/// Orange at an opacity — `rgba(247,139,20,.x)`.
Color orangeAlpha(double a) => AppColors.orange.withValues(alpha: a);

/// Electrolyte at an opacity — `rgba(28,249,207,.x)`.
Color electrolyteAlpha(double a) => AppColors.electrolyte.withValues(alpha: a);

/// The raised card fill — `rgb(74,33,67)` (`AppColors.blackberryLight`).
const Color fuelingCardFill = AppColors.blackberryLight;

/// The rendering's **Compadre** slots (food names, the hydration-check title
/// and question) rendered in **Sansita 700** at the rendering's size.
///
/// DISCREPANCY, RAISED (qa intake
/// `2026-08-26-compadre-demo-cut-cannot-render-design-lowercase.md`): the
/// app ships a 66-glyph *demo* cut of Compadre whose lowercase codepoints
/// carry full-cap outlines and which has no `(` / `)` glyphs, so "Oatmeal
/// with banana" renders as spaced capitals and "Water (cups)" shows tofu
/// boxes. The side-by-side cannot be made to match with that file; until the
/// licensed face lands (or the fallback is ratified) this follows the
/// existing in-app precedent for these slots (the retired BEFORE widget's
/// Sansita substitution). Sizes, colours and line heights stay the
/// rendering's.
TextStyle fuelingDisplayStyle({
  required double fontSize,
  double height = 1.2,
  Color color = AppColors.cream,
}) => TextStyle(
  fontFamily: AppTextStyles.sansita,
  fontWeight: FontWeight.w700,
  fontSize: fontSize,
  height: height,
  color: color,
);
