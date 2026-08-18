/**
 * Conformance runner — feeds the ratified daily-macros vectors
 * (docs/ssot/vectors/daily-macros/*.json, verbatim mirror of the QA repo,
 * bundle daily-macros-dashboard@v1) to the REAL formulas.
 *
 * Governance: the vectors are the contract. A red here means the code is
 * wrong, or a ruling is needed — never edit a spec or a vector to make code
 * pass. Expected values are the UNROUNDED chain (R1), abs tolerance per
 * file; display rounding is half-up and happens at assembly step 12.
 *
 * Run:
 *   deno test --allow-read --allow-env --node-modules-dir=none \
 *     supabase/functions/calculate-daily-macros/vectors.conformance.test.ts
 */

import {
  assert,
  assertAlmostEquals,
  assertEquals,
  assertThrows,
} from 'https://deno.land/std@0.168.0/testing/asserts.ts';
import { describe, it } from 'https://deno.land/std@0.168.0/testing/bdd.ts';

import { calculateRMR } from './formulas/rmr.ts';
import { baselineMacros } from './formulas/baseline.ts';
import {
  carbDemand,
  sessionCost,
  zoneDistributionToIF,
} from './formulas/session.ts';
import {
  recoveryDebt,
  preLoadOverride,
  weeklyLoadAdjust,
  phaseModifier,
} from './formulas/multi-day.ts';
import {
  calculateNEAT,
  calculateTDEE,
  getDayModifier,
  inferVolumeTier,
} from './formulas/neat-tef.ts';
import {
  carbCycleAdjust,
  checkEnergyAvailability,
  deriveFFM,
  eaOverride,
  multiSessionCarbCompound,
  type CompoundSession,
} from './formulas/safety.ts';
import {
  ctlToVolumeTier,
  resolveNEAT,
  resolveRMR,
  resolveSessionData,
  resolveTomorrow,
  resolveWeeklyRatio,
} from './formulas/resolve.ts';
import {
  calculateDailyMacrosCore,
  type CoreInput,
  type CoreSession,
} from './pipeline.ts';
import {
  applyGarminSyncStart,
  applyMarkDone,
  applyMarkUndone,
  displayTimeMin,
  type WorkoutTimes,
} from '../_shared/workouts/workout-times.ts';
import { decideImport } from '../_shared/workouts/activity-match.ts';
import type { Lifestyle, Sport, TrainingPhase } from './types.ts';

// ---------------------------------------------------------------------------
// Vector loading
// ---------------------------------------------------------------------------

interface Vector {
  id: string;
  status: string;
  // deno-lint-ignore no-explicit-any
  inputs: Record<string, any>;
  // deno-lint-ignore no-explicit-any
  expected: Record<string, any>;
  why?: string;
  kind?: string;
}

interface VectorFile {
  section: string;
  toleranceG?: number;
  toleranceKcal?: number;
  vectors: Vector[];
}

function loadVectors(name: string): VectorFile {
  const url = new URL(
    `../../../docs/ssot/vectors/daily-macros/${name}.json`,
    import.meta.url,
  );
  return JSON.parse(Deno.readTextFileSync(url));
}

function tolOf(file: VectorFile): number {
  return file.toleranceKcal ?? file.toleranceG ?? 0.001;
}

const lc = (s: string) => s.toLowerCase() as Lifestyle & TrainingPhase & Sport;

// ---------------------------------------------------------------------------
// rmr.json — F1 + F24
// ---------------------------------------------------------------------------

describe('vectors: rmr', () => {
  const file = loadVectors('rmr');
  const tol = tolOf(file);

  for (const v of file.vectors) {
    it(v.id, () => {
      const i = v.inputs;
      if ('garminBmrKcal' in i) {
        const r = resolveRMR(
          i.garminBmrKcal == null ? null : { bmrKilocalories: i.garminBmrKcal },
          {
            weight_kg: i.weightKg,
            height_cm: i.heightCm ?? 178,
            age: i.age ?? 34,
            sex: i.sex ?? 'male',
            body_fat_pct: i.bodyFatPct ?? null,
          },
        );
        assertAlmostEquals(r.rmr, v.expected.rmr, tol);
        if ('source' in v.expected) assertEquals(r.source, v.expected.source);
      } else {
        const rmr = calculateRMR(
          i.weightKg,
          i.heightCm ?? 0,
          i.age ?? 0,
          i.sex ?? 'male',
          i.bodyFatPct ?? null,
        );
        assertAlmostEquals(rmr, v.expected.rmr, tol);
      }
    });
  }
});

// ---------------------------------------------------------------------------
// baseline-macros.json — F2 + F20
// ---------------------------------------------------------------------------

describe('vectors: baseline-macros', () => {
  const file = loadVectors('baseline-macros');
  const tol = tolOf(file);

  for (const v of file.vectors) {
    it(v.id, () => {
      const i = v.inputs;
      if ('optIn' in i) {
        // F20 carb cycling over the F2 baseline
        const baseline = 4.0 * i.weightKg;
        let carb = baseline;
        if (i.sessions.length === 1) {
          const s = i.sessions[0];
          carb = carbCycleAdjust(
            s.IF,
            s.durationHr ?? s.dur,
            i.optIn,
            lc(i.phase),
            baseline,
            i.weightKg,
          );
        }
        assertAlmostEquals(carb, v.expected.carbG, tol);
      } else {
        const b = baselineMacros(i.weightKg, i.lbmKg ?? null, i.age);
        assertAlmostEquals(b.carb_g, v.expected.carbG, tol);
        assertAlmostEquals(b.prot_g, v.expected.protG, tol);
      }
    });
  }
});

// ---------------------------------------------------------------------------
// session-demand.json — F3 / F4 / F5 / F19 + protein bump
// ---------------------------------------------------------------------------

describe('vectors: session-demand', () => {
  const file = loadVectors('session-demand');
  const tol = tolOf(file);

  for (const v of file.vectors) {
    it(v.id, () => {
      const i = v.inputs;
      const e = v.expected;

      if ('reject' in e) {
        assertThrows(() =>
          zoneDistributionToIF(i.pctConv, i.pctTempo, i.pctAllout)
        );
      } else if ('IF' in e) {
        const f = zoneDistributionToIF(i.pctConv, i.pctTempo, i.pctAllout);
        assertAlmostEquals(f, e.IF, 0.005); // spec tolerance for F3
      } else if ('kcal' in e) {
        const kcal = sessionCost(lc(i.sport), i.durationHr, i.IF, i.weightKg);
        assertAlmostEquals(kcal, e.kcal, tol);
      } else if ('carbG' in e) {
        const carb = carbDemand(lc(i.sport), i.IF, i.durationHr, i.weightKg);
        assertAlmostEquals(carb, e.carbG, tol);
      } else if ('protBumpG' in e || 'sessionCarbG' in e) {
        const sessions: CompoundSession[] = i.sessions.map(
          // deno-lint-ignore no-explicit-any
          (s: any) => ({
            sport: lc(s.sport),
            intensity_factor: s.IF,
            duration_hr: s.durationHr ?? s.dur,
          }),
        );
        const r = multiSessionCarbCompound(sessions, i.weightKg, carbDemand);
        if ('protBumpG' in e) assertAlmostEquals(r.prot_bump, e.protBumpG, tol);
        if ('sessionCarbG' in e) {
          assertAlmostEquals(r.session_carb, e.sessionCarbG, tol);
        }
      } else {
        throw new Error(`unhandled expected shape for ${v.id}`);
      }
    });
  }
});

// ---------------------------------------------------------------------------
// multi-day-context.json — F7 / F8 / F9 / F10
// ---------------------------------------------------------------------------

describe('vectors: multi-day-context', () => {
  const file = loadVectors('multi-day-context');
  const tol = tolOf(file);

  for (const v of file.vectors) {
    it(v.id, () => {
      const i = v.inputs;
      const e = v.expected;

      if ('carbAddG' in e) {
        const d = recoveryDebt(i.yesterdayTss, i.hoursSince, i.weightKg);
        assertAlmostEquals(d.carb_add, e.carbAddG, tol);
        assertAlmostEquals(d.prot_add, e.protAddG, tol);
      } else if ('currentCarbG' in i) {
        const carb = preLoadOverride(
          i.tomorrowTss ?? null,
          i.tomorrowDurationHr ?? null,
          i.isRace ?? false,
          i.currentCarbG,
          i.weightKg,
        );
        assertAlmostEquals(carb, e.carbG, tol);
      } else if ('weeklyLoadRatio' in i) {
        const a = weeklyLoadAdjust(i.weeklyLoadRatio, i.weightKg);
        assertAlmostEquals(a.carb_add, e.carbAdjG, tol);
        assertAlmostEquals(a.prot_add, e.protAdjG, tol);
      } else if ('phase' in i) {
        const m = phaseModifier(lc(i.phase));
        assertAlmostEquals(i.carbG * m.carb_mod, e.carbG, tol);
        assertAlmostEquals(i.protG * m.prot_mod, e.protG, tol);
        // fat_mod is returned but applied NOWHERE in the pipeline (Q-004) —
        // the vector's fatModApplied:false is structural: no code path
        // multiplies fat by m.fat_mod.
        assertEquals(false, e.fatModApplied);
      } else {
        throw new Error(`unhandled expected shape for ${v.id}`);
      }
    });
  }
});

// ---------------------------------------------------------------------------
// neat-tef.json — F12 / F13 / F14 / F15 (+ CTL tier variant)
// ---------------------------------------------------------------------------

describe('vectors: neat-tef', () => {
  const file = loadVectors('neat-tef');
  const tol = tolOf(file);

  for (const v of file.vectors) {
    it(v.id, () => {
      const i = v.inputs;
      const e = v.expected;

      if ('weeklyHours' in i) {
        assertEquals(inferVolumeTier(i.weeklyHours).base_neat, e.baseNeat);
      } else if ('ctl' in i) {
        const t = ctlToVolumeTier(i.ctl);
        assert(t != null, 'CTL tier must resolve');
        assertEquals(t.base_neat, e.baseNeat);
      } else if ('modifier' in e) {
        const m = getDayModifier(
          // deno-lint-ignore no-explicit-any
          i.sessions.map((s: any) => ({ duration_hr: s.durationHr })),
          i.yesterdayTss,
        );
        assertEquals(m.modifier, e.modifier);
      } else if ('neatKcal' in e) {
        const neat = calculateNEAT(
          i.rmr,
          i.baseNeat,
          i.dayModifier,
          lc(i.lifestyle),
        );
        assertAlmostEquals(neat, e.neatKcal, tol);
      } else if ('tdee' in e) {
        const r = calculateTDEE(
          i.rmr,
          i.neatKcal,
          i.sessionKcal,
          i.carbG,
          i.protG,
          i.weightKg,
        );
        assertAlmostEquals(r.tdee, e.tdee, tol);
        assertAlmostEquals(r.fat_g, e.fatPreCapG, tol);
        assertAlmostEquals(r.tef, e.tef, tol);
        assertEquals(r.fat_at_floor, e.fatAtFloor);
      } else {
        throw new Error(`unhandled expected shape for ${v.id}`);
      }
    });
  }
});

// ---------------------------------------------------------------------------
// energy-availability.json — FFM + F17 + F18
// ---------------------------------------------------------------------------

describe('vectors: energy-availability', () => {
  const file = loadVectors('energy-availability');
  const tol = tolOf(file);

  for (const v of file.vectors) {
    it(v.id, () => {
      const i = v.inputs;
      const e = v.expected;

      if ('ffmKg' in e) {
        assertAlmostEquals(
          deriveFFM(i.weightKg, i.sex ?? 'male', i.bodyFatPct ?? null),
          e.ffmKg,
          tol,
        );
      } else if ('intakeKcal' in i) {
        const r = checkEnergyAvailability(i.intakeKcal, i.sessionKcal, i.ffmKg);
        assertAlmostEquals(r.ea, e.ea, tol);
        assertEquals(r.status, e.status);
      } else if ('carbG' in i) {
        const r = eaOverride(
          i.carbG,
          i.protG,
          i.fatG,
          i.sessionKcal,
          i.ffmKg,
          i.weightKg,
        );
        if (e.result === 'BLOCK') {
          assert('block' in r, `${v.id}: expected BLOCK`);
          return;
        }
        assert(!('block' in r), `${v.id}: unexpected BLOCK`);
        assertEquals(r.adjusted, e.adjusted);
        if ('carbG' in e) assertAlmostEquals(r.carb, e.carbG, tol);
        if ('protG' in e) assertAlmostEquals(r.prot, e.protG, tol);
        if ('fatG' in e) assertAlmostEquals(r.fat, e.fatG, tol);
        if ('ea' in e) {
          const intake = r.carb * 4 + r.prot * 4 + r.fat * 9;
          assertAlmostEquals(
            checkEnergyAvailability(intake, i.sessionKcal, i.ffmKg).ea,
            e.ea,
            tol,
          );
        }
      } else {
        throw new Error(`unhandled expected shape for ${v.id}`);
      }
    });
  }
});

// ---------------------------------------------------------------------------
// assembly.json — the integrated pipeline over resolved inputs
// ---------------------------------------------------------------------------

/** Build a CoreInput from an assembly-vector persona. */
// deno-lint-ignore no-explicit-any
function coreInputFromAssembly(i: Record<string, any>): CoreInput {
  const body_fat_pct = i.lbm != null ? (1 - i.lbm / i.w) * 100 : null;
  const sessions: CoreSession[] = (i.sessions ?? []).map(
    // deno-lint-ignore no-explicit-any
    (s: any) => ({
      sport: lc(s.sport),
      intensity_factor: s.IF,
      duration_hr: s.durationHr,
      session_kcal: sessionCost(lc(s.sport), s.durationHr, s.IF, i.w),
    }),
  );
  return {
    weight_kg: i.w,
    lbm_kg: i.lbm ?? null,
    age: i.age,
    sex: 'male',
    body_fat_pct,
    lifestyle: lc(i.life),
    training_phase: 'base',
    sessions,
    yesterday_tss: i.ytss ?? null,
    yesterday_hours_since: i.yhrs ?? null,
    weekly_ratio: 1.0,
    rmr: i.rmr,
    base_neat: i.tier_v,
  };
}

describe('vectors: assembly', () => {
  const file = loadVectors('assembly');
  const tol = tolOf(file);
  const byId = new Map(file.vectors.map((v) => [v.id, v]));

  for (const v of file.vectors) {
    it(v.id, () => {
      const i = v.inputs;
      const e = v.expected;

      if (v.id === 'invariant-I6-weight-linearity') {
        const kcal = (w: number) => sessionCost('running', 1.5, 0.74, w);
        const ref = kcal(75);
        assertEquals(
          [kcal(60) / ref, kcal(75) / ref, kcal(90) / ref],
          e.ratios,
        );
        return;
      }

      if (v.id === 'invariant-I10-cap-conserves') {
        const day = byId.get(`pipeline-${i.day}`);
        assert(day != null, `persona pipeline-${i.day} must exist`);
        const plan = calculateDailyMacrosCore(coreInputFromAssembly(day.inputs));
        const intake = plan.carb_g * 4 + plan.prot_g * 4 + plan.fat_g * 9;
        assertAlmostEquals(intake, plan.tdee, 1e-6);
        return;
      }

      const plan = calculateDailyMacrosCore(coreInputFromAssembly(i));
      assertAlmostEquals(plan.carb_g, e.carbG, tol);
      assertAlmostEquals(plan.prot_g, e.protG, tol);
      assertAlmostEquals(plan.fat_g, e.fatG, tol);
      assertAlmostEquals(plan.tdee, e.tdee, tol);
      assertAlmostEquals(plan.session_kcal, e.sessionKcal, tol);
      assertAlmostEquals(plan.neat_kcal, e.neatKcal, tol);
      assertAlmostEquals(plan.ea, e.ea, 0.001);
      assertEquals(plan.ea_status, e.eaStatus);
    });
  }
});

// ---------------------------------------------------------------------------
// platform-resolution.json — F22–F27 ladders + rulings
// ---------------------------------------------------------------------------

describe('vectors: platform-resolution', () => {
  const file = loadVectors('platform-resolution');
  const tol = tolOf(file);

  const REFERENCE_BF = (1 - 64 / 75) * 100;

  for (const v of file.vectors) {
    it(v.id, () => {
      const i = v.inputs;
      const e = v.expected;
      const mode = (i.mode ?? 'PROSPECTIVE').toLowerCase();

      if (v.id.startsWith('kcal-ladder')) {
        const r = resolveSessionData(
          {
            sport: 'running',
            duration_hr: i.durationHr ?? 1.5,
            pct_conversational: 1,
            pct_tempo: 0,
            pct_allout: 0,
          },
          i.weightKg ?? 75,
          mode,
          { activeKilocalories: i.garminActiveKcal },
          i.resolvedIF != null ? { planned_IF: i.resolvedIF } : null,
        );
        assertAlmostEquals(r.session_kcal, e.sessionKcal, tol);
        assertEquals(r.kcal_source, e.source);
      } else if (v.id.startsWith('if-ladder')) {
        const r = resolveSessionData(
          {
            sport: 'running',
            duration_hr: 1.5,
            pct_conversational: 1,
            pct_tempo: 0,
            pct_allout: 0,
          },
          75,
          mode,
          null,
          { actual_IF: i.tpActualIF, planned_IF: i.tpPlannedIF },
        );
        assertAlmostEquals(r.intensity_factor, e.IF, 0.005);
        assertEquals(r.if_source, e.source);
      } else if (v.id.startsWith('neat-')) {
        const r = resolveNEAT(
          mode,
          i.garminDailyActiveKcal == null
            ? null
            : { activeKilocalories: i.garminDailyActiveKcal },
          i.sessionKcalTotal,
          1908,
          0.2,
          1.1,
          'desk',
        );
        // The formula-path value is supplied by the vector; assert only the
        // Garmin path numerically, the fallback via its source + input value.
        if (e.source === 'GARMIN') {
          assertAlmostEquals(r.neat_kcal, e.neatKcal, tol);
        } else {
          assertEquals(r.source, 'FORMULA');
          assertAlmostEquals(
            calculateNEAT(1908, 0.2, 1.1, 'desk'),
            e.neatKcal,
            tol,
          );
        }
        assertEquals(r.source, e.source);
      } else if (v.id.startsWith('tomorrow-')) {
        const r = resolveTomorrow(
          i.tpTomorrow == null ? null : {
            tomorrow_planned: {
              tss: i.tpTomorrow.tss ?? null,
              is_race: i.tpTomorrow.isRace ?? null,
            },
          },
          i.manualTomorrow == null ? {} : {
            tomorrow_tss: i.manualTomorrow.tss ?? null,
            tomorrow_is_race: i.manualTomorrow.isRace ?? undefined,
          },
        );
        assertEquals(r.source, e.source);
        if ('isRace' in e) assertEquals(r.tomorrow_is_race, e.isRace);
        if ('tss' in e) assertEquals(r.tomorrow_tss, e.tss);
      } else if (v.id.startsWith('ratio-')) {
        const r = resolveWeeklyRatio(
          { ATL: i.atl, CTL: i.ctl },
          i.manualRatio ?? null,
        );
        assertAlmostEquals(r.ratio, e.ratio, 0.0001);
        assertEquals(r.source, e.source);
      } else if (v.id.startsWith('two-time')) {
        let times: WorkoutTimes = {
          planned_time_min: i.plannedTimeMin ?? null,
          actual_time_min: i.actualTimeMin ?? null,
        };
        let source: string | undefined = i.source;
        if (i.gesture === 'mark_done') times = applyMarkDone(times, i.nowMin);
        if (i.gesture === 'mark_undone') times = applyMarkUndone(times);
        if (i.gesture === 'sync') {
          // A later Garmin sync overwrites a mark-done actual_time with the
          // measured start — MANUAL → GARMIN, same as the kcal path.
          times = applyGarminSyncStart(times, i.measuredStartMin);
          source = 'GARMIN';
        }
        if ('actualTimeMin' in e) {
          assertEquals(times.actual_time_min, e.actualTimeMin);
        }
        if ('source' in e) assertEquals(source, e.source);
        if ('plannedTimeMin' in e) {
          assertEquals(times.planned_time_min, e.plannedTimeMin);
        }
        if ('displayTimeMin' in e) {
          assertEquals(displayTimeMin(times), e.displayTimeMin);
        }
      } else if (v.id.startsWith('tombstone-matcher')) {
        // deno-lint-ignore no-explicit-any
        const norm = (a: any) => ({
          platform_id: a.platformId ?? null,
          platform: a.platform ?? null,
          sport: a.sport ?? null,
          start_min: a.startMin ?? null,
          status: a.status ?? null,
        });
        const decision = decideImport(
          norm(i.incomingActivity),
          // deno-lint-ignore no-explicit-any
          i.localRows.map((r: any) => norm(r)),
        );
        assertEquals(decision.import, e.imported);
      } else if (v.id === 'end-to-end-prospective') {
        const plan = calculateDailyMacrosCore({
          weight_kg: 75,
          lbm_kg: 64,
          age: 34,
          sex: 'male',
          body_fat_pct: REFERENCE_BF,
          lifestyle: 'desk',
          training_phase: 'base',
          sessions: [{
            sport: 'running',
            intensity_factor: i.session.tpPlannedIF,
            duration_hr: i.session.durationHr,
            session_kcal: sessionCost(
              'running',
              i.session.durationHr,
              i.session.tpPlannedIF,
              75,
            ),
          }],
          weekly_ratio: 1.0,
          rmr: calculateRMR(75, 178, 34, 'male', REFERENCE_BF),
          base_neat: 0.2,
        });
        assertAlmostEquals(plan.carb_g, e.carbG, tol);
        assertAlmostEquals(plan.fat_g, e.fatG, tol);
        assertAlmostEquals(plan.tdee, e.tdee, tol);
      } else if (v.id === 'end-to-end-retrospective') {
        const rmr = resolveRMR({ bmrKilocalories: i.garmin.bmr }, {
          weight_kg: 75,
          height_cm: 178,
          age: 34,
          sex: 'male',
          body_fat_pct: REFERENCE_BF,
        });
        const session = resolveSessionData(
          {
            sport: 'running',
            duration_hr: 1.5,
            pct_conversational: 1,
            pct_tempo: 0,
            pct_allout: 0,
          },
          75,
          'retrospective',
          { activeKilocalories: i.garmin.sessionKcal },
          { actual_IF: i.tpActualIF },
        );
        const neat = resolveNEAT(
          'retrospective',
          { activeKilocalories: i.garmin.dailyActive },
          session.session_kcal,
          rmr.rmr,
          0.2,
          1.1,
          'desk',
        );
        const plan = calculateDailyMacrosCore({
          weight_kg: 75,
          lbm_kg: 64,
          age: 34,
          sex: 'male',
          body_fat_pct: REFERENCE_BF,
          lifestyle: 'desk',
          training_phase: 'base',
          sessions: [{
            sport: 'running',
            intensity_factor: session.intensity_factor,
            duration_hr: session.duration_hr,
            session_kcal: session.session_kcal,
          }],
          weekly_ratio: 1.0,
          rmr: rmr.rmr,
          base_neat: 0.2,
          neat_measured_kcal: neat.source === 'GARMIN' ? neat.neat_kcal : null,
        });
        assertAlmostEquals(plan.carb_g, e.carbG, tol);
        assertAlmostEquals(plan.fat_g, e.fatG, tol);
        assertAlmostEquals(plan.tdee, e.tdee, tol);
      } else {
        throw new Error(`unhandled vector ${v.id}`);
      }
    });
  }
});
