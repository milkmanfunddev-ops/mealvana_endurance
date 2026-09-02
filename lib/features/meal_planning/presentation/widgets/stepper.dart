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
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final bool enabled;

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
          onTap: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 30,
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
  });

  final FaIconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: enabled ? onTap : null,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      iconSize: 13,
      icon: FaIcon(icon),
      color: color,
      disabledColor: color.withValues(alpha: 0.3),
    );
  }
}
