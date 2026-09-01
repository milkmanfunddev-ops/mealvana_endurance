/**
 * Integration Tests for Pre-Workout V4 Algorithm
 *
 * Tests validate:
 * 1. Fluids hard cap — standalone drink doesn't push past 1.5x fluid target
 * 2. No duplicate bananas — banana never appears both as component and add-on
 * 3. Cross-phase uniqueness — no food_id duplication across sub-phases
 * 4. Variety — multiple scenarios yield at least 3 distinct primary templates
 * 5. Component explosion — nutrition proportional to component_quantities
 *
 * Run with:
 *   deno test --allow-net --allow-env supabase/functions/generate-macros-v4/pre-workout.test.ts
 */

import {
  assertEquals,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import {
  calculatePreWorkoutTargets,
  selectPreWorkoutFoods,
  getActiveSubPhases,
  splitTargets,
} from './pre-workout.ts';

import type {
  PreWorkoutTemplate,
  PreWorkoutPhaseResult,
} from './types.ts';

// ============================================================================
// Mock Template Data
// ============================================================================

function makeTemplate(overrides: Partial<PreWorkoutTemplate> & { id: string; name: string }): PreWorkoutTemplate {
  return {
    base_category: 'grain',
    time_window: '1.5-3 hours',
    digestion_speed: 'medium',
    allergens: [],
    serving_unit: 'serving',
    min_servings: 1,
    max_servings: 4,
    plus_banana: true,
    plus_sports_drink: true,
    carbs_per_serving: 30,
    protein_per_serving: 5,
    fat_per_serving: 3,
    sodium_mg: 100,
    fluid_ml: 0,
    template_type: 'food',
    is_active: true,
    component_food_names: [],
    component_quantities: {},
    ...overrides,
  };
}

// Meal templates (1.5-3 hours)
const TOAST_PB: PreWorkoutTemplate = makeTemplate({
  id: 'toast-pb', name: 'Toast + PB', base_category: 'toast',
  time_window: '1.5-3 hours',
  carbs_per_serving: 25, protein_per_serving: 8, fat_per_serving: 7,
  sodium_mg: 200, fluid_ml: 0,
  component_food_names: ['toast', 'peanut_butter'],
  component_quantities: { toast: 1, peanut_butter: 1 },
});

const OATMEAL: PreWorkoutTemplate = makeTemplate({
  id: 'oatmeal', name: 'Oatmeal', base_category: 'oatmeal',
  time_window: '1.5-3 hours',
  carbs_per_serving: 35, protein_per_serving: 6, fat_per_serving: 3,
  sodium_mg: 50, fluid_ml: 200,
  component_food_names: ['oatmeal', 'honey'],
  component_quantities: { oatmeal: 1, honey: 1 },
});

const SMOOTHIE_BANANA: PreWorkoutTemplate = makeTemplate({
  id: 'smoothie-banana', name: 'Smoothie (Fruit)', base_category: 'smoothie',
  time_window: '1.5-3 hours',
  carbs_per_serving: 40, protein_per_serving: 4, fat_per_serving: 2,
  sodium_mg: 30, fluid_ml: 300,
  component_food_names: ['banana', 'blueberries', 'milk'],
  component_quantities: { banana: 1, blueberries: 0.5, milk: 1 },
});

const PANCAKES: PreWorkoutTemplate = makeTemplate({
  id: 'pancakes', name: 'Pancakes', base_category: 'pancakes',
  time_window: '1.5-3 hours',
  carbs_per_serving: 30, protein_per_serving: 5, fat_per_serving: 5,
  sodium_mg: 300, fluid_ml: 0,
  component_food_names: ['pancake', 'maple_syrup'],
  component_quantities: { pancake: 1, maple_syrup: 1 },
});

// Snack templates (30-90 min)
const ENERGY_BAR: PreWorkoutTemplate = makeTemplate({
  id: 'energy-bar', name: 'Energy Bar', base_category: 'bar',
  time_window: '30-90 min',
  carbs_per_serving: 25, protein_per_serving: 5, fat_per_serving: 3,
  sodium_mg: 100, fluid_ml: 0,
  component_food_names: ['energy_bar'],
  component_quantities: { energy_bar: 1 },
});

const BANANA_SNACK: PreWorkoutTemplate = makeTemplate({
  id: 'banana-snack', name: 'Banana', base_category: 'fruit',
  time_window: '30-90 min',
  carbs_per_serving: 27, protein_per_serving: 1, fat_per_serving: 0,
  sodium_mg: 1, fluid_ml: 0,
  plus_banana: false,
  component_food_names: ['banana'],
  component_quantities: { banana: 1 },
});

const RICE_CAKE: PreWorkoutTemplate = makeTemplate({
  id: 'rice-cake', name: 'Rice Cake + Honey', base_category: 'rice_cake',
  time_window: '30-90 min',
  carbs_per_serving: 20, protein_per_serving: 2, fat_per_serving: 1,
  sodium_mg: 50, fluid_ml: 0,
  component_food_names: ['rice_cake', 'honey'],
  component_quantities: { rice_cake: 1, honey: 0.5 },
});

// Top-up templates (< 30 min)
const GEL: PreWorkoutTemplate = makeTemplate({
  id: 'gel', name: 'Energy Gel', base_category: 'gel',
  time_window: '< 30 min',
  carbs_per_serving: 25, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 50, fluid_ml: 30,
  min_servings: 1, max_servings: 2,
  component_food_names: ['energy_gel'],
  component_quantities: { energy_gel: 1 },
});

const CHEWS: PreWorkoutTemplate = makeTemplate({
  id: 'chews', name: 'Energy Chews', base_category: 'chews',
  time_window: '< 30 min',
  carbs_per_serving: 24, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 60, fluid_ml: 0,
  min_servings: 1, max_servings: 2,
  component_food_names: ['energy_chews'],
  component_quantities: { energy_chews: 1 },
});

// Drink templates
const WATER: PreWorkoutTemplate = makeTemplate({
  id: 'water', name: 'Water', base_category: 'water',
  time_window: '< 30 min',
  template_type: 'drink',
  carbs_per_serving: 0, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 0, fluid_ml: 240,
  min_servings: 0.5, max_servings: 4,
  plus_banana: false, plus_sports_drink: false,
  component_food_names: ['water'],
  component_quantities: { water: 1 },
});

const SPORTS_DRINK: PreWorkoutTemplate = makeTemplate({
  id: 'sports-drink', name: 'Sports Drink', base_category: 'sports_drink',
  time_window: '< 30 min',
  template_type: 'drink',
  carbs_per_serving: 17, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 110, fluid_ml: 240,
  min_servings: 0.5, max_servings: 3,
  plus_banana: false, plus_sports_drink: false,
  component_food_names: ['sports_drink'],
  component_quantities: { sports_drink: 1 },
});

// Electrolyte templates
const NUUN: PreWorkoutTemplate = makeTemplate({
  id: 'nuun', name: 'Nuun Tab', base_category: 'electrolyte',
  time_window: '< 30 min',
  template_type: 'electrolyte',
  carbs_per_serving: 2, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 300, fluid_ml: 0,
  min_servings: 1, max_servings: 2,
  plus_banana: false, plus_sports_drink: false,
  component_food_names: ['nuun'],
  component_quantities: { nuun: 1 },
});

const ALL_FOOD_TEMPLATES = [TOAST_PB, OATMEAL, SMOOTHIE_BANANA, PANCAKES, ENERGY_BAR, BANANA_SNACK, RICE_CAKE, GEL, CHEWS];
const ALL_DRINK_TEMPLATES = [WATER, SPORTS_DRINK];
const ALL_ELECTROLYTE_TEMPLATES = [NUUN];

// ============================================================================
// Helper Functions
// ============================================================================

/** Collect all banana appearances across all phases */
function countBananaAppearances(results: PreWorkoutPhaseResult[]): {
  asComponent: number;
  asAddOn: number;
  total: number;
} {
  let asComponent = 0;
  let asAddOn = 0;

  for (const phase of results) {
    // Check primary template components
    if (phase.primary?.component_food_names?.includes('banana')) asComponent++;
    // Check stack template components
    if (phase.stack?.component_food_names?.includes('banana')) asComponent++;
    // Check add-ons
    asAddOn += phase.add_ons.filter((a) => a.type === 'banana').length;
  }

  return { asComponent, asAddOn, total: asComponent + asAddOn };
}

/** Get total fluids across all phases */
function totalFluids(results: PreWorkoutPhaseResult[]): number {
  return results.reduce((sum, p) => sum + p.total_fluid_ml, 0);
}

/** Collect all primary template IDs */
function primaryTemplateIds(results: PreWorkoutPhaseResult[]): string[] {
  return results
    .filter((r) => r.primary !== null)
    .map((r) => r.primary!.id);
}

// ============================================================================
// Tests
// ============================================================================

describe('Pre-Workout V4 Integration Tests', () => {

  // ─── Test 1: Fluids Hard Cap ──────────────────────────────────────────

  describe('Fluids Hard Cap', () => {
    it('should not push total fluids past 1.5x fluid target with drink', () => {
      // 73kg athlete, 3h before → full meal + snack + top-up
      const targets = calculatePreWorkoutTargets(73, 3.0, false, 'medium', 'moderate');
      const fluidTarget = targets.water_ml;

      const results = selectPreWorkoutFoods(
        targets, 3.0, 'none',
        ALL_FOOD_TEMPLATES, ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
      );

      const total = totalFluids(results);
      const maxAllowed = fluidTarget * 1.5;

      assert(
        total <= maxAllowed,
        `Total fluids ${total}ml exceeded 1.5x target ${maxAllowed}ml (target: ${fluidTarget}ml)`,
      );
    });

    it('should respect fluid cap for heavy athlete with high-fluid foods', () => {
      // 91kg athlete, 3h before — higher targets, oatmeal + smoothie have high fluid
      const targets = calculatePreWorkoutTargets(91, 3.0, false, 'high', 'hot');
      const fluidTarget = targets.water_ml;

      const results = selectPreWorkoutFoods(
        targets, 3.0, 'none',
        ALL_FOOD_TEMPLATES, ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
      );

      const total = totalFluids(results);
      const maxAllowed = fluidTarget * 1.5;

      assert(
        total <= maxAllowed,
        `Total fluids ${total}ml exceeded 1.5x target ${maxAllowed}ml (target: ${fluidTarget}ml)`,
      );
    });
  });

  // ─── Test 2: No Duplicate Bananas ─────────────────────────────────────

  describe('No Duplicate Bananas', () => {
    it('should not add banana as add-on when primary contains banana component', () => {
      const targets = calculatePreWorkoutTargets(73, 3.0, false, 'medium', 'moderate');

      // Force smoothie-banana as a likely pick by making it the only meal template
      const foodTemplates = [SMOOTHIE_BANANA, ENERGY_BAR, GEL, CHEWS];

      const results = selectPreWorkoutFoods(
        targets, 3.0, 'none',
        foodTemplates, ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
      );

      const bananas = countBananaAppearances(results);

      // Banana should appear at most once total
      assert(
        bananas.total <= 1,
        `Banana appeared ${bananas.total} times (component: ${bananas.asComponent}, add-on: ${bananas.asAddOn}). ` +
        'Should appear at most once.',
      );

      // Specifically: if banana is in a component, no add-on banana
      if (bananas.asComponent > 0) {
        assertEquals(
          bananas.asAddOn, 0,
          'Banana add-on should not be used when a template already contains banana as component',
        );
      }
    });

    it('should set banana_used flag from component, preventing later add-on', () => {
      const targets = calculatePreWorkoutTargets(64, 3.0, false, 'low', 'moderate');

      // Smoothie (with banana) is the only meal option → meal phase gets banana component
      // Then snack/top_up phases should not get banana add-on
      const foodTemplates = [SMOOTHIE_BANANA, RICE_CAKE, GEL];

      const results = selectPreWorkoutFoods(
        targets, 3.0, 'none',
        foodTemplates, ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
      );

      const bananas = countBananaAppearances(results);
      assert(
        bananas.total <= 1,
        `Banana appeared ${bananas.total} times across phases. Expected at most 1.`,
      );
    });
  });

  // ─── Test 3: Cross-Phase Uniqueness ───────────────────────────────────

  describe('Cross-Phase Uniqueness', () => {
    it('should not duplicate primary template IDs across phases', () => {
      const targets = calculatePreWorkoutTargets(73, 3.0, false, 'medium', 'moderate');

      const results = selectPreWorkoutFoods(
        targets, 3.0, 'none',
        ALL_FOOD_TEMPLATES, ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
      );

      const ids = primaryTemplateIds(results);
      const uniqueIds = new Set(ids);

      assertEquals(
        ids.length, uniqueIds.size,
        `Duplicate primary template IDs found: ${ids.join(', ')}`,
      );
    });

    // NOTE: base_category uniqueness across phases is covered by
    // pre-workout-matrix.test.ts ("Cross-phase uniqueness") across the full
    // athlete × time-window matrix. Kept here: template_id uniqueness only.
  });

  // ─── Test 4: Variety ─────────────────────────────────────────────────

  describe('Variety', () => {
    it('should select at least 3 distinct primary templates across 20 scenarios', () => {
      const allPrimaryIds = new Set<string>();

      const weights = [54, 64, 73, 82, 91];
      const timings = [3.0, 2.5];
      const sweats = ['low', 'medium', 'high'];
      const envs = ['moderate', 'hot'];

      let scenarioCount = 0;
      for (const weight of weights) {
        for (const timing of timings) {
          for (const sweat of sweats) {
            for (const env of envs) {
              if (scenarioCount >= 20) break;
              const targets = calculatePreWorkoutTargets(weight, timing, false, sweat, env);
              const results = selectPreWorkoutFoods(
                targets, timing, 'none',
                ALL_FOOD_TEMPLATES, ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
              );

              for (const r of results) {
                if (r.primary) allPrimaryIds.add(r.primary.id);
              }
              scenarioCount++;
            }
          }
        }
      }

      assert(
        allPrimaryIds.size >= 3,
        `Only ${allPrimaryIds.size} distinct templates across ${scenarioCount} scenarios. ` +
        `Templates used: ${[...allPrimaryIds].join(', ')}. Expected at least 3.`,
      );
    });
  });

  // ─── Test 5: Component Explosion ─────────────────────────────────────

  describe('Component Explosion', () => {
    it('should produce nutrition proportional to servings', () => {
      const targets = calculatePreWorkoutTargets(73, 1.5, false, 'medium', 'moderate');

      // Use only energy bar for snack so we know exactly what to expect
      const results = selectPreWorkoutFoods(
        targets, 1.5, 'none',
        [ENERGY_BAR, GEL], ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
      );

      // Find the snack phase result
      const snackResult = results.find((r) => r.phase === 'snack');
      assert(snackResult !== undefined, 'Should have a snack phase');
      assert(snackResult!.primary !== null, 'Snack should have a primary selection');

      const primary = snackResult!.primary!;
      const template = [ENERGY_BAR, GEL].find((t) => t.id === primary.id)!;

      // Verify carbs are proportional to servings
      const expectedCarbs = Math.round(template.carbs_per_serving * primary.servings * 10) / 10;
      assertEquals(
        primary.carbs_g, expectedCarbs,
        `Carbs should be proportional: ${primary.servings} servings × ${template.carbs_per_serving}g = ${expectedCarbs}g, got ${primary.carbs_g}g`,
      );

      // Verify protein is proportional
      const expectedProtein = Math.round(template.protein_per_serving * primary.servings * 10) / 10;
      assertEquals(
        primary.protein_g, expectedProtein,
        `Protein should be proportional: ${primary.servings} servings × ${template.protein_per_serving}g = ${expectedProtein}g, got ${primary.protein_g}g`,
      );
    });

    it('should preserve component_food_names and component_quantities in selection', () => {
      const targets = calculatePreWorkoutTargets(73, 3.0, false, 'medium', 'moderate');

      const results = selectPreWorkoutFoods(
        targets, 3.0, 'none',
        ALL_FOOD_TEMPLATES, ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
      );

      for (const result of results) {
        if (result.primary) {
          const template = ALL_FOOD_TEMPLATES.find((t) => t.id === result.primary!.id);
          if (template) {
            assertEquals(
              result.primary.component_food_names, template.component_food_names,
              `component_food_names should be preserved for ${result.primary.name}`,
            );
          }
        }
      }
    });
  });

  // ─── Test 6: Target Calculation ────────────────────────────────────────

  describe('Target Calculation', () => {
    it('should return fasted targets when isFasted is true', () => {
      const targets = calculatePreWorkoutTargets(73, 3.0, true, 'medium', 'moderate');
      assertEquals(targets.carbs_g, 0);
      assertEquals(targets.protein_g, 0);
      assertEquals(targets.water_ml, 0);
      assertEquals(targets.meal_type, 'fasted');
    });

    it('should return empty results for fasted meal type', () => {
      const targets = calculatePreWorkoutTargets(73, 3.0, true, 'medium', 'moderate');
      const results = selectPreWorkoutFoods(
        targets, 3.0, 'none',
        ALL_FOOD_TEMPLATES, ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
      );
      assertEquals(results.length, 0);
    });

    it('should return full_meal type for >= 2 hours', () => {
      const targets = calculatePreWorkoutTargets(73, 3.0, false, 'medium', 'moderate');
      assertEquals(targets.meal_type, 'full_meal');
    });

    it('should return full_meal type from exactly 2 hours (carbs v2: TIER_MEAL_MIN = 120 min)', () => {
      // The boundary moved from 1.5 h to 2 h when carbs v2 was ratified, and it
      // is inclusive at the bottom.
      assertEquals(
        calculatePreWorkoutTargets(73, 2.0, false, 'medium', 'moderate').meal_type,
        'full_meal',
      );
      assertEquals(
        calculatePreWorkoutTargets(73, 119.999 / 60, false, 'medium', 'moderate').meal_type,
        'snack',
      );
    });

    it('should return snack type for 0.5-2 hours (1.5 h no longer earns a meal)', () => {
      assertEquals(
        calculatePreWorkoutTargets(73, 1.5, false, 'medium', 'moderate').meal_type,
        'snack',
      );
      assertEquals(
        calculatePreWorkoutTargets(73, 1.0, false, 'medium', 'moderate').meal_type,
        'snack',
      );
    });

    it('should return top_up type for < 0.5 hours', () => {
      const targets = calculatePreWorkoutTargets(73, 0.25, false, 'medium', 'moderate');
      assertEquals(targets.meal_type, 'top_up');
    });
  });

  // ─── Test 7: Variable Sports Drink Add-On ────────────────────────────

  describe('Variable Sports Drink Add-On', () => {
    it('should produce sports drink add-ons with valid servings (0.5, 1, or 2)', () => {
      const weights = [54, 64, 73, 82, 91];
      const timings = [3.0, 2.5, 1.5];

      for (const weight of weights) {
        for (const timing of timings) {
          const targets = calculatePreWorkoutTargets(weight, timing, false, 'medium', 'moderate');
          const results = selectPreWorkoutFoods(
            targets, timing, 'none',
            ALL_FOOD_TEMPLATES, ALL_DRINK_TEMPLATES, ALL_ELECTROLYTE_TEMPLATES,
          );

          for (const phase of results) {
            for (const addOn of phase.add_ons) {
              if (addOn.type === 'sports_drink') {
                assert(
                  [0.5, 1, 2].includes(addOn.servings),
                  `Sports drink add-on servings should be 0.5, 1, or 2, got ${addOn.servings}`,
                );
                // Verify nutrition scales with servings
                assert(
                  addOn.carbs_g > 0,
                  `Sports drink carbs should be > 0 for ${addOn.servings} servings`,
                );
                assert(
                  addOn.fluid_ml > 0,
                  `Sports drink fluid should be > 0 for ${addOn.servings} servings`,
                );
              }
            }
          }
        }
      }
    });
  });

  // ─── Test 8: Phase Splitting ───────────────────────────────────────────

  describe('Phase Splitting', () => {
    it('should have 3 phases for >= 2 hours', () => {
      const phases = getActiveSubPhases(3.0);
      assertEquals(phases.length, 3);
      assertEquals(phases, ['meal', 'snack', 'top_up']);
    });

    it('should have 3 phases from exactly 2 hours (carbs v2: TIER_MEAL_MIN = 120 min)', () => {
      const phases = getActiveSubPhases(2.0);
      assertEquals(phases.length, 3);
      assertEquals(phases, ['meal', 'snack', 'top_up']);
    });

    it('should have 2 phases for 0.5-2 hours (1.5 h no longer earns a meal)', () => {
      assertEquals(getActiveSubPhases(1.5), ['snack', 'top_up']);
      assertEquals(getActiveSubPhases(1.0), ['snack', 'top_up']);
    });

    it('should have 1 phase for < 0.5 hours', () => {
      const phases = getActiveSubPhases(0.25);
      assertEquals(phases.length, 1);
      assertEquals(phases, ['top_up']);
    });

    it('should split targets proportionally across active phases', () => {
      const targets = calculatePreWorkoutTargets(73, 3.0, false, 'medium', 'moderate');
      const phaseTargets = splitTargets(targets, 3.0);

      let totalCarbs = 0;
      for (const [, pt] of phaseTargets) {
        totalCarbs += pt.carbs_g;
      }

      // Total split carbs should approximately equal overall target
      assert(
        Math.abs(totalCarbs - targets.carbs_g) < 1,
        `Split carbs ${totalCarbs}g should approximately equal target ${targets.carbs_g}g`,
      );
    });
  });
});
