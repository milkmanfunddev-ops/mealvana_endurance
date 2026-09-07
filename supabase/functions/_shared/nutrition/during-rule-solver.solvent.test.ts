/**
 * §6(e) pick-time solvent feasibility — the S29 regression pair.
 *
 * Twin test: test/features/nutrition_plan/application/during_solvent_pick_test.dart
 * runs the SAME fixture through the Dart solver and pins the SAME invariant
 * (§8 — one rule, both engines). The fixture mirrors the run/run brick
 * segment (Lee's 2026-09-03 screenshot, reproduced on dev): 60-min run,
 * carbs 53 / sodium 331 / fluid 401 [341, 461], real catalog numbers.
 *
 * The invariant (not a byte-pin — the rule solver's picks are weighted-
 * random): every plate the solver emits leaves the §6(e) backstop FEASIBLE —
 *   solventRequirement(plate) ≤ plainWater(plate) + (fluidUpper − totalFluid)
 * — and the pairing pass then finishes without a fluid_ceiling conflict, so
 * a concentrated mix can never ship without the water to dissolve it.
 */

import { assert, assertEquals } from "https://deno.land/std@0.177.1/testing/asserts.ts";
import { generateDuringPhaseRuleBased } from "./during-rule-solver.ts";
import {
  ensureElectrolyteWaterPairing,
  plainWaterMl,
  solventRequirementMl,
} from "./electrolyte-water-pairing.ts";
import type { Food, MacroTargets } from "./types.ts";

function food(p: Partial<Food> & { id: string }): Food {
  return {
    name: p.id,
    display_name: p.id,
    display_name_plural: null,
    description: null,
    image_address: null,
    per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 0, calories: 0 },
    serving_amount: 1,
    min_servings: 0.5,
    max_servings: 10,
    preference_score: 50,
    is_electrolyte: false,
    is_liquid: false,
    is_essential: false,
    is_user_food: false,
    is_indivisible: false,
    ...p,
  } as Food;
}

// Real catalog shapes (dev rows, 2026-09-03).
const POOL: Food[] = [
  food({ id: "carb_drink_mix", product_type: "drink_mix", is_liquid: true,
    per_serving: { carbs_g: 60, protein_g: 0, fat_g: 0, sodium_mg: 160, water_ml: 0, calories: 240 },
    min_servings: 0.5, max_servings: 10, solvent_min_ml: 475 }),
  food({ id: "energy_gel", product_type: "gel", is_indivisible: true, min_servings: 1,
    per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 55, water_ml: 20, calories: 100 },
    max_servings: 15, solvent_min_ml: 150 }),
  food({ id: "energy_chews", product_type: "chew", is_indivisible: true, min_servings: 1,
    per_serving: { carbs_g: 25, protein_g: 0, fat_g: 0, sodium_mg: 80, water_ml: 0, calories: 100 },
    max_servings: 10 }),
  food({ id: "sports_drink", product_type: "sports_drink", is_liquid: true,
    per_serving: { carbs_g: 15, protein_g: 0, fat_g: 0, sodium_mg: 100, water_ml: 240, calories: 60 },
    max_servings: 20 }),
  food({ id: "water", product_type: "beverage", is_liquid: true,
    per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 0, water_ml: 240, calories: 0 },
    max_servings: 14 }),
  food({ id: "electrolyte_capsule", product_type: "supplement", is_indivisible: true, min_servings: 1,
    per_serving: { carbs_g: 0, protein_g: 0, fat_g: 0, sodium_mg: 190, water_ml: 0, calories: 0 },
    max_servings: 8 }),
];

const TARGETS: MacroTargets = {
  carbs_g: 53,
  carbs_low_g: 47.7,
  carbs_high_g: 58.3,
  protein_g: 0,
  sodium_mg: 331,
  sodium_low_mg: 298,
  sodium_high_mg: 364,
  water_ml: 401,
  water_low_ml: 341,
  water_high_ml: 461,
} as MacroTargets;

Deno.test("§6(e): every rule-solver plate leaves the solvent backstop feasible (25 runs)", () => {
  for (let i = 0; i < 25; i++) {
    const res = generateDuringPhaseRuleBased(POOL, TARGETS, "running", 60, "moderate");
    const totalFluid = res.foods.reduce((s, f) => s + (f.fluids_ml || 0), 0);
    const headroom = Math.max(0, 461 - totalFluid);
    const requirement = solventRequirementMl(res.foods);
    const plain = plainWaterMl(res.foods);
    assert(
      requirement <= plain + headroom + 1e-6,
      `run ${i}: requirement ${requirement} > plain ${plain} + headroom ${headroom} — ` +
        `plate: ${res.foods.map((f) => `${f.food_id} x${f.quantity}`).join(", ")}`,
    );

    // And the backstop actually finishes the job: no ceiling conflict, and
    // the requirement is met by plain water after the pass.
    const paired = ensureElectrolyteWaterPairing(res.foods, [POOL[4]], {
      timing: "t",
      logPrefix: "[TEST]",
      fluidCeilingMl: 461,
    });
    assertEquals(
      paired.conflict,
      null,
      `run ${i}: pairing conflict ${JSON.stringify(paired.conflict)} — ` +
        `plate: ${res.foods.map((f) => `${f.food_id} x${f.quantity} fl=${f.fluids_ml}`).join(", ")}`,
    );
    // Post-pass the declared requirement is met, or the shortfall is below
    // the meaningful-pairing minimum next to plain water already on the
    // plate (the spec's solvent lines are approximate — "gels chase ~150").
    const owed = solventRequirementMl(paired.foods) -
      plainWaterMl(paired.foods);
    assert(
      owed <= 1e-6 || (owed < 100 && plainWaterMl(paired.foods) > 0),
      `run ${i}: post-pairing plate owes ${owed}ml solvent water — ` +
        `plate: ${paired.foods.map((f) => `${f.food_id} x${f.quantity}`).join(", ")}`,
    );
  }
});
