/**
 * The orientation flow, as data (proposal v7 §5, ratified 2026-10-15; prompts in ops/experiments/setup-chat/v7/prompts/).
 *
 * Order: plan → wearable → week → formula → long_run → race → wrap. `week` is the "learn the long workout" half of the
 * long-workout step (the week planner), split out so the formula picker — which binds sport and minutes — always runs
 * after the file knows a long workout and before its form. §5 lists the planner under plan's on_decline and the
 * step-long-run.md section covers both forms; one step id per card keeps Route's "a card other than the step's own"
 * check structural. Declining the planner declines the long workout (the harness rule).
 *
 * `steer` lines are drafts for Xuan to edit (handoff). max_passes: 4.
 */
import type { FlowDeclaration, Snapshot, StepDeclaration } from '../types.ts';
import { ANSWER } from './shared.ts';
import { bracketOf, fmtDate, weekdayOf } from '../dates.ts';
import { historyPattern, knowsWorkout, longTarget, nextLong, pinFor } from '../gate.ts';

const react = { name: 'react', kind: 'react' as const };

/** The workout form's mode and prefill, from the file (README delta 5: weekday / type / minutes off the model). */
export function workoutFormArgs(d: Snapshot): Record<string, unknown> | null {
  const nl = nextLong(d);
  if (nl) {
    if (!nl.fueled) return { mode: 'fuel', workoutId: nl.id };
    const pin = pinFor(d, nl);
    if (pin && nl.fueledWithPin !== pin.id) return { mode: 'fuel', workoutId: nl.id, replan: true };
    return { mode: 'edit', workoutId: nl.id };
  }
  const t = longTarget(d);
  if (!t) return { mode: 'create' };
  const weekday = t.from === 'week' ? d.week!.reduce((a, b) => (b.minutes > a.minutes ? b : a)).day : t.from === 'pattern' ? historyPattern(d)!.weekday : undefined;
  return { mode: 'create', type: t.sport, minutes: t.minutes, ...(weekday ? { weekday } : {}) };
}

const steps: Record<string, StepDeclaration> = {
  plan: {
    id: 'plan', shape: 'hand_off', section: 'step-plan',
    tools: [{ name: 'showConnectCard', kind: 'card' }, react], cards: ['connect_plan'], bound: { showConnectCard: () => ({ kind: 'plan' }) },
    forcedFirstTool: 'showConnectCard', checks: ['name_from_data', 'one_question', 'same_words_twice', 'lead_in_names_step', 'no_app_claims'], reply: 'model',
    status: (d) => (d.connections.plan ? 'done' : 'open'), stores: ['plan_platform'],
    steer: 'Want to keep going with your training plan?',
  },
  wearable: {
    id: 'wearable', shape: 'hand_off', section: 'step-wearable',
    tools: [{ name: 'showConnectCard', kind: 'card' }, react], cards: ['connect_wearable'], bound: { showConnectCard: () => ({ kind: 'wearable' }) },
    forcedFirstTool: 'showConnectCard', checks: ['name_from_data', 'one_question', 'same_words_twice', 'lead_in_names_step', 'no_app_claims'], reply: 'model',
    status: (d) => (d.connections.wearable ? 'done' : 'open'), stores: ['wearable'],
    steer: 'Want to keep going with your Garmin?',
  },
  week: {
    id: 'week', shape: 'draft_record', section: 'step-long-run',
    tools: [{ name: 'longRunPattern', kind: 'read' }, { name: 'showWeekPlanner', kind: 'card' }, react], cards: ['week_planner'],
    checks: ['pattern_from_data', 'name_from_data', 'one_question', 'same_words_twice', 'lead_in_names_step', 'no_app_claims'], reply: 'model',
    status: (d) => (knowsWorkout(d) ? 'done' : 'open'), onDecline: { alsoDecline: ['long_run'] },
    steer: 'Want to keep going with your training week?',
  },
  formula: {
    id: 'formula', shape: 'choose', section: 'step-formula',
    tools: [{ name: 'recommendFormulas', kind: 'card' }, { name: 'formulaCoverage', kind: 'read' }, react], cards: ['formulas'],
    bound: { recommendFormulas: (d) => { const t = longTarget(d); return t ? { phase: 'during', sport: t.sport === 'ride' ? 'ride' : 'run', minutes: t.minutes } : null; } },
    forcedFirstTool: 'recommendFormulas', checks: ['pin_covers', 'name_from_data', 'one_question', 'same_words_twice', 'lead_in_names_step', 'no_app_claims'], reply: 'model',
    status: (d) => (d.pins.length ? 'done' : 'open'), milestone: 'formula_pinned',
    steer: 'Want to keep going with a formula for your long workout?',
  },
  long_run: {
    id: 'long_run', shape: 'draft_record', section: 'step-long-run',
    tools: [{ name: 'getWorkouts', kind: 'read' }, { name: 'showWorkoutCard', kind: 'card' }, react], cards: ['workout_card'],
    bound: { showWorkoutCard: workoutFormArgs },
    checks: ['pattern_from_data', 'pin_covers', 'name_from_data', 'one_question', 'same_words_twice', 'lead_in_names_step', 'no_app_claims'], reply: 'model',
    status: (d) => { const nl = nextLong(d); if (!nl || !nl.fueled) return 'open'; const pin = pinFor(d, nl); return pin && nl.fueledWithPin !== pin.id ? 'open' : 'done'; },
    milestone: 'long_workout_fueled',
    steer: 'Want to keep going with fueling your long workout?',
  },
  race: {
    id: 'race', shape: 'draft_record', section: 'step-race',
    tools: [{ name: 'showRaceCard', kind: 'card' }, react], cards: ['race_card'],
    forcedFirstTool: 'showRaceCard', checks: ['race_question_narrow', 'name_from_data', 'one_question', 'same_words_twice', 'lead_in_names_step', 'no_app_claims'], reply: 'model',
    status: (d) => (d.race ? 'done' : 'open'), stores: ['race_date', 'race_distance'], milestone: 'race_added',
    steer: 'Want to keep going with your race?',
  },
  wrap: {
    id: 'wrap', shape: 'scripted', section: null,
    tools: [{ name: 'setupRecap', kind: 'card' }], cards: ['recap'], checks: [], reply: 'scripted', scripted: 'wrap',
    status: () => 'open', milestone: 'setup_done',
    steer: '',
  },
};

/** The flow's lines for the block (README: PLAN · WEARABLE · RACE · FORMULA · GUT TRAINING · NEXT LONG WORKOUT · WEEK · MEMORIES). */
export function orientationLines(d: Snapshot): string[] {
  const c = d.connections;
  const wearable = !c.wearable ? 'not connected' : c.wearableJustConnected ? 'Garmin, connected just now (past workouts not synced yet)' : `Garmin, connected${c.historySynced ? ` (${d.history.length} workouts synced)` : ' (nothing synced yet)'}`;
  const nl = nextLong(d);
  const longRun = nl
    ? `${nl.title}, ${nl.minutes} min (${bracketOf(nl.minutes)}), ${fmtDate(nl.date)} (id ${nl.id})${nl.fueled ? `, fueling plan saved (${nl.fueledWithPin ? `made with ${d.pins.find((p) => p.id === nl.fueledWithPin)?.name ?? 'a pin'}` : 'made without a pin: the app chose defaults'})` : ', no fueling plan yet'}${d.pins.length && !pinFor(d, nl) ? ' — the pinned formula does NOT cover this length' : ''}`
    : 'none on the calendar';
  return [
    `- PLAN: ${c.plan ? `connected (${c.plan})` : 'not connected'}`,
    `- WEARABLE: ${wearable}`,
    `- RACE: ${d.race ? `${d.race.name}, ${d.race.distance ?? ''} ${fmtDate(d.race.date)} ${d.race.date.slice(0, 4)}${d.race.source === 'plan' ? ' (from their plan)' : ''}`.replace(/\s+/g, ' ') : 'none on the calendar'}`,
    `- FORMULA: ${d.pins.length ? `pinned: ${d.pins.map((p) => `${p.name} (${p.phase}; ${p.activities.join('/')}; ${p.brackets.join(', ')})`).join('; ')}` : 'none pinned'}`,
    `- GUT TRAINING (profile): ${d.profile.gutTraining ?? 'moderate'}`,
    `- NEXT LONG WORKOUT (90+ min): ${longRun}`,
    `- WEEK (from the planner): ${d.week ? d.week.map((w) => `${w.day} ${w.minutes} min ${w.sports.join('/')}`).join(' · ') : 'not filled in'}`,
    `- MEMORIES: ${d.memories.length ? d.memories.join(' · ') : 'none'}`,
  ];
}

export const ORIENTATION: FlowDeclaration = {
  id: 'orientation',
  starts: (situation, d) => situation?.opened === 'orientation' || situation?.opened === 'banner' || (!d.profile.metVana && situation?.opened !== 'plan_button'),
  lines: orientationLines,
  allowsJump: false,
  maxPasses: 4,
  order: ['plan', 'wearable', 'week', 'formula', 'long_run', 'race', 'wrap'],
  steps,
  answerStep: ANSWER,
};

export const weekdayFor = weekdayOf;
