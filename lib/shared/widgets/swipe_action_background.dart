import 'package:flutter/material.dart';

import '../../theme/kyle_design/app_spacing.dart';
import '../../theme/kyle_design/app_text_styles.dart';

/// The coloured panel revealed behind a swiped row — the widget you hand to
/// [Dismissible.background] / [Dismissible.secondaryBackground].
///
/// It exists so the reveal is always shaped like the card sitting on top of
/// it. Pass the *same* [borderRadius] and [margin] the foreground row uses;
/// a mismatch is what produces the square corners poking out from under a
/// rounded card, or a panel that's taller than the row it belongs to.
///
/// When the foreground is a plain [Card] taking its shape from the app theme,
/// use [cardThemeRadius] rather than guessing a number.
class SwipeActionBackground extends StatelessWidget {
  const SwipeActionBackground({
    super.key,
    required this.color,
    required this.alignment,
    required this.borderRadius,
    this.margin,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.icon,
    this.label,
    this.labelStyle,
    this.gap = AppSpacing.sm,
  });

  /// Fill of the revealed panel (red for delete/remove, blue for swap, ...).
  final Color color;

  /// Which edge the icon/label hug. [Alignment.centerLeft] is the
  /// `startToEnd` (background) reveal; [Alignment.centerRight] the
  /// `endToStart` (secondaryBackground) one.
  final AlignmentGeometry alignment;

  /// Must match the foreground card's radius.
  final BorderRadius borderRadius;

  /// Must match the foreground card's margin, so the panel occupies exactly
  /// the same rect as the card and no sliver of colour leaks past its edges.
  final EdgeInsetsGeometry? margin;

  final EdgeInsetsGeometry padding;

  /// Optional leading/trailing glyph. Any widget, so callers can pass either a
  /// Material [Icon] or a [FaIcon] without this widget knowing the difference.
  final Widget? icon;

  final String? label;
  final TextStyle? labelStyle;

  /// Space between [icon] and [label] when both are present.
  final double gap;

  /// The radius a Material [Card] paints with under the current theme.
  ///
  /// Cards in this app get their shape from `CardThemeData`, so a hardcoded
  /// number in the swipe background silently drifts the day the theme moves.
  static BorderRadius cardThemeRadius(BuildContext context) {
    final shape = Theme.of(context).cardTheme.shape;
    if (shape is RoundedRectangleBorder) {
      final radius = shape.borderRadius;
      if (radius is BorderRadius) return radius;
    }
    return AppRadius.cardRadius;
  }

  @override
  Widget build(BuildContext context) {
    // Right-aligned reveals read label-then-icon so the glyph stays nearest
    // the screen edge the finger is travelling towards.
    final isLeading = alignment == Alignment.centerLeft;
    final parts = <Widget>[
      if (icon != null) icon!,
      if (icon != null && label != null) SizedBox(width: gap),
      if (label != null)
        Text(
          label!,
          style:
              labelStyle ??
              AppTextStyles.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
    ];

    return Container(
      margin: margin,
      padding: padding,
      alignment: alignment,
      decoration: BoxDecoration(color: color, borderRadius: borderRadius),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: isLeading ? parts : parts.reversed.toList(),
      ),
    );
  }
}
