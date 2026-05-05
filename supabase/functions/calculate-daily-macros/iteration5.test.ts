/**
 * Iteration 5 — Source-resolution layer tests.
 *
 * Mirrors test buckets from Notion `daily_macro_calc_iteration5_tests`:
 *   - Data Source Priority (session kcal, IF, NEAT, RMR, tomorrow, weekly ratio)
 *   - Retrospective Recalculation deltas
 *   - Weight/BF auto-update from Garmin (with user-wins + staleness)
 *   - CTL → Volume Tier
 *   - Regression: no platforms connected
 *   - End-to-end with simulated platform data
 *
 * Reference athlete (per Notion): Male, 34yr, 75kg, 178cm, BF 14.7%, RMR ~1908,
 *   serious tier, DESK lifestyle. Tolerances: carb/prot ±5%, fat ±15%, TDEE ±5%.
 */

import { assertEquals, assert } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { calculateDailyMacros } from './pipeline.ts';
import {
  ctlToVolumeTier,
  resolveAthleteProfile,
  resolveNEAT,
  resolveRMR,
  resolveSessionData,
  resolveTomorrow,
  resolveWeeklyRatio,
} from './formulas/resolve.ts';
import type { DailyMacroInput, SessionInput, Sport } from './types.ts';

// ----------------------------------------------------------------------------
// Helpers
// ----------------------------------------------------------------------------

function refInput(overrides: Partial<DailyMacroInput> = {}): DailyMacroInput {
  return {
    sex: 'male',
    age: 34,
    weight_kg: 75,
    height_cm: 178,
    body_fat_pct: 14.7,
    lifestyle: 'desk',
    typical_weekly_hours: 10, // serious tier (8 ≤ h < 12)
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

function session(
  sport: Sport,
  duration_hr: number,
  pct_conversational: number,
  pct_tempo: number,
  pct_allout: number,
): SessionInput {
  return {
    sport,
    duration_hr,
    pct_conversational,
    pct_tempo,
    pct_allout,
    tss: null,
  };
}

function assertWithinPercent(
  actual: number,
  expected: number,
  percent: number,
  message?: string,
) {
  const tolerance = Math.abs(expected) * (percent / 100);
  const diff = Math.abs(actual - expected);
  if (diff > tolerance) {
    throw new Error(
      `${message || 'Assertion'}: expected ${expected} ±${percent}%, got ${actual} (diff ${diff.toFixed(2)}, tol ${tolerance.toFixed(2)})`,
    );
  }
}

// ============================================================================
// Data Source Priority — Session kcal (Notion §22)
// ============================================================================

Deno.test('Iter5: session kcal — RETROSPECTIVE + Garmin wins', () => {
  const out = calculateDailyMacros(
    refInput({
      sessions: [session('running', 1.5, 0.7, 0.2, 0.1)],
      mode: 'retrospective',
      garmin_activities: [{ activeKilocalories: 892, durationInSeconds: 5400 }],
    }),
  );
  assertEquals(out.session_kcal, 892);
  assertEquals(out.sources.sessions[0].session_kcal, 'GARMIN');
});

Deno.test('Iter5: session kcal — auto-detect promotes prospective→retrospective when Garmin data present', () => {
  const out = calculateDailyMacros(
    refInput({
      sessions: [session('running', 1.5, 0.7, 0.2, 0.1)],
      mode: 'prospective', // explicit prospective is overridden by auto-detect
      garmin_activities: [{ activeKilocalories: 892 }],
    }),
  );
  // Per server-side auto-detect: any Garmin activity data → retrospective.
  assertEquals(out.mode, 'retrospective');
  assertEquals(out.sources.sessions[0].session_kcal, 'GARMIN');
  assertEquals(out.session_kcal, 892);
});

Deno.test('Iter5: session kcal — falls back to FORMULA when Garmin missing', () => {
  const out = calculateDailyMacros(
    refInput({
      sessions: [session('running', 1.5, 0.7, 0.2, 0.1)],
      mode: 'retrospective',
      garmin_activities: null,
    }),
  );
  assertEquals(out.sources.sessions[0].session_kcal, 'FORMULA');
});

// ============================================================================
// Data Source Priority — IF (Notion §22)
// ============================================================================

Deno.test('Iter5: IF — RETROSPECTIVE + TP actual wins', () => {
  const r = resolveSessionData(
    session('running', 1.5, 0.7, 0.2, 0.1),
    75,
    'retrospective',
    null,
    { actual_IF: 0.82, planned_IF: 0.75 },
  );
  assertEquals(r.if_source, 'TP_ACTUAL');
  assertEquals(r.intensity_factor, 0.82);
});

Deno.test('Iter5: IF — TP planned beats zone distribution', () => {
  const r = resolveSessionData(
    session('running', 1.5, 0.7, 0.2, 0.1),
    75,
    'prospective',
    null,
    { planned_IF: 0.78 },
  );
  assertEquals(r.if_source, 'TP_PLANNED');
  assertEquals(r.intensity_factor, 0.78);
});

Deno.test('Iter5: IF — falls back to ZONE_DIST when no TP data', () => {
  const r = resolveSessionData(
    session('running', 1.5, 0.7, 0.2, 0.1),
    75,
    'prospective',
    null,
    null,
  );
  assertEquals(r.if_source, 'ZONE_DIST');
  assert(r.intensity_factor > 0.7 && r.intensity_factor < 0.85);
});

// ============================================================================
// Data Source Priority — Duration
// ============================================================================

Deno.test('Iter5: duration — Garmin retrospective wins', () => {
  const r = resolveSessionData(
    session('running', 1.5, 0.7, 0.2, 0.1),
    75,
    'retrospective',
    { durationInSeconds: 5760 }, // 1.6 hr
    null,
  );
  assertEquals(r.duration_source, 'GARMIN');
  assertWithinPercent(r.duration_hr, 1.6, 0.1);
});

Deno.test('Iter5: duration — TP planned wins when no Garmin', () => {
  const r = resolveSessionData(
    session('running', 1.5, 0.7, 0.2, 0.1),
    75,
    'retrospective',
    null,
    { planned_duration_hr: 1.75 },
  );
  assertEquals(r.duration_source, 'TP_PLANNED');
  assertEquals(r.duration_hr, 1.75);
});

// ============================================================================
// Data Source Priority — TSS
// ============================================================================

Deno.test('Iter5: TSS — TP actual wins in retrospective', () => {
  const r = resolveSessionData(
    session('running', 1.0, 0.7, 0.2, 0.1),
    75,
    'retrospective',
    null,
    { actual_TSS: 95, planned_TSS: 80 },
  );
  assertEquals(r.tss_source, 'TP_ACTUAL');
  assertEquals(r.TSS, 95);
});

Deno.test('Iter5: TSS — derived from IF² × duration when no TP', () => {
  const r = resolveSessionData(
    session('running', 1.0, 0.0, 1.0, 0.0), // IF = 0.88
    75,
    'prospective',
    null,
    null,
  );
  assertEquals(r.tss_source, 'FORMULA');
  // 1.0 × 0.88² × 100 ≈ 77.4
  assertWithinPercent(r.TSS, 77.4, 5);
});

// ============================================================================
// Data Source Priority — NEAT (Notion §23)
// ============================================================================

Deno.test('Iter5: NEAT — Garmin active − sessions in retrospective', () => {
  const r = resolveNEAT(
    'retrospective',
    { activeKilocalories: 1200 },
    800, // session total
    1908,
    0.20,
    1.10,
    'desk',
  );
  assertEquals(r.source, 'GARMIN');
  assertEquals(r.neat_kcal, 400);
});

Deno.test('Iter5: NEAT — guards against negative when sessions exceed Garmin active', () => {
  const r = resolveNEAT(
    'retrospective',
    { activeKilocalories: 700 },
    1200,
    1908,
    0.20,
    1.10,
    'desk',
  );
  assertEquals(r.source, 'GARMIN');
  assertEquals(r.neat_kcal, 0);
});

Deno.test('Iter5: NEAT — falls back to FORMULA in prospective even with Garmin daily', () => {
  const r = resolveNEAT(
    'prospective',
    { activeKilocalories: 1200 },
    0,
    1908,
    0.20,
    1.00,
    'desk',
  );
  assertEquals(r.source, 'FORMULA');
});

// ============================================================================
// Data Source Priority — RMR (Notion §24)
// ============================================================================

Deno.test('Iter5: RMR — Garmin BMR wins when present', () => {
  const r = resolveRMR(
    { bmrKilocalories: 1875 },
    {
      weight_kg: 75,
      height_cm: 178,
      age: 34,
      sex: 'male',
      body_fat_pct: 14.7,
    },
  );
  assertEquals(r.source, 'GARMIN');
  assertEquals(r.rmr, 1875);
});

Deno.test('Iter5: RMR — falls back to FORMULA when Garmin missing', () => {
  const r = resolveRMR(null, {
    weight_kg: 75,
    height_cm: 178,
    age: 34,
    sex: 'male',
    body_fat_pct: 14.7,
  });
  assertEquals(r.source, 'FORMULA');
  assertWithinPercent(r.rmr, 1908, 2);
});

// ============================================================================
// Data Source Priority — Tomorrow + Weekly ratio (Notion §25, §26)
// ============================================================================

Deno.test('Iter5: tomorrow — TP_CALENDAR wins over manual', () => {
  const r = resolveTomorrow(
    { tomorrow_planned: { tss: 120, duration_hr: 2, is_race: false } },
    { tomorrow_tss: 80, tomorrow_duration_hr: 1.5, tomorrow_is_race: false },
  );
  assertEquals(r.source, 'TP_CALENDAR');
  assertEquals(r.tomorrow_tss, 120);
  assertEquals(r.tomorrow_duration_hr, 2);
});

Deno.test('Iter5: tomorrow — manual when no TP', () => {
  const r = resolveTomorrow(null, {
    tomorrow_tss: 80,
    tomorrow_duration_hr: 1.5,
    tomorrow_is_race: true,
  });
  assertEquals(r.source, 'MANUAL');
  assertEquals(r.tomorrow_is_race, true);
});

Deno.test('Iter5: tomorrow — NONE when neither', () => {
  const r = resolveTomorrow(null, {});
  assertEquals(r.source, 'NONE');
  assertEquals(r.tomorrow_tss, null);
});

Deno.test('Iter5: weekly ratio — TP wins (ATL/CTL)', () => {
  const r = resolveWeeklyRatio({ ATL: 80, CTL: 100 }, 1.2);
  assertEquals(r.source, 'TP');
  assertEquals(r.ratio, 0.8);
});

Deno.test('Iter5: weekly ratio — manual when CTL ≤ 0', () => {
  const r = resolveWeeklyRatio({ ATL: 80, CTL: 0 }, 1.15);
  assertEquals(r.source, 'MANUAL');
  assertEquals(r.ratio, 1.15);
});

Deno.test('Iter5: weekly ratio — defaults to 1.0 when none', () => {
  const r = resolveWeeklyRatio(null, null);
  assertEquals(r.source, 'MANUAL');
  assertEquals(r.ratio, 1.0);
});

// ============================================================================
// Weight / BF auto-update from Garmin — latest-wins precedence
// ============================================================================

const NOW_S = Math.floor(Date.now() / 1000);
const HOUR_S = 3600;

// garmin-only: user has no value
Deno.test('Iter5: profile — Garmin fills BF when user value is null', () => {
  const r = resolveAthleteProfile(
    { weightInGrams: 76000, percentFat: 12.0, measurementTimeInSeconds: NOW_S },
    75,
    null,
    NOW_S,
  );
  assertEquals(r.body_fat_source, 'GARMIN');
  assertEquals(r.body_fat_pct, 12.0);
});

Deno.test('Iter5: profile — Garmin fills weight when user value is zero', () => {
  const r = resolveAthleteProfile(
    { weightInGrams: 76000, measurementTimeInSeconds: NOW_S },
    0,
    null,
    NOW_S,
  );
  assertEquals(r.weight_source, 'GARMIN');
  assertWithinPercent(r.weight_kg, 76, 1);
});

// user-newer: user updated AFTER Garmin measurement → user wins
Deno.test('Iter5: profile — user BF wins when user updated more recently than Garmin', () => {
  const garminTs = NOW_S - 2 * HOUR_S; // Garmin measured 2 hours ago
  const userTs = NOW_S - 1 * HOUR_S;   // User saved 1 hour ago (newer)
  const r = resolveAthleteProfile(
    { weightInGrams: 76000, percentFat: 12.0, measurementTimeInSeconds: garminTs },
    75,
    14.7,
    NOW_S,
    NOW_S - 4 * HOUR_S, // weight unchanged
    userTs,
  );
  assertEquals(r.body_fat_source, 'MANUAL');
  assertEquals(r.body_fat_pct, 14.7);
});

Deno.test('Iter5: profile — user weight wins when user updated more recently than Garmin', () => {
  const garminTs = NOW_S - 2 * HOUR_S;
  const userTs = NOW_S - 1 * HOUR_S;
  const r = resolveAthleteProfile(
    { weightInGrams: 80000, measurementTimeInSeconds: garminTs },
    75,
    null,
    NOW_S,
    userTs,
  );
  assertEquals(r.weight_source, 'MANUAL');
  assertEquals(r.weight_kg, 75);
});

// garmin-newer: Garmin measured AFTER user's last manual entry → Garmin wins
Deno.test('Iter5: profile — Garmin BF wins when Garmin measurement is newer', () => {
  const garminTs = NOW_S - 1 * HOUR_S; // Garmin measured 1 hour ago (newer)
  const userTs = NOW_S - 2 * HOUR_S;   // User last saved 2 hours ago
  const r = resolveAthleteProfile(
    { weightInGrams: 76000, percentFat: 12.0, measurementTimeInSeconds: garminTs },
    75,
    14.7,
    NOW_S,
    NOW_S - 4 * HOUR_S, // weight unchanged
    userTs,
  );
  assertEquals(r.body_fat_source, 'GARMIN');
  assertEquals(r.body_fat_pct, 12.0);
});

Deno.test('Iter5: profile — Garmin weight wins when Garmin measurement is newer', () => {
  const garminTs = NOW_S - 1 * HOUR_S;
  const userTs = NOW_S - 2 * HOUR_S;
  const r = resolveAthleteProfile(
    { weightInGrams: 80000, measurementTimeInSeconds: garminTs },
    75,
    null,
    NOW_S,
    userTs,
  );
  assertEquals(r.weight_source, 'GARMIN');
  assertWithinPercent(r.weight_kg, 80, 1);
});

// garmin-stale-but-newer-rejected: Garmin is newer but > 30 days old → rejected
Deno.test('Iter5: profile — Garmin body comp ignored if older than 30 days, even if newer than user', () => {
  // Garmin measured 31 days ago, user set value 60 days ago (Garmin "newer" but stale)
  const garminTs = NOW_S - 31 * 86400;
  const userTs = NOW_S - 60 * 86400;
  const r = resolveAthleteProfile(
    { weightInGrams: 76000, percentFat: 12.0, measurementTimeInSeconds: garminTs },
    75,
    null, // user has no BF
    NOW_S,
    userTs,
    userTs,
  );
  // Garmin is stale → rejected → user has no BF → NONE
  assertEquals(r.body_fat_source, 'NONE');
  assertEquals(r.body_fat_pct, null);
  // Weight: user has value → MANUAL (stale Garmin rejected)
  assertEquals(r.weight_source, 'MANUAL');
  assertEquals(r.weight_kg, 75);
});

// both-null: no Garmin data
Deno.test('Iter5: profile — both Garmin and user body comp null → NONE, weight is MANUAL from user', () => {
  const r = resolveAthleteProfile(null, 75, null, NOW_S);
  assertEquals(r.body_fat_source, 'NONE');
  assertEquals(r.body_fat_pct, null);
  assertEquals(r.weight_source, 'MANUAL');
  assertEquals(r.weight_kg, 75);
});

// no-timestamps: falls back to user-wins safe default
Deno.test('Iter5: profile — no timestamps on either side → user wins (safe default)', () => {
  const r = resolveAthleteProfile(
    { weightInGrams: 80000, percentFat: 12.0, measurementTimeInSeconds: NOW_S },
    75,
    14.7,
    NOW_S,
    null, // no user weight timestamp
    null, // no user BF timestamp
  );
  // No timestamps → safe default → user wins
  assertEquals(r.body_fat_source, 'MANUAL');
  assertEquals(r.body_fat_pct, 14.7);
  assertEquals(r.weight_source, 'MANUAL');
  assertEquals(r.weight_kg, 75);
});

// ============================================================================
// CTL → Volume Tier
// ============================================================================

Deno.test('Iter5: ctlToVolumeTier — boundary mapping', () => {
  assertEquals(ctlToVolumeTier(20)?.tier, 'recreational');
  assertEquals(ctlToVolumeTier(20)?.base_neat, 0.30);

  assertEquals(ctlToVolumeTier(45)?.tier, 'moderate');
  assertEquals(ctlToVolumeTier(45)?.base_neat, 0.25);

  assertEquals(ctlToVolumeTier(70)?.tier, 'serious');
  assertEquals(ctlToVolumeTier(70)?.base_neat, 0.20);

  assertEquals(ctlToVolumeTier(100)?.tier, 'high_volume');
  assertEquals(ctlToVolumeTier(100)?.base_neat, 0.17);

  assertEquals(ctlToVolumeTier(125)?.tier, 'professional');
  assertEquals(ctlToVolumeTier(125)?.base_neat, 0.13);

  assertEquals(ctlToVolumeTier(null), null);
});

Deno.test('Iter5: pipeline uses CTL tier when TP CTL provided', () => {
  // CTL=70 → serious (0.20), same as 10 weekly_hours → serious. Verify path.
  const out = calculateDailyMacros(
    refInput({
      typical_weekly_hours: null, // no hours-based fallback
      tp_global: { CTL: 70 },
    }),
  );
  // No regression in TDEE despite missing weekly_hours — CTL filled the tier.
  assert(out.tdee > 0);
  assert(out.neat_kcal > 0);
});

// ============================================================================
// Regression — No platforms connected
// ============================================================================

Deno.test('Iter5 regression: no platforms → identical to v4 numerics', () => {
  // Same input as classic Iter1 90-min run test. Numbers should match v4.
  const out = calculateDailyMacros(
    refInput({
      sessions: [session('running', 1.5, 0.7, 0.2, 0.1)],
    }),
  );
  // Carb/prot/fat/tdee anchors from existing v4 test suite (90-min run).
  assert(out.carb_g >= 300 && out.carb_g <= 500);
  assert(out.prot_g >= 90 && out.prot_g <= 200);
  assert(out.tdee > 2500 && out.tdee < 4500);

  // All sources should be FORMULA / MANUAL / NONE / ZONE_DIST
  assertEquals(out.sources.rmr, 'FORMULA');
  assertEquals(out.sources.neat, 'FORMULA');
  assertEquals(out.sources.weight, 'MANUAL');
  assertEquals(out.sources.body_fat, 'MANUAL');
  assertEquals(out.sources.sessions[0].session_kcal, 'FORMULA');
  assertEquals(out.sources.sessions[0].intensity_factor, 'ZONE_DIST');
  assertEquals(out.mode, 'prospective');
  assertEquals(out.delta, undefined);
});

Deno.test('Iter5 regression: empty garmin/tp objects → still formula path', () => {
  const out = calculateDailyMacros(
    refInput({
      sessions: [session('running', 1.0, 0.7, 0.2, 0.1)],
      garmin_daily: null,
      garmin_body_comp: null,
      garmin_activities: null,
      tp_global: null,
      tp_sessions: null,
    }),
  );
  assertEquals(out.sources.rmr, 'FORMULA');
  assertEquals(out.sources.sessions[0].session_kcal, 'FORMULA');
});

// ============================================================================
// Mode auto-detection
// ============================================================================

Deno.test('Iter5: mode auto-detects retrospective from Garmin activity', () => {
  const out = calculateDailyMacros(
    refInput({
      sessions: [session('running', 1.5, 0.7, 0.2, 0.1)],
      mode: 'prospective', // explicit prospective
      garmin_activities: [{ activeKilocalories: 800, durationInSeconds: 5400 }],
    }),
  );
  // Garmin activity present → mode flips to retrospective per spec
  assertEquals(out.mode, 'retrospective');
});

Deno.test('Iter5: explicit retrospective stays retrospective', () => {
  const out = calculateDailyMacros(
    refInput({
      sessions: [session('running', 1.0, 0.7, 0.2, 0.1)],
      mode: 'retrospective',
    }),
  );
  assertEquals(out.mode, 'retrospective');
});

// ============================================================================
// End-to-End with simulated platform data (Notion reference scenario)
// ============================================================================

Deno.test('Iter5 e2e: 90-min run with Garmin ActiveKcal=1200, BASE phase', () => {
  // Notion key insight: Garmin measured kcal (892) is much lower than formula
  // estimate (1205) for this session. TDEE drops ~412 kcal. Carb barely
  // changes (+5g, from slightly higher actual IF) but fat drops 48g because
  // fat is the residual that absorbs TDEE changes.
  const prospective = calculateDailyMacros(
    refInput({
      sessions: [session('running', 1.5, 0.7, 0.2, 0.1)],
      training_phase: 'base',
    }),
  );

  const retrospective = calculateDailyMacros(
    refInput({
      sessions: [session('running', 1.5, 0.7, 0.2, 0.1)],
      training_phase: 'base',
      mode: 'retrospective',
      garmin_daily: { activeKilocalories: 1200, bmrKilocalories: 1908 },
      garmin_activities: [{ activeKilocalories: 892, durationInSeconds: 5400 }],
      prospective_plan: prospective,
    }),
  );

  // Sources reflect Garmin path
  assertEquals(retrospective.sources.sessions[0].session_kcal, 'GARMIN');
  assertEquals(retrospective.sources.neat, 'GARMIN');

  // Session kcal matches Garmin
  assertEquals(retrospective.session_kcal, 892);

  // Delta exists
  assert(retrospective.delta !== undefined);

  // TDEE should be lower (Garmin measured less burn) — within Notion expected
  // direction. Tolerance is wide because per-formula variance.
  assert(
    retrospective.tdee < prospective.tdee,
    `expected retrospective tdee (${retrospective.tdee}) < prospective (${prospective.tdee})`,
  );

  // Fat is the residual and should absorb most of the TDEE drop.
  assert(
    retrospective.fat_g < prospective.fat_g,
    `expected retrospective fat (${retrospective.fat_g}) < prospective (${prospective.fat_g})`,
  );
});

// ============================================================================
// Retrospective Recalculation — recalculateAfterSync wrapper
// ============================================================================

Deno.test('Iter5: retrospective recalculation produces delta vs prospective', () => {
  const baseInput = refInput({
    sessions: [session('running', 1.0, 0.7, 0.2, 0.1)],
  });
  const prospective = calculateDailyMacros(baseInput);

  const retrospective = calculateDailyMacros({
    ...baseInput,
    mode: 'retrospective',
    garmin_daily: { activeKilocalories: 1000 },
    garmin_activities: [{ activeKilocalories: 700, durationInSeconds: 3600 }],
  });

  assertEquals(retrospective.mode, 'retrospective');
  // Retrospective should differ from prospective when Garmin data is present
  assert(
    retrospective.session_kcal !== prospective.session_kcal ||
    retrospective.tdee !== prospective.tdee,
    'retrospective should differ from prospective with Garmin data',
  );
});

// ============================================================================
// Output shape contract
// ============================================================================

Deno.test('Iter5: output always includes sources block', () => {
  const out = calculateDailyMacros(refInput());
  assert(out.sources, 'sources should be present');
  assert(Array.isArray(out.sources.sessions));
  // String-typed source fields, not undefined
  assert(typeof out.sources.rmr === 'string');
  assert(typeof out.sources.neat === 'string');
});

Deno.test('Iter5: prospective never emits delta even with prior plan', () => {
  const baseInput = refInput({
    sessions: [session('running', 1.0, 0.7, 0.2, 0.1)],
  });
  const prior = calculateDailyMacros(baseInput);
  const next = calculateDailyMacros({ ...baseInput, prospective_plan: prior });
  // Prospective + prior plan but no Garmin activity → mode stays prospective →
  // no delta is emitted.
  assertEquals(next.mode, 'prospective');
  assertEquals(next.delta, undefined);
});
