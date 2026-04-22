/**
 * Tests for sweat-hydration.ts
 *
 * Ported verbatim from /docs/sodium_hydration/hydration_sodium_calc_tests.md
 * Tolerances: sweat rate ±0.01 L/hr
 *
 * Run with:
 *   deno test supabase/functions/_shared/nutrition/sweat-hydration.test.ts
 */

import {
  assertEquals,
  assertAlmostEquals,
  assert,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import {
  baseSweatRateFromCategory,
  sodiumConcentrationFromCategory,
  calculateActualSweatRate,
  SWIMMING_SWEAT_MODIFIER,
  replacementPctForDuration,
} from './sweat-hydration.ts';

const RATE_TOLERANCE = 0.01; // L/hr
const ML_TOLERANCE_PCT = 0.05; // 5%

function assertRateClose(actual: number, expected: number, msg?: string) {
  const diff = Math.abs(actual - expected);
  assert(diff <= RATE_TOLERANCE, `${msg ?? ''} Expected ${expected} ±${RATE_TOLERANCE}, got ${actual}`);
}

// ============================================================================
// Base Rate Lookup
// ============================================================================

describe('Base Rate Lookup', () => {
  it('LIGHT sweater returns 0.90 L/hr', () => {
    assertEquals(baseSweatRateFromCategory('light'), 0.90);
  });

  it('MEDIUM sweater returns 1.28 L/hr', () => {
    assertEquals(baseSweatRateFromCategory('medium'), 1.28);
  });

  it('HEAVY sweater returns 1.66 L/hr', () => {
    assertEquals(baseSweatRateFromCategory('heavy'), 1.66);
  });

  it('unknown category defaults to medium (1.28)', () => {
    assertEquals(baseSweatRateFromCategory('unknown'), 1.28);
  });
});

// ============================================================================
// Sodium Concentration
// ============================================================================

describe('Sodium Concentration Lookup', () => {
  it('LOW returns 650 mg/L', () => {
    assertEquals(sodiumConcentrationFromCategory('low'), 650);
  });

  it('AVERAGE returns 825 mg/L', () => {
    assertEquals(sodiumConcentrationFromCategory('average'), 825);
  });

  it('medium is alias for average (825 mg/L)', () => {
    assertEquals(sodiumConcentrationFromCategory('medium'), 825);
  });

  it('HIGH returns 1000 mg/L', () => {
    assertEquals(sodiumConcentrationFromCategory('high'), 1000);
  });

  it('unknown category defaults to average (825)', () => {
    assertEquals(sodiumConcentrationFromCategory('unknown'), 825);
  });
});

// ============================================================================
// Temperature Multiplier Tests (spec table)
// ============================================================================

describe('Temperature Multiplier', () => {
  it('22°C → 1.00 (baseline)', () => {
    // MEDIUM at 22°C, 50%, outdoor → 1.28
    const rate = calculateActualSweatRate('medium', 22, 50, false, null, null);
    assertRateClose(rate, 1.28, 'MEDIUM 22°C 50% outdoor');
  });

  it('32°C → temp_mult 1.40 → MEDIUM rate 1.79 L/hr', () => {
    // 1.28 * 1.40 = 1.792
    const rate = calculateActualSweatRate('medium', 32, 50, false, null, null);
    assertRateClose(rate, 1.79, 'MEDIUM 32°C 50% outdoor');
  });

  it('14°C → temp_mult 0.68 → LIGHT rate 0.61 L/hr', () => {
    // 0.90 * 0.68 = 0.612
    const rate = calculateActualSweatRate('light', 14, 50, false, null, null);
    assertRateClose(rate, 0.61, 'LIGHT 14°C 50% outdoor');
  });

  it('0°C → temp_mult clamped at 0.50 → MEDIUM rate 0.64 L/hr', () => {
    // raw = 1.0 + (0-22)*0.04 = 0.12 → clamped to 0.50
    // 1.28 * 0.50 = 0.64
    const rate = calculateActualSweatRate('medium', 0, 50, false, null, null);
    assertRateClose(rate, 0.64, 'MEDIUM 0°C clamp 0.50');
  });

  it('50°C → temp_mult clamped at 1.80 → MEDIUM rate 2.30 L/hr', () => {
    // raw = 1.0 + (50-22)*0.04 = 2.12 → clamped to 1.80
    // 1.28 * 1.80 = 2.304
    const rate = calculateActualSweatRate('medium', 50, 50, false, null, null);
    assertRateClose(rate, 2.30, 'MEDIUM 50°C clamp 1.80');
  });
});

// ============================================================================
// Humidity Multiplier Tests
// ============================================================================

describe('Humidity Multiplier', () => {
  it('50% humidity → multiplier 1.00 (threshold, no effect)', () => {
    // MEDIUM 22°C 50% outdoor = 1.28
    const rate = calculateActualSweatRate('medium', 22, 50, false, null, null);
    assertRateClose(rate, 1.28, 'humidity at threshold');
  });

  it('100% humidity → multiplier clamped at 1.10', () => {
    // raw = 1 + (100-50)*0.002 = 1.10, clamped at 1.10
    // MEDIUM 22°C 100% outdoor = 1.28 * 1.10 = 1.408
    const rate = calculateActualSweatRate('medium', 22, 100, false, null, null);
    assertRateClose(rate, 1.41, 'humidity 100% cap 1.10');
  });

  it('below 50% humidity → multiplier 1.00', () => {
    // MEDIUM 22°C 20% outdoor = 1.28
    const rate = calculateActualSweatRate('medium', 22, 20, false, null, null);
    assertRateClose(rate, 1.28, 'humidity below threshold');
  });
});

// ============================================================================
// Indoor Multiplier
// ============================================================================

describe('Indoor Multiplier', () => {
  it('is_indoor=true → 1.30× on top of other factors', () => {
    // MEDIUM 22°C 50% indoor = 1.28 * 1.30 = 1.664
    const rate = calculateActualSweatRate('medium', 22, 50, true, null, null);
    assertRateClose(rate, 1.66, 'MEDIUM indoor');
  });
});

// ============================================================================
// Combined Effective Sweat Rate (spec table verbatim)
// ============================================================================

describe('Combined Effective Sweat Rate', () => {
  it('MEDIUM, 22°C, 50%, outdoor → 1.28', () => {
    const rate = calculateActualSweatRate('medium', 22, 50, false, null, null);
    assertRateClose(rate, 1.28);
  });

  it('MEDIUM, 22°C, 50%, indoor → 1.66', () => {
    // 1.28 * 1.30 = 1.664
    const rate = calculateActualSweatRate('medium', 22, 50, true, null, null);
    assertRateClose(rate, 1.66);
  });

  it('HEAVY, 31°C, 65%, outdoor → 2.33', () => {
    // 1.66 * 1.36 * 1.03 = 2.326
    const rate = calculateActualSweatRate('heavy', 31, 65, false, null, null);
    assertRateClose(rate, 2.33);
  });

  it('LIGHT, 14°C, 50%, outdoor → 0.61', () => {
    // 0.90 * 0.68 = 0.612
    const rate = calculateActualSweatRate('light', 14, 50, false, null, null);
    assertRateClose(rate, 0.61);
  });

  it('known=1300, 26°C, 55%, outdoor → 1.52', () => {
    // base = 1300/1000 = 1.30
    // temp_mult = 1 + (26-22)*0.04 = 1.16
    // humidity_mult = 1 + max(0, 55-50)*0.002 = 1.01
    // 1.30 * 1.16 * 1.01 = 1.523
    const rate = calculateActualSweatRate('medium', 26, 55, false, 1300, null);
    assertRateClose(rate, 1.52);
  });
});

// ============================================================================
// Swimming Modifier
// ============================================================================

describe('Swimming Sweat Modifier', () => {
  it('SWIMMING_SWEAT_MODIFIER constant is 0.4', () => {
    assertEquals(SWIMMING_SWEAT_MODIFIER, 0.4);
  });

  it('1.28 L/hr * 0.4 = 0.51 L/hr swim effective', () => {
    const baseRate = 1.28;
    const swimRate = Math.round(baseRate * SWIMMING_SWEAT_MODIFIER * 100) / 100;
    assertRateClose(swimRate, 0.51, 'swim modifier result');
  });
});

// ============================================================================
// Overall Clamp Test
// ============================================================================

describe('Overall Clamp (0.3 – 3.0 L/hr)', () => {
  it('HEAVY, 50°C, 100%, indoor → clamped to 3.0', () => {
    // 1.66 * 1.80 * 1.10 * 1.30 = 4.27 → clamped to 3.0
    const rate = calculateActualSweatRate('heavy', 50, 100, true, null, null);
    assertEquals(rate, 3.0);
  });
});

// ============================================================================
// Known Sweat Rate Override
// ============================================================================

describe('Known Sweat Rate Override', () => {
  it('knownSweatRateMlPerHour overrides base but still applies multipliers', () => {
    // known=1300, 22°C, 50%, outdoor → 1.30 * 1.0 * 1.0 = 1.30
    const rate = calculateActualSweatRate('light', 22, 50, false, 1300, null);
    assertRateClose(rate, 1.30);
  });

  it('known=0 → after multipliers → clamped to 0.3 L/hr', () => {
    const rate = calculateActualSweatRate('medium', 22, 50, false, 0, null);
    assertEquals(rate, 0.3);
  });
});

// ============================================================================
// Replacement Percentage Lookup
// ============================================================================

describe('Replacement Percentage Lookup', () => {
  it('59 min → 0.30', () => assertEquals(replacementPctForDuration(59), 0.30));
  it('89 min → 0.50', () => assertEquals(replacementPctForDuration(89), 0.50));
  it('140 min → 0.60', () => assertEquals(replacementPctForDuration(140), 0.60));
  it('180 min → 0.70', () => assertEquals(replacementPctForDuration(180), 0.70));
  it('600 min → 0.80', () => assertEquals(replacementPctForDuration(600), 0.80));
  // Boundary exactly at 60
  it('60 min → 0.50 (boundary: start of 60-90 tier)', () => assertEquals(replacementPctForDuration(60), 0.50));
  // 90 min inclusive of the 60-90 tier per Example 2 in spec
  it('90 min → 0.50 (inclusive upper boundary of 60-90 tier, per Example 2)', () => assertEquals(replacementPctForDuration(90), 0.50));
  it('91 min → 0.60', () => assertEquals(replacementPctForDuration(91), 0.60));
  it('150 min → 0.60 (inclusive upper boundary of 91-150 tier)', () => assertEquals(replacementPctForDuration(150), 0.60));
  it('151 min → 0.70', () => assertEquals(replacementPctForDuration(151), 0.70));
  it('240 min → 0.80', () => assertEquals(replacementPctForDuration(240), 0.80));
});
