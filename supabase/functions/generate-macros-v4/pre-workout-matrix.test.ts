/**
 * Pre-Workout Template Selection — Comprehensive Test Matrix
 *
 * Data-driven test suite that exercises selectPreWorkoutFoods across:
 *   - 5 athlete profiles (weight, sweat, preferences)
 *   - 4 sport contexts (running, cycling, swimming, brick)
 *   - 3 time windows (full meal ≥2.5h, snack 1-2.5h, top-up <1h)
 *   - Edge cases (all fallbacks blocked, allergen stacking, fasted)
 *
 * Templates mirror production DB (pulled 2026-05-05).
 *
 * Run with:
 *   deno test --no-check --allow-write --allow-read \
 *     supabase/functions/generate-macros-v4/pre-workout-matrix.test.ts
 */

import {
  assertEquals,
  assert,
  assertNotEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import {
  calculatePreWorkoutTargets,
  selectPreWorkoutFoods,
  getActiveSubPhases,
} from './pre-workout.ts';

import type {
  PreWorkoutTemplate,
  PreWorkoutTargets,
  PreWorkoutPhaseResult,
} from './types.ts';

// ============================================================================
// Production Template Catalog (pulled from live DB 2026-05-05)
// ============================================================================

function t(overrides: Partial<PreWorkoutTemplate> & { id: string; name: string }): PreWorkoutTemplate {
  return {
    base_category: 'grain',
    time_window: '1.5-3 hours',
    digestion_speed: 'medium',
    allergens: [],
    excluded_diets: [],
    serving_unit: 'serving',
    min_servings: 1,
    max_servings: 2,
    plus_banana: true,
    plus_sports_drink: true,
    carbs_per_serving: 25,
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

// ── Meal templates (1.5-3 hours) ──────────────────────────────────────────

const BAGEL_CREAM_CHEESE = t({
  id: 'bagel-cream-cheese', name: 'Bagel + Cream Cheese', base_category: 'Bagel',
  time_window: '1.5-3 hours', carbs_per_serving: 27, protein_per_serving: 6, fat_per_serving: 5,
  sodium_mg: 350, min_servings: 1, max_servings: 2,
  component_food_names: ['bagel', 'cream_cheese'],
  component_quantities: { bagel: 0.5, cream_cheese: 1 },
  allergens: ['Gluten', 'Dairy'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo', 'vegan'],
});

const BAGEL_PB_JAM = t({
  id: 'bagel-pb-jam', name: 'Bagel + PB + Jam', base_category: 'Bagel',
  time_window: '1.5-3 hours', carbs_per_serving: 33, protein_per_serving: 9, fat_per_serving: 8,
  sodium_mg: 380, min_servings: 1, max_servings: 2,
  component_food_names: ['bagel', 'peanut_butter', 'jam'],
  component_quantities: { jam: 0.5, bagel: 0.5, peanut_butter: 1 },
  allergens: ['Gluten', 'Peanut'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo'],
});

const CEREAL_MILK = t({
  id: 'cereal-milk', name: 'Cereal + Milk', base_category: 'Cereal',
  time_window: '1.5-3 hours', carbs_per_serving: 25, protein_per_serving: 6, fat_per_serving: 3,
  sodium_mg: 200, min_servings: 1, max_servings: 3,
  plus_sports_drink: false,
  component_food_names: ['cereal', 'milk'],
  component_quantities: { milk: 0.5, cereal: 0.75 },
  allergens: ['Dairy', 'Gluten'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo', 'vegan'],
});

const OATMEAL = t({
  id: 'oatmeal', name: 'Oatmeal', base_category: 'Oats / Granola',
  time_window: '1.5-3 hours', carbs_per_serving: 27, protein_per_serving: 3, fat_per_serving: 1.5,
  sodium_mg: 0, min_servings: 1, max_servings: 3,
  plus_sports_drink: false,
  component_food_names: ['oatmeal'],
  component_quantities: { oatmeal: 1 },
  excluded_diets: ['gluten_free', 'keto', 'low_carb'],
});

const OATMEAL_RAISINS = t({
  id: 'oatmeal-raisins', name: 'Oatmeal + Raisins', base_category: 'Oats / Granola',
  time_window: '1.5-3 hours', carbs_per_serving: 35, protein_per_serving: 3.5, fat_per_serving: 1.5,
  sodium_mg: 5, min_servings: 1, max_servings: 3,
  plus_sports_drink: false,
  component_food_names: ['oatmeal', 'raisins'],
  component_quantities: { oatmeal: 1, raisins: 0.5 },
  excluded_diets: ['gluten_free', 'keto', 'low_carb'],
});

const RICE_CAKE_PB_JAM_MEAL = t({
  id: 'rice-cake-pb-jam-meal', name: 'Rice Cake + PB + Jam', base_category: 'Rice Cake',
  time_window: '1.5-3 hours', carbs_per_serving: 14, protein_per_serving: 4.5, fat_per_serving: 4,
  sodium_mg: 95, min_servings: 2, max_servings: 4,
  component_food_names: ['rice_cake', 'peanut_butter', 'jam'],
  component_quantities: { jam: 0.5, rice_cake: 1, peanut_butter: 0.5 },
  allergens: ['Peanut'], excluded_diets: ['keto', 'low_carb'],
});

const TOAST_PB_JAM_MEAL = t({
  id: 'toast-pb-jam-meal', name: 'Toast + PB + Jam', base_category: 'Toast / Bread',
  time_window: '1.5-3 hours', carbs_per_serving: 25, protein_per_serving: 7, fat_per_serving: 8,
  sodium_mg: 230, min_servings: 1, max_servings: 3,
  component_food_names: ['toast', 'peanut_butter', 'jam'],
  component_quantities: { jam: 0.5, toast: 1, peanut_butter: 1 },
  allergens: ['Gluten', 'Peanut'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo'],
});

const YOGURT_GRANOLA = t({
  id: 'yogurt-granola', name: 'Yogurt + Granola', base_category: 'Yogurt',
  time_window: '1.5-3 hours', carbs_per_serving: 20, protein_per_serving: 8, fat_per_serving: 5,
  sodium_mg: 125, min_servings: 1, max_servings: 3,
  plus_sports_drink: false,
  component_food_names: ['yogurt', 'granola'],
  component_quantities: { yogurt: 0.5, granola: 0.5 },
  allergens: ['Dairy', 'Gluten'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo', 'vegan'],
});

// ── Snack templates (30-90 min) ───────────────────────────────────────────

const BAGEL_JAM_SNACK = t({
  id: 'bagel-jam-snack', name: 'Bagel + Jam', base_category: 'Bagel',
  time_window: '30-90 min', carbs_per_serving: 28, protein_per_serving: 5, fat_per_serving: 1,
  sodium_mg: 305, min_servings: 1, max_servings: 2,
  component_food_names: ['bagel', 'jam'],
  component_quantities: { jam: 0.5, bagel: 0.5 },
  allergens: ['Gluten'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo'],
});

const BAGEL_PB_SNACK = t({
  id: 'bagel-pb-snack', name: 'Bagel + Peanut Butter', base_category: 'Bagel',
  time_window: '30-90 min', carbs_per_serving: 28, protein_per_serving: 9, fat_per_serving: 8,
  sodium_mg: 375, min_servings: 1, max_servings: 2,
  component_food_names: ['bagel', 'peanut_butter'],
  component_quantities: { bagel: 0.5, peanut_butter: 1 },
  allergens: ['Gluten', 'Peanut'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo'],
});

const GRANOLA_BAR = t({
  id: 'granola-bar', name: 'Granola Bar', base_category: 'Oats / Granola',
  time_window: '30-90 min', carbs_per_serving: 35, protein_per_serving: 4, fat_per_serving: 6,
  sodium_mg: 150, min_servings: 1, max_servings: 2,
  component_food_names: ['granola_bar'],
  component_quantities: { granola_bar: 1 },
  allergens: ['Gluten'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo'],
});

const OJ_TOAST = t({
  id: 'oj-toast', name: 'OJ + Toast', base_category: 'Liquid-Forward',
  time_window: '30-90 min', carbs_per_serving: 25, protein_per_serving: 4, fat_per_serving: 1,
  sodium_mg: 152, min_servings: 1, max_servings: 2,
  plus_sports_drink: false,
  component_food_names: ['orange_juice', 'toast'],
  component_quantities: { toast: 1, orange_juice: 0.5 },
  allergens: ['Gluten'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo'],
});

const RICE_CAKE_JAM_SNACK = t({
  id: 'rice-cake-jam-snack', name: 'Rice Cake + Jam', base_category: 'Rice Cake',
  time_window: '30-90 min', carbs_per_serving: 10, protein_per_serving: 0.5, fat_per_serving: 0,
  sodium_mg: 20, min_servings: 2, max_servings: 4,
  component_food_names: ['rice_cake', 'jam'],
  component_quantities: { jam: 0.5, rice_cake: 1 },
  excluded_diets: ['keto', 'low_carb'],
});

const RICE_CAKE_PB_SNACK = t({
  id: 'rice-cake-pb-snack', name: 'Rice Cake + Peanut Butter', base_category: 'Rice Cake',
  time_window: '30-90 min', carbs_per_serving: 10, protein_per_serving: 4.5, fat_per_serving: 4,
  sodium_mg: 90, min_servings: 2, max_servings: 4,
  component_food_names: ['rice_cake', 'peanut_butter'],
  component_quantities: { rice_cake: 1, peanut_butter: 0.5 },
  allergens: ['Peanut'], excluded_diets: ['keto', 'low_carb'],
});

const SMOOTHIE_FRUIT = t({
  id: 'smoothie-fruit', name: 'Smoothie (Fruit)', base_category: 'Smoothie',
  time_window: '30-90 min', carbs_per_serving: 25, protein_per_serving: 5.5, fat_per_serving: 2.5,
  sodium_mg: 51, min_servings: 1, max_servings: 2,
  plus_banana: false, plus_sports_drink: false,
  component_food_names: ['banana', 'blueberries', 'milk'],
  component_quantities: { milk: 0.5, banana: 0.5, blueberries: 0.5 },
  allergens: ['Dairy'], excluded_diets: ['paleo', 'vegan'],
});

const TOAST_JAM_SNACK = t({
  id: 'toast-jam-snack', name: 'Toast + Jam', base_category: 'Toast / Bread',
  time_window: '30-90 min', carbs_per_serving: 20, protein_per_serving: 3, fat_per_serving: 1,
  sodium_mg: 155, min_servings: 1, max_servings: 3,
  component_food_names: ['toast', 'jam'],
  component_quantities: { jam: 0.5, toast: 1 },
  allergens: ['Gluten'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo'],
});

const TOAST_PB_SNACK = t({
  id: 'toast-pb-snack', name: 'Toast + Peanut Butter', base_category: 'Toast / Bread',
  time_window: '30-90 min', carbs_per_serving: 20, protein_per_serving: 7, fat_per_serving: 8,
  sodium_mg: 225, min_servings: 1, max_servings: 2,
  component_food_names: ['toast', 'peanut_butter'],
  component_quantities: { toast: 1, peanut_butter: 1 },
  allergens: ['Gluten', 'Peanut'], excluded_diets: ['gluten_free', 'keto', 'low_carb', 'paleo'],
});

// ── Top-up templates (< 30 min) ──────────────────────────────────────────

const ENERGY_CHEWS = t({
  id: 'energy-chews', name: 'Energy Chews', base_category: 'Quick Grab',
  time_window: '< 30 min', template_type: 'food',
  carbs_per_serving: 25, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 50, min_servings: 1, max_servings: 2,
  component_food_names: ['energy_chews'], component_quantities: { energy_chews: 1 },
});

const ENERGY_GEL = t({
  id: 'energy-gel', name: 'Energy Gel', base_category: 'Quick Grab',
  time_window: '< 30 min', template_type: 'food',
  carbs_per_serving: 25, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 50, min_servings: 1, max_servings: 2,
  component_food_names: ['energy_gel'], component_quantities: { energy_gel: 1 },
});

// ── Vegan + GF + allergen-free templates (issue #13 — match DB migration
//    20260506100100_add_vegan_gf_pre_workout_templates.sql) ─────────────

const RICE_BANANA = t({
  id: 'rice-banana', name: 'Rice + Banana', base_category: 'White Rice',
  time_window: '1.5-3 hours', template_type: 'food', digestion_speed: 'medium',
  carbs_per_serving: 72, protein_per_serving: 5, fat_per_serving: 0.5,
  sodium_mg: 5, min_servings: 0.5, max_servings: 2,
  component_food_names: ['white_rice_cooked', 'banana'],
  component_quantities: { white_rice_cooked: 1, banana: 1 },
  allergens: [], excluded_diets: ['keto', 'low_carb'],
});

const POTATO_SALT = t({
  id: 'potato-salt', name: 'Potato + Salt', base_category: 'Potato',
  time_window: '1.5-3 hours', template_type: 'food', digestion_speed: 'medium',
  carbs_per_serving: 37, protein_per_serving: 2, fat_per_serving: 0.5,
  sodium_mg: 300, min_servings: 1, max_servings: 2,
  component_food_names: ['baked_potato'],
  component_quantities: { baked_potato: 1 },
  allergens: [], excluded_diets: ['keto', 'low_carb'],
});

const FRUIT_BOWL = t({
  id: 'fruit-bowl', name: 'Fruit Bowl', base_category: 'Fruit Mix',
  time_window: '1.5-3 hours', template_type: 'food', digestion_speed: 'fast',
  carbs_per_serving: 90, protein_per_serving: 2, fat_per_serving: 1,
  sodium_mg: 5, min_servings: 0.5, max_servings: 1.5,
  component_food_names: ['banana', 'dates', 'mixed_berries'],
  component_quantities: { banana: 1, dates: 3, mixed_berries: 0.5 },
  allergens: [], excluded_diets: ['keto'],
});

const DATES_BANANA = t({
  id: 'dates-banana', name: 'Dates + Banana', base_category: 'Fruit Mix',
  time_window: '30-90 min', template_type: 'food', digestion_speed: 'fast',
  carbs_per_serving: 63, protein_per_serving: 1.5, fat_per_serving: 0.5,
  sodium_mg: 5, min_servings: 0.5, max_servings: 2,
  component_food_names: ['dates', 'banana'],
  component_quantities: { dates: 2, banana: 1 },
  allergens: [], excluded_diets: ['keto'],
});

const BANANA_STANDALONE = t({
  id: 'banana', name: 'Banana', base_category: 'Fruit',
  time_window: '30-90 min', template_type: 'food', digestion_speed: 'fast',
  carbs_per_serving: 27, protein_per_serving: 1.3, fat_per_serving: 0.4,
  sodium_mg: 1, min_servings: 1, max_servings: 3,
  component_food_names: ['banana'], component_quantities: { banana: 1 },
  allergens: [], excluded_diets: ['keto'],
});

// ── Drink templates ──────────────────────────────────────────────────────

const WATER = t({
  id: 'water', name: 'Water', base_category: 'Hydration',
  time_window: '< 30 min', template_type: 'drink',
  carbs_per_serving: 0, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 0, fluid_ml: 240, min_servings: 0.5, max_servings: 3,
  plus_banana: false, plus_sports_drink: false,
  component_food_names: ['water'], component_quantities: { water: 1 },
});

const COCONUT_WATER = t({
  id: 'coconut-water', name: 'Coconut Water', base_category: 'Hydration',
  time_window: '< 30 min', template_type: 'drink',
  carbs_per_serving: 9, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 252, fluid_ml: 240, min_servings: 0.5, max_servings: 2,
  plus_banana: false, plus_sports_drink: false,
  component_food_names: ['coconut_water'], component_quantities: { coconut_water: 1 },
});

const SPORTS_DRINK = t({
  id: 'sports-drink', name: 'Sports Drink', base_category: 'Hydration',
  time_window: '< 30 min', template_type: 'drink',
  carbs_per_serving: 14, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 110, fluid_ml: 237, min_servings: 0.5, max_servings: 2,
  plus_banana: false, plus_sports_drink: false,
  component_food_names: ['sports_drink'], component_quantities: { sports_drink: 1 },
});

// ── Electrolyte templates ────────────────────────────────────────────────

const ELECTROLYTE_TABLET = t({
  id: 'electrolyte-tablet', name: 'Electrolyte Tablet', base_category: 'Electrolyte',
  time_window: '< 30 min', template_type: 'electrolyte',
  carbs_per_serving: 2, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 300, min_servings: 1, max_servings: 2,
  plus_banana: false, plus_sports_drink: false,
  component_food_names: ['electrolyte_tablet'], component_quantities: { electrolyte_tablet: 1 },
});

const ELECTROLYTE_DRINK_MIX = t({
  id: 'electrolyte-drink-mix', name: 'Electrolyte Drink Mix', base_category: 'Electrolyte',
  time_window: '< 30 min', template_type: 'electrolyte',
  carbs_per_serving: 15, protein_per_serving: 0, fat_per_serving: 0,
  sodium_mg: 400, min_servings: 1, max_servings: 1,
  plus_banana: false, plus_sports_drink: false,
  component_food_names: ['electrolyte_drink_mix'], component_quantities: { electrolyte_drink_mix: 1 },
});

// ── Template collections ─────────────────────────────────────────────────

const ALL_FOOD = [
  // Meal
  BAGEL_CREAM_CHEESE, BAGEL_PB_JAM, CEREAL_MILK, OATMEAL, OATMEAL_RAISINS,
  RICE_CAKE_PB_JAM_MEAL, TOAST_PB_JAM_MEAL, YOGURT_GRANOLA,
  RICE_BANANA, POTATO_SALT, FRUIT_BOWL, // vegan + GF + allergen-free meals
  // Snack
  BAGEL_JAM_SNACK, BAGEL_PB_SNACK, GRANOLA_BAR, OJ_TOAST,
  RICE_CAKE_JAM_SNACK, RICE_CAKE_PB_SNACK, SMOOTHIE_FRUIT,
  TOAST_JAM_SNACK, TOAST_PB_SNACK,
  DATES_BANANA, BANANA_STANDALONE, // vegan + GF + allergen-free snacks
  // Top-up
  ENERGY_CHEWS, ENERGY_GEL,
];

const ALL_DRINKS = [WATER, COCONUT_WATER, SPORTS_DRINK];
const ALL_ELECTROLYTES = [ELECTROLYTE_TABLET, ELECTROLYTE_DRINK_MIX];

// ============================================================================
// Athlete Profiles
// ============================================================================

interface AthleteProfile {
  name: string;
  weightKg: number;
  sweatSodium: string;    // 'low' | 'medium' | 'high'
  envLabel: string;       // 'mild' | 'warm' | 'hot' | 'very_hot'
  diet: string;           // 'none' | 'vegan' | 'gluten_free' | 'dairy_free' etc.
  allergies: string[];
  dislikedFoods: string[];
  likedFoods: string[];
}

const ATHLETES: AthleteProfile[] = [
  {
    name: 'Unrestricted (70kg male, no prefs)',
    weightKg: 70,
    sweatSodium: 'medium',
    envLabel: 'mild',
    diet: 'none',
    allergies: [],
    dislikedFoods: [],
    likedFoods: [],
  },
  {
    name: 'Picky Athlete (73kg, dislikes gels/chews/sports drink/rice cake)',
    weightKg: 73,
    sweatSodium: 'medium',
    envLabel: 'warm',
    diet: 'none',
    allergies: [],
    dislikedFoods: [
      'energy_gel', 'energy_chews', 'sports_drink', 'rice_cake',
      'electrolyte_capsule', 'high_sodium_electrolyte_mix',
    ],
    likedFoods: ['high_carb_drink_mix'],
  },
  {
    name: 'Vegan + Gluten-Free (60kg female)',
    weightKg: 60,
    sweatSodium: 'low',
    envLabel: 'mild',
    diet: 'vegan',
    allergies: ['Gluten'],
    dislikedFoods: [],
    likedFoods: [],
  },
  {
    name: 'Peanut + Dairy Allergy (80kg, hot climate)',
    weightKg: 80,
    sweatSodium: 'high',
    envLabel: 'hot',
    diet: 'none',
    allergies: ['Peanut', 'Dairy'],
    dislikedFoods: [],
    likedFoods: ['oatmeal', 'banana'],
  },
  {
    name: 'Maximum Restriction (65kg, vegan + all common allergies + picky)',
    weightKg: 65,
    sweatSodium: 'medium',
    envLabel: 'mild',
    diet: 'vegan',
    allergies: ['Gluten', 'Peanut', 'Dairy'],
    dislikedFoods: [
      'energy_gel', 'energy_chews', 'sports_drink', 'rice_cake',
    ],
    likedFoods: [],
  },
];

// ============================================================================
// Scenario Definitions
// ============================================================================

interface Scenario {
  name: string;
  hoursBefore: number;
  isFasted: boolean;
}

const TIME_WINDOWS: Scenario[] = [
  { name: 'Full meal (3h before)',  hoursBefore: 3.0, isFasted: false },
  { name: 'Snack (1.5h before)',    hoursBefore: 1.5, isFasted: false },
  { name: 'Top-up only (0.5h)',     hoursBefore: 0.5, isFasted: false },
  { name: 'Fasted',                 hoursBefore: 2.0, isFasted: true  },
];

// ============================================================================
// Assertion Helpers
// ============================================================================

function totalCarbs(results: PreWorkoutPhaseResult[]): number {
  return results.reduce((s, p) => s + p.total_carbs_g, 0);
}

function totalSodium(results: PreWorkoutPhaseResult[]): number {
  return results.reduce((s, p) => s + p.total_sodium_mg, 0);
}

function totalFluid(results: PreWorkoutPhaseResult[]): number {
  return results.reduce((s, p) => s + p.total_fluid_ml, 0);
}

function totalProtein(results: PreWorkoutPhaseResult[]): number {
  return results.reduce((s, p) => s + p.total_protein_g, 0);
}

function allFoodNames(results: PreWorkoutPhaseResult[]): string[] {
  const names: string[] = [];
  for (const phase of results) {
    if (phase.primary) names.push(...(phase.primary.component_food_names ?? []));
    if (phase.stack) names.push(...(phase.stack.component_food_names ?? []));
    for (const addOn of phase.add_ons) {
      if (addOn.type === 'banana') names.push('banana');
      if (addOn.type === 'sports_drink') names.push('sports_drink');
    }
    if (phase.drink) names.push(...(phase.drink.component_food_names ?? []));
  }
  return names;
}

function hasDislikedFood(results: PreWorkoutPhaseResult[], disliked: string[]): string | null {
  const dislikedSet = new Set(disliked);
  for (const name of allFoodNames(results)) {
    if (dislikedSet.has(name)) return name;
  }
  return null;
}

// TemplateSelection no longer carries `allergens` (it's a slim output shape),
// so map selections back to their source templates by id to check allergens.
const ALLERGENS_BY_TEMPLATE_ID = new Map<string, string[]>(
  [...ALL_FOOD, ...ALL_DRINKS, ...ALL_ELECTROLYTES].map(t => [t.id, t.allergens ?? []]),
);

function hasAllergen(results: PreWorkoutPhaseResult[], allergens: string[]): string | null {
  const allergenSet = new Set(allergens.map(a => a.toLowerCase()));
  for (const phase of results) {
    for (const selection of [phase.primary, phase.stack]) {
      if (!selection) continue;
      for (const templateAllergen of (ALLERGENS_BY_TEMPLATE_ID.get(selection.id) ?? [])) {
        if (allergenSet.has(templateAllergen.toLowerCase())) return templateAllergen;
      }
    }
  }
  return null;
}

// ============================================================================
// Core Matrix: Athlete × Time Window
// ============================================================================

describe('Pre-Workout Matrix', () => {

  for (const athlete of ATHLETES) {
    describe(`Athlete: ${athlete.name}`, () => {

      for (const scenario of TIME_WINDOWS) {
        describe(`${scenario.name}`, () => {
          const targets = calculatePreWorkoutTargets(
            athlete.weightKg,
            scenario.hoursBefore,
            scenario.isFasted,
            athlete.sweatSodium,
            athlete.envLabel,
          );

          const results = selectPreWorkoutFoods(
            targets,
            scenario.hoursBefore,
            athlete.diet,
            ALL_FOOD,
            ALL_DRINKS,
            ALL_ELECTROLYTES,
            athlete.likedFoods,
            athlete.dislikedFoods,
            athlete.allergies,
          );

          if (scenario.isFasted) {
            it('should return empty plan for fasted', () => {
              assertEquals(results.length, 0);
            });
            return; // skip remaining assertions for fasted
          }

          // ── Carb range ────────────────────────────────────────────
          it('should deliver carbs within target range (or document shortfall)', () => {
            const carbs = totalCarbs(results);
            // Per issue #15: when preferences eliminate all viable templates
            // for a phase, the algorithm now emits a shortfalls[] array
            // describing the gap rather than silently delivering 0g. Either
            // the carb target is met OR every short phase carries a carb
            // shortfall. Both are acceptable outcomes.
            const carbShortfallDocumented = results.some(
              (r) => (r.shortfalls ?? []).some((s) => s.macro === 'carbs'),
            );
            assert(
              carbs >= targets.carbs_low_g || carbShortfallDocumented,
              `[${athlete.name} / ${scenario.name}] Carbs ${carbs.toFixed(1)}g below ` +
              `minimum ${targets.carbs_low_g}g (target: ${targets.carbs_g}g) ` +
              `and no carb shortfall was documented`,
            );
            assert(
              carbs <= targets.carbs_high_g * 1.1, // 10% tolerance above high
              `[${athlete.name} / ${scenario.name}] Carbs ${carbs.toFixed(1)}g exceeds ` +
              `maximum ${targets.carbs_high_g}g`,
            );
          });

          // ── No disliked foods ─────────────────────────────────────
          it('should not include disliked foods', () => {
            const found = hasDislikedFood(results, athlete.dislikedFoods);
            assertEquals(
              found, null,
              `[${athlete.name} / ${scenario.name}] Found disliked food: ${found}`,
            );
          });

          // ── No allergens in food templates ────────────────────────
          if (athlete.allergies.length > 0) {
            it('should not include templates with allergens', () => {
              const found = hasAllergen(results, athlete.allergies);
              assertEquals(
                found, null,
                `[${athlete.name} / ${scenario.name}] Found allergen: ${found}`,
              );
            });
          }

          // ── At least one food selected per active food phase ──────
          it('should select food for each active phase', () => {
            const phases = getActiveSubPhases(scenario.hoursBefore);
            for (const phase of phases) {
              const phaseResult = results.find(r => r.phase === phase);
              assert(
                phaseResult !== undefined,
                `[${athlete.name} / ${scenario.name}] Missing phase: ${phase}`,
              );
            }
          });

          // ── Fluid delivered (should be > 0 for non-fasted) ────────
          it('should deliver some fluid', () => {
            const fluid = totalFluid(results);
            assert(
              fluid > 0,
              `[${athlete.name} / ${scenario.name}] Zero fluid delivered`,
            );
          });
        });
      }
    });
  }

  // ========================================================================
  // Issue #11 — Specific regression test
  // ========================================================================

  describe('Issue #11: Carb redistribution when top-off blocked', () => {
    const athlete = ATHLETES[1]; // Picky Athlete
    const targets = calculatePreWorkoutTargets(
      athlete.weightKg, 1.5, false, athlete.sweatSodium, athlete.envLabel,
    );
    const results = selectPreWorkoutFoods(
      targets, 1.5, athlete.diet,
      ALL_FOOD, ALL_DRINKS, ALL_ELECTROLYTES,
      athlete.likedFoods, athlete.dislikedFoods, athlete.allergies,
    );

    it('should meet carbs_low even when all top-off carbs are disliked', () => {
      const carbs = totalCarbs(results);
      assert(
        carbs >= targets.carbs_low_g,
        `Issue #11 regression: carbs ${carbs.toFixed(1)}g below minimum ` +
        `${targets.carbs_low_g}g. Top-off carb redistribution needed.`,
      );
    });

    it('should not include sports drink (disliked)', () => {
      const found = hasDislikedFood(results, ['sports_drink']);
      assertEquals(found, null, 'Sports drink appeared despite being disliked');
    });
  });

  // ========================================================================
  // Edge Cases
  // ========================================================================

  describe('Edge: Very light athlete (45kg)', () => {
    const targets = calculatePreWorkoutTargets(45, 1.5, false, 'low', 'mild');
    const results = selectPreWorkoutFoods(
      targets, 1.5, 'none',
      ALL_FOOD, ALL_DRINKS, ALL_ELECTROLYTES,
    );

    it('should produce valid plan with low carb targets', () => {
      const carbs = totalCarbs(results);
      assert(carbs > 0, 'Should deliver some carbs even for light athlete');
      assert(carbs <= targets.carbs_high_g * 1.1, `Carbs ${carbs}g exceeds high`);
    });
  });

  describe('Edge: Heavy athlete (100kg) full meal in hot climate', () => {
    const targets = calculatePreWorkoutTargets(100, 3.0, false, 'high', 'very_hot');
    const results = selectPreWorkoutFoods(
      targets, 3.0, 'none',
      ALL_FOOD, ALL_DRINKS, ALL_ELECTROLYTES,
    );

    it('should handle high carb and sodium targets', () => {
      const carbs = totalCarbs(results);
      assert(
        carbs >= targets.carbs_low_g,
        `Heavy/hot: carbs ${carbs}g below min ${targets.carbs_low_g}g`,
      );
    });

    it('should deliver elevated sodium for hot climate', () => {
      const sodium = totalSodium(results);
      assert(sodium > 200, `Expected elevated sodium for hot climate, got ${sodium}mg`);
    });
  });

  describe('Edge: Only rice cake templates available (minimal catalog)', () => {
    const minimalFood = [RICE_CAKE_JAM_SNACK, ENERGY_GEL];
    const targets = calculatePreWorkoutTargets(70, 1.5, false, 'medium', 'mild');
    const results = selectPreWorkoutFoods(
      targets, 1.5, 'none',
      minimalFood, [WATER], ALL_ELECTROLYTES,
    );

    it('should still produce a plan with limited templates', () => {
      assert(results.length > 0, 'Should produce some plan');
      const carbs = totalCarbs(results);
      assert(carbs > 0, 'Should deliver some carbs');
    });
  });

  describe('Edge: Vegan + gluten-free has very few options', () => {
    const targets = calculatePreWorkoutTargets(65, 3.0, false, 'medium', 'mild');
    const results = selectPreWorkoutFoods(
      targets, 3.0, 'vegan',
      ALL_FOOD, ALL_DRINKS, ALL_ELECTROLYTES,
      [], [], ['Gluten'],
    );

    it('should still deliver carbs with severely limited templates', () => {
      const carbs = totalCarbs(results);
      // Vegan + gluten-free eliminates most meal templates
      // Rice cake variants and energy products should still be available
      assert(carbs > 0, `Vegan+GF full meal: expected some carbs, got ${carbs}g`);
    });

    it('should not include any gluten or dairy templates', () => {
      const glutenFound = hasAllergen(results, ['Gluten']);
      assertEquals(glutenFound, null, `Found gluten template in vegan+GF plan`);
    });
  });

  describe('Edge: Short top-up only with everything disliked', () => {
    const targets = calculatePreWorkoutTargets(70, 0.4, false, 'medium', 'mild');
    const results = selectPreWorkoutFoods(
      targets, 0.4, 'none',
      ALL_FOOD, [WATER], ALL_ELECTROLYTES,
      [], ['energy_gel', 'energy_chews', 'sports_drink'], [],
    );

    it('should not crash and should deliver water at minimum', () => {
      assert(results.length > 0, 'Should produce at least one phase');
      const fluid = totalFluid(results);
      assert(fluid > 0, 'Should at least deliver water');
    });
  });

  // ========================================================================
  // No duplicate foods across phases
  // ========================================================================

  describe('Cross-phase uniqueness', () => {
    for (const athlete of ATHLETES) {
      for (const scenario of TIME_WINDOWS) {
        if (scenario.isFasted) continue;

        it(`${athlete.name} / ${scenario.name}: no duplicate primary categories`, () => {
          const targets = calculatePreWorkoutTargets(
            athlete.weightKg, scenario.hoursBefore, false,
            athlete.sweatSodium, athlete.envLabel,
          );
          const results = selectPreWorkoutFoods(
            targets, scenario.hoursBefore, athlete.diet,
            ALL_FOOD, ALL_DRINKS, ALL_ELECTROLYTES,
            athlete.likedFoods, athlete.dislikedFoods, athlete.allergies,
          );

          const categories = results
            .filter(r => r.primary)
            .map(r => r.primary!.base_category);
          const unique = new Set(categories);
          assertEquals(
            categories.length, unique.size,
            `Duplicate category across phases: ${categories.join(', ')}`,
          );
        });
      }
    }
  });
});

// ============================================================================
// Pin-State Matrix — formula-kit pins × athletes × time windows
// ============================================================================
// Sprint Task 3a4e3fdb-815c: cover pinned / partially pinned / unpinned kit
// states for every athlete × window combination, asserting the PRIMARY
// invariant — the produced fueling solution hits the carb target (or
// documents why not). Pin semantics under test (locked policy 2026-05-21):
// an in-scope pin (template.time_window === phase window) is honored
// unconditionally — diet/allergen/dislike filters and the serving clamp are
// bypassed — and the plan still converges on the carb band because pinned
// servings scale to the phase budget.

const WINDOW_FOR_PHASE: Record<string, string> = {
  meal: '1.5-3 hours',
  snack: '30-90 min',
  top_up: '< 30 min',
};

// One deterministic pin per window, drawn from the production catalog above.
const PIN_FOR_WINDOW: Record<string, PreWorkoutTemplate> = {
  '1.5-3 hours': OATMEAL,
  '30-90 min': TOAST_JAM_SNACK,
  '< 30 min': ENERGY_GEL,
};

type PinState = 'unpinned' | 'partial' | 'full';
const PIN_STATES: PinState[] = ['unpinned', 'partial', 'full'];

function pinsFor(state: PinState, hoursBefore: number): Set<string> | undefined {
  const windows = getActiveSubPhases(hoursBefore).map((p) => WINDOW_FOR_PHASE[p]);
  switch (state) {
    case 'unpinned':
      return undefined;
    case 'partial':
      return new Set([PIN_FOR_WINDOW[windows[0]].id]);
    case 'full':
      return new Set(windows.map((w) => PIN_FOR_WINDOW[w].id));
  }
}

describe('Pin-State Matrix', () => {
  for (const athlete of ATHLETES) {
    describe(`Athlete: ${athlete.name}`, () => {
      for (const scenario of TIME_WINDOWS) {
        if (scenario.isFasted) continue; // fasted plans are empty; pins moot

        for (const pinState of PIN_STATES) {
          describe(`${scenario.name} / ${pinState}`, () => {
            const targets = calculatePreWorkoutTargets(
              athlete.weightKg,
              scenario.hoursBefore,
              scenario.isFasted,
              athlete.sweatSodium,
              athlete.envLabel,
            );
            const pins = pinsFor(pinState, scenario.hoursBefore);
            const results = selectPreWorkoutFoods(
              targets,
              scenario.hoursBefore,
              athlete.diet,
              ALL_FOOD,
              ALL_DRINKS,
              ALL_ELECTROLYTES,
              athlete.likedFoods,
              athlete.dislikedFoods,
              athlete.allergies,
              pins,
            );

            // ── The primary invariant (Xuan): carb target hit, or the gap
            //    documented. Same contract as the base matrix.
            it('should hit the carb target or document the shortfall', () => {
              const carbs = totalCarbs(results);
              const carbShortfallDocumented = results.some(
                (r) => (r.shortfalls ?? []).some((s) => s.macro === 'carbs'),
              );
              assert(
                carbs >= targets.carbs_low_g || carbShortfallDocumented,
                `[${athlete.name} / ${scenario.name} / ${pinState}] Carbs ` +
                `${carbs.toFixed(1)}g below minimum ${targets.carbs_low_g}g ` +
                `and no carb shortfall was documented`,
              );
              assert(
                carbs <= targets.carbs_high_g * 1.1,
                `[${athlete.name} / ${scenario.name} / ${pinState}] Carbs ` +
                `${carbs.toFixed(1)}g exceeds maximum ${targets.carbs_high_g}g`,
              );
            });

            // ── Pin honoring per state ─────────────────────────────────
            if (pinState === 'unpinned') {
              it('should omit pin_decision entirely (no-pin parity contract)', () => {
                for (const r of results) {
                  assertEquals(
                    r.pin_decision, undefined,
                    `[${athlete.name} / ${scenario.name}] phase ${r.phase} ` +
                    `carries pin_decision without pins`,
                  );
                }
              });
            } else {
              it('should honor every in-scope pin unconditionally', () => {
                for (const r of results) {
                  const window = WINDOW_FOR_PHASE[r.phase];
                  const pinnedHere = pins!.has(PIN_FOR_WINDOW[window].id);
                  if (pinnedHere) {
                    assertEquals(
                      r.pin_decision?.used_pin, true,
                      `[${athlete.name} / ${scenario.name} / ${pinState}] ` +
                      `phase ${r.phase} did not honor its in-scope pin`,
                    );
                    assertEquals(
                      r.pin_decision?.pinned_template_id,
                      PIN_FOR_WINDOW[window].id,
                      `[${athlete.name} / ${scenario.name} / ${pinState}] ` +
                      `phase ${r.phase} honored the wrong pin`,
                    );
                  } else {
                    assertEquals(
                      r.pin_decision?.used_pin, false,
                      `[${athlete.name} / ${scenario.name} / ${pinState}] ` +
                      `unpinned phase ${r.phase} claims a pin`,
                    );
                    assertEquals(
                      r.pin_decision?.fallthrough_reason, 'no_pin_for_scope',
                      `[${athlete.name} / ${scenario.name} / ${pinState}] ` +
                      `unpinned phase ${r.phase} has wrong fallthrough reason`,
                    );
                  }
                }
              });
            }
          });
        }
      }
    });
  }
});
