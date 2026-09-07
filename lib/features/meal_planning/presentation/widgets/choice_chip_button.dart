import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// The one chip in Vana's conversation surfaces — the prototype's
/// `.k-choice`: an electrolyte outline over a faint electrolyte wash, filled
/// solid once chosen and greyed out once the strip is spent.
///
/// [emphasized] is `.v-chip--primary` (a full-strength border and bold
/// label) for the leading action in a picker strip; [dense] is
/// `.v-chip--filter`, the smaller filter chips underneath it.
class ChoiceChipButton extends StatelessWidget {
  const ChoiceChipButton({
    super.key,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
    this.emphasized = false,
    this.dense = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool enabled;
  final bool emphasized;
  final bool dense;

  /// Fill the space the caller gives it, with the label centred. Off by
  /// default so a chip in a [Wrap] sizes to its own text.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final neutral = isDark ? AppColors.cream : AppColors.blackberry;

    final Color background;
    final Color border;
    final Color foreground;
    final FontWeight weight;

    if (!enabled) {
      background = Colors.transparent;
      border = neutral.withValues(alpha: 0.15);
      foreground = neutral.withValues(alpha: 0.3);
      weight = FontWeight.w500;
    } else if (selected) {
      background = accent;
      border = accent;
      foreground = AppColors.blackberry;
      weight = FontWeight.w700;
    } else {
      background = accent.withValues(alpha: isDark ? 0.1 : 0.07);
      border = accent.withValues(alpha: emphasized ? 1 : 0.6);
      foreground = accent;
      weight = emphasized ? FontWeight.w700 : FontWeight.w500;
    }

    final chip = Container(
      key: ValueKey('meal_planning.choice_chip_$label'),
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 3)
          : const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
      // A Container with an alignment fills its constraints, so this is set
      // only where the caller wants a stretched chip.
      alignment: expand ? Alignment.center : null,
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodySmall.copyWith(
          color: foreground,
          fontWeight: weight,
          fontSize: dense ? 11.5 : null,
        ),
      ),
    );

    if (!enabled) return Opacity(opacity: dense ? 0.85 : 1, child: chip);
    return GestureDetector(onTap: onTap, child: chip);
  }
}
