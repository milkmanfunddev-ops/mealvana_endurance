import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';

/// Compact servings stepper (− value +) for dense rows: plan tiles, the
/// plan bar, review/tile sheets. Sits as a plain `Row` child — no flex, no
/// intrinsic width demands — which `KylePlusMinusControl` (a full-width
/// form control with an internal `Expanded`) cannot do.
class ServingsStepper extends StatelessWidget {
  const ServingsStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 12,
    this.enabled = true,
    this.dense = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool enabled;

  /// Tighter buttons and value column, for the plan-bar tiles where the
  /// stepper shares a 184pt row with the slot chip (prototype
  /// `.v-plantile .k-stepper__btn`).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final fg = isDark ? AppColors.cream : AppColors.blackberry;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: FontAwesomeIcons.minus,
          color: accent,
          enabled: enabled && value > min,
          dense: dense,
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: dense ? 22 : 30,
          child: Text(
            '$value',
            key: const ValueKey('meal_planning.stepper_value'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _StepButton(
          icon: FontAwesomeIcons.plus,
          color: accent,
          enabled: enabled && value < max,
          dense: dense,
          onTap: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
    this.dense = false,
  });

  final FaIconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
      constraints: BoxConstraints(
        minWidth: dense ? 24 : 30,
        minHeight: dense ? 24 : 30,
      ),
      padding: EdgeInsets.symmetric(horizontal: dense ? 0 : AppSpacing.xxs),
      iconSize: dense ? 11 : 13,
      icon: FaIcon(icon),
      color: color,
      disabledColor: color.withValues(alpha: 0.3),
    );
  }
}
