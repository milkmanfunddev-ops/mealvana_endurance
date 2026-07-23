import 'package:flutter/material.dart';

import '../../../../features/daily_macros/domain/daily_macro_targets.dart';
import '../../domain/consumed_totals.dart';

/// Shows eaten totals vs. optional macro targets.
///
/// Pass [targets] when you want to render "X g / Y g" comparison rows;
/// omit it (null) to render totals-only rows.
class ConsumedProgressWidget extends StatelessWidget {
  const ConsumedProgressWidget({
    super.key,
    required this.consumed,
    this.targets,
  });

  final ConsumedTotals consumed;
  final DailyMacroTargets? targets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark
        ? Colors.white70
        : theme.colorScheme.onSurfaceVariant;

    final targetCalories = targets?.totalCalories.round();
    final caloriesRatio = (targetCalories != null && targetCalories > 0)
        ? (consumed.calories / targetCalories).clamp(0.0, 1.0)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Eaten Today',
          style: theme.textTheme.labelLarge?.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Calories row
        _MacroRow(
          label: 'Calories',
          eaten: consumed.calories.toDouble(),
          target: targetCalories?.toDouble(),
          unit: 'kcal',
          color: const Color(0xFFFF9500),
          ratio: caloriesRatio,
        ),
        const SizedBox(height: 6),

        // Carbs
        _MacroRow(
          label: 'Carbs',
          eaten: consumed.carbsG,
          target: targets?.carbG,
          unit: 'g',
          color: const Color(0xFF00C896),
          ratio: (targets != null && targets!.carbG > 0)
              ? (consumed.carbsG / targets!.carbG).clamp(0.0, 1.0)
              : null,
        ),
        const SizedBox(height: 6),

        // Protein
        _MacroRow(
          label: 'Protein',
          eaten: consumed.proteinG,
          target: targets?.protG,
          unit: 'g',
          color: const Color(0xFF6B4FA0),
          ratio: (targets != null && targets!.protG > 0)
              ? (consumed.proteinG / targets!.protG).clamp(0.0, 1.0)
              : null,
        ),
        const SizedBox(height: 6),

        // Fat
        _MacroRow(
          label: 'Fat',
          eaten: consumed.fatG,
          target: targets?.fatG,
          unit: 'g',
          color: const Color(0xFFFF2D55),
          ratio: (targets != null && targets!.fatG > 0)
              ? (consumed.fatG / targets!.fatG).clamp(0.0, 1.0)
              : null,
        ),
      ],
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.eaten,
    required this.unit,
    required this.color,
    this.target,
    this.ratio,
  });

  final String label;
  final double eaten;
  final double? target;
  final String unit;
  final Color color;
  final double? ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final eatenStr = unit == 'kcal'
        ? '${eaten.round()} $unit'
        : '${eaten.toStringAsFixed(0)} $unit';

    final targetStr = target != null
        ? (unit == 'kcal'
              ? '/ ${target!.round()} $unit'
              : '/ ${target!.toStringAsFixed(0)} $unit')
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark
                    ? Colors.white70
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              targetStr != null ? '$eatenStr $targetStr' : eatenStr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (ratio != null) ...[
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
        ],
      ],
    );
  }
}
