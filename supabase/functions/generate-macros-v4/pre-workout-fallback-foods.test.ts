/**
 * Regression tests for the Pass 1.5 carb gap-fill.
 *
 * HISTORY
 * -------
 * #15 (2026-07) introduced a hardcoded universal fallback chain
 * (dates → applesauce → raisins) for athletes who dislike the standard
 * fallbacks. Bug 3b4e3fdb (2026-08-06) showed why that was wrong: the chain
 * emitted foods that exist in NO pinnable template — the athlete saw
 * "Medjool Dates" fill the Top-Off with the pin banner reading "No pin
 * found" — and Medjool Dates fail food-composition v3's H2 fibre gate at the
 * top-off tier anyway (2 dates ≈ 3.2 g fibre > the 2 g flat ceiling).
 *
 * CURRENT BEHAVIOR (2026-08-06)
 * -----------------------------
 * The gap-fill derives its candidates from the ACTUAL template catalog:
 * eligible (diet/allergen/dislike-filtered) templates for the top_up → snack
 * → meal phases, scaled within their own [min_servings, max_servings], placed
 * into the phase's empty primary slot (or empty stack slot) so every filled
 * gap is a REAL formula with a template id — renderable, pinnable, and
 * governed by the catalog's own composition gates. When the catalog offers
 * nothing the athlete accepts, the plan ships short WITH a shortfall record —
 * it never invents food.
 *
 * The banana add-on branch (a real, universally-safe add-on with an
 * established wire type) still runs first and is unchanged.
 *
 * Run with:
 *   deno test --allow-read --allow-env \
 *     supabase/functions/generate-macros-v4/pre-workout-fallback-foods.test.ts
 */

import { assert, assertEquals } from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import {
  applyPreWorkoutHydrationOverlay,
  calculatePreWorkoutHydration,
  calculatePreWorkoutTargets,
  selectPreWorkoutFoods,
} from './pre-workout.ts';
import type { PreWorkoutTemplate } from './types.ts';

function makeTopUpTemplate(overrides: Partial<PreWorkoutTemplate> & { id: string; name: string }): PreWorkoutTemplate {
  return {
    base_category: 'Quick Grab',
    time_window: '< 30 min',
    digestion_speed: 'fast',
    allergens: [],
    serving_unit: 'piece',
    min_servings: 1,
    max_servings: 2,
    plus_banana: false,
    plus_sports_drink: false,
    carbs_per_serving: 25,
    protein_per_serving: 0,
    fat_per_serving: 0,
    sodium_mg: 40,
    fluid_ml: 0,
    template_type: 'food',
    is_active: true,
    component_food_names: [],
    component_quantities: {},
    ...overrides,
  };
}

const GEL = makeTopUpTemplate({
  id: 'gel',
  name: 'Energy Gel',
  component_food_names: ['energy_gel'],
});

const CHEWS = makeTopUpTemplate({
  id: 'chews',
  name: 'Energy Chews',
  component_food_names: ['energy_chews'],
});

// Mirrors the v3 catalog's real 'Applesauce Pouch (Top-Off)' row: a small
// low-fibre fruit formula the pool-derived gap-fill can scale (1–3 pouches).
const APPLESAUCE_POUCH = makeTopUpTemplate({
  id: 'applesauce-pouch-topoff',
  name: 'Applesauce Pouch (Top-Off)',
  base_category: 'Fruit',
  carbs_per_serving: 11,
  sodium_mg: 3,
  fluid_ml: 77,
  min_servings: 1,
  max_servings: 3,
  component_food_names: ['applesauce_pouch'],
  component_quantities: { applesauce_pouch: 1 },
});

// ---------------------------------------------------------------------------
// Engine-realistic fixture: 60 kg athlete, 30 minutes out, 90-minute session.
// carbs v2: carbPerKg = min(30/60, 4) = 0.5 → carbs_g = 30 exactly.
// hydration v6: t = 30 is the snack boundary → f(30) = 300 ml, band [0, 600].
// ---------------------------------------------------------------------------
const HOURS_BEFORE = 0.5;

function makeTargets() {
  const legacy = calculatePreWorkoutTargets(
    /* weightKg */ 60,
    HOURS_BEFORE,
    /* isFasted */ false,
    /* sweatSodiumCat */ 'medium',
    /* envLabel */ 'mild',
    /* workoutDurationMin */ 90,
  );
  const hydration = calculatePreWorkoutHydration({
    bodyWeightKg: 60,
    workoutDurationMin: 90,
    timeBeforeWorkoutMin: HOURS_BEFORE * 60,
    tempC: 22,
  });
  return applyPreWorkoutHydrationOverlay(legacy, hydration);
}

const TARGETS = makeTargets();

/** The band the solver actually enforces — `carbs_g × (1 ∓ 0.125)`. */
const SOLVER_LOW = TARGETS.carbs_g * 0.875;   // 26.25
const SOLVER_HIGH = TARGETS.carbs_g * 1.125;  // 33.75

function run(disliked: string[], catalog: PreWorkoutTemplate[] = [GEL, CHEWS]) {
  return selectPreWorkoutFoods(
    TARGETS,
    HOURS_BEFORE,
    /* diet */ 'none',
    /* foodTemplates */ catalog,
    /* drinkTemplates */ [],
    /* electrolyteTemplates */ [],
    /* likedFoods */ [],
    disliked,
    /* allergies */ [],
  );
}

function totals(results: ReturnType<typeof selectPreWorkoutFoods>) {
  return {
    carbs: results.reduce((sum, p) => sum + p.total_carbs_g, 0),
    addOnTypes: results.flatMap((p) => p.add_ons.map((a) => a.type)),
    selectionIds: results.flatMap((p) =>
      [p.primary, p.stack].filter((s) => s !== null && s !== undefined)
        .map((s) => s!.id)
    ),
  };
}

Deno.test('fixture is the engine\'s own arithmetic, not hand-written', () => {
  // If any of these move, the SSOT moved and the expectations below need
  // re-deriving — they must never be adjusted to keep a test green.
  assertEquals(TARGETS.carbs_g, 30, '60 kg x 0.5 g/kg at t-30');
  assertEquals(SOLVER_LOW, 26.25);
  assertEquals(SOLVER_HIGH, 33.75);
  assertEquals(TARGETS.water_ml, 300, 'hydration v6 taper f(30) for 60 kg');
});

Deno.test(
  'pool fallback: picky athlete gets a REAL catalog formula, scaled into the band',
  () => {
    // Dislikes gels/chews/banana/sports drink — but the catalog carries the
    // v3 applesauce-pouch top-off formula, which survives the filters. The
    // gap-fill must select IT (3 pouches = 33 g, inside [26.25, 33.75]) as
    // the phase primary, not conjure a hardcoded add-on.
    const results = run(
      ['energy_gel', 'energy_chews', 'banana', 'sports_drink', 'sports_drink_mix'],
      [GEL, CHEWS, APPLESAUCE_POUCH],
    );
    const { carbs, addOnTypes, selectionIds } = totals(results);

    assert(
      selectionIds.includes('applesauce-pouch-topoff'),
      `expected the catalog formula to fill the gap, got selections: ${JSON.stringify(selectionIds)}`,
    );
    // Every selection carries a real template id from the supplied catalog —
    // THE invariant bug 3b4e3fdb is about: everything rendered is pinnable.
    const catalogIds = new Set([GEL, CHEWS, APPLESAUCE_POUCH].map((t) => t.id));
    for (const id of selectionIds) {
      assert(catalogIds.has(id), `selection ${id} is not a catalog template`);
    }
    for (const t of ['dates', 'applesauce', 'raisins']) {
      assert(
        !addOnTypes.includes(t as never),
        `hardcoded ${t} add-on must never be emitted`,
      );
    }
    assert(
      carbs >= SOLVER_LOW && carbs <= SOLVER_HIGH,
      `pool fallback must land in [${SOLVER_LOW}, ${SOLVER_HIGH}], got ${carbs}`,
    );
  },
);

Deno.test(
  'pool fallback: when the catalog offers nothing acceptable, the plan ships short with a shortfall — no invented food',
  () => {
    // Everything in the catalog is disliked. The old behavior invented dates
    // out of thin air; the new behavior is honest: no add-ons, no selections,
    // a recorded carb shortfall.
    const results = run(
      ['energy_gel', 'energy_chews', 'banana', 'sports_drink', 'sports_drink_mix'],
    );
    const { carbs, addOnTypes, selectionIds } = totals(results);

    assertEquals(selectionIds.length, 0, 'nothing eligible → nothing selected');
    for (const t of ['dates', 'applesauce', 'raisins']) {
      assert(
        !addOnTypes.includes(t as never),
        `hardcoded ${t} add-on must never be emitted`,
      );
    }
    assertEquals(carbs, 0);
    const shortfalls = results.flatMap((p) => p.shortfalls ?? []);
    assert(
      shortfalls.some((s) => s.macro === 'carbs'),
      'the unmet carb target must be surfaced as a shortfall',
    );
  },
);

Deno.test(
  'pool fallback: a cross-phase gap left by serving granularity is closed from the catalog into the empty stack slot',
  () => {
    // A single small-serving template (16 g, max 1) leaves Pass 1 at 16 g of
    // a 30 g target — below the 26.25 g solver floor. With banana disliked,
    // the pool fallback must close the gap from the catalog (the 11 g pouch,
    // → 27 g total, in band) by filling the phase's empty stack slot with a
    // real template selection.
    const HALF_GEL = makeTopUpTemplate({
      id: 'half-gel',
      name: 'Mini Gel',
      carbs_per_serving: 16,
      max_servings: 1,
      component_food_names: ['mini_gel'],
    });
    // max 1 pouch so Pass 1 prefers the 16 g gel (closer to the 30 g target)
    // and the pouch is left for the gap-fill.
    const SINGLE_POUCH = { ...APPLESAUCE_POUCH, max_servings: 1 };
    const results = run(
      ['banana', 'sports_drink', 'sports_drink_mix'],
      [HALF_GEL, SINGLE_POUCH],
    );
    const { carbs, addOnTypes, selectionIds } = totals(results);

    assert(selectionIds.includes('half-gel'), 'Pass 1 primary expected');
    assert(
      selectionIds.includes('applesauce-pouch-topoff'),
      `gap-fill must come from the catalog, got: ${JSON.stringify(selectionIds)}`,
    );
    const topUp = results.find((p) => p.phase === 'top_up')!;
    assert(topUp.stack, 'the catalog gap-fill lands in the empty stack slot');
    for (const t of ['dates', 'applesauce', 'raisins']) {
      assert(!addOnTypes.includes(t as never), `hardcoded ${t} must not fire`);
    }
    assert(
      carbs >= SOLVER_LOW && carbs <= SOLVER_HIGH,
      `expected in-band total, got ${carbs}`,
    );
  },
);

Deno.test(
  'no-regression — when banana is available the banana add-on still fires first, and the plan is IN band',
  () => {
    const { carbs, addOnTypes } = totals(run(['energy_gel', 'energy_chews']));

    assert(
      addOnTypes.includes('banana'),
      `expected banana to be used preferentially, got: ${JSON.stringify(addOnTypes)}`,
    );
    // Banana is 27 g — inside [26.25, 33.75]. When it is available the plan
    // IS satisfied and the pool fallback must not pile more on top.
    assertEquals(carbs, 27);
    assert(
      carbs >= SOLVER_LOW && carbs <= SOLVER_HIGH,
      `banana path must land in [${SOLVER_LOW}, ${SOLVER_HIGH}], got ${carbs}`,
    );
  },
);
