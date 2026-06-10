import { assertEquals } from "https://deno.land/std@0.177.1/testing/asserts.ts";
import {
  beforeSlotForSubPhase,
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
