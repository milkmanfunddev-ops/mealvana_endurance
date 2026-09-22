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
import { dayName, weekStartFor } from './env.ts';
import { sessionDates } from './opener.ts';
import { getPlanPeriod } from './memory.ts';
import { getPlan, getPlanById } from './plan.ts';
import type { MealPlan } from './contracts.ts';

/** One component of a formula draft: which food, and how much of it (mp-274). Ids only. */
export interface DraftComponent {
  /** `template_foods.id` or `user_foods.id`. */
  id: string;
  /** Servings multiplier. During formulas carry none — the solver derives amounts. */
  qty?: number | null;
}

/**
 * The formula editor's draft, as it is on screen, unsaved edits included (mp-274).
 *
 * The one named exception to mp-043: structured fields, every one of them shaped and capped here
 * the way routes are shaped, and only for the editor route. Nothing free-form travels but the
 * name, which the athlete typed and which is capped at [DRAFT_NAME_CAP].
 */
export interface FormulaDraft {
  phase?: string | null;
  subPhase?: string | null;
  durations?: string[] | null;
  activities?: string[] | null;
  components?: DraftComponent[] | null;
  name?: string | null;
}

/** What the client puts on each message. Ids only, plus the formula editor's draft (mp-274). */
export interface Situation {
  /** The matched route pattern, e.g. '/plan', '/food/meals/:id'. */
  route: string;
  /** The primary entity in view, when the route has one. */
  entityId?: string | null;
  /** The day the screen is showing (YYYY-MM-DD). */
  date?: string | null;
  /** Meal-log screens only: which slot is being logged. */
  slot?: string | null;
  /** The formula editor only: the draft on screen. Any other route's draft is refused. */
  draft?: FormulaDraft | null;
}

/** Which kind of thing the route's `entityId` points at. */
export type EntityKind = 'plan' | 'meal' | 'activity' | 'event' | 'formula' | null;

/** How the Situation opens on the message it rides (chat.ts situationNote). Stored with the message since ticket 07
 *  (mp-420 clause 5), so the summariser recognises the line by this and leaves it out of what was said. */
export const SITUATION_MARK = '[SITUATION right now they are ';

/** The one capped section a screen adds for what is in view (mp-273 clause 2). Most screens add none. */
export type SectionKind = 'events_ahead' | 'day_plan' | 'formula';

/** The screen table, verbatim from the spec. Longest prefix wins.
 *  `exact` rows match only themselves: `/food` is the Plan tab, but `/food/meals/recents` and
 *  `/food/swap/:planMealId` are not, and must not inherit its entity.
 *  A new entry point adds a row here and nothing else (mp-273 clause 4): the Doll never grows for it. */
const SCREENS: { route: string; entity: EntityKind; wantsDate: boolean; wantsSlot?: boolean; exact?: boolean; section?: SectionKind }[] = [
  // The meal-planning Plan tab is /food?tab=plan; /plan and /current-plan are both the activity
  // detail screen (one session's fuel plan), which is why they resolve to an activity, not a plan.
  { route: '/food', entity: 'plan', wantsDate: true, exact: true, section: 'day_plan' },
  { route: '/food/meals/:id', entity: 'meal', wantsDate: false },
  { route: '/food/cook/:id', entity: 'meal', wantsDate: false },
  { route: '/fuel-log', entity: 'activity', wantsDate: true },
  { route: '/plan', entity: 'activity', wantsDate: true },
  { route: '/current-plan', entity: 'activity', wantsDate: true },
  { route: '/events/:eventId/checklist', entity: 'event', wantsDate: false, section: 'events_ahead' },
  { route: '/events', entity: 'event', wantsDate: false, exact: true, section: 'events_ahead' },
  { route: '/meal-log', entity: null, wantsDate: true, wantsSlot: true },
  { route: '/main', entity: null, wantsDate: true },
  // The personal-formula editor, create (`personal/create`) and edit (`personal/:id`) alike: one
  // prefix row, and it is the only route allowed to carry a draft (mp-274).
  { route: '/settings/food-preferences/formula-library/personal', entity: 'formula', wantsDate: false, section: 'formula' },
];

/** The table row for a route, or null when the route carries nothing but itself. */
export function screenFor(route: string): { route: string; entity: EntityKind; wantsDate: boolean; wantsSlot?: boolean; section?: SectionKind } | null {
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
    case 'formula': {
      // The draft carries its own name (mp-274), so the sentence needs no read at all.
      const name = acceptDraft(route, s!.draft)?.name ?? null;
      if (name) return `editing the formula "${name}"`;
      return id ? 'editing one of their own formulas' : 'building a new formula';
    }
    default: {
      const slot = s!.slot && SLOTS.has(String(s!.slot).toLowerCase()) ? String(s!.slot).toLowerCase() : null;
      if (screen.wantsSlot) return `logging ${slot ? `a ${slot}` : 'a meal'}${on(s!.date)}`;
      return `in the app${on(s!.date)}`;
    }
  }
}

// ---------------------------------------------------------------- the section for what is in view
/** Every list in a section stops here, then says there is more. A section is a few lines, never a dump of the record;
 *  anything deeper is a tool (mp-273 clause 3). */
export const SECTION_CAP = 6;
/** A day note is Vana's own one-liner; this only stops a runaway one from filling the message. */
const NOTE_CAP = 240;

const capped = (items: string[], rows: number) => [...items.slice(0, SECTION_CAP), ...(rows > SECTION_CAP ? ['and more'] : [])].join(' | ');
const daysOut = (from: string, to: string) => Math.round((new Date(`${to}T00:00:00Z`).getTime() - new Date(`${from}T00:00:00Z`).getTime()) / 86400_000);
const SESSION_LABEL: Record<string, string> = { 'cook-sun': 'batch cook', 'topup-wed': 'top-up', 'fresh-fri': 'fresh cook' };

/**
 * The one capped section for the entity in view, or null when the route has none (mp-273 clause 2). Like the sentence,
 * it is built per request from the athlete's own rows and rides on the user message, never in the context block: the
 * Doll stays the same for every entry point, and the cached prefix stays byte-identical across turns (mp-276).
 * `todayIso` is the athlete's local day, the one the context block is built for.
 */
export async function inViewSection(v: VanaCtx, s: Situation | null | undefined, todayIso: string): Promise<string | null> {
  const route = typeof s?.route === 'string' ? s.route.trim() : '';
  if (!route || !ROUTE_SHAPE.test(route)) return null;
  switch (screenFor(route)?.section) {
    case 'events_ahead': return await eventsAhead(v, todayIso);
    case 'day_plan': return await dayPlan(v, s!, todayIso);
    case 'formula': return await formulaSection(v, route, s!.draft);
    default: return null;
  }
}

// ---------------------------------------------------------------- the formula draft (mp-274)
/** The athlete typed the name; it is the only free text that travels, and it stops here. */
export const DRAFT_NAME_CAP = 40;
/** Values the app itself writes into the draft's scope chips. Anything else is dropped, never echoed. */
const PHASES = new Set(['before', 'during', 'after']);
const SUB_PHASES = new Set(['full_meal', 'snack', 'top_up']);
/** A scope chip's stored value — '90-150 min', 'triathlon_bike'. Shaped like the routes are shaped. */
const TAG_SHAPE = /^[A-Za-z0-9 _<>-]{1,24}$/;
/** A food id: `template_foods.id` or `user_foods.id`, never prose. */
const FOOD_ID_SHAPE = /^[A-Za-z0-9:_-]{1,64}$/;

/** The validated draft: every field the server is willing to say out loud, and nothing else. */
export interface AcceptedDraft {
  name: string | null;
  phase: string | null;
  subPhase: string | null;
  durations: string[];
  activities: string[];
  components: { id: string; qty: number | null }[];
}

const tags = (xs: unknown): string[] =>
  (Array.isArray(xs) ? xs : []).filter((x): x is string => typeof x === 'string' && TAG_SHAPE.test(x.trim())).map((x) => x.trim()).slice(0, SECTION_CAP);

/**
 * The draft, validated, or null when it is refused (mp-274 clause 2).
 *
 * Refused means refused: a draft on any route but the formula editor's is dropped whole — the
 * server validates the shape as it validates routes, and a screen that is not the editor has no
 * business carrying one. Inside the editor, each field stands or falls on its own shape, so one
 * bad chip never costs the athlete the rest of what is on screen.
 */
export function acceptDraft(route: string, draft: FormulaDraft | null | undefined): AcceptedDraft | null {
  if (!draft || typeof draft !== 'object') return null;
  const r = (route ?? '').trim();
  if (!r || !ROUTE_SHAPE.test(r) || screenFor(r)?.section !== 'formula') return null;
  const rawName = typeof draft.name === 'string' ? draft.name.replace(/\s+/g, ' ').trim() : '';
  const components = (Array.isArray(draft.components) ? draft.components : [])
    .filter((c): c is DraftComponent => !!c && typeof c === 'object' && typeof c.id === 'string' && FOOD_ID_SHAPE.test(c.id.trim()))
    .slice(0, SECTION_CAP + 1)
    .map((c) => ({ id: c.id.trim(), qty: typeof c.qty === 'number' && Number.isFinite(c.qty) && c.qty > 0 && c.qty <= 999 ? Math.round(c.qty * 100) / 100 : null }));
  return {
    name: rawName ? rawName.slice(0, DRAFT_NAME_CAP) : null,
    phase: typeof draft.phase === 'string' && PHASES.has(draft.phase) ? draft.phase : null,
    subPhase: typeof draft.subPhase === 'string' && SUB_PHASES.has(draft.subPhase) ? draft.subPhase : null,
    durations: tags(draft.durations),
    activities: tags(draft.activities),
    components,
  };
}

/**
 * The FORMULA section: what the draft targets, and what is in it right now (mp-274 clause 1).
 *
 * The client sends ids and quantities; the names come from the athlete's own rows and the catalog,
 * under their RLS, capped like every other section. An empty draft is still worth a line — it says
 * the editor is open with nothing in it, which is exactly the question an athlete asks there.
 */
async function formulaSection(v: VanaCtx, route: string, draft: FormulaDraft | null | undefined): Promise<string> {
  const d = acceptDraft(route, draft);
  if (!d || (!d.components.length && !d.name && !d.phase)) return 'FORMULA a new formula with nothing in it yet';
  const targets = [d.phase, d.subPhase, d.activities.length ? `activities: ${d.activities.join(', ')}` : null, d.durations.length ? `durations: ${d.durations.join(', ')}` : null].filter(Boolean);
  const bits = [`FORMULA ${d.name ? `"${d.name}"` : 'unnamed'}`, ...(targets.length ? [targets.join(', ')] : [])];
  if (!d.components.length) return `${bits.join(' · ')} · nothing in it yet`;
  const names = await foodNames(v, d.components.map((c) => c.id));
  const items = d.components.map((c) => `${names[c.id] ?? 'a food the catalog does not have'}${c.qty == null ? '' : ` x${c.qty}`}`);
  return `${bits.join(' · ')} · ${capped(items, d.components.length)}`;
}

/** Component ids to display names, from the catalog and the athlete's own foods. */
async function foodNames(v: VanaCtx, ids: string[]): Promise<Record<string, string>> {
  const out: Record<string, string> = {};
  if (!ids.length) return out;
  const [{ data: template }, { data: mine }] = await Promise.all([
    v.db.from('template_foods').select('id, name, display_name').in('id', ids),
    v.db.from('user_foods').select('id, name, display_name').eq('user_id', v.userId).in('id', ids),
  ]);
  // deno-lint-ignore no-explicit-any
  for (const row of [...((template ?? []) as any[]), ...((mine ?? []) as any[])]) {
    const name = row.display_name ?? row.name;
    if (row.id && name) out[String(row.id)] = String(name);
  }
  return out;
}

async function eventsAhead(v: VanaCtx, todayIso: string): Promise<string> {
  const { data } = await v.db.from('events').select('event_name, event_date, location').eq('user_id', v.userId).gte('event_date', todayIso).order('event_date').limit(SECTION_CAP + 1);
  // deno-lint-ignore no-explicit-any
  const rows = ((data ?? []) as any[]).filter((e) => e.event_date);
  if (!rows.length) return 'EVENTS AHEAD none';
  const items = rows.map((e) => `${e.event_name ?? 'Race'} ${e.event_date} (${[`${daysOut(todayIso, String(e.event_date))}d`, e.location].filter(Boolean).join(', ')})`);
  return `EVENTS AHEAD ${capped(items, rows.length)}`;
}

async function dayPlan(v: VanaCtx, s: Situation, todayIso: string): Promise<string> {
  const date = typeof s.date === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(s.date) ? s.date : todayIso;
  const head = `DAY PLAN ${dayName(date)} ${date}`;
  const id = s.entityId?.trim() || null;
  // The id the tab sent, else the week's own plan for that day: an id that does not resolve is not an error.
  const byId = id ? await getPlanById(v, id) : null;
  // mp-269: the week and the cook dates read the athlete's start day and period length, like every other plan read.
  const period = await getPlanPeriod(v);
  const plan: MealPlan | null = byId ?? (await getPlan(v, weekStartFor(date, period.weekStart)));
  if (!plan) return `${head} · no plan this week`;
  const bits = [head, `week of ${plan.weekStart} ${plan.status}`];
  const note = plan.dayNotes?.[date]?.trim();
  if (note) bits.push(`note: ${note.length > NOTE_CAP ? `${note.slice(0, NOTE_CAP - 1)}…` : note}`);
  const onDate = sessionDates(plan.weekStart, period.periodDays);
  const cooks = [...new Set(plan.meals.map((m) => m.session).filter((x): x is Exclude<typeof x, null> => !!x && onDate[x] === date))];
  if (cooks.length) bits.push(`cook: ${cooks.map((c) => SESSION_LABEL[c] ?? c).join(', ')}`);
  const slots = Object.entries(plan.days?.[date] ?? {}).filter(([, ref]) => ref?.name).map(([slot, ref]) => `${slot} ${ref!.name}`);
  if (slots.length) bits.push(`today: ${capped(slots, slots.length)}`);
  bits.push(`meals: ${plan.meals.length ? capped(plan.meals.map((m) => `${m.name} (${m.mealType}, ${m.servingsLeft} of ${m.servings} left)`), plan.meals.length) : 'none yet'}`);
  return bits.join(' · ');
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
