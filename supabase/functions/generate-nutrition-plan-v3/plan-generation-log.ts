/**
 * Plan-generation ledger.
 *
 * One row per generated plan: targets vs delivered totals, the during-cascade
 * path taken, shortfalls, and pin decisions. Turns "fueling plans seem to miss
 * their carb target a lot" (Wiredash, bug 3a3e3fdb) into a measurable failure
 * rate, and proves fixes in prod without waiting for user reports.
 *
 * Writes are strictly best-effort: a ledger failure must never fail or delay
 * a plan response.
 */

import { createServiceClient } from "../_shared/supabase-client.ts";
import {
  calculateTotals,
  type FoodResult,
} from "../_shared/nutrition/index.ts";
import type { LPPhaseResult, PlanInputV2 } from "./types.ts";

export interface PlanGenerationLogRow {
  plan_id: string;
  device_id: string;
  activity_type: string;
  duration_minutes: number | null;
  gut_training_level: string | null;
  during_path: string | null;
  /** food-recommendation §10 (migration 20260903121000): before-phase
   * resolution, derived from the slot pin decisions + foods — the step
   * funnel's before leg. */
  before_path: string | null;
  /** After-phase generation_path (personal_formula / template / lp). */
  after_path: string | null;
  /** §10 test-traffic marker: the raw `x-mealvana-test` request header when
   * present, else null. Funnel queries exclude non-null rows. */
  source: string | null;
  /** Brick only: per-segment during generation paths, keyed by segment
   * order — without it brick cascade coverage is unmeasurable (bench
   * finding B-2). */
  during_segment_paths: Record<string, string | null> | null;
  targets: Record<string, unknown>;
  delivered: Record<string, unknown>;
  shortfalls: Record<string, unknown> | null;
  pin_decision: Record<string, unknown> | null;
  warnings: string[] | null;
}

/**
 * §10 funnel: derive the before-phase resolution from the per-slot results.
 * Order mirrors the §1 cascade — the phase records the HIGHEST face any slot
 * resolved at (a plan with one pinned slot and two default slots reads as
 * the pin step; the per-slot split stays derivable from pin_decision).
 */
export function deriveBeforePath(
  beforeResult: Record<
    string,
    { foods?: FoodResult[]; pin_decision?: Record<string, unknown> }
  > | null,
): string | null {
  if (!beforeResult) return null;
  const slots = Object.values(beforeResult);
  if (slots.length === 0) return null;
  let sawFoods = false;
  let sawUserPin = false;
  for (const slot of slots) {
    if ((slot.foods?.length ?? 0) > 0) sawFoods = true;
    const d = slot.pin_decision;
    if (!d || d.used_pin !== true || d.ephemeral === true) continue;
    if (d.decision_source === "personal_formula") return "personal_formula";
    sawUserPin = true;
  }
  if (sawUserPin) return "pinned_template";
  return sawFoods ? "template" : "empty";
}

function phaseTotals(foods: FoodResult[]): Record<string, number> {
  const t = calculateTotals(foods);
  return {
    carbs_g: Math.round(t.carbs_g * 10) / 10,
    protein_g: Math.round(t.protein_g * 10) / 10,
    sodium_mg: Math.round(t.sodium_mg),
    water_ml: Math.round(t.water_ml),
    food_count: foods.length,
  };
}

/** Pure row assembly — unit-testable without a Supabase client. */
export function buildPlanGenerationLogRow(params: {
  planId: string;
  input: PlanInputV2;
  activityType: string;
  beforeFoods: FoodResult[];
  duringResult: LPPhaseResult;
  afterResult: LPPhaseResult;
  warnings: string[];
  /** The raw sub-phase before result, for §10's before_path derivation. */
  beforeResult?: Record<
    string,
    { foods?: FoodResult[]; pin_decision?: Record<string, unknown> }
  > | null;
  /** §10 test-traffic marker (the `x-mealvana-test` request header). */
  testSource?: string | null;
  /** Brick: per-segment during generation paths, keyed by segment order. */
  duringSegmentPaths?: Record<string, string | null> | null;
}): PlanGenerationLogRow {
  const {
    planId,
    input,
    activityType,
    beforeFoods,
    duringResult,
    afterResult,
    warnings,
  } = params;

  const shortfalls: Record<string, unknown> = {};
  if (duringResult.shortfalls?.length) {
    shortfalls.during = duringResult.shortfalls;
  }
  if (afterResult.shortfalls?.length) shortfalls.after = afterResult.shortfalls;

  const pinDecision: Record<string, unknown> = {};
  if (duringResult.pin_decision) pinDecision.during = duringResult.pin_decision;
  if (afterResult.pin_decision) pinDecision.after = afterResult.pin_decision;

  return {
    plan_id: planId,
    device_id: input.device_id,
    activity_type: activityType,
    duration_minutes: input.duration_minutes ?? null,
    // Raw client value on purpose — lets us measure how often invalid/missing
    // levels arrive (the normalized value is derivable, the raw one is not).
    gut_training_level: input.gut_training_level ?? null,
    during_path: duringResult.generation_path ?? null,
    before_path: deriveBeforePath(params.beforeResult ?? null),
    after_path: afterResult.generation_path ?? null,
    source: params.testSource ?? null,
    during_segment_paths: params.duringSegmentPaths ?? null,
    targets: {
      pre_run: input.macro_targets.pre_run ?? null,
      during_run: input.macro_targets.during_run ?? null,
      post_run: input.macro_targets.post_run ?? null,
    },
    delivered: {
      before: phaseTotals(beforeFoods),
      during: phaseTotals(duringResult.foods),
      after: phaseTotals(afterResult.foods),
    },
    shortfalls: Object.keys(shortfalls).length > 0 ? shortfalls : null,
    pin_decision: Object.keys(pinDecision).length > 0 ? pinDecision : null,
    warnings: warnings.length > 0 ? warnings : null,
  };
}

/** Insert a ledger row. Never throws; failures are logged and swallowed. */
export async function insertPlanGenerationLog(
  supabase: ReturnType<typeof createServiceClient>,
  row: PlanGenerationLogRow,
): Promise<void> {
  try {
    const { error } = await supabase.from("plan_generation_log").insert(row);
    if (error) {
      console.warn("[PLAN-V3] plan_generation_log insert failed:", error);
    }
  } catch (err) {
    console.warn("[PLAN-V3] plan_generation_log insert threw:", err);
  }
}
