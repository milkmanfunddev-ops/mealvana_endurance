/**
 * Integration Tests for generate-macros-v3 Edge Function
 *
 * Tests validate Rachel-corrected nutrition algorithm (v3) with research-validated formulas:
 * - Pre-workout: 1 g/kg per hour (linear, capped at 4 g/kg for 4h window)
 * - During-workout: Absolute g/hr bands based on duration (NOT body weight)
 * - Gut training: Multipliers (0.7×, 1.0×, 1.2×) applied to entire band
 * - Sport-specific ceilings: Running 70 g/hr, Cycling 120 g/hr, Swimming 0 g/hr
 * - During-workout target: Midpoint of the scaled band (no intensity positioning)
 *
 * Run with: deno test --allow-net --allow-env supabase/functions/generate-macros-v3/index.test.ts
 *
 * IMPORTANT: These tests call the deployed edge function and require:
 * - SUPABASE_URL environment variable
 * - SUPABASE_ANON_KEY environment variable
 */

import {
  assertEquals,
  assertExists,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it, beforeAll } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

// ============================================================================
// Configuration
// ============================================================================

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') || '';
const EDGE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/generate-macros-v3`;

// Tolerance for macro calculations (±10g for carbs, ±5g for protein/fat)
const CARB_TOLERANCE_G = 10;
const PROTEIN_TOLERANCE_G = 5;
const FAT_TOLERANCE_G = 5;

// ============================================================================
// Helper Functions
// ============================================================================

async function callEdgeFunction(body: any): Promise<any> {
  const response = await fetch(EDGE_FUNCTION_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    },
    body: JSON.stringify(body),
  });

  const data = await response.json();
  return { status: response.status, data };
}

/**
 * Assert that a value is within tolerance of target
 */
function assertWithinTolerance(
  actual: number,
  expected: number,
  tolerance: number,
  label: string
): void {
  const diff = Math.abs(actual - expected);
  assert(
    diff <= tolerance,
    `${label}: expected ${expected} (±${tolerance}), got ${actual} (diff: ${diff})`
  );
}

/**
 * Assert that a value is within a range
 */
function assertInRange(
  actual: number,
  min: number,
  max: number,
  label: string
): void {
  assert(
    actual >= min && actual <= max,
    `${label}: expected [${min}, ${max}], got ${actual}`
  );
}

// ============================================================================
// Test Fixtures
// ============================================================================

const fixtures = {
  // 70kg athlete, 3h pre-workout window
  preWorkout3Hours: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // 70kg athlete, 1h pre-workout window
  preWorkout1Hour: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 1,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // 70kg athlete, 0.5h pre-workout window (top-up)
  preWorkoutHalfHour: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 0.5,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // 70kg athlete, full meal window (2.5h)
  preWorkoutFullMeal: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 2.5,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // 70kg athlete, snack window (1.5h)
  preWorkoutSnack: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 1.5,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // 2h run, moderate gut training
  during2HoursModerateGut: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 16.25,
    run_distance_unit: 'mi',
    run_pace: '8:00', // 130 min = 2.17h
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // 2h run, low gut training (0.7x multiplier)
  during2HoursLowGut: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 16.25,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'low',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // 2h run, high gut training (1.2x multiplier)
  during2HoursHighGut: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 16.25,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'high',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // Running workout (sport ceiling 70 g/hr)
  runningWorkout: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 20,
    run_distance_unit: 'mi',
    run_pace: '7:00', // Long, fast run
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    intensity_distribution: {
      zone_low: 0,
      zone_mid: 0.3,
      zone_high: 0.7,
    },
  },

  // Cycling workout (sport ceiling 120 g/hr)
  cyclingWorkout: {
    weight: 70,
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
    intensity_distribution: {
      zone_low: 0,
      zone_mid: 0.3,
      zone_high: 0.7,
    },
  },

  // Swimming workout (sport ceiling 0 g/hr)
  swimmingWorkout: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    activity_type: 'swimming',
    distance_meters: 3000,
    pace_per_100m_seconds: 90,
    pool_or_open_water: 'pool',
    water_temp_c: 26,
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // Fasted workout
  fastedWorkout: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 0,
    is_fasted: true,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // Long duration (>2h) for post-workout
  longDurationWorkout: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 20,
    run_distance_unit: 'mi',
    run_pace: '8:00', // 160 min = 2.67h
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // Short duration (<=2h) for post-workout
  shortDurationWorkout: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '8:00', // 80 min = 1.33h
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  // Fasted long workout for post-workout boost
  fastedLongWorkout: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 0,
    is_fasted: true,
    run_distance: 20,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },
};

// ============================================================================
// Tests
// ============================================================================

describe('generate-macros-v3 Edge Function', () => {
  beforeAll(() => {
    // Validate environment
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
      console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variables');
      console.error('Set these before running tests:');
      console.error('  export SUPABASE_URL=https://your-project.supabase.co');
      console.error('  export SUPABASE_ANON_KEY=your-anon-key');
      Deno.exit(1);
    }
  });

  describe('Pre-Workout Nutrition Tests', () => {
    it('should calculate 210g carbs for 70kg athlete at 3h (3 g/kg)', async () => {
      const { status, data } = await callEdgeFunction(fixtures.preWorkout3Hours);

      assertEquals(status, 200);
      assertEquals(data.success, true);
      assertExists(data.macros);

      // 70kg × 3 g/kg = 210g
      assertWithinTolerance(data.macros.pre_run_carbs_g, 210, CARB_TOLERANCE_G, 'Pre-workout carbs (3h)');
    });

    it('should calculate 70g carbs for 70kg athlete at 1h (1 g/kg)', async () => {
      const { status, data } = await callEdgeFunction(fixtures.preWorkout1Hour);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // 70kg × 1 g/kg = 70g
      assertWithinTolerance(data.macros.pre_run_carbs_g, 70, CARB_TOLERANCE_G, 'Pre-workout carbs (1h)');
    });

    it('should calculate 35g carbs for 70kg athlete at 0.5h (0.5 g/kg minimum)', async () => {
      const { status, data } = await callEdgeFunction(fixtures.preWorkoutHalfHour);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // 70kg × 0.5 g/kg = 35g
      assertWithinTolerance(data.macros.pre_run_carbs_g, 35, CARB_TOLERANCE_G, 'Pre-workout carbs (0.5h)');
    });

    it('should set full meal macros for >=2.5h window: protein 0.25 g/kg, fat 0.4 g/kg', async () => {
      const { status, data } = await callEdgeFunction(fixtures.preWorkoutFullMeal);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // Protein: 70kg × 0.25 g/kg = 17.5g (rounds to 18g)
      // Fat: 70kg × 0.4 g/kg = 28g
      assertWithinTolerance(data.macros.pre_run_protein_g, 18, PROTEIN_TOLERANCE_G, 'Pre-workout protein (full meal)');
      assertWithinTolerance(data.macros.pre_run_fat_g, 28, FAT_TOLERANCE_G, 'Pre-workout fat (full meal)');
      assertEquals(data.macros.pre_run_meal_type, 'full_meal');
    });

    it('should set snack macros for 1-2.5h window: protein 0.15 g/kg, fat 5g', async () => {
      const { status, data } = await callEdgeFunction(fixtures.preWorkoutSnack);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // Protein: 70kg × 0.15 g/kg = 10.5g (rounds to 11g)
      // Fat: 5g fixed
      assertWithinTolerance(data.macros.pre_run_protein_g, 11, PROTEIN_TOLERANCE_G, 'Pre-workout protein (snack)');
      assertEquals(data.macros.pre_run_fat_g, 5);
      assertEquals(data.macros.pre_run_meal_type, 'snack');
    });

    it('should set top-up macros for <1h window: protein 0g, fat 0g', async () => {
      const { status, data } = await callEdgeFunction(fixtures.preWorkoutHalfHour);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      assertEquals(data.macros.pre_run_protein_g, 0);
      assertEquals(data.macros.pre_run_fat_g, 0);
      assertEquals(data.macros.pre_run_meal_type, 'top_up');
    });
  });

  describe('During-Exercise Nutrition Tests', () => {
    it('should calculate 2h run with moderate gut in 45-60 g/hr band', async () => {
      const { status, data } = await callEdgeFunction(fixtures.during2HoursModerateGut);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // 2h run falls in 90-150min range: base band 45-60 g/hr
      // Moderate gut: 1.0× multiplier
      assertEquals(data.macros.during_band_low_g_per_h, 45);
      assertEquals(data.macros.during_band_high_g_per_h, 60);
      assertEquals(data.macros.during_gut_multiplier, 1.0);

      // Midpoint of scaled band: (45 + 60) / 2 = 52.5 g/hr
      assertEquals(data.macros.during_rate_g_per_h, 52.5);
    });

    it('should apply low gut multiplier (0.7x) to entire band: 31.5-42 g/hr', async () => {
      const { status, data } = await callEdgeFunction(fixtures.during2HoursLowGut);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // Base band: 45-60 g/hr
      // Low gut: 0.7× → 31.5-42 g/hr
      assertWithinTolerance(data.macros.during_band_low_g_per_h, 32, 2, 'Low gut band low (31.5)');
      assertWithinTolerance(data.macros.during_band_high_g_per_h, 42, 2, 'Low gut band high');
      assertEquals(data.macros.during_gut_multiplier, 0.7);

      // Midpoint of scaled band: (31.5 + 42) / 2 = 36.75 → 36.8 g/hr
      assertWithinTolerance(data.macros.during_rate_g_per_h, 36.8, 0.1, 'During-exercise carb rate (low gut)');
    });

    it('should apply high gut multiplier (1.2x) to entire band: 54-72 g/hr', async () => {
      const { status, data } = await callEdgeFunction(fixtures.during2HoursHighGut);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // Base band: 45-60 g/hr
      // High gut: 1.2× → 54-72 g/hr
      assertWithinTolerance(data.macros.during_band_low_g_per_h, 54, 2, 'High gut band low');
      assertWithinTolerance(data.macros.during_band_high_g_per_h, 72, 2, 'High gut band high');
      assertEquals(data.macros.during_gut_multiplier, 1.2);

      // Midpoint of scaled band: (54 + 72) / 2 = 63 g/hr
      assertWithinTolerance(data.macros.during_rate_g_per_h, 63, 0.1, 'During-exercise carb rate (high gut)');
    });

    it('should cap running at sport ceiling of 70 g/hr', async () => {
      const { status, data } = await callEdgeFunction(fixtures.runningWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70);
      assert(
        data.macros.during_rate_g_per_h <= 70,
        `Running should cap at 70 g/hr, got ${data.macros.during_rate_g_per_h}`
      );
    });

    it('should cap cycling at sport ceiling of 120 g/hr', async () => {
      const { status, data } = await callEdgeFunction(fixtures.cyclingWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      assertEquals(data.macros.during_sport_ceiling_g_per_h, 120);
      assert(
        data.macros.during_rate_g_per_h <= 120,
        `Cycling should cap at 120 g/hr, got ${data.macros.during_rate_g_per_h}`
      );
    });

    it('should cap swimming at sport ceiling of 0 g/hr', async () => {
      const { status, data } = await callEdgeFunction(fixtures.swimmingWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      assertEquals(data.macros.during_sport_ceiling_g_per_h, 0);
      assertEquals(data.macros.during_rate_g_per_h, 0, 'Swimming should have 0 g/hr during');
    });

    it('should not use body weight in during-exercise calculation', async () => {
      // Test with two different body weights, same duration/intensity
      const workout70kg = {
        ...fixtures.during2HoursModerateGut,
        weight: 70,
      };

      const workout100kg = {
        ...fixtures.during2HoursModerateGut,
        weight: 100,
      };

      const { data: data70 } = await callEdgeFunction(workout70kg);
      const { data: data100 } = await callEdgeFunction(workout100kg);

      // During-exercise carb rate should be the same (body weight independent)
      assertEquals(
        data70.macros.during_rate_g_per_h,
        data100.macros.during_rate_g_per_h,
        'During-exercise rate should not depend on body weight'
      );
    });
  });

  describe('Fasted Mode Tests', () => {
    it('should set pre-workout macros to 0 for fasted workout', async () => {
      const { status, data } = await callEdgeFunction(fixtures.fastedWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      assertEquals(data.macros.pre_run_carbs_g, 0);
      assertEquals(data.macros.pre_run_protein_g, 0);
      assertEquals(data.macros.pre_run_fat_g, 0);
      assertEquals(data.macros.pre_run_meal_type, 'fasted');
    });

    it('should apply 1.2x carb boost to post-workout for fasted workout', async () => {
      const { data: fastedData } = await callEdgeFunction(fixtures.fastedLongWorkout);
      const { data: fedData } = await callEdgeFunction(fixtures.longDurationWorkout);

      // Both are long duration (>2h), so base is 1.2 g/kg
      // Fasted adds another 1.2x multiplier: 70kg × 1.2 × 1.2 = 100.8g
      // Fed: 70kg × 1.2 = 84g
      assertWithinTolerance(fastedData.macros.post_run_carbs_g, 101, CARB_TOLERANCE_G, 'Post-workout carbs (fasted)');
      assertWithinTolerance(fedData.macros.post_run_carbs_g, 84, CARB_TOLERANCE_G, 'Post-workout carbs (fed)');

      // Verify fasted has higher carbs
      assert(
        fastedData.macros.post_run_carbs_g > fedData.macros.post_run_carbs_g,
        'Fasted post-workout carbs should be higher than fed'
      );
    });

    it('should set protein to 0.35 g/kg for fasted post-workout', async () => {
      const { data: fastedData } = await callEdgeFunction(fixtures.fastedWorkout);
      const { data: fedData } = await callEdgeFunction(fixtures.shortDurationWorkout);

      // Fasted: 70kg × 0.35 g/kg = 24.5g (rounds to 25g)
      // Fed: 70kg × 0.3 g/kg = 21g
      assertWithinTolerance(fastedData.macros.post_run_protein_g, 25, PROTEIN_TOLERANCE_G, 'Post-workout protein (fasted)');
      assertWithinTolerance(fedData.macros.post_run_protein_g, 21, PROTEIN_TOLERANCE_G, 'Post-workout protein (fed)');
    });
  });

  describe('Post-Workout Nutrition Tests', () => {
    it('should set carbs to 1.2 g/kg for duration > 2h', async () => {
      const { status, data } = await callEdgeFunction(fixtures.longDurationWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // 70kg × 1.2 g/kg = 84g
      assertWithinTolerance(data.macros.post_run_carbs_g, 84, CARB_TOLERANCE_G, 'Post-workout carbs (>2h)');
    });

    it('should set carbs to 1.0 g/kg for duration <= 2h', async () => {
      const { status, data } = await callEdgeFunction(fixtures.shortDurationWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // 70kg × 1.0 g/kg = 70g
      assertWithinTolerance(data.macros.post_run_carbs_g, 70, CARB_TOLERANCE_G, 'Post-workout carbs (<=2h)');
    });

    it('should set protein to 0.3 g/kg for normal post-workout', async () => {
      const { status, data } = await callEdgeFunction(fixtures.shortDurationWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // 70kg × 0.3 g/kg = 21g
      assertWithinTolerance(data.macros.post_run_protein_g, 21, PROTEIN_TOLERANCE_G, 'Post-workout protein');
    });

    it('should set fat to 0.2 g/kg for post-workout', async () => {
      const { status, data } = await callEdgeFunction(fixtures.shortDurationWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      // 70kg × 0.2 g/kg = 14g
      assertWithinTolerance(data.macros.post_run_fat_g, 14, FAT_TOLERANCE_G, 'Post-workout fat');
    });
  });

  describe('Algorithm Metadata', () => {
    it('should return algorithm_version as v3', async () => {
      const { status, data } = await callEdgeFunction(fixtures.preWorkout3Hours);

      assertEquals(status, 200);
      assertEquals(data.success, true);
      assertEquals(data.macros.algorithm_version, 'v3');
    });

    it('should include all required metadata fields', async () => {
      const { status, data } = await callEdgeFunction(fixtures.preWorkout3Hours);

      assertEquals(status, 200);
      assertEquals(data.success, true);

      const macros = data.macros;

      // Duration & distance
      assertExists(macros.duration_min);
      assertExists(macros.duration_h);
      assertExists(macros.distance_km);

      // Energy
      assertExists(macros.calories_gross_kcal);
      assertExists(macros.calories_net_kcal);
      assertExists(macros.MET);

      // Intensity
      assertExists(macros.intensity_distribution);
      assertExists(macros.intensity_distribution.zone_low);
      assertExists(macros.intensity_distribution.zone_mid);
      assertExists(macros.intensity_distribution.zone_high);

      // Pre-workout
      assertExists(macros.pre_run_carbs_g);
      assertExists(macros.pre_run_protein_g);
      assertExists(macros.pre_run_fat_g);
      assertExists(macros.pre_run_sodium_mg);
      assertExists(macros.pre_run_water_ml);
      assertExists(macros.pre_run_meal_type);

      // During-workout
      assertExists(macros.during_rate_g_per_h);
      assertExists(macros.during_total_g);
      assertExists(macros.during_band_low_g_per_h);
      assertExists(macros.during_band_high_g_per_h);
      assertExists(macros.during_gut_multiplier);
      assertExists(macros.during_sport_ceiling_g_per_h);
      assertExists(macros.during_sodium_rate_mg_per_h);
      assertExists(macros.during_water_rate_ml_per_h);

      // Post-workout
      assertExists(macros.post_run_carbs_g);
      assertExists(macros.post_run_protein_g);
      assertExists(macros.post_run_fat_g);
      assertExists(macros.post_run_sodium_mg);
      assertExists(macros.post_run_water_ml);

      // Hydration details
      assertExists(macros.sweat_rate_lph);
      assertExists(macros.sodium_conc_mg_per_l);
      assertExists(macros.environment_label);
    });
  });

  describe('Multi-Sport Support', () => {
    it('should calculate macros for running workout', async () => {
      const { status, data } = await callEdgeFunction(fixtures.runningWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);
      assertEquals(data.macros.activity_type, 'running');
    });

    it('should calculate macros for cycling workout', async () => {
      const { status, data } = await callEdgeFunction(fixtures.cyclingWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);
      assertEquals(data.macros.activity_type, 'cycling');
    });

    it('should calculate macros for swimming workout', async () => {
      const { status, data } = await callEdgeFunction(fixtures.swimmingWorkout);

      assertEquals(status, 200);
      assertEquals(data.success, true);
      assertEquals(data.macros.activity_type, 'swimming');
    });
  });

  describe('Error Handling', () => {
    it('should return error for missing weight', async () => {
      const { status, data } = await callEdgeFunction({
        hours_before: 3,
        is_fasted: false,
        run_distance: 10,
        run_pace: '8:00',
      });

      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('should return error for missing hours_before', async () => {
      const { status, data } = await callEdgeFunction({
        weight: 70,
        weight_unit: 'kg',
        is_fasted: false,
        run_distance: 10,
        run_pace: '8:00',
      });

      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('should return error for missing is_fasted', async () => {
      const { status, data } = await callEdgeFunction({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 3,
        run_distance: 10,
        run_pace: '8:00',
      });

      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('should return error for missing activity-specific fields (running)', async () => {
      const { status, data } = await callEdgeFunction({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 3,
        is_fasted: false,
        activity_type: 'running',
        // Missing run_distance and run_pace
      });

      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('should return error for invalid activity_type', async () => {
      const { status, data } = await callEdgeFunction({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 3,
        is_fasted: false,
        activity_type: 'invalid_sport',
      });

      assertEquals(status, 400);
      assertEquals(data.success, false);
    });
  });
});

// ============================================================================
// Brick Workout Test Fixtures
// ============================================================================

const brickFixtures = {
  // Full triathlon: swim/bike/run, 70kg athlete
  swimBikeRun: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 2.5,
    is_fasted: false,
    activity_type: 'brick',
    gut_training: 'moderate',
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
        duration_minutes: 60,
        intensity: 'moderate',
        pace_minutes_per_mile: 9,
      },
    ],
    segment_order: ['swimming', 'cycling', 'running'],
  },

  // 2-segment brick: bike/run
  bikeRun: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    activity_type: 'brick',
    gut_training: 'high',
    brick_segments: [
      {
        sport: 'cycling',
        order: 1,
        duration_minutes: 90,
        intensity: 'hard',
        distance_miles: 30,
        speed_mph: 20,
        terrain: 'rolling',
      },
      {
        sport: 'running',
        order: 2,
        duration_minutes: 45,
        intensity: 'moderate',
        pace_minutes_per_mile: 8,
      },
    ],
    segment_order: ['cycling', 'running'],
  },

  // Fasted brick workout
  fastedBrick: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 0,
    is_fasted: true,
    activity_type: 'brick',
    gut_training: 'moderate',
    brick_segments: [
      {
        sport: 'cycling',
        order: 1,
        duration_minutes: 60,
        intensity: 'easy',
        distance_miles: 18,
        speed_mph: 18,
        terrain: 'flat',
      },
      {
        sport: 'running',
        order: 2,
        duration_minutes: 30,
        intensity: 'easy',
        pace_minutes_per_mile: 10,
      },
    ],
    segment_order: ['cycling', 'running'],
  },
};

// ============================================================================
// Brick Workout Tests
// ============================================================================

describe('Brick Workout Support', () => {
  describe('Response Structure', () => {
    it('should return phases-structured response for brick workout', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      assertEquals(data.success, true);
      assertExists(data.macros);
      assertEquals(data.macros.algorithm_version, 'v3');
      assertEquals(data.macros.activity_type, 'brick');

      // Must have phases object
      assertExists(data.macros.phases);
      assertExists(data.macros.phases.before);
      assertExists(data.macros.phases.during_segments);
      assertExists(data.macros.phases.transitions);
      assertExists(data.macros.phases.after);
    });

    it('should return correct segment and transition counts for 3-sport brick', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      assertEquals(data.macros.phases.during_segments.length, 3, 'Should have 3 during segments');
      assertEquals(data.macros.phases.transitions.length, 2, 'Should have 2 transitions (T1, T2)');
    });

    it('should return correct segment and transition counts for 2-sport brick', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.bikeRun);

      assertEquals(status, 200);
      assertEquals(data.macros.phases.during_segments.length, 2, 'Should have 2 during segments');
      assertEquals(data.macros.phases.transitions.length, 1, 'Should have 1 transition (T1)');
    });

    it('should include duration, distance, and energy fields', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      assertExists(data.macros.duration_h);
      assertExists(data.macros.duration_min);
      assert(data.macros.distance_mi !== undefined, 'Should include distance_mi');
      assert(data.macros.distance_km !== undefined, 'Should include distance_km');
      assertExists(data.macros.calories_gross_kcal);
      assertExists(data.macros.calories_net_kcal);
    });
  });

  describe('Swimming Segment (0 Carbs)', () => {
    it('should give 0 carbs/water/sodium for swimming segment', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      const swimSegment = data.macros.phases.during_segments.find(
        (s: any) => s.sport === 'swimming'
      );
      assertExists(swimSegment);
      assertEquals(swimSegment.carbs_g, 0, 'Swimming should have 0 carbs');
      assertEquals(swimSegment.water_ml, 0, 'Swimming should have 0 water');
      assertEquals(swimSegment.sodium_mg, 0, 'Swimming should have 0 sodium');
    });
  });

  describe('Cycling and Running Segments', () => {
    it('should give positive carbs for cycling segment', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      const cyclingSegment = data.macros.phases.during_segments.find(
        (s: any) => s.sport === 'cycling'
      );
      assertExists(cyclingSegment);
      assert(cyclingSegment.carbs_g > 0, `Cycling should have positive carbs, got ${cyclingSegment.carbs_g}`);
      assert(cyclingSegment.water_ml > 0, `Cycling should have positive water, got ${cyclingSegment.water_ml}`);
    });

    it('should give positive carbs for running segment', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      const runningSegment = data.macros.phases.during_segments.find(
        (s: any) => s.sport === 'running'
      );
      assertExists(runningSegment);
      assert(runningSegment.carbs_g > 0, `Running should have positive carbs, got ${runningSegment.carbs_g}`);
      assert(runningSegment.water_ml > 0, `Running should have positive water, got ${runningSegment.water_ml}`);
    });

    it('should cap running carbs at sport ceiling of 70 g/hr', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      const runSegment = data.macros.phases.during_segments.find(
        (s: any) => s.sport === 'running'
      );
      assertExists(runSegment);
      // Running is 60 min = 1h, so max carbs at ceiling = 70g
      assert(
        runSegment.carbs_g <= 70,
        `Running carbs should not exceed ceiling (70g for 1h), got ${runSegment.carbs_g}`
      );
    });
  });

  describe('Transition Values (Distance-Based)', () => {
    it('should have Olympic-distance transitions for swimBikeRun (165 min total)', async () => {
      // swimBikeRun = 30+75+60 = 165 min (Olympic range: 90-180 min)
      // Olympic: T1 = 0g/0mg/50ml, T2 = 0g/0mg/50ml
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      const t1 = data.macros.phases.transitions.find(
        (t: any) => t.transition_name === 'T1'
      );
      assertExists(t1);
      assertEquals(t1.carbs_g, 0, 'T1 carbs should be 0g (Olympic)');
      assertEquals(t1.water_ml, 50, 'T1 water should be 50ml (Olympic)');
      assertEquals(t1.sodium_mg, 0, 'T1 sodium should be 0mg (Olympic)');

      const t2 = data.macros.phases.transitions.find(
        (t: any) => t.transition_name === 'T2'
      );
      assertExists(t2);
      assertEquals(t2.carbs_g, 0, 'T2 carbs should be 0g (Olympic)');
      assertEquals(t2.water_ml, 50, 'T2 water should be 50ml (Olympic)');
      assertEquals(t2.sodium_mg, 0, 'T2 sodium should be 0mg (Olympic)');
    });
  });

  describe('Pre/Post Workout (v3 Formulas)', () => {
    it('should use v3 pre-workout formula for brick (2.5h = full meal)', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      const before = data.macros.phases.before;

      // 70kg × 2.5 g/kg = 175g carbs
      assertWithinTolerance(before.carbs_g, 175, CARB_TOLERANCE_G, 'Brick pre-workout carbs');
      assertEquals(before.meal_type, 'full_meal');
      assert(before.protein_g > 0, 'Full meal should include protein');
      assert(before.fat_g > 0, 'Full meal should include fat');
    });

    it('should use v3 post-workout formula for brick', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      const after = data.macros.phases.after;

      // Total duration = 30+75+60 = 165 min = 2.75h (>2h, so 1.2 g/kg)
      // 70kg × 1.2 = 84g
      assertWithinTolerance(after.carbs_g, 84, CARB_TOLERANCE_G, 'Brick post-workout carbs');

      // Protein: 70kg × 0.3 = 21g
      assertWithinTolerance(after.protein_g, 21, PROTEIN_TOLERANCE_G, 'Brick post-workout protein');
    });

    it('should apply fasted mode to brick pre and post workout', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.fastedBrick);

      assertEquals(status, 200);
      const before = data.macros.phases.before;
      const after = data.macros.phases.after;

      // Fasted pre-workout = all zeros
      assertEquals(before.carbs_g, 0, 'Fasted brick pre carbs should be 0');
      assertEquals(before.protein_g, 0, 'Fasted brick pre protein should be 0');
      assertEquals(before.fat_g, 0, 'Fasted brick pre fat should be 0');
      assertEquals(before.meal_type, 'fasted');

      // Fasted post: 1.2x carb boost
      // Duration: 60+30 = 90 min = 1.5h (<=2h, so base 1.0 g/kg)
      // Fasted: 70 × 1.0 × 1.2 = 84g
      assertWithinTolerance(after.carbs_g, 84, CARB_TOLERANCE_G, 'Fasted brick post-workout carbs');

      // Fasted protein: 0.35 g/kg = 24.5g
      assertWithinTolerance(after.protein_g, 25, PROTEIN_TOLERANCE_G, 'Fasted brick post-workout protein');
    });
  });

  describe('Energy and Distance Sums', () => {
    it('should sum duration across all segments', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      // 30 + 75 + 60 = 165 minutes
      assertWithinTolerance(data.macros.duration_min, 165, 1, 'Total duration minutes');
      assertWithinTolerance(data.macros.duration_h, 2.75, 0.05, 'Total duration hours');
    });

    it('should have positive gross and net calories', async () => {
      const { status, data } = await callEdgeFunction(brickFixtures.swimBikeRun);

      assertEquals(status, 200);
      assert(data.macros.calories_gross_kcal > 0, 'Gross calories should be positive');
      assert(data.macros.calories_net_kcal > 0, 'Net calories should be positive');
      assert(
        data.macros.calories_gross_kcal >= data.macros.calories_net_kcal,
        'Gross should be >= net calories'
      );
    });
  });

  describe('Validation Errors', () => {
    it('should reject brick with missing brick_segments', async () => {
      const { status, data } = await callEdgeFunction({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 2.5,
        is_fasted: false,
        activity_type: 'brick',
        gut_training: 'moderate',
        // Missing brick_segments
      });

      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('should reject brick with only 1 segment', async () => {
      const { status, data } = await callEdgeFunction({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 2.5,
        is_fasted: false,
        activity_type: 'brick',
        gut_training: 'moderate',
        brick_segments: [
          { sport: 'running', order: 1, duration_minutes: 60, intensity: 'moderate' },
        ],
      });

      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('should reject brick with invalid segment sport', async () => {
      const { status, data } = await callEdgeFunction({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 2.5,
        is_fasted: false,
        activity_type: 'brick',
        gut_training: 'moderate',
        brick_segments: [
          { sport: 'kayaking', order: 1, duration_minutes: 60, intensity: 'moderate' },
          { sport: 'running', order: 2, duration_minutes: 30, intensity: 'moderate' },
        ],
      });

      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('should reject brick with segment missing duration', async () => {
      const { status, data } = await callEdgeFunction({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 2.5,
        is_fasted: false,
        activity_type: 'brick',
        gut_training: 'moderate',
        brick_segments: [
          { sport: 'cycling', order: 1, intensity: 'moderate' },
          { sport: 'running', order: 2, duration_minutes: 30, intensity: 'moderate' },
        ],
      });

      assertEquals(status, 400);
      assertEquals(data.success, false);
    });
  });
});

// Run tests if executed directly
if (import.meta.main) {
  console.log('Running generate-macros-v3 edge function integration tests...');
  console.log(`Edge Function URL: ${EDGE_FUNCTION_URL}`);
}
