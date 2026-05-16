import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/formula_phase.dart';

/// Two-tab pill control for switching between Before / During formulas.
///
/// Mirrors the design's `PhaseTabs` component — equal-width pills with the
/// active tab using the orange primary color and the inactive tab muted.
class PhaseTabBar extends StatelessWidget {
  const PhaseTabBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final FormulaPhase selected;
  final ValueChanged<FormulaPhase> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: _tab(context, FormulaPhase.before)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _tab(context, FormulaPhase.during)),
        ],
      ),
    );
  }

  Widget _tab(BuildContext context, FormulaPhase phase) {
    final isActive = phase == selected;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: isActive ? AppColors.orange : scheme.surfaceContainerHighest,
      borderRadius: AppRadius.circularRadius,
      child: InkWell(
        borderRadius: AppRadius.circularRadius,
        onTap: () => onSelected(phase),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.md,
          ),
          child: Center(
            child: Text(
              phase.displayLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isActive ? Colors.white : scheme.onSurface,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
