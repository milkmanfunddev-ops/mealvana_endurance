import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

/// The plain placeholder a meal row shows where its picture would be when it
/// has none, or when every photograph failed to load (mp-145).
///
/// A flat tint of the host's own ink at the picture's footprint and corners,
/// with nothing drawn inside: no meal glyph, no "missing image" affordance,
/// no name, no border. It borrows no accent token because none of their
/// meanings covers "this meal has no picture", and it reads as a designed
/// state rather than a failure. Rows mixing pictures and placeholders stay
/// aligned because the box is the picture's box.
///
/// The 23-key icon classifier and the stored icon key are untouched by this
/// widget; the key is kept on the meal for when it is wanted, it is just not
/// drawn.
class MealPicturePlaceholder extends StatelessWidget {
  const MealPicturePlaceholder({
    super.key,
    required this.size,
    this.borderRadius,
  });

  /// Edge of the square box — the same dimension the picture would take.
  final double size;

  /// Corners; defaults to a quarter of [size] (9 at the 36pt card thumbnail,
  /// which is the picture's own radius there).
  final BorderRadius? borderRadius;

  /// Ink alpha of the fill — the same 10% the rows' hairlines use, so the
  /// box sits at the weight of the card's own edges.
  static const double tintAlpha = 0.10;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.cream : AppColors.blackberry;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: tintAlpha),
        borderRadius: borderRadius ?? BorderRadius.circular(size / 4),
      ),
    );
  }
}
