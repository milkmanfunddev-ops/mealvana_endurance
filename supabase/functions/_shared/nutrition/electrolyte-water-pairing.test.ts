/**
 * Tests for the electrolyte ↔ water pairing invariant.
 *
 * Product rule: an electrolyte mix / tablet / sodium supplement is never
 * recommended alone — water always goes with it.
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.177.1/testing/asserts.ts";
import {
  deliversDrinkableFluid,
  DEFAULT_PAIRING_VOLUME_ML,
  ensureElectrolyteWaterPairing,
  isElectrolyteItem,
  needsWaterPairing,
  plainWaterMl,
  requiresWaterWhenDry,
  solventRequirementMl,
  unpairedElectrolyteItems,
} from "./electrolyte-water-pairing.ts";
import type { Food, FoodResult } from "./types.ts";

const OPTS = { timing: "Throughout activity", logPrefix: "[TEST]" };

function item(overrides: Partial<FoodResult>): FoodResult {
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

/** A dry electrolyte tablet: sodium, zero fluid of its own. */
function electrolyteTablet(overrides: Partial<FoodResult> = {}): FoodResult {
  return item({
    food_id: "salt-tab",
    display_name: "Electrolyte Tablet",
    carbs_grams: 0,
    sodium_mg: 300,
    fluids_ml: 0,
    is_electrolyte: true,
    is_indivisible: true,
    product_type: "supplement",
    timing_category: "electrolyte",
    ...overrides,
  });
}

function poolFood(overrides: Partial<Food>): Food {
  return {
    id: "water",
    name: "water",
    display_name: "Water",
    display_name_plural: "Water",
    description: null,
    image_address: null,
    per_serving: {
      carbs_g: 0,
      protein_g: 0,
      fat_g: 0,
      sodium_mg: 0,
      water_ml: 240,
      calories: 0,
    },
    serving_amount: 1,
    min_servings: 1,
    max_servings: 10,
    preference_score: 50,
    is_electrolyte: false,
    is_liquid: false, // getEssentialFoods() really does hardcode this false
    is_essential: true,
    is_user_food: false,
    is_indivisible: false,
    ...overrides,
  };
}

const WATER_POOL = [poolFood({})];

function totalFluid(foods: FoodResult[]): number {
  return foods.reduce((s, f) => s + (f.fluids_ml || 0), 0);
}

// ---------------------------------------------------------------------------
// Detection
// ---------------------------------------------------------------------------

Deno.test("isElectrolyteItem keys off data-model flags, not names", () => {
  assert(isElectrolyteItem(electrolyteTablet()));
  // Flag alone is enough.
  assert(isElectrolyteItem(item({ is_electrolyte: true })));
  // Sodium-bearing supplement with no is_electrolyte flag still counts.
  assert(
    isElectrolyteItem(
      item({ product_type: "supplement", sodium_mg: 200, is_electrolyte: false }),
    ),
  );
  // A plain gel named nothing electrolyte-ish is not one.
  assertEquals(isElectrolyteItem(item({})), false);
  // A food merely *called* "Electrolyte Gel" with no flags is NOT matched —
  // this pass must never key off display names.
  assertEquals(
    isElectrolyteItem(item({ display_name: "Electrolyte Drink Mix" })),
    false,
  );
});

Deno.test("deliversDrinkableFluid ignores water locked in solid food", () => {
  // A banana carries 88ml but you cannot wash a tablet down with it.
  assertEquals(
    deliversDrinkableFluid(item({ fluids_ml: 88, is_liquid: false })),
    false,
  );
  assert(deliversDrinkableFluid(item({ fluids_ml: 500, is_liquid: true })));
  assert(deliversDrinkableFluid(item({ fluids_ml: 500, is_drink: true })));
});

// ---------------------------------------------------------------------------
// Core invariant
// ---------------------------------------------------------------------------

Deno.test("electrolyte alone gets water added", () => {
  const foods = [item({}), electrolyteTablet()];
  assert(needsWaterPairing(foods));

  const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, OPTS);

  assert(res.changed);
  assertEquals(res.conflict, null);
  assertEquals(res.foods.length, 3);
  const added = res.foods[2];
  assertEquals(added.food_id, "water");
  assert(added.fluids_ml >= DEFAULT_PAIRING_VOLUME_ML);
  // The appended item must read as a drink so the invariant now holds.
  assert(res.foods.some(deliversDrinkableFluid));
  assertEquals(needsWaterPairing(res.foods), false);
});

Deno.test(
  "electrolyte alongside whole-food water still gets a real drink",
  () => {
    // Banana's 88ml satisfies no pairing — it is not drinkable.
    const foods = [
      item({ food_id: "banana", fluids_ml: 88, is_liquid: false }),
      electrolyteTablet(),
    ];
    const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, OPTS);
    assert(res.changed);
    assert(res.foods.some((f) => f.food_id === "water"));
  },
);

Deno.test("electrolyte carrying its own water is NOT re-paired", () => {
  // A drink mix already dissolved in 500ml — pairing is self-satisfied and
  // adding more water here would double-count the phase's fluid.
  const mix = item({
    food_id: "drink-mix",
    display_name: "Electrolyte Drink Mix",
    carbs_grams: 0,
    sodium_mg: 400,
    fluids_ml: 500,
    is_electrolyte: true,
    is_liquid: true,
    is_drink: true,
  });
  const foods = [item({}), mix];

  assertEquals(needsWaterPairing(foods), false);
  const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, OPTS);

  assertEquals(res.changed, false);
  assertEquals(res.conflict, null);
  assertEquals(res.foods.length, 2);
  assertEquals(totalFluid(res.foods), 500); // no double-count
});

Deno.test("a dry tablet next to a sports drink needs nothing extra", () => {
  const foods = [
    item({ food_id: "sports-drink", fluids_ml: 600, is_liquid: true }),
    electrolyteTablet(),
  ];
  assertEquals(needsWaterPairing(foods), false);
  const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, OPTS);
  assertEquals(res.changed, false);
  assertEquals(res.foods.length, 2);
});

Deno.test("no electrolyte present is a no-op", () => {
  const foods = [item({}), item({ food_id: "bar", carbs_grams: 40 })];
  assertEquals(needsWaterPairing(foods), false);
  const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, OPTS);
  assertEquals(res.changed, false);
  assertEquals(res.foods.length, 2);
});

// ---------------------------------------------------------------------------
// Fluid ceiling
// ---------------------------------------------------------------------------

Deno.test("pairing never breaches the fluid ceiling", () => {
  // 900ml of whole-food water already, ceiling 950ml: one 240ml serving of
  // water would land at 1140ml. Half a serving (120ml) is also over. The
  // pass must refuse and report, not overshoot.
  const foods = [
    item({ food_id: "melon", carbs_grams: 30, fluids_ml: 900, is_liquid: false }),
    electrolyteTablet(),
  ];
  const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, {
    ...OPTS,
    fluidCeilingMl: 950,
  });

  assertEquals(res.changed, false);
  assert(res.conflict != null);
  assertEquals(res.conflict!.reason, "fluid_ceiling");
  assertEquals(res.conflict!.electrolyte_food_ids, ["salt-tab"]);
  assertEquals(totalFluid(res.foods), 900); // unchanged, not overshot
});

Deno.test("pairing fits inside available headroom", () => {
  // Ceiling 1100ml with 900ml used → 200ml headroom. 240ml/serving water
  // cannot fit a full serving, but 0.5 servings (120ml) can.
  const foods = [
    item({ food_id: "melon", carbs_grams: 30, fluids_ml: 900, is_liquid: false }),
    electrolyteTablet(),
  ];
  const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, {
    ...OPTS,
    fluidCeilingMl: 1100,
  });

  assert(res.changed);
  assertEquals(res.conflict, null);
  assert(totalFluid(res.foods) <= 1100);
  assert(totalFluid(res.foods) > 900);
});

Deno.test(
  "tight ceiling is resolved by trimming a zero-carb fluid carrier",
  () => {
    // Broth: carries fluid, carries no carbs, is not drinkable-flagged, so it
    // neither satisfies the pairing nor costs carbs when trimmed.
    const foods = [
      item({
        food_id: "broth",
        display_name: "Broth",
        carbs_grams: 0,
        fluids_ml: 800,
        quantity: 4,
        is_liquid: false,
      }),
      electrolyteTablet(),
    ];
    const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, {
      ...OPTS,
      fluidCeilingMl: 820,
    });

    assert(res.changed);
    assertEquals(res.conflict, null);
    assert(res.foods.some((f) => f.food_id === "water"));
    assert(totalFluid(res.foods) <= 820);
  },
);

Deno.test("no water source in the pool reports an honest conflict", () => {
  const foods = [item({}), electrolyteTablet()];
  const res = ensureElectrolyteWaterPairing(foods, [], OPTS);

  assertEquals(res.changed, false);
  assert(res.conflict != null);
  assertEquals(res.conflict!.reason, "no_water_source");
  assertEquals(res.foods.length, 2);
});

// ---------------------------------------------------------------------------
// Idempotency
// ---------------------------------------------------------------------------

Deno.test("running the pass twice does not add water twice", () => {
  const foods = [item({}), electrolyteTablet()];

  const once = ensureElectrolyteWaterPairing(foods, WATER_POOL, OPTS);
  const twice = ensureElectrolyteWaterPairing(once.foods, WATER_POOL, OPTS);
  const thrice = ensureElectrolyteWaterPairing(twice.foods, WATER_POOL, OPTS);

  assert(once.changed);
  assertEquals(twice.changed, false);
  assertEquals(thrice.changed, false);
  assertEquals(twice.foods.length, once.foods.length);
  assertEquals(thrice.foods.length, once.foods.length);
  assertEquals(totalFluid(thrice.foods), totalFluid(once.foods));
  assertEquals(
    once.foods.filter((f) => f.food_id === "water").length,
    1,
  );
});

Deno.test("input array is never mutated", () => {
  const foods = [item({}), electrolyteTablet()];
  const before = foods.length;
  ensureElectrolyteWaterPairing(foods, WATER_POOL, OPTS);
  assertEquals(foods.length, before);
});

// ---------------------------------------------------------------------------
// C2 scope extension — docs/ssot/spec/domain/catalog-conventions.md (RULED
// Xuan 2026-09-01): every DRY requires-water item is covered, not only
// electrolyte-flagged ones. With the C1 catalog zeros in place a carb drink
// mix row is dry — nobody chews drink mix.
// ---------------------------------------------------------------------------

Deno.test("C2: a dry carb drink mix (no electrolyte flags) gets water", () => {
  const dryMix = item({
    food_id: "carb-mix",
    display_name: "Carb Drink Mix",
    carbs_grams: 45,
    sodium_mg: 0,
    fluids_ml: 0, // C1: dry as catalogued
    product_type: "drink_mix",
  });
  assert(requiresWaterWhenDry(dryMix), "drink_mix is drink-shaped");
  assert(needsWaterPairing([dryMix]));

  const result = ensureElectrolyteWaterPairing([dryMix], WATER_POOL, OPTS);
  assert(result.changed, "water appended for the dry mix");
  assert(
    result.foods.some((f) => deliversDrinkableFluid(f)),
    "invariant satisfied",
  );
});

Deno.test("C2: a hydrated sports drink is self-satisfying (no double count)", () => {
  const mixed = item({
    food_id: "sports-drink",
    display_name: "Sports Drink",
    carbs_grams: 30,
    fluids_ml: 500,
    is_drink: true,
    product_type: "sports_drink",
  });
  const result = ensureElectrolyteWaterPairing([mixed], WATER_POOL, OPTS);
  assertEquals(result.changed, false, "already delivers its own fluid");
});

Deno.test("C2: a plain solid food stays outside the pairing scope", () => {
  const banana = item({
    food_id: "banana",
    display_name: "Banana",
    carbs_grams: 27,
    fluids_ml: 0,
    product_type: "real_food",
  });
  assertEquals(requiresWaterWhenDry(banana), false);
  assertEquals(unpairedElectrolyteItems([banana]).length, 0);
});

// ---------------------------------------------------------------------------
// Catalog-conventions v1.1 — per-product solvent minima (food-recommendation
// §6(e), RULED Xuan 2026-09-03). The declared column supersedes the flat
// 250 ml constant; 250 stays the undeclared-row fallback (asserted above by
// "electrolyte alone gets water added").
// ---------------------------------------------------------------------------

Deno.test("declared solvent_min_ml supersedes the flat pairing constant (W7)", () => {
  // High-carb mix x2 with a 600 ml/serving label -> plain water >= 1200 ml.
  const mix = item({
    food_id: "high-carb-mix",
    display_name: "High-Carb Drink Mix",
    carbs_grams: 180, // 90 g x2
    quantity: 2,
    fluids_ml: 0, // C1: dry as consumed
    is_liquid: true,
    product_type: "drink_mix",
    solvent_min_ml: 600,
  });
  const foods = [mix];
  assertEquals(solventRequirementMl(foods), 1200);
  assert(needsWaterPairing(foods));

  const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, OPTS);
  assert(res.changed);
  assertEquals(res.conflict, null);
  assert(plainWaterMl(res.foods) >= 1200);
});

Deno.test("a drink on the plate does not satisfy a declared solvent need", () => {
  // Legacy C2 no-ops when any drink is present; a declared solvent row still
  // demands its dilution water.
  const mix = item({
    food_id: "high-carb-mix",
    carbs_grams: 90,
    quantity: 1,
    fluids_ml: 0,
    is_liquid: true,
    product_type: "drink_mix",
    solvent_min_ml: 600,
  });
  const sportsDrink = item({
    food_id: "sports-drink",
    carbs_grams: 15,
    quantity: 1,
    fluids_ml: 240,
    is_drink: true,
    product_type: "sports_drink",
  });
  const foods = [mix, sportsDrink];
  const res = ensureElectrolyteWaterPairing(foods, WATER_POOL, OPTS);
  assert(res.changed);
  assert(plainWaterMl(res.foods) >= 600);
});

Deno.test("existing plain water counts toward the solvent total (no double demand)", () => {
  const mix = item({
    food_id: "high-carb-mix",
    carbs_grams: 90,
    quantity: 1,
    fluids_ml: 0,
    is_liquid: true,
    product_type: "drink_mix",
    solvent_min_ml: 600,
  });
  const water = item({
    food_id: "water",
    carbs_grams: 0,
    sodium_mg: 0,
    quantity: 3,
    fluids_ml: 720,
    is_drink: true,
    product_type: "beverage",
  });
  const res = ensureElectrolyteWaterPairing([mix, water], WATER_POOL, OPTS);
  assertEquals(res.changed, false);
  assertEquals(res.conflict, null);
});
