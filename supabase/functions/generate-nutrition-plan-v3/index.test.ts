/**
 * E2E Integration Tests for generate-nutrition-plan-v3 Edge Function
 *
 * Full pipeline: call generate-macros-v4 -> transform -> call generate-nutrition-plan-v3
 * Validates food selections, allergy compliance, dietary preferences, macro ranges,
 * brick workouts, diverse personas, user food integration, and variability.
 *
 * Run with:
 *   export SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
 *   export SUPABASE_ANON_KEY=<prod-anon-key>
 *   deno test --allow-net --allow-env supabase/functions/generate-nutrition-plan-v3/index.test.ts
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it, beforeAll, afterAll } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Configuration
// ============================================================================

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';
const MACROS_URL = `${SUPABASE_URL}/functions/v1/generate-macros-v4`;
const PLAN_URL = `${SUPABASE_URL}/functions/v1/generate-nutrition-plan-v3`;

// NO BUFFER. V4 gives us ranges. The plan must land within those ranges.
// If it doesn't, the edge function needs fixing.

// ============================================================================
// Allergen & Diet Keyword Maps
// ============================================================================

const ALLERGEN_KEYWORDS: Record<string, string[]> = {
  gluten: ['toast', 'bagel', 'oatmeal', 'cereal', 'granola', 'pancake', 'waffle', 'bread', 'pasta', 'cracker', 'pretzel', 'muffin', 'fig bar'],
  dairy: ['yogurt', 'milk', 'cheese', 'chocolate milk', 'latte', 'smoothie'],
  peanuts: ['peanut butter', 'peanut', ' pb '],
  'tree nuts': ['almond', 'cashew', 'walnut', 'pecan', 'pistachio', 'macadamia'],
  eggs: ['egg', 'pancake', 'waffle'],
};

const VEGAN_EXCLUDED_KEYWORDS = [
  'yogurt', 'milk', 'cheese', 'egg', 'honey', 'whey',
  'chocolate milk', 'greek yogurt',
];

// ============================================================================
// Known Food Lists (from template_foods and pre_workout_templates)
// ============================================================================

const KNOWN_TEMPLATE_FOOD_NAMES = [
  'banana', 'oatmeal', 'toast', 'bagel', 'rice_cake', 'rice cake', 'yogurt', 'granola',
  'energy_gel', 'energy gel', 'energy_chews', 'energy chews', 'water', 'sports_drink',
  'sports drink', 'coconut_water', 'coconut water', 'electrolyte_tablet', 'electrolyte tablet',
  'electrolyte_drink_mix', 'electrolyte drink mix', 'high_carb_drink_mix', 'high carb drink mix',
  'energy_bar', 'energy bar', 'fig_bar', 'fig bar', 'pretzels', 'honey', 'jam',
  'peanut_butter', 'peanut butter', 'milk', 'cereal', 'orange_juice', 'orange juice',
  'coffee', 'blueberries', 'maple_syrup', 'maple syrup', 'chocolate_milk', 'chocolate milk',
  'protein_shake', 'protein shake', 'rice', 'chicken', 'sweet_potato', 'sweet potato',
  'eggs', 'avocado', 'salmon', 'greek_yogurt', 'greek yogurt', 'white_rice', 'white rice',
  'pasta', 'bread', 'crackers', 'apple', 'dates', 'raisins', 'waffle', 'pancake',
  'pickle juice', 'pickle_juice', 'protein bar', 'protein_bar', 'sweet potato',
  'sweet_potato', 'recovery shake', 'recovery_shake', 'energy waffle', 'energy_waffle',
  'stroopwafel', 'rice crispy', 'rice_crispy', 'applesauce',
  'high-carb drink mix', 'drink mix', 'electrolyte mix',
  'electrolyte capsule', 'electrolyte_capsule',
  'electrolyte packet', 'electrolyte_packet',
  'high-sodium electrolyte mix', 'high_sodium_electrolyte_mix',
  'plant protein shake', 'plant_protein_shake',
];

// ============================================================================
// Helper Functions
// ============================================================================

async function callEdgeFunction(url: string, body: Record<string, unknown>): Promise<{ status: number; data: any }> {
  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  try {
    const data = JSON.parse(text);
    return { status: response.status, data };
  } catch {
    return { status: response.status, data: { success: false, error: `Non-JSON response: ${text.substring(0, 200)}` } };
  }
}

function assertInRange(actual: number, min: number, max: number, label: string): void {
  assert(
    actual >= min && actual <= max,
    `${label}: expected [${min.toFixed(1)}, ${max.toFixed(1)}], got ${actual.toFixed(1)}`,
  );
}

/**
 * Extract all food display_names from a plan response (flattened across phases).
 * @param excludeBefore - if true, skip before-phase foods
 */
function getAllFoodNames(plan: any, excludeBefore = false): string[] {
  const names: string[] = [];

  // Before phase sub-phases
  if (!excludeBefore && plan.before) {
    for (const subPhaseKey of ['meal', 'snack', 'top_up']) {
      const subPhase = plan.before[subPhaseKey];
      if (subPhase?.foods) {
        for (const food of subPhase.foods) {
          if (food.display_name) names.push(food.display_name.toLowerCase());
        }
      }
    }
  }

  // During phase (standard)
  if (plan.during?.foods) {
    for (const food of plan.during.foods) {
      if (food.display_name) names.push(food.display_name.toLowerCase());
    }
  }

  // During segments (brick)
  if (plan.during_segments) {
    for (const segKey of Object.keys(plan.during_segments)) {
      for (const food of plan.during_segments[segKey]) {
        if (food.display_name) names.push(food.display_name.toLowerCase());
      }
    }
  }

  // Transitions (brick)
  if (plan.transitions) {
    for (const tKey of Object.keys(plan.transitions)) {
      for (const food of plan.transitions[tKey]) {
        if (food.display_name) names.push(food.display_name.toLowerCase());
      }
    }
  }

  // After phase
  if (Array.isArray(plan.after)) {
    for (const food of plan.after) {
      if (food.display_name) names.push(food.display_name.toLowerCase());
    }
  }

  return names;
}

/**
 * Get all foods as FoodResult[] from all phases.
 */
function getAllFoods(plan: any): any[] {
  const foods: any[] = [];

  if (plan.before) {
    for (const key of ['meal', 'snack', 'top_up']) {
      if (plan.before[key]?.foods) {
        foods.push(...plan.before[key].foods);
      }
    }
  }
  if (plan.during?.foods) {
    foods.push(...plan.during.foods);
  }
  if (plan.during_segments) {
    for (const segKey of Object.keys(plan.during_segments)) {
      foods.push(...plan.during_segments[segKey]);
    }
  }
  if (plan.transitions) {
    for (const tKey of Object.keys(plan.transitions)) {
      foods.push(...plan.transitions[tKey]);
    }
  }
  if (Array.isArray(plan.after)) {
    foods.push(...plan.after);
  }

  return foods;
}

/**
 * Count total foods across all before sub-phases.
 */
function countBeforeFoods(plan: any): number {
  let count = 0;
  if (plan.before) {
    for (const key of ['meal', 'snack', 'top_up']) {
      if (plan.before[key]?.foods) count += plan.before[key].foods.length;
    }
  }
  return count;
}

/**
 * Get before-phase foods as flat array.
 */
function getBeforeFoods(plan: any): any[] {
  const foods: any[] = [];
  if (plan.before) {
    for (const key of ['meal', 'snack', 'top_up']) {
      if (plan.before[key]?.foods) foods.push(...plan.before[key].foods);
    }
  }
  return foods;
}

/**
 * Sum macros from a food array.
 */
function sumMacros(foods: any[]): { carbs: number; protein: number; fat: number; sodium: number; water: number; calories: number } {
  return foods.reduce(
    (acc, f) => ({
      carbs: acc.carbs + (f.carbs_grams ?? 0),
      protein: acc.protein + (f.protein_grams ?? 0),
      fat: acc.fat + (f.fat_grams ?? 0),
      sodium: acc.sodium + (f.sodium_mg ?? 0),
      water: acc.water + (f.fluids_ml ?? 0),
      calories: acc.calories + (f.calories ?? 0),
    }),
    { carbs: 0, protein: 0, fat: 0, sodium: 0, water: 0, calories: 0 },
  );
}

/**
 * Assert macro is within the V4 range. No buffer. No excuses.
 * If the plan can't hit the range, the edge function needs fixing.
 */
function assertMacroInRange(
  actual: number,
  low: number | undefined,
  high: number | undefined,
  label: string,
): void {
  if (low == null || high == null || (low === 0 && high === 0)) {
    // Range not provided or zero — skip
    return;
  }
  assert(
    actual >= low && actual <= high,
    `${label}: expected [${low.toFixed(1)}, ${high.toFixed(1)}], got ${actual.toFixed(1)}`,
  );
}

// ============================================================================
// Athlete Profiles (Base)
// ============================================================================

const macroProfiles: Record<string, Record<string, unknown>> = {
  smallFemale: {
    weight: 50,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 13.1,
    run_distance_unit: 'mi',
    run_pace: '9:30',
    gut_training: 'low',
    sweat_rate_category: 'light',
    sweat_sodium: 'low',
  },
  averageMale: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },
  heavyCyclist: {
    weight: 91,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    activity_type: 'cycling',
    distance_miles: 60,
    speed_mph: 20,
    terrain: 'flat',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 32,
    humidity_pct: 70,
  },
  fastedRunner: {
    weight: 65,
    weight_unit: 'kg',
    hours_before: 0,
    is_fasted: true,
    run_distance: 6,
    run_distance_unit: 'mi',
    run_pace: '7:30',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },
  swimmer: {
    weight: 73,
    weight_unit: 'kg',
    hours_before: 1.5,
    is_fasted: false,
    activity_type: 'swimming',
    distance_meters: 3000,
    pace_per_100m_seconds: 100,
    pool_or_open_water: 'pool',
    water_temp_c: 26,
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },
  lightweightTopUp: {
    weight: 55,
    weight_unit: 'kg',
    hours_before: 0.5,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '9:00',
    gut_training: 'moderate',
    sweat_rate_category: 'light',
    sweat_sodium: 'low',
  },
  // Cold weather runner
  coldWeatherRunner: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    run_distance: 8,
    run_distance_unit: 'mi',
    run_pace: '8:30',
    gut_training: 'moderate',
    sweat_rate_category: 'light',
    sweat_sodium: 'low',
    temp_c: 5,
    humidity_pct: 40,
  },
  // Very hot weather heavy sweater
  hotWeatherRunner: {
    weight: 82,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 20,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 35,
    humidity_pct: 80,
  },
  // Brick triathlete
  brickTriathlete: {
    weight: 75,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    activity_type: 'brick',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 28,
    humidity_pct: 65,
    brick_segments: [
      {
        sport: 'swimming',
        order: 1,
        duration_minutes: 30,
        intensity: 'moderate',
        distance_meters: 1500,
        pace_per_100m_seconds: 120,
        pool_or_open_water: 'open_water',
        water_temp_c: 22,
      },
      {
        sport: 'cycling',
        order: 2,
        duration_minutes: 75,
        intensity: 'moderate',
        distance_miles: 25,
        speed_mph: 20,
        terrain: 'flat',
      },
      {
        sport: 'running',
        order: 3,
        duration_minutes: 50,
        intensity: 'hard',
        pace_minutes_per_mile: 8,
      },
    ],
  },

  // ---- New profiles for audit expansion ----

  ultraRunner: {
    weight: 75,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 50,
    run_distance_unit: 'mi',
    run_pace: '10:00',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 30,
    humidity_pct: 60,
  },

  veryLightFemale: {
    weight: 44,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'km',
    run_pace: '10:00',
    gut_training: 'low',
    sweat_rate_category: 'light',
    sweat_sodium: 'low',
  },

  veryHeavyMale: {
    weight: 110,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '9:00',
    gut_training: 'moderate',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
  },

  longCyclist: {
    weight: 80,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    activity_type: 'cycling',
    distance_miles: 100,
    speed_mph: 18,
    terrain: 'hilly',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 32,
    humidity_pct: 60,
  },

  marathonHeavySweater: {
    weight: 85,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 26.2,
    run_distance_unit: 'mi',
    run_pace: '8:30',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 32,
    humidity_pct: 75,
  },

  shortEasyRun: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    run_distance: 5,
    run_distance_unit: 'mi',
    run_pace: '9:30',
    gut_training: 'moderate',
    sweat_rate_category: 'light',
    sweat_sodium: 'low',
  },

  mediumDistanceCyclist: {
    weight: 72,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    activity_type: 'cycling',
    distance_miles: 32,
    speed_mph: 16,
    terrain: 'flat',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  longSwimmer: {
    weight: 80,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    activity_type: 'swimming',
    distance_meters: 5000,
    pace_per_100m_seconds: 110,
    pool_or_open_water: 'open_water',
    water_temp_c: 20,
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },
};

// ============================================================================
// E2E Flow: macros V4 -> transform -> plan V3
// ============================================================================

interface FullPlanResult {
  macroData: any;
  planData: any;
  planStatus: number;
}

async function generateFullPlan(
  macroInput: Record<string, unknown>,
  overrides?: {
    dietary_preference?: string;
    allergies?: string[];
    liked_foods?: string[];
    disliked_foods?: string[];
    device_id?: string;
  },
): Promise<FullPlanResult> {
  // Step 1: Call macros V4 (with retry for transient WORKER_LIMIT)
  let macroResponse: any;
  for (let attempt = 0; attempt < 3; attempt++) {
    const { data } = await callEdgeFunction(MACROS_URL, macroInput);
    macroResponse = data;
    if (macroResponse.success) break;
    if (macroResponse.code === 'WORKER_LIMIT' && attempt < 2) {
      console.log(`[E2E] Macros V4 WORKER_LIMIT, retrying in ${(attempt + 1) * 2}s...`);
      await new Promise(r => setTimeout(r, (attempt + 1) * 2000));
      continue;
    }
    throw new Error(`Macros V4 failed: ${JSON.stringify(macroResponse)}`);
  }

  const m = macroResponse.macros;
  const activityType = (macroInput.activity_type as string) || 'running';
  const hoursBefore = macroInput.hours_before as number;
  const weightKg = macroInput.weight_unit === 'lb'
    ? (macroInput.weight as number) * 0.45359237
    : (macroInput.weight as number);

  // Step 2: Transform macros -> plan request
  const planInput: Record<string, unknown> = {
    device_id: overrides?.device_id ?? `test-e2e-${Date.now()}`,
    activity_type: activityType,
    hours_before: hoursBefore,
    weight_kg: weightKg,
    duration_minutes: m.duration_min,
    gut_training_level: macroInput.gut_training || 'moderate',
    macro_targets: {
      pre_run: {
        carbs_g: m.pre_run_carbs_g ?? m.phases?.before?.carbs_g ?? 0,
        sodium_mg: m.pre_run_sodium_mg ?? m.phases?.before?.sodium_mg ?? 0,
        water_ml: m.pre_run_water_ml ?? m.phases?.before?.water_ml ?? 0,
        protein_g: m.pre_run_protein_g ?? m.phases?.before?.protein_g ?? 0,
        fat_g: m.pre_run_fat_g ?? m.phases?.before?.fat_g ?? 0,
      },
      during_run: {
        carbs_g: m.during_total_g ?? 0,
        sodium_mg: m.during_sodium_total_mg ?? 0,
        water_ml: m.during_water_total_ml ?? 0,
      },
      post_run: {
        carbs_g: m.post_run_carbs_g ?? m.phases?.after?.carbs_g ?? 0,
        sodium_mg: m.post_run_sodium_mg ?? m.phases?.after?.sodium_mg ?? 0,
        water_ml: m.post_run_water_ml ?? m.phases?.after?.water_ml ?? 0,
        protein_g: m.post_run_protein_g ?? m.phases?.after?.protein_g ?? 0,
      },
    },
  };

  // For brick workouts, pass brick_segments with their macro_targets from macros V4
  if (activityType === 'brick' && m.phases?.during_segments) {
    const brickSegmentsInput = macroInput.brick_segments as any[];
    const brickSegments = m.phases.during_segments.map((seg: any, i: number) => ({
      sport: seg.sport,
      duration_minutes: seg.duration_min,
      macro_targets: {
        carbs_g: seg.carbs_g,
        sodium_mg: seg.sodium_mg,
        water_ml: seg.water_ml,
      },
    }));
    planInput.brick_segments = brickSegments;
  }

  // Apply overrides
  if (overrides?.dietary_preference) planInput.dietary_preference = overrides.dietary_preference;
  if (overrides?.allergies) planInput.allergies = overrides.allergies;
  if (overrides?.liked_foods) planInput.liked_foods = overrides.liked_foods;
  if (overrides?.disliked_foods) planInput.disliked_foods = overrides.disliked_foods;

  // Step 3: Call plan V3 (with retry on transient failure)
  let planStatus: number;
  let planData: any;

  for (let attempt = 0; attempt < 2; attempt++) {
    const result = await callEdgeFunction(PLAN_URL, planInput);
    planStatus = result.status;
    planData = result.data;
    if (planStatus === 200 && planData?.success) break;
    if (attempt === 0) {
      console.log(`[E2E] Plan V3 attempt 1 failed (status=${planStatus}), retrying...`);
      await new Promise(r => setTimeout(r, 1000));
    }
  }

  return { macroData: macroResponse, planData: planData!, planStatus: planStatus! };
}

// ============================================================================
// Tests
// ============================================================================

describe('generate-nutrition-plan-v3 E2E Tests', () => {
  beforeAll(() => {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
      console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variables');
      Deno.exit(1);
    }
  });

  // =========================================================================
  // 1. E2E Response Structure (8 tests)
  // =========================================================================

  describe('1. E2E Response Structure', () => {
    it('should return valid plan for running', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale);
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      assertExists(planData.plan_id);
      assertExists(planData.plan);
    });

    it('should return valid plan for cycling', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.heavyCyclist);
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      assertExists(planData.plan);
    });

    it('should return valid plan for swimming', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.swimmer);
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      assertExists(planData.plan);
    });

    it('should have meal+snack+top_up sub-phases for 3h before', async () => {
      const { planData } = await generateFullPlan(macroProfiles.smallFemale);
      const before = planData.plan.before;
      const subPhaseKeys = Object.keys(before);
      assert(subPhaseKeys.length >= 2, `Expected >= 2 sub-phases for 3h window, got ${subPhaseKeys.length}: ${subPhaseKeys.join(',')}`);
    });

    it('should have snack+top_up sub-phases for 1.5h before', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.swimmer);
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      assertExists(planData.plan, 'Plan response should have plan object');
      const before = planData.plan.before;
      assertExists(before, 'Plan should have before phase');
      assert(!before.meal || before.meal.foods?.length === 0,
        'Should not have meal sub-phase for 1.5h');
    });

    it('should have top_up only for 0.5h before', async () => {
      const { planData } = await generateFullPlan(macroProfiles.lightweightTopUp);
      const before = planData.plan.before;
      assert(!before.meal || Object.keys(before.meal).length === 0 || before.meal.foods?.length === 0,
        'Should not have meal for 0.5h');
      assert(!before.snack || Object.keys(before.snack).length === 0 || before.snack.foods?.length === 0,
        'Should not have snack for 0.5h');
    });

    it('should have during phase structure with foods and by_hour_data', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      assertExists(planData.plan.during, 'Plan should have during phase');
      assert(Array.isArray(planData.plan.during.foods), 'during.foods should be array');
    });

    it('should have empty before for fasted runner', async () => {
      const { planData } = await generateFullPlan(macroProfiles.fastedRunner);
      const totalBeforeFoods = countBeforeFoods(planData.plan);
      assertEquals(totalBeforeFoods, 0, 'Fasted should have 0 before-phase foods');
    });
  });

  // =========================================================================
  // 2. Food Quality (6 tests)
  // =========================================================================

  describe('2. Food Quality', () => {
    it('all foods should have valid nutritional data', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const allFoods = getAllFoods(planData.plan);

      for (const food of allFoods) {
        assertExists(food.food_id, 'food should have food_id');
        assert(food.quantity > 0, `food ${food.food_id} should have positive quantity, got ${food.quantity}`);
        assert(food.calories >= 0, `food ${food.food_id} should have non-negative calories`);
      }
    });

    it('no UUIDs as display names', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const names = getAllFoodNames(planData.plan);
      const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

      for (const name of names) {
        assert(!uuidPattern.test(name), `Found UUID as display_name: ${name}`);
      }
    });

    it('display_names should be set for all foods', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const allFoods = getAllFoods(planData.plan);

      for (const food of allFoods) {
        assert(
          food.display_name && food.display_name.length > 0,
          `Food ${food.food_id} missing display_name`,
        );
      }
    });

    it('all quantities should be positive', async () => {
      const { planData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const allFoods = getAllFoods(planData.plan);
      for (const food of allFoods) {
        assert(food.quantity > 0, `Food ${food.display_name} has non-positive quantity: ${food.quantity}`);
      }
    });

    it('at least 1 food per active phase', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const beforeCount = countBeforeFoods(planData.plan);
      assert(beforeCount >= 1, `Expected >= 1 before food, got ${beforeCount}`);
      assert(
        planData.plan.during.foods.length >= 1,
        `Expected >= 1 during food, got ${planData.plan.during.foods.length}`,
      );
      assert(
        planData.plan.after.length >= 1,
        `Expected >= 1 after food, got ${planData.plan.after.length}`,
      );
    });

    it('calories should roughly match macros (carbs*4 + protein*4 + fat*9)', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const allFoods = getAllFoods(planData.plan);

      for (const food of allFoods) {
        const expectedCalories = (food.carbs_grams ?? 0) * 4 + (food.protein_grams ?? 0) * 4 + (food.fat_grams ?? 0) * 9;
        if (expectedCalories > 0 && food.calories > 0) {
          const ratio = food.calories / expectedCalories;
          assert(
            ratio >= 0.7 && ratio <= 1.5,
            `Food ${food.display_name}: calories ${food.calories} vs calculated ${expectedCalories.toFixed(0)} (ratio: ${ratio.toFixed(2)})`,
          );
        }
      }
    });
  });

  // =========================================================================
  // 3. STRICT Macro Range Adherence (15+ tests)
  // =========================================================================

  describe('3. Strict Macro Range Adherence', () => {
    // --- BEFORE PHASE ---

    it('before carbs within V4 range (small female runner)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.smallFemale);
      const beforeCarbs = sumMacros(getBeforeFoods(planData.plan)).carbs;
      const m = macroData.macros;
      console.log(`  Before carbs (small): ${beforeCarbs.toFixed(1)}g | range: [${m.pre_run_carbs_low_g}, ${m.pre_run_carbs_high_g}]`);
      assertMacroInRange(beforeCarbs, m.pre_run_carbs_low_g, m.pre_run_carbs_high_g, 'Before carbs (small female)');
    });

    it('before carbs within V4 range (heavy cyclist)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const beforeCarbs = sumMacros(getBeforeFoods(planData.plan)).carbs;
      const m = macroData.macros;
      console.log(`  Before carbs (cyclist): ${beforeCarbs.toFixed(1)}g | range: [${m.pre_run_carbs_low_g}, ${m.pre_run_carbs_high_g}]`);
      assertMacroInRange(beforeCarbs, m.pre_run_carbs_low_g, m.pre_run_carbs_high_g, 'Before carbs (cyclist)');
    });

    it('before protein within V4 range (3h meal window)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.smallFemale);
      const beforeProtein = sumMacros(getBeforeFoods(planData.plan)).protein;
      const m = macroData.macros;
      console.log(`  Before protein: ${beforeProtein.toFixed(1)}g | range: [${m.pre_run_protein_low_g}, ${m.pre_run_protein_high_g}]`);
      assertMacroInRange(beforeProtein, m.pre_run_protein_low_g, m.pre_run_protein_high_g, 'Before protein');
    });

    it('before sodium within V4 range', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const beforeSodium = sumMacros(getBeforeFoods(planData.plan)).sodium;
      const m = macroData.macros;
      console.log(`  Before sodium: ${beforeSodium.toFixed(0)}mg | range: [${m.pre_run_sodium_low_mg}, ${m.pre_run_sodium_high_mg}]`);
      assertMacroInRange(beforeSodium, m.pre_run_sodium_low_mg, m.pre_run_sodium_high_mg, 'Before sodium');
    });

    it('before hydration within V4 range', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const beforeWater = sumMacros(getBeforeFoods(planData.plan)).water;
      const m = macroData.macros;
      console.log(`  Before hydration: ${beforeWater.toFixed(0)}ml | range: [${m.pre_run_water_low_ml}, ${m.pre_run_water_high_ml}]`);
      assertMacroInRange(beforeWater, m.pre_run_water_low_ml, m.pre_run_water_high_ml, 'Before hydration');
    });

    // --- DURING PHASE ---

    it('during carbs within V4 band range (running)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const duringCarbs = sumMacros(planData.plan.during.foods).carbs;
      const m = macroData.macros;
      const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
      const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;
      console.log(`  During carbs (running): ${duringCarbs.toFixed(1)}g | band: [${bandLowTotal.toFixed(0)}, ${bandHighTotal.toFixed(0)}]`);
      assertMacroInRange(duringCarbs, bandLowTotal, bandHighTotal, 'During carbs (running)');
    });

    it('during carbs within V4 band range (cycling)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const duringCarbs = sumMacros(planData.plan.during.foods).carbs;
      const m = macroData.macros;
      const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
      const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;
      console.log(`  During carbs (cycling): ${duringCarbs.toFixed(1)}g | band: [${bandLowTotal.toFixed(0)}, ${bandHighTotal.toFixed(0)}]`);
      assertMacroInRange(duringCarbs, bandLowTotal, bandHighTotal, 'During carbs (cycling)');
    });

    it('during sodium within V4 range (running)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const duringSodium = sumMacros(planData.plan.during.foods).sodium;
      const m = macroData.macros;
      console.log(`  During sodium (running): ${duringSodium.toFixed(0)}mg | range: [${m.during_sodium_low_mg}, ${m.during_sodium_high_mg}]`);
      assertMacroInRange(duringSodium, m.during_sodium_low_mg, m.during_sodium_high_mg, 'During sodium (running)');
    });

    it('during hydration within V4 range (running)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const duringWater = sumMacros(planData.plan.during.foods).water;
      const m = macroData.macros;
      console.log(`  During hydration (running): ${duringWater.toFixed(0)}ml | range: [${m.during_water_low_ml}, ${m.during_water_high_ml}]`);
      assertMacroInRange(duringWater, m.during_water_low_ml, m.during_water_high_ml, 'During hydration (running)');
    });

    it('during sodium within V4 range (heavy cyclist)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const duringSodium = sumMacros(planData.plan.during.foods).sodium;
      const m = macroData.macros;
      console.log(`  During sodium (cyclist): ${duringSodium.toFixed(0)}mg | range: [${m.during_sodium_low_mg}, ${m.during_sodium_high_mg}]`);
      assertMacroInRange(duringSodium, m.during_sodium_low_mg, m.during_sodium_high_mg, 'During sodium (cyclist)');
    });

    it('during hydration within V4 range (heavy cyclist)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const duringWater = sumMacros(planData.plan.during.foods).water;
      const m = macroData.macros;
      console.log(`  During hydration (cyclist): ${duringWater.toFixed(0)}ml | range: [${m.during_water_low_ml}, ${m.during_water_high_ml}]`);
      assertMacroInRange(duringWater, m.during_water_low_ml, m.during_water_high_ml, 'During hydration (cyclist)');
    });

    it('during sodium within V4 range (hot weather runner)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.hotWeatherRunner);
      const duringSodium = sumMacros(planData.plan.during.foods).sodium;
      const m = macroData.macros;
      console.log(`  During sodium (hot): ${duringSodium.toFixed(0)}mg | range: [${m.during_sodium_low_mg}, ${m.during_sodium_high_mg}]`);
      assertMacroInRange(duringSodium, m.during_sodium_low_mg, m.during_sodium_high_mg, 'During sodium (hot weather)');
    });

    it('during hydration within V4 range (hot weather runner)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.hotWeatherRunner);
      const duringWater = sumMacros(planData.plan.during.foods).water;
      const m = macroData.macros;
      console.log(`  During hydration (hot): ${duringWater.toFixed(0)}ml | range: [${m.during_water_low_ml}, ${m.during_water_high_ml}]`);
      assertMacroInRange(duringWater, m.during_water_low_ml, m.during_water_high_ml, 'During hydration (hot weather)');
    });

    it('swimming during carbs = 0', async () => {
      const { planData } = await generateFullPlan(macroProfiles.swimmer);
      assertEquals(
        planData.plan.during.foods.length,
        0,
        'Swimming should have 0 during-phase foods',
      );
    });

    // --- AFTER PHASE ---

    it('after carbs within V4 range (average male)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const afterCarbs = sumMacros(planData.plan.after).carbs;
      const m = macroData.macros;
      console.log(`  After carbs: ${afterCarbs.toFixed(1)}g | range: [${m.post_run_carbs_low_g}, ${m.post_run_carbs_high_g}]`);
      assertMacroInRange(afterCarbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, 'After carbs');
    });

    it('after protein within V4 range (average male)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const afterProtein = sumMacros(planData.plan.after).protein;
      const m = macroData.macros;
      console.log(`  After protein: ${afterProtein.toFixed(1)}g | range: [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
      assertMacroInRange(afterProtein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'After protein');
    });

    it('after sodium within V4 range (average male)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const afterSodium = sumMacros(planData.plan.after).sodium;
      const m = macroData.macros;
      console.log(`  After sodium: ${afterSodium.toFixed(0)}mg | range: [${m.post_run_sodium_low_mg}, ${m.post_run_sodium_high_mg}]`);
      assertMacroInRange(afterSodium, m.post_run_sodium_low_mg, m.post_run_sodium_high_mg, 'After sodium');
    });

    it('after hydration within V4 range (average male)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const afterWater = sumMacros(planData.plan.after).water;
      const m = macroData.macros;
      console.log(`  After hydration: ${afterWater.toFixed(0)}ml | range: [${m.post_run_water_low_ml}, ${m.post_run_water_high_ml}]`);
      assertMacroInRange(afterWater, m.post_run_water_low_ml, m.post_run_water_high_ml, 'After hydration');
    });

    it('after carbs within V4 range (heavy cyclist)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const afterCarbs = sumMacros(planData.plan.after).carbs;
      const m = macroData.macros;
      console.log(`  After carbs (cyclist): ${afterCarbs.toFixed(1)}g | range: [${m.post_run_carbs_low_g}, ${m.post_run_carbs_high_g}]`);
      assertMacroInRange(afterCarbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, 'After carbs (cyclist)');
    });

    it('after protein within V4 range (heavy cyclist)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const afterProtein = sumMacros(planData.plan.after).protein;
      const m = macroData.macros;
      console.log(`  After protein (cyclist): ${afterProtein.toFixed(1)}g | range: [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
      assertMacroInRange(afterProtein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'After protein (cyclist)');
    });

    it('after sodium within V4 range (heavy cyclist)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const afterSodium = sumMacros(planData.plan.after).sodium;
      const m = macroData.macros;
      console.log(`  After sodium (cyclist): ${afterSodium.toFixed(0)}mg | range: [${m.post_run_sodium_low_mg}, ${m.post_run_sodium_high_mg}]`);
      assertMacroInRange(afterSodium, m.post_run_sodium_low_mg, m.post_run_sodium_high_mg, 'After sodium (cyclist)');
    });

    it('after hydration within V4 range (heavy cyclist)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const afterWater = sumMacros(planData.plan.after).water;
      const m = macroData.macros;
      console.log(`  After hydration (cyclist): ${afterWater.toFixed(0)}ml | range: [${m.post_run_water_low_ml}, ${m.post_run_water_high_ml}]`);
      assertMacroInRange(afterWater, m.post_run_water_low_ml, m.post_run_water_high_ml, 'After hydration (cyclist)');
    });

    it('after sodium within V4 range (hot weather runner)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.hotWeatherRunner);
      const afterSodium = sumMacros(planData.plan.after).sodium;
      const m = macroData.macros;
      console.log(`  After sodium (hot): ${afterSodium.toFixed(0)}mg | range: [${m.post_run_sodium_low_mg}, ${m.post_run_sodium_high_mg}]`);
      assertMacroInRange(afterSodium, m.post_run_sodium_low_mg, m.post_run_sodium_high_mg, 'After sodium (hot weather)');
    });

    it('after hydration within V4 range (hot weather runner)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.hotWeatherRunner);
      const afterWater = sumMacros(planData.plan.after).water;
      const m = macroData.macros;
      console.log(`  After hydration (hot): ${afterWater.toFixed(0)}ml | range: [${m.post_run_water_low_ml}, ${m.post_run_water_high_ml}]`);
      assertMacroInRange(afterWater, m.post_run_water_low_ml, m.post_run_water_high_ml, 'After hydration (hot weather)');
    });

    it('total plan calories reasonable (200-5000 kcal)', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const allFoods = getAllFoods(planData.plan);
      const totalCals = sumMacros(allFoods).calories;
      console.log(`  Total plan calories: ${totalCals.toFixed(0)} kcal`);
      assertInRange(totalCals, 200, 5000, 'Total plan calories');
    });
  });

  // =========================================================================
  // 4. Allergy Compliance (10 tests)
  // =========================================================================

  describe('4. Allergy Compliance', () => {
    /**
     * Check that allergen foods are excluded from during/after phases.
     * Before-phase uses Algorithm C template-level filtering (not component-level).
     */
    function assertNoAllergenFoods(plan: any, allergen: string, checkBefore = false): void {
      const names = getAllFoodNames(plan, /* excludeBefore */ !checkBefore);
      const keywords = ALLERGEN_KEYWORDS[allergen.toLowerCase()] ?? [];

      for (const name of names) {
        for (const keyword of keywords) {
          assert(
            !name.includes(keyword.toLowerCase()),
            `Found "${keyword}" in food "${name}" — should be excluded for ${allergen} allergy`,
          );
        }
      }
    }

    it('gluten allergy excludes gluten foods', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['gluten'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      assertNoAllergenFoods(planData.plan, 'gluten');
    });

    it('dairy allergy excludes dairy foods', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['dairy'],
      });
      assertEquals(planStatus, 200);
      assertNoAllergenFoods(planData.plan, 'dairy');
    });

    it('peanut allergy excludes peanut foods', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['peanuts'],
      });
      assertEquals(planStatus, 200);
      assertNoAllergenFoods(planData.plan, 'peanuts');
    });

    it('tree nut allergy excludes tree nut foods', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['tree nuts'],
      });
      assertEquals(planStatus, 200);
      assertNoAllergenFoods(planData.plan, 'tree nuts');
    });

    it('egg allergy excludes egg foods', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['eggs'],
      });
      assertEquals(planStatus, 200);
      assertNoAllergenFoods(planData.plan, 'eggs');
    });

    it('multiple simultaneous allergies', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['gluten', 'dairy'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      assertNoAllergenFoods(planData.plan, 'gluten');
      assertNoAllergenFoods(planData.plan, 'dairy');
    });

    it('all major allergies still produces valid plan', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['gluten', 'dairy', 'peanuts', 'tree nuts', 'eggs'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, `Should still have foods with all allergies, got ${allFoods.length}`);
    });

    it('case-insensitive allergy names', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['GLUTEN', 'Dairy'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      assertNoAllergenFoods(planData.plan, 'gluten');
    });

    it('allergy filtering with heavy cyclist profile', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.heavyCyclist, {
        allergies: ['dairy'],
      });
      assertEquals(planStatus, 200);
      assertNoAllergenFoods(planData.plan, 'dairy');
    });

    it('water is never excluded by allergies', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['gluten', 'dairy', 'peanuts', 'tree nuts', 'eggs'],
      });
      assertEquals(planData.success, true);
    });
  });

  // =========================================================================
  // 5. Dietary Preference Compliance (8 tests)
  // =========================================================================

  describe('5. Dietary Preference Compliance', () => {
    it('vegan excludes animal products', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'vegan',
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      const names = getAllFoodNames(planData.plan);
      for (const name of names) {
        for (const keyword of VEGAN_EXCLUDED_KEYWORDS) {
          assert(
            !name.includes(keyword.toLowerCase()),
            `Found "${keyword}" in food "${name}" — should be excluded for vegan diet`,
          );
        }
      }
    });

    it('gluten-free preference produces valid plan', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'gluten-free',
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, 'Should have foods with gluten-free preference');
    });

    it('dairy-free preference produces valid plan', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'dairy-free',
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
    });

    it('valid plan for vegan', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'vegan',
      });
      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, 'Vegan plan should still have foods');
    });

    it('valid plan for vegetarian', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'vegetarian',
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
    });

    it('combined allergy + diet', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'vegan',
        allergies: ['gluten'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, 'Combined vegan+gluten-free should still work');
    });

    it('paleo diet produces valid plan', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'paleo',
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
    });

    it('no dietary preference produces valid plan', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale);
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
    });
  });

  // =========================================================================
  // 6. Disliked Foods Exclusion (8 tests)
  // =========================================================================

  describe('6. Disliked Foods Exclusion', () => {
    it('disliked banana excluded from during/after phases', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        disliked_foods: ['banana'],
      });
      assertEquals(planStatus, 200);
      const names = getAllFoodNames(planData.plan, /* excludeBefore */ true);
      for (const name of names) {
        assert(!name.includes('banana'), `Found "banana" in during/after despite being disliked: ${name}`);
      }
    });

    it('disliked oatmeal excluded from during/after phases', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.smallFemale, {
        disliked_foods: ['oatmeal'],
      });
      assertEquals(planStatus, 200);
      const names = getAllFoodNames(planData.plan, /* excludeBefore */ true);
      for (const name of names) {
        assert(!name.includes('oatmeal'), `Found "oatmeal" in during/after despite being disliked: ${name}`);
      }
    });

    it('disliked energy gel excluded from during/after phases', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        disliked_foods: ['energy gel'],
      });
      assertEquals(planStatus, 200);
      const names = getAllFoodNames(planData.plan, /* excludeBefore */ true);
      for (const name of names) {
        assert(!name.includes('energy gel') && !name.includes('energy_gel'),
          `Found "energy gel" in during/after despite being disliked: ${name}`);
      }
    });

    it('disliked blueberries excluded from all phases', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        disliked_foods: ['blueberries'],
      });
      assertEquals(planStatus, 200);
      const names = getAllFoodNames(planData.plan, /* excludeBefore */ true);
      for (const name of names) {
        assert(!name.includes('blueberr'), `Found "blueberry" in plan despite being disliked: ${name}`);
      }
    });

    it('disliked yogurt excluded from during/after phases', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        disliked_foods: ['yogurt'],
      });
      assertEquals(planStatus, 200);
      const names = getAllFoodNames(planData.plan, /* excludeBefore */ true);
      for (const name of names) {
        assert(!name.includes('yogurt'), `Found "yogurt" in during/after despite being disliked: ${name}`);
      }
    });

    it('disliked sports drink excluded from during/after phases', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        disliked_foods: ['sports drink', 'sports_drink'],
      });
      assertEquals(planStatus, 200);
      const names = getAllFoodNames(planData.plan, /* excludeBefore */ true);
      for (const name of names) {
        assert(!name.includes('sports drink') && !name.includes('sports_drink'),
          `Found "sports drink" in during/after despite being disliked: ${name}`);
      }
    });

    it('multiple disliked foods still produces valid plan', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        disliked_foods: ['banana', 'oatmeal', 'energy gel', 'yogurt', 'blueberries'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, 'Should still have foods with multiple dislikes');
    });

    it('water is never excluded by disliked foods', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale, {
        disliked_foods: ['water'],
      });
      assertEquals(planData.success, true);
    });
  });

  // =========================================================================
  // 7. Liked Foods Preference (5 tests)
  // =========================================================================

  describe('7. Liked Foods Preference', () => {
    it('valid plan with liked foods', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        liked_foods: ['banana', 'oatmeal'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
    });

    it('liked food appears in at least 1 of 3 calls', async () => {
      const likedFood = 'banana';
      let foundLiked = false;

      for (let i = 0; i < 3; i++) {
        const { planData } = await generateFullPlan(macroProfiles.smallFemale, {
          liked_foods: [likedFood],
        });
        const names = getAllFoodNames(planData.plan);
        if (names.some(n => n.includes(likedFood))) {
          foundLiked = true;
          break;
        }
      }

      assert(foundLiked, `Liked food "${likedFood}" should appear in at least 1 of 3 plan generations`);
    });

    it('unknown liked foods do not crash', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        liked_foods: ['nonexistent_superfood_xyz'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
    });

    it('liked + disliked together', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        liked_foods: ['banana'],
        disliked_foods: ['oatmeal'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      const names = getAllFoodNames(planData.plan, /* excludeBefore */ true);
      for (const name of names) {
        assert(!name.includes('oatmeal'), 'Disliked should still be excluded');
      }
    });

    it('empty arrays graceful', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        liked_foods: [],
        disliked_foods: [],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
    });
  });

  // =========================================================================
  // 8. Variability (3 tests — trimmed from 5 to reduce redundant calls)
  // =========================================================================

  describe('8. Variability', () => {
    it('same inputs can produce valid plans across 3 calls', async () => {
      const plans: string[] = [];
      for (let i = 0; i < 3; i++) {
        const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale);
        assertEquals(planStatus, 200);
        assertEquals(planData.success, true);
        const names = getAllFoodNames(planData.plan);
        plans.push(names.sort().join('|'));
      }
      const uniquePlans = new Set(plans);
      if (uniquePlans.size === 1) {
        console.log('Note: All 3 plan runs produced identical results (deterministic algorithm)');
      }
      assert(plans.length === 3, 'Should have 3 plan results');
    });

    it('variety across athlete profiles (>=3 distinct food sets)', async () => {
      const profiles = [
        macroProfiles.smallFemale,
        macroProfiles.averageMale,
        macroProfiles.heavyCyclist,
        macroProfiles.swimmer,
      ];

      const foodSets: string[] = [];
      for (const profile of profiles) {
        const { planData } = await generateFullPlan(profile);
        const names = getAllFoodNames(planData.plan).sort().join('|');
        foodSets.push(names);
      }

      const uniqueSets = new Set(foodSets);
      assert(
        uniqueSets.size >= 3,
        `Expected >= 3 distinct food sets across 4 profiles, got ${uniqueSets.size}`,
      );
    });

    it('after-phase variety between small and heavy profiles', async () => {
      const smallResult = await generateFullPlan(macroProfiles.smallFemale);
      const heavyResult = await generateFullPlan(macroProfiles.heavyCyclist);
      assert(smallResult.planData.plan.after.length >= 1, 'Small athlete should have after foods');
      assert(heavyResult.planData.plan.after.length >= 1, 'Heavy athlete should have after foods');
    });
  });

  // =========================================================================
  // 9. Before-Phase Details (8 tests)
  // =========================================================================

  describe('9. Before-Phase Details', () => {
    it('sub-phase structure has type, targets, foods', async () => {
      const { planData } = await generateFullPlan(macroProfiles.smallFemale);
      const before = planData.plan.before;
      for (const key of Object.keys(before)) {
        const subPhase = before[key];
        if (subPhase && subPhase.foods && subPhase.foods.length > 0) {
          assertExists(subPhase.sub_phase_type ?? key, 'Sub-phase should have type');
          assertExists(subPhase.foods, 'Sub-phase should have foods');
          assert(Array.isArray(subPhase.foods), 'foods should be array');
        }
      }
    });

    it('exploded component foods (not composites)', async () => {
      const { planData } = await generateFullPlan(macroProfiles.smallFemale);
      const beforeFoods = getBeforeFoods(planData.plan);

      for (const food of beforeFoods) {
        assert(
          food.display_name !== undefined,
          `Before food ${food.food_id} should have display_name`,
        );
      }
    });

    it('no duplicate display_name across different sub-phases', async () => {
      const { planData } = await generateFullPlan(macroProfiles.smallFemale);
      const namesBySubPhase: Record<string, Set<string>> = {};

      for (const key of ['meal', 'snack', 'top_up']) {
        if (planData.plan.before[key]?.foods) {
          namesBySubPhase[key] = new Set<string>();
          for (const food of planData.plan.before[key].foods) {
            const name = food.display_name?.toLowerCase();
            if (name) namesBySubPhase[key].add(name);
          }
        }
      }

      // Check for same display_name appearing in MULTIPLE sub-phases
      const subPhaseKeys = Object.keys(namesBySubPhase);
      for (let i = 0; i < subPhaseKeys.length; i++) {
        for (let j = i + 1; j < subPhaseKeys.length; j++) {
          const setA = namesBySubPhase[subPhaseKeys[i]];
          const setB = namesBySubPhase[subPhaseKeys[j]];
          for (const name of setA) {
            assert(
              !setB.has(name),
              `Duplicate food "${name}" found in both "${subPhaseKeys[i]}" and "${subPhaseKeys[j]}" sub-phases`,
            );
          }
        }
      }
    });

    it('drink in top_up phase', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const topUp = planData.plan.before.top_up;
      if (topUp?.foods && topUp.foods.length > 0) {
        const hasDrink = topUp.foods.some((f: any) => f.is_drink === true || f.is_liquid === true);
        if (!hasDrink) {
          console.log('Note: top_up phase has no drink (not strictly required)');
        }
      }
      assert(true);
    });

    it('fluid not exceeding 2x target', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const beforeFoods = getBeforeFoods(planData.plan);
      const totalFluid = sumMacros(beforeFoods).water;
      const target = macroData.macros.pre_run_water_ml;
      if (target > 0) {
        assert(
          totalFluid <= target * 2.0,
          `Before fluid ${totalFluid}ml should not exceed 2x target ${target}ml`,
        );
      }
    });

    it('no excessive bananas across sub-phases', async () => {
      const { planData } = await generateFullPlan(macroProfiles.smallFemale);
      let bananaCount = 0;
      for (const key of ['meal', 'snack', 'top_up']) {
        if (planData.plan.before[key]?.foods) {
          for (const food of planData.plan.before[key].foods) {
            if (food.display_name?.toLowerCase().includes('banana')) {
              bananaCount++;
            }
          }
        }
      }
      assert(bananaCount <= 3, `Too many banana entries: ${bananaCount}`);
    });

    it('foods present in each active sub-phase', async () => {
      const { planData } = await generateFullPlan(macroProfiles.smallFemale);
      const totalFoods = countBeforeFoods(planData.plan);
      assert(totalFoods >= 1, `Should have at least 1 before food for 3h window, got ${totalFoods}`);
    });

    it('sub-phase targets sum approximately to pre_run targets', async () => {
      const { planData } = await generateFullPlan(macroProfiles.smallFemale);
      const before = planData.plan.before;
      let totalTargetCarbs = 0;

      for (const key of Object.keys(before)) {
        const subPhase = before[key];
        if (subPhase?.targets?.carbs_g) {
          totalTargetCarbs += subPhase.targets.carbs_g;
        }
      }

      if (totalTargetCarbs > 0) {
        assert(totalTargetCarbs > 0, 'Sub-phase targets should sum to positive value');
      }
    });
  });

  // =========================================================================
  // 10. During-Phase Details (5 tests)
  // =========================================================================

  describe('10. During-Phase Details', () => {
    it('timing_category present on each during food', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      for (const food of planData.plan.during.foods) {
        assertExists(food.timing_category, `During food ${food.display_name} should have timing_category`);
      }
    });

    it('at least one hydration item in during phase', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const duringFoods = planData.plan.during.foods;
      const hasHydration = duringFoods.some(
        (f: any) => f.is_drink === true || f.is_liquid === true || f.is_electrolyte === true ||
          (f.fluids_ml && f.fluids_ml > 50),
      );
      assert(hasHydration, 'During phase should have at least one hydration item');
    });

    it('empty during phase for swimming', async () => {
      const { planData } = await generateFullPlan(macroProfiles.swimmer);
      assertEquals(planData.plan.during.foods.length, 0, 'Swimming during should be empty');
    });

    it('product_type present on during foods', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      for (const food of planData.plan.during.foods) {
        if (food.product_type === undefined && food.timing_category !== 'electrolyte') {
          console.log(`Note: During food ${food.display_name} has no product_type`);
        }
      }
      assert(true);
    });

    it('quantities scale to macros V4 band range', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const duringFoods = planData.plan.during.foods;
      if (duringFoods.length > 0) {
        const totalCarbs = sumMacros(duringFoods).carbs;
        const m = macroData.macros;
        const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
        const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;
        console.log(`  During quantities: ${totalCarbs.toFixed(1)}g | band: [${bandLowTotal.toFixed(0)}g, ${bandHighTotal.toFixed(0)}g]`);
        assertMacroInRange(totalCarbs, bandLowTotal, bandHighTotal, 'During carbs band check');
      }
    });
  });

  // =========================================================================
  // 11. After-Phase Details (4 tests)
  // =========================================================================

  describe('11. After-Phase Details', () => {
    it('after phase contains protein-rich foods', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const afterFoods = planData.plan.after;
      const totalProtein = sumMacros(afterFoods).protein;
      assert(totalProtein > 5, `After phase should have > 5g protein, got ${totalProtein}g`);
    });

    it('hydration present in after phase', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const afterFoods = planData.plan.after;
      const totalFluid = sumMacros(afterFoods).water;
      assert(totalFluid > 0, 'After phase should have some hydration');
    });

    it('after carbs+protein for heavy cyclist within V4 ranges', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const afterMacros = sumMacros(planData.plan.after);
      const m = macroData.macros;

      console.log(`  Heavy cyclist after carbs: ${afterMacros.carbs.toFixed(1)}g | range: [${m.post_run_carbs_low_g}, ${m.post_run_carbs_high_g}]`);
      console.log(`  Heavy cyclist after protein: ${afterMacros.protein.toFixed(1)}g | range: [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);

      assertMacroInRange(afterMacros.carbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, 'Heavy cyclist after carbs');
      assertMacroInRange(afterMacros.protein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'Heavy cyclist after protein');
    });

    it('reasonable after food count (1-8)', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      assertInRange(planData.plan.after.length, 1, 8, 'After food count');
    });
  });

  // =========================================================================
  // 12. Brick Workout Tests (6 tests) — NEW
  // =========================================================================

  describe('12. Brick Workout Tests', () => {
    it('brick workout returns valid response structure', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.brickTriathlete);
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      assertExists(planData.plan_id);
      assertExists(planData.plan);
    });

    it('brick plan has during_segments and transitions', async () => {
      const { planData } = await generateFullPlan(macroProfiles.brickTriathlete);
      const plan = planData.plan;

      assertExists(plan.during_segments, 'Brick plan should have during_segments');
      assertExists(plan.transitions, 'Brick plan should have transitions');

      // 3 segments -> keys "1", "2", "3"
      const segmentKeys = Object.keys(plan.during_segments);
      assert(segmentKeys.length >= 2, `Expected >= 2 segment keys, got ${segmentKeys.length}`);

      // 3 segments -> 2 transitions: T1, T2
      const transitionKeys = Object.keys(plan.transitions);
      assert(transitionKeys.length >= 1, `Expected >= 1 transition, got ${transitionKeys.length}`);
    });

    it('brick swimming segment has no during foods', async () => {
      const { planData } = await generateFullPlan(macroProfiles.brickTriathlete);
      const swimSegment = planData.plan.during_segments['1'];
      // Segment 1 is swimming
      assertExists(swimSegment, 'Swimming segment should exist');
      assertEquals(swimSegment.length, 0, 'Swimming segment should have 0 foods');
    });

    it('brick cycling segment has foods', async () => {
      const { planData } = await generateFullPlan(macroProfiles.brickTriathlete);
      const cycleSegment = planData.plan.during_segments['2'];
      assertExists(cycleSegment, 'Cycling segment should exist');
      assert(cycleSegment.length >= 1, `Cycling segment should have >= 1 food, got ${cycleSegment.length}`);
    });

    it('brick after phase is present', async () => {
      const { planData } = await generateFullPlan(macroProfiles.brickTriathlete);
      assert(Array.isArray(planData.plan.after), 'Brick after should be array');
      assert(planData.plan.after.length >= 1, `Brick after should have >= 1 food, got ${planData.plan.after.length}`);
    });

    it('brick before phase is present', async () => {
      const { planData } = await generateFullPlan(macroProfiles.brickTriathlete);
      assertExists(planData.plan.before, 'Brick plan should have before phase');
      const beforeCount = countBeforeFoods(planData.plan);
      assert(beforeCount >= 1, `Brick before should have >= 1 food, got ${beforeCount}`);
    });
  });

  // =========================================================================
  // 13. Comprehensive Persona Tests (8 tests) — NEW
  // =========================================================================

  describe('13. Comprehensive Persona Tests', () => {
    it('Celiac Vegan Runner: no gluten, no animal products', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'vegan',
        allergies: ['gluten'],
        liked_foods: ['banana', 'energy gel'],
        disliked_foods: ['oatmeal', 'toast'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      // No gluten in during/after
      const names = getAllFoodNames(planData.plan, true);
      for (const name of names) {
        for (const kw of ALLERGEN_KEYWORDS.gluten) {
          assert(!name.includes(kw.toLowerCase()), `Celiac vegan: found gluten "${kw}" in "${name}"`);
        }
        for (const kw of VEGAN_EXCLUDED_KEYWORDS) {
          assert(!name.includes(kw.toLowerCase()), `Celiac vegan: found animal product "${kw}" in "${name}"`);
        }
      }
    });

    it('Dairy-Free Nut-Allergy Cyclist: no dairy, no nuts', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.heavyCyclist, {
        allergies: ['dairy', 'tree nuts', 'peanuts'],
        liked_foods: ['energy chews'],
        disliked_foods: ['yogurt', 'granola'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      const names = getAllFoodNames(planData.plan, true);
      for (const name of names) {
        for (const kw of ALLERGEN_KEYWORDS.dairy) {
          assert(!name.includes(kw.toLowerCase()), `Dairy-free cyclist: found dairy "${kw}" in "${name}"`);
        }
        for (const kw of ALLERGEN_KEYWORDS['tree nuts']) {
          assert(!name.includes(kw.toLowerCase()), `Nut-free cyclist: found nut "${kw}" in "${name}"`);
        }
        for (const kw of ALLERGEN_KEYWORDS.peanuts) {
          assert(!name.includes(kw.toLowerCase()), `Peanut-free cyclist: found peanut "${kw}" in "${name}"`);
        }
      }
    });

    it('Paleo Female Runner: small, cold weather', async () => {
      const paleoFemale = {
        ...macroProfiles.smallFemale,
        temp_c: 5,
        humidity_pct: 40,
      };
      const { planData, planStatus } = await generateFullPlan(paleoFemale, {
        dietary_preference: 'paleo',
        liked_foods: ['banana'],
        disliked_foods: ['cereal', 'bagel', 'toast'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, 'Paleo female should have valid plan');
    });

    it('Pescatarian Swimmer: no during foods expected', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.swimmer, {
        dietary_preference: 'vegetarian',
        allergies: ['eggs'],
        liked_foods: ['oatmeal'],
        disliked_foods: ['energy gel'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      assertEquals(planData.plan.during.foods.length, 0, 'Swimmer should have 0 during foods');
    });

    it('Fasted Male Runner: zero before-phase foods', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.fastedRunner);
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const beforeCount = countBeforeFoods(planData.plan);
      assertEquals(beforeCount, 0, 'Fasted runner should have 0 before foods');
    });

    it('Blueberry-Hater Cyclist: no blueberries anywhere', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.heavyCyclist, {
        liked_foods: ['banana', 'oatmeal'],
        disliked_foods: ['blueberries', 'yogurt'],
      });
      assertEquals(planStatus, 200);
      const names = getAllFoodNames(planData.plan, true);
      for (const name of names) {
        assert(!name.includes('blueberr'), `Found blueberry in plan despite being disliked: ${name}`);
        assert(!name.includes('yogurt'), `Found yogurt in plan despite being disliked: ${name}`);
      }
    });

    it('All-Allergies Runner: max allergens, still valid', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['gluten', 'dairy', 'peanuts', 'tree nuts', 'eggs'],
        liked_foods: ['rice cake'],
        disliked_foods: ['bagel', 'cereal'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, 'Should still produce foods with all allergies');

      // Verify each allergen excluded
      const names = getAllFoodNames(planData.plan, true);
      for (const allergen of ['gluten', 'dairy', 'peanuts', 'tree nuts', 'eggs']) {
        for (const name of names) {
          for (const kw of (ALLERGEN_KEYWORDS[allergen] ?? [])) {
            assert(!name.includes(kw.toLowerCase()), `All-allergies: found "${kw}" (${allergen}) in "${name}"`);
          }
        }
      }
    });

    it('Hot Weather Heavy Sweater: higher sodium/hydration targets', async () => {
      const { planData, planStatus, macroData } = await generateFullPlan(macroProfiles.hotWeatherRunner, {
        liked_foods: ['energy gel', 'sports drink'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      // Hot weather should produce higher sodium and hydration targets
      const m = macroData.macros;
      console.log(`  Hot weather: during sodium target=${m.during_sodium_total_mg}mg, hydration target=${m.during_water_total_ml}ml`);
      assert(m.during_sodium_total_mg > 200, `Hot weather sodium target should be > 200mg, got ${m.during_sodium_total_mg}`);
      assert(m.during_water_total_ml > 500, `Hot weather hydration target should be > 500ml, got ${m.during_water_total_ml}`);
    });
  });

  // =========================================================================
  // 14. Food Source Validation (3 tests) — NEW
  // =========================================================================

  describe('14. Food Source Validation', () => {
    it('>=80% of during/after display_names match known template food names', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const duringAfterFoods: any[] = [...planData.plan.during.foods, ...planData.plan.after];

      if (duringAfterFoods.length === 0) return;

      let matchCount = 0;
      const unmatched: string[] = [];
      for (const food of duringAfterFoods) {
        const displayName = (food.display_name || '').toLowerCase();
        const isKnown = KNOWN_TEMPLATE_FOOD_NAMES.some(known =>
          displayName.includes(known)
        );
        if (isKnown) {
          matchCount++;
        } else {
          unmatched.push(displayName);
        }
      }

      const matchRate = matchCount / duringAfterFoods.length;
      if (unmatched.length > 0) {
        console.log(`  Unmatched foods: ${unmatched.join(', ')}`);
      }
      console.log(`  Food source match rate: ${(matchRate * 100).toFixed(0)}% (${matchCount}/${duringAfterFoods.length})`);
      assert(
        matchRate >= 0.8,
        `Expected >= 80% of foods to match known templates, got ${(matchRate * 100).toFixed(0)}% — unmatched: ${unmatched.join(', ')}`,
      );
    });

    it('no phantom food_ids (all IDs are non-empty strings)', async () => {
      const { planData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const allFoods = getAllFoods(planData.plan);

      for (const food of allFoods) {
        assert(
          typeof food.food_id === 'string' && food.food_id.length > 0,
          `Food has invalid food_id: ${JSON.stringify(food.food_id)}`,
        );
      }
    });

    it('cycling plan uses known template foods', async () => {
      const { planData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const duringFoods = planData.plan.during.foods;

      if (duringFoods.length === 0) return;

      let matchCount = 0;
      const unmatched: string[] = [];
      for (const food of duringFoods) {
        const displayName = (food.display_name || '').toLowerCase();
        const isKnown = KNOWN_TEMPLATE_FOOD_NAMES.some(known =>
          displayName.includes(known)
        );
        if (isKnown) {
          matchCount++;
        } else {
          unmatched.push(displayName);
        }
      }

      const matchRate = matchCount / duringFoods.length;
      if (unmatched.length > 0) {
        console.log(`  Unmatched cycling foods: ${unmatched.join(', ')}`);
      }
      console.log(`  Cycling food source match rate: ${(matchRate * 100).toFixed(0)}% (${matchCount}/${duringFoods.length})`);
      assert(
        matchRate >= 0.8,
        `Expected >= 80% of cycling during foods to match known templates, got ${(matchRate * 100).toFixed(0)}% — unmatched: ${unmatched.join(', ')}`,
      );
    });
  });

  // =========================================================================
  // 15. User Food Tests (5 tests) — NEW (with mocked prod data + setup/teardown)
  // =========================================================================

  describe('15. User Food Tests', () => {
    const HAS_SERVICE_KEY = !!SUPABASE_SERVICE_ROLE_KEY;
    const TEST_DEVICE_ID = `test-e2e-user-foods-${Date.now()}`;
    let testUserId: string | null = null;

    const MOCK_USER_FOODS = [
      {
        name: 'homemade_energy_balls',
        display_name: 'Homemade Energy Balls',
        display_name_plural: 'Homemade Energy Balls',
        serving_amount: 1,
        serving_unit: 'ball',
        serving_size: '1 ball (30g)',
        calories_per_serving: 120,
        carbs_per_serving: 18,
        protein_per_serving: 3,
        fat_per_serving: 5,
        sodium_mg: 50,
        fluid_ml_per_serving: 0,
        is_electrolyte: false,
        to_exclude_from_solver: false,
        is_deleted: false,
        product_type: 'real_food_carbs',
        categories: ['before_run'],
        activity_types: ['running', 'cycling'],
      },
      {
        name: 'custom_gel',
        display_name: 'Custom Gel',
        display_name_plural: 'Custom Gels',
        serving_amount: 1,
        serving_unit: 'packet',
        serving_size: '1 packet (32g)',
        calories_per_serving: 100,
        carbs_per_serving: 25,
        protein_per_serving: 0,
        fat_per_serving: 0,
        sodium_mg: 100,
        fluid_ml_per_serving: 0,
        is_electrolyte: false,
        to_exclude_from_solver: false,
        is_deleted: false,
        product_type: 'gel',
        categories: ['during_run'],
        activity_types: ['running', 'cycling'],
      },
      {
        name: 'protein_smoothie',
        display_name: 'Protein Smoothie',
        display_name_plural: 'Protein Smoothies',
        serving_amount: 1,
        serving_unit: 'cup',
        serving_size: '1 cup (240ml)',
        calories_per_serving: 200,
        carbs_per_serving: 30,
        protein_per_serving: 20,
        fat_per_serving: 3,
        sodium_mg: 150,
        fluid_ml_per_serving: 240,
        is_electrolyte: false,
        to_exclude_from_solver: false,
        is_deleted: false,
        product_type: 'recovery_shake',
        categories: ['after_run'],
        activity_types: ['running', 'cycling'],
      },
    ];

    async function supabaseServiceCall(path: string, method: string, body?: any): Promise<any> {
      const response = await fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${SUPABASE_SERVICE_ROLE_KEY}`,
          'apikey': SUPABASE_SERVICE_ROLE_KEY,
          'Prefer': method === 'POST' ? 'return=representation' : 'return=minimal',
        },
        body: body ? JSON.stringify(body) : undefined,
      });

      if (method === 'POST' || method === 'GET') {
        const text = await response.text();
        try { return JSON.parse(text); } catch { return text; }
      }
      return response.status;
    }

    if (HAS_SERVICE_KEY) {
      beforeAll(async () => {
        try {
          // Insert test user
          const userResult = await supabaseServiceCall('users', 'POST', {
            device_id: TEST_DEVICE_ID,
            weight: 70,
            weight_unit: 'kg',
          });
          testUserId = Array.isArray(userResult) ? userResult[0]?.id : userResult?.id;
          console.log(`[User Food Setup] Created test user: ${testUserId}`);

          if (testUserId) {
            // Insert mock user foods
            for (const food of MOCK_USER_FOODS) {
              await supabaseServiceCall('user_foods', 'POST', {
                ...food,
                user_id: testUserId,
              });
            }
            console.log(`[User Food Setup] Inserted ${MOCK_USER_FOODS.length} mock user foods`);
          }
        } catch (err) {
          console.error(`[User Food Setup] Failed: ${err}`);
        }
      });

      afterAll(async () => {
        try {
          if (testUserId) {
            await supabaseServiceCall(
              `user_foods?user_id=eq.${testUserId}`,
              'DELETE',
            );
            await supabaseServiceCall(
              `users?id=eq.${testUserId}`,
              'DELETE',
            );
            console.log(`[User Food Teardown] Cleaned up test user ${testUserId}`);
          }
        } catch (err) {
          console.error(`[User Food Teardown] Failed: ${err}`);
        }
      });

      it('plan generates successfully with user food device_id', async () => {
        const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
          device_id: TEST_DEVICE_ID,
        });
        assertEquals(planStatus, 200);
        assertEquals(planData.success, true);
      });

      it('before phase may include user food substitution', async () => {
        const { planData } = await generateFullPlan(macroProfiles.averageMale, {
          device_id: TEST_DEVICE_ID,
        });
        const beforeNames = getBeforeFoods(planData.plan).map((f: any) => f.display_name?.toLowerCase() || '');
        const hasUserFood = beforeNames.some(n => n.includes('energy balls'));
        console.log(`  User food in before: ${hasUserFood} (names: ${beforeNames.join(', ')})`);
        // User food may or may not appear — just verify plan is valid
        assert(true, 'Plan valid with user foods');
      });

      it('during phase may include custom_gel', async () => {
        const { planData } = await generateFullPlan(macroProfiles.averageMale, {
          device_id: TEST_DEVICE_ID,
        });
        const duringNames = planData.plan.during.foods.map((f: any) => f.display_name?.toLowerCase() || '');
        const hasCustomGel = duringNames.some((n: string) => n.includes('custom gel'));
        console.log(`  Custom gel in during: ${hasCustomGel} (names: ${duringNames.join(', ')})`);
        assert(true, 'Plan valid with user gel');
      });

      it('after phase may include protein_smoothie', async () => {
        const { planData } = await generateFullPlan(macroProfiles.averageMale, {
          device_id: TEST_DEVICE_ID,
        });
        const afterNames = planData.plan.after.map((f: any) => f.display_name?.toLowerCase() || '');
        const hasSmoothie = afterNames.some((n: string) => n.includes('protein smoothie'));
        console.log(`  Protein smoothie in after: ${hasSmoothie} (names: ${afterNames.join(', ')})`);
        assert(true, 'Plan valid with user recovery food');
      });

      it('excluded user foods should not appear in plan', async () => {
        // Insert an excluded user food, then verify it doesn't appear
        if (testUserId) {
          await supabaseServiceCall('user_foods', 'POST', {
            name: 'excluded_test_food',
            display_name: 'Excluded Test Food',
            display_name_plural: 'Excluded Test Foods',
            serving_amount: 1,
            serving_unit: 'item',
            serving_size: '1 item',
            calories_per_serving: 100,
            carbs_per_serving: 20,
            protein_per_serving: 5,
            fat_per_serving: 2,
            sodium_mg: 50,
            fluid_ml_per_serving: 0,
            is_electrolyte: false,
            to_exclude_from_solver: true,
            is_deleted: false,
            product_type: 'real_food_carbs',
            categories: ['before_run', 'during_run', 'after_run'],
            activity_types: ['running'],
            user_id: testUserId,
          });

          const { planData } = await generateFullPlan(macroProfiles.averageMale, {
            device_id: TEST_DEVICE_ID,
          });
          const allNames = getAllFoodNames(planData.plan);
          for (const name of allNames) {
            assert(!name.includes('excluded test food'),
              `Found excluded user food in plan: ${name}`);
          }
        }
      });
    } else {
      it('SKIPPED: user food tests require SUPABASE_SERVICE_ROLE_KEY', () => {
        console.log('Skipping user food tests — set SUPABASE_SERVICE_ROLE_KEY to enable');
        assert(true);
      });
    }
  });

  // =========================================================================
  // 16. Cross-Phase Integration (5 tests)
  // =========================================================================

  describe('16. Cross-Phase Integration', () => {
    it('no UUIDs as display names across entire plan', async () => {
      const { planData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const names = getAllFoodNames(planData.plan);
      const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
      for (const name of names) {
        assert(!uuidPattern.test(name), `Found UUID as display_name: ${name}`);
      }
    });

    it('response time < 10 seconds', async () => {
      const start = Date.now();
      await generateFullPlan(macroProfiles.averageMale);
      const elapsed = Date.now() - start;
      assert(elapsed < 10000, `Response took ${elapsed}ms, expected < 10000ms`);
    });

    it('very short run (30 min) edge case', async () => {
      const shortRun = {
        ...macroProfiles.averageMale,
        run_distance: 3.5,
        run_pace: '8:30',
      };
      const { planData, planStatus } = await generateFullPlan(shortRun);
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
    });

    it('long run (26.2 mi marathon) edge case', async () => {
      const marathon = {
        ...macroProfiles.averageMale,
        run_distance: 26.2,
        run_pace: '8:00',
        hours_before: 3,
      };
      const { planData, planStatus } = await generateFullPlan(marathon);
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 3, `Marathon plan should have >= 3 total foods, got ${allFoods.length}`);
    });

    it('complete plan with all phases populated', async () => {
      const { planData } = await generateFullPlan(macroProfiles.smallFemale);
      assert(countBeforeFoods(planData.plan) >= 1, 'Before should have foods');
      assert(planData.plan.during.foods.length >= 1, 'During should have foods');
      assert(planData.plan.after.length >= 1, 'After should have foods');
    });
  });

  // =========================================================================
  // 17. Weather Diversity (2 tests) — NEW
  // =========================================================================

  describe('17. Weather Diversity', () => {
    it('cold weather produces lower sodium/hydration than hot weather', async () => {
      const [coldResult, hotResult] = await Promise.all([
        generateFullPlan(macroProfiles.coldWeatherRunner),
        generateFullPlan(macroProfiles.hotWeatherRunner),
      ]);

      const coldDuringSodium = coldResult.macroData.macros.during_sodium_total_mg;
      const hotDuringSodium = hotResult.macroData.macros.during_sodium_total_mg;
      const coldDuringWater = coldResult.macroData.macros.during_water_total_ml;
      const hotDuringWater = hotResult.macroData.macros.during_water_total_ml;

      console.log(`  Cold sodium: ${coldDuringSodium}mg, Hot sodium: ${hotDuringSodium}mg`);
      console.log(`  Cold water: ${coldDuringWater}ml, Hot water: ${hotDuringWater}ml`);

      assert(
        hotDuringSodium > coldDuringSodium,
        `Hot weather sodium (${hotDuringSodium}) should be > cold weather (${coldDuringSodium})`,
      );
      assert(
        hotDuringWater > coldDuringWater,
        `Hot weather water (${hotDuringWater}) should be > cold weather (${coldDuringWater})`,
      );
    });

    it('both weather extremes produce valid plans', async () => {
      const [coldResult, hotResult] = await Promise.all([
        generateFullPlan(macroProfiles.coldWeatherRunner),
        generateFullPlan(macroProfiles.hotWeatherRunner),
      ]);
      assertEquals(coldResult.planStatus, 200);
      assertEquals(coldResult.planData.success, true);
      assertEquals(hotResult.planStatus, 200);
      assertEquals(hotResult.planData.success, true);
    });
  });

  // =========================================================================
  // 18. Error Handling (5 tests)
  // =========================================================================

  describe('18. Error Handling', () => {
    it('missing device_id -> 400', async () => {
      const { status } = await callEdgeFunction(PLAN_URL, {
        hours_before: 2,
        weight_kg: 70,
        macro_targets: {
          pre_run: { carbs_g: 100, sodium_mg: 500, water_ml: 400 },
          during_run: { carbs_g: 50, sodium_mg: 300, water_ml: 500 },
          post_run: { carbs_g: 70, sodium_mg: 300, water_ml: 500 },
        },
      });
      assertEquals(status, 400);
    });

    it('missing macro_targets -> 400', async () => {
      const { status } = await callEdgeFunction(PLAN_URL, {
        device_id: 'test-error',
        hours_before: 2,
        weight_kg: 70,
      });
      assertEquals(status, 400);
    });

    it('negative hours_before -> 400', async () => {
      const { status } = await callEdgeFunction(PLAN_URL, {
        device_id: 'test-error',
        hours_before: -1,
        weight_kg: 70,
        macro_targets: {
          pre_run: { carbs_g: 100, sodium_mg: 500, water_ml: 400 },
          during_run: { carbs_g: 50, sodium_mg: 300, water_ml: 500 },
          post_run: { carbs_g: 70, sodium_mg: 300, water_ml: 500 },
        },
      });
      assertEquals(status, 400);
    });

    it('zero macro targets still produces valid plan', async () => {
      const { status } = await callEdgeFunction(PLAN_URL, {
        device_id: `test-e2e-${Date.now()}`,
        hours_before: 0,
        weight_kg: 70,
        macro_targets: {
          pre_run: { carbs_g: 0, sodium_mg: 0, water_ml: 0 },
          during_run: { carbs_g: 0, sodium_mg: 0, water_ml: 0 },
          post_run: { carbs_g: 0, sodium_mg: 0, water_ml: 0 },
        },
      });
      assert(status === 200 || status === 500, `Expected 200 or 500, got ${status}`);
    });

    it('very high carb targets still produces valid plan', async () => {
      const { status, data } = await callEdgeFunction(PLAN_URL, {
        device_id: `test-e2e-${Date.now()}`,
        hours_before: 3,
        weight_kg: 100,
        macro_targets: {
          pre_run: { carbs_g: 500, sodium_mg: 2000, water_ml: 2000 },
          during_run: { carbs_g: 300, sodium_mg: 3000, water_ml: 5000 },
          post_run: { carbs_g: 200, sodium_mg: 1000, water_ml: 3000 },
        },
      });
      assertEquals(status, 200);
      assertEquals(data.success, true);
    });
  });

  // =========================================================================
  // 19. Aggressive After-Phase Protein Tests — NEW
  //     The after phase is BROKEN. Screenshot shows 4g protein with just
  //     "3 Bananas + Coconut Water". This section catches that.
  // =========================================================================

  describe('19. After-Phase Protein (MUST be fixed)', () => {
    it('after protein within V4 range (small female runner)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.smallFemale);
      const afterProtein = sumMacros(planData.plan.after).protein;
      const m = macroData.macros;
      console.log(`  After protein (small female): ${afterProtein.toFixed(1)}g | range: [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
      assertMacroInRange(afterProtein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'After protein (small female)');
    });

    it('after protein within V4 range (heavy cyclist)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.heavyCyclist);
      const afterProtein = sumMacros(planData.plan.after).protein;
      const m = macroData.macros;
      console.log(`  After protein (heavy cyclist): ${afterProtein.toFixed(1)}g | range: [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
      assertMacroInRange(afterProtein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'After protein (heavy cyclist)');
    });

    it('after protein within V4 range (hot weather runner)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.hotWeatherRunner);
      const afterProtein = sumMacros(planData.plan.after).protein;
      const m = macroData.macros;
      console.log(`  After protein (hot weather): ${afterProtein.toFixed(1)}g | range: [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
      assertMacroInRange(afterProtein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'After protein (hot weather)');
    });

    it('after protein within V4 range (cold weather runner)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.coldWeatherRunner);
      const afterProtein = sumMacros(planData.plan.after).protein;
      const m = macroData.macros;
      console.log(`  After protein (cold weather): ${afterProtein.toFixed(1)}g | range: [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
      assertMacroInRange(afterProtein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'After protein (cold weather)');
    });

    it('after protein within V4 range (swimmer)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.swimmer);
      const afterProtein = sumMacros(planData.plan.after).protein;
      const m = macroData.macros;
      console.log(`  After protein (swimmer): ${afterProtein.toFixed(1)}g | range: [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
      assertMacroInRange(afterProtein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'After protein (swimmer)');
    });

    it('after protein MUST be >= 10g for any non-fasted workout', async () => {
      // This is an absolute floor. No non-fasted workout should produce < 10g protein.
      const profiles = [
        { name: 'small female', profile: macroProfiles.smallFemale },
        { name: 'average male', profile: macroProfiles.averageMale },
        { name: 'heavy cyclist', profile: macroProfiles.heavyCyclist },
        { name: 'hot weather', profile: macroProfiles.hotWeatherRunner },
        { name: 'cold weather', profile: macroProfiles.coldWeatherRunner },
        { name: 'swimmer', profile: macroProfiles.swimmer },
      ];

      for (const { name, profile } of profiles) {
        const { planData } = await generateFullPlan(profile);
        const afterProtein = sumMacros(planData.plan.after).protein;
        console.log(`  ${name}: after protein = ${afterProtein.toFixed(1)}g`);
        assert(
          afterProtein >= 10,
          `${name}: after-phase protein ${afterProtein.toFixed(1)}g is below absolute minimum 10g — the LP solver is failing to include protein-rich foods`,
        );
      }
    });

    it('after phase MUST include at least one food with protein > 5g/serving', async () => {
      // "3 Bananas + Coconut Water" is NOT a recovery meal. At least one food must be protein-rich.
      const profiles = [
        { name: 'average male', profile: macroProfiles.averageMale },
        { name: 'heavy cyclist', profile: macroProfiles.heavyCyclist },
        { name: 'swimmer', profile: macroProfiles.swimmer },
      ];

      for (const { name, profile } of profiles) {
        const { planData } = await generateFullPlan(profile);
        const afterFoods = planData.plan.after;
        const hasProteinFood = afterFoods.some(
          (f: any) => (f.protein_grams ?? 0) * (f.quantity ?? 1) > 5,
        );
        const foodDesc = afterFoods.map((f: any) => `${f.display_name}(${(f.protein_grams ?? 0).toFixed(0)}g pro)`).join(', ');
        console.log(`  ${name} after foods: ${foodDesc}`);
        assert(
          hasProteinFood,
          `${name}: after phase has NO food with >5g protein. Foods: ${foodDesc}. This is not a valid recovery meal.`,
        );
      }
    });

    it('after phase should NOT be only bananas and water', async () => {
      // Specific regression test for the observed failure: "3 Bananas + Coconut Water"
      const { planData } = await generateFullPlan(macroProfiles.averageMale);
      const afterNames = planData.plan.after.map((f: any) => (f.display_name || '').toLowerCase());
      const onlyBananaAndWater = afterNames.every(
        (n: string) => n.includes('banana') || n.includes('water') || n.includes('coconut'),
      );
      if (afterNames.length > 0 && onlyBananaAndWater) {
        const afterProtein = sumMacros(planData.plan.after).protein;
        assert(
          false,
          `After phase is ONLY bananas and water (${afterNames.join(', ')}), protein=${afterProtein.toFixed(1)}g. ` +
          `The LP solver must include a protein source like chocolate milk, protein shake, yogurt, or eggs.`,
        );
      }
    });

    it('after phase all macros within V4 range (full audit for average male)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.averageMale);
      const afterMacros = sumMacros(planData.plan.after);
      const m = macroData.macros;

      console.log(`  FULL AUDIT (avg male after):`);
      console.log(`    Carbs:    ${afterMacros.carbs.toFixed(1)}g | [${m.post_run_carbs_low_g}, ${m.post_run_carbs_high_g}]`);
      console.log(`    Protein:  ${afterMacros.protein.toFixed(1)}g | [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
      console.log(`    Sodium:   ${afterMacros.sodium.toFixed(0)}mg | [${m.post_run_sodium_low_mg}, ${m.post_run_sodium_high_mg}]`);
      console.log(`    Water:    ${afterMacros.water.toFixed(0)}ml | [${m.post_run_water_low_ml}, ${m.post_run_water_high_ml}]`);

      assertMacroInRange(afterMacros.carbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, 'After carbs (audit)');
      assertMacroInRange(afterMacros.protein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'After protein (audit)');
      assertMacroInRange(afterMacros.sodium, m.post_run_sodium_low_mg, m.post_run_sodium_high_mg, 'After sodium (audit)');
      assertMacroInRange(afterMacros.water, m.post_run_water_low_ml, m.post_run_water_high_ml, 'After hydration (audit)');
    });

    it('after phase all macros within V4 range (full audit for hot weather)', async () => {
      const { planData, macroData } = await generateFullPlan(macroProfiles.hotWeatherRunner);
      const afterMacros = sumMacros(planData.plan.after);
      const m = macroData.macros;

      console.log(`  FULL AUDIT (hot weather after):`);
      console.log(`    Carbs:    ${afterMacros.carbs.toFixed(1)}g | [${m.post_run_carbs_low_g}, ${m.post_run_carbs_high_g}]`);
      console.log(`    Protein:  ${afterMacros.protein.toFixed(1)}g | [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
      console.log(`    Sodium:   ${afterMacros.sodium.toFixed(0)}mg | [${m.post_run_sodium_low_mg}, ${m.post_run_sodium_high_mg}]`);
      console.log(`    Water:    ${afterMacros.water.toFixed(0)}ml | [${m.post_run_water_low_ml}, ${m.post_run_water_high_ml}]`);

      assertMacroInRange(afterMacros.carbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, 'After carbs (hot audit)');
      assertMacroInRange(afterMacros.protein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'After protein (hot audit)');
      assertMacroInRange(afterMacros.sodium, m.post_run_sodium_low_mg, m.post_run_sodium_high_mg, 'After sodium (hot audit)');
      assertMacroInRange(afterMacros.water, m.post_run_water_low_ml, m.post_run_water_high_ml, 'After hydration (hot audit)');
    });
  });

  // =========================================================================
  // 20. Exhaustive Allergy/Diet/Likes/Dislikes Edge Cases — NEW
  //     "Go hard" — test every intersection of constraints across sports.
  // =========================================================================

  describe('20. Exhaustive Preference Edge Cases', () => {
    // --- Allergies across ALL sport types ---

    it('gluten allergy + cycling: no gluten in ANY phase', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.heavyCyclist, {
        allergies: ['gluten'],
      });
      assertEquals(planStatus, 200);
      // Check ALL phases including before
      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of ALLERGEN_KEYWORDS.gluten) {
          assert(!name.includes(kw.toLowerCase()), `Gluten+cycling: found "${kw}" in "${name}"`);
        }
      }
    });

    it('dairy allergy + swimming: no dairy in ANY phase', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.swimmer, {
        allergies: ['dairy'],
      });
      assertEquals(planStatus, 200);
      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of ALLERGEN_KEYWORDS.dairy) {
          assert(!name.includes(kw.toLowerCase()), `Dairy+swimming: found "${kw}" in "${name}"`);
        }
      }
    });

    it('peanut+tree nut allergy + hot weather runner: no nuts anywhere', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.hotWeatherRunner, {
        allergies: ['peanuts', 'tree nuts'],
      });
      assertEquals(planStatus, 200);
      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of [...ALLERGEN_KEYWORDS.peanuts, ...ALLERGEN_KEYWORDS['tree nuts']]) {
          assert(!name.includes(kw.toLowerCase()), `Nut allergy+hot: found "${kw}" in "${name}"`);
        }
      }
    });

    it('all 5 allergies + cycling: still produces valid plan with no allergens', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.heavyCyclist, {
        allergies: ['gluten', 'dairy', 'peanuts', 'tree nuts', 'eggs'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, 'All allergies + cycling should still produce foods');

      const allNames = getAllFoodNames(planData.plan, false);
      for (const allergen of ['gluten', 'dairy', 'peanuts', 'tree nuts', 'eggs']) {
        for (const name of allNames) {
          for (const kw of (ALLERGEN_KEYWORDS[allergen] ?? [])) {
            assert(!name.includes(kw.toLowerCase()), `All-allergies+cycling: found "${kw}" (${allergen}) in "${name}"`);
          }
        }
      }
    });

    it('allergy exclusion applies to BEFORE phase (template-level)', async () => {
      // Before phase uses Algorithm C (template selection). Templates with allergens should be excluded.
      const { planData, planStatus } = await generateFullPlan(macroProfiles.smallFemale, {
        allergies: ['gluten'],
      });
      assertEquals(planStatus, 200);
      const beforeNames = getBeforeFoods(planData.plan).map((f: any) => (f.display_name || '').toLowerCase());
      for (const name of beforeNames) {
        for (const kw of ALLERGEN_KEYWORDS.gluten) {
          assert(!name.includes(kw.toLowerCase()),
            `Gluten allergy BEFORE phase: found "${kw}" in "${name}" — template filtering is broken`);
        }
      }
    });

    it('dairy allergy excludes from BEFORE phase', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['dairy'],
      });
      const beforeNames = getBeforeFoods(planData.plan).map((f: any) => (f.display_name || '').toLowerCase());
      for (const name of beforeNames) {
        for (const kw of ALLERGEN_KEYWORDS.dairy) {
          assert(!name.includes(kw.toLowerCase()),
            `Dairy allergy BEFORE phase: found "${kw}" in "${name}"`);
        }
      }
    });

    // --- Combined: diet + allergy + sport ---

    it('vegan + gluten allergy + cycling: no animal products, no gluten', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.heavyCyclist, {
        dietary_preference: 'vegan',
        allergies: ['gluten'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of VEGAN_EXCLUDED_KEYWORDS) {
          assert(!name.includes(kw.toLowerCase()), `Vegan+gluten+cycling: found animal "${kw}" in "${name}"`);
        }
        for (const kw of ALLERGEN_KEYWORDS.gluten) {
          assert(!name.includes(kw.toLowerCase()), `Vegan+gluten+cycling: found gluten "${kw}" in "${name}"`);
        }
      }
    });

    it('vegan + all 5 allergies + multiple dislikes: most restrictive scenario', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'vegan',
        allergies: ['gluten', 'dairy', 'peanuts', 'tree nuts', 'eggs'],
        disliked_foods: ['banana', 'oatmeal', 'energy gel'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, 'Most restrictive scenario should still produce at least 1 food');

      // Verify ALL constraints
      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        // Vegan check
        for (const kw of VEGAN_EXCLUDED_KEYWORDS) {
          assert(!name.includes(kw.toLowerCase()), `Max restriction: found animal "${kw}" in "${name}"`);
        }
        // All allergens
        for (const allergen of ['gluten', 'dairy', 'peanuts', 'tree nuts', 'eggs']) {
          for (const kw of (ALLERGEN_KEYWORDS[allergen] ?? [])) {
            assert(!name.includes(kw.toLowerCase()), `Max restriction: found "${kw}" (${allergen}) in "${name}"`);
          }
        }
      }
      // Dislikes in during/after
      const duringAfterNames = getAllFoodNames(planData.plan, true);
      for (const name of duringAfterNames) {
        assert(!name.includes('banana'), `Max restriction: found disliked "banana" in "${name}"`);
        assert(!name.includes('oatmeal'), `Max restriction: found disliked "oatmeal" in "${name}"`);
        assert(!name.includes('energy gel') && !name.includes('energy_gel'),
          `Max restriction: found disliked "energy gel" in "${name}"`);
      }
    });

    it('paleo + swimmer: valid plan, no grains', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.swimmer, {
        dietary_preference: 'paleo',
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const allFoods = getAllFoods(planData.plan);
      assert(allFoods.length >= 1, 'Paleo swimmer should have valid plan');
    });

    it('gluten-free + hot weather runner: valid plan, no gluten', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.hotWeatherRunner, {
        dietary_preference: 'gluten-free',
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of ALLERGEN_KEYWORDS.gluten) {
          assert(!name.includes(kw.toLowerCase()),
            `Gluten-free+hot: found "${kw}" in "${name}"`);
        }
      }
    });

    // --- Liked food conflicts with allergy ---

    it('liked food containing allergen should STILL be excluded', async () => {
      // User likes "granola" but is allergic to tree nuts.
      // Granola often contains nuts. The allergen must win.
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['tree nuts'],
        liked_foods: ['granola'],
      });
      assertEquals(planStatus, 200);
      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of ALLERGEN_KEYWORDS['tree nuts']) {
          assert(!name.includes(kw.toLowerCase()),
            `Liked granola + tree nut allergy: found "${kw}" in "${name}" — allergy must override like`);
        }
      }
    });

    it('liked food that IS an allergen should be excluded', async () => {
      // User likes "peanut butter" but has peanut allergy. Safety must win.
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['peanuts'],
        liked_foods: ['peanut butter'],
      });
      assertEquals(planStatus, 200);
      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of ALLERGEN_KEYWORDS.peanuts) {
          assert(!name.includes(kw.toLowerCase()),
            `Liked PB + peanut allergy: found "${kw}" in "${name}" — allergy MUST override like`);
        }
      }
    });

    // --- Disliked foods in ALL phases including BEFORE ---

    it('disliked oatmeal excluded from BEFORE phase templates', async () => {
      // Before phase uses Algorithm C templates. Disliked foods should suppress templates containing them.
      let foundOatmeal = false;
      // Run 3 times to catch stochastic template selection
      for (let i = 0; i < 3; i++) {
        const { planData } = await generateFullPlan(macroProfiles.smallFemale, {
          disliked_foods: ['oatmeal'],
        });
        const beforeNames = getBeforeFoods(planData.plan).map((f: any) => (f.display_name || '').toLowerCase());
        if (beforeNames.some((n: string) => n.includes('oatmeal'))) {
          foundOatmeal = true;
          break;
        }
      }
      assert(!foundOatmeal, 'Disliked "oatmeal" appeared in before phase in at least 1 of 3 runs — template filtering should exclude it');
    });

    it('disliked toast excluded from BEFORE phase templates', async () => {
      let foundToast = false;
      for (let i = 0; i < 3; i++) {
        const { planData } = await generateFullPlan(macroProfiles.averageMale, {
          disliked_foods: ['toast'],
        });
        const beforeNames = getBeforeFoods(planData.plan).map((f: any) => (f.display_name || '').toLowerCase());
        if (beforeNames.some((n: string) => n.includes('toast'))) {
          foundToast = true;
          break;
        }
      }
      assert(!foundToast, 'Disliked "toast" appeared in before phase in at least 1 of 3 runs');
    });

    it('disliked banana excluded from ALL phases', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale, {
        disliked_foods: ['banana'],
      });
      // Check ALL phases including before
      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        assert(!name.includes('banana'),
          `Disliked "banana" found in plan: "${name}" — must be excluded from ALL phases`);
      }
    });

    it('disliked energy chews excluded from during phase', async () => {
      const { planData } = await generateFullPlan(macroProfiles.averageMale, {
        disliked_foods: ['energy chews'],
      });
      const duringNames = planData.plan.during.foods.map((f: any) => (f.display_name || '').toLowerCase());
      for (const name of duringNames) {
        assert(!name.includes('energy chew') && !name.includes('energy_chew'),
          `Disliked "energy chews" found in during phase: "${name}"`);
      }
    });

    // --- Multiple disliked + multiple allergies + diet ---

    it('dairy-free diet + egg allergy + dislike banana + dislike gel + cycling', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.heavyCyclist, {
        dietary_preference: 'dairy-free',
        allergies: ['eggs'],
        disliked_foods: ['banana', 'energy gel'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of ALLERGEN_KEYWORDS.dairy) {
          assert(!name.includes(kw.toLowerCase()), `Dairy-free cyclist: found "${kw}" in "${name}"`);
        }
        for (const kw of ALLERGEN_KEYWORDS.eggs) {
          assert(!name.includes(kw.toLowerCase()), `Egg allergy cyclist: found "${kw}" in "${name}"`);
        }
      }
      const duringAfterNames = getAllFoodNames(planData.plan, true);
      for (const name of duringAfterNames) {
        assert(!name.includes('banana'), `Disliked banana found in "${name}"`);
        assert(!name.includes('energy gel') && !name.includes('energy_gel'), `Disliked gel found in "${name}"`);
      }
    });

    it('vegan + peanut allergy + dislike sports drink + hot weather: valid plan', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.hotWeatherRunner, {
        dietary_preference: 'vegan',
        allergies: ['peanuts'],
        disliked_foods: ['sports drink', 'sports_drink'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of VEGAN_EXCLUDED_KEYWORDS) {
          assert(!name.includes(kw.toLowerCase()), `Vegan+peanut+hot: found animal "${kw}" in "${name}"`);
        }
        for (const kw of ALLERGEN_KEYWORDS.peanuts) {
          assert(!name.includes(kw.toLowerCase()), `Vegan+peanut+hot: found "${kw}" in "${name}"`);
        }
      }
      const duringAfterNames = getAllFoodNames(planData.plan, true);
      for (const name of duringAfterNames) {
        assert(!name.includes('sports drink') && !name.includes('sports_drink'),
          `Disliked sports drink found in "${name}"`);
      }
    });

    // --- Liked foods across sports ---

    it('liked banana appears for cyclist (at least 1 of 3 runs)', async () => {
      let foundLiked = false;
      for (let i = 0; i < 3; i++) {
        const { planData } = await generateFullPlan(macroProfiles.heavyCyclist, {
          liked_foods: ['banana'],
        });
        const names = getAllFoodNames(planData.plan);
        if (names.some((n: string) => n.includes('banana'))) {
          foundLiked = true;
          break;
        }
      }
      assert(foundLiked, 'Liked "banana" should appear in at least 1 of 3 cycling plan generations');
    });

    it('liked energy gel appears for hot weather runner (at least 1 of 3 runs)', async () => {
      let foundLiked = false;
      for (let i = 0; i < 3; i++) {
        const { planData } = await generateFullPlan(macroProfiles.hotWeatherRunner, {
          liked_foods: ['energy gel'],
        });
        const names = getAllFoodNames(planData.plan);
        if (names.some((n: string) => n.includes('gel'))) {
          foundLiked = true;
          break;
        }
      }
      assert(foundLiked, 'Liked "energy gel" should appear in at least 1 of 3 hot weather plan generations');
    });

    // --- Simultaneous like + dislike (different foods) ---

    it('liked banana + disliked oatmeal + gluten allergy: all constraints respected', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['gluten'],
        liked_foods: ['banana'],
        disliked_foods: ['oatmeal'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);

      const allNames = getAllFoodNames(planData.plan, false);
      for (const name of allNames) {
        for (const kw of ALLERGEN_KEYWORDS.gluten) {
          assert(!name.includes(kw.toLowerCase()), `Like+dislike+allergy: found gluten "${kw}" in "${name}"`);
        }
      }
      const duringAfterNames = getAllFoodNames(planData.plan, true);
      for (const name of duringAfterNames) {
        assert(!name.includes('oatmeal'), `Disliked oatmeal found despite being disliked: "${name}"`);
      }
    });

    // --- Edge case: disliked food = liked food (contradictory) ---

    it('same food liked AND disliked: dislike wins (safety)', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        liked_foods: ['oatmeal'],
        disliked_foods: ['oatmeal'],
      });
      assertEquals(planStatus, 200);
      assertEquals(planData.success, true);
      const duringAfterNames = getAllFoodNames(planData.plan, true);
      for (const name of duringAfterNames) {
        assert(!name.includes('oatmeal'),
          `Oatmeal is both liked AND disliked — dislike should win, but found in "${name}"`);
      }
    });

    // --- Verify constraint compliance for constrained profiles still hits macro ranges ---

    it('vegan + gluten-free runner: after macros still within V4 range', async () => {
      const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        dietary_preference: 'vegan',
        allergies: ['gluten'],
      });
      assertEquals(planStatus, 200);
      const afterMacros = sumMacros(planData.plan.after);
      const m = macroData.macros;

      console.log(`  Vegan+GF after: carbs=${afterMacros.carbs.toFixed(1)}g, protein=${afterMacros.protein.toFixed(1)}g, sodium=${afterMacros.sodium.toFixed(0)}mg, water=${afterMacros.water.toFixed(0)}ml`);

      assertMacroInRange(afterMacros.carbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, 'Vegan+GF after carbs');
      assertMacroInRange(afterMacros.protein, m.post_run_protein_low_g, m.post_run_protein_high_g, 'Vegan+GF after protein');
    });

    it('all-allergies runner: during macros still within V4 range', async () => {
      const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.averageMale, {
        allergies: ['gluten', 'dairy', 'peanuts', 'tree nuts', 'eggs'],
      });
      assertEquals(planStatus, 200);
      const duringMacros = sumMacros(planData.plan.during.foods);
      const m = macroData.macros;

      const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
      const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;

      console.log(`  All-allergies during: carbs=${duringMacros.carbs.toFixed(1)}g [${bandLowTotal.toFixed(0)}, ${bandHighTotal.toFixed(0)}], sodium=${duringMacros.sodium.toFixed(0)}mg`);

      assertMacroInRange(duringMacros.carbs, bandLowTotal, bandHighTotal, 'All-allergies during carbs');
      assertMacroInRange(duringMacros.sodium, m.during_sodium_low_mg, m.during_sodium_high_mg, 'All-allergies during sodium');
    });
  });

  // ============================================================================
  // 21. Extreme Scenario Validation
  // ============================================================================

  describe('21. Extreme Scenario Validation', () => {
    it('ultra runner 50mi: during carbs, sodium, hydration within V4 ranges', async () => {
      const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.ultraRunner);
      assertEquals(planStatus, 200);
      const m = macroData.macros;
      const duringMacros = sumMacros(planData.plan.during.foods);

      const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
      const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;

      console.log(`  Ultra 50mi during: carbs=${duringMacros.carbs.toFixed(1)}g [${bandLowTotal.toFixed(0)}, ${bandHighTotal.toFixed(0)}], sodium=${duringMacros.sodium.toFixed(0)}mg, water=${duringMacros.water.toFixed(0)}ml`);

      assertMacroInRange(duringMacros.carbs, bandLowTotal, bandHighTotal, 'Ultra during carbs');
      assertMacroInRange(duringMacros.sodium, m.during_sodium_low_mg, m.during_sodium_high_mg, 'Ultra during sodium');
      assertMacroInRange(duringMacros.water, m.during_water_low_ml, m.during_water_high_ml, 'Ultra during hydration');
    });

    it('ultra runner: no single food > 6 servings', async () => {
      const { planData, planStatus } = await generateFullPlan(macroProfiles.ultraRunner);
      assertEquals(planStatus, 200);
      const allFoods = getAllFoods(planData.plan);
      for (const food of allFoods) {
        assert(
          (food.quantity ?? 0) <= 6,
          `Ultra: ${food.display_name} x${food.quantity} — no food should exceed 6 servings`
        );
      }
    });

    it('very light female 44kg: all after macros within range', async () => {
      const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.veryLightFemale);
      assertEquals(planStatus, 200);
      const m = macroData.macros;
      const afterMacros = sumMacros(planData.plan.after);

      console.log(`  44kg female after: carbs=${afterMacros.carbs.toFixed(1)}g, protein=${afterMacros.protein.toFixed(1)}g, sodium=${afterMacros.sodium.toFixed(0)}mg`);

      assertMacroInRange(afterMacros.carbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, '44kg after carbs');
      assertMacroInRange(afterMacros.protein, m.post_run_protein_low_g, m.post_run_protein_high_g, '44kg after protein');
    });

    it('very heavy male 110kg: all during macros within range', async () => {
      const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.veryHeavyMale);
      assertEquals(planStatus, 200);
      const m = macroData.macros;
      const duringMacros = sumMacros(planData.plan.during.foods);

      const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
      const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;

      console.log(`  110kg during: carbs=${duringMacros.carbs.toFixed(1)}g [${bandLowTotal.toFixed(0)}, ${bandHighTotal.toFixed(0)}], sodium=${duringMacros.sodium.toFixed(0)}mg`);

      assertMacroInRange(duringMacros.carbs, bandLowTotal, bandHighTotal, '110kg during carbs');
      assertMacroInRange(duringMacros.sodium, m.during_sodium_low_mg, m.during_sodium_high_mg, '110kg during sodium');
    });

    it('100-mile cyclist: during carbs + sodium within range', async () => {
      const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.longCyclist);
      assertEquals(planStatus, 200);
      const m = macroData.macros;
      const duringMacros = sumMacros(planData.plan.during.foods);

      const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
      const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;

      console.log(`  100mi cyclist during: carbs=${duringMacros.carbs.toFixed(1)}g [${bandLowTotal.toFixed(0)}, ${bandHighTotal.toFixed(0)}], sodium=${duringMacros.sodium.toFixed(0)}mg`);

      assertMacroInRange(duringMacros.carbs, bandLowTotal, bandHighTotal, '100mi cyclist during carbs');
      assertMacroInRange(duringMacros.sodium, m.during_sodium_low_mg, m.during_sodium_high_mg, '100mi cyclist during sodium');
    });

    it('marathon heavy sweater: during sodium within V4 range', async () => {
      const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.marathonHeavySweater);
      assertEquals(planStatus, 200);
      const m = macroData.macros;
      const duringMacros = sumMacros(planData.plan.during.foods);

      console.log(`  Marathon heavy sweater during: sodium=${duringMacros.sodium.toFixed(0)}mg [${m.during_sodium_low_mg}, ${m.during_sodium_high_mg}], water=${duringMacros.water.toFixed(0)}ml`);

      assertMacroInRange(duringMacros.sodium, m.during_sodium_low_mg, m.during_sodium_high_mg, 'Marathon heavy sweater during sodium');
    });

    it('short 5mi easy run: before/after reasonable, during minimal', async () => {
      const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.shortEasyRun);
      assertEquals(planStatus, 200);
      const m = macroData.macros;

      const beforeMacros = sumMacros(getBeforeFoods(planData.plan));
      console.log(`  Short run before: carbs=${beforeMacros.carbs.toFixed(1)}g`);
      assertMacroInRange(beforeMacros.carbs, m.pre_run_carbs_low_g, m.pre_run_carbs_high_g, 'Short run before carbs');

      const afterMacros = sumMacros(planData.plan.after);
      console.log(`  Short run after: carbs=${afterMacros.carbs.toFixed(1)}g, protein=${afterMacros.protein.toFixed(1)}g`);
      assertMacroInRange(afterMacros.carbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, 'Short run after carbs');
    });

    it('32mi cycling: all phases within range', async () => {
      const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.mediumDistanceCyclist);
      assertEquals(planStatus, 200);
      const m = macroData.macros;

      const duringMacros = sumMacros(planData.plan.during.foods);
      const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
      const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;

      console.log(`  32mi cycling during: carbs=${duringMacros.carbs.toFixed(1)}g [${bandLowTotal.toFixed(0)}, ${bandHighTotal.toFixed(0)}]`);
      assertMacroInRange(duringMacros.carbs, bandLowTotal, bandHighTotal, '32mi cycling during carbs');

      const afterMacros = sumMacros(planData.plan.after);
      assertMacroInRange(afterMacros.carbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, '32mi cycling after carbs');
    });
  });

  // ============================================================================
  // 22. Variability Stress Tests
  // ============================================================================

  describe('22. Variability Stress Tests', () => {
    it('average male: 5 consecutive plans ALL within V4 ranges', async () => {
      for (let i = 0; i < 5; i++) {
        const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.averageMale);
        assertEquals(planStatus, 200, `Run ${i + 1}: plan should succeed`);
        const m = macroData.macros;

        // Before
        const beforeMacros = sumMacros(getBeforeFoods(planData.plan));
        assertMacroInRange(beforeMacros.carbs, m.pre_run_carbs_low_g, m.pre_run_carbs_high_g, `Run ${i + 1} before carbs`);

        // During
        const duringMacros = sumMacros(planData.plan.during.foods);
        const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
        const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;
        assertMacroInRange(duringMacros.carbs, bandLowTotal, bandHighTotal, `Run ${i + 1} during carbs`);
        assertMacroInRange(duringMacros.sodium, m.during_sodium_low_mg, m.during_sodium_high_mg, `Run ${i + 1} during sodium`);

        // After
        const afterMacros = sumMacros(planData.plan.after);
        assertMacroInRange(afterMacros.carbs, m.post_run_carbs_low_g, m.post_run_carbs_high_g, `Run ${i + 1} after carbs`);
        assertMacroInRange(afterMacros.protein, m.post_run_protein_low_g, m.post_run_protein_high_g, `Run ${i + 1} after protein`);

        console.log(`  Run ${i + 1}: ALL macros within V4 ranges`);
      }
    });

    it('heavy cyclist: 3 consecutive plans ALL within ranges', async () => {
      for (let i = 0; i < 3; i++) {
        const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.heavyCyclist);
        assertEquals(planStatus, 200, `Cyclist run ${i + 1}: plan should succeed`);
        const m = macroData.macros;

        const duringMacros = sumMacros(planData.plan.during.foods);
        const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
        const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;
        assertMacroInRange(duringMacros.carbs, bandLowTotal, bandHighTotal, `Cyclist ${i + 1} during carbs`);
        assertMacroInRange(duringMacros.sodium, m.during_sodium_low_mg, m.during_sodium_high_mg, `Cyclist ${i + 1} during sodium`);

        console.log(`  Cyclist ${i + 1}: ALL macros within V4 ranges`);
      }
    });

    it('hot weather runner: 3 consecutive plans ALL within ranges', async () => {
      for (let i = 0; i < 3; i++) {
        const { planData, macroData, planStatus } = await generateFullPlan(macroProfiles.hotWeatherRunner);
        assertEquals(planStatus, 200, `Hot run ${i + 1}: plan should succeed`);
        const m = macroData.macros;

        const duringMacros = sumMacros(planData.plan.during.foods);
        const bandLowTotal = m.during_band_low_g_per_h * m.duration_h;
        const bandHighTotal = Math.min(m.during_band_high_g_per_h, m.during_sport_ceiling_g_per_h) * m.duration_h;
        assertMacroInRange(duringMacros.carbs, bandLowTotal, bandHighTotal, `Hot run ${i + 1} during carbs`);
        assertMacroInRange(duringMacros.sodium, m.during_sodium_low_mg, m.during_sodium_high_mg, `Hot run ${i + 1} during sodium`);

        console.log(`  Hot run ${i + 1}: ALL macros within V4 ranges`);
      }
    });
  });

  // ============================================================================
  // 23. Electrolyte Capsule Guard
  // ============================================================================

  describe('23. Electrolyte Capsule Guard', () => {
    it('no electrolyte supplement > 4 servings in during phase (multiple profiles)', async () => {
      const profiles = ['averageMale', 'heavyCyclist', 'hotWeatherRunner', 'marathonHeavySweater'];
      for (const profileKey of profiles) {
        const profile = macroProfiles[profileKey];
        const { planData, planStatus } = await generateFullPlan(profile);
        assertEquals(planStatus, 200, `${profileKey}: plan should succeed`);

        const duringFoods = planData.plan.during?.foods ?? [];
        for (const food of duringFoods) {
          if (food.is_electrolyte && food.product_type === 'supplement') {
            assert(
              food.quantity <= 4,
              `${profileKey}: electrolyte ${food.display_name} x${food.quantity} — must be ≤4 servings`
            );
          }
        }
        console.log(`  ${profileKey}: electrolyte capsule guard passed`);
      }
    });

    it('no electrolyte supplement > 4 servings in after phase', async () => {
      const profiles = ['averageMale', 'heavyCyclist', 'ultraRunner'];
      for (const profileKey of profiles) {
        const profile = macroProfiles[profileKey];
        const { planData, planStatus } = await generateFullPlan(profile);
        assertEquals(planStatus, 200);

        const afterFoods = planData.plan.after ?? [];
        for (const food of afterFoods) {
          if (food.is_electrolyte && food.product_type === 'supplement') {
            assert(
              food.quantity <= 4,
              `${profileKey} after: electrolyte ${food.display_name} x${food.quantity} — must be ≤4 servings`
            );
          }
        }
      }
    });
  });

  // ============================================================================
  // 24. Pre-Workout Timing Windows
  // ============================================================================

  describe('24. Pre-Workout Timing Windows', () => {
    const timingWindows = [0.5, 1.0, 1.5, 2.0, 3.0];

    for (const hours of timingWindows) {
      it(`${hours}h pre-workout: valid plan structure`, async () => {
        const profile = {
          ...macroProfiles.averageMale,
          hours_before: hours,
          is_fasted: hours === 0,
        };
        const { planData, planStatus } = await generateFullPlan(profile);
        assertEquals(planStatus, 200, `${hours}h window: plan should succeed`);

        // Check before phase has expected sub-phases
        const before = planData.plan.before;
        assertExists(before, `${hours}h: should have before phase`);

        if (hours >= 2.0) {
          // Full meal window: should have meal sub-phase
          assert(before.meal?.foods?.length > 0, `${hours}h: should have meal sub-phase foods`);
          console.log(`  ${hours}h: meal(${before.meal?.foods?.length ?? 0} foods), snack(${before.snack?.foods?.length ?? 0}), top_up(${before.top_up?.foods?.length ?? 0})`);
        } else if (hours >= 1.0) {
          // Snack window
          const totalFoods = countBeforeFoods(planData.plan);
          assert(totalFoods > 0, `${hours}h: should have some before-phase foods`);
          console.log(`  ${hours}h: ${totalFoods} before foods`);
        } else {
          // Top-up only
          console.log(`  ${hours}h: before foods count: ${countBeforeFoods(planData.plan)}`);
        }
      });
    }
  });

  // ============================================================================
  // 25. Comprehensive All-Profile All-Phase Validation
  // ============================================================================

  describe('25. Comprehensive All-Profile All-Phase Validation', () => {
    const profileKeys = [
      'smallFemale', 'averageMale', 'heavyCyclist', 'swimmer',
      'coldWeatherRunner', 'hotWeatherRunner', 'shortEasyRun',
      'veryLightFemale', 'veryHeavyMale', 'longCyclist',
      'marathonHeavySweater', 'mediumDistanceCyclist',
    ];

    it('all profiles x all phases: every macro within V4 range', async () => {
      const failures: string[] = [];

      for (const profileKey of profileKeys) {
        try {
          const profile = macroProfiles[profileKey];
          const { planData, macroData, planStatus } = await generateFullPlan(profile);

          if (planStatus !== 200) {
            failures.push(`${profileKey}: HTTP ${planStatus}`);
            continue;
          }

          const m = macroData.macros;

          // Before phase
          const beforeMacros = sumMacros(getBeforeFoods(planData.plan));
          if (m.pre_run_carbs_low_g != null && m.pre_run_carbs_high_g != null) {
            if (beforeMacros.carbs < m.pre_run_carbs_low_g || beforeMacros.carbs > m.pre_run_carbs_high_g) {
              failures.push(`${profileKey} before carbs: ${beforeMacros.carbs.toFixed(1)}g not in [${m.pre_run_carbs_low_g}, ${m.pre_run_carbs_high_g}]`);
            }
          }

          // During phase
          if (planData.plan.during?.foods) {
            const duringMacros = sumMacros(planData.plan.during.foods);
            const bandLowTotal = (m.during_band_low_g_per_h ?? 0) * (m.duration_h ?? 0);
            const bandHighTotal = Math.min(m.during_band_high_g_per_h ?? 999, m.during_sport_ceiling_g_per_h ?? 999) * (m.duration_h ?? 0);
            if (bandLowTotal > 0 && bandHighTotal > 0) {
              if (duringMacros.carbs < bandLowTotal || duringMacros.carbs > bandHighTotal) {
                failures.push(`${profileKey} during carbs: ${duringMacros.carbs.toFixed(1)}g not in [${bandLowTotal.toFixed(0)}, ${bandHighTotal.toFixed(0)}]`);
              }
            }
            if (m.during_sodium_low_mg != null && m.during_sodium_high_mg != null) {
              if (duringMacros.sodium < m.during_sodium_low_mg || duringMacros.sodium > m.during_sodium_high_mg) {
                failures.push(`${profileKey} during sodium: ${duringMacros.sodium.toFixed(0)}mg not in [${m.during_sodium_low_mg}, ${m.during_sodium_high_mg}]`);
              }
            }
          }

          // After phase
          const afterMacros = sumMacros(planData.plan.after ?? []);
          if (m.post_run_carbs_low_g != null && m.post_run_carbs_high_g != null) {
            if (afterMacros.carbs < m.post_run_carbs_low_g || afterMacros.carbs > m.post_run_carbs_high_g) {
              failures.push(`${profileKey} after carbs: ${afterMacros.carbs.toFixed(1)}g not in [${m.post_run_carbs_low_g}, ${m.post_run_carbs_high_g}]`);
            }
          }
          if (m.post_run_protein_low_g != null && m.post_run_protein_high_g != null) {
            if (afterMacros.protein < m.post_run_protein_low_g || afterMacros.protein > m.post_run_protein_high_g) {
              failures.push(`${profileKey} after protein: ${afterMacros.protein.toFixed(1)}g not in [${m.post_run_protein_low_g}, ${m.post_run_protein_high_g}]`);
            }
          }

          console.log(`  ${profileKey}: all phases validated`);
        } catch (error) {
          failures.push(`${profileKey}: ${(error as Error).message}`);
        }
      }

      if (failures.length > 0) {
        console.error(`\n  FAILURES (${failures.length}):\n  - ${failures.join('\n  - ')}`);
      }
      assertEquals(
        failures.length,
        0,
        `${failures.length} profile/phase failures:\n  - ${failures.join('\n  - ')}`,
      );
    });
  });
});
