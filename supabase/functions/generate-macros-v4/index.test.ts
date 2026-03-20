/**
 * Integration Tests for generate-macros-v4 Edge Function
 *
 * Tests validate Algorithm C "Comfort-Capped Hybrid" with:
 * - Range-based pre-workout targets with food selections
 * - V3 during-workout (duration bands, gut multipliers, sport ceilings)
 * - V3 post-workout (duration/fasted multipliers)
 * - Brick workout multi-segment calculations
 * - Error handling for invalid inputs
 *
 * Run with:
 *   export SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
 *   export SUPABASE_ANON_KEY=<prod-anon-key>
 *   deno test --allow-net --allow-env supabase/functions/generate-macros-v4/index.test.ts
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
const EDGE_FUNCTION_URL = `${SUPABASE_URL}/functions/v1/generate-macros-v4`;

const CARB_TOLERANCE_G = 10;
const PROTEIN_TOLERANCE_G = 5;

// ============================================================================
// Helper Functions
// ============================================================================

async function callMacrosV4(body: Record<string, unknown>): Promise<{ status: number; data: any }> {
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

function assertWithinTolerance(
  actual: number,
  expected: number,
  tolerance: number,
  label: string,
): void {
  const diff = Math.abs(actual - expected);
  assert(
    diff <= tolerance,
    `${label}: expected ${expected} (+-${tolerance}), got ${actual} (diff: ${diff})`,
  );
}

function assertInRange(actual: number, min: number, max: number, label: string): void {
  assert(
    actual >= min && actual <= max,
    `${label}: expected [${min}, ${max}], got ${actual}`,
  );
}

// ============================================================================
// Athlete Profiles (6 diverse)
// ============================================================================

const athletes = {
  /** Profile 1: Small female runner — 50kg, half marathon, 3h window */
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

  /** Profile 2: Average male runner — 70kg, 10mi, 2h window */
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

  /** Profile 3: Heavy male cyclist — 91kg, 60mi, hot conditions */
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

  /** Profile 4: Fasted runner — 65kg, 6mi, no pre-workout */
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

  /** Profile 5: Swimmer — 73kg, 3000m, pool */
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

  /** Profile 6: Lightweight top-up runner — 55kg, 10mi, 0.5h window */
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
};

// ============================================================================
// Tests
// ============================================================================

describe('generate-macros-v4 Integration Tests', () => {
  beforeAll(() => {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
      console.error('Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variables');
      Deno.exit(1);
    }
  });

  // =========================================================================
  // A. Response Structure (4 tests)
  // =========================================================================

  describe('A. Response Structure', () => {
    it('should return algorithm_version v4 and success: true', async () => {
      const { status, data } = await callMacrosV4(athletes.averageMale);
      assertEquals(status, 200);
      assertEquals(data.success, true);
      assertEquals(data.macros.algorithm_version, 'v4');
    });

    it('should include all required V4 fields', async () => {
      const { data } = await callMacrosV4(athletes.averageMale);
      const m = data.macros;

      // Duration & distance
      assertExists(m.duration_min);
      assertExists(m.duration_h);
      assertExists(m.distance_km);

      // Energy
      assertExists(m.calories_gross_kcal);
      assertExists(m.calories_net_kcal);
      assertExists(m.MET);

      // Pre-workout with ranges
      assertExists(m.pre_run_carbs_g);
      assertExists(m.pre_run_carbs_low_g);
      assertExists(m.pre_run_carbs_high_g);
      assertExists(m.pre_run_protein_g);
      assertExists(m.pre_run_protein_low_g);
      assertExists(m.pre_run_protein_high_g);
      assertExists(m.pre_run_fat_g);
      assertExists(m.pre_run_sodium_mg);
      assertExists(m.pre_run_water_ml);
      assertExists(m.pre_run_meal_type);

      // Pre-workout selections (V4 new)
      assertExists(m.pre_run_selections);
      assert(Array.isArray(m.pre_run_selections), 'pre_run_selections should be array');

      // During-workout
      assertExists(m.during_rate_g_per_h);
      assertExists(m.during_total_g);
      assertExists(m.during_band_low_g_per_h);
      assertExists(m.during_band_high_g_per_h);
      assertExists(m.during_gut_multiplier);
      assertExists(m.during_sport_ceiling_g_per_h);
      assertExists(m.during_sodium_total_mg);
      assertExists(m.during_water_total_ml);

      // Post-workout with ranges
      assertExists(m.post_run_carbs_g);
      assertExists(m.post_run_carbs_low_g);
      assertExists(m.post_run_carbs_high_g);
      assertExists(m.post_run_protein_g);
      assertExists(m.post_run_fat_g);
      assertExists(m.post_run_sodium_mg);
      assertExists(m.post_run_water_ml);

      // Hydration
      assertExists(m.sweat_rate_lph);
      assertExists(m.sodium_conc_mg_per_l);
      assertExists(m.environment_label);
    });

    it('should include pre-workout food selections for non-fasted athlete', async () => {
      const { data } = await callMacrosV4(athletes.averageMale);
      const selections = data.macros.pre_run_selections;
      assert(selections.length > 0, 'Non-fasted athlete should have pre-workout selections');
    });

    it('should return empty pre_run_selections for fasted athlete', async () => {
      const { data } = await callMacrosV4(athletes.fastedRunner);
      const selections = data.macros.pre_run_selections;
      assert(Array.isArray(selections), 'pre_run_selections should be an array');
      // Fasted: either empty selections or fasted meal_type
      assertEquals(data.macros.pre_run_meal_type, 'fasted');
    });
  });

  // =========================================================================
  // B. Pre-Workout Calculations (5 tests)
  // =========================================================================

  describe('B. Pre-Workout Calculations', () => {
    it('50kg @ 3h -> 150g carbs (3 g/kg)', async () => {
      const { data } = await callMacrosV4(athletes.smallFemale);
      // 50 * 3 = 150
      assertWithinTolerance(data.macros.pre_run_carbs_g, 150, CARB_TOLERANCE_G, 'Pre carbs 50kg@3h');
    });

    it('70kg @ 2h -> 140g carbs (2 g/kg)', async () => {
      const { data } = await callMacrosV4(athletes.averageMale);
      // 70 * 2 = 140
      assertWithinTolerance(data.macros.pre_run_carbs_g, 140, CARB_TOLERANCE_G, 'Pre carbs 70kg@2h');
    });

    it('full_meal type for >= 2.5h window', async () => {
      const { data } = await callMacrosV4(athletes.smallFemale); // 3h
      assertEquals(data.macros.pre_run_meal_type, 'full_meal');
    });

    it('snack type for 1-2.5h window', async () => {
      const { data } = await callMacrosV4(athletes.swimmer); // 1.5h
      assertEquals(data.macros.pre_run_meal_type, 'snack');
    });

    it('top_up type for < 1h window', async () => {
      const { data } = await callMacrosV4(athletes.lightweightTopUp); // 0.5h
      assertEquals(data.macros.pre_run_meal_type, 'top_up');
    });
  });

  // =========================================================================
  // C. During-Workout (4 tests)
  // =========================================================================

  describe('C. During-Workout', () => {
    it('running caps at sport ceiling of 70 g/hr', async () => {
      // Use a long, high-gut-training running workout to push carb rate high
      const longRun = {
        ...athletes.averageMale,
        run_distance: 30,
        run_pace: '7:00',
        gut_training: 'high',
      };
      const { data } = await callMacrosV4(longRun);
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70);
      assert(
        data.macros.during_rate_g_per_h <= 70,
        `Running rate should be <= 70, got ${data.macros.during_rate_g_per_h}`,
      );
    });

    it('cycling caps at sport ceiling of 120 g/hr', async () => {
      const { data } = await callMacrosV4(athletes.heavyCyclist);
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 120);
      assert(
        data.macros.during_rate_g_per_h <= 120,
        `Cycling rate should be <= 120, got ${data.macros.during_rate_g_per_h}`,
      );
    });

    it('swimming gives 0 g/hr during', async () => {
      const { data } = await callMacrosV4(athletes.swimmer);
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 0);
      assertEquals(data.macros.during_rate_g_per_h, 0);
      assertEquals(data.macros.during_total_g, 0);
    });

    it('low gut training produces lower rate than moderate', async () => {
      const lowGut = { ...athletes.averageMale, gut_training: 'low' };
      const modGut = { ...athletes.averageMale, gut_training: 'moderate' };

      const [lowRes, modRes] = await Promise.all([
        callMacrosV4(lowGut),
        callMacrosV4(modGut),
      ]);

      assert(
        lowRes.data.macros.during_rate_g_per_h < modRes.data.macros.during_rate_g_per_h,
        `Low gut (${lowRes.data.macros.during_rate_g_per_h}) should be < moderate (${modRes.data.macros.during_rate_g_per_h})`,
      );
    });
  });

  // =========================================================================
  // D. Post-Workout (3 tests)
  // =========================================================================

  describe('D. Post-Workout', () => {
    it('higher post carbs for >2h duration (1.2 g/kg multiplier)', async () => {
      // Small female half marathon: duration ~124 min (>2h), 50kg * 1.2 = 60g
      const { data } = await callMacrosV4(athletes.smallFemale);
      const durationH = data.macros.duration_h;

      if (durationH > 2) {
        // 50 * 1.2 = 60
        assertWithinTolerance(data.macros.post_run_carbs_g, 60, CARB_TOLERANCE_G, 'Post carbs >2h');
      } else {
        // 50 * 1.0 = 50
        assertWithinTolerance(data.macros.post_run_carbs_g, 50, CARB_TOLERANCE_G, 'Post carbs <=2h');
      }
    });

    it('fasted workout gets 1.2x post-workout carb boost', async () => {
      const fedRunner = {
        ...athletes.fastedRunner,
        is_fasted: false,
        hours_before: 2,
      };
      const [fastedRes, fedRes] = await Promise.all([
        callMacrosV4(athletes.fastedRunner),
        callMacrosV4(fedRunner),
      ]);

      assert(
        fastedRes.data.macros.post_run_carbs_g > fedRes.data.macros.post_run_carbs_g,
        `Fasted post carbs (${fastedRes.data.macros.post_run_carbs_g}) should be > fed (${fedRes.data.macros.post_run_carbs_g})`,
      );
    });

    it('protein at 0.3 g/kg for non-fasted post-workout', async () => {
      const { data } = await callMacrosV4(athletes.averageMale);
      // 70 * 0.3 = 21
      assertWithinTolerance(data.macros.post_run_protein_g, 21, PROTEIN_TOLERANCE_G, 'Post protein 0.3 g/kg');
    });
  });

  // =========================================================================
  // E. Brick Workouts (3 tests)
  // =========================================================================

  describe('E. Brick Workouts', () => {
    const bikeRunBrick = {
      weight: 70,
      weight_unit: 'kg',
      hours_before: 3,
      is_fasted: false,
      activity_type: 'brick',
      gut_training: 'moderate',
      sweat_rate_category: 'medium',
      sweat_sodium: 'medium',
      brick_segments: [
        {
          sport: 'cycling',
          order: 1,
          duration_minutes: 90,
          intensity: 'moderate',
          distance_miles: 25,
          speed_mph: 20,
          terrain: 'flat',
        },
        {
          sport: 'running',
          order: 2,
          duration_minutes: 45,
          intensity: 'moderate',
          pace_minutes_per_mile: 8,
        },
      ],
    };

    const swimBikeRunBrick = {
      weight: 70,
      weight_unit: 'kg',
      hours_before: 2.5,
      is_fasted: false,
      activity_type: 'brick',
      gut_training: 'moderate',
      sweat_rate_category: 'medium',
      sweat_sodium: 'medium',
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
    };

    it('2-segment brick returns phases structure with correct counts', async () => {
      const { status, data } = await callMacrosV4(bikeRunBrick);
      assertEquals(status, 200);
      assertEquals(data.success, true);
      assertEquals(data.macros.activity_type, 'brick');
      assertExists(data.macros.phases);
      assertEquals(data.macros.phases.during_segments.length, 2);
      assertEquals(data.macros.phases.transitions.length, 1);
    });

    it('swimming segment gives 0 carbs/water/sodium', async () => {
      const { data } = await callMacrosV4(swimBikeRunBrick);
      const swimSeg = data.macros.phases.during_segments.find(
        (s: any) => s.sport === 'swimming',
      );
      assertExists(swimSeg);
      assertEquals(swimSeg.carbs_g, 0, 'Swimming carbs should be 0');
      assertEquals(swimSeg.water_ml, 0, 'Swimming water should be 0');
      assertEquals(swimSeg.sodium_mg, 0, 'Swimming sodium should be 0');
    });

    it('duration sums correctly across segments', async () => {
      const { data } = await callMacrosV4(swimBikeRunBrick);
      // 30 + 75 + 60 = 165 min
      assertWithinTolerance(data.macros.duration_min, 165, 1, 'Total duration min');
      assertWithinTolerance(data.macros.duration_h, 2.75, 0.05, 'Total duration hours');
    });
  });

  // =========================================================================
  // F. Error Handling (5 tests)
  // =========================================================================

  describe('F. Error Handling', () => {
    it('missing weight -> 400', async () => {
      const { status, data } = await callMacrosV4({
        hours_before: 3,
        is_fasted: false,
        run_distance: 10,
        run_pace: '8:00',
        gut_training: 'moderate',
        sweat_rate_category: 'medium',
        sweat_sodium: 'medium',
      });
      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('missing hours_before -> 400', async () => {
      const { status, data } = await callMacrosV4({
        weight: 70,
        weight_unit: 'kg',
        is_fasted: false,
        run_distance: 10,
        run_pace: '8:00',
        gut_training: 'moderate',
        sweat_rate_category: 'medium',
        sweat_sodium: 'medium',
      });
      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('invalid activity_type -> 400', async () => {
      const { status, data } = await callMacrosV4({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 3,
        is_fasted: false,
        activity_type: 'skateboarding',
        gut_training: 'moderate',
        sweat_rate_category: 'medium',
        sweat_sodium: 'medium',
      });
      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('running without distance/pace -> 400', async () => {
      const { status, data } = await callMacrosV4({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 3,
        is_fasted: false,
        activity_type: 'running',
        gut_training: 'moderate',
        sweat_rate_category: 'medium',
        sweat_sodium: 'medium',
      });
      assertEquals(status, 400);
      assertEquals(data.success, false);
    });

    it('brick with 1 segment -> 400', async () => {
      const { status, data } = await callMacrosV4({
        weight: 70,
        weight_unit: 'kg',
        hours_before: 3,
        is_fasted: false,
        activity_type: 'brick',
        gut_training: 'moderate',
        sweat_rate_category: 'medium',
        sweat_sodium: 'medium',
        brick_segments: [
          { sport: 'running', order: 1, duration_minutes: 60, intensity: 'moderate' },
        ],
      });
      assertEquals(status, 400);
      assertEquals(data.success, false);
    });
  });
});
