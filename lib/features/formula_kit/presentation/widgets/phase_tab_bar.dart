import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/formula_phase.dart';

/// Three-tab pill control for switching between Before / During / After
/// formulas.
///
/// Mirrors the design's `PhaseTabs` component — equal-width pills with the
/// active tab using the orange primary color and the inactive tab muted.
/// The After tab was added in PR 3 substep 6 to round out the phase trio;
/// the layout stays equal-width Expanded so all three pills share row width.
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
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: _tab(context, FormulaPhase.after)),
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
        key: ValueKey('formula_kit.phase_tab.${phase.name}'),
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
