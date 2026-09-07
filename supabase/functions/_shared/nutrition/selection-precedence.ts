/**
 * Selection precedence & honesty — food-recommendation §1/§1a (RATIFIED
 * Xuan, 2026-09-03). Dart twin:
 * `lib/features/nutrition_plan/domain/selection_precedence.dart` (§8).
 *
 * These are the POLICY KERNELS the conformance harness drives; the live
 * cascade implements the same contract in control flow (personal-formula pin
 * → pinned system template → default-formula tier → rule/LP/greedy;
 * `before-phase.ts` / `during-phase.ts`, the Option A unrenderable-pin
 * downgrade, `personal-formula-pins.ts` roundHalf scaling). Keeping the
 * kernels next to those paths is what lets one ruling bind both engines.
 */

/** §1 faces, first match wins. */
export function resolveSelectionStep(args: {
  hasInScopePersonalFormula: boolean;
  hasInScopePinnedTemplate: boolean;
  hasEligibleTemplates: boolean;
}): 1 | 2 | 3 | 4 {
  if (args.hasInScopePersonalFormula) return 1;
  if (args.hasInScopePinnedTemplate) return 2;
  if (args.hasEligibleTemplates) return 3;
  return 4;
}

/** Face-1/2 servings: pure uniform carb scaling, snapped to 0.5 servings,
 * floored at half a serving, UNCLAMPED (§1a: pins bypass the scale clamp —
 * W1's Oatmeal ×3.5 = 94 ÷ 27). Matches `roundHalf` in
 * personal-formula-pins.ts. */
export function scalePinnedServings(
  carbTargetG: number,
  carbsPerServingG: number,
): number {
  if (carbsPerServingG <= 0) return 0;
  return Math.max(0.5, Math.round((carbTargetG / carbsPerServingG) * 2) / 2);
}

/** §1a labeled override: a pin is honored unconditionally AND any conflict
 * with the athlete's profile must be labeled visibly — informed, never
 * silent. */
export function pinConflictLabelRequired(
  templateAllergens: string[],
  athleteAllergies: string[],
): boolean {
  const athlete = new Set(athleteAllergies.map((a) => a.toLowerCase()));
  return templateAllergens.some((a) => athlete.has(a.toLowerCase()));
}

/** §1 honesty contract: an unrenderable pin downgrades EXPLICITLY — a system
 * pick never claims `used_pin` (the Option A guard / F-31). */
export function unrenderablePinDowngrade(): {
  used_pin: false;
  fallthrough_reason: "pinned_template_unrenderable";
} {
  return {
    used_pin: false,
    fallthrough_reason: "pinned_template_unrenderable",
  };
}
