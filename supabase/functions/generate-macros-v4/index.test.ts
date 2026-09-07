/**
 * Integration Tests for generate-macros-v4 Edge Function
 *
 * Tests validate Algorithm C "Comfort-Capped Hybrid" with:
 * - Range-based pre-workout targets with food selections
 * - V3 during-workout (duration bands, gut multipliers, sport ceilings)
 * - V3 post-workout (duration/fasted multipliers)
 * - Brick workout multi-segment calculations
 * - Formula validation with ±5% tolerance
 * - Sport ceiling enforcement
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

const PERCENT_TOLERANCE = 0.05; // ±5%

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

function assertWithinPercent(
  actual: number,
  expected: number,
  pct: number,
  label: string,
): void {
  const tolerance = expected * pct;
  const diff = Math.abs(actual - expected);
  assert(
    diff <= tolerance,
    `${label}: expected ${expected} (±${(pct * 100).toFixed(1)}%), got ${actual} (diff: ${diff.toFixed(2)}, tolerance: ${tolerance.toFixed(2)})`,
  );
}

function assertInRange(actual: number, min: number, max: number, label: string): void {
  assert(
    actual >= min && actual <= max,
    `${label}: expected [${min}, ${max}], got ${actual}`,
  );
}

// ============================================================================
// Athlete Profiles (26 diverse)
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

  /** Profile 7: Very light female — 45kg, 5K, low gut, cool temp */
  veryLight45kg: {
    weight: 45,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    run_distance: 5,
    run_distance_unit: 'km',
    run_pace: '6:00',
    gut_training: 'low',
    sweat_rate_category: 'light',
    sweat_sodium: 'low',
    temp_c: 15,
    humidity_pct: 40,
  },

  /** Profile 8: Very heavy male — 110kg, marathon, high gut, hot */
  veryHeavy110kg: {
    weight: 110,
    weight_unit: 'kg',
    hours_before: 3.5,
    is_fasted: false,
    run_distance: 42.2,
    run_distance_unit: 'km',
    run_pace: '5:30',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 35,
    humidity_pct: 80,
  },

  /** Profile 9: Ultra runner — 75kg, 50mi, high gut, variable temp */
  ultraRunner75kg: {
    weight: 75,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 50,
    run_distance_unit: 'mi',
    run_pace: '10:00',
    gut_training: 'high',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
    temp_c: 22,
    humidity_pct: 60,
  },

  /** Profile 10: Light male — 55kg, 10K, low gut, cool */
  lightMale55kg: {
    weight: 55,
    weight_unit: 'kg',
    hours_before: 1.5,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'km',
    run_pace: '4:30',
    gut_training: 'low',
    sweat_rate_category: 'light',
    sweat_sodium: 'low',
    temp_c: 12,
    humidity_pct: 50,
  },

  /** Profile 11: Average female — 60kg, half marathon, moderate gut, mild */
  avgFemale60kg: {
    weight: 60,
    weight_unit: 'kg',
    hours_before: 2.5,
    is_fasted: false,
    run_distance: 21.1,
    run_distance_unit: 'km',
    run_pace: '5:45',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
    temp_c: 20,
    humidity_pct: 55,
  },

  /** Profile 12: Fasted long run — 70kg, marathon, fasted, moderate gut */
  fastedLong: {
    weight: 70,
    weight_unit: 'kg',
    hours_before: 0,
    is_fasted: true,
    run_distance: 42.2,
    run_distance_unit: 'km',
    run_pace: '5:00',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
    temp_c: 18,
    humidity_pct: 50,
  },

  /** Profile 13: Sprint triathlete — 65kg, brick workout */
  sprintTriathlete: {
    weight: 65,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    activity_type: 'brick',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
    temp_c: 24,
    humidity_pct: 60,
    brick_segments: [
      {
        sport: 'swimming',
        order: 1,
        duration_minutes: 15,
        intensity: 'moderate',
        distance_meters: 750,
        pace_per_100m_seconds: 120,
        pool_or_open_water: 'open_water',
        water_temp_c: 20,
      },
      {
        sport: 'cycling',
        order: 2,
        duration_minutes: 40,
        intensity: 'moderate',
        distance_miles: 12.4,
        speed_mph: 18,
        terrain: 'flat',
      },
      {
        sport: 'running',
        order: 3,
        duration_minutes: 25,
        intensity: 'moderate',
        pace_minutes_per_mile: 8,
      },
    ],
  },

  /** Profile 14: Ironman triathlete — 80kg, full distance brick */
  ironmanTriathlete: {
    weight: 80,
    weight_unit: 'kg',
    hours_before: 3.5,
    is_fasted: false,
    activity_type: 'brick',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 28,
    humidity_pct: 70,
    brick_segments: [
      {
        sport: 'swimming',
        order: 1,
        duration_minutes: 60,
        intensity: 'moderate',
        distance_meters: 3800,
        pace_per_100m_seconds: 95,
        pool_or_open_water: 'open_water',
        water_temp_c: 22,
      },
      {
        sport: 'cycling',
        order: 2,
        duration_minutes: 300,
        intensity: 'moderate',
        distance_miles: 112,
        speed_mph: 22,
        terrain: 'flat',
      },
      {
        sport: 'running',
        order: 3,
        duration_minutes: 210,
        intensity: 'moderate',
        pace_minutes_per_mile: 8,
      },
    ],
  },

  /** Profile 15: Hot heavy runner — 95kg, 15mi, high gut, hot */
  hotHeavy95kg: {
    weight: 95,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 15,
    run_distance_unit: 'mi',
    run_pace: '8:30',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 35,
    humidity_pct: 80,
  },

  /** Profile 16: Cold light runner — 52kg, 10mi, low gut, cold */
  coldLight52kg: {
    weight: 52,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '9:00',
    gut_training: 'low',
    sweat_rate_category: 'light',
    sweat_sodium: 'low',
    temp_c: 2,
    humidity_pct: 30,
  },

  /** Profile 17: Moderate cyclist — 75kg, 40mi, moderate gut, mild */
  moderateCyclist75kg: {
    weight: 75,
    weight_unit: 'kg',
    hours_before: 2.5,
    is_fasted: false,
    activity_type: 'cycling',
    distance_miles: 40,
    speed_mph: 18,
    terrain: 'rolling',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
    temp_c: 22,
    humidity_pct: 55,
  },

  /** Profile 18: Heavy cyclist long — 100kg, 100mi, high gut, warm */
  heavyCyclist100kg: {
    weight: 100,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    activity_type: 'cycling',
    distance_miles: 100,
    speed_mph: 20,
    terrain: 'rolling',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 28,
    humidity_pct: 65,
  },

  /** Profile 19: Short swimmer — 68kg, 1500m pool, moderate gut */
  shortSwimmer68kg: {
    weight: 68,
    weight_unit: 'kg',
    hours_before: 1.5,
    is_fasted: false,
    activity_type: 'swimming',
    distance_meters: 1500,
    pace_per_100m_seconds: 110,
    pool_or_open_water: 'pool',
    water_temp_c: 27,
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  /** Profile 20: Long swimmer — 78kg, 5000m open water, high gut */
  longSwimmer78kg: {
    weight: 78,
    weight_unit: 'kg',
    hours_before: 2.5,
    is_fasted: false,
    activity_type: 'swimming',
    distance_meters: 5000,
    pace_per_100m_seconds: 100,
    pool_or_open_water: 'open_water',
    water_temp_c: 20,
    gut_training: 'high',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  /** Profile 21: Top-up short window — 60kg, 0.3h before, 10mi, low gut */
  topUpShort: {
    weight: 60,
    weight_unit: 'kg',
    hours_before: 0.3,
    is_fasted: false,
    run_distance: 10,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'low',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },

  /** Profile 22: Meal long window (capped at 4h) — 85kg, 4h before, marathon, high gut */
  mealLong: {
    weight: 85,
    weight_unit: 'kg',
    hours_before: 4,
    is_fasted: false,
    run_distance: 42.2,
    run_distance_unit: 'km',
    run_pace: '5:00',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
  },

  /** Profile 23: Short 5K run — 65kg, easy pace, low gut, cool */
  shortRun5K: {
    weight: 65,
    weight_unit: 'kg',
    hours_before: 1.5,
    is_fasted: false,
    run_distance: 5,
    run_distance_unit: 'km',
    run_pace: '6:00',
    gut_training: 'low',
    sweat_rate_category: 'light',
    sweat_sodium: 'low',
    temp_c: 15,
    humidity_pct: 45,
  },

  /** Profile 24: Medium 15K run — 72kg, moderate gut, mild */
  mediumRun15K: {
    weight: 72,
    weight_unit: 'kg',
    hours_before: 2,
    is_fasted: false,
    run_distance: 15,
    run_distance_unit: 'km',
    run_pace: '5:15',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
    temp_c: 20,
    humidity_pct: 55,
  },

  /** Profile 25: Long 20mi run — 78kg, high gut, warm */
  longRun20mi: {
    weight: 78,
    weight_unit: 'kg',
    hours_before: 3,
    is_fasted: false,
    run_distance: 20,
    run_distance_unit: 'mi',
    run_pace: '8:00',
    gut_training: 'high',
    sweat_rate_category: 'heavy',
    sweat_sodium: 'high',
    temp_c: 25,
    humidity_pct: 65,
  },

  /** Profile 26: Heavy fasted short — 88kg, 8mi, fasted */
  heavyFastedShort: {
    weight: 88,
    weight_unit: 'kg',
    hours_before: 0,
    is_fasted: true,
    run_distance: 8,
    run_distance_unit: 'mi',
    run_pace: '7:45',
    gut_training: 'moderate',
    sweat_rate_category: 'medium',
    sweat_sodium: 'medium',
  },
};

// ============================================================================
// Tests
// ============================================================================

describe('generate-macros-v4 Integration Tests', () => {
  beforeAll(() => {
    if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
      throw new Error('Missing SUPABASE_URL or SUPABASE_ANON_KEY environment variables');
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
      // Sodium v3: pre-workout sodium is STRICT NULL on the wire — a number
      // here would be the regression (the overlay suite pins the same).
      assertEquals(m.pre_run_sodium_mg, null);
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

    it('is_fasted is tolerated and IGNORED (fasted retired, D-001)', async () => {
      // food-recommendation §7: the fasted state is retired; the wire field
      // is accepted and dropped. t = 0 yields top_up meal_type like any fed
      // request at that window — never the retired 'fasted' value.
      const { data } = await callMacrosV4(athletes.fastedRunner);
      const selections = data.macros.pre_run_selections;
      assert(Array.isArray(selections), 'pre_run_selections should be an array');
      assertEquals(data.macros.pre_run_meal_type, 'top_up');
    });
  });

  // =========================================================================
  // B. Pre-Workout Calculations (5 tests with ±5% tolerance)
  // =========================================================================

  describe('B. Pre-Workout Calculations', () => {
    it('50kg @ 3h -> 150g carbs (3 g/kg) ±5%', async () => {
      const { data } = await callMacrosV4(athletes.smallFemale);
      // 50 * 3 = 150
      assertWithinPercent(data.macros.pre_run_carbs_g, 150, PERCENT_TOLERANCE, 'Pre carbs 50kg@3h');
    });

    it('70kg @ 2h -> 140g carbs (2 g/kg) ±5%', async () => {
      const { data } = await callMacrosV4(athletes.averageMale);
      // 70 * 2 = 140
      assertWithinPercent(data.macros.pre_run_carbs_g, 140, PERCENT_TOLERANCE, 'Pre carbs 70kg@2h');
    });

    it('full_meal type for >= 2.5h window', async () => {
      const { data } = await callMacrosV4(athletes.smallFemale); // 3h
      assertEquals(data.macros.pre_run_meal_type, 'full_meal');
    });

    it('snack type for 1-2.5h window', async () => {
      const { data } = await callMacrosV4(athletes.swimmer); // 1.5h
      assertEquals(data.macros.pre_run_meal_type, 'snack');
    });

    it('snack type at exactly 0.5h (snack tier is inclusive at >= 30 min)', async () => {
      // Ratified tier thresholds (carbs v2): snack activates at window
      // >= 30 min inclusive; top_up-only is the < 30 min regime.
      const { data } = await callMacrosV4(athletes.lightweightTopUp); // 0.5h
      assertEquals(data.macros.pre_run_meal_type, 'snack');
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
  // D. Post-Workout (3 tests with ±5% tolerance)
  // =========================================================================

  describe('D. Post-Workout', () => {
    it('higher post carbs for >2h duration (1.2 g/kg multiplier) ±5%', async () => {
      // Small female half marathon: duration ~124 min (>2h), 50kg * 1.2 = 60g
      const { data } = await callMacrosV4(athletes.smallFemale);
      const durationH = data.macros.duration_h;

      if (durationH > 2) {
        // 50 * 1.2 = 60
        assertWithinPercent(data.macros.post_run_carbs_g, 60, PERCENT_TOLERANCE, 'Post carbs >2h');
      } else {
        // 50 * 1.0 = 50
        assertWithinPercent(data.macros.post_run_carbs_g, 50, PERCENT_TOLERANCE, 'Post carbs <=2h');
      }
    });

    it('is_fasted no longer boosts post-workout carbs (fasted retired, D-001)', async () => {
      // The 1.2x fasted post-boost went with the fasted branches. Same
      // athlete ± the flag must produce IDENTICAL post targets.
      const fedRunner = {
        ...athletes.fastedRunner,
        is_fasted: false,
      };
      const [fastedRes, fedRes] = await Promise.all([
        callMacrosV4(athletes.fastedRunner),
        callMacrosV4(fedRunner),
      ]);

      assertEquals(
        fastedRes.data.macros.post_run_carbs_g,
        fedRes.data.macros.post_run_carbs_g,
        'is_fasted must not change post carbs',
      );
    });

    it('protein at 0.3 g/kg for non-fasted post-workout ±5%', async () => {
      const { data } = await callMacrosV4(athletes.averageMale);
      // 70 * 0.3 = 21
      assertWithinPercent(data.macros.post_run_protein_g, 21, PERCENT_TOLERANCE, 'Post protein 0.3 g/kg');
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

    it('duration sums correctly across segments ±5%', async () => {
      const { data } = await callMacrosV4(swimBikeRunBrick);
      // 30 + 75 + 60 = 165 min
      assertWithinPercent(data.macros.duration_min, 165, PERCENT_TOLERANCE, 'Total duration min');
      assertWithinPercent(data.macros.duration_h, 2.75, PERCENT_TOLERANCE, 'Total duration hours');
    });

    it('top-level during_carb_rate_g_per_h override applies to all non-swim brick segments', async () => {
      const payload = {
        weight: 70,
        weight_unit: 'kg',
        hours_before: 2,
        is_fasted: false,
        activity_type: 'brick',
        gut_training: 'high',
        sweat_rate_category: 'medium',
        sweat_sodium: 'medium',
        overrides: {
          during_carb_rate_g_per_h: 120,
        },
        brick_segments: [
          {
            sport: 'cycling',
            order: 1,
            duration_minutes: 180,
            intensity: 'moderate',
            distance_miles: 54,
            speed_mph: 18,
            terrain: 'flat',
          },
          {
            sport: 'running',
            order: 2,
            duration_minutes: 120,
            intensity: 'moderate',
            pace_minutes_per_mile: 9.2,
          },
        ],
      };

      const { status, data } = await callMacrosV4(payload);
      assertEquals(status, 200);
      assertEquals(data.success, true);

      const bikeSeg = data.macros.phases.during_segments.find((s: any) => s.sport === 'cycling');
      const runSeg = data.macros.phases.during_segments.find((s: any) => s.sport === 'running');
      assertExists(bikeSeg);
      assertExists(runSeg);

      assertEquals(bikeSeg.carbs_rate_g_per_h, 120);
      assertEquals(runSeg.carbs_rate_g_per_h, 120);
      assertEquals(bikeSeg.carbs_g, 360); // 120 g/h * 3 h
      assertEquals(runSeg.carbs_g, 240); // 120 g/h * 2 h
    });

    it('segment override_carb_rate_g_per_h supports per-segment brick targets and takes precedence', async () => {
      const payload = {
        weight: 70,
        weight_unit: 'kg',
        hours_before: 2,
        is_fasted: false,
        activity_type: 'brick',
        gut_training: 'high',
        sweat_rate_category: 'medium',
        sweat_sodium: 'medium',
        overrides: {
          during_carb_rate_g_per_h: 90,
          cycling_carb_rate_g_per_h: 110,
          running_carb_rate_g_per_h: 45,
        },
        brick_segments: [
          {
            sport: 'cycling',
            order: 1,
            duration_minutes: 180,
            intensity: 'moderate',
            override_carb_rate_g_per_h: 120,
            distance_miles: 54,
            speed_mph: 18,
            terrain: 'flat',
          },
          {
            sport: 'running',
            order: 2,
            duration_minutes: 120,
            intensity: 'moderate',
            override_carb_rate_g_per_h: 30,
            pace_minutes_per_mile: 9.2,
          },
        ],
      };

      const { status, data } = await callMacrosV4(payload);
      assertEquals(status, 200);
      assertEquals(data.success, true);

      const bikeSeg = data.macros.phases.during_segments.find((s: any) => s.sport === 'cycling');
      const runSeg = data.macros.phases.during_segments.find((s: any) => s.sport === 'running');
      assertExists(bikeSeg);
      assertExists(runSeg);

      // Segment-level overrides should win over sport-specific and global overrides.
      assertEquals(bikeSeg.carbs_rate_g_per_h, 120);
      assertEquals(runSeg.carbs_rate_g_per_h, 30);
      assertEquals(bikeSeg.carbs_g, 360); // 120 g/h * 3 h
      assertEquals(runSeg.carbs_g, 60); // 30 g/h * 2 h
    });

    // Regression test: 1500m swim + 20mi bike + 3mi run (2h4m total)
    // Validates cumulative_duration_min, per-segment carbs, and brick penalty
    it('swim-bike-run 2h4m brick: cumulative times and per-segment carbs are accurate', async () => {
      const payload = {
        weight: 165,
        weight_unit: 'lbs',
        hours_before: 2,
        is_fasted: false,
        activity_type: 'brick',
        gut_training: 'low',
        sweat_rate_category: 'medium',
        sweat_sodium_category: 'average',
        brick_segments: [
          {
            sport: 'swimming',
            order: 1,
            duration_minutes: 30,
            distance_meters: 1500,
          },
          {
            sport: 'cycling',
            order: 2,
            duration_minutes: 67,
            distance_miles: 20,
            speed_mph: 18,
          },
          {
            sport: 'running',
            order: 3,
            duration_minutes: 27,
            distance_miles: 3.0,
            pace_minutes_per_mile: 9,
          },
        ],
      };

      const { status, data } = await callMacrosV4(payload);
      assertEquals(status, 200);
      assertEquals(data.success, true);

      const phases = data.macros.phases;
      assertExists(phases.during_segments);
      assertEquals(phases.during_segments.length, 3, 'Should have 3 during segments');
      assertEquals(phases.transitions.length, 2, 'Should have 2 transitions');

      // Total duration
      assertEquals(data.macros.duration_min, 124, 'Total duration = 30+67+27 = 124 min');

      // --- Segment 1: Swim ---
      const swim = phases.during_segments[0];
      assertEquals(swim.sport, 'swimming');
      assertEquals(swim.duration_minutes, 30);
      assertEquals(swim.carbs_g, 0, 'Swim carbs = 0');
      assertEquals(swim.carbs_low_g, 0, 'Swim carbs_low = 0');
      assertEquals(swim.carbs_high_g, 0, 'Swim carbs_high = 0');
      assertEquals(swim.cumulative_duration_min, 30, 'Swim cumulative = 30');

      // --- Segment 2: Bike ---
      const bike = phases.during_segments[1];
      assertEquals(bike.sport, 'cycling');
      assertEquals(bike.duration_minutes, 67);
      assertEquals(bike.cumulative_duration_min, 97, 'Bike cumulative = 30+67 = 97');
      assertEquals(bike.brick_penalty, 1, 'No brick penalty for cycling');

      // Band lookup uses totalDurationMin=124 → [45,60] g/hr
      assertEquals(bike.raw_band_low_g_per_h, 45, 'Bike raw band low = 45');
      assertEquals(bike.raw_band_high_g_per_h, 60, 'Bike raw band high = 60');

      // Gut training = low → multiplier 0.7
      assertEquals(bike.gut_multiplier, 0.7, 'Low gut training = 0.7');
      // Scaled band: [45*0.7, 60*0.7] = [31.5, 42] → rounded [31, 42]
      assertInRange(bike.scaled_band_low_g_per_h, 31, 32, 'Bike scaled low');
      assertInRange(bike.scaled_band_high_g_per_h, 42, 42, 'Bike scaled high');

      // Sport ceiling for cycling = 120 g/hr
      assertEquals(bike.sport_ceiling_g_per_h, 120, 'Cycling ceiling = 120');

      // Midpoint = (31.5+42)/2 ≈ 36.75 → rate ≈ 36.8 g/hr (no cap, no penalty)
      // carbs_g = round(36.75 * 67/60) = round(41.0) = 41
      assertInRange(bike.carbs_g, 39, 43, 'Bike carbs ≈ 41g');

      // Per-segment carb ranges: band_low * penalty * durationH to band_high * penalty * durationH
      // Bike: round(31.5 * 1.0 * 67/60) = round(35.2) = 35
      // Bike: round(42 * 1.0 * 67/60) = round(46.9) = 47
      assertInRange(bike.carbs_low_g, 33, 37, 'Bike carbs_low ≈ 35g');
      assertInRange(bike.carbs_high_g, 45, 49, 'Bike carbs_high ≈ 47g');

      // --- Segment 3: Run ---
      const run = phases.during_segments[2];
      assertEquals(run.sport, 'running');
      assertEquals(run.duration_minutes, 27);
      assertEquals(run.cumulative_duration_min, 124, 'Run cumulative = 30+67+27 = 124');
      assertEquals(run.brick_penalty, 0.8, 'Run-after-bike penalty = 0.8');

      // Same band [45,60] scaled by 0.7 → [31.5, 42], midpoint 36.75
      // After brick penalty: 36.75 * 0.8 = 29.4 g/hr
      // carbs_g = round(29.4 * 27/60) = round(13.2) = 13
      assertInRange(run.carbs_g, 12, 15, 'Run carbs ≈ 13g (with 0.8 brick penalty)');

      // Per-segment carb ranges with brick penalty:
      // Run: round(31.5 * 0.8 * 27/60) = round(11.3) = 11
      // Run: round(42 * 0.8 * 27/60) = round(15.1) = 15
      assertInRange(run.carbs_low_g, 10, 13, 'Run carbs_low ≈ 11g');
      assertInRange(run.carbs_high_g, 14, 17, 'Run carbs_high ≈ 15g');

      // Running sport ceiling = 70
      assertEquals(run.sport_ceiling_g_per_h, 70, 'Running ceiling = 70');

      // Verify per-segment carbs are NOT equal (the bug was showing same target for both)
      assert(
        bike.carbs_g !== run.carbs_g,
        `Bike (${bike.carbs_g}g) and run (${run.carbs_g}g) should have different carb targets`,
      );

      // Verify total during carbs = swim + bike + run
      const totalDuringCarbs = swim.carbs_g + bike.carbs_g + run.carbs_g;
      assertInRange(totalDuringCarbs, 50, 60, 'Total during carbs ≈ 0+41+13 = 54g');
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

  // =========================================================================
  // G. Formula Validation (26+ tests with ±5% tolerance)
  // =========================================================================

  describe('G. Formula Validation', () => {
    it('veryLight45kg: pre carbs = 45 * min(2, 4) = 90g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.veryLight45kg);
      const expected = 45 * Math.min(2, 4); // 90
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'veryLight45kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('veryHeavy110kg: pre carbs = 110 * min(3.5, 4) = 385g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.veryHeavy110kg);
      const expected = 110 * Math.min(3.5, 4); // 385
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'veryHeavy110kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('ultraRunner75kg: pre carbs = 75 * min(3, 4) = 225g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.ultraRunner75kg);
      const expected = 75 * Math.min(3, 4); // 225
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'ultraRunner75kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');

      // Post: duration > 2h, not fasted: 75 * 1.2 * 1.0 = 90g
      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const fastedMult = 1.0; // not fasted
      const expectedPost = 75 * durationMult * fastedMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'Post carbs');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('lightMale55kg: pre carbs = 55 * min(1.5, 4) = 82.5g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.lightMale55kg);
      const expected = 55 * Math.min(1.5, 4); // 82.5
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'lightMale55kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('avgFemale60kg: pre carbs = 60 * min(2.5, 4) = 150g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.avgFemale60kg);
      const expected = 60 * Math.min(2.5, 4); // 150
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'avgFemale60kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');

      // Post: duration > 2h, not fasted: 60 * 1.2 * 1.0 = 72g
      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const fastedMult = 1.0;
      const expectedPost = 60 * durationMult * fastedMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'Post carbs');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('fastedLong: is_fasted ignored (D-001) — t=0 top_up, post carbs = 70 * durationMult ±5%', async () => {
      const { data } = await callMacrosV4(athletes.fastedLong);
      assertEquals(data.macros.pre_run_meal_type, 'top_up');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');

      // Post: duration > 2h: 70 * 1.2 (the fasted 1.2x boost is retired).
      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const expectedPost = 70 * durationMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'Fasted post carbs');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('sprintTriathlete: brick with swim=0, cycling=120, running=70 ceilings', async () => {
      const { data } = await callMacrosV4(athletes.sprintTriathlete);
      const phases = data.macros.phases;

      const swimSeg = phases.during_segments.find((s: any) => s.sport === 'swimming');
      const bikeSeg = phases.during_segments.find((s: any) => s.sport === 'cycling');
      const runSeg = phases.during_segments.find((s: any) => s.sport === 'running');

      assertExists(swimSeg);
      assertExists(bikeSeg);
      assertExists(runSeg);

      assertEquals(swimSeg.carbs_g, 0, 'Swim carbs = 0');
      // Compute rate from carbs_g / duration_h (carbs_rate_g_per_h may not be present yet)
      const bikeRateGph = bikeSeg.carbs_rate_g_per_h ?? (bikeSeg.carbs_g / (bikeSeg.duration_minutes / 60));
      const runRateGph = runSeg.carbs_rate_g_per_h ?? (runSeg.carbs_g / (runSeg.duration_minutes / 60));
      assert(bikeRateGph <= 120, `Bike rate <= 120, got ${bikeRateGph}`);
      assert(runRateGph <= 70, `Run rate <= 70, got ${runRateGph}`);

      // Pre carbs: 65 * min(2, 4) = 130g (brick uses phases.before.carbs_g)
      assertWithinPercent(phases.before.carbs_g, 130, PERCENT_TOLERANCE, 'Sprint tri pre carbs');
      assertInRange(phases.after.protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('ironmanTriathlete: brick with swim=0, cycling=120, running=70 ceilings', async () => {
      const { data } = await callMacrosV4(athletes.ironmanTriathlete);
      const phases = data.macros.phases;

      const swimSeg = phases.during_segments.find((s: any) => s.sport === 'swimming');
      const bikeSeg = phases.during_segments.find((s: any) => s.sport === 'cycling');
      const runSeg = phases.during_segments.find((s: any) => s.sport === 'running');

      assertExists(swimSeg);
      assertExists(bikeSeg);
      assertExists(runSeg);

      assertEquals(swimSeg.carbs_g, 0, 'Swim carbs = 0');
      // Compute rate from carbs_g / duration_h (carbs_rate_g_per_h may not be present yet)
      const bikeRateGph = bikeSeg.carbs_rate_g_per_h ?? (bikeSeg.carbs_g / (bikeSeg.duration_minutes / 60));
      const runRateGph = runSeg.carbs_rate_g_per_h ?? (runSeg.carbs_g / (runSeg.duration_minutes / 60));
      assert(bikeRateGph <= 120, `Bike rate <= 120, got ${bikeRateGph}`);
      assert(runRateGph <= 70, `Run rate <= 70, got ${runRateGph}`);

      // Pre carbs: 80 * min(3.5, 4) = 280g (brick uses phases.before.carbs_g)
      assertWithinPercent(phases.before.carbs_g, 280, PERCENT_TOLERANCE, 'Ironman pre carbs');

      // Post: duration > 2h, not fasted: 80 * 1.2 * 1.0 = 96g (brick uses phases.after.carbs_g)
      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const fastedMult = 1.0;
      const expectedPost = 80 * durationMult * fastedMult;
      assertWithinPercent(phases.after.carbs_g, expectedPost, PERCENT_TOLERANCE, 'Post carbs');
      assertInRange(phases.after.protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('hotHeavy95kg: pre carbs = 95 * min(3, 4) = 285g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.hotHeavy95kg);
      const expected = 95 * Math.min(3, 4); // 285
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'hotHeavy95kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('coldLight52kg: pre carbs = 52 * min(2, 4) = 104g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.coldLight52kg);
      const expected = 52 * Math.min(2, 4); // 104
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'coldLight52kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('moderateCyclist75kg: pre carbs = 75 * min(2.5, 4) = 187.5g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.moderateCyclist75kg);
      const expected = 75 * Math.min(2.5, 4); // 187.5
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'moderateCyclist75kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 120, 'Cycling ceiling');
      assert(data.macros.during_rate_g_per_h <= 120, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('heavyCyclist100kg: pre carbs = 100 * min(3, 4) = 300g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.heavyCyclist100kg);
      const expected = 100 * Math.min(3, 4); // 300
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'heavyCyclist100kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 120, 'Cycling ceiling');
      assert(data.macros.during_rate_g_per_h <= 120, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('shortSwimmer68kg: pre carbs = 68 * min(1.5, 4) = 102g ±5%, during = 0', async () => {
      const { data } = await callMacrosV4(athletes.shortSwimmer68kg);
      const expected = 68 * Math.min(1.5, 4); // 102
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'shortSwimmer68kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 0, 'Swimming ceiling');
      assertEquals(data.macros.during_rate_g_per_h, 0, 'Swimming rate = 0');
      assertEquals(data.macros.during_total_g, 0, 'Swimming total = 0');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('longSwimmer78kg: pre carbs = 78 * min(2.5, 4) = 195g ±5%, during = 0', async () => {
      const { data } = await callMacrosV4(athletes.longSwimmer78kg);
      const expected = 78 * Math.min(2.5, 4); // 195
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'longSwimmer78kg pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 0, 'Swimming ceiling');
      assertEquals(data.macros.during_rate_g_per_h, 0, 'Swimming rate = 0');
      assertEquals(data.macros.during_total_g, 0, 'Swimming total = 0');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('topUpShort: pre carbs = 60 * 0.3 = 18g ±5% (no floor — carbs v2)', async () => {
      // The 0.5 g/kg floor is retired (carbs v2: reintroducing a floor is
      // the regression). Target = t/60 × 1 g/kg × BW, uncapped below 4.
      const { data } = await callMacrosV4(athletes.topUpShort);
      const expected = 60 * Math.min(0.3, 4); // 18
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'topUpShort pre carbs');
      assertEquals(data.macros.pre_run_meal_type, 'top_up');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('mealLong: pre carbs capped at 85 * min(4, 4) = 340g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.mealLong);
      const expected = 85 * Math.min(4, 4); // 340 (capped at 4h)
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'mealLong pre carbs (4h cap)');
      assertEquals(data.macros.pre_run_meal_type, 'full_meal');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');

      // Post: duration > 2h, not fasted: 85 * 1.2 * 1.0 = 102g
      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const fastedMult = 1.0;
      const expectedPost = 85 * durationMult * fastedMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'Post carbs');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('shortRun5K: pre carbs = 65 * min(1.5, 4) = 97.5g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.shortRun5K);
      const expected = 65 * Math.min(1.5, 4); // 97.5
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'shortRun5K pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('mediumRun15K: pre carbs = 72 * min(2, 4) = 144g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.mediumRun15K);
      const expected = 72 * Math.min(2, 4); // 144
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'mediumRun15K pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('longRun20mi: pre carbs = 78 * min(3, 4) = 234g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.longRun20mi);
      const expected = 78 * Math.min(3, 4); // 234
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'longRun20mi pre carbs');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');

      // Post: duration > 2h, not fasted: 78 * 1.2 * 1.0 = 93.6g
      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const fastedMult = 1.0;
      const expectedPost = 78 * durationMult * fastedMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'Post carbs');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('heavyFastedShort: is_fasted ignored (D-001) — post carbs = 88 * durationMult ±5%', async () => {
      const { data } = await callMacrosV4(athletes.heavyFastedShort);
      assertEquals(data.macros.pre_run_meal_type, 'top_up');
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling');
      assert(data.macros.during_rate_g_per_h <= 70, 'Rate <= ceiling');

      // Post: 88 * durationMult (fasted boost retired).
      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const expectedPost = 88 * durationMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'Fasted post carbs');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('smallFemale: post carbs = 50 * durationMult * 1.0 ±5%', async () => {
      const { data } = await callMacrosV4(athletes.smallFemale);
      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const fastedMult = 1.0;
      const expectedPost = 50 * durationMult * fastedMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'smallFemale post carbs');
    });

    it('averageMale: post carbs = 70 * durationMult * 1.0 ±5%', async () => {
      const { data } = await callMacrosV4(athletes.averageMale);
      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const fastedMult = 1.0;
      const expectedPost = 70 * durationMult * fastedMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'averageMale post carbs');
    });

    it('heavyCyclist: cycling ceiling = 120, post carbs = 91 * durationMult * 1.0 ±5%', async () => {
      const { data } = await callMacrosV4(athletes.heavyCyclist);
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 120, 'Cycling ceiling');
      assert(data.macros.during_rate_g_per_h <= 120, 'Rate <= ceiling');

      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const fastedMult = 1.0;
      const expectedPost = 91 * durationMult * fastedMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'heavyCyclist post carbs');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('fastedRunner: is_fasted ignored (D-001) — post carbs = 65 * durationMult ±5%', async () => {
      const { data } = await callMacrosV4(athletes.fastedRunner);
      assertEquals(data.macros.pre_run_meal_type, 'top_up');

      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const expectedPost = 65 * durationMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'fastedRunner post carbs');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('swimmer: swimming ceiling = 0, post carbs = 73 * durationMult * 1.0 ±5%', async () => {
      const { data } = await callMacrosV4(athletes.swimmer);
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 0, 'Swimming ceiling');
      assertEquals(data.macros.during_rate_g_per_h, 0, 'Swimming rate = 0');

      const durationH = data.macros.duration_h;
      const durationMult = durationH > 2 ? 1.2 : 1.0;
      const fastedMult = 1.0;
      const expectedPost = 73 * durationMult * fastedMult;
      assertWithinPercent(data.macros.post_run_carbs_g, expectedPost, PERCENT_TOLERANCE, 'swimmer post carbs');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });

    it('lightweightTopUp: pre carbs = 55 * min(0.5, 4) = 27.5g ±5%', async () => {
      const { data } = await callMacrosV4(athletes.lightweightTopUp);
      const expected = 55 * Math.min(0.5, 4); // 27.5
      assertWithinPercent(data.macros.pre_run_carbs_g, expected, PERCENT_TOLERANCE, 'lightweightTopUp pre carbs');
      // 0.5 h sits ON the inclusive snack boundary (>= 30 min).
      assertEquals(data.macros.pre_run_meal_type, 'snack');
      assertInRange(data.macros.post_run_protein_g, 20, 40, 'Post protein 20-40g');
    });
  });

  // =========================================================================
  // H. Sport Ceiling Zero Tolerance (3 tests)
  // =========================================================================

  describe('H. Sport Ceiling Zero Tolerance', () => {
    it('running sport ceiling = exactly 70 g/hr', async () => {
      const { data } = await callMacrosV4(athletes.averageMale);
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 70, 'Running ceiling must be exactly 70');
    });

    it('cycling sport ceiling = exactly 120 g/hr', async () => {
      const { data } = await callMacrosV4(athletes.heavyCyclist);
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 120, 'Cycling ceiling must be exactly 120');
    });

    it('swimming sport ceiling = exactly 0 g/hr', async () => {
      const { data } = await callMacrosV4(athletes.swimmer);
      assertEquals(data.macros.during_sport_ceiling_g_per_h, 0, 'Swimming ceiling must be exactly 0');
    });
  });
});
