import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../application/formula_pin_controller.dart';
import '../../domain/formula_view.dart';
import 'pin_conflict_card_state.dart';
import 'pin_toggle.dart';

/// List card for a Before formula. Mirrors the design's `BeforeCard` —
/// title, components subtitle, macros pill row, timing window pill.
///
/// Carries the FP-4a inline pre-pin warning and FP-4b post-pin conflict
/// label when the formula conflicts with the athlete's profile
/// (`formula-pin-surface.md`, RATIFIED Xuan 2026-09-03).
class BeforeFormulaCard extends ConsumerStatefulWidget {
  const BeforeFormulaCard({
    super.key,
    required this.formula,
    required this.onTap,
  });

  final BeforeFormulaView formula;
  final VoidCallback onTap;

  @override
  ConsumerState<BeforeFormulaCard> createState() => _BeforeFormulaCardState();
}

class _BeforeFormulaCardState extends ConsumerState<BeforeFormulaCard>
    with PinConflictCardState<BeforeFormulaCard> {
  BeforeFormulaView get formula => widget.formula;

  @override
  String get templateId => formula.id;

  @override
  List<String> get templateAllergens => formula.allergens;

  @override
  List<String> get excludedDiets => formula.excludedDiets;

  @override
  Future<void> completePin() => ref
      .read(formulaPinControllerProvider.notifier)
      .toggleBefore(formula: formula, source: 'card');

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BaseCard(
      child: InkWell(
        onTap: widget.onTap,
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
                  _Pill(
                    text: formula.timingWindow,
                    bg: AppColors.orange.withValues(alpha: 0.15),
                    fg: AppColors.orange,
                  ),
                  // Pin toggle: V1 supports food templates only (drink /
                  // electrolyte cards intentionally render no affordance).
                  if (formula.isPinnable) ...[
                    const SizedBox(width: AppSpacing.xs),
                    PinToggleBefore(
                      key: ValueKey(
                        'formula_kit.before_card_pin_${formula.id}',
                      ),
                      formula: formula,
                      source: 'card',
                      conflict: conflict,
                      onAllergyConflictPinAttempt: showAllergyWarning,
                      onDietConflictPinned: showDietNote,
                    ),
                  ],
                ],
              ),
              if (formula.componentDisplayStrings.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  formula.componentDisplayStrings.join(' + '),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  _MacroPill(label: '${formula.totalCarbsG.round()}g C'),
                  _MacroPill(label: '${formula.totalProteinG.round()}g P'),
                  _MacroPill(label: '${formula.totalFatG.round()}g F'),
                  _MacroPill(label: '${formula.totalSodiumMg.round()}mg Na'),
                ],
              ),
              ...conflictFooter(),
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

class _MacroPill extends StatelessWidget {
  const _MacroPill({required this.label});
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
