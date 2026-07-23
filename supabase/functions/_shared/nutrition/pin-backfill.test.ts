import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.177.1/testing/asserts.ts";
import {
  backfillPinnedFluidsAndSodium,
  fluidSodiumDeficits,
} from "./pin-backfill.ts";
import type { Food, FoodResult } from "./types.ts";

function food(overrides: Partial<FoodResult>): FoodResult {
  return {
    food_id: "gel",
    quantity: 1,
    carbs_grams: 25,
    protein_grams: 0,
    fat_grams: 0,
    sodium_mg: 0,
    fluids_ml: 0,
    calories: 100,
    timing: "Throughout activity",
    display_name: "Energy Gel",
    ...overrides,
  };
}

function essential(overrides: Partial<Food>): Food {
  return {
    id: "water",
    name: "water",
    display_name: "Water",
    display_name_plural: "Water",
    description: null,
    image_address: null,
    serving_unit: "cup",
    per_serving: {
      calories: 0,
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      water_ml: 240,
    },
    serving_amount: 1,
    min_servings: 1,
    max_servings: 10,
    preference_score: 50,
    is_electrolyte: false,
    is_liquid: true,
    is_essential: true,
    is_user_food: false,
    is_indivisible: false,
    ...overrides,
  } as Food;
}

const WATER = essential({});
const SALT = essential({
  id: "salt",
  name: "salt",
  display_name: "Salt",
  serving_unit: "pinch",
  is_liquid: false,
  is_electrolyte: true,
  is_indivisible: true,
  per_serving: {
    calories: 0,
    carbs_g: 0,
    protein_g: 0,
    fat_g: 0,
    sodium_mg: 300,
    water_ml: 0,
  },
});

function totals(foods: FoodResult[]) {
  return {
    fluid: foods.reduce((s, f) => s + f.fluids_ml, 0),
    sodium: foods.reduce((s, f) => s + f.sodium_mg, 0),
    carbs: foods.reduce((s, f) => s + f.carbs_grams, 0),
  };
}

Deno.test("no deficit → foods unchanged", () => {
  const foods = [
    food({ fluids_ml: 600, sodium_mg: 400 }),
  ];
  const targets = { water_ml: 600, sodium_mg: 400 };
  assertEquals(fluidSodiumDeficits(foods, targets).needsBackfill, false);
  const out = backfillPinnedFluidsAndSodium(
    foods,
    targets,
    [WATER, SALT],
    "t",
    "[TEST]",
  );
  assertEquals(out, foods);
});

Deno.test("zero targets never report a deficit", () => {
  const d = fluidSodiumDeficits([food({})], { water_ml: 0, sodium_mg: 0 });
  assertEquals(d.needsBackfill, false);
});

Deno.test("fluid deficit bumps existing plain-water component, rounding UP (4 cups → 5 cups)", () => {
  // The reported bug: formula scaled to 4 cups (960ml) against a 1150ml
  // target — the plan must round up to 5 cups, never sit under target.
  const foods = [
    food({ carbs_grams: 50 }),
    food({
      food_id: "water",
      display_name: "Water",
      carbs_grams: 0,
      calories: 0,
      quantity: 4,
      fluids_ml: 960,
    }),
  ];
  const out = backfillPinnedFluidsAndSodium(
    foods,
    { water_ml: 1150, sodium_mg: 0 },
    [],
    "t",
    "[TEST]",
  );
  const water = out.find((f) => f.food_id === "water")!;
  assertEquals(water.quantity, 5); // ceil((1150-960)/240 * 2)/2 = 1 extra cup
  assert(totals(out).fluid >= 1150);
  assertEquals(totals(out).carbs, 50); // carbs untouched
});

Deno.test("fluid deficit with no water component appends essential water", () => {
  const foods = [food({ carbs_grams: 60 })];
  const out = backfillPinnedFluidsAndSodium(
    foods,
    { water_ml: 700, sodium_mg: 0 },
    [WATER, SALT],
    "Throughout activity",
    "[TEST]",
  );
  assertEquals(out.length, 2);
  const water = out[1];
  assertEquals(water.food_id, "water");
  assertEquals(water.quantity, 3); // ceil(700/240 * 2)/2 = 3
  assert(totals(out).fluid >= 700);
  assertEquals(water.timing, "Throughout activity");
});

Deno.test("sodium deficit bumps existing carb-free sodium component", () => {
  const foods = [
    food({ carbs_grams: 50 }),
    food({
      food_id: "salt-tabs",
      display_name: "Salt Tabs",
      carbs_grams: 0,
      calories: 0,
      quantity: 1,
      sodium_mg: 200,
      is_indivisible: true,
    }),
  ];
  const out = backfillPinnedFluidsAndSodium(
    foods,
    { water_ml: 0, sodium_mg: 600 },
    [],
    "t",
    "[TEST]",
  );
  const tabs = out.find((f) => f.food_id === "salt-tabs")!;
  assertEquals(tabs.quantity, 3); // 200mg/serving, need +400mg → +2 whole tabs
  assertEquals(totals(out).sodium, 600);
  assertEquals(totals(out).carbs, 50);
});

Deno.test("sodium deficit with no sodium component appends essential salt, capped at 110%", () => {
  const foods = [food({ carbs_grams: 80 })];
  const out = backfillPinnedFluidsAndSodium(
    foods,
    { water_ml: 0, sodium_mg: 500 },
    [WATER, SALT],
    "t",
    "[TEST]",
  );
  assertEquals(out.length, 2);
  assertEquals(out[1].food_id, "salt");
  // ceil(500/300)=2 servings wanted (600mg) but cap is 550 → floor(550/300)=1
  assertEquals(out[1].quantity, 1);
  assert(totals(out).sodium <= 500 * 1.1);
});

Deno.test("appended salt never violates the 110% cap, even when a whole serving doesn't fit", () => {
  // 460mg already present (carby drink), target 500, cap 550. SALT is
  // 300mg/serving indivisible — no whole serving fits under the cap, so
  // nothing is added (caps win over the last 40mg of deficit).
  const foods = [
    food({ food_id: "mix", carbs_grams: 40, sodium_mg: 460, fluids_ml: 0 }),
  ];
  const out = backfillPinnedFluidsAndSodium(
    foods,
    { water_ml: 0, sodium_mg: 500 },
    [WATER, SALT],
    "t",
    "[TEST]",
  );
  assertEquals(out.length, 1);
  assertEquals(totals(out).sodium, 460);
});

Deno.test("carby drink mix is never used for sodium backfill (carbs preserved)", () => {
  const foods = [
    food({
      food_id: "mix",
      carbs_grams: 40,
      sodium_mg: 300,
      fluids_ml: 500,
      quantity: 2,
    }),
  ];
  const out = backfillPinnedFluidsAndSodium(
    foods,
    { water_ml: 500, sodium_mg: 800 },
    [WATER, SALT],
    "t",
    "[TEST]",
  );
  // Sodium gap filled by salt (appended), NOT by bumping the carby mix.
  const mix = out.find((f) => f.food_id === "mix")!;
  assertEquals(mix.quantity, 2);
  assertEquals(totals(out).carbs, 40);
  assert(out.some((f) => f.food_id === "salt"));
});

Deno.test("electrolyte fluid counts toward the fluid target (sodium fills first)", () => {
  const ELECTROLYTE_DRINK = essential({
    id: "elec-drink",
    name: "electrolyte drink",
    display_name: "Electrolyte Drink",
    is_electrolyte: true,
    is_indivisible: true,
    per_serving: {
      calories: 0,
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 250,
      water_ml: 240,
    },
  });
  const foods = [food({ carbs_grams: 50 })];
  const out = backfillPinnedFluidsAndSodium(
    foods,
    { water_ml: 480, sodium_mg: 250 },
    [WATER, ELECTROLYTE_DRINK],
    "t",
    "[TEST]",
  );
  // Drink (240ml) added for sodium first; water only fills the REMAINING
  // 240ml — 1 cup, not 2.
  const water = out.find((f) => f.food_id === "water")!;
  assertEquals(water.quantity, 1);
  assert(totals(out).fluid >= 480);
});

Deno.test("empty pool and no matching components degrades gracefully", () => {
  const foods = [food({ carbs_grams: 50 })];
  const out = backfillPinnedFluidsAndSodium(
    foods,
    { water_ml: 500, sodium_mg: 400 },
    [],
    "t",
    "[TEST]",
  );
  assertEquals(out, foods); // nothing to add from — unchanged, logged
});
