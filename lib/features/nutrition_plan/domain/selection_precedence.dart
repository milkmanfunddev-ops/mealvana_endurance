/// Selection precedence & honesty — food-recommendation §1/§1a (RATIFIED
/// Xuan, 2026-09-03). TS twin:
/// `supabase/functions/_shared/nutrition/selection-precedence.ts` (§8).
///
/// Policy kernels the conformance harness drives; the live client cascade
/// implements the same contract in control flow
/// (`ClientPlanService._solveBefore`: pinned personal formula → template →
/// greedy, with `FormulaMacros` carb scaling).
library;

import 'dart:math';

/// §1 faces, first match wins.
int resolveSelectionStep({
  required bool hasInScopePersonalFormula,
  required bool hasInScopePinnedTemplate,
  required bool hasEligibleTemplates,
}) {
  if (hasInScopePersonalFormula) return 1;
  if (hasInScopePinnedTemplate) return 2;
  if (hasEligibleTemplates) return 3;
  return 4;
}

/// Face-1/2 servings: pure uniform carb scaling, snapped to 0.5 servings,
/// floored at half a serving, UNCLAMPED (§1a: pins bypass the scale clamp —
/// W1's Oatmeal ×3.5 = 94 ÷ 27).
double scalePinnedServings(double carbTargetG, double carbsPerServingG) {
  if (carbsPerServingG <= 0) return 0;
  return max(0.5, (carbTargetG / carbsPerServingG * 2).round() / 2);
}

/// §1a labeled override: a pin is honored unconditionally AND any conflict
/// with the athlete's profile must be labeled visibly — informed, never
/// silent.
bool pinConflictLabelRequired(
  List<String> templateAllergens,
  List<String> athleteAllergies,
) {
  final athlete = athleteAllergies.map((a) => a.toLowerCase()).toSet();
  return templateAllergens.any((a) => athlete.contains(a.toLowerCase()));
}

/// §1 honesty contract: an unrenderable pin downgrades EXPLICITLY — a system
/// pick never claims `used_pin` (the Option A guard / F-31).
({bool usedPin, String fallthroughReason}) unrenderablePinDowngrade() =>
    (usedPin: false, fallthroughReason: 'pinned_template_unrenderable');
