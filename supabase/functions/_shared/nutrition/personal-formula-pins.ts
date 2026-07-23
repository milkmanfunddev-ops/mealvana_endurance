/**
 * Personal-formula pin honoring — shared helpers.
 *
 * A pinned personal formula (resolved in `pins.ts` into `PersonalFormulaPin`)
 * is self-contained: its `components` array carries each food's per-serving
 * macros, so it can be emitted as a phase's foods with NO food-pool lookup.
 *
 * Honor policy mirrors system-template pins (locked 2026-05-21): an in-scope
 * pin is honored unconditionally (bypasses allergen / diet / dislike filters).
 * Fall through to normal selection only when no pin matches the workout's
 * scope.
 *
 * Quantity semantics (decided 2026-06-12, supersedes the 2026-06-11
 * asymmetry): ALL phases scale. Authored quantities define the formula's
 * composition ratio; each caller passes its phase/slot carb target and the
 * components are scaled uniformly to hit it (see [carbScaleFactor]). A
 * missing/zero target or a carb-free formula falls back to authored
 * quantities verbatim (factor 1).
 *
 * Scope:
 *   - before: phase match only (no activity/duration axis).
 *   - during: activity overlap AND duration-bracket membership (null = any).
 *   - after:  activity overlap only (post phase has no duration brackets).
 *
 * Component keys are the canonical Flutter `FormulaMacros` shape:
 *   food_id, food_name, quantity, serving_unit, carbs_per_serving,
 *   protein_per_serving, fat_per_serving, sodium_mg, fluid_ml_per_serving,
 *   calories_per_serving.
 */

import type { FoodResult } from "./types.ts";
import type { PersonalFormulaPin } from "./pins.ts";

/** Map a workout activity type to the activity strings personal formulas use. */
function mapActivity(activityType: string): string[] {
  switch (activityType) {
    case "running":
      return ["running"];
    case "cycling":
      return ["cycling"];
    case "swimming":
      return ["swimming"];
    case "triathlon":
    case "duathlon":
    case "multisport":
      return [
        "running",
        "cycling",
        "swimming",
        "triathlon_bike",
        "triathlon_run",
        "triathlon_transition",
      ];
    case "brick":
      return ["running", "cycling", "triathlon_bike", "triathlon_run"];
    default:
      return [activityType];
  }
}

/** Duration → bracket string (matches DuringDuration storage values). */
function durationBracket(durationMinutes: number): string {
  if (durationMinutes < 90) return "< 90 min";
  if (durationMinutes <= 150) return "90-150 min";
  if (durationMinutes <= 240) return "150-240 min";
  return "> 240 min";
}

function activityInScope(
  formulaActivities: string[] | null,
  activityType: string,
): boolean {
  if (formulaActivities === null || formulaActivities.length === 0) return true;
  const mapped = mapActivity(activityType);
  return formulaActivities.some((a) => mapped.includes(a));
}

/**
 * Find the first in-scope pinned personal formula for [phase], or null.
 * Personal formulas come newest-first from `pins.ts` (preserves
 * `personal_formulas.updated_at DESC` ordering of the underlying query).
 */
export function matchPersonalFormulaPin(
  personalFormulas: PersonalFormulaPin[],
  phase: "before" | "during" | "after",
  activityType: string,
  durationMinutes?: number,
): PersonalFormulaPin | null {
  for (const f of personalFormulas) {
    if (f.phase !== phase) continue;
    if (phase === "before") return f;
    if (!activityInScope(f.activities, activityType)) continue;
    if (phase === "during") {
      const durs = f.durations;
      if (durs !== null && durs.length > 0 && durationMinutes !== undefined) {
        if (!durs.includes(durationBracket(durationMinutes))) continue;
      }
    }
    return f;
  }
  return null;
}

/**
 * Why a pinned personal formula was excluded from a phase it was authored for.
 *
 * - `activity_out_of_scope` — the formula's `activities` list has no overlap
 *   with the workout's activity type.
 * - `duration_out_of_scope` — activity matched, but the workout's duration
 *   bracket is not one the formula targets. This is the common case: a
 *   "90-150 min" cycling formula on a 75-minute ride.
 */
export type PersonalFormulaSkipReason =
  | "activity_out_of_scope"
  | "duration_out_of_scope";

export interface PersonalFormulaSkip {
  id: string;
  name: string;
  reason: PersonalFormulaSkipReason;
  /** Brackets the formula targets. Null when the formula is unscoped. */
  formula_durations: string[] | null;
  /** Bracket this workout resolved to, e.g. "< 90 min". Null when unknown. */
  workout_bracket: string | null;
}

/**
 * Explain why the user's pinned personal formulas did not apply to this
 * workout. Mirrors the scope gates in [matchPersonalFormulaPin] exactly, but
 * records a reason per excluded formula instead of returning the first match.
 *
 * Intended to be called ONLY when [matchPersonalFormulaPin] returned null —
 * if a formula was honored there is nothing to explain.
 *
 * Motivation (audit 2026-07-18): a scope-excluded personal formula previously
 * produced no signal at all. When an unrelated `during_system` pin fired later
 * in the same phase, the wire response reported `used_pin: true` naming THAT
 * pin, so the client rendered a green "pinned formula used" banner while the
 * user's own formula had been silently discarded — indistinguishable from the
 * app ignoring their formula outright. This list rides alongside whatever
 * decision is ultimately emitted so the skip stays visible either way.
 */
export function collectPersonalFormulaSkips(
  personalFormulas: PersonalFormulaPin[],
  phase: "before" | "during" | "after",
  activityType: string,
  durationMinutes?: number,
): PersonalFormulaSkip[] {
  // `before` has no activity/duration axis — a before formula is never
  // scope-excluded, so there is nothing to report.
  if (phase === "before") return [];

  const workoutBracket = phase === "during" && durationMinutes !== undefined
    ? durationBracket(durationMinutes)
    : null;

  const skips: PersonalFormulaSkip[] = [];
  for (const f of personalFormulas) {
    if (f.phase !== phase) continue;

    if (!activityInScope(f.activities, activityType)) {
      skips.push({
        id: f.id,
        name: f.name,
        reason: "activity_out_of_scope",
        formula_durations: f.durations,
        workout_bracket: workoutBracket,
      });
      continue;
    }

    if (phase === "during") {
      const durs = f.durations;
      if (durs !== null && durs.length > 0 && durationMinutes !== undefined) {
        if (!durs.includes(durationBracket(durationMinutes))) {
          skips.push({
            id: f.id,
            name: f.name,
            reason: "duration_out_of_scope",
            formula_durations: durs,
            workout_bracket: workoutBracket,
          });
        }
      }
    }
  }
  return skips;
}

/**
 * Map a before personal-formula `sub_phase` tag to its BeforePhaseResult slot.
 * Returns null for an untagged (no-timing) formula — timing is required for
 * before formulas, so an untagged one is never honored (defensive: the client
 * editor enforces a timing on save, but a legacy/forked row could lack one).
 */
export function beforeSlotForSubPhase(
  subPhase: string | null,
): "meal" | "snack" | "top_up" | null {
  switch (subPhase) {
    case "full_meal":
      return "meal";
    case "snack":
      return "snack";
    case "top_up":
      return "top_up";
    default:
      return null;
  }
}

/**
 * Find the newest pinned before personal formula tagged for [slot], or null.
 *
 * Before honoring is per sub-phase slot (unlike during/after, which have a
 * single output): a before formula carries one timing tag (full_meal / snack /
 * top_up) and overlays only the matching active sub-phase. Untagged formulas
 * are skipped (see [beforeSlotForSubPhase]).
 */
export function matchBeforePersonalFormulaForSlot(
  personalFormulas: PersonalFormulaPin[],
  slot: "meal" | "snack" | "top_up",
): PersonalFormulaPin | null {
  for (const f of personalFormulas) {
    if (f.phase !== "before") continue;
    if (beforeSlotForSubPhase(f.subPhase) === slot) return f;
  }
  return null;
}

function num(v: unknown): number {
  return typeof v === "number" ? v : 0;
}

/** Round to one decimal (matches buildFoodResult macro rounding). */
function r1(v: number): number {
  return Math.round(v * 10) / 10;
}

/**
 * Uniform multiplier that scales a during formula's authored quantities so
 * its total carbs hit [targetCarbsG], preserving the formula's composition
 * (every component scales by the same factor, water included). Returns 1
 * (no scaling) when the target is missing/non-positive or the formula has
 * no carbs to scale (e.g. water + electrolytes only).
 *
 * Mirrored in Flutter by `FormulaMacros.carbScaleFactor` — keep in sync.
 */
export function carbScaleFactor(
  components: Array<Record<string, unknown>>,
  targetCarbsG: number | undefined,
): number {
  if (targetCarbsG === undefined || targetCarbsG <= 0) return 1;
  let baseCarbs = 0;
  for (const c of components) {
    const qty = typeof c.quantity === "number" ? c.quantity : 1;
    if (qty <= 0) continue;
    baseCarbs += num(c.carbs_per_serving) * qty;
  }
  if (baseCarbs <= 0) return 1;
  return targetCarbsG / baseCarbs;
}

/**
 * Round a scaled quantity to user-meaningful 0.5 steps, flooring at 0.5 so
 * no component vanishes from the user's formula.
 *
 * Mirrored in Flutter by `FormulaMacros.scaledQuantity` — keep in sync.
 */
function roundHalf(v: number): number {
  return Math.max(0.5, Math.round(v * 2) / 2);
}

/**
 * Render a pinned personal formula's components into the phase's
 * [FoodResult] list, using the per-serving macros snapshotted on each
 * component. No food-pool lookup.
 *
 * [scaleToCarbsG]: scale quantities uniformly to the phase/slot carb target
 * (all phases scale, decided 2026-06-12). When omitted, zero, or the formula
 * has no carbs, authored quantities are emitted verbatim.
 */
export function personalFormulaToFoodResults(
  pin: PersonalFormulaPin,
  timing: string,
  scaleToCarbsG?: number,
): FoodResult[] {
  const k = carbScaleFactor(pin.components, scaleToCarbsG);
  const out: FoodResult[] = [];
  for (const c of pin.components) {
    const authoredQty = typeof c.quantity === "number" ? c.quantity : 1;
    if (authoredQty <= 0) continue;
    const qty = k === 1 ? authoredQty : roundHalf(authoredQty * k);
    const carbs = r1(num(c.carbs_per_serving) * qty);
    const protein = r1(num(c.protein_per_serving) * qty);
    const fat = r1(num(c.fat_per_serving) * qty);
    const sodium = Math.round(num(c.sodium_mg) * qty);
    const fluids = Math.round(num(c.fluid_ml_per_serving) * qty);
    const calories = typeof c.calories_per_serving === "number"
      ? Math.round(c.calories_per_serving * qty)
      : Math.round(carbs * 4 + protein * 4 + fat * 9);
    const name = (c.food_name as string | undefined) ?? "Food";
    out.push({
      food_id: (c.food_id as string | undefined) ?? name,
      quantity: qty,
      carbs_grams: carbs,
      protein_grams: protein,
      fat_grams: fat,
      sodium_mg: sodium,
      fluids_ml: fluids,
      calories,
      timing,
      display_name: name,
      serving_unit: (c.serving_unit as string | undefined) ?? null,
      is_user_food: c.source === "user",
    });
  }
  return out;
}
