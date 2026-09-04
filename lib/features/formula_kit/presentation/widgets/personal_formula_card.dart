import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../application/athlete_conflict_profile_provider.dart';
import '../../domain/formula_profile_conflict.dart';

import '../../domain/after_filter_options.dart' show TravelFriendliness;
import '../../domain/during_filter_options.dart' show DuringDuration;
import '../../domain/formula_macros.dart';
import '../../domain/formula_phase.dart';
import '../../domain/personal_formula.dart';
import 'pin_toggle.dart';

/// List card for a user-authored personal formula. Mirrors [BeforeFormulaCard]
/// — title, component subtitle, macro pill row — with a pin toggle and a
/// "Yours" provenance pill.
class PersonalFormulaCard extends ConsumerWidget {
  const PersonalFormulaCard({
    super.key,
    required this.formula,
    required this.onTap,
  });

  final PersonalFormula formula;
  final VoidCallback onTap;

  /// The timing/scope badges shown like the system cards do — the before
  /// timing window (e.g. "30-120 min"), one badge per during duration bracket,
  /// or the after travel label. Empty when the formula has no scope set yet.
  List<String> _scopeBadges() {
    switch (formula.phase) {
      case FormulaPhase.before:
        // Ratified windows after the 120-minute meal boundary (D-017).
        final label = switch (formula.subPhase) {
          'full_meal' => '2-4 hours',
          'snack' => '30-120 min',
          'top_up' => '< 30 min',
          _ => null,
        };
        return [if (label != null) label];
      case FormulaPhase.during:
        return [
          for (final d in formula.durations ?? const <String>[])
            _durationLabel(d),
        ];
      case FormulaPhase.after:
        final label = TravelFriendliness.fromStorageValue(
          formula.travelFriendliness,
        )?.displayLabel;
        return [if (label != null) label];
    }
  }

  /// Durations are stored as [DuringDuration] storage values ("90-150 min");
  /// show the matching display label ("90–150 min") like the editor chips do.
  String _durationLabel(String storage) {
    for (final v in DuringDuration.values) {
      if (v.storageValue == storage) return v.displayLabel;
    }
    return storage;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // Personal formulas are standing auto-includes ("Mealvana will always
    // include your own formulas"), so a profile conflict is labeled on the
    // card itself, not only at the pin/save moments (Xuan, 2026-09-03
    // evening; S-04 copy register; intake
    // 2026-09-03-personal-formula-conflict-labeling.md).
    final conflict = ref
        .watch(athleteConflictProfileProvider)
        .maybeWhen(
          data: (profile) =>
              firstComponentConflict(formula.components, profile)?.conflict,
          orElse: () => null,
        );
    final badges = _scopeBadges();
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
                  // A single scope badge sits in the header like the system
                  // before/after cards. Multiple badges (during formulas with
                  // several duration brackets) move to their own Wrap below —
                  // one pill per bracket, never merged into one.
                  if (badges.length == 1) ...[
                    _Pill(
                      text: badges.single,
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
                    conflict: conflict,
                  ),
                ],
              ),
              if (conflict != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  key: ValueKey(
                    'formula_kit.personal_card_conflict_${formula.id}',
                  ),
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 14,
                      color: AppColors.dragonfruit,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                    Expanded(
                      child: Text(
                        conflict.kind == FormulaConflictKind.allergy
                            ? 'Contains ${conflict.allergenDisplay} — '
                                  'your allergy'
                            : dietConflictNoteText(conflict.dietDisplay),
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.dragonfruit,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
              if (badges.length > 1) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final badge in badges)
                      _Pill(
                        text: badge,
                        bg: AppColors.electrolyte.withValues(alpha: 0.18),
                        fg: AppColors.electrolyte,
                      ),
                  ],
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
