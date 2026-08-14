/**
 * F27 recalculateAfterSync — the wrapper contract: retrospective plan,
 * delta vs the prospective baseline, and the calibration log row
 * (like-for-like formula kcal at the RESOLVED IF/duration).
 *
 * Run: deno test --allow-read --allow-env --node-modules-dir=none \
 *   supabase/functions/calculate-daily-macros/recalculate.test.ts
 */

import {
  assert,
  assertAlmostEquals,
  assertEquals,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { calculateDailyMacros } from './pipeline.ts';
import { recalculateAfterSync } from './recalculate.ts';
import type { DailyMacroInput } from './types.ts';

const referenceInput: DailyMacroInput = {
  sex: 'male',
  age: 34,
  weight_kg: 75,
  height_cm: 178,
  body_fat_pct: (1 - 64 / 75) * 100,
  lifestyle: 'desk',
  typical_weekly_hours: 10,
  training_phase: 'base',
  sessions: [{
    sport: 'running',
    duration_hr: 1.5,
    pct_conversational: 1,
    pct_tempo: 0,
    pct_allout: 0,
  }],
};

describe('recalculateAfterSync (F27)', () => {
  it('replaces the plan retrospectively and emits delta vs the prospective baseline', () => {
    const prospective = calculateDailyMacros({
      ...referenceInput,
      mode: 'prospective',
    });
    assertEquals(prospective.delta, null); // null off the recalc path

    const { plan } = recalculateAfterSync({
      ...referenceInput,
      garmin_activities: [{ activeKilocalories: 892, durationInSeconds: null }],
      prospective_plan: prospective,
    });

    assertEquals(plan.mode, 'retrospective');
    assert(plan.delta != null, 'recalc emits a delta');
    assertEquals(plan.delta!.session_kcal, plan.session_kcal - prospective.session_kcal);
    assertEquals(plan.sources.sessions[0].session_kcal, 'GARMIN');
  });

  it('writes a like-for-like calibration row: formula kcal at the resolved IF/duration', () => {
    const { logRow } = recalculateAfterSync({
      ...referenceInput,
      garmin_activities: [{ activeKilocalories: 892, durationInSeconds: null }],
    });

    assertEquals(logRow.sessions.length, 1);
    const s = logRow.sessions[0];
    assertEquals(s.kcal_source, 'GARMIN');
    assertEquals(s.garmin_kcal, 892);
    // Formula side priced at the SAME resolved IF (0.68 zones) and duration:
    // 11 * (0.68/0.75)^2 * 1.5 * 75
    assertAlmostEquals(s.formula_kcal, 11 * Math.pow(0.68 / 0.75, 2) * 1.5 * 75, 1e-6);
    assertEquals(logRow.ea_status_before, null); // no prospective plan passed
    assert(logRow.ea_status_after != null);
    assert(/^\d{2}:\d{2}:\d{2}$/.test(logRow.local_sync_time ?? ''));
  });

  it('a prospective run is NOT a recalc: no Garmin values leak in', () => {
    const plan = calculateDailyMacros({
      ...referenceInput,
      mode: 'prospective',
      garmin_activities: [{ activeKilocalories: 892, durationInSeconds: null }],
    });
    assertEquals(plan.sources.sessions[0].session_kcal, 'FORMULA');
    assertEquals(plan.delta, null);
  });
});
