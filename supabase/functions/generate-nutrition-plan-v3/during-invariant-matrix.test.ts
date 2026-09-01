/**
 * During Phase — Macro-Target Invariant Matrix
 *
 * THE invariant of bug 3a3e3fdb (Critical, prod 1.21.1): for every combination
 * of activity × duration × gut level × preference profile, a generated during
 * phase must satisfy exactly one of:
 *
 *   (a) delivered carbs ≥ 90% of the carb target, OR
 *   (b) the result carries a `shortfalls` entry for carbs.
 *
 * A plan may be honestly short (empty pool, gut caps binding) — it may never
 * be SILENTLY short. Also locks the guard regression: a null or invalid
 * (`'medium'`) gut_training_level must not skip the template/formula tier.
 *
 * Runs the REAL `generateDuringPhase` cascade against a fake Supabase client
 * serving fixture catalog rows — no network.
 *
 * Run with:
 *   deno test --allow-write --node-modules-dir=none \
 *     supabase/functions/generate-nutrition-plan-v3/during-invariant-matrix.test.ts
 */

import {
  assert,
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import { generateDuringPhase } from "./during-phase.ts";
import { gapFillDuringCarbs } from "../_shared/nutrition/during-gap-fill.ts";
import type { FoodWithConstraints } from "../_shared/nutrition/during-template-solver.ts";
import { calculateTotals } from "../_shared/nutrition/food-utils.ts";
import type { MacroTargets } from "../_shared/nutrition/types.ts";
import { buildFoodResult } from "../_shared/nutrition/during-utils.ts";

import { fakeSupabase } from "../_shared/nutrition/test-fake-supabase.ts";

// ============================================================================
// Fixtures (DB row shape — the loaders do the mapping)
// ============================================================================

function dbFood(
  over: Partial<Record<string, unknown>> & { name: string },
): Record<string, unknown> {
  return {
    id: `id-${over.name}`,
    display_name: over.name,
    display_name_plural: null,
    description: null,
    image_address: null,
    calories: 100,
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 0,
    fluid_ml: 0,
    serving_amount: 1,
    serving_size: "1",
    serving_unit: "serving",
    serving_qualifier: null,
    max_servings_before: 10,
    max_servings_during: 12,
    max_servings_after: 10,
    min_servings_during: 1,
    is_electrolyte: false,
    to_exclude_from_solver: false,
    is_essential: false,
    is_indivisible: true,
    is_active: true,
    categories: ["during_run", "during_ride"],
    activity_types: ["running", "cycling"],
    is_liquid: false,
    product_type: "gel",
    default_during: true,
    allergens: [],
    excluded_diets: [],
    max_per_hr_low: 1,
    max_per_hr_moderate: 2,
    max_per_hr_high: 3,
    min_increment: null,
    sodium_top_up_eligible: null,
    ...over,
  };
}

function standardCatalog(): Record<string, unknown>[] {
  return [
    dbFood({
      name: "energy_gel",
      carbs_g: 25,
      sodium_mg: 50,
      product_type: "gel",
      max_per_hr_low: 2,
      max_per_hr_moderate: 3,
      max_per_hr_high: 4,
    }),
    dbFood({
      name: "sports_drink",
      carbs_g: 21,
      sodium_mg: 300,
      fluid_ml: 500,
      product_type: "sports_drink",
      is_liquid: true,
      is_indivisible: false,
      min_increment: 0.5,
      max_per_hr_low: 1,
      max_per_hr_moderate: 2,
      max_per_hr_high: 2,
    }),
    dbFood({
      name: "water",
      fluid_ml: 500,
      calories: 0,
      product_type: "beverage",
      is_liquid: true,
      is_essential: true,
      is_indivisible: false,
      min_increment: 0.5,
      max_per_hr_low: null,
      max_per_hr_moderate: null,
      max_per_hr_high: null,
    }),
    dbFood({
      name: "salt_tab",
      carbs_g: 1,
      sodium_mg: 200,
      calories: 5,
      product_type: "supplement",
      is_electrolyte: true,
      sodium_top_up_eligible: true,
      max_per_hr_low: null,
      max_per_hr_moderate: null,
      max_per_hr_high: null,
    }),
  ];
}

function dbTemplate(
  over: Partial<Record<string, unknown>> & { template_number: number },
): Record<string, unknown> {
  return {
    id: `tpl-${over.template_number}`,
    name: `Template ${over.template_number}`,
    formula: "gel + drink",
    food_form: "mixed",
    activity_types: ["running", "cycling"],
    duration_brackets: ["< 90 min", "90-150 min", "150-240 min", "> 240 min"],
    gut_training_levels: ["low", "moderate", "high"],
    component_food_names: ["energy_gel", "sports_drink", "water"],
    component_carb_ratios: { energy_gel: 0.6, sports_drink: 0.4 },
    primary_to_secondary_ratio: null,
    allergens: [],
    excluded_diets: [],
    notes: null,
    is_active: true,
    selection_priority: 10,
    ...over,
  };
}

function standardTables(): Record<string, Record<string, unknown>[]> {
  return {
    during_workout_templates: [dbTemplate({ template_number: 1 })],
    template_foods: standardCatalog(),
  };
}

/** Hour-scaled targets: 60 g/hr carbs, 500 mg/hr sodium, 500 ml/hr fluid. */
function targetsFor(durationMinutes: number): MacroTargets {
  const hours = durationMinutes / 60;
  return {
    carbs_g: Math.round(60 * hours),
    sodium_mg: Math.round(500 * hours),
    water_ml: Math.round(500 * hours),
  };
}

/** The invariant: on target, or honestly reported short. */
function assertCarbInvariant(
  // deno-lint-ignore no-explicit-any
  result: any,
  targets: MacroTargets,
  label: string,
) {
  const totals = calculateTotals(result.foods);
  const onTarget = totals.carbs_g >= targets.carbs_g * 0.9 - 1e-6;
  const reported = (result.shortfalls ?? []).some(
    // deno-lint-ignore no-explicit-any
    (s: any) => s.macro === "carbs",
  );
  assert(
    onTarget || reported,
    `${label}: SILENT carb miss — delivered ${totals.carbs_g.toFixed(1)}g ` +
      `of ${targets.carbs_g}g with no carbs shortfall reported`,
  );
  // And never grossly over: the solvers/gap-fill must respect the upper band.
  assert(
    targets.carbs_g <= 0 || totals.carbs_g <= targets.carbs_g * 1.3 + 1e-6,
    `${label}: carbs ${totals.carbs_g.toFixed(1)}g exceed 130% of ` +
      `${targets.carbs_g}g target`,
  );
}

// ============================================================================
// Suite 1 — Full matrix: activity × duration × gut level
// ============================================================================

describe("Invariant matrix — activity × duration × gut level", () => {
  const activities = ["running", "cycling"] as const;
  const durations = [45, 90, 180, 300];
  const gutLevels: (string | undefined)[] = [
    undefined, // profile not loaded — Failure Mode A trigger
    "low",
    "moderate",
    "high",
    "medium", // legacy invalid literal shipped in 1.21.1
  ];

  for (const activity of activities) {
    for (const duration of durations) {
      for (const gut of gutLevels) {
        it(`${activity} / ${duration}min / gut=${gut ?? "null"}`, async () => {
          const targets = targetsFor(duration);
          const result = await generateDuringPhase(
            fakeSupabase(standardTables()),
            targets,
            activity,
            undefined,
            undefined,
            undefined,
            undefined,
            undefined,
            undefined,
            gut,
            duration,
          );
          assertCarbInvariant(
            result,
            targets,
            `${activity}/${duration}min/gut=${gut ?? "null"}`,
          );
        });
      }
    }
  }
});

// ============================================================================
// Suite 2 — Guard regression: gut level must never disable the formula tier
// ============================================================================

describe("Guard regression — null/invalid gut level still runs templates", () => {
  for (const gut of [undefined, "medium", "moderate"]) {
    it(`gut=${gut ?? "null"} → template tier runs (template_metadata present)`, async () => {
      const targets = targetsFor(120);
      const result = await generateDuringPhase(
        fakeSupabase(standardTables()),
        targets,
        "running",
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        gut,
        120,
      );
      assertExists(
        result.template_metadata,
        `gut=${gut ?? "null"} must reach the template solver — its absence ` +
          `means the formula tier was skipped (bug 3a3e3fdb Failure Mode A)`,
      );
      assertEquals(result.generation_path, "template");
    });
  }

  it("no duration → template tier skipped but invariant still holds", async () => {
    const targets = targetsFor(90);
    const result = await generateDuringPhase(
      fakeSupabase(standardTables()),
      targets,
      "running",
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      "moderate",
      undefined, // no duration_minutes
    );
    assertEquals(result.generation_path, "rule");
    assertCarbInvariant(result, targets, "no-duration rule path");
  });
});

// ============================================================================
// Suite 3 — Preference collapse: dislikes can empty the carb pool,
// but never silently (the 8g-salt-tab disaster)
// ============================================================================

describe("Preference collapse — all carb sources disliked", () => {
  it("reports a carbs shortfall instead of shipping a silent near-zero plan", async () => {
    const targets = targetsFor(120);
    const result = await generateDuringPhase(
      fakeSupabase(standardTables()),
      targets,
      "running",
      undefined,
      undefined,
      ["energy_gel", "sports_drink"], // every carb source disliked
      undefined,
      undefined,
      undefined,
      "moderate",
      120,
    );
    const totals = calculateTotals(result.foods);
    assert(
      totals.carbs_g < targets.carbs_g * 0.9,
      "fixture error: expected the disliked pool to be carb-starved",
    );
    const carbShortfall = (result.shortfalls ?? []).find(
      (s) => s.macro === "carbs",
    );
    assertExists(
      carbShortfall,
      "carb-starved plan MUST carry a carbs shortfall on the wire",
    );
    assertEquals(carbShortfall.reason, "all_disliked");
  });

  it("empty catalog → empty foods + full shortfall set", async () => {
    const targets = targetsFor(90);
    const result = await generateDuringPhase(
      fakeSupabase({ during_workout_templates: [], template_foods: [] }),
      targets,
      "running",
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      undefined,
      "moderate",
      90,
    );
    assertEquals(result.foods.length, 0);
    assertEquals(result.generation_path, "empty");
    const macros = (result.shortfalls ?? []).map((s) => s.macro).sort();
    assertEquals(macros, ["carbs", "fluid", "sodium"]);
  });
});

// ============================================================================
// Suite 4 — Gap-fill unit behavior
// ============================================================================

function constrainedFood(
  over: Partial<FoodWithConstraints> & { name: string },
): FoodWithConstraints {
  return {
    id: `id-${over.name}`,
    display_name: over.name,
    display_name_plural: null,
    description: null,
    image_address: null,
    serving_size: null,
    serving_unit: null,
    serving_qualifier: null,
    per_serving: {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      water_ml: 0,
      calories: 0,
    },
    serving_amount: 1,
    min_servings: 1,
    max_servings: 12,
    preference_score: 50,
    is_electrolyte: false,
    is_liquid: false,
    is_essential: false,
    is_user_food: false,
    is_indivisible: true,
    product_type: "gel",
    max_per_hr_low: 2,
    max_per_hr_moderate: 3,
    max_per_hr_high: 4,
    min_increment: null,
    sodium_top_up_eligible: null,
    ...over,
  } as FoodWithConstraints;
}

describe("Gap-fill unit behavior", () => {
  const gel = constrainedFood({
    name: "gel",
    per_serving: {
      carbs_g: 25,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 50,
      water_ml: 0,
      calories: 100,
    },
  });
  const targets: MacroTargets = {
    carbs_g: 120,
    sodium_mg: 10000, // wide-open sodium/fluid bands: carbs are under test
    water_ml: 10000,
  };

  it("tops up an existing item to the carb TARGET, not the 90% line", () => {
    const current = [buildFoodResult(gel, 2)]; // 50g of 120g target
    const out = gapFillDuringCarbs(current, [gel], targets, 120, "moderate");
    assert(out.applied, "fill must apply on a 42% delivery");
    const totals = calculateTotals(out.foods);
    assert(
      totals.carbs_g >= 120 - 2,
      `expected ≥118g (target − rounding slack) after fill, got ${totals.carbs_g}g`,
    );
    assertEquals(out.foods.length, 1, "top-up must not add a duplicate item");
  });

  it("REGRESSION: a plan at 93% of target still gets filled to target", () => {
    // The old fill anchored on the 90% shortfall line: 112.5g of 120g (94%)
    // was "good enough" and every gap-filled plan settled ~10% short. The
    // target is the goal; the range is a reporting band (Lee, 2026-08-06).
    // A half-serving increment food, so the [118, 132]g window is reachable —
    // with whole 25g gels it wouldn't be, and staying short is correct.
    const halfGel = constrainedFood({
      name: "gel",
      is_indivisible: false,
      min_increment: 0.5,
      per_serving: {
        carbs_g: 25,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 50,
        water_ml: 0,
        calories: 100,
      },
    });
    const current = [buildFoodResult(halfGel, 4.5)]; // 112.5g of 120g
    const out = gapFillDuringCarbs(current, [halfGel], targets, 120, "moderate");
    assert(out.applied, "fill must apply below target − slack");
    const totals = calculateTotals(out.foods);
    assert(
      totals.carbs_g >= 120 - 2,
      `expected ≥118g after fill, got ${totals.carbs_g}g — the fill stopped ` +
        `short of the point target again`,
    );
    assert(
      totals.carbs_g <= 120 * 1.1 + 1e-6,
      `fill overshot the upper band: ${totals.carbs_g}g > 132g`,
    );
  });

  it("respects the gut-training per-hour cap (low gut stays short + honest)", () => {
    const current = [buildFoodResult(gel, 2)];
    // low gut: 2/hr × 2hr = 4 servings cap → only +2 possible → 100g < 108g
    const out = gapFillDuringCarbs(current, [gel], targets, 120, "low");
    const totals = calculateTotals(out.foods);
    assert(
      totals.carbs_g <= 4 * 25 + 1e-6,
      `low-gut cap violated: ${totals.carbs_g}g from a 4-serving cap`,
    );
  });

  it("no-op when already at/above the target", () => {
    const current = [buildFoodResult(gel, 5)]; // 125g ≥ 118g (target − slack)
    const out = gapFillDuringCarbs(current, [gel], targets, 120, "moderate");
    assertEquals(out.applied, false);
    assertEquals(out.addedCarbs, 0);
  });

  it("never fills from electrolyte/hydration incidental carbs", () => {
    const saltTab = constrainedFood({
      name: "salt_tab",
      is_electrolyte: true,
      product_type: "supplement",
      per_serving: {
        carbs_g: 1,
        protein_g: 0,
        fat_g: 0,
        sodium_mg: 200,
        water_ml: 0,
        calories: 5,
      },
    });
    const out = gapFillDuringCarbs([], [saltTab], targets, 120, "moderate");
    assertEquals(
      out.applied,
      false,
      "salt tabs must never be a carb source (the 8g disaster)",
    );
  });
});
