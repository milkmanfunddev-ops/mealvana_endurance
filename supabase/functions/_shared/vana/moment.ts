/**
 * The moment opener (vana-moment spec VM-1). The device decides that Vana has something to say — a workout's pre-workout
 * window has opened with nothing eaten (M-1), or a session has finished with nothing logged while its recovery window is open
 * (M-2) — and opens the sheet on it with `opener: true` and a `moment` naming the workout. The opener is written into the day's
 * existing conversation and names the session from the athlete's own row, under RLS.
 *
 * Like the Situation, a moment carries ids and one number, never text: the server reads the names itself.
 */
import type { VanaCtx } from './env.ts';
import { OPENERS } from './persona.ts';

/**
 * What the client sends: which moment, which workout, and the window the device resolved — minutes before the start for
 * `pre_workout`, minutes after the end for `recovery`. A recovery also carries the device's branch (post-workout.md: `urgent`
 * when the next fuel-demanding session is under 8 h away) and names that next session when it is under 24 h away.
 */
export interface MomentRef { kind: MomentKind; activityId: string; windowMinutes: number | null; nextActivityId: string | null; urgent: boolean }
export type MomentKind = 'pre_workout' | 'recovery';

const KINDS = new Set<string>(['pre_workout', 'recovery']);
const ID_SHAPE = /^[A-Za-z0-9_-]{1,64}$/;
/** A window the device may send: the fuelling-window stepper's range (the authority's floor of 15 min, the stepper's 240 max,
 *  FuelingWindowLimits), which also holds both recovery windows (120 and 240). */
const WINDOW_MIN = 15;
const WINDOW_MAX = 240;

/** The body's `moment`, or null when it is absent or not moment-shaped. A window out of range is dropped, not trusted. */
export function parseMoment(raw: unknown): MomentRef | null {
  if (!raw || typeof raw !== 'object') return null;
  const m = raw as { kind?: unknown; activity_id?: unknown; window_minutes?: unknown; next_activity_id?: unknown; branch?: unknown };
  if (typeof m.kind !== 'string' || !KINDS.has(m.kind)) return null;
  if (typeof m.activity_id !== 'string' || !ID_SHAPE.test(m.activity_id)) return null;
  const w = m.window_minutes;
  const windowMinutes = typeof w === 'number' && Number.isInteger(w) && w >= WINDOW_MIN && w <= WINDOW_MAX ? w : null;
  const next = m.next_activity_id;
  const nextActivityId = typeof next === 'string' && ID_SHAPE.test(next) ? next : null;
  // Anything but the word itself is relaxed: urgency is the claim that needs evidence.
  return { kind: m.kind as MomentKind, activityId: m.activity_id, windowMinutes, nextActivityId, urgent: m.kind === 'recovery' && m.branch === 'urgent' };
}

/** `scheduled_date_time` is the athlete's wall clock with no zone: read the clock off the string, never through a Date. */
function wallMinutes(scheduled: string): number | null {
  const hit = /T(\d{2}):(\d{2})/.exec(scheduled);
  return hit ? Number(hit[1]) * 60 + Number(hit[2]) : null;
}
function clock(minutes: number): string {
  const m = ((minutes % 1440) + 1440) % 1440;
  const h = Math.floor(m / 60);
  return `${h % 12 === 0 ? 12 : h % 12}:${String(m % 60).padStart(2, '0')} ${h < 12 ? 'am' : 'pm'}`;
}

export interface MomentSession { title: string; activityType: string; durationMinutes: number | null; startsAt: string; windowOpensAt: string | null }

// deno-lint-ignore no-explicit-any
type Row = Record<string, any>;
const num = (x: unknown): number | null => (typeof x === 'number' ? x : null);
/** The athlete's own words, kept out of the prompt's brackets and quotes. */
const titleOf = (row: Row): string => String(row.title ?? row.activity_type ?? 'session').replace(/[[\]"]/g, '').slice(0, 80);

async function ownRow(v: VanaCtx, id: string, columns: string): Promise<Row | null> {
  const { data } = await v.db.from('activities').select(columns).eq('id', id).eq('user_id', v.userId).is('deleted_at', null).maybeSingle();
  return (data as Row | null) ?? null;
}

/** The workout a pre-workout moment names, from the caller's own row; null when it is not theirs or is gone. */
export async function momentSession(v: VanaCtx, m: MomentRef): Promise<MomentSession | null> {
  const data = await ownRow(v, m.activityId, 'title, activity_type, duration_minutes, scheduled_date_time, time_before_minutes');
  const start = data ? wallMinutes(String(data.scheduled_date_time ?? '')) : null;
  if (!data || start == null) return null;
  const window = m.windowMinutes ?? (typeof data.time_before_minutes === 'number' && data.time_before_minutes > 0 ? data.time_before_minutes : null);
  return {
    title: titleOf(data),
    activityType: String(data.activity_type ?? ''),
    durationMinutes: num(data.duration_minutes),
    startsAt: clock(start),
    windowOpensAt: window == null ? null : clock(start - window),
  };
}

/** post-workout.md `POST_URGENT_DURATION_H`: the urgent copy says "the next 4 hours", so its close is computed from the same. */
const URGENT_WINDOW_MINUTES = 240;

export interface RecoverySession {
  title: string; activityType: string; durationMinutes: number; endedAt: string;
  /** Urgent only: when the refuelling window closes. */
  urgentUntil: string | null;
  /** The next fuel-demanding session the device named, when the caller can read it; `when` says the day if it is not today. */
  next: { title: string; when: string } | null;
}

/**
 * The finished session a recovery moment names, from the caller's own row; null when it is not theirs, is gone, or has no
 * length. It ended at its start (measured, else the planned slot mark-done confirms) plus its length (measured, else planned),
 * the same reading the device makes. The row is not required to say `completed`: the device writes that first and uploads it
 * behind, so the opener can arrive before it.
 */
export async function recoverySession(v: VanaCtx, m: MomentRef): Promise<RecoverySession | null> {
  const data = await ownRow(v, m.activityId, 'title, activity_type, duration_minutes, actual_duration_minutes, scheduled_date_time, actual_time');
  if (!data) return null;
  const start = wallMinutes(String(data.actual_time ?? data.scheduled_date_time ?? ''));
  const length = num(data.actual_duration_minutes) ?? num(data.duration_minutes);
  if (start == null || length == null) return null;
  const end = start + length;
  const nextRow = m.nextActivityId ? await ownRow(v, m.nextActivityId, 'title, activity_type, scheduled_date_time') : null;
  const nextScheduled = String(nextRow?.scheduled_date_time ?? '');
  const nextStart = wallMinutes(nextScheduled);
  const sameDay = nextScheduled.slice(0, 10) === String(data.actual_time ?? data.scheduled_date_time ?? '').slice(0, 10);
  const next = nextRow && nextStart != null ? { title: titleOf(nextRow), when: `${sameDay ? '' : 'tomorrow '}at ${clock(nextStart)}` } : null;
  return {
    title: titleOf(data),
    activityType: String(data.activity_type ?? ''),
    durationMinutes: length,
    endedAt: clock(end),
    // The device decides the branch; urgent copy needs the next session it names, so one the caller cannot read leaves it relaxed.
    urgentUntil: m.urgent && next ? clock(end + URGENT_WINDOW_MINUTES) : null,
    next,
  };
}


/** The first user message for a pre-workout moment. It ends in exactly two replies: the sheet shows at most two. */
export function preWorkoutOpener(s: MomentSession): string {
  const bits = [s.activityType, s.durationMinutes ? `${s.durationMinutes} min` : null].filter(Boolean).join(', ');
  const window = s.windowOpensAt ? `; its pre-workout fuelling window opened at ${s.windowOpensAt}` : '';
  return `[MOMENT opener — the athlete did not open this to ask anything: the app raised it because the pre-workout fuelling window for today's session is open and nothing has been logged since it opened. The session: "${s.title}"${bits ? ` (${bits})` : ''} starts at ${s.startsAt}${window}. Write 1–2 sentences that name the session, its start time and when the window opened. Then call askChoice once, with the question "Want me to walk you through fuelling it?" and exactly two options: ["Walk me through it", "I'll handle it"]. Do not ask that question in your sentences as well, and do not suggest meals or list foods yet. No greeting.]`;
}

/**
 * The first user message for a recovery moment (post-workout.md, the copy contract). Urgent: start refuelling now and keep
 * carbs coming through the next 4 h. Relaxed: no rush, the next normal meal covers it — and no deadline, since the relaxed
 * branch's ~2 h meal anchor must never be presented as a window; with a session 8–24 h away, leaning earlier rather than later
 * today. Protein (~20–30 g within a couple of hours) holds in both.
 */
export function recoveryOpener(s: RecoverySession): string {
  const lead = `[MOMENT opener — the athlete did not open this to ask anything: the app raised it because a session today has finished and nothing has been logged since it ended. The session: "${s.title}" (${s.activityType}, ${s.durationMinutes} min) finished at ${s.endedAt}.`;
  const tail = 'Do not ask that question in your sentences as well, and do not suggest meals or list foods yet. Never say "within 30 minutes" or "within the hour". No greeting.]';
  if (s.urgentUntil && s.next) {
    return `${lead} The next session, "${s.next.title}", starts ${s.next.when}: under 8 hours away, so recovery is urgent. Start refuelling now and keep carbs coming through the next 4 hours, until ${s.urgentUntil}, with ~20–30 g of protein within the first couple of hours. Write 1–2 sentences that name the finished session and the next one, and say that. Then call askChoice once, with the question "Want help picking what to eat now?" and exactly two options: ["Help me pick", "I've got it"]. ${tail}`;
  }
  // The 8–24 h band (§6 Q1): relaxed, with the copy softened toward earlier rather than later today.
  const relaxed = s.next
    ? `The next session, "${s.next.title}", starts ${s.next.when}: 8 or more hours away, so there is no rush, though eating earlier rather than later today helps. The next normal meal covers recovery.`
    : 'No fuel-demanding session follows within 8 hours, so there is no rush: the next normal meal covers recovery.';
  return `${lead} ${relaxed} Aim for the day's carb total, and ~20–30 g of protein within a couple of hours. Write 1–2 sentences that name the finished session and say that. Do not give a deadline, a countdown or a time to eat by. Then call askChoice once, with the question "Want a recovery idea for your next meal?" and exactly two options: ["Give me an idea", "I'll eat normally"]. ${tail}`;
}

/** The opener for a general conversation: the moment's, when the body names one that resolves, else the general opener. */
export async function generalOpener(v: VanaCtx, body: { moment?: unknown }): Promise<{ text: string; variant: 'plan' | 'moment' }> {
  const ref = parseMoment(body.moment);
  let text: string | null = null;
  if (ref?.kind === 'pre_workout') {
    const session = await momentSession(v, ref);
    if (session) text = preWorkoutOpener(session);
  } else if (ref?.kind === 'recovery') {
    const session = await recoverySession(v, ref);
    if (session) text = recoveryOpener(session);
  }
  return text ? { text, variant: 'moment' } : { text: OPENERS.general, variant: 'plan' };
}
