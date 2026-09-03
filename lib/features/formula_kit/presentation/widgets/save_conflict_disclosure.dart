import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/formula_profile_conflict.dart';

/// FP-8 authoring save-time disclosure — `formula-pin-surface.md` (RATIFIED
/// Xuan, 2026-09-03; design v4). Rendered ABOVE the Save button when the
/// composed formula contains a component conflicting with the profile:
///
///   - allergy: the full note naming the food and allergen, ending exactly
///     with [saveDisclosureClosingSentence]
///   - diet: the softer one-liner
///
/// Save is NEVER disabled (disclose-never-block, §1a) — this widget carries
/// no action and gates nothing.
class SaveConflictDisclosure extends StatelessWidget {
  const SaveConflictDisclosure({
    super.key,
    required this.foodName,
    required this.conflict,
  });

  final String foodName;
  final FormulaProfileConflict conflict;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isAllergy = conflict.kind == FormulaConflictKind.allergy;
    final text = isAllergy
        ? saveAllergyDisclosureText(foodName, conflict.allergenDisplay)
        : dietConflictNoteText(conflict.dietDisplay);
    final accent = isAllergy ? AppColors.dragonfruit : scheme.onSurfaceVariant;
    return Container(
      key: const ValueKey('formula_kit.save_conflict_disclosure'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: isAllergy
            ? AppColors.dragonfruit.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isAllergy ? Icons.warning_amber_rounded : Icons.info_outline,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
