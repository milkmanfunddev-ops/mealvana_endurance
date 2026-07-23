/**
 * During Phase — Remote Invariant E2E
 *
 * Calls the DEPLOYED generate-nutrition-plan-v3 function and asserts the
 * bug-3a3e3fdb contract against the live catalog: for carbs, sodium, and
 * fluid — delivered ≥ 90% of target OR a shortfall for that macro is present
 * in `plan.during.shortfalls`. Includes the failure modes that caused the
 * prod bug: missing gut level, the legacy invalid `'medium'` literal, and a
 * preference profile that guts the carb pool.
 *
 * Complements strict-macro-e2e.test.ts (happy-path zero-tolerance bands via
 * generate-macros-v4); this suite targets the plan function directly with
 * hand-built targets so the failure-mode matrix is exact.
 *
 * Requires:
 *   export SUPABASE_URL=...        (dev or prod project)
 *   export SUPABASE_ANON_KEY=...
 * Run with:
 *   deno test --allow-net --allow-env \
 *     supabase/functions/generate-nutrition-plan-v3/during-invariant-remote-e2e.test.ts
 */

import {
  assert,
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") || "";
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") || "";
const PLAN_URL = `${SUPABASE_URL}/functions/v1/generate-nutrition-plan-v3`;

if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
  throw new Error(
    "SUPABASE_URL and SUPABASE_ANON_KEY must be set for remote E2E tests",
  );
}

interface DuringTargets {
  carbs_g: number;
  sodium_mg: number;
  water_ml: number;
}

function targetsFor(
  carbsPerHr: number,
  sodiumPerHr: number,
  fluidPerHr: number,
  durationMinutes: number,
): DuringTargets {
  const h = durationMinutes / 60;
  return {
    carbs_g: Math.round(carbsPerHr * h),
    sodium_mg: Math.round(sodiumPerHr * h),
    water_ml: Math.round(fluidPerHr * h),
  };
}

async function generatePlan(body: Record<string, unknown>) {
  const res = await fetch(PLAN_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${SUPABASE_ANON_KEY}`,
      apikey: SUPABASE_ANON_KEY,
    },
    body: JSON.stringify(body),
  });
  assertEquals(res.status, 200, `plan-v3 HTTP ${res.status}`);
  return await res.json();
}

function basePayload(
  activity: string,
  duration: number | undefined,
  during: DuringTargets,
  extra: Record<string, unknown> = {},
): Record<string, unknown> {
  return {
    device_id: `e2e-invariant-${crypto.randomUUID()}`,
    activity_type: activity,
    hours_before: 2,
    weight_kg: 70,
    macro_targets: {
      pre_run: { carbs_g: 80, protein_g: 15, sodium_mg: 500, water_ml: 500 },
      during_run: during,
      post_run: { carbs_g: 60, protein_g: 25, sodium_mg: 400, water_ml: 600 },
    },
    ...(duration !== undefined && { duration_minutes: duration }),
    ...extra,
  };
}

// deno-lint-ignore no-explicit-any
function duringTotals(planData: any) {
  // deno-lint-ignore no-explicit-any
  const foods = (planData.plan?.during?.foods ?? []) as any[];
  return {
    carbs_g: foods.reduce((s, f) => s + (f.carbs_grams ?? 0), 0),
    sodium_mg: foods.reduce((s, f) => s + (f.sodium_mg ?? 0), 0),
    water_ml: foods.reduce((s, f) => s + (f.fluids_ml ?? 0), 0),
    foods,
  };
}

// deno-lint-ignore no-explicit-any
function assertDuringInvariant(planData: any, t: DuringTargets, label: string) {
  const totals = duringTotals(planData);
  const shortfalls = new Set(
    // deno-lint-ignore no-explicit-any
    (planData.plan?.during?.shortfalls ?? []).map((s: any) => s.macro),
  );
  const checks: Array<[string, number, number]> = [
    ["carbs", totals.carbs_g, t.carbs_g],
    ["sodium", totals.sodium_mg, t.sodium_mg],
    ["fluid", totals.water_ml, t.water_ml],
  ];
  for (const [macro, delivered, target] of checks) {
    if (target <= 0) continue;
    assert(
      delivered >= target * 0.9 - 1e-6 || shortfalls.has(macro),
      `${label}: SILENT ${macro} miss — ${delivered.toFixed(1)} of ${target}, ` +
        `shortfalls=${JSON.stringify(planData.plan?.during?.shortfalls ?? [])}`,
    );
  }
  // The prod symptom itself: a meaningful carb target must never yield a
  // near-zero-carb plan without a carbs shortfall on the wire.
  if (t.carbs_g >= 30 && totals.carbs_g < 10) {
    assert(
      shortfalls.has("carbs"),
      `${label}: near-zero carbs (${totals.carbs_g}g of ${t.carbs_g}g) unreported`,
    );
  }
}

describe("Remote invariant — deployed generate-nutrition-plan-v3", () => {
  const matrix: Array<{
    key: string;
    activity: string;
    duration?: number;
    gut?: string;
    perHr: [number, number, number];
    extra?: Record<string, unknown>;
  }> = [
    // The Failure-Mode-A triggers — these produced the 8g disaster in prod:
    { key: "run-90-no-gut", activity: "running", duration: 90, perHr: [60, 500, 500] },
    { key: "run-90-medium-gut", activity: "running", duration: 90, gut: "medium", perHr: [60, 500, 500] },
    // Normal levels across activities and durations:
    { key: "run-60-low", activity: "running", duration: 60, gut: "low", perHr: [45, 450, 450] },
    { key: "run-150-moderate", activity: "running", duration: 150, gut: "moderate", perHr: [60, 500, 500] },
    { key: "ride-120-moderate", activity: "cycling", duration: 120, gut: "moderate", perHr: [75, 600, 600] },
    { key: "ride-300-high", activity: "cycling", duration: 300, gut: "high", perHr: [90, 800, 700] },
    { key: "tri-200-moderate", activity: "triathlon", duration: 200, gut: "moderate", perHr: [65, 550, 550] },
    // Body-size extremes (gender/weight proxy at the plan-function boundary):
    { key: "run-120-light-athlete", activity: "running", duration: 120, gut: "moderate", perHr: [40, 400, 400] },
    { key: "ride-240-heavy-athlete", activity: "cycling", duration: 240, gut: "high", perHr: [100, 900, 800] },
    // No duration at all (legacy client shape):
    { key: "run-no-duration", activity: "running", gut: "moderate", perHr: [60, 500, 500] },
    // Preference collapse — dislikes gut the carb pool:
    {
      key: "run-120-carbs-disliked",
      activity: "running",
      duration: 120,
      gut: "moderate",
      perHr: [60, 500, 500],
      extra: {
        disliked_foods: [
          "energy_gel",
          "energy_chews",
          "sports_drink",
          "high_carb_drink_mix",
          "banana",
          "stroopwafel",
          "energy_bar",
        ],
      },
    },
    // Hard dietary constraints:
    {
      key: "ride-180-vegan-gf",
      activity: "cycling",
      duration: 180,
      gut: "moderate",
      perHr: [70, 600, 600],
      extra: { dietary_preference: "vegan", allergies: ["gluten"] },
    },
  ];

  for (const c of matrix) {
    it(c.key, async () => {
      const during = targetsFor(...c.perHr, c.duration ?? 60);
      const planData = await generatePlan(basePayload(
        c.activity,
        c.duration,
        during,
        { ...(c.gut !== undefined && { gut_training_level: c.gut }), ...c.extra },
      ));
      assertEquals(planData.success, true, `${c.key}: success flag`);
      assertExists(planData.plan?.during, `${c.key}: during section`);
      assertDuringInvariant(planData, during, c.key);
    });
  }

  it("swimming has no during phase (contract unchanged)", async () => {
    const during = targetsFor(0, 0, 0, 60);
    const planData = await generatePlan(
      basePayload("swimming", 60, during, { gut_training_level: "moderate" }),
    );
    assertEquals(planData.plan?.during?.foods?.length ?? 0, 0);
  });
});
