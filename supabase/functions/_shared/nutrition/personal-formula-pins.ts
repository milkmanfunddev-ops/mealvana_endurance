/**
 * Personal-formula pin honoring — shared helpers.
 *
 * A pinned personal formula (resolved in `pins.ts` into `PersonalFormulaPin`)
 * is self-contained: its `components` array carries each food's per-serving
 * macros, so it can be emitted as a phase's foods with NO food-pool lookup.
 *
 * Honor policy mirrors system-template pins (locked 2026-05-21): an in-scope
 * pin is honored unconditionally (bypasses allergen / diet / dislike filters
 * and scaling). Fall through to normal selection only when no pin matches the
 * workout's scope.
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
 * Render a pinned personal formula's components into the phase's
 * [FoodResult] list, using the per-serving macros snapshotted on each
 * component. No food-pool lookup.
 */
export function personalFormulaToFoodResults(
  pin: PersonalFormulaPin,
  timing: string,
): FoodResult[] {
  const out: FoodResult[] = [];
  for (const c of pin.components) {
    const qty = typeof c.quantity === "number" ? c.quantity : 1;
    if (qty <= 0) continue;
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
