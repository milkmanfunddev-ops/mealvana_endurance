/**
 * Single-Sport Integration Tests for hydration algorithm.
 *
 * Ported verbatim from /docs/sodium_hydration/hydration_sodium_calc_tests.md §Single-Sport Integration Tests
 * Tolerances: ml/hr ±5%, sweat rate ±0.01 L/hr
 *
 * Run with:
 *   deno test supabase/functions/generate-macros-v4/single-sport.test.ts
 */

import {
  assertEquals,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { calculateDuringWorkoutHydration } from './single-sport.ts';

const ML_TOL = 0.05; // 5% tolerance for ml/hr values

function assertMlClose(actual: number, expected: number, msg?: string) {
  const tol = Math.max(1, expected * ML_TOL);
  const diff = Math.abs(actual - expected);
  assert(diff <= tol, `${msg ?? ''} Expected ${expected} ±${tol.toFixed(1)}, got ${actual}`);
}

// ============================================================================
// Short-Workout Gate Cases
// ============================================================================

describe('Short-Workout Gate', () => {
  it('45 min at 31°C → gate NOT triggered (temp >= 30 bypasses)', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 45,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 31,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assert(!result.safety_flags.includes('No structured hydration plan needed.'),
      'Gate should not trigger when temp >= 30');
  });

  it('59 min at 29°C → gate triggered', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 59,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 29,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assert(result.safety_flags.includes('No structured hydration plan needed.'),
      'Gate should trigger at 59 min, 29°C');
  });
});

// ============================================================================
// Replacement % Boundary Cases
// ============================================================================

describe('Replacement % boundary cases', () => {
  it('exactly 60 min uses 0.50 replacement pct', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 60,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assertEquals(result.replacement_pct, 0.50);
  });

  it('exactly 90 min uses 0.50 replacement pct (90 is inclusive upper bound of 60-90 tier per Example 2)', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 90,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assertEquals(result.replacement_pct, 0.50);
  });
});

// ============================================================================
// Example 1: 45-min speedwork, nice day (gate triggered)
// ============================================================================

describe('Example 1: 45-min speedwork, gate triggered', () => {
  it('returns recommended=384, floor=0, ceiling=800 with gate flag', () => {
    // Athlete: 70 kg, MEDIUM sweater, 22°C, 45% humidity, outdoor, 45 min run
    // Effective sweat rate: 1.28 L/hr (22°C no adj)
    // Gate: duration < 60 AND temp < 30 → triggered
    // Conservative target: 1280 * 0.30 = 384 ml/hr
    // Floor: total_loss=1280*0.75=960; max_deficit=1400; (960-1400)/0.75 < 0 → 0
    // Ceiling: min(800, 1280) = 800
    const result = calculateDuringWorkoutHydration({
      durationMin: 45,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 45,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });

    assertMlClose(result.hydration_rate_mlph, 384, 'recommended');
    assertEquals(result.floor_ml_hr, 0, 'floor should be 0');
    assertEquals(result.ceiling_ml_hr, 800, 'ceiling should be 800');
    assert(
      result.safety_flags.includes('No structured hydration plan needed.'),
      'gate flag present',
    );
  });
});

// ============================================================================
// Example 2: 90-min long run, cool morning
// ============================================================================

describe('Example 2: 90-min long run, cool morning', () => {
  it('returns recommended=306, floor=0, ceiling=612', () => {
    // Athlete: 65 kg, LIGHT sweater, 14°C, 50% humidity, outdoor, 90 min run
    // effective = 0.90 * 0.68 = 0.612 L/hr
    // replacement = 90 → 0.50
    // recommended = 612 * 0.50 = 306 ml/hr
    // total_loss = 612 * 1.5 = 918; max_deficit = 1300; floor = (918-1300)/1.5 < 0 → 0
    // ceiling = min(800, 612) = 612
    const result = calculateDuringWorkoutHydration({
      durationMin: 90,
      weightKg: 65,
      sweatRateCategory: 'light',
      sweatSodiumCat: 'average',
      tempC: 14,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });

    assertMlClose(result.hydration_rate_mlph, 306, 'recommended');
    assertEquals(result.floor_ml_hr, 0, 'floor should be 0');
    assertMlClose(result.ceiling_ml_hr, 612, 'ceiling should be 612');
    assertEquals(result.replacement_pct, 0.50);
    assert(result.safety_flags.length === 0, 'no safety flags expected');
  });
});

// ============================================================================
// Example 3: 3-hour bike, hot day (floor > ceiling)
// ============================================================================

describe('Example 3: 3-hour bike, hot day (floor > ceiling)', () => {
  it('returns recommended=1200 (capped at ceiling), floor=1792, ceiling=1200 with flags', () => {
    // Athlete: 80 kg, HEAVY sweater, 31°C, 65% outdoor, 180 min cycling
    // effective = 1.66 * 1.36 * 1.03 = 2.325 L/hr
    // replacement = 180 → 0.70
    // pct-based = 2325 * 0.70 = 1628 ml/hr
    // total_loss = 2325*3 = 6975; max_deficit = 1600
    // floor = (6975-1600)/3 = 1792 ml/hr → overrides pct
    // ceiling = min(1200, 2325) = 1200 → ceiling < floor → recommended = ceiling
    const result = calculateDuringWorkoutHydration({
      durationMin: 180,
      weightKg: 80,
      sweatRateCategory: 'heavy',
      sweatSodiumCat: 'average',
      tempC: 31,
      humidityPct: 65,
      isIndoor: false,
      sport: 'cycling',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });

    assertEquals(result.hydration_rate_mlph, 1200, 'recommended should be capped at ceiling');
    assertMlClose(result.floor_ml_hr, 1792, 'floor');
    assertEquals(result.ceiling_ml_hr, 1200, 'ceiling');
    assert(
      result.safety_flags.some(f => f.includes('Even at maximum intake, you will exceed 2% BW loss.')),
      'ceiling-floor flag',
    );
    assert(
      result.safety_flags.some(f => f.includes('Significant dehydration expected')),
      'significant dehydration flag',
    );
  });
});

// ============================================================================
// Example 4: 60-min indoor trainer
// ============================================================================

describe('Example 4: 60-min indoor trainer', () => {
  it('returns recommended=832, floor=164, ceiling=1200', () => {
    // Athlete: 75 kg, MEDIUM sweater, 22°C, 50%, indoor, 60 min cycling
    // effective = 1.28 * 1.30 = 1.664 L/hr
    // replacement = 60 → 0.50
    // recommended = 1664 * 0.50 = 832 ml/hr
    // total_loss = 1664; max_deficit = 1500
    // floor = (1664-1500)/1 = 164 ml/hr
    // ceiling = min(1200, 1664) = 1200
    const result = calculateDuringWorkoutHydration({
      durationMin: 60,
      weightKg: 75,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: true,
      sport: 'cycling',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });

    assertMlClose(result.hydration_rate_mlph, 832, 'recommended');
    assertMlClose(result.floor_ml_hr, 164, 'floor');
    assertEquals(result.ceiling_ml_hr, 1200, 'ceiling');
    assertEquals(result.replacement_pct, 0.50);
    assert(result.safety_flags.length === 0, 'no safety flags');
  });
});

// ============================================================================
// Sodium Derivation
// ============================================================================

describe('Sodium is derived from fluid × concentration', () => {
  it('sodium_rate = (fluid_ml_hr / 1000) * sodium_conc', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 90,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    // sodium_conc = 825 mg/L
    const expectedSodium = Math.round((result.hydration_rate_mlph / 1000) * 825);
    assertEquals(result.sodium_rate_mgph, expectedSodium);
  });
});

// ============================================================================
// Indoor multiplier does not bypass the gate (<60 min AND <30°C)
// ============================================================================

describe('Indoor + short + mild — gate still fires', () => {
  it('45 min indoor at 22°C → gate triggered, effective rate reflects 1.30× indoor', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 45,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: true,
      sport: 'cycling',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assert(result.safety_flags.includes('No structured hydration plan needed.'),
      'gate should still trigger indoors when short and mild');
    // Effective rate with indoor multiplier: 1.28 × 1.30 = 1.664
    assert(Math.abs(result.effective_sweat_rate_lph - 1.664) < 0.02,
      `expected ~1.66 effective L/hr, got ${result.effective_sweat_rate_lph}`);
  });
});

// ============================================================================
// Zero-value override edge cases
// ============================================================================

describe('Zero-value overrides', () => {
  it('knownSweatRateMlPerHour=0 → clamped to 0.3 L/hr, no NaN', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 90,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: 0,
      knownSodiumConcMgPerL: null,
    });
    assertEquals(result.effective_sweat_rate_lph, 0.3);
    assert(Number.isFinite(result.hydration_rate_mlph), 'fluid rate is finite');
    assert(Number.isFinite(result.sodium_rate_mgph), 'sodium rate is finite');
  });

  it('knownSodiumConcMgPerL=0 → sodium rate = 0, no NaN', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 90,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: 0,
    });
    assertEquals(result.sodium_rate_mgph, 0);
    assert(Number.isFinite(result.hydration_rate_mlph), 'fluid rate is finite');
  });
});

// ============================================================================
// Breakdown fields expose temp/humidity/indoor mults for the UI
// ============================================================================

describe('Breakdown fields for calculation UI', () => {
  it('returns base_sweat_rate_lph, temp_mult, humidity_mult, indoor_mult, replacement_band', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 135,  // in 90–150 band
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 26,
      humidityPct: 55,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assertEquals(result.base_sweat_rate_lph, 1.28);
    assertEquals(result.temp_mult, 1.16); // 1 + (26-22)*0.04
    assertEquals(result.humidity_mult, 1.01); // 1 + (55-50)*0.002
    assertEquals(result.indoor_mult, 1);
    assertEquals(result.replacement_band, '90–150 min');
  });

  it('known sweat rate → base reflects override, is_tested=true', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 90,
      weightKg: 65,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22, humidityPct: 50, isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: 1300,
      knownSodiumConcMgPerL: null,
    });
    assertEquals(result.base_sweat_rate_lph, 1.3);
    assertEquals(result.is_tested, true);
  });
});

// ============================================================================
// is_tested flag
// ============================================================================

describe('is_tested flag', () => {
  it('is true when known sweat rate provided', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 90,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: 1200,
      knownSodiumConcMgPerL: null,
    });
    assert(result.is_tested === true);
  });

  it('is false when no known sweat rate', () => {
    const result = calculateDuringWorkoutHydration({
      durationMin: 90,
      weightKg: 70,
      sweatRateCategory: 'medium',
      sweatSodiumCat: 'average',
      tempC: 22,
      humidityPct: 50,
      isIndoor: false,
      sport: 'running',
      knownSweatRateMlPerHour: null,
      knownSodiumConcMgPerL: null,
    });
    assert(result.is_tested === false);
  });
});
