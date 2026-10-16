/**
 * Box 1 · Gate (code): whether Vana speaks at all, and what code already knows (proposal v7 §4.1).
 *
 * Entitlement and rate limit are hooks (no-op adapters are fine for the harness). The token ceiling is the runaway
 * guard inside one reply. A tap never reaches a model: it goes to Save. And the tool arguments code already knows —
 * the long workout's sport and minutes, the workout form's weekday / type / minutes — are bound here and removed from
 * what the model may set (README delta 5; §12 "bound arguments": what the model would have passed is logged, not used).
 */
import type { Adapters } from './adapters.ts';
import type { HistoryPattern, Snapshot, Sport, StepDeclaration, ToolCall, TurnInput, Workout } from './types.ts';
import { weekdayOf } from './dates.ts';

/** Input + output tokens one turn may spend across every pass before the loop lands (invisible to the athlete). */
export const TURN_TOKEN_CEILING = 60_000;
/** A long workout is 90 minutes or more (conversation rules; the app's own bracket). */
export const LONG_MINUTES = 90;

export type GateVerdict = { ok: true; kind: 'message' | 'tap' } | { ok: false; reason: string };

export async function gate(input: TurnInput, a: Adapters): Promise<GateVerdict> {
  if (!input.message && !input.tap) return { ok: false, reason: 'empty turn: neither a message nor a tap' };
  const ent = await (a.entitlement ?? { allowed: () => Promise.resolve({ ok: true as const }) }).allowed(input.userId);
  if (!ent.ok) return { ok: false, reason: `entitlement: ${ent.reason}` };
  const rl = await (a.rateLimit ?? { take: () => Promise.resolve({ ok: true as const }) }).take(input.userId);
  if (!rl.ok) return { ok: false, reason: `rate limit: ${rl.reason}` };
  return { ok: true, kind: input.tap ? 'tap' : 'message' };
}

// ---------------------------------------------------------------- the long workout, in code
const isLong = (w: Workout) => w.minutes >= LONG_MINUTES;
const sportRank: Record<Sport, number> = { run: 0, ride: 1, swim: 2, strength: 3 };

/**
 * The next long workout: the soonest 90+ minute session from TOMORROW on, never today (ruled 2026-10-15, E2), else the
 * soonest one the athlete saved in this app (an 80-minute Sunday run saved from the planner still counts as "the" long
 * workout — v10 s15). Two long sessions on the same day (a brick weekend, a tri plan): run, then ride, then swim; the
 * sport breaks a tie only within a day, never across days.
 */
export function nextLong(d: Snapshot): Workout | null {
  const up = d.workouts.filter((w) => w.date > d.today).sort((a, b) => a.date.localeCompare(b.date) || sportRank[a.type] - sportRank[b.type]);
  return up.find(isLong) ?? up.find((w) => w.source === 'calendar') ?? null;
}

/** The athlete's usual long day from synced history, or null when it holds no pattern (port of the harness's longRunPattern). */
export function historyPattern(d: Snapshot): HistoryPattern | null {
  if (!d.connections.wearable || !d.connections.historySynced || d.connections.wearableJustConnected) return null;
  const longs = d.history.filter(isLong);
  if (longs.length < 2) return null;
  const byDay = new Map<string, number>();
  for (const w of longs) byDay.set(weekdayOf(w.date), (byDay.get(weekdayOf(w.date)) ?? 0) + 1);
  const [weekday, count] = [...byDay.entries()].sort((a, b) => b[1] - a[1])[0];
  const mins = longs.map((w) => w.minutes).sort((a, b) => a - b);
  // the sport of the most common long day, run before ride on a tie (the E2 order)
  const sports = longs.filter((w) => weekdayOf(w.date) === weekday).map((w) => w.type).sort((a, b) => sportRank[a] - sportRank[b]);
  return { weekday: weekday as HistoryPattern['weekday'], sport: sports[0] ?? 'run', typicalMinutes: mins[Math.floor(mins.length / 2)], confidence: count >= 3 && count / longs.length >= 0.75 ? 'clear' : 'weak' };
}

/** The sport and length the formula picker is bound to: the workout ahead, else the planner's biggest day, else the pattern. */
export function longTarget(d: Snapshot): { sport: Sport; minutes: number; from: 'workout' | 'week' | 'pattern' } | null {
  const nl = nextLong(d);
  if (nl) return { sport: nl.type, minutes: nl.minutes, from: 'workout' };
  if (d.week?.length) {
    const big = d.week.reduce((a, b) => (b.minutes > a.minutes ? b : a));
    const sport = [...big.sports].sort((a, b) => sportRank[a] - sportRank[b])[0] ?? 'run';   // the E2 order
    return { sport, minutes: big.minutes, from: 'week' };
  }
  const p = historyPattern(d);
  return p ? { sport: p.sport, minutes: p.typicalMinutes, from: 'pattern' } : null;
}

/** Does the file know the long workout at all (a workout ahead, a planner week, or a history pattern)? */
export const knowsWorkout = (d: Snapshot): boolean => !!longTarget(d);

/** The pinned During formula that applies to this workout (activity × bracket, as pin_decision.dart reports it). */
export function pinFor(d: Snapshot, w: Workout) {
  const act = w.type === 'ride' ? 'cycling' : 'running';
  const bracket = w.minutes < 90 ? '< 90 min' : w.minutes <= 150 ? '90-150 min' : w.minutes <= 240 ? '150-240 min' : '> 240 min';
  return d.pins.find((p) => p.phase === 'during' && p.activities.includes(act) && p.brackets.includes(bracket)) ?? null;
}

// ---------------------------------------------------------------- bound arguments
/**
 * Merge what the model passed with what the step binds. Bound keys win; a model value that differs is counted as a
 * disagreement (§12) and dropped. Returns the call to run and whether the model disagreed.
 */
export function bindArguments(step: StepDeclaration, call: ToolCall, d: Snapshot): { call: ToolCall; disagreement: boolean; dropped: string[] } {
  const bound = step.bound?.[call.name]?.(d);
  if (!bound) return { call, disagreement: false, dropped: [] };
  const dropped: string[] = [];
  for (const [k, v] of Object.entries(bound)) {
    if (k in call.input && JSON.stringify(call.input[k]) !== JSON.stringify(v)) dropped.push(`${k}: model said ${JSON.stringify(call.input[k])}, bound ${JSON.stringify(v)}`);
  }
  return { call: { name: call.name, input: { ...call.input, ...bound } }, disagreement: dropped.length > 0, dropped };
}
