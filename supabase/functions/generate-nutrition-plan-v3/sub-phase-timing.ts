/**
 * Athlete-facing timing copy for the three before sub-phases.
 *
 * Ratified design copy from the BEFORE screen redesign (pre-workout bundle
 * `pre-workout-macros@v1`, see docs/ssot/PRE-WORKOUT-BUNDLE-DIGEST.md §5).
 * The windows are the SSOT tier boundaries — `meal` iff t >= 120 min,
 * `snack` iff t >= 30 min, top-off always — so the labels are fixed per
 * sub-phase and no longer vary with lead time.
 *
 * Local to generate-nutrition-plan-v3: the shared
 * `_shared/nutrition/templates/pre-workout-targets.ts` label helper still
 * carries the pre-v2 windows ("3-4 hours before" / "45-60 min before") and
 * was not updated by this pass; once its other consumers (currently none)
 * are audited it can be deleted in favour of this one.
 */

import type { SubPhaseType } from "../generate-macros-v4/types.ts";

export function getSubPhaseTimingLabel(subPhase: SubPhaseType): string {
  if (subPhase === "meal") return "FINISH BY 2H OUT";
  if (subPhase === "snack") return "2H TO 30 MIN OUT";
  return "LAST 30 MIN";
}
