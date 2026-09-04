import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/formula_profile_conflict.dart';

/// FP-7 detail DIETARY section — `formula-pin-surface.md` (RATIFIED Xuan,
/// 2026-09-03; design v4 upgrade). Allergen + diet chips in human copy, no
/// machine strings, with the S-04 emphasis rule:
///
///   - an allergen the athlete HAS → personalized + emphasized, dragonfruit:
///     "Contains gluten — your allergy"
///   - an allergen they do NOT have → neutral: "Contains peanut"
///   - diet exclusions → neutral: "Not Keto" (capitalized diet name)
///
/// Passive UI: the athlete's allergy set is injected by the owning screen
/// (the profile read lives in `athleteConflictProfileProvider`).
class DietarySection extends StatelessWidget {
  const DietarySection({
    super.key,
    required this.allergens,
    required this.excludedDiets,
    required this.athleteAllergyDbValues,
  });

  /// The formula's allergen db values (e.g. `['gluten', 'peanut']`).
  final List<String> allergens;

  /// The formula's excluded-diet db values (e.g. `['keto']`).
  final List<String> excludedDiets;

  /// The athlete's allergy db values, for the S-04 emphasis rule.
  final List<String> athleteAllergyDbValues;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final athlete = athleteAllergyDbValues.map((a) => a.toLowerCase()).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DIETARY',
          style: AppTextStyles.bodyMedium.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final a in allergens)
              if (athlete.contains(a.toLowerCase()))
                _Chip(
                  key: ValueKey('formula_kit.dietary_chip_personal_$a'),
                  label: 'Contains ${humanAllergen(a)} — your allergy',
                  bg: AppColors.dragonfruit.withValues(alpha: 0.15),
                  fg: AppColors.dragonfruit,
                  emphasized: true,
                )
              else
                _Chip(
                  key: ValueKey('formula_kit.dietary_chip_allergen_$a'),
                  label: 'Contains ${humanAllergen(a)}',
                  bg: scheme.surfaceContainerHighest,
                  fg: scheme.onSurface,
                ),
            for (final d in excludedDiets)
              _Chip(
                key: ValueKey('formula_kit.dietary_chip_diet_$d'),
                label: 'Not ${humanDietTitle(d)}',
                bg: scheme.surfaceContainerHighest,
                fg: scheme.onSurface,
              ),
          ],
        ),
        if (allergens.isEmpty && excludedDiets.isEmpty)
          Text(
            'No restrictions noted.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.bg,
    required this.fg,
    this.emphasized = false,
  });

  final String label;
  final Color bg;
  final Color fg;
  final bool emphasized;

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
        label,
        style: AppTextStyles.bodyMedium.copyWith(
          fontSize: 12,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w400,
          color: fg,
        ),
      ),
    );
  }
}
