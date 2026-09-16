/** Vana writes the app's own objects (Lee's playtest 2026-09-16 §10): a fresh plan, a deleted plan, events, workouts
 *  (`activities`), meal logs.
 *
 *  Before this the chat could only hand off to a screen for anything outside the meal plan. Now "delete my Ironman"
 *  or "log that I ate the lentil salad" is a write Vana makes herself, and every write answers a `receipt` part the
 *  app draws as a small card with an Undo where one is cheap.
 *
 *  Rules, in code rather than prose:
 *  - Every query is the service-role client filtered by `v.userId` (a tool never reaches another athlete's rows).
 *  - A DELETE without `confirmed: true` writes nothing and answers `needs_confirmation`; the persona asks with
 *    askChoice and calls again after a yes. `guardDelete` is the one place that rule lives.
 *  - The rows written are the rows the app writes: an event is the `events` row `EventsRepository._toSupabaseJson`
 *    sends (text id, `start_time` as a naive local ISO, `event_date` derived from it, `origin: 'manual'`); a meal log
 *    is the `meal_logs` row the Describe flow writes (`source: 'describe'`, `items` components, per-log macros) and a
 *    delete is the same tombstone (`is_deleted`) the app's soft delete leaves. Events have no tombstone — the app hard
 *    deletes — so the receipt carries the row and Undo re-inserts it. `carb_loading_plans` cascade on that delete and
 *    do not come back with Undo.
 *  - The device owns events and meal logs offline-first (Drift). A server-side write bypasses `ensureSynced`, so the
 *    receipt names its `entity` and the client refetches that store when the part arrives.
 */
import type { VanaCtx } from './env.ts';
import type { ReceiptAction, ReceiptEntity, ReceiptUndo, VanaPart } from './contracts.ts';
import { today } from './env.ts';
import { getPlanPeriod } from './memory.ts';
import { invalidateContext } from './context-cache.ts';
import * as plan from './plan.ts';
import type { PlanScope } from './plan.ts';

export type ReceiptPart = Extract<VanaPart, { kind: 'receipt' }>;
export type NeedsConfirmationPart = Extract<VanaPart, { kind: 'needs_confirmation' }>;

/** `events.event_type` (activity_type_enum). */
export const EVENT_TYPES = ['running', 'cycling', 'swimming', 'triathlon', 'duathlon', 'multisport', 'brick', 'transition', 'other'] as const;
/** `events.event_subtype` (event_subtype_enum) — the distance. The app validates the same way before it uploads. */
export const EVENT_SUBTYPES = ['5k', '10k', '15k', '10_mile', 'half_marathon', '25k', '30k', 'marathon', 'ultra_50k', 'ultra_50m', 'ultra_100k', 'ultra_100m', 'ultra_12h', 'ultra_24h', '20k', '40k_tt', '50k', 'half_century', 'metric_century', 'century', 'gran_fondo', '200k', '1k', '1.5k', '2.5k', 'sprint', 'olympic', 'half_ironman', 'ironman', 'standard', 'long_course', 'aquathlon', 'aquabike', 'custom'] as const;
export type EventType = typeof EVENT_TYPES[number];
export type EventSubtype = typeof EVENT_SUBTYPES[number];

/** The time an event starts when the athlete named only the day — the app derives `event_date` from `start_time`, so it is never null. */
export const DEFAULT_EVENT_TIME = '07:00';

const receipt = (action: ReceiptAction, entity: ReceiptEntity, summary: string, entityId: string, params: Record<string, unknown> | null): ReceiptPart =>
  ({ kind: 'receipt', action, entity, summary: summary.slice(0, 200), entityId, undo: params ? ({ action: 'undo_receipt', params: { action, ...params } } as ReceiptUndo) : null });

/** The delete rule: no `confirmed: true`, no write — the part tells the model to ask. */
export function guardDelete(confirmed: boolean | undefined, action: ReceiptAction, entity: ReceiptEntity, summary: string, entityId: string): NeedsConfirmationPart | null {
  return confirmed === true ? null : { kind: 'needs_confirmation', action, entity, summary: summary.slice(0, 200), entityId };
}

/** "Nov 22" from an ISO date, for a summary line. */
export const shortDate = (iso: string | null | undefined) => iso ? new Date(`${iso}T12:00:00Z`).toLocaleDateString('en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' }) : '';

// ---------------------------------------------------------------- plan
/** Archive the plan the conversation is on (never deleted — it stays in history) and start an empty draft. */
export async function startNewPlan(v: VanaCtx, scope: PlanScope | null): Promise<ReceiptPart> {
  const fresh = await plan.newPlan(v, scope);
  return receipt('new_plan', 'plan', 'Started a new plan — the old one is archived', fresh.id, null);
}

/** "Sep 13 – Sep 19" for a plan's period, the way the Plan tab's summary line says it. */
async function planLabel(v: VanaCtx, weekStart: string): Promise<string> {
  const days = (await getPlanPeriod(v)).periodDays;
  const end = new Date(`${weekStart}T12:00:00Z`); end.setUTCDate(end.getUTCDate() + days - 1);
  return `${shortDate(weekStart)} – ${shortDate(end.toISOString().slice(0, 10))}`;
}

/** Delete a plan outright (the `is_deleted` tombstone the app's sync reads as "gone"; the meals stay attached for Undo).
 *  `id` names one plan; without it the scope's plan (a conversation's draft, else the week's active plan). The Plan tab calls
 *  this with a confirm dialog of its own, so `confirmed` here is the chat's rule only: the tool asks first, the tab already did. */
export async function deletePlan(v: VanaCtx, id: string | null, scope: PlanScope | null, confirmed: boolean | undefined): Promise<ReceiptPart | NeedsConfirmationPart> {
  const cur = id ? await plan.getPlanById(v, id) : await plan.resolvePlan(v, scope, false);
  if (!cur) throw new Error('no plan to delete');
  const label = await planLabel(v, cur.weekStart);
  const ask = guardDelete(confirmed, 'delete_plan', 'plan', `Delete the plan for ${label} (${cur.meals.length} meal${cur.meals.length === 1 ? '' : 's'})?`, cur.id);
  if (ask) return ask;
  const { error } = await v.admin.from('meal_plans').update({ is_deleted: true, updated_at: new Date().toISOString() }).eq('id', cur.id).eq('user_id', v.userId);
  if (error) throw new Error(error.message);
  await invalidateContext(v);
  console.log(`[vana] deletePlan user=${v.userId} id=${cur.id} week=${cur.weekStart}`);
  return receipt('delete_plan', 'plan', `Deleted the plan for ${label}`, cur.id, { id: cur.id });
}

// ---------------------------------------------------------------- events
export interface EventInput { name: string; date: string; time?: string | null; type: EventType; subtype?: EventSubtype | null; location?: string | null; registrationUrl?: string | null; goalTimeMinutes?: number | null }
export type EventPatch = Partial<EventInput>;

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const HHMM = /^\d{2}:\d{2}$/;
/** The app stores `start_time` as a naive local ISO string ("2026-11-22T06:30:00.000") and derives `event_date` from it. */
export function startTimeFor(date: string, time?: string | null): string {
  if (!ISO_DATE.test(date)) throw new Error(`date must be YYYY-MM-DD, got ${date}`);
  const t = time ?? DEFAULT_EVENT_TIME;
  if (!HHMM.test(t)) throw new Error(`time must be HH:MM, got ${t}`);
  return `${date}T${t}:00.000`;
}

// deno-lint-ignore no-explicit-any
const eventRow = (v: VanaCtx, id: string, i: EventInput): Record<string, any> => ({
  id, user_id: v.userId, origin: 'manual', activity_id: null,
  event_name: i.name, event_type: i.type, event_subtype: i.subtype ?? null, location: i.location ?? null, registration_url: i.registrationUrl ?? null,
  event_date: i.date, start_time: startTimeFor(i.date, i.time), goal_time_minutes: i.goalTimeMinutes ?? null,
  has_carb_loading: false, has_nutrition_plan: false,
  created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
});

/** A patch in the tool's terms → the `events` columns it touches. `date`/`time` move `start_time` together, the way the app does. */
// deno-lint-ignore no-explicit-any
export function eventColumns(patch: EventPatch, current: Record<string, any>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  if (patch.name !== undefined) out.event_name = patch.name;
  if (patch.type !== undefined) out.event_type = patch.type;
  if (patch.subtype !== undefined) out.event_subtype = patch.subtype;
  if (patch.location !== undefined) out.location = patch.location;
  if (patch.registrationUrl !== undefined) out.registration_url = patch.registrationUrl;
  if (patch.goalTimeMinutes !== undefined) out.goal_time_minutes = patch.goalTimeMinutes;
  if (patch.date !== undefined || patch.time !== undefined) {
    const date = patch.date ?? String(current.event_date ?? '');
    const time = patch.time ?? (typeof current.start_time === 'string' && current.start_time.length >= 16 ? current.start_time.slice(11, 16) : null);
    out.event_date = date; out.start_time = startTimeFor(date, time);
  }
  return out;
}

// deno-lint-ignore no-explicit-any
async function ownEvent(v: VanaCtx, id: string): Promise<Record<string, any>> {
  const { data, error } = await v.admin.from('events').select('*').eq('id', id).eq('user_id', v.userId).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data) throw new Error('event not found');
  return data;
}

export async function createEvent(v: VanaCtx, i: EventInput): Promise<ReceiptPart> {
  const id = crypto.randomUUID();
  const { error } = await v.admin.from('events').insert(eventRow(v, id, i));
  if (error) throw new Error(error.message);
  await invalidateContext(v); // the RACE line
  console.log(`[vana] createEvent user=${v.userId} id=${id} "${i.name}" ${i.date}`);
  return receipt('create_event', 'event', `Added ${i.name} · ${shortDate(i.date)}`, id, null);
}

export async function updateEvent(v: VanaCtx, id: string, patch: EventPatch): Promise<ReceiptPart> {
  const cur = await ownEvent(v, id);
  const cols = eventColumns(patch, cur);
  if (!Object.keys(cols).length) throw new Error('nothing to change');
  const before: Record<string, unknown> = {}; for (const k of Object.keys(cols)) before[k] = cur[k] ?? null;
  const { error } = await v.admin.from('events').update({ ...cols, updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', v.userId);
  if (error) throw new Error(error.message);
  await invalidateContext(v);
  const name = String(cols.event_name ?? cur.event_name ?? 'event');
  const date = String(cols.event_date ?? cur.event_date ?? '');
  return receipt('update_event', 'event', `Updated ${name} · ${shortDate(date)}`, id, { id, before });
}

export async function deleteEvent(v: VanaCtx, id: string, confirmed: boolean | undefined): Promise<ReceiptPart | NeedsConfirmationPart> {
  const cur = await ownEvent(v, id);
  const label = `${cur.event_name ?? 'event'}${cur.event_date ? ` on ${shortDate(String(cur.event_date))}` : ''}`;
  const ask = guardDelete(confirmed, 'delete_event', 'event', `Delete ${label}?`, id);
  if (ask) return ask;
  const { error } = await v.admin.from('events').delete().eq('id', id).eq('user_id', v.userId);
  if (error) throw new Error(error.message);
  await invalidateContext(v);
  console.log(`[vana] deleteEvent user=${v.userId} id=${id}`);
  // The row, less the device-only columns, so Undo re-inserts exactly what was there.
  const { needs_upload: _nu, local_updated_at: _lu, ...row } = cur;
  return receipt('delete_event', 'event', `Removed ${cur.event_name ?? 'event'}`, id, { row });
}

/** Every event with its id — the model needs ids for update/delete and getProfile only shows the next three. */
export async function listEvents(v: VanaCtx) {
  const { data, error } = await v.admin.from('events').select('id, event_name, event_date, event_type, event_subtype, location').eq('user_id', v.userId).order('event_date', { ascending: false }).limit(30);
  if (error) throw new Error(error.message);
  // deno-lint-ignore no-explicit-any
  return (data ?? []).map((e: any) => ({ id: e.id, name: e.event_name, date: e.event_date, type: e.event_type, distance: e.event_subtype, location: e.location, daysOut: e.event_date ? Math.round((new Date(e.event_date).getTime() - new Date(today()).getTime()) / 864e5) : null }));
}

// ---------------------------------------------------------------- activities (planned workouts)
/** `activities.intensity_level` (intensity_enum). */
export const INTENSITIES = ['easy', 'moderate', 'hard', 'race'] as const;
export type Intensity = typeof INTENSITIES[number];
export interface ActivityInput { title: string; date: string; time?: string | null; type: EventType; durationMinutes?: number | null; distanceMiles?: number | null; intensity?: Intensity | null; notes?: string | null }
export type ActivityPatch = Partial<ActivityInput>;
/** A workout the athlete named only by day starts at a training hour, not the event default. */
export const DEFAULT_ACTIVITY_TIME = '06:30';

/** The row `ActivityMapper.toSupabaseJson` sends: text id, `scheduled_date_time` as a naive local ISO, `status: 'planned'`, `origin` none. */
// deno-lint-ignore no-explicit-any
const activityRow = (v: VanaCtx, id: string, i: ActivityInput): Record<string, any> => ({
  id, user_id: v.userId, title: i.title, activity_type: i.type, status: 'planned',
  scheduled_date_time: startTimeFor(i.date, i.time ?? DEFAULT_ACTIVITY_TIME),
  duration_minutes: i.durationMinutes ?? null, distance_miles: i.distanceMiles ?? null, intensity_level: i.intensity ?? null, notes: i.notes ?? null,
  completion_type: 'manual', is_fasted: false, needs_nutrition_refresh: false,
  created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
});

/** A patch in the tool's terms → the `activities` columns it touches. `date`/`time` move `scheduled_date_time` together. */
// deno-lint-ignore no-explicit-any
export function activityColumns(patch: ActivityPatch, current: Record<string, any>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  if (patch.title !== undefined) out.title = patch.title;
  if (patch.type !== undefined) out.activity_type = patch.type;
  if (patch.durationMinutes !== undefined) out.duration_minutes = patch.durationMinutes;
  if (patch.distanceMiles !== undefined) out.distance_miles = patch.distanceMiles;
  if (patch.intensity !== undefined) out.intensity_level = patch.intensity;
  if (patch.notes !== undefined) out.notes = patch.notes;
  if (patch.date !== undefined || patch.time !== undefined) {
    const cur = typeof current.scheduled_date_time === 'string' ? current.scheduled_date_time : '';
    const date = patch.date ?? cur.slice(0, 10);
    const time = patch.time ?? (cur.length >= 16 ? cur.slice(11, 16) : DEFAULT_ACTIVITY_TIME);
    out.scheduled_date_time = startTimeFor(date, time);
    // The app flags a moved session so its fuelling plan is rebuilt; a server move must do the same.
    out.schedule_changed_at = new Date().toISOString(); out.needs_nutrition_refresh = true;
  }
  return out;
}

// deno-lint-ignore no-explicit-any
async function ownActivity(v: VanaCtx, id: string): Promise<Record<string, any>> {
  const { data, error } = await v.admin.from('activities').select('*').eq('id', id).eq('user_id', v.userId).maybeSingle();
  if (error) throw new Error(error.message);
  if (!data || data.deleted_at || data.status === 'deleted') throw new Error('workout not found');
  return data;
}

const activityLabel = (row: Record<string, unknown>) => `${row.title ?? 'workout'}${typeof row.scheduled_date_time === 'string' ? ` · ${shortDate(row.scheduled_date_time.slice(0, 10))}` : ''}`;

/** Planned and recent workouts with ids — the model needs ids for update/delete; the WEEK line in the context has none. */
export async function listActivities(v: VanaCtx, opts: { from?: string | null; to?: string | null } = {}) {
  const from = opts.from ?? (() => { const d = new Date(`${today()}T12:00:00Z`); d.setUTCDate(d.getUTCDate() - 7); return d.toISOString().slice(0, 10); })();
  const to = opts.to ?? (() => { const d = new Date(`${today()}T12:00:00Z`); d.setUTCDate(d.getUTCDate() + 28); return d.toISOString().slice(0, 10); })();
  const { data, error } = await v.admin.from('activities').select('id, title, activity_type, scheduled_date_time, duration_minutes, distance_miles, intensity_level, status, completed_at, synced_from_provider')
    .eq('user_id', v.userId).is('deleted_at', null).neq('status', 'deleted').gte('scheduled_date_time', `${from}T00:00:00`).lte('scheduled_date_time', `${to}T23:59:59`).order('scheduled_date_time', { ascending: true }).limit(60);
  if (error) throw new Error(error.message);
  // deno-lint-ignore no-explicit-any
  return (data ?? []).map((a: any) => ({ id: a.id, title: a.title, type: a.activity_type, date: String(a.scheduled_date_time ?? '').slice(0, 10), time: String(a.scheduled_date_time ?? '').slice(11, 16) || null, durationMinutes: a.duration_minutes, distanceMiles: a.distance_miles, intensity: a.intensity_level, status: a.status, completed: !!a.completed_at, from: a.synced_from_provider ?? 'manual' }));
}

export async function createActivity(v: VanaCtx, i: ActivityInput): Promise<ReceiptPart> {
  const id = crypto.randomUUID();
  const row = activityRow(v, id, i);
  const { error } = await v.admin.from('activities').insert(row);
  if (error) throw new Error(error.message);
  await invalidateContext(v); // the WEEK line
  console.log(`[vana] createActivity user=${v.userId} id=${id} "${i.title}" ${i.date}`);
  return receipt('create_activity', 'activity', `Added ${activityLabel(row)}`, id, { id });
}

export async function updateActivity(v: VanaCtx, id: string, patch: ActivityPatch): Promise<ReceiptPart> {
  const cur = await ownActivity(v, id);
  const cols = activityColumns(patch, cur);
  if (!Object.keys(cols).length) throw new Error('nothing to change');
  const before: Record<string, unknown> = {}; for (const k of Object.keys(cols)) before[k] = cur[k] ?? null;
  const { error } = await v.admin.from('activities').update({ ...cols, updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', v.userId);
  if (error) throw new Error(error.message);
  await invalidateContext(v);
  return receipt('update_activity', 'activity', `Updated ${activityLabel({ ...cur, ...cols })}`, id, { id, before });
}

/** The same tombstone the app leaves (`status: 'deleted'` + `deleted_at`), so every device's sync matcher sees it. */
export async function deleteActivity(v: VanaCtx, id: string, confirmed: boolean | undefined): Promise<ReceiptPart | NeedsConfirmationPart> {
  const cur = await ownActivity(v, id);
  const ask = guardDelete(confirmed, 'delete_activity', 'activity', `Delete ${activityLabel(cur)}?`, id);
  if (ask) return ask;
  const now = new Date().toISOString();
  const { error } = await v.admin.from('activities').update({ status: 'deleted', deleted_at: now, updated_at: now }).eq('id', id).eq('user_id', v.userId);
  if (error) throw new Error(error.message);
  await invalidateContext(v);
  console.log(`[vana] deleteActivity user=${v.userId} id=${id}`);
  return receipt('delete_activity', 'activity', `Removed ${cur.title ?? 'the workout'}`, id, { id, before: { status: cur.status ?? 'planned' } });
}

// ---------------------------------------------------------------- meal logs
export interface LogItem { name: string; portion?: string | null; calories?: number | null; carbG?: number | null; proteinG?: number | null; fatG?: number | null }
export interface FreeTextLog { name: string; mealType: 'breakfast' | 'lunch' | 'dinner' | 'snack'; date?: string | null; kcal?: number | null; carbsG?: number | null; proteinG?: number | null; fatG?: number | null; items?: LogItem[] | null; notes?: string | null }

/** The `meal_logs.items` component shape (`MealComponent.toJson`). */
const componentRow = (c: LogItem) => ({ name: c.name, portion: c.portion ?? '', ...(c.calories != null ? { calories: c.calories } : {}), ...(c.carbG != null ? { carb_g: c.carbG } : {}), ...(c.proteinG != null ? { protein_g: c.proteinG } : {}), ...(c.fatG != null ? { fat_g: c.fatG } : {}) });

/** A plan meal: the same `plan_log_from_plan` transaction the app's "Ate it" runs. A free-text meal: the Describe row. */
export async function logMeal(v: VanaCtx, i: { planMealId?: string | null; mealType?: FreeTextLog['mealType'] | null; date?: string | null } & Partial<FreeTextLog>): Promise<ReceiptPart> {
  const logDate = i.date ?? today();
  if (!ISO_DATE.test(logDate)) throw new Error(`date must be YYYY-MM-DD, got ${logDate}`);
  if (i.planMealId) {
    const r = await plan.logFromPlan(v, i.planMealId, i.mealType ?? undefined, logDate);
    return receipt('log_meal', 'meal_log', `Logged ${r.name} · ${r.servingsLeft} left`, r.logId, { logId: r.logId, planMealId: i.planMealId });
  }
  const name = (i.name ?? '').trim();
  if (!name) throw new Error('name is required for a meal that is not on the plan');
  if (!i.mealType) throw new Error('mealType is required');
  const items = (i.items ?? []).map(componentRow);
  const sum = (k: 'calories' | 'carb_g' | 'protein_g' | 'fat_g') => items.some((x) => k in x) ? items.reduce((s, x) => s + Number((x as Record<string, unknown>)[k] ?? 0), 0) : null;
  const { data, error } = await v.admin.from('meal_logs').insert({
    user_id: v.userId, log_date: logDate, slot: i.mealType, name, source: 'describe', items,
    calories: i.kcal ?? sum('calories'), carbs_g: i.carbsG ?? sum('carb_g'), protein_g: i.proteinG ?? sum('protein_g'), fat_g: i.fatG ?? sum('fat_g'),
    notes: i.notes ?? null, eaten_at: logDate === today() ? new Date().toISOString() : `${logDate}T12:00:00Z`,
  }).select('id').single();
  if (error) throw new Error(error.message);
  await invalidateContext(v); // LOGGED TODAY
  const id = String(data.id);
  console.log(`[vana] logMeal user=${v.userId} id=${id} "${name}" ${logDate}`);
  return receipt('log_meal', 'meal_log', `Logged ${name}${logDate === today() ? '' : ` · ${shortDate(logDate)}`}`, id, { logId: id });
}

export async function deleteLoggedMeal(v: VanaCtx, id: string, confirmed: boolean | undefined): Promise<ReceiptPart | NeedsConfirmationPart> {
  const { data: cur, error: readError } = await v.admin.from('meal_logs').select('id, name, log_date, is_deleted').eq('id', id).eq('user_id', v.userId).maybeSingle();
  if (readError) throw new Error(readError.message);
  if (!cur || cur.is_deleted) throw new Error('logged meal not found');
  const ask = guardDelete(confirmed, 'delete_logged_meal', 'meal_log', `Remove ${cur.name} from ${shortDate(String(cur.log_date))}?`, id);
  if (ask) return ask;
  const { error } = await v.admin.from('meal_logs').update({ is_deleted: true, updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', v.userId);
  if (error) throw new Error(error.message);
  await invalidateContext(v);
  return receipt('delete_logged_meal', 'meal_log', `Removed ${cur.name}`, id, { logId: id });
}

// ---------------------------------------------------------------- undo
/** The Undo button: `params` is what the receipt carried. Answers a receipt of its own (no further undo). */
export async function undoReceipt(v: VanaCtx, params: Record<string, unknown>): Promise<ReceiptPart> {
  const action = String(params.action ?? '');
  switch (action) {
    case 'delete_plan': {
      const id = String(params.id ?? '');
      if (!id) throw new Error('undo delete_plan needs id');
      const { data: cur } = await v.admin.from('meal_plans').select('id, week_start').eq('id', id).eq('user_id', v.userId).maybeSingle();
      if (!cur) throw new Error('plan not found');
      const { error } = await v.admin.from('meal_plans').update({ is_deleted: false, updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', v.userId);
      if (error) throw new Error(error.message);
      await invalidateContext(v);
      return receipt('undo', 'plan', `Put back the plan for ${await planLabel(v, String(cur.week_start))}`, id, null);
    }
    case 'create_activity': {
      const id = String(params.id ?? '');
      if (!id) throw new Error('undo create_activity needs id');
      const cur = await ownActivity(v, id);
      const now = new Date().toISOString();
      const { error } = await v.admin.from('activities').update({ status: 'deleted', deleted_at: now, updated_at: now }).eq('id', id).eq('user_id', v.userId);
      if (error) throw new Error(error.message);
      await invalidateContext(v);
      return receipt('undo', 'activity', `Removed ${String(cur.title ?? 'the workout')}`, id, null);
    }
    case 'update_activity': {
      const id = String(params.id ?? ''); const before = params.before as Record<string, unknown> | undefined;
      if (!id || !before) throw new Error('undo update_activity needs id and before');
      const cur = await ownActivity(v, id);
      const { error } = await v.admin.from('activities').update({ ...before, updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', v.userId);
      if (error) throw new Error(error.message);
      await invalidateContext(v);
      return receipt('undo', 'activity', `Reverted ${String(before.title ?? cur.title ?? 'the workout')}`, id, null);
    }
    case 'delete_activity': {
      const id = String(params.id ?? ''); const before = (params.before ?? {}) as Record<string, unknown>;
      if (!id) throw new Error('undo delete_activity needs id');
      const { data: cur } = await v.admin.from('activities').select('id, title').eq('id', id).eq('user_id', v.userId).maybeSingle();
      if (!cur) throw new Error('workout not found');
      const { error } = await v.admin.from('activities').update({ status: String(before.status ?? 'planned'), deleted_at: null, updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', v.userId);
      if (error) throw new Error(error.message);
      await invalidateContext(v);
      return receipt('undo', 'activity', `Put back ${String(cur.title ?? 'the workout')}`, id, null);
    }
    case 'delete_event': {
      const row = params.row as Record<string, unknown> | undefined;
      if (!row || typeof row.id !== 'string') throw new Error('undo delete_event needs the row');
      const { error } = await v.admin.from('events').insert({ ...row, user_id: v.userId, needs_upload: false });
      if (error) throw new Error(error.message);
      await invalidateContext(v);
      return receipt('undo', 'event', `Put back ${String(row.event_name ?? 'the event')}`, row.id, null);
    }
    case 'update_event': {
      const id = String(params.id ?? ''); const before = params.before as Record<string, unknown> | undefined;
      if (!id || !before) throw new Error('undo update_event needs id and before');
      const cur = await ownEvent(v, id);
      const { error } = await v.admin.from('events').update({ ...before, updated_at: new Date().toISOString() }).eq('id', id).eq('user_id', v.userId);
      if (error) throw new Error(error.message);
      await invalidateContext(v);
      return receipt('undo', 'event', `Reverted ${String(before.event_name ?? cur.event_name ?? 'the event')}`, id, null);
    }
    case 'log_meal': {
      const logId = String(params.logId ?? ''); const planMealId = params.planMealId ? String(params.planMealId) : null;
      if (!logId) throw new Error('undo log_meal needs logId');
      const { data: cur } = await v.admin.from('meal_logs').select('name').eq('id', logId).eq('user_id', v.userId).maybeSingle();
      const { error } = await v.admin.from('meal_logs').update({ is_deleted: true, updated_at: new Date().toISOString() }).eq('id', logId).eq('user_id', v.userId);
      if (error) throw new Error(error.message);
      if (planMealId) { // the serving goes back on the plan
        const { data: m } = await v.admin.from('plan_meals').select('servings, servings_left').eq('id', planMealId).eq('user_id', v.userId).maybeSingle();
        if (m) await v.admin.from('plan_meals').update({ servings_left: Math.min(m.servings, m.servings_left + 1), updated_at: new Date().toISOString() }).eq('id', planMealId).eq('user_id', v.userId);
      }
      await invalidateContext(v);
      return receipt('undo', 'meal_log', `Unlogged ${cur?.name ?? 'the meal'}`, logId, null);
    }
    case 'delete_logged_meal': {
      const logId = String(params.logId ?? '');
      if (!logId) throw new Error('undo delete_logged_meal needs logId');
      const { data: cur } = await v.admin.from('meal_logs').select('name').eq('id', logId).eq('user_id', v.userId).maybeSingle();
      const { error } = await v.admin.from('meal_logs').update({ is_deleted: false, updated_at: new Date().toISOString() }).eq('id', logId).eq('user_id', v.userId);
      if (error) throw new Error(error.message);
      await invalidateContext(v);
      return receipt('undo', 'meal_log', `Put back ${cur?.name ?? 'the meal'}`, logId, null);
    }
    default: throw new Error(`nothing to undo for ${action || '(no action)'}`);
  }
}
