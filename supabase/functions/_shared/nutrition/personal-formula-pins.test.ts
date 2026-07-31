import { assertEquals } from "https://deno.land/std@0.177.1/testing/asserts.ts";
import {
  beforeSlotForSubPhase,
  collectPersonalFormulaSkips,
  carbScaleFactor,
  matchBeforePersonalFormulaForSlot,
  matchPersonalFormulaPin,
  personalFormulaToFoodResults,
} from "./personal-formula-pins.ts";
import type { PersonalFormulaPin } from "./pins.ts";

function pin(overrides: Partial<PersonalFormulaPin>): PersonalFormulaPin {
  return {
    id: "f1",
    name: "Test formula",
    phase: "during",
    activities: null,
    durations: null,
    subPhase: null,
    components: [],
    ...overrides,
  };
}

Deno.test("before pin matches on phase only (no activity scope)", () => {
  const f = pin({ phase: "before", activities: ["cycling"] });
  assertEquals(matchPersonalFormulaPin([f], "before", "running")?.id, "f1");
});

Deno.test("during pin requires activity overlap", () => {
  const f = pin({ phase: "during", activities: ["cycling"] });
  assertEquals(matchPersonalFormulaPin([f], "during", "running", 120), null);
  assertEquals(
    matchPersonalFormulaPin([f], "during", "cycling", 120)?.id,
    "f1",
  );
});

Deno.test("during pin requires duration-bracket membership when set", () => {
  const f = pin({ phase: "during", durations: ["> 240 min"] });
  // 120 min → "90-150 min" bracket, not in scope
  assertEquals(matchPersonalFormulaPin([f], "during", "running", 120), null);
  // 300 min → "> 240 min", in scope
  assertEquals(
    matchPersonalFormulaPin([f], "during", "running", 300)?.id,
    "f1",
  );
});

Deno.test("null activities/durations = any", () => {
  const f = pin({ phase: "during" });
  assertEquals(
    matchPersonalFormulaPin([f], "during", "running", 60)?.id,
    "f1",
  );
});

Deno.test("multisport activity matches sub-activity-scoped during pin", () => {
  const f = pin({ phase: "during", activities: ["triathlon_bike"] });
  assertEquals(
    matchPersonalFormulaPin([f], "during", "triathlon", 200)?.id,
    "f1",
  );
});

Deno.test("after pin matches on activity only (ignores duration)", () => {
  const f = pin({ phase: "after", activities: ["running"] });
  assertEquals(matchPersonalFormulaPin([f], "after", "running")?.id, "f1");
  assertEquals(matchPersonalFormulaPin([f], "after", "cycling"), null);
});

Deno.test("components render to FoodResults with per-serving × quantity", () => {
  const f = pin({
    components: [
      {
        food_id: "banana",
        food_name: "Banana",
        quantity: 2,
        serving_unit: "medium",
        source: "template",
        carbs_per_serving: 27,
        protein_per_serving: 1.3,
        fat_per_serving: 0.4,
        sodium_mg: 1,
        fluid_ml_per_serving: 0,
        calories_per_serving: 105,
      },
    ],
  });
  const foods = personalFormulaToFoodResults(f, "Throughout activity");
  assertEquals(foods.length, 1);
  assertEquals(foods[0].food_id, "banana");
  assertEquals(foods[0].quantity, 2);
  assertEquals(foods[0].carbs_grams, 54); // 27 * 2
  assertEquals(foods[0].calories, 210); // 105 * 2
  assertEquals(foods[0].display_name, "Banana");
  assertEquals(foods[0].timing, "Throughout activity");
});

Deno.test("missing calories falls back to macro-derived estimate", () => {
  const f = pin({
    components: [
      {
        food_name: "Mystery",
        quantity: 1,
        carbs_per_serving: 10,
        protein_per_serving: 5,
        fat_per_serving: 2,
      },
    ],
  });
  const foods = personalFormulaToFoodResults(f, "x");
  // 10*4 + 5*4 + 2*9 = 78
  assertEquals(foods[0].calories, 78);
});

Deno.test("zero-quantity components are skipped", () => {
  const f = pin({
    components: [{ food_name: "Z", quantity: 0, carbs_per_serving: 10 }],
  });
  assertEquals(personalFormulaToFoodResults(f, "x").length, 0);
});

// ── During carb-target scaling (quantity-less by design, 2026-06-11) ──────

Deno.test("carbScaleFactor scales formula carbs to the target", () => {
  // 25g/serving gel × 1 + 0g water × 1 → 25g base; 100g target → k=4.
  const components = [
    { food_name: "Gel", quantity: 1, carbs_per_serving: 25 },
    { food_name: "Water", quantity: 1, carbs_per_serving: 0 },
  ];
  assertEquals(carbScaleFactor(components, 100), 4);
});

Deno.test("carbScaleFactor is 1 when target missing or formula carb-free", () => {
  const carby = [{ food_name: "Gel", quantity: 1, carbs_per_serving: 25 }];
  assertEquals(carbScaleFactor(carby, undefined), 1);
  assertEquals(carbScaleFactor(carby, 0), 1);
  // Water + electrolytes only — nothing to scale.
  const carbFree = [{ food_name: "Water", quantity: 2, carbs_per_serving: 0 }];
  assertEquals(carbScaleFactor(carbFree, 90), 1);
});

Deno.test("during scaling multiplies all components uniformly", () => {
  const f = pin({
    components: [
      { food_name: "Gel", quantity: 1, carbs_per_serving: 25, sodium_mg: 50 },
      {
        food_name: "Water",
        quantity: 1,
        carbs_per_serving: 0,
        fluid_ml_per_serving: 500,
      },
    ],
  });
  // base 25g, target 75g → k=3: 3 gels + 3 waters.
  const foods = personalFormulaToFoodResults(f, "Throughout activity", 75);
  assertEquals(foods[0].quantity, 3);
  assertEquals(foods[0].carbs_grams, 75);
  assertEquals(foods[0].sodium_mg, 150);
  assertEquals(foods[1].quantity, 3);
  assertEquals(foods[1].fluids_ml, 1500);
});

Deno.test("scaled quantities round to 0.5 steps and floor at 0.5", () => {
  const f = pin({
    components: [
      { food_name: "Drink mix", quantity: 1, carbs_per_serving: 90 },
      { food_name: "Chews", quantity: 1, carbs_per_serving: 0.5 },
    ],
  });
  // base 90.5g, target 60g → k≈0.663: 0.663 → 0.5 after rounding.
  const foods = personalFormulaToFoodResults(f, "x", 60);
  assertEquals(foods[0].quantity, 0.5);
  assertEquals(foods[1].quantity, 0.5);
});

Deno.test("no scaling argument leaves authored quantities verbatim", () => {
  const f = pin({
    components: [
      { food_name: "Bagel", quantity: 0.75, carbs_per_serving: 48 },
    ],
  });
  // Before/after path: exact authored quantity, no 0.5 rounding.
  const foods = personalFormulaToFoodResults(f, "x");
  assertEquals(foods[0].quantity, 0.75);
  assertEquals(foods[0].carbs_grams, 36);
});

// ── Before per-slot honoring ──────────────────────────────────────────────

Deno.test("beforeSlotForSubPhase maps timing tags to slots", () => {
  assertEquals(beforeSlotForSubPhase("full_meal"), "meal");
  assertEquals(beforeSlotForSubPhase("snack"), "snack");
  assertEquals(beforeSlotForSubPhase("top_up"), "top_up");
});

Deno.test("beforeSlotForSubPhase returns null for untagged / unknown", () => {
  assertEquals(beforeSlotForSubPhase(null), null);
  assertEquals(beforeSlotForSubPhase("whenever"), null);
});

Deno.test("before slot matcher returns the formula tagged for that slot", () => {
  const meal = pin({ id: "m", phase: "before", subPhase: "full_meal" });
  const snack = pin({ id: "s", phase: "before", subPhase: "snack" });
  const formulas = [meal, snack];
  assertEquals(matchBeforePersonalFormulaForSlot(formulas, "meal")?.id, "m");
  assertEquals(matchBeforePersonalFormulaForSlot(formulas, "snack")?.id, "s");
  // No top_up formula pinned → that slot stays algorithmic.
  assertEquals(matchBeforePersonalFormulaForSlot(formulas, "top_up"), null);
});

Deno.test("before slot matcher skips untagged before formulas", () => {
  const untagged = pin({ id: "u", phase: "before", subPhase: null });
  assertEquals(matchBeforePersonalFormulaForSlot([untagged], "meal"), null);
  assertEquals(matchBeforePersonalFormulaForSlot([untagged], "snack"), null);
  assertEquals(matchBeforePersonalFormulaForSlot([untagged], "top_up"), null);
});

Deno.test("before slot matcher ignores during/after pins", () => {
  const during = pin({ id: "d", phase: "during", subPhase: "snack" });
  assertEquals(matchBeforePersonalFormulaForSlot([during], "snack"), null);
});

Deno.test("before slot matcher returns first (newest) when multiple match", () => {
  const newer = pin({ id: "new", phase: "before", subPhase: "snack" });
  const older = pin({ id: "old", phase: "before", subPhase: "snack" });
  // pins.ts preserves updated_at DESC ordering → first wins.
  assertEquals(
    matchBeforePersonalFormulaForSlot([newer, older], "snack")?.id,
    "new",
  );
});

// ---------------------------------------------------------------------------
// collectPersonalFormulaSkips — audit 2026-07-18
//
// Regression cover for the reported bug: a cycling formula scoped to 90+ min
// was silently dropped on a 75-minute ride while an unrelated system pin was
// reported as honored. These assert the skip is explained rather than lost.
// ---------------------------------------------------------------------------

Deno.test("skips: duration miss is reported with both brackets", () => {
  const f = pin({
    phase: "during",
    activities: ["cycling"],
    durations: ["90-150 min", "150-240 min"],
    name: "Carb Drink Mix + Stroopwafel",
  });
  const skips = collectPersonalFormulaSkips([f], "during", "cycling", 75);
  assertEquals(skips.length, 1);
  assertEquals(skips[0].reason, "duration_out_of_scope");
  assertEquals(skips[0].name, "Carb Drink Mix + Stroopwafel");
  assertEquals(skips[0].workout_bracket, "< 90 min");
  assertEquals(skips[0].formula_durations, ["90-150 min", "150-240 min"]);
});

Deno.test("skips: activity miss is reported ahead of duration", () => {
  const f = pin({
    phase: "during",
    activities: ["running"],
    durations: ["90-150 min"],
  });
  const skips = collectPersonalFormulaSkips([f], "during", "cycling", 75);
  assertEquals(skips.length, 1);
  assertEquals(skips[0].reason, "activity_out_of_scope");
});

Deno.test("skips: nothing reported when the formula is in scope", () => {
  const f = pin({
    phase: "during",
    activities: ["cycling"],
    durations: ["90-150 min"],
  });
  // 100 min → "90-150 min" — matches, so there is nothing to explain.
  assertEquals(
    collectPersonalFormulaSkips([f], "during", "cycling", 100).length,
    0,
  );
});

Deno.test("skips: boundary at 90 matches matchPersonalFormulaPin exactly", () => {
  const f = pin({
    phase: "during",
    activities: ["cycling"],
    durations: ["90-150 min"],
  });
  // 89 → out of scope, 90 → in scope. The skip list must agree with the
  // matcher at the boundary or the banner would contradict the plan.
  assertEquals(matchPersonalFormulaPin([f], "during", "cycling", 89), null);
  assertEquals(
    collectPersonalFormulaSkips([f], "during", "cycling", 89).length,
    1,
  );
  assertEquals(
    matchPersonalFormulaPin([f], "during", "cycling", 90)?.id,
    "f1",
  );
  assertEquals(
    collectPersonalFormulaSkips([f], "during", "cycling", 90).length,
    0,
  );
});

Deno.test("skips: unscoped formula is never reported as skipped", () => {
  // Null activities/durations = wildcard, so it always matches.
  const f = pin({ phase: "during", activities: null, durations: null });
  assertEquals(
    collectPersonalFormulaSkips([f], "during", "cycling", 75).length,
    0,
  );
});

Deno.test("skips: before phase has no scope axis, reports nothing", () => {
  const f = pin({ phase: "before", activities: ["running"] });
  assertEquals(
    collectPersonalFormulaSkips([f], "before", "cycling", 75).length,
    0,
  );
});

Deno.test("skips: formulas for other phases are ignored", () => {
  const f = pin({ phase: "after", activities: ["running"] });
  assertEquals(
    collectPersonalFormulaSkips([f], "during", "cycling", 75).length,
    0,
  );
});
