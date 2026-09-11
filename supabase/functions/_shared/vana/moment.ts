/**
 * The moment opener (vana-moment spec VM-1). The device decides that Vana has something to say — a workout's pre-workout
 * window has opened with nothing eaten — and opens the sheet on it with `opener: true` and a `moment` naming the workout.
 * The opener is written into the day's existing conversation and names the session from the athlete's own row, under RLS.
 *
 * Like the Situation, a moment carries ids and one number, never text: the server reads the name itself.
 */
import type { VanaCtx } from './env.ts';
import { OPENERS } from './persona.ts';

/** What the client sends: which moment, which workout, and the window the device resolved (minutes before the start). */
export interface MomentRef { kind: 'pre_workout'; activityId: string; windowMinutes: number | null }

const KINDS = new Set(['pre_workout']);
const ID_SHAPE = /^[A-Za-z0-9_-]{1,64}$/;
/** The fuelling-window stepper's range: the authority's floor of 15 min, and the stepper's 240 max (FuelingWindowLimits). */
const WINDOW_MIN = 15;
const WINDOW_MAX = 240;

/** The body's `moment`, or null when it is absent or not moment-shaped. A window out of range is dropped, not trusted. */
export function parseMoment(raw: unknown): MomentRef | null {
  if (!raw || typeof raw !== 'object') return null;
  const m = raw as { kind?: unknown; activity_id?: unknown; window_minutes?: unknown };
  if (typeof m.kind !== 'string' || !KINDS.has(m.kind)) return null;
  if (typeof m.activity_id !== 'string' || !ID_SHAPE.test(m.activity_id)) return null;
  const w = m.window_minutes;
  const windowMinutes = typeof w === 'number' && Number.isInteger(w) && w >= WINDOW_MIN && w <= WINDOW_MAX ? w : null;
  return { kind: 'pre_workout', activityId: m.activity_id, windowMinutes };
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

/** The workout a moment names, from the caller's own row; null when it is not theirs or is gone. */
export async function momentSession(v: VanaCtx, m: MomentRef): Promise<MomentSession | null> {
  const { data } = await v.db.from('activities').select('title, activity_type, duration_minutes, scheduled_date_time, time_before_minutes').eq('id', m.activityId).eq('user_id', v.userId).is('deleted_at', null).maybeSingle();
  const start = data ? wallMinutes(String(data.scheduled_date_time ?? '')) : null;
  if (!data || start == null) return null;
  const window = m.windowMinutes ?? (typeof data.time_before_minutes === 'number' && data.time_before_minutes > 0 ? data.time_before_minutes : null);
  return {
    // The athlete's own words, kept out of the prompt's brackets and quotes.
    title: String(data.title ?? data.activity_type ?? 'session').replace(/[[\]"]/g, '').slice(0, 80),
    activityType: String(data.activity_type ?? ''),
    durationMinutes: typeof data.duration_minutes === 'number' ? data.duration_minutes : null,
    startsAt: clock(start),
    windowOpensAt: window == null ? null : clock(start - window),
  };
}

/** The first user message for a pre-workout moment. It ends in exactly two replies: the sheet shows at most two. */
export function preWorkoutOpener(s: MomentSession): string {
  const bits = [s.activityType, s.durationMinutes ? `${s.durationMinutes} min` : null].filter(Boolean).join(', ');
  const window = s.windowOpensAt ? `; its pre-workout fuelling window opened at ${s.windowOpensAt}` : '';
  return `[MOMENT opener — the athlete did not open this to ask anything: the app raised it because the pre-workout fuelling window for today's session is open and nothing has been logged since it opened. The session: "${s.title}"${bits ? ` (${bits})` : ''} starts at ${s.startsAt}${window}. Write 1–2 sentences that name the session, its start time and when the window opened. Then call askChoice once, with the question "Want me to walk you through fuelling it?" and exactly two options: ["Walk me through it", "I'll handle it"]. Do not ask that question in your sentences as well, and do not suggest meals or list foods yet. No greeting.]`;
}

/** The opener for a general conversation: the moment's, when the body names one that resolves, else the general opener. */
export async function generalOpener(v: VanaCtx, body: { opener?: boolean; moment?: unknown }): Promise<{ text: string; variant: 'plan' | 'moment' }> {
  const ref = parseMoment(body.moment);
  const session = ref ? await momentSession(v, ref) : null;
  return session ? { text: preWorkoutOpener(session), variant: 'moment' } : { text: OPENERS.general, variant: 'plan' };
}
