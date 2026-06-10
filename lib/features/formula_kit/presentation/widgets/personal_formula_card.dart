import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/after_filter_options.dart' show TravelFriendliness;
import '../../domain/formula_macros.dart';
import '../../domain/formula_phase.dart';
import '../../domain/personal_formula.dart';
import 'pin_toggle.dart';

/// List card for a user-authored personal formula. Mirrors [BeforeFormulaCard]
/// — title, component subtitle, macro pill row — with a pin toggle and a
/// "Yours" provenance pill.
class PersonalFormulaCard extends StatelessWidget {
  const PersonalFormulaCard({
    super.key,
    required this.formula,
    required this.onTap,
  });

  final PersonalFormula formula;
  final VoidCallback onTap;

  /// The timing/scope badge shown like the system cards do — the before
  /// timing window (e.g. "30-90 min"), the during duration bracket(s), or the
  /// after travel label. Null when the formula has no scope set yet.
  String? _scopeBadge() {
    switch (formula.phase) {
      case FormulaPhase.before:
        return switch (formula.subPhase) {
          'full_meal' => '1.5-3 hours',
          'snack' => '30-90 min',
          'top_up' => '< 30 min',
          _ => null,
        };
      case FormulaPhase.during:
        final d = formula.durations;
        return (d != null && d.isNotEmpty) ? d.join(' · ') : null;
      case FormulaPhase.after:
        return TravelFriendliness.fromStorageValue(formula.travelFriendliness)
            ?.displayLabel;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final componentNames = formula.components
        .map(FormulaMacros.nameOf)
        .where((n) => n.isNotEmpty)
        .toList();
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
                  if (_scopeBadge() case final badge?) ...[
                    _Pill(
                      text: badge,
                      bg: AppColors.electrolyte.withValues(alpha: 0.18),
                      fg: AppColors.electrolyte,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  PinTogglePersonalFormula(
                    key: ValueKey(
                      'formula_kit.personal_card_pin_${formula.id}',
                    ),
                    formulaId: formula.id,
                    phase: formula.phase,
                    source: 'card',
                  ),
                ],
              ),
              if (componentNames.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  componentNames.join(' + '),
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
                  _MacroPill(label: '${formula.totalCarbsG ?? 0}g C'),
                  _MacroPill(label: '${formula.totalProteinG ?? 0}g P'),
                  _MacroPill(label: '${formula.totalFatG ?? 0}g F'),
                  _MacroPill(label: '${formula.totalSodiumMg ?? 0}mg Na'),
                ],
              ),
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
