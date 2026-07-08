/**
 * Pin-override shortfall tests for `generateDuringPhaseTemplate`.
 *
 * Regression for: "Pinned drink-only formula not scheduled for sub-90-min runs
 * — 'ingredient not available' despite pin" (Bug 395e3fdb).
 *
 * Root cause: a pinned "Sports Drink Only" template can't meet the carb target
 * on a short run because the drink is capped by max-servings-per-hour. The
 * solver's macro-validation gate returned null (carb ratio < 0.9), the
 * orchestrator downgraded the pin to `pinned_template_unrenderable`, and the UI
 * showed a misleading "Pin ingredient unavailable" banner.
 *
 * Fix: a `pinOverride` flag decouples "accept a macro shortfall" from "user has
 * dislikes". A pin-selected template now renders a best-effort result and
 * reports the shortfall instead of returning null. Non-pinned candidates keep
 * the old behavior (null → try next template).
 *
 * Run with:
 *   deno test --no-check --allow-all \
 *     supabase/functions/_shared/nutrition/during-template-pinoverride.test.ts
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  type DuringWorkoutTemplate,
  type FoodWithConstraints,
  generateDuringPhaseTemplate,
} from "./during-template-solver.ts";
import type { MacroTargets } from "./types.ts";
import { makeFood } from "./test-utils.ts";

// ---------------------------------------------------------------------------
// Fixtures — a drink-only template whose only food is capped below target.
// ---------------------------------------------------------------------------

function drinkOnlyTemplate(): DuringWorkoutTemplate {
  return {
    id: "template-5",
    template_number: 5,
    name: "Sports Drink Only",
    formula: "Sports Drink Only",
    food_form: "Liquid",
    activity_types: ["running"],
    duration_brackets: ["< 90 min"],
    gut_training_levels: ["low", "moderate", "high"],
    component_food_names: ["sports_drink"],
    component_carb_ratios: { sports_drink: 1.0 },
    primary_to_secondary_ratio: null,
    allergens: [],
    excluded_diets: [],
    notes: null,
    is_active: true,
    selection_priority: 1,
  };
}

/** Sports drink capped at 2 servings/hr → 30g carbs max on a 60-min run. */
function drinkOnlyPool(): Map<string, FoodWithConstraints> {
  const pool = new Map<string, FoodWithConstraints>();
  const base = makeFood({
    id: "sports_drink",
    name: "sports_drink",
    display_name: "Sports Drink",
    per_serving: {
      carbs_g: 15,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 110,
      water_ml: 240,
      calories: 60,
    },
    product_type: "sports_drink",
    is_liquid: true,
    min_servings: 1,
    max_servings: 6,
  });
  pool.set("sports_drink", {
    ...base,
    max_per_hr_low: 2,
    max_per_hr_moderate: 2,
    max_per_hr_high: 3,
    min_increment: 1,
    sodium_top_up_eligible: null,
  });
  return pool;
}

// 60-min run, 40g carb target — unreachable (2 servings × 15g = 30g → 0.75).
const targets: MacroTargets = {
  carbs_g: 40,
  sodium_mg: 200,
  water_ml: 400,
};

describe("generateDuringPhaseTemplate pin-override shortfall", () => {
  it("returns null WITHOUT pin override when carb target is unreachable (legacy behavior)", () => {
    const result = generateDuringPhaseTemplate(
      drinkOnlyTemplate(),
      drinkOnlyPool(),
      targets,
      60,
      "low",
      new Set<string>(), // no dislikes
      // pinOverride omitted → false
    );
    assertEquals(
      result,
      null,
      "Non-pinned candidate that misses the carb target should return null so the next template is tried",
    );
  });

  it("returns a best-effort result WITH a reported shortfall when pinOverride is true", () => {
    const result = generateDuringPhaseTemplate(
      drinkOnlyTemplate(),
      drinkOnlyPool(),
      targets,
      60,
      "low",
      new Set<string>(), // still no dislikes — shortfall is allowed purely by the pin
      true, // pinOverride
    );

    assert(
      result !== null,
      "Pinned drink-only template must render (not null) even though it can't meet the carb target",
    );
    assert(
      result!.foods.length > 0,
      "Rendered plan should include the pinned drink",
    );
    assert(
      result!.shortfalls !== undefined && result!.shortfalls.length > 0,
      "A carb shortfall should be reported to the UI",
    );
    const carbShortfall = result!.shortfalls!.find((s) => s.macro === "carbs");
    assert(carbShortfall !== undefined, "Expected a carb shortfall entry");
    assert(
      carbShortfall!.delivered < carbShortfall!.target,
      "Delivered carbs should be below target",
    );
    // With no dislikes, the shortfall cause is the template constraint, not prefs.
    assertEquals(
      carbShortfall!.reason,
      "template_constraint",
      "Shortfall reason should be template_constraint (max-per-hour cap), not all_disliked",
    );
  });
});
