import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/after_filter_options.dart';
import '../../domain/formula_view.dart';
import 'pin_toggle.dart';

/// List card for an After formula. Spare by design: name + travel-friendliness
/// pill + pin toggle in the header row, and an optional C:P ratio meta pill
/// below. Detail screen carries the macros, components, and full taxonomy.
///
/// Pin toggle is always rendered — every after template is pinnable in V1
/// (`AfterFormulaView.isPinnable` is hard-coded `true`).
class AfterFormulaCard extends StatelessWidget {
  const AfterFormulaCard({
    super.key,
    required this.formula,
    required this.onTap,
  });

  final AfterFormulaView formula;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final travel =
        TravelFriendliness.fromStorageValue(formula.travelFriendliness);
    return BaseCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardRadius,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      formula.name,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  if (travel != null)
                    _Pill(
                      text: travel.displayLabel,
                      bg: AppColors.electrolyte.withValues(alpha: 0.18),
                      fg: AppColors.electrolyte,
                    ),
                  const SizedBox(width: AppSpacing.xs),
                  PinToggleAfter(
                    key: ValueKey('formula_kit.after_card_pin_${formula.id}'),
                    formula: formula,
                    source: 'card',
                  ),
                ],
              ),
              if (formula.targetCarbProteinRatio != null &&
                  formula.targetCarbProteinRatio!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _MetaPill(
                      label: 'C:P ${formula.targetCarbProteinRatio}',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.circularRadius,
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.circularRadius,
      ),
      child: Text(
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 12,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
