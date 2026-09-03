import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../application/athlete_conflict_profile_provider.dart';
import '../../application/formula_pin_controller.dart';
import '../../domain/formula_profile_conflict.dart';
import 'pin_conflict_label.dart';
import 'pin_conflict_warning.dart';

/// Shared FP-4a/FP-4b card behavior for the library formula cards
/// (`formula-pin-surface.md`, RATIFIED Xuan 2026-09-03):
///
///   - evaluates the formula's profile conflict (allergy beats diet) via the
///     §1a kernel behind [evaluateFormulaProfileConflict]
///   - mounts the INLINE pre-pin warning when the pin gesture hits an
///     allergy-conflicted formula ("Pin anyway" completes the pin, "Choose
///     another" dismisses without pinning)
///   - mounts the softer diet note after a diet-conflicted pin proceeds
///   - mounts the persistent collapsible dragonfruit label on an honored
///     conflicting pin — presentation only: a pin is NEVER auto-removed when
///     the profile changes
///
/// Mix into a card's `ConsumerState`, implement the four members, pass
/// [conflict] + [showAllergyWarning] + [showDietNote] to the card's pin
/// toggle, and append [conflictFooter] to the card body.
mixin PinConflictCardState<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool _allergyWarningVisible = false;
  bool _dietNoteVisible = false;

  /// The template / formula id the pin controller tracks.
  String get templateId;

  /// The formula's allergen db values.
  List<String> get templateAllergens;

  /// The formula's excluded-diet db values.
  List<String> get excludedDiets;

  /// Executes the real pin toggle through [FormulaPinController] ("Pin
  /// anyway", and "Unpin" on the FP-4b label reuse it).
  Future<void> completePin();

  /// The formula's conflict with the current profile, or null. Watches the
  /// profile provider, so cards relabel live when the profile changes —
  /// without ever touching the pin itself.
  FormulaProfileConflict? get conflict => ref
      .watch(athleteConflictProfileProvider)
      .maybeWhen(
        data: (profile) => evaluateFormulaProfileConflict(
          templateAllergens: templateAllergens,
          excludedDiets: excludedDiets,
          profile: profile,
        ),
        orElse: () => null,
      );

  bool get isPinned => ref
      .watch(formulaPinControllerProvider)
      .maybeWhen(
        data: (s) => s.pinnedTemplateIds.contains(templateId),
        orElse: () => false,
      );

  /// FP-4a: pin gesture hit an allergy-conflicted formula — mount the
  /// inline warning instead of pinning.
  void showAllergyWarning() => setState(() => _allergyWarningVisible = true);

  /// FP-4a: a diet-conflicted pin proceeded — surface the one-line note.
  void showDietNote() => setState(() => _dietNoteVisible = true);

  Future<void> _pinAnyway() async {
    setState(() => _allergyWarningVisible = false);
    try {
      await completePin();
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Couldn\'t update pin: $e');
      }
    }
  }

  Future<void> _unpin() async {
    try {
      await completePin(); // toggle: currently pinned → unpins.
    } catch (e) {
      if (mounted) {
        MealvanaSnackbar.showError(context, 'Couldn\'t update pin: $e');
      }
    }
  }

  /// Widgets to append at the bottom of the card body, in a `Column` with
  /// `crossAxisAlignment: stretch/start`.
  List<Widget> conflictFooter() {
    final c = conflict;
    if (c == null) return const [];
    final pinned = isPinned;
    return [
      if (_allergyWarningVisible &&
          !pinned &&
          c.kind == FormulaConflictKind.allergy)
        PinConflictWarning.allergy(
          allergenDisplay: c.allergenDisplay,
          onChooseAnother: () =>
              setState(() => _allergyWarningVisible = false),
          onPinAnyway: _pinAnyway,
        ),
      if (_dietNoteVisible && c.kind == FormulaConflictKind.diet)
        PinConflictWarning.diet(dietDisplay: c.dietDisplay),
      // FP-4b: persistent label on the honored conflicting pin.
      if (pinned) PinConflictLabel(conflict: c, onUnpin: _unpin),
    ];
  }
}
