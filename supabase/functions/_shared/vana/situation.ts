/**
 * The Situation — which screen the athlete is on and what is in view.
 *
 * The client sends the matched route and, for the screens that have something in view, that thing's
 * id and date. It never sends a name or any free text: the server resolves ids into one sentence,
 * from the athlete's own rows, under their RLS. The Situation is never stored — it lives for one
 * request, in the context block, and nowhere else.
 *
 * The screen table below is the contract. A route that is not in it resolves to the route alone,
 * which is still worth a line: "they are in settings" changes what a question means.
 */
import type { VanaCtx } from './env.ts';
import { dayName } from './env.ts';

/** What the client puts on each message. Ids only. */
export interface Situation {
  /** The matched route pattern, e.g. '/plan', '/food/meals/:id'. */
  route: string;
  /** The primary entity in view, when the route has one. */
  entityId?: string | null;
  /** The day the screen is showing (YYYY-MM-DD). */
  date?: string | null;
  /** Meal-log screens only: which slot is being logged. */
  slot?: string | null;
}

/** Which kind of thing the route's `entityId` points at. */
export type EntityKind = 'plan' | 'meal' | 'activity' | 'event' | null;

/** The screen table, verbatim from the spec. Longest prefix wins.
 *  `exact` rows match only themselves: `/food` is the Plan tab, but `/food/meals/recents` and
 *  `/food/swap/:planMealId` are not, and must not inherit its entity. */
const SCREENS: { route: string; entity: EntityKind; wantsDate: boolean; wantsSlot?: boolean; exact?: boolean }[] = [
  // The meal-planning Plan tab is /food?tab=plan; /plan and /current-plan are both the activity
  // detail screen (one session's fuel plan), which is why they resolve to an activity, not a plan.
  { route: '/food', entity: 'plan', wantsDate: true, exact: true },
  { route: '/food/meals/:id', entity: 'meal', wantsDate: false },
  { route: '/food/cook/:id', entity: 'meal', wantsDate: false },
  { route: '/fuel-log', entity: 'activity', wantsDate: true },
  { route: '/plan', entity: 'activity', wantsDate: true },
  { route: '/current-plan', entity: 'activity', wantsDate: true },
  { route: '/events/:eventId/checklist', entity: 'event', wantsDate: false },
  { route: '/events', entity: 'event', wantsDate: false, exact: true },
  { route: '/meal-log', entity: null, wantsDate: true, wantsSlot: true },
  { route: '/main', entity: null, wantsDate: true },
];

/** The table row for a route, or null when the route carries nothing but itself. */
export function screenFor(route: string): { route: string; entity: EntityKind; wantsDate: boolean; wantsSlot?: boolean } | null {
  const r = (route ?? '').trim();
  if (!r) return null;
  return SCREENS.filter((s) => (s.exact ? r === s.route : r === s.route || r.startsWith(`${s.route}/`))).sort((a, b) => b.route.length - a.route.length)[0] ?? null;
}

/** A slot is one of the app's meal slots or nothing — never free text. */
const SLOTS = new Set(['breakfast', 'lunch', 'dinner', 'snack']);
/** Route-shaped: a leading slash, then path segments of the app's own alphabet — no spaces, no
 *  punctuation, bounded length. The client sends a route, not prose, and this is what stops a
 *  string the athlete typed from reaching the system prompt through this field. */
const ROUTE_SHAPE = /^\/[A-Za-z0-9\-_:/]{0,80}$/;

const on = (date?: string | null) => (date ? ` on ${dayName(date)} ${date}` : '');

/**
 * One sentence for the context block, or null when there is nothing to say.
 * A missing or unreadable entity is not an error: the sentence falls back to the screen and the day.
 */
export async function resolveSituation(v: VanaCtx, s: Situation | null | undefined): Promise<string | null> {
  const route = typeof s?.route === 'string' ? s.route.trim() : '';
  if (!route) return null;
  // A route this server does not know is described, never quoted — an unrecognised string is not
  // allowed to reach the system prompt as itself.
  if (!ROUTE_SHAPE.test(route)) return 'on a screen this server does not recognise';
  const screen = screenFor(route);
  if (!screen) return `on the ${route} screen`;

  const id = s!.entityId?.trim() || null;
  switch (screen.entity) {
    case 'meal': {
      const cooking = route.startsWith('/food/cook');
      const name = id ? await mealName(v, id) : null;
      if (!name) return cooking ? 'cooking a meal from the library' : 'looking at a meal in the library';
      return cooking ? `cooking "${name}" right now` : `looking at the meal "${name}"`;
    }
    case 'activity': {
      const a = id ? await activityRow(v, id) : null;
      const where = route === '/fuel-log' ? 'the fuel log' : 'the fuel plan';
      if (!a) return `looking at ${where}${on(s!.date)}`;
      const bits = [a.activity_type, a.duration_minutes ? `${a.duration_minutes} min` : null].filter(Boolean).join(', ');
      return `looking at ${where} for ${a.title ?? a.activity_type ?? 'a session'}${on(String(a.scheduled_date_time ?? '').slice(0, 10) || s!.date)}${bits ? ` (${bits})` : ''}`;
    }
    case 'event': {
      const e = id ? await eventRow(v, id) : null;
      return e ? `looking at the event ${e.event_name ?? 'race'} on ${e.event_date}${e.location ? ` in ${e.location}` : ''}` : 'looking at their events';
    }
    case 'plan': {
      const p = id ? await planRow(v, id) : null;
      const day = `the Plan tab${on(s!.date)}`;
      return p ? `looking at ${day}; the week of ${p.week_start} is ${p.status}` : `looking at ${day}`;
    }
    default: {
      const slot = s!.slot && SLOTS.has(String(s!.slot).toLowerCase()) ? String(s!.slot).toLowerCase() : null;
      if (screen.wantsSlot) return `logging ${slot ? `a ${slot}` : 'a meal'}${on(s!.date)}`;
      return `in the app${on(s!.date)}`;
    }
  }
}

// ---------------------------------------------------------------- reads (all RLS-scoped)
async function mealName(v: VanaCtx, id: string): Promise<string | null> {
  const { data: lib } = await v.db.from('meal_library').select('name').eq('id', id).maybeSingle();
  if (lib?.name) return String(lib.name);
  const { data: saved } = await v.db.from('saved_meals').select('name').eq('id', id).eq('user_id', v.userId).maybeSingle();
  return saved?.name ? String(saved.name) : null;
}
// deno-lint-ignore no-explicit-any
async function activityRow(v: VanaCtx, id: string): Promise<any | null> {
  const { data } = await v.db.from('activities').select('title, activity_type, duration_minutes, scheduled_date_time').eq('id', id).eq('user_id', v.userId).is('deleted_at', null).maybeSingle();
  return data ?? null;
}
// deno-lint-ignore no-explicit-any
async function eventRow(v: VanaCtx, id: string): Promise<any | null> {
  const { data } = await v.db.from('events').select('event_name, event_date, location').eq('id', id).eq('user_id', v.userId).maybeSingle();
  return data ?? null;
}
// deno-lint-ignore no-explicit-any
async function planRow(v: VanaCtx, id: string): Promise<any | null> {
  const { data } = await v.db.from('meal_plans').select('week_start, status').eq('id', id).eq('user_id', v.userId).eq('is_deleted', false).maybeSingle();
  return data ?? null;
}
