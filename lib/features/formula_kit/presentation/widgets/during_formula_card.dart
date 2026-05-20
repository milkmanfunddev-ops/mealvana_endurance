import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/formula_view.dart';

/// List card for a During formula. Mirrors the design's `DuringCard` —
/// formula string, components, activity + duration tags.
class DuringFormulaCard extends StatelessWidget {
  const DuringFormulaCard({
    super.key,
    required this.formula,
    required this.onTap,
  });

  final DuringFormulaView formula;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BaseCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formula.formula,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final a in formula.activityTypes)
                    _Tag(label: _humanActivity(a), color: AppColors.electrolyte),
                  for (final d in formula.durationBrackets)
                    _Tag(label: d, color: AppColors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _humanActivity(String raw) {
    return switch (raw) {
      'triathlon_bike' => 'Tri — Bike',
      'triathlon_run' => 'Tri — Run',
      'triathlon_transition' => 'Tri — Transition',
      _ => raw.isEmpty ? raw : '${raw[0].toUpperCase()}${raw.substring(1)}',
    };
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: AppRadius.circularRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
