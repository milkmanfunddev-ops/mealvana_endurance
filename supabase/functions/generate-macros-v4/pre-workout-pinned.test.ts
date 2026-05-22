/**
 * Pin-honoring tests for `selectPreWorkoutFoods` — Formula Kit PR 2 substep 5a.
 *
 * Locks in the locked honor-pin policy (2026-05-21):
 *   - In-scope pin (template.time_window === sub_phase's window) is honored
 *     unconditionally — skip allergen/diet/dislike filters and the
 *     [min_servings, max_servings] scale clamp.
 *   - The only fallthrough reason is `no_pin_for_scope`.
 *   - When `pinnedTemplateIds` is undefined or empty, behavior is identical
 *     to pre-pin v3 (verified by parity test).
 *
 * Run with:
 *   deno test --no-check --allow-all \
 *     supabase/functions/generate-macros-v4/pre-workout-pinned.test.ts
 */

import {
  assert,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { selectPreWorkoutFoods } from './pre-workout.ts';
import type { PreWorkoutTemplate, PreWorkoutTargets } from './types.ts';

/** Top-up template (single-phase scenario when hoursBefore < 1.0). */
function makeTopUpTemplate(
  overrides: Partial<PreWorkoutTemplate> & { id: string; name: string },
): PreWorkoutTemplate {
  return {
    base_category: 'quick_grab',
    time_window: '< 30 min',
    digestion_speed: 'fast',
    allergens: [],
    excluded_diets: [],
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

/** Meal-window template (won't fire in a top_up-only scenario). */
function makeMealTemplate(
  overrides: Partial<PreWorkoutTemplate> & { id: string; name: string },
): PreWorkoutTemplate {
  return {
    base_category: 'grain',
    time_window: '1.5-3 hours',
    digestion_speed: 'medium',
    allergens: [],
    excluded_diets: [],
    serving_unit: 'serving',
    min_servings: 1,
    max_servings: 2,
    plus_banana: false,
    plus_sports_drink: false,
    carbs_per_serving: 30,
    protein_per_serving: 5,
    fat_per_serving: 2,
    sodium_mg: 100,
    fluid_ml: 50,
    template_type: 'food',
    is_active: true,
    component_food_names: [],
    component_quantities: {},
    ...overrides,
  };
}

// top_up-only targets — keeps the test scope to a single phase.
const TOP_UP_TARGETS: PreWorkoutTargets = {
  carbs_g: 30,
  carbs_low_g: 25,
  carbs_high_g: 40,
  protein_g: 0,
  protein_low_g: 0,
  protein_high_g: 5,
  fat_g: 0,
  sodium_mg: 100,
  sodium_low_mg: 50,
  sodium_high_mg: 300,
  water_ml: 200,
  water_low_ml: 100,
  water_high_ml: 400,
  meal_type: 'top_up',
};

// ─── Pin override over preference filters ─────────────────────────────────────

Deno.test('pin override: pinned template wins even when its component is disliked', () => {
  const gel = makeTopUpTemplate({
    id: 'gel-1',
    name: 'Energy Gel',
    component_food_names: ['energy_gel'],
  });
  const chews = makeTopUpTemplate({
    id: 'chews-1',
    name: 'Energy Chews',
    component_food_names: ['energy_chews'],
  });

  const results = selectPreWorkoutFoods(
    TOP_UP_TARGETS,
    /* hoursBefore */ 0.5, // top_up-only
    /* diet */ 'none',
    /* foodTemplates */ [gel, chews],
    /* drinkTemplates */ [],
    /* electrolyteTemplates */ [],
    /* likedFoods */ [],
    /* dislikedFoods */ ['energy_gel'], // ← user dislikes gels
    /* allergies */ [],
    /* pinnedTemplateIds */ new Set(['gel-1']), // ← but pinned the gel
  );

  const topUp = results.find((r) => r.phase === 'top_up');
  assert(topUp, 'top_up phase should exist');
  assertEquals(topUp.primary?.id, 'gel-1', 'pinned gel should win despite dislike');
  assertEquals(topUp.pin_decision?.used_pin, true);
  assertEquals(topUp.pin_decision?.pinned_template_id, 'gel-1');
});

Deno.test('pin override: pinned template wins even when its excluded_diets matches user diet', () => {
  const veganGel = makeTopUpTemplate({
    id: 'gel-1',
    name: 'Vegan Gel',
    excluded_diets: [],
    component_food_names: ['energy_gel'],
  });
  const honeyChews = makeTopUpTemplate({
    id: 'chews-1',
    name: 'Honey Chews',
    excluded_diets: ['vegan'], // ← excluded by user's vegan diet
    component_food_names: ['honey_chews'],
  });

  const results = selectPreWorkoutFoods(
    TOP_UP_TARGETS,
    /* hoursBefore */ 0.5,
    /* diet */ 'vegan', // ← user is vegan
    /* foodTemplates */ [veganGel, honeyChews],
    /* drinkTemplates */ [],
    /* electrolyteTemplates */ [],
    /* likedFoods */ [],
    /* dislikedFoods */ [],
    /* allergies */ [],
    /* pinnedTemplateIds */ new Set(['chews-1']), // ← pinned the non-vegan one
  );

  const topUp = results.find((r) => r.phase === 'top_up');
  assert(topUp, 'top_up phase should exist');
  assertEquals(topUp.primary?.id, 'chews-1', 'pinned honey chews should win over diet filter');
  assertEquals(topUp.pin_decision?.used_pin, true);
});

Deno.test('pin override: scaling bypasses [min_servings, max_servings] clamp', () => {
  // A template at 10g carbs/serving with max_servings=2 would normally cap
  // at 20g. With pin override + 30g target, ideal=3 servings → 30g. Pin
  // should ship 3 servings (or close) rather than clamping at 2.
  const lowCarbPin = makeTopUpTemplate({
    id: 'rice-cake-1',
    name: 'Rice Cake',
    carbs_per_serving: 10,
    min_servings: 1,
    max_servings: 2,
    component_food_names: ['rice_cake'],
  });

  const results = selectPreWorkoutFoods(
    TOP_UP_TARGETS, // 30g carb target
    /* hoursBefore */ 0.5,
    /* diet */ 'none',
    /* foodTemplates */ [lowCarbPin],
    /* drinkTemplates */ [],
    /* electrolyteTemplates */ [],
    /* likedFoods */ [],
    /* dislikedFoods */ [],
    /* allergies */ [],
    /* pinnedTemplateIds */ new Set(['rice-cake-1']),
  );

  const topUp = results.find((r) => r.phase === 'top_up');
  assert(topUp, 'top_up phase should exist');
  assertEquals(topUp.primary?.id, 'rice-cake-1');
  // Servings should exceed max_servings (2) — pin honors the carb target.
  assert(
    (topUp.primary?.servings ?? 0) > 2,
    `expected servings > max_servings=2, got ${topUp.primary?.servings}`,
  );
});

// ─── Pin scope matching ───────────────────────────────────────────────────────

Deno.test('pin scope: pin for meal time_window does NOT fire when running top_up-only', () => {
  // hoursBefore=0.5 → top_up-only phase (< 30 min window).
  // A pin on a meal-window template should NOT fire (scope mismatch).
  const mealOnlyTemplate = makeMealTemplate({
    id: 'meal-1',
    name: 'Oatmeal',
    component_food_names: ['oats'],
  });
  const topUpTemplate = makeTopUpTemplate({
    id: 'gel-1',
    name: 'Energy Gel',
    component_food_names: ['energy_gel'],
  });

  const results = selectPreWorkoutFoods(
    TOP_UP_TARGETS,
    /* hoursBefore */ 0.5, // top_up-only
    /* diet */ 'none',
    /* foodTemplates */ [mealOnlyTemplate, topUpTemplate],
    /* drinkTemplates */ [],
    /* electrolyteTemplates */ [],
    /* likedFoods */ [],
    /* dislikedFoods */ [],
    /* allergies */ [],
    /* pinnedTemplateIds */ new Set(['meal-1']), // ← scope mismatch
  );

  const topUp = results.find((r) => r.phase === 'top_up');
  assert(topUp, 'top_up phase should exist');
  assertEquals(topUp.primary?.id, 'gel-1', 'pin should NOT fire, normal top_up template selected');
  assertEquals(topUp.pin_decision?.used_pin, false);
  assertEquals(topUp.pin_decision?.fallthrough_reason, 'no_pin_for_scope');
});

Deno.test('pin scope: pinsActive but no pin for ANY scope → fallthrough_reason on all phases', () => {
  const gel = makeTopUpTemplate({
    id: 'gel-1',
    name: 'Energy Gel',
    component_food_names: ['energy_gel'],
  });

  const results = selectPreWorkoutFoods(
    TOP_UP_TARGETS,
    /* hoursBefore */ 0.5,
    /* diet */ 'none',
    /* foodTemplates */ [gel],
    /* drinkTemplates */ [],
    /* electrolyteTemplates */ [],
    /* likedFoods */ [],
    /* dislikedFoods */ [],
    /* allergies */ [],
    /* pinnedTemplateIds */ new Set(['nonexistent-id']), // ← pin exists but no template matches
  );

  for (const phase of results) {
    assertEquals(phase.pin_decision?.used_pin, false);
    assertEquals(phase.pin_decision?.fallthrough_reason, 'no_pin_for_scope');
  }
});

// ─── No-pin parity (the critical regression guard) ───────────────────────────

Deno.test('no-pin parity: calling without pinnedTemplateIds yields no pin_decision field', () => {
  const gel = makeTopUpTemplate({
    id: 'gel-1',
    name: 'Energy Gel',
    component_food_names: ['energy_gel'],
  });

  const results = selectPreWorkoutFoods(
    TOP_UP_TARGETS,
    /* hoursBefore */ 0.5,
    /* diet */ 'none',
    /* foodTemplates */ [gel],
    /* drinkTemplates */ [],
    /* electrolyteTemplates */ [],
    /* likedFoods */ [],
    /* dislikedFoods */ [],
    /* allergies */ [],
    // pinnedTemplateIds omitted
  );

  for (const phase of results) {
    assertEquals(
      phase.pin_decision,
      undefined,
      'no-pin call must omit pin_decision entirely (byte-identical to pre-pin behavior)',
    );
  }
});

Deno.test('no-pin parity: empty pinnedTemplateIds set yields no pin_decision field', () => {
  // Edge case: caller passes an empty set (user has no pins). Treated as
  // "pins inactive" — no pin_decision field, no behavior change.
  const gel = makeTopUpTemplate({
    id: 'gel-1',
    name: 'Energy Gel',
    component_food_names: ['energy_gel'],
  });

  const results = selectPreWorkoutFoods(
    TOP_UP_TARGETS,
    /* hoursBefore */ 0.5,
    /* diet */ 'none',
    /* foodTemplates */ [gel],
    /* drinkTemplates */ [],
    /* electrolyteTemplates */ [],
    /* likedFoods */ [],
    /* dislikedFoods */ [],
    /* allergies */ [],
    /* pinnedTemplateIds */ new Set<string>(), // ← empty
  );

  for (const phase of results) {
    assertEquals(phase.pin_decision, undefined);
  }
});

Deno.test('no-pin parity: identical results with and without empty Set passed', () => {
  // Stronger parity check: the algorithm output must be byte-identical
  // (apart from pin_decision presence) between the two calling conventions.
  // The algorithm sorts template arrays in place, so fixtures must be
  // rebuilt per call to keep state isolated across the two invocations.
  const mkArgs = () => ({
    targets: TOP_UP_TARGETS,
    hoursBefore: 0.5,
    diet: 'none',
    foodTemplates: [
      makeTopUpTemplate({
        id: 'gel-1',
        name: 'Energy Gel',
        component_food_names: ['energy_gel'],
      }),
      makeTopUpTemplate({
        id: 'chews-1',
        name: 'Energy Chews',
        component_food_names: ['energy_chews'],
      }),
    ],
    drinkTemplates: [],
    electrolyteTemplates: [],
    liked: [],
    disliked: [],
    allergies: [],
  });

  const a = mkArgs();
  const withoutPins = selectPreWorkoutFoods(
    a.targets,
    a.hoursBefore,
    a.diet,
    a.foodTemplates,
    a.drinkTemplates,
    a.electrolyteTemplates,
    a.liked,
    a.disliked,
    a.allergies,
  );
  const b = mkArgs();
  const withEmptyPins = selectPreWorkoutFoods(
    b.targets,
    b.hoursBefore,
    b.diet,
    b.foodTemplates,
    b.drinkTemplates,
    b.electrolyteTemplates,
    b.liked,
    b.disliked,
    b.allergies,
    new Set<string>(),
  );

  assertEquals(withoutPins.length, withEmptyPins.length);
  for (let i = 0; i < withoutPins.length; i++) {
    assertEquals(withoutPins[i].primary?.id, withEmptyPins[i].primary?.id);
    assertEquals(withoutPins[i].total_carbs_g, withEmptyPins[i].total_carbs_g);
    assertEquals(withoutPins[i].total_sodium_mg, withEmptyPins[i].total_sodium_mg);
    assertEquals(withoutPins[i].total_fluid_ml, withEmptyPins[i].total_fluid_ml);
    assertEquals(withoutPins[i].pin_decision, undefined);
    assertEquals(withEmptyPins[i].pin_decision, undefined);
  }
});
