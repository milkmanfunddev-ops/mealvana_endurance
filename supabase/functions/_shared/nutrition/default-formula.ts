/**
 * Default-formula selector (formula-first flip, 2026-07-03).
 *
 * Picks the best-fit SYSTEM formula for a phase so an unpinned plan is still
 * "formula-first" instead of falling straight through to the free solver. The
 * result is honored either:
 *   - as a real pin written at onboarding (see onboarding auto-pin), or
 *   - as an EPHEMERAL safety-net inside generate-nutrition-plan-v3 (no
 *     `formula_pins` rows written; the outcome is tagged on `pin_decision`).
 *
 * Design constraints (audit §6, plan Phase 1 #1):
 *   - Best-fit = highest `selection_priority` among the survivors.
 *   - Diet + allergen filtering is a SAFETY filter and is always applied.
 *   - Food-availability is respected so the chosen template is renderable
 *     (important: the pin path bypasses the availability filter, so the
 *     selector must not hand back a template we can't render).
 *   - Returns `null` when nothing fits → the caller falls through to the
 *     existing solver unchanged. Auto-pin is best-effort and never blocks a
 *     plan.
 *
 * The selector deliberately REUSES the existing candidate selectors
 * (`selectTemplateCandidates` / `selectPostWorkoutTemplateCandidates`) rather
 * than re-implementing the activity/duration/diet/allergen/availability
 * filters, so it can never diverge from what the phase generators actually
 * accept. Preferences are intentionally NOT passed — a default formula is a
 * neutral best-fit, not a preference-weighted pick.
 */

import {
  type DuringWorkoutTemplate,
  type FoodWithConstraints,
  type GutTrainingLevel,
  selectTemplateCandidates,
} from "./during-template-solver.ts";
import {
  type PostWorkoutTemplate,
  selectPostWorkoutTemplateCandidates,
} from "./post-template-solver.ts";
import { type ActivityType, type Food } from "./types.ts";

/** Treat null/undefined `selection_priority` as the lowest possible rank so a
 * template that forgot to set one never wins over a real value. Mirrors the
 * private `priorityRank` in post-template-solver.ts. */
function priorityRank(value: number | null | undefined): number {
  return value ?? Number.NEGATIVE_INFINITY;
}

/**
 * Pick the single best-fit template from a pre-filtered candidate list by
 * `selection_priority` DESC, tie-broken by `template_number` ASC (lower =
 * simpler) so the pick is deterministic. Returns null for an empty list.
 *
 * The input MUST already be scope/diet/allergen/availability filtered (i.e.
 * the survivor list a candidate selector returns) — this only re-ranks.
 */
export function pickHighestPriorityTemplate<
  T extends {
    id: string;
    template_number: number;
    selection_priority?: number | null;
  },
>(candidates: readonly T[]): T | null {
  let best: T | null = null;
  for (const candidate of candidates) {
    if (best === null) {
      best = candidate;
      continue;
    }
    // Compare ranks directly (not via subtraction): both being
    // Number.NEGATIVE_INFINITY must count as a tie, but the subtraction
    // -Inf − -Inf yields NaN and would silently skip the tie-break.
    const candidateRank = priorityRank(candidate.selection_priority);
    const bestRank = priorityRank(best.selection_priority);
    if (
      candidateRank > bestRank ||
      (candidateRank === bestRank &&
        candidate.template_number < best.template_number)
    ) {
      best = candidate;
    }
  }
  return best;
}

/**
 * Best-fit default DURING formula id for the given workout, or null.
 *
 * The during candidate selector already ranks by `selection_priority` (its
 * score starts from it), so `candidates[0]` is the default formula. Passing no
 * preferences keeps it a neutral best-fit.
 */
export function selectDefaultDuringFormulaId(
  templates: DuringWorkoutTemplate[],
  activityType: ActivityType,
  durationMinutes: number,
  gutTrainingLevel: GutTrainingLevel,
  foodsByName: Map<string, FoodWithConstraints>,
  allergies?: string[],
  dietaryPreference?: string,
): string | null {
  const candidates = selectTemplateCandidates(
    templates,
    activityType,
    durationMinutes,
    gutTrainingLevel,
    foodsByName,
    undefined, // liked — a default formula is preference-neutral
    undefined, // willing
    undefined, // disliked
    allergies,
    dietaryPreference,
    // no pinnedTemplateIds — we want the filtered, ranked survivor set
  );
  return candidates[0]?.id ?? null;
}

/**
 * Best-fit default AFTER formula id for the given activity, or null.
 *
 * The post candidate selector ranks by travel/prep (NOT selection_priority)
 * on the non-pin path, so we take its filtered survivors and re-rank them by
 * `selection_priority` to get the "default formula" tier the audit describes.
 */
export function selectDefaultPostFormulaId(
  templates: PostWorkoutTemplate[],
  activityType: ActivityType,
  foodsByName: Map<string, Food>,
  allergies?: string[],
  dietaryPreference?: string,
): string | null {
  const survivors = selectPostWorkoutTemplateCandidates(
    templates,
    activityType,
    foodsByName,
    allergies,
    dietaryPreference,
    // default random + no pins
  );
  return pickHighestPriorityTemplate(survivors)?.id ?? null;
}
