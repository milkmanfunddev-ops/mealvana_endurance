/**
 * Comprehensive tests for calculate-daily-macros edge function
 * Covers all iterations 1-4 with test cases from spec files
 */

import { assertEquals, assertThrows } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { calculateRMR } from './formulas/rmr.ts';
import { zoneDistributionToIF, sessionCost, carbDemand } from './formulas/session.ts';
import { baselineMacros, clampMacros } from './formulas/baseline.ts';
import {
  recoveryDebt,
  preLoadOverride,
  weeklyLoadAdjust,
  phaseModifier,
} from './formulas/multi-day.ts';
import { inferVolumeTier, getDayModifier, calculateNEAT, calculateTDEE } from './formulas/neat-tef.ts';
import {
  deriveFFM,
  checkEnergyAvailability,
  eaOverride,
  multiSessionCarbCompound,
  carbCycleAdjust,
} from './formulas/safety.ts';
import type { SessionInput, DailyMacroInput, Sport } from './types.ts';
import { calculateDailyMacros, validateInput } from './pipeline.ts';

// Reference athlete: Male, 34yr, 75kg, 178cm, BF 14.7% -> LBM 64kg
const REF_ATHLETE = {
  sex: 'male' as const,
  age: 34,
  weight_kg: 75,
  height_cm: 178,
  body_fat_pct: 14.7,
  lbm_kg: 64, // 75 * (1 - 0.147) = 63.975 ~ 64
};

// Tolerance helpers
function assertWithinPercent(actual: number, expected: number, percent: number, message?: string) {
  const tolerance = Math.abs(expected) * (percent / 100);
  const diff = Math.abs(actual - expected);
  if (diff > tolerance) {
    throw new Error(
      `${message || 'Assertion failed'}: expected ${expected} +/- ${percent}%, got ${actual} (diff: ${diff.toFixed(2)}, tolerance: ${tolerance.toFixed(2)})`
    );
  }
}

function assertWithinAbsolute(actual: number, expected: number, tolerance: number, message?: string) {
  const diff = Math.abs(actual - expected);
  if (diff > tolerance) {
    throw new Error(
      `${message || 'Assertion failed'}: expected ${expected} +/- ${tolerance}, got ${actual} (diff: ${diff.toFixed(2)})`
    );
  }
}

/** Helper: build a reference athlete pipeline input */
function refInput(overrides: Partial<DailyMacroInput> = {}): DailyMacroInput {
  return {
    sex: 'male',
    age: 34,
    weight_kg: 75,
    height_cm: 178,
    body_fat_pct: 14.7,
    lifestyle: 'desk',
    typical_weekly_hours: 10,
    carb_cycle_opt_in: false,
    training_phase: 'base',
    sessions: [],
    yesterday_tss: null,
    yesterday_hours_since: null,
    tomorrow_tss: null,
    tomorrow_duration_hr: null,
    tomorrow_is_race: false,
    weekly_hours_ratio: 1.0,
    mode: 'prospective',
    ...overrides,
  };
}

/** Helper: create a typed session */
function session(
  sport: Sport,
  duration_hr: number,
  pct_conversational: number,
  pct_tempo: number,
  pct_allout: number,
  tss?: number | null,
): SessionInput {
  return { sport, duration_hr, pct_conversational, pct_tempo, pct_allout, tss: tss ?? null };
}

// ============================================================================
// ITERATION 1: UNIT TESTS
// ============================================================================

Deno.test('Iter1: RMR - Cunningham with body fat', () => {
  const rmr = calculateRMR(75, 178, 34, 'male', 14.7);
  assertWithinPercent(rmr, 1908, 2, 'RMR with Cunningham');
});

Deno.test('Iter1: RMR - Mifflin without body fat', () => {
  const rmr = calculateRMR(75, 178, 34, 'male', null);
  assertWithinPercent(rmr, 1698, 2, 'RMR with Mifflin');
});

Deno.test('Iter1: RMR - Female', () => {
  const rmr = calculateRMR(62, 165, 29, 'female', null);
  assertWithinPercent(rmr, 1345, 2, 'Female RMR');
});

Deno.test('Iter1: RMR - Cunningham priority over Mifflin', () => {
  const rmr = calculateRMR(75, 178, 34, 'male', 14.7);
  assertWithinPercent(rmr, 1908, 2, 'Cunningham must take priority');
});

Deno.test('Iter1: RMR - Body fat 0% edge case', () => {
  const rmr = calculateRMR(75, 178, 34, 'male', 0);
  // LBM = 75, Cunningham = 500 + 22*75 = 2150
  assertWithinPercent(rmr, 2150, 1);
});

Deno.test('Iter1: Zone Distribution to IF - Pure zones', () => {
  assertEquals(Math.round(zoneDistributionToIF(1.0, 0, 0) * 1000), 680);
  assertEquals(Math.round(zoneDistributionToIF(0, 1.0, 0) * 1000), 880);
  assertEquals(Math.round(zoneDistributionToIF(0, 0, 1.0) * 1000), 1080);
});

Deno.test('Iter1: Zone Distribution to IF - Mixed zones', () => {
  assertWithinPercent(zoneDistributionToIF(0.70, 0.20, 0.10), 0.771, 1);
  assertWithinPercent(zoneDistributionToIF(0.30, 0.40, 0.30), 0.894, 1);
  assertWithinPercent(zoneDistributionToIF(0.50, 0, 0.50), 0.902, 1);
});

Deno.test('Iter1: Zone Distribution to IF - Rejects bad sum (never normalizes)', () => {
  assertThrows(() => zoneDistributionToIF(0.70, 0.20, 0.20), RangeError);
  assertThrows(() => zoneDistributionToIF(0, 0, 0), RangeError);
});

Deno.test('Iter1: Session Cost - Running', () => {
  assertWithinPercent(sessionCost('running', 1.5, 0.74, 75), 1205, 5);
});

Deno.test('Iter1: Session Cost - Cycling high IF', () => {
  assertWithinPercent(sessionCost('cycling', 1.25, 0.93, 75), 1297, 5);
});

Deno.test('Iter1: Session Cost - Long cycling', () => {
  assertWithinPercent(sessionCost('cycling', 4.0, 0.72, 75), 2488, 5);
});

Deno.test('Iter1: Session Cost - Strength', () => {
  assertWithinPercent(sessionCost('strength', 1.0, 0.70, 75), 350, 5);
});

Deno.test('Iter1: Session Cost - Running short easy', () => {
  assertWithinPercent(sessionCost('running', 0.75, 0.65, 75), 465, 5);
});

// INTERIM behavior pending the SSOT ruling in
// qa/intake/2026-08-20-session-cost-unknown-activity-types.md — see
// ops/data/bug-reports/2026-08-20-session-cost-unknown-sport-priced-as-running.md.
// Deliberately un-vectored: session-demand.json pins no unmapped-sport case.
function captureWarn(body: () => void): string[] {
  const warnings: string[] = [];
  const original = console.warn;
  console.warn = (...args: unknown[]) => {
    warnings.push(args.map(String).join(' '));
  };
  try {
    body();
  } finally {
    console.warn = original;
  }
  return warnings;
}

Deno.test('INTERIM bug 2026-08-20: unmapped sports use the conservative linear strength rate and are flagged by name', () => {
  const unmapped = ['other', 'triathlon', 'duathlon', 'multisport', 'brick'];
  const warnings = captureWarn(() => {
    for (const sport of unmapped) {
      const kcal = sessionCost(sport, 1.0, 0.75, 70);
      // 5 kcal/kg/hr, linear, IF at reference 0.75: 5 × 1 × 1 × 70.
      assertEquals(Math.abs(kcal - 350) < 0.001, true, sport);
    }
  });
  assertEquals(warnings.length, unmapped.length);
  for (const sport of unmapped) {
    assertEquals(
      warnings.some((w) => w.includes(`"${sport}"`)),
      true,
      sport,
    );
  }
});

Deno.test('INTERIM bug 2026-08-20: 60-min foam roll (other, IF 0.74, 70 kg) is no longer ~750 kcal (or NaN)', () => {
  let kcal = NaN;
  captureWarn(() => {
    kcal = sessionCost('other', 1.0, 0.74, 70);
  });
  const expected = 5 * (0.74 / 0.75) * 1.0 * 70; // ≈345.3
  assertEquals(Math.abs(kcal - expected) < 0.001, true);
  assertEquals(kcal < 400, true);
});

Deno.test('INTERIM bug 2026-08-20: unmapped sport scales linearly with IF, not quadratically', () => {
  let ratio = NaN;
  captureWarn(() => {
    ratio = sessionCost('other', 1.0, 0.90, 70) /
      sessionCost('other', 1.0, 0.45, 70);
  });
  assertEquals(Math.abs(ratio - 2.0) < 1e-9, true); // quadratic would give 4.0
});

Deno.test('INTERIM bug 2026-08-20: mapped sports are unchanged and not flagged', () => {
  const warnings = captureWarn(() => {
    assertEquals(
      Math.abs(
        sessionCost('running', 1.5, 0.74, 75) -
          11 * Math.pow(0.74 / 0.75, 2) * 1.5 * 75,
      ) < 0.001,
      true,
    );
    assertEquals(
      Math.abs(
        sessionCost('cycling', 1.25, 0.93, 75) -
          9 * Math.pow(0.93 / 0.75, 2) * 1.25 * 75,
      ) < 0.001,
      true,
    );
    assertEquals(
      Math.abs(
        sessionCost('swimming', 1.0, 0.80, 75) -
          7 * Math.pow(0.80 / 0.75, 2) * 1.0 * 75,
      ) < 0.001,
      true,
    );
    assertEquals(
      Math.abs(
        sessionCost('strength', 1.0, 0.70, 75) - 5 * (0.70 / 0.75) * 1.0 * 75,
      ) < 0.001,
      true,
    );
  });
  assertEquals(warnings, []);
});

Deno.test('Iter1: Session Cost - Weight scaling', () => {
  const cost60 = sessionCost('running', 1.5, 0.74, 60);
  const cost75 = sessionCost('running', 1.5, 0.74, 75);
  const cost90 = sessionCost('running', 1.5, 0.74, 90);

  assertWithinPercent(cost60, 964, 5);
  assertWithinPercent(cost75, 1205, 5);
  assertWithinPercent(cost90, 1446, 5);

  // Check ratios
  assertWithinPercent(cost60 / cost75, 0.800, 1);
  assertWithinPercent(cost90 / cost75, 1.200, 1);
});

Deno.test('Iter1: Carb Demand - No multiplier', () => {
  assertWithinPercent(carbDemand('running', 0.65, 0.75, 75), 26, 5);
  assertWithinPercent(carbDemand('running', 0.74, 1.5, 75), 69, 5);
});

Deno.test('Iter1: Carb Demand - With 1.15x multiplier', () => {
  assertWithinPercent(carbDemand('running', 0.88, 2.0, 75), 163, 5);
  assertWithinPercent(carbDemand('cycling', 0.93, 1.25, 75), 116, 5);
  assertWithinPercent(carbDemand('cycling', 0.72, 4.0, 75), 198, 5);
});

Deno.test('Iter1: Carb Demand - Weight scaling', () => {
  assertWithinPercent(carbDemand('running', 0.74, 1.5, 60), 55, 5);
  assertWithinPercent(carbDemand('running', 0.74, 1.5, 75), 69, 5);
  assertWithinPercent(carbDemand('running', 0.74, 1.5, 90), 83, 5);

  assertWithinPercent(carbDemand('running', 0.88, 2.0, 60), 131, 5);
  assertWithinPercent(carbDemand('running', 0.88, 2.0, 90), 196, 5);
});

Deno.test('Iter1: Carb Demand - Strength flat rate (Q-003)', () => {
  // 27 g/hr × (weight/75); IF ignored, no long/intense multiplier
  assertEquals(carbDemand('strength', 0.9, 1.0, 75), 27);
  assertEquals(carbDemand('strength', 0.6, 1.0, 75), 27);
  assertEquals(carbDemand('strength', 0.9, 2.0, 75), 54);
  assertWithinPercent(carbDemand('strength', 0.9, 1.0, 90), 32.4, 1);
});

Deno.test('Iter1: Baseline Macros - With LBM', () => {
  const baseline = baselineMacros(75, 64, 34);
  assertWithinPercent(baseline.carb_g, 300, 5); // 4.0 * 75
  assertWithinPercent(baseline.prot_g, 115, 5); // 1.8 * 64
});

Deno.test('Iter1: Baseline Macros - Without LBM', () => {
  const baseline = baselineMacros(75, null, 34);
  assertWithinPercent(baseline.carb_g, 300, 5);
  assertWithinPercent(baseline.prot_g, 105, 5); // 1.4 * 75
});

Deno.test('Iter1: Baseline Macros - Masters age 45', () => {
  const baseline = baselineMacros(75, 64, 45);
  assertWithinPercent(baseline.prot_g, 132, 5); // 1.8 * 64 * 1.15
});

Deno.test('Iter1: Baseline Macros - Age 44 no masters', () => {
  const baseline = baselineMacros(75, 64, 44);
  assertWithinPercent(baseline.prot_g, 115, 5); // no multiplier
});

Deno.test('Iter1: Baseline Macros - Masters without LBM', () => {
  const baseline = baselineMacros(75, null, 45);
  assertWithinPercent(baseline.prot_g, 121, 5); // 1.4 * 75 * 1.15
});

Deno.test('Iter1: Baseline Macros - Age 60 masters', () => {
  const baseline = baselineMacros(75, 64, 60);
  assertWithinPercent(baseline.prot_g, 132, 5); // 1.8 * 64 * 1.15
});

// ============================================================================
// ITERATION 2: UNIT TESTS
// ============================================================================

Deno.test('Iter2: Recovery Debt - No debt (TSS < 150)', () => {
  const debt = recoveryDebt(100, 20, 75);
  assertEquals(debt.carb_add, 0);
  assertEquals(debt.prot_add, 0);
});

Deno.test('Iter2: Recovery Debt - Full debt at 16h', () => {
  const debt = recoveryDebt(150, 16, 75);
  assertWithinPercent(debt.carb_add, 93.75, 2); // 1.25 * 75
  assertWithinPercent(debt.prot_add, 7.5, 2); // 0.1 * 75
});

Deno.test('Iter2: Recovery Debt - Half decay at 27h', () => {
  const debt = recoveryDebt(150, 27, 75);
  assertWithinPercent(debt.carb_add, 46.875, 5); // ~50% decay
  assertWithinPercent(debt.prot_add, 3.75, 5);
});

Deno.test('Iter2: Recovery Debt - Minimal decay at 34h', () => {
  const debt = recoveryDebt(220, 34, 75);
  // decay = 1.0 - (34-18)/(36-18) = 1.0 - 16/18 = 0.111
  assertWithinPercent(debt.carb_add, 10.4, 20);
  assertWithinPercent(debt.prot_add, 0.83, 20);
});

Deno.test('Iter2: Recovery Debt - Zero at 36h', () => {
  const debt = recoveryDebt(220, 36, 75);
  assertEquals(debt.carb_add, 0);
  assertEquals(debt.prot_add, 0);
});

Deno.test('Iter2: Recovery Debt - TSS 200 at 18h', () => {
  const debt = recoveryDebt(200, 18, 75);
  assertWithinPercent(debt.carb_add, 93.75, 2);
  assertWithinPercent(debt.prot_add, 7.5, 2);
});

Deno.test('Iter2: Recovery Debt - Null inputs', () => {
  const debt = recoveryDebt(null, null, 75);
  assertEquals(debt.carb_add, 0);
  assertEquals(debt.prot_add, 0);
});

Deno.test('Iter2: Recovery Debt - Just finished (0h)', () => {
  const debt = recoveryDebt(200, 0, 75);
  assertWithinPercent(debt.carb_add, 93.75, 2); // factor = 1.0
});

Deno.test('Iter2: Recovery Debt - Very old (100h)', () => {
  const debt = recoveryDebt(200, 100, 75);
  assertEquals(debt.carb_add, 0); // factor = 0
  assertEquals(debt.prot_add, 0);
});

Deno.test('Iter2: Pre-Load Override - No tomorrow', () => {
  assertEquals(preLoadOverride(null, null, false, 400, 75), 400);
});

Deno.test('Iter2: Pre-Load Override - Low TSS no change', () => {
  assertEquals(preLoadOverride(50, 1, false, 400, 75), 400);
});

Deno.test('Iter2: Pre-Load Override - Moderate TSS add 1.5g/kg', () => {
  assertWithinPercent(preLoadOverride(130, 2, false, 350, 75), 462.5, 2);
});

Deno.test('Iter2: Pre-Load Override - Moderate TSS from higher base', () => {
  assertWithinPercent(preLoadOverride(130, 2, false, 500, 75), 612.5, 2);
});

Deno.test('Iter2: Pre-Load Override - Race day', () => {
  assertWithinPercent(preLoadOverride(null, null, true, 350, 75), 675, 2);
});

Deno.test('Iter2: Pre-Load Override - Race day already high', () => {
  assertEquals(preLoadOverride(null, null, true, 700, 75), 700);
});

Deno.test('Iter2: Pre-Load Override - Very high TSS', () => {
  assertWithinPercent(preLoadOverride(250, null, false, 400, 75), 675, 2);
});

Deno.test('Iter2: Pre-Load Override - TSS 121 boundary', () => {
  // TSS > 120 triggers moderate pre-load
  assertWithinPercent(preLoadOverride(121, null, false, 400, 75), 512.5, 2);
});

Deno.test('Iter2: Pre-Load Override - TSS 120 no trigger', () => {
  // TSS = 120 does NOT trigger (> not >=)
  assertEquals(preLoadOverride(120, null, false, 400, 75), 400);
});

Deno.test('Iter2: Weekly Load Adjust - Low ratio', () => {
  const adj = weeklyLoadAdjust(0.50, 75);
  assertWithinAbsolute(adj.carb_add, -75, 1); // -1.0 * 75
  assertEquals(adj.prot_add, 0);
});

Deno.test('Iter2: Weekly Load Adjust - Below average', () => {
  const adj = weeklyLoadAdjust(0.75, 75);
  assertWithinAbsolute(adj.carb_add, -37.5, 1); // -0.5 * 75
  assertEquals(adj.prot_add, 0);
});

Deno.test('Iter2: Weekly Load Adjust - Normal', () => {
  const adj = weeklyLoadAdjust(1.00, 75);
  assertEquals(adj.carb_add, 0);
  assertEquals(adj.prot_add, 0);
});

Deno.test('Iter2: Weekly Load Adjust - Building', () => {
  const adj = weeklyLoadAdjust(1.15, 75);
  assertWithinAbsolute(adj.carb_add, 37.5, 1); // 0.5 * 75
  assertWithinAbsolute(adj.prot_add, 7.5, 1); // 0.1 * 75
});

Deno.test('Iter2: Weekly Load Adjust - High overreach', () => {
  const adj = weeklyLoadAdjust(1.35, 75);
  assertWithinAbsolute(adj.carb_add, 75, 1);
  assertWithinAbsolute(adj.prot_add, 15, 1);
});

Deno.test('Iter2: Weekly Load Adjust - Boundary 0.7 (in 0.7-0.9 bucket)', () => {
  const adj = weeklyLoadAdjust(0.70, 75);
  // ratio < 0.7 is false (0.7 is NOT < 0.7), so falls into 0.7-0.9 bucket
  assertWithinAbsolute(adj.carb_add, -37.5, 1);
});

Deno.test('Iter2: Weekly Load Adjust - Boundary 0.91 (neutral)', () => {
  const adj = weeklyLoadAdjust(0.91, 75);
  assertEquals(adj.carb_add, 0);
  assertEquals(adj.prot_add, 0);
});

Deno.test('Iter2: Weekly Load Adjust - Boundary 1.1 (neutral)', () => {
  const adj = weeklyLoadAdjust(1.10, 75);
  assertEquals(adj.carb_add, 0); // <= 1.1 is neutral
  assertEquals(adj.prot_add, 0);
});

Deno.test('Iter2: Weekly Load Adjust - Boundary 1.11 (building)', () => {
  const adj = weeklyLoadAdjust(1.11, 75);
  // 1.11 > 1.1 so falls in building bucket
  assertWithinAbsolute(adj.carb_add, 37.5, 1);
  assertWithinAbsolute(adj.prot_add, 7.5, 1);
});

Deno.test('Iter2: Phase Modifiers - BASE', () => {
  const mod = phaseModifier('base');
  assertEquals(mod.carb_mod, 1.0);
  assertEquals(mod.prot_mod, 1.0);
});

Deno.test('Iter2: Phase Modifiers - BUILD', () => {
  const mod = phaseModifier('build');
  assertWithinPercent(400 * mod.carb_mod, 432, 2);
  assertWithinPercent(130 * mod.prot_mod, 136.5, 2);
});

Deno.test('Iter2: Phase Modifiers - PEAK', () => {
  const mod = phaseModifier('peak');
  assertWithinPercent(400 * mod.carb_mod, 448, 2);
  assertWithinPercent(130 * mod.prot_mod, 143, 2);
});

Deno.test('Iter2: Phase Modifiers - TAPER', () => {
  const mod = phaseModifier('taper');
  assertWithinPercent(400 * mod.carb_mod, 352, 2);
  assertEquals(130 * mod.prot_mod, 130);
});

Deno.test('Iter2: Phase Modifiers - OFF_SEASON', () => {
  const mod = phaseModifier('off_season');
  assertWithinPercent(400 * mod.carb_mod, 320, 2);
  assertEquals(130 * mod.prot_mod, 130);
});

Deno.test('Iter2: Phase Modifiers - RACE_WEEK', () => {
  const mod = phaseModifier('race_week');
  assertEquals(mod.carb_mod, 1.0);
  assertEquals(mod.prot_mod, 1.0);
});

// ============================================================================
// ITERATION 3: UNIT TESTS
// ============================================================================

Deno.test('Iter3: Volume Tier - All tiers', () => {
  assertEquals(inferVolumeTier(3).tier, 'recreational');
  assertEquals(inferVolumeTier(3).base_neat, 0.30);
  assertEquals(inferVolumeTier(6).tier, 'moderate');
  assertEquals(inferVolumeTier(6).base_neat, 0.25);
  assertEquals(inferVolumeTier(10).tier, 'serious');
  assertEquals(inferVolumeTier(10).base_neat, 0.20);
  assertEquals(inferVolumeTier(15).tier, 'high_volume');
  assertEquals(inferVolumeTier(15).base_neat, 0.17);
  assertEquals(inferVolumeTier(20).tier, 'professional');
  assertEquals(inferVolumeTier(20).base_neat, 0.13);
  assertEquals(inferVolumeTier(null).tier, 'moderate');
  assertEquals(inferVolumeTier(null).base_neat, 0.25);
  assertEquals(inferVolumeTier(0).tier, 'recreational');
});

Deno.test('Iter3: Volume Tier - Exact boundaries', () => {
  assertEquals(inferVolumeTier(4.9).tier, 'recreational');
  assertEquals(inferVolumeTier(5.0).tier, 'moderate');
  assertEquals(inferVolumeTier(8.0).tier, 'serious');
  assertEquals(inferVolumeTier(12.0).tier, 'high_volume');
  assertEquals(inferVolumeTier(18.0).tier, 'professional');
});

Deno.test('Iter3: Day Type - Double session', () => {
  const sessions: SessionInput[] = [
    session('running', 1.0, 1, 0, 0),
    session('cycling', 1.0, 1, 0, 0),
  ];
  const result = getDayModifier(sessions, null);
  assertEquals(result.day_type, 'double');
  assertEquals(result.modifier, 1.15);
});

Deno.test('Iter3: Day Type - Training day', () => {
  const sessions: SessionInput[] = [session('running', 1.5, 1, 0, 0)];
  const result = getDayModifier(sessions, null);
  assertEquals(result.day_type, 'training');
  assertEquals(result.modifier, 1.10);
});

Deno.test('Iter3: Day Type - Rest after hard', () => {
  const result = getDayModifier([], 180);
  assertEquals(result.day_type, 'rest_after_hard');
  assertEquals(result.modifier, 0.90);
});

Deno.test('Iter3: Day Type - Regular rest', () => {
  const result = getDayModifier([], 50);
  assertEquals(result.day_type, 'rest');
  assertEquals(result.modifier, 1.00);
});

Deno.test('Iter3: Day Type - Short session is rest', () => {
  const sessions: SessionInput[] = [session('running', 0.5, 1, 0, 0)];
  const result = getDayModifier(sessions, 50);
  assertEquals(result.day_type, 'rest');
  assertEquals(result.modifier, 1.00);
});

Deno.test('Iter3: Day Type - Exactly 0.75hr is training', () => {
  const sessions: SessionInput[] = [session('running', 0.75, 1, 0, 0)];
  const result = getDayModifier(sessions, 50);
  assertEquals(result.day_type, 'training');
  assertEquals(result.modifier, 1.10);
});

Deno.test('Iter3: Day Type - Rest with null yesterday', () => {
  const result = getDayModifier([], null);
  assertEquals(result.day_type, 'rest');
  assertEquals(result.modifier, 1.00);
});

Deno.test('Iter3: NEAT - Serious/rest/desk', () => {
  assertWithinPercent(calculateNEAT(1908, 0.20, 1.00, 'desk'), 343, 5);
});

Deno.test('Iter3: NEAT - Serious/training/desk', () => {
  assertWithinPercent(calculateNEAT(1908, 0.20, 1.10, 'desk'), 378, 5);
});

Deno.test('Iter3: NEAT - Recreational/rest/active', () => {
  assertWithinPercent(calculateNEAT(1908, 0.30, 1.00, 'active'), 658, 5);
});

Deno.test('Iter3: NEAT - Pro/double/mixed', () => {
  // 0.13 * 1.15 * 1.00 = 0.1495
  assertWithinPercent(calculateNEAT(1908, 0.13, 1.15, 'mixed'), 285, 5);
});

Deno.test('Iter3: NEAT - Serious/rest after hard/desk', () => {
  assertWithinPercent(calculateNEAT(1908, 0.20, 0.90, 'desk'), 309, 5);
});

Deno.test('Iter3: NEAT - Very high (recreational/double/very_active)', () => {
  // 0.30 * 1.15 * 1.25 = 0.43125
  const neat = calculateNEAT(1908, 0.30, 1.15, 'very_active');
  assertWithinPercent(neat, 823, 5);
});

Deno.test('Iter3: NEAT - Very low (pro/rest after hard/desk)', () => {
  // 0.13 * 0.90 * 0.90 = 0.1053
  const neat = calculateNEAT(1908, 0.13, 0.90, 'desk');
  assertWithinPercent(neat, 201, 5);
});

Deno.test('Iter3: TDEE - Rest day convergence', () => {
  const result = calculateTDEE(1908, 343, 0, 300, 115, 75);
  assertWithinPercent(result.tdee, 2501, 5);
  assertWithinPercent(result.fat_g, 93, 15);
  assertWithinPercent(result.tef, 250, 5);
});

Deno.test('Iter3: TDEE - Fat at floor (pre-race)', () => {
  const result = calculateTDEE(1908, 378, 1050, 798, 159, 75);
  assertEquals(result.fat_g, 60); // 0.8 * 75 floor
  assertEquals(result.fat_at_floor, true);
  assertWithinPercent(result.tdee, 3773, 5);
});

Deno.test('Iter3: TDEE - Returns uncapped fat residual', () => {
  // 90min run, 1205 kcal session — F15 returns the raw residual (~209g,
  // ≈2.8 g/kg), UNROUNDED. The fat cap is not F15's job: assembly step 10b
  // caps at 30 %E of TDEE and reroutes the excess to carbohydrate (Q-014).
  const result = calculateTDEE(1908, 378, 1205, 369, 130, 75);
  assertWithinPercent(result.tdee, 3879, 10);
  assertWithinPercent(result.fat_g, 209.2, 1);
  assertEquals(result.fat_at_floor, false);
});

// ============================================================================
// ITERATION 3: LIFESTYLE VARIATION TESTS
// ============================================================================

Deno.test('Iter3: Lifestyle - All lifestyles same rest day', () => {
  // Rest day, no sessions, Serious tier, RMR 1908
  const desk = calculateTDEE(1908, calculateNEAT(1908, 0.20, 1.00, 'desk'), 0, 300, 115, 75);
  const mixed = calculateTDEE(1908, calculateNEAT(1908, 0.20, 1.00, 'mixed'), 0, 300, 115, 75);
  const active = calculateTDEE(1908, calculateNEAT(1908, 0.20, 1.00, 'active'), 0, 300, 115, 75);
  const vactive = calculateTDEE(1908, calculateNEAT(1908, 0.20, 1.00, 'very_active'), 0, 300, 115, 75);

  assertWithinPercent(desk.tdee, 2501, 5);
  assertWithinPercent(mixed.tdee, 2544, 5);
  assertWithinPercent(active.tdee, 2608, 5);
  assertWithinPercent(vactive.tdee, 2650, 5);
});

// ============================================================================
// ITERATION 4: UNIT TESTS
// ============================================================================

Deno.test('Iter4: FFM - From body fat', () => {
  assertWithinPercent(deriveFFM(75, 'male', 14.7), 64, 2);
});

Deno.test('Iter4: FFM - Male estimate', () => {
  assertWithinPercent(deriveFFM(75, 'male', null), 63.75, 2);
});

Deno.test('Iter4: FFM - Female estimate', () => {
  assertWithinPercent(deriveFFM(62, 'female', null), 48.36, 2);
});

Deno.test('Iter4: EA Check - OK', () => {
  const result = checkEnergyAvailability(4368, 1479, 64);
  assertWithinAbsolute(result.ea, 45.1, 1);
  assertEquals(result.status, 'OK');
});

Deno.test('Iter4: EA Check - Soft warning', () => {
  const result = checkEnergyAvailability(3500, 1000, 64);
  assertWithinAbsolute(result.ea, 39.1, 1);
  assertEquals(result.status, 'SOFT_WARNING');
});

Deno.test('Iter4: EA Check - Hard warning', () => {
  const result = checkEnergyAvailability(2500, 800, 64);
  assertWithinAbsolute(result.ea, 26.6, 1);
  assertEquals(result.status, 'HARD_WARNING');
});

Deno.test('Iter4: EA Check - Block', () => {
  const result = checkEnergyAvailability(1800, 900, 64);
  assertWithinAbsolute(result.ea, 14.1, 1);
  assertEquals(result.status, 'BLOCK');
});

Deno.test('Iter4: EA Check - No session', () => {
  const result = checkEnergyAvailability(1500, 0, 64);
  assertWithinAbsolute(result.ea, 23.4, 1);
  assertEquals(result.status, 'HARD_WARNING');
});

Deno.test('Iter4: EA Check - Boundary OK (45.0)', () => {
  assertEquals(checkEnergyAvailability(3780, 900, 64).status, 'OK');
});

Deno.test('Iter4: EA Check - Boundary SOFT_WARNING (30.0)', () => {
  assertEquals(checkEnergyAvailability(2720, 800, 64).status, 'SOFT_WARNING');
});

Deno.test('Iter4: EA Check - Boundary HARD_WARNING (20.0)', () => {
  assertEquals(checkEnergyAvailability(2180, 900, 64).status, 'HARD_WARNING');
});

Deno.test('Iter4: EA Override - Force to EA 30', () => {
  const result = eaOverride(250, 115, 60, 208, 64, 75);
  if ('block' in result) throw new Error('Should not block');
  assertEquals(result.adjusted, true);
  assertWithinPercent(result.carb, 269, 5);
  assertWithinPercent(result.fat, 66, 5);
  assertEquals(result.prot, 115);
});

Deno.test('Iter4: EA Override - Block when EA < 20', () => {
  const result = eaOverride(200, 100, 55, 543, 64, 75);
  assertEquals('block' in result, true);
});

Deno.test('Iter4: EA Override - No change when EA >= 45', () => {
  const result = eaOverride(500, 140, 120, 300, 64, 75);
  if ('block' in result) throw new Error('Should not block');
  assertEquals(result.adjusted, false);
});

Deno.test('Iter4: EA Override - No change when EA 30-45 (soft warning)', () => {
  const result = eaOverride(400, 130, 90, 200, 64, 75);
  if ('block' in result) throw new Error('Should not block');
  assertEquals(result.adjusted, false);
});

// ============================================================================
// ITERATION 4: MULTI-SESSION CARB COMPOUNDING
// ============================================================================

/** Helper: build an F22-resolved session for multiSessionCarbCompound */
function resolved(
  sport: Sport,
  intensity_factor: number,
  duration_hr: number,
  start_time?: string,
) {
  return { sport, intensity_factor, duration_hr, start_time: start_time ?? null };
}

Deno.test('Iter4: Multi-Session - Bike + Run compounding', () => {
  // Use pre-computed IFs to match spec values
  // bike IF=0.80, run IF=0.78 per spec
  // bike x1.0 + run x1.1, UNROUNDED (Q-002)
  const bikeCarb = carbDemand('cycling', 0.80, 2.0, 75);
  const runCarb = carbDemand('running', 0.78, 0.75, 75);

  const result = multiSessionCarbCompound(
    [resolved('cycling', 0.80, 2.0), resolved('running', 0.78, 0.75)],
    75,
    carbDemand,
  );

  assertWithinAbsolute(result.session_carb, bikeCarb * 1.0 + runCarb * 1.1, 1e-9);
  // Verify compounding happens: result > naive sum
  assertEquals(result.session_carb > bikeCarb + runCarb, true, 'Compounding should increase total');
  assertWithinAbsolute(result.prot_bump, 15, 1); // bike dur > 1hr: 0.2 * 75
});

Deno.test('Iter4: Multi-Session - Swim + Bike + Run triple', () => {
  const result = multiSessionCarbCompound(
    [
      resolved('swimming', zoneDistributionToIF(0.70, 0.20, 0.10), 0.5),
      resolved('cycling', zoneDistributionToIF(0.30, 0.40, 0.30), 2.0),
      resolved('running', zoneDistributionToIF(0.60, 0.30, 0.10), 1.0),
    ],
    75,
    carbDemand,
  );

  // Triple: swim x1.0 + bike x1.1 + run x1.21
  // Verify compounding: result > session_carb without any compounding
  assertEquals(result.session_carb > 200, true, 'Triple session should exceed 200g carbs');
  assertWithinAbsolute(result.prot_bump, 15, 1); // bike dur > 1hr
});

Deno.test('Iter4: Multi-Session - Strength + Run (strength not compounded)', () => {
  const if_ = zoneDistributionToIF(0.70, 0.20, 0.10);
  const result = multiSessionCarbCompound(
    [resolved('strength', if_, 1.0), resolved('running', if_, 1.5)],
    75,
    carbDemand,
  );

  // strength x1.0 (no compound), run x1.0 (1st endurance)
  // No compounding factor applied since run is first endurance session
  assertEquals(result.session_carb > 0, true);
  assertWithinAbsolute(result.prot_bump, 22.5, 1); // strength: 0.3 * 75
});

Deno.test('Iter4: Multi-Session - Sorted by start_time before compounding', () => {
  // Run listed first but starts in the evening — the morning bike must take
  // the x1.0 slot and the run the x1.1 slot (Q-002).
  const bike = resolved('cycling', 0.80, 2.0, '2026-08-14T06:00:00Z');
  const run = resolved('running', 0.78, 0.75, '2026-08-14T17:00:00Z');
  const listedLate = multiSessionCarbCompound([run, bike], 75, carbDemand);
  const listedEarly = multiSessionCarbCompound([bike, run], 75, carbDemand);
  assertEquals(listedLate.session_carb, listedEarly.session_carb);
});

Deno.test('Iter4: Multi-Session - Cap at 12g/kg', () => {
  // 5 endurance sessions: factors 1.0, 1.1, 1.21, 1.331, 1.464
  const hardIF = zoneDistributionToIF(0.20, 0.40, 0.40);
  const result = multiSessionCarbCompound(
    [
      resolved('running', hardIF, 3.0),
      resolved('cycling', hardIF, 3.0),
      resolved('running', hardIF, 3.0),
      resolved('cycling', hardIF, 3.0),
      resolved('running', hardIF, 3.0),
    ],
    75,
    carbDemand,
  );

  // Should be capped at 12 * 75 = 900
  assertEquals(result.session_carb <= 900, true);
});

// ============================================================================
// ITERATION 4: CARB CYCLING
// ============================================================================

Deno.test('Iter4: Carb Cycle - Qualifying easy day', () => {
  assertEquals(carbCycleAdjust(0.65, 0.75, true, 'base', 300, 75), 225); // 3.0 * 75
});

Deno.test('Iter4: Carb Cycle - IF too high', () => {
  assertEquals(carbCycleAdjust(0.85, 0.75, true, 'base', 300, 75), 300);
});

Deno.test('Iter4: Carb Cycle - Duration too long', () => {
  assertEquals(carbCycleAdjust(0.70, 1.5, true, 'base', 300, 75), 300);
});

Deno.test('Iter4: Carb Cycle - Not opted in', () => {
  assertEquals(carbCycleAdjust(0.70, 0.75, false, 'base', 300, 75), 300);
});

Deno.test('Iter4: Carb Cycle - Disabled in PEAK', () => {
  assertEquals(carbCycleAdjust(0.65, 0.75, true, 'peak', 300, 75), 300);
});

Deno.test('Iter4: Carb Cycle - Disabled in RACE_WEEK', () => {
  assertEquals(carbCycleAdjust(0.65, 0.75, true, 'race_week', 300, 75), 300);
});

Deno.test('Iter4: Carb Cycle - Allowed in BUILD', () => {
  assertEquals(carbCycleAdjust(0.65, 0.75, true, 'build', 300, 75), 225);
});

Deno.test('Iter4: Carb Cycle - Allowed in OFF_SEASON', () => {
  assertEquals(carbCycleAdjust(0.65, 0.75, true, 'off_season', 300, 75), 225);
});

Deno.test('Iter4: Carb Cycle - Allowed in TAPER', () => {
  assertEquals(carbCycleAdjust(0.65, 0.75, true, 'taper', 300, 75), 225);
});

Deno.test('Iter4: Carb Cycle - IF boundary 0.80 qualifies', () => {
  assertEquals(carbCycleAdjust(0.80, 0.75, true, 'base', 300, 75), 225);
});

Deno.test('Iter4: Carb Cycle - IF boundary 0.81 fails', () => {
  assertEquals(carbCycleAdjust(0.81, 0.75, true, 'base', 300, 75), 300);
});

Deno.test('Iter4: Carb Cycle - Duration boundary 1.25 qualifies', () => {
  assertEquals(carbCycleAdjust(0.70, 1.25, true, 'base', 300, 75), 225);
});

Deno.test('Iter4: Carb Cycle - Duration boundary 1.267 fails', () => {
  assertEquals(carbCycleAdjust(0.70, 1.267, true, 'base', 300, 75), 300);
});

// ============================================================================
// FULL PIPELINE: ITERATION 1 INTEGRATION TESTS
// ============================================================================

Deno.test('Pipeline Iter1: Rest day (no sessions)', () => {
  // Baseline carb 300; step 10b caps fat at 30 %E (83g) and reroutes the
  // excess kcal to carbohydrate → 322g. Energy is conserved (I10).
  const result = calculateDailyMacros(refInput());
  assertWithinPercent(result.carb_g, 322, 2);
  assertWithinPercent(result.prot_g, 115, 5);
  assertWithinPercent(result.fat_g, 83, 5);
  assertWithinPercent(result.tdee, 2501, 5);
  assertEquals(result.mode, 'prospective');
  assertEquals(result.algorithm_version, 'v6.0.0');
});

Deno.test('Pipeline Iter1: 90-min run', () => {
  // Zones 0.70/0.20/0.10 → IF ≈ 0.771 (spec assumed IF=0.74)
  // Pre-cap carb 376; the raw fat residual (~219g) is capped at 30 %E of
  // TDEE (133g) and the excess kcal reroutes to carbohydrate → 569g.
  const result = calculateDailyMacros(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
  }));
  assertWithinPercent(result.carb_g, 569, 2);
  assertWithinPercent(result.prot_g, 130, 5);
  assertWithinPercent(result.fat_g, 133, 5);
  assertWithinPercent(result.session_kcal, 1309, 5);
  assertEquals(result.ea_status !== null, true);
});

Deno.test('Pipeline Iter1: 4hr bike ride', () => {
  // Zones 0.60/0.30/0.10 → IF ≈ 0.791 (spec assumed IF=0.72)
  // Fat-cap redistribution pushes carb up to the 12 g/kg clamp (~899g).
  const result = calculateDailyMacros(refInput({
    sessions: [session('cycling', 4.0, 0.60, 0.30, 0.10)],
  }));
  assertWithinPercent(result.carb_g, 899, 2);
  assertWithinPercent(result.prot_g, 130, 5);
  assertWithinPercent(result.fat_g, 196, 5);
  assertWithinPercent(result.session_kcal, 3007, 5);
});

Deno.test('Pipeline Iter1: Strength session', () => {
  // Strength carb demand is a flat 27 g/hr (Q-003): baseline 300 + 27 = 327
  // pre-cap; step 10b redistribution lands carb at 382.
  const result = calculateDailyMacros(refInput({
    sessions: [session('strength', 1.0, 0.70, 0.20, 0.10)],
  }));
  assertWithinPercent(result.carb_g, 382, 2);
  assertWithinPercent(result.prot_g, 138, 5);
  assertWithinPercent(result.session_kcal, 386, 5);
});

Deno.test('Pipeline Iter1: Bike 1.25hr high IF', () => {
  const result = calculateDailyMacros(refInput({
    sessions: [session('cycling', 1.25, 0.20, 0.30, 0.50)],
  }));
  assertWithinPercent(result.carb_g, 579, 2);
  assertWithinPercent(result.prot_g, 130, 5);
});

Deno.test('Pipeline Iter1: Two sessions - protein bump override', () => {
  const result = calculateDailyMacros(refInput({
    sessions: [
      session('strength', 1.0, 0.70, 0.20, 0.10),
      session('running', 1.5, 0.70, 0.20, 0.10),
    ],
  }));
  // Protein bump = max(22.5, 15) = 22.5 (override not sum)
  // Baseline prot 115 + bump 22.5 = 137.5 -> 138 (rounded)
  assertWithinPercent(result.prot_g, 138, 5);
});

// ============================================================================
// FULL PIPELINE: ITERATION 2 INTEGRATION TESTS
// ============================================================================

Deno.test('Pipeline Iter2: Rest, no context (baseline)', () => {
  const result = calculateDailyMacros(refInput());
  assertWithinPercent(result.carb_g, 322, 2);
  assertWithinPercent(result.prot_g, 115, 5);
});

Deno.test('Pipeline Iter2: Hard intervals + build + overreach', () => {
  const result = calculateDailyMacros(refInput({
    sessions: [session('cycling', 1.25, 0.20, 0.30, 0.50)],
    training_phase: 'build',
    weekly_hours_ratio: 1.15,
  }));
  assertWithinPercent(result.carb_g, 565, 2);
  assertWithinPercent(result.prot_g, 145, 5);
});

Deno.test('Pipeline Iter2: Rest after long ride', () => {
  const result = calculateDailyMacros(refInput({
    sessions: [],
    yesterday_tss: 208,
    yesterday_hours_since: 16,
    weekly_hours_ratio: 1.05,
  }));
  assertWithinPercent(result.carb_g, 394, 10);
  assertWithinPercent(result.prot_g, 123, 10);
});

Deno.test('Pipeline Iter2: Pre-race all layers', () => {
  const result = calculateDailyMacros(refInput({
    sessions: [session('running', 1.5, 0.40, 0.40, 0.20)],
    yesterday_tss: 220,
    yesterday_hours_since: 20,
    tomorrow_is_race: true,
    training_phase: 'peak',
    weekly_hours_ratio: 1.25,
  }));
  assertWithinPercent(result.carb_g, 798, 10);
  assertWithinPercent(result.prot_g, 159, 10);
  assertEquals(result.fat_g, 60); // fat floor
});

Deno.test('Pipeline Iter2: Taper rest + de-load', () => {
  // Taper + de-load lands carb at 231 pre-cap, but step 10b lifts it back to
  // the energy-conserving 322 once fat hits the 30 %E ceiling.
  const result = calculateDailyMacros(refInput({
    sessions: [],
    training_phase: 'taper',
    weekly_hours_ratio: 0.75,
  }));
  assertWithinPercent(result.carb_g, 322, 2);
  assertWithinPercent(result.prot_g, 115, 5);
});

// ============================================================================
// FULL PIPELINE: ITERATION 4 INTEGRATION TESTS
// ============================================================================

Deno.test('Pipeline Iter4: Normal day has EA status', () => {
  const result = calculateDailyMacros(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
  }));
  assertEquals(result.ea !== null, true);
  assertEquals(result.ea_status !== null, true);
  // Step 10b conserves energy, so intake ≈ TDEE and EA sits comfortably in
  // the 30-45 band on a normal training day — never BLOCK.
  assertEquals(result.ea! >= 30, true, `EA was ${result.ea}`);
  assertEquals(result.ea_status !== 'BLOCK', true);
});

Deno.test('Pipeline Iter4: Carb cycling easy day', () => {
  const result = calculateDailyMacros(refInput({
    sessions: [session('running', 0.75, 1.0, 0, 0)], // Easy Z1 session, IF ~0.68
    carb_cycle_opt_in: true,
    training_phase: 'base',
  }));
  // Carb baseline reduced to 225g (3.0 * 75) + session carb ~26g = ~251
  // pre-cap. Step 10b then lifts carb to the energy-conserving 428.
  assertWithinPercent(result.carb_g, 428, 2);
});

Deno.test('Pipeline Iter4: Carb cycling converges under the fat cap', () => {
  const resultOptIn = calculateDailyMacros(refInput({
    sessions: [session('running', 0.75, 1.0, 0, 0)],
    carb_cycle_opt_in: true,
    training_phase: 'base',
  }));
  const resultNoOptIn = calculateDailyMacros(refInput({
    sessions: [session('running', 0.75, 1.0, 0, 0)],
    carb_cycle_opt_in: false,
    training_phase: 'base',
  }));
  // When the 30 %E fat cap binds, step 10b reroutes the excess to carb, so
  // both plans land on the same energy-conserving carb figure (I10). The
  // opt-in distinction itself is pinned by the carbCycleAdjust unit tests.
  assertEquals(resultNoOptIn.carb_g, resultOptIn.carb_g);
  assertEquals(resultNoOptIn.tdee, resultOptIn.tdee);
});

Deno.test('Pipeline Iter4: No sessions + carb_cycle_opt_in = no cycling', () => {
  const result = calculateDailyMacros(refInput({
    sessions: [],
    carb_cycle_opt_in: true,
  }));
  // No session to evaluate -> cycling does not fire. Same as plain rest day.
  assertWithinPercent(result.carb_g, 322, 2);
});

Deno.test('Pipeline Iter4: Brick with compounding', () => {
  const resultBrick = calculateDailyMacros(refInput({
    sessions: [
      session('cycling', 2.0, 0.30, 0.40, 0.30),
      session('running', 0.75, 0.60, 0.30, 0.10),
    ],
  }));
  // Carb should be higher than sum of individual sessions due to 1.1x on 2nd
  // Just verify it produces valid output
  assertEquals(resultBrick.carb_g > 300, true); // above baseline
  assertEquals(resultBrick.session_kcal > 0, true);
});

Deno.test('Pipeline Iter4: Different days produce different macros', () => {
  // Rest day
  const rest = calculateDailyMacros(refInput({ sessions: [] }));
  // Training day
  const training = calculateDailyMacros(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
  }));
  // Hard day
  const hard = calculateDailyMacros(refInput({
    sessions: [session('cycling', 3.0, 0.30, 0.40, 0.30)],
  }));

  // Each should be different
  assertEquals(rest.carb_g !== training.carb_g, true);
  assertEquals(training.carb_g !== hard.carb_g, true);
  assertEquals(rest.tdee < training.tdee, true);
  assertEquals(training.tdee < hard.tdee, true);
});

// ============================================================================
// VALIDATION TESTS
// ============================================================================

Deno.test('Validation: Invalid sex', () => {
  const err = validateInput({ ...refInput(), sex: 'other' as 'male' });
  assertEquals(err !== null, true);
});

Deno.test('Validation: Invalid age', () => {
  assertEquals(validateInput(refInput({ age: -5 })) !== null, true);
  assertEquals(validateInput(refInput({ age: 150 })) !== null, true);
});

Deno.test('Validation: Invalid weight', () => {
  assertEquals(validateInput(refInput({ weight_kg: 0 })) !== null, true);
});

Deno.test('Validation: Zone sum != 1.0', () => {
  const err = validateInput(refInput({
    sessions: [session('running', 1.0, 0.70, 0.20, 0.20)],
  }));
  assertEquals(err !== null, true);
  assertEquals(err!.includes('sum to 1.0'), true);
});

Deno.test('Validation: Valid input returns null', () => {
  assertEquals(validateInput(refInput()), null);
  assertEquals(validateInput(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
  })), null);
});

// ============================================================================
// EDGE CASES
// ============================================================================

Deno.test('Edge: All Iter 2-4 inputs null/default = same as Iter 1 rest day', () => {
  const result = calculateDailyMacros({
    sex: 'male',
    age: 34,
    weight_kg: 75,
    height_cm: 178,
    body_fat_pct: 14.7,
    sessions: [],
    lifestyle: 'desk',
    typical_weekly_hours: 10,
  });
  // Should produce rest day macros
  assertWithinPercent(result.carb_g, 322, 2);
  assertWithinPercent(result.prot_g, 115, 5);
});

Deno.test('Edge: Mode field passes through', () => {
  assertEquals(calculateDailyMacros(refInput({ mode: 'prospective' })).mode, 'prospective');
  assertEquals(calculateDailyMacros(refInput({ mode: 'retrospective' })).mode, 'retrospective');
});

Deno.test('Edge: Output includes all required fields', () => {
  const result = calculateDailyMacros(refInput());
  assertEquals(typeof result.carb_g, 'number');
  assertEquals(typeof result.prot_g, 'number');
  assertEquals(typeof result.fat_g, 'number');
  assertEquals(typeof result.tdee, 'number');
  assertEquals(typeof result.rmr, 'number');
  assertEquals(typeof result.session_kcal, 'number');
  assertEquals(typeof result.neat_kcal, 'number');
  assertEquals(typeof result.tef_kcal, 'number');
  assertEquals(typeof result.mode, 'string');
  assertEquals(typeof result.ea, 'number');
  assertEquals(typeof result.ea_status, 'string');
  assertEquals(result.energy_basis, 'as_computed');
  // Delta is always present: null on every path except a retrospective
  // recalculation with a prior prospective plan.
  assertEquals(result.delta, null);
  assertEquals(result.algorithm_version, 'v6.0.0');
});

Deno.test('Edge: Clamp ceiling - carb capped at 12g/kg', () => {
  // Create scenario that would push carb very high
  const result = calculateDailyMacros(refInput({
    sessions: [session('running', 1.5, 0.40, 0.40, 0.20)],
    yesterday_tss: 200,
    yesterday_hours_since: 16,
    tomorrow_is_race: true,
    training_phase: 'peak',
    weekly_hours_ratio: 1.35,
  }));
  // Carb should not exceed 12 * 75 = 900
  assertEquals(result.carb_g <= 900, true);
});

Deno.test('Edge: Clamp floor - carb at least 3g/kg', () => {
  const result = calculateDailyMacros(refInput({
    sessions: [],
    training_phase: 'off_season',
    weekly_hours_ratio: 0.50,
  }));
  // Carb should not go below 3 * 75 = 225
  assertEquals(result.carb_g >= 225, true);
});

Deno.test('Edge: Fat floor at 0.8 * weight', () => {
  // Pre-race scenario with very high carbs
  const result = calculateDailyMacros(refInput({
    sessions: [session('running', 1.5, 0.40, 0.40, 0.20)],
    tomorrow_is_race: true,
    training_phase: 'peak',
  }));
  assertEquals(result.fat_g >= 60, true); // 0.8 * 75 = 60
});

Deno.test('Edge: HARD_WARNING override keeps pre-override energy figures', () => {
  // Measured Garmin data (low BMR, NEAT 0) drives EA into the 20-30 band.
  // The override raises the macros to EA=30, but ea/tdee/tef stay the gate's
  // PRE-override decision values and energy_basis says so (Q-009).
  const result = calculateDailyMacros(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
    mode: 'retrospective',
    garmin_daily: { bmrKilocalories: 1000, activeKilocalories: 800 },
    garmin_activities: [{ activeKilocalories: 800, durationInSeconds: 5400 }],
  }));
  assertEquals(result.ea_status, 'HARD_WARNING');
  assertEquals(result.energy_basis, 'pre_override');
  assertEquals(result.ea! < 30, true, `EA was ${result.ea}`);
});

Deno.test('Edge: BLOCK-level EA throws (no fat-relax escape hatch)', () => {
  // EA < 20 refuses to produce a plan — the retired v4/v5 "relax fat" branch
  // is gone; the gate now throws.
  assertThrows(
    () =>
      calculateDailyMacros(refInput({
        sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
        mode: 'retrospective',
        garmin_daily: { bmrKilocalories: 1000, activeKilocalories: 1050 },
        garmin_activities: [{ activeKilocalories: 1050, durationInSeconds: 1800 }],
      })),
    Error,
    'Energy Availability too low',
  );
});

Deno.test('Edge: Retrospective mode with different inputs', () => {
  const prospective = calculateDailyMacros(refInput({
    sessions: [session('running', 1.5, 0.70, 0.20, 0.10)],
    mode: 'prospective',
  }));
  const retrospective = calculateDailyMacros(refInput({
    sessions: [session('running', 2.0, 0.70, 0.20, 0.10)], // longer duration
    mode: 'retrospective',
  }));
  // Different inputs should give different outputs
  assertEquals(prospective.carb_g !== retrospective.carb_g, true);
  assertEquals(prospective.session_kcal !== retrospective.session_kcal, true);
});
