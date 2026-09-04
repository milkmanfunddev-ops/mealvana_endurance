import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../domain/formula_profile_conflict.dart';

/// FP-4a pre-pin warning — `formula-pin-surface.md` (RATIFIED Xuan,
/// 2026-09-03), policy `food-recommendation.md` §1a (labeled override).
///
/// INLINE, in-card, at the decision moment — never a modal/dialog.
///
///   - Allergy conflict: the full warning naming the allergen, with two
///     actions. Emphasis per R-01 option 1: **"Choose another" is the FILLED
///     primary; "Pin anyway" is the OUTLINE** — the safe default carries the
///     visual weight; the pin stays one tap away.
///   - Diet conflict: the softer one-line note (R-02 option 1), no
///     interrupting action pair — the pin proceeds; the note informs.
class PinConflictWarning extends StatelessWidget {
  /// Allergy variant. [onPinAnyway] completes the pin; [onChooseAnother]
  /// dismisses without pinning.
  const PinConflictWarning.allergy({
    super.key,
    required String allergenDisplay,
    required VoidCallback this.onChooseAnother,
    required VoidCallback this.onPinAnyway,
  }) : _allergenDisplay = allergenDisplay,
       _dietDisplay = null;

  /// Diet variant — informational one-liner, no actions.
  const PinConflictWarning.diet({super.key, required String dietDisplay})
    : _allergenDisplay = null,
      _dietDisplay = dietDisplay,
      onChooseAnother = null,
      onPinAnyway = null;

  final String? _allergenDisplay;
  final String? _dietDisplay;
  final VoidCallback? onChooseAnother;
  final VoidCallback? onPinAnyway;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final allergen = _allergenDisplay;
    if (allergen == null) {
      // Softer diet note: one line, no action pair (R-02 option 1).
      return Padding(
        key: const ValueKey('formula_kit.pin_conflict_diet_note'),
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                dietConflictNoteText(_dietDisplay ?? ''),
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const ValueKey('formula_kit.pin_conflict_warning'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.dragonfruit.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.dragonfruit.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: AppColors.dragonfruit,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  pinAllergyWarningText(allergen),
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 13,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              // R-01 option 1: the safe default is the FILLED primary…
              // 44 is the floor: the buttons' 16px/1.2 label + their 12pt
              // vertical padding clip below it (38 shore the descenders off).
              Expanded(
                child: KylePrimaryButton(
                  key: const ValueKey(
                    'formula_kit.pin_conflict_choose_another',
                  ),
                  text: 'Choose another',
                  height: 44,
                  onPressed: onChooseAnother,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // …and the pin stays one tap away as the OUTLINE.
              Expanded(
                child: KyleSecondaryButton(
                  key: const ValueKey('formula_kit.pin_conflict_pin_anyway'),
                  text: 'Pin anyway',
                  height: 44,
                  onPressed: onPinAnyway,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
