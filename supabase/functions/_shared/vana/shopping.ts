/** Shopping lists with their own rows (2026-09-16, Lee's playtest §5 option C + §6).
 *
 *  A list is `shopping_lists` + `shopping_items`. A plan owns at most one list (plan_id); a hand-made list has none.
 *  `syncPlanList` is what `refreshShopping` / `confirmPlan` call: the plan-built lines replace the list's
 *  `source='plan'` rows, while `manual` rows and `edited=true` rows are kept untouched. `checked` / `have` carry over
 *  by name, as the jsonb column always did. The merged list is also what `meal_plans.shopping` mirrors, so Kroger and
 *  every older reader see the same lines the tab does. The merge rule is a pure function ([mergePlanItems]) so the
 *  survival of a hand-added or renamed line is unit-tested without a database. */
import type { ShoppingItem, ShoppingListItem, ShoppingListSummary, ShoppingListDetail } from './contracts.ts';
import type { VanaCtx } from './env.ts';
import { today, weekStartFor } from './env.ts';
import { classifyAisle } from './grocery.ts';
import { getPlanPeriod } from './memory.ts';

const AISLE_ORDER = ['Produce', 'Protein', 'Dairy', 'Bakery & Grains', 'Pantry', 'Spices', 'Frozen', 'Beverages', 'Other'];
const now = () => new Date().toISOString();
const key = (name: string) => name.trim().toLowerCase();

// deno-lint-ignore no-explicit-any
export const toItem = (r: any): ShoppingListItem => ({ id: r.id, listId: r.list_id, aisle: r.aisle ?? 'Other', name: r.name, qty: r.qty ?? '', checked: !!r.checked, have: !!r.have, fromMealIds: (r.from_meal_ids ?? []) as string[], source: r.source === 'plan' ? 'plan' : 'manual', edited: !!r.edited, position: r.position ?? 0 });
// deno-lint-ignore no-explicit-any
const toSummary = (r: any, itemCount: number): ShoppingListSummary => ({ id: r.id, planId: r.plan_id ?? null, name: r.name ?? '', createdAt: r.created_at, updatedAt: r.updated_at ?? r.created_at, confirmedAt: r.confirmed_at ?? null, itemCount });

/** The jsonb-shaped line (what `meal_plans.shopping` and the `shopping_list` part carry). */
export const toPlain = (i: ShoppingListItem): ShoppingItem => ({ aisle: i.aisle, name: i.name, qty: i.qty, checked: i.checked, have: i.have, fromMealIds: i.fromMealIds });

/** Sort like grocery.ts: aisle order, then name. */
export function sortItems<T extends { aisle: string; name: string }>(items: T[]): T[] {
  return [...items].sort((a, b) => (AISLE_ORDER.indexOf(a.aisle) === -1 ? 99 : AISLE_ORDER.indexOf(a.aisle)) - (AISLE_ORDER.indexOf(b.aisle) === -1 ? 99 : AISLE_ORDER.indexOf(b.aisle)) || a.name.localeCompare(b.name));
}

/** The merge rule, pure. `prev` = the list's rows today; `fresh` = the lines the plan's meals build now.
 *  - manual rows and edited plan rows are kept exactly (by id);
 *  - every other plan row is dropped and replaced by the fresh lines;
 *  - a fresh line whose name matches a kept row is NOT duplicated (the kept row wins — the athlete renamed or added it);
 *  - `checked` / `have` carry over from a dropped plan row of the same name. */
export function mergePlanItems(prev: ShoppingListItem[], fresh: ShoppingItem[]): { keep: ShoppingListItem[]; insert: Omit<ShoppingListItem, 'id' | 'listId'>[]; drop: string[] } {
  const keep = prev.filter((p) => p.source === 'manual' || p.edited);
  const dropped = prev.filter((p) => !(p.source === 'manual' || p.edited));
  const keptNames = new Set(keep.map((k) => key(k.name)));
  const carry = new Map(dropped.map((d) => [key(d.name), d]));
  const insert = fresh.filter((f) => !keptNames.has(key(f.name))).map((f, i) => { const c = carry.get(key(f.name)); return { ...f, checked: c ? c.checked : f.checked, have: f.have || (c ? c.have : false), source: 'plan' as const, edited: false, position: i }; });
  return { keep, insert, drop: dropped.map((d) => d.id) };
}

async function itemsOf(v: VanaCtx, listId: string): Promise<ShoppingListItem[]> {
  const { data } = await v.db.from('shopping_items').select('*').eq('list_id', listId).eq('user_id', v.userId).order('position').order('created_at');
  return sortItems((data ?? []).map(toItem));
}
// deno-lint-ignore no-explicit-any
async function detail(v: VanaCtx, row: any): Promise<ShoppingListDetail> {
  const items = await itemsOf(v, row.id);
  return { ...toSummary(row, items.filter((i) => !i.have).length), items };
}
// deno-lint-ignore no-explicit-any
async function listRow(v: VanaCtx, id: string): Promise<any> {
  const { data } = await v.db.from('shopping_lists').select('*').eq('id', id).eq('user_id', v.userId).maybeSingle();
  if (!data) throw new Error('shopping list not found');
  return data;
}
async function touch(v: VanaCtx, listId: string) { await v.db.from('shopping_lists').update({ updated_at: now() }).eq('id', listId).eq('user_id', v.userId); }

/** Mirror a list into `meal_plans.shopping` (when it belongs to a plan) so older readers stay right. */
export async function mirrorToPlan(v: VanaCtx, listId: string): Promise<ShoppingItem[]> {
  const row = await listRow(v, listId);
  const items = (await itemsOf(v, listId)).map(toPlain);
  if (row.plan_id) await v.db.from('meal_plans').update({ shopping: items, updated_at: now() }).eq('id', row.plan_id).eq('user_id', v.userId);
  return items;
}

// ---------------------------------------------------------------- plan ↔ list
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
/** A plan's list name: its week in words, "Week of Sep 20", like the Plan tab's "Sep 20 – Sep 26" (16-007). Read from
 *  the `YYYY-MM-DD` string itself, never through a Date, so no time zone can move the day. Lists made before
 *  2026-09-25 keep their stored "Week of 2026-09-20"; the app shows those in words too. */
export function weekListName(weekStart: string): string {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(weekStart);
  const month = m ? MONTHS[Number(m[2]) - 1] : undefined;
  return month ? `Week of ${month} ${Number(m![3])}` : `Week of ${weekStart}`;
}
/** The plan's list, made on first use. Named after the week ([weekListName]). A plan has at most one list (ticket 96,
 *  Lee 09-25; the unique index `shopping_lists_plan_idx` holds it in SQL): confirm, every edit and Rebuild land here and
 *  update that list in place. Two writes racing to make it both see none; the loser's insert hits the index and reads
 *  the winner's list back instead of failing the edit. */
// deno-lint-ignore no-explicit-any
export async function ensurePlanList(v: VanaCtx, planId: string, weekStart: string): Promise<any> {
  // deno-lint-ignore no-explicit-any
  const existing = async (): Promise<any> => (await v.db.from('shopping_lists').select('*').eq('plan_id', planId).eq('user_id', v.userId).order('created_at').limit(1).maybeSingle()).data;
  const found = await existing();
  if (found) return found;
  const { data: made, error } = await v.db.from('shopping_lists').insert({ user_id: v.userId, plan_id: planId, name: weekListName(weekStart) }).select('*').single();
  if (!error) return made;
  const raced = await existing();
  if (raced) return raced;
  throw new Error(error.message);
}
/** The plan's own list with its rows, or null when it has none (never made, or deleted). */
export async function planList(v: VanaCtx, planId: string): Promise<ShoppingListDetail | null> {
  const { data } = await v.db.from('shopping_lists').select('*').eq('plan_id', planId).eq('user_id', v.userId).order('created_at').limit(1).maybeSingle();
  return data ? detail(v, data) : null;
}
/** Replace the plan's rows from `fresh`, keep manual / edited rows, and answer the whole list as plain lines
 *  (the caller writes those to `meal_plans.shopping`). */
export async function syncPlanList(v: VanaCtx, plan: { id: string; weekStart: string; status: string }, fresh: ShoppingItem[]): Promise<ShoppingItem[]> {
  // An archived draft lost its list with the archive (ticket 101); a pick still reaching it (mp-683) must not make it
  // again. An archived plan that was once confirmed stays editable (mp-675) and rebuilds its list as before.
  if (plan.status === 'archived' && !(await planList(v, plan.id)) && !(await wasConfirmed(v, plan.id))) return fresh;
  const list = await ensurePlanList(v, plan.id, plan.weekStart);
  const prev = await itemsOf(v, list.id);
  const { keep, insert, drop } = mergePlanItems(prev, fresh);
  if (drop.length) await v.db.from('shopping_items').delete().in('id', drop).eq('user_id', v.userId);
  if (insert.length) {
    const { error } = await v.db.from('shopping_items').insert(insert.map((i) => ({ list_id: list.id, user_id: v.userId, name: i.name, qty: i.qty, aisle: i.aisle, checked: i.checked, have: i.have, source: 'plan', from_meal_ids: i.fromMealIds, edited: false, position: keep.length + i.position })));
    if (error) throw new Error(error.message);
  }
  await touch(v, list.id);
  return (await itemsOf(v, list.id)).map(toPlain);
}
const wasConfirmed = async (v: VanaCtx, planId: string): Promise<boolean> =>
  (await v.db.from('meal_plans').select('confirmed_at').eq('id', planId).eq('user_id', v.userId).maybeSingle()).data?.confirmed_at != null;
/** After `confirm_meal_plan`: the list takes the plan's confirmation time, which is what sorts it to the top. */
export async function markListConfirmed(v: VanaCtx, planId: string): Promise<void> {
  await v.db.from('shopping_lists').update({ confirmed_at: now(), updated_at: now() }).eq('plan_id', planId).eq('user_id', v.userId);
}
/** Rebuild on a confirmed plan whose list was deleted: the new list is the confirmed plan's list, so it carries a
 *  confirmation time like the one it replaces. A list that already has one keeps it. */
export async function markListConfirmedIfUnset(v: VanaCtx, planId: string): Promise<void> {
  await v.db.from('shopping_lists').update({ confirmed_at: now(), updated_at: now() }).eq('plan_id', planId).eq('user_id', v.userId).is('confirmed_at', null);
}
/** A draft's list goes with its draft (ticket 101, Lee 2026-09-25): once a plan that was never confirmed is archived
 *  (another plan's confirm, `new_plan`, `use_plan_again`), its list and rows are deleted, so Previous lists holds only
 *  confirmed plans' lists and hand-made ones. "Never confirmed" is the plan's `confirmed_at` unset AND the list's own
 *  `confirmed_at` unset: the list's stamp (markListConfirmed, since 2026-09-16) guards a plan confirmed before the plan
 *  column's backfill. Scoped to one week so a later archive in that week also clears any leftover; idempotent. Answers
 *  how many lists went. The same predicate cleans existing lists in 20260925170100_drop_archived_draft_lists.sql. */
export async function dropArchivedDraftLists(v: VanaCtx, weekStart: string): Promise<number> {
  const { data: plans, error: e0 } = await v.db.from('meal_plans').select('id').eq('user_id', v.userId).eq('week_start', weekStart)
    .eq('status', 'archived').is('confirmed_at', null);
  if (e0) throw new Error(e0.message);
  const planIds = (plans ?? []).map((p: { id: string }) => p.id);
  if (!planIds.length) return 0;
  const { data: lists, error: e1 } = await v.db.from('shopping_lists').select('id').eq('user_id', v.userId).in('plan_id', planIds).is('confirmed_at', null);
  if (e1) throw new Error(e1.message);
  const listIds = (lists ?? []).map((l: { id: string }) => l.id);
  if (!listIds.length) return 0;
  // Rows also cascade in SQL; deleted here too so the fake db agrees (as deleteList does).
  const { error: e2 } = await v.db.from('shopping_items').delete().in('list_id', listIds).eq('user_id', v.userId);
  if (e2) throw new Error(e2.message);
  const { error: e3 } = await v.db.from('shopping_lists').delete().in('id', listIds).eq('user_id', v.userId);
  if (e3) throw new Error(e3.message);
  return listIds.length;
}
/** The legacy `toggle_shopping {name}` path: keep the list row in step with the jsonb flip. */
export async function toggleByName(v: VanaCtx, planId: string, name: string, field: 'checked' | 'have', value: boolean): Promise<void> {
  const { data: list } = await v.db.from('shopping_lists').select('id').eq('plan_id', planId).eq('user_id', v.userId).maybeSingle();
  if (!list) return;
  const items = await itemsOf(v, list.id);
  for (const i of items) if (key(i.name) === key(name)) await v.db.from('shopping_items').update({ [field]: value }).eq('id', i.id).eq('user_id', v.userId);
}

// ---------------------------------------------------------------- the actions
/** The week's confirmed plan: the plan the Plan tab shows once the athlete has confirmed (plan.ts `getPlan`, same week
 *  rule; plan.ts imports this file, so the week is worked out here rather than imported). */
async function confirmedPlanId(v: VanaCtx): Promise<string | null> {
  const week = weekStartFor(today(), (await getPlanPeriod(v)).weekStart);
  const { data } = await v.db.from('meal_plans').select('id').eq('user_id', v.userId).eq('week_start', week).eq('status', 'confirmed').eq('is_deleted', false).limit(1).maybeSingle();
  return data?.id ?? null;
}
/** Every list the athlete owns, newest first by coalesce(confirmed_at, created_at), with the default list (below) moved
 *  to the front so the tab's "current" list and its default agree. */
// deno-lint-ignore no-explicit-any
async function orderedRows(v: VanaCtx): Promise<{ rows: any[]; current: any | null }> {
  const { data } = await v.db.from('shopping_lists').select('*').eq('user_id', v.userId).limit(200);
  const rows = (data ?? []).slice().sort((a, b) => String(b.confirmed_at ?? b.created_at).localeCompare(String(a.confirmed_at ?? a.created_at)));
  const planId = await confirmedPlanId(v);
  // The default (ticket 35, mp-244): the confirmed plan's list; else the newest hand-made list; else none. A draft's list
  // (Browse and chat edits build one), an archived plan's list and another week's list are never the default.
  const current = (planId ? rows.find((r) => r.plan_id === planId) : undefined) ?? rows.find((r) => !r.plan_id) ?? null;
  return { rows: current ? [current, ...rows.filter((r) => r !== current)] : rows, current };
}
export async function listLists(v: VanaCtx, limit = 30): Promise<ShoppingListSummary[]> {
  const { rows } = await orderedRows(v);
  const out: ShoppingListSummary[] = [];
  for (const r of rows.slice(0, limit)) { const items = await itemsOf(v, r.id); out.push(toSummary(r, items.filter((i) => !i.have).length)); }
  return out;
}
/** `id` given → that list; else the default list: this week's confirmed plan's list, else the newest hand-made list by
 *  coalesce(confirmed_at, created_at); none → null (the tab's empty state). */
export async function getList(v: VanaCtx, id?: string | null): Promise<ShoppingListDetail | null> {
  if (id) return detail(v, await listRow(v, id));
  const { current } = await orderedRows(v);
  return current ? detail(v, current) : null;
}
/** A new hand-made list (empty), or one seeded from the plan's current lines when `fromPlan` names a plan. */
export async function createList(v: VanaCtx, name: string | null, seed: ShoppingItem[] | null): Promise<ShoppingListDetail> {
  const { data: made, error } = await v.db.from('shopping_lists').insert({ user_id: v.userId, plan_id: null, name: name?.trim() || `List ${new Date().toISOString().slice(0, 10)}` }).select('*').single();
  if (error) throw new Error(error.message);
  if (seed?.length) {
    const { error: e2 } = await v.db.from('shopping_items').insert(seed.map((i, position) => ({ list_id: made.id, user_id: v.userId, name: i.name, qty: i.qty, aisle: i.aisle, checked: false, have: i.have, source: 'manual', from_meal_ids: i.fromMealIds ?? [], edited: false, position })));
    if (e2) throw new Error(e2.message);
  }
  return detail(v, made);
}
export async function renameList(v: VanaCtx, id: string, name: string): Promise<ShoppingListDetail> {
  const clean = name.trim(); if (!clean) throw new Error('name required');
  await listRow(v, id);
  await v.db.from('shopping_lists').update({ name: clean, updated_at: now() }).eq('id', id).eq('user_id', v.userId);
  return detail(v, await listRow(v, id));
}
/** Delete a list and every row on it (the rows also cascade in SQL; deleted here too so the fake db agrees). Owner-scoped
 *  like the rest. A plan's list takes the plan's mirror with it, so Kroger and the offline stand-in stop showing lines the
 *  athlete threw away; the next meal edit, or the Plan tab's Rebuild shopping list (ticket 96), rebuilds both. Answers the default list left ([getList]), or null when none is. */
export async function deleteList(v: VanaCtx, id: string): Promise<ShoppingListDetail | null> {
  const row = await listRow(v, id);
  const { error: e1 } = await v.db.from('shopping_items').delete().eq('list_id', id).eq('user_id', v.userId);
  if (e1) throw new Error(e1.message);
  const { error: e2 } = await v.db.from('shopping_lists').delete().eq('id', id).eq('user_id', v.userId);
  if (e2) throw new Error(e2.message);
  if (row.plan_id) await v.db.from('meal_plans').update({ shopping: [], updated_at: now() }).eq('id', row.plan_id).eq('user_id', v.userId);
  return getList(v, null);
}
export async function addItem(v: VanaCtx, listId: string, name: string, qty: string, aisle?: string | null): Promise<ShoppingListDetail> {
  const clean = name.trim(); if (!clean) throw new Error('name required');
  const list = await listRow(v, listId);
  const items = await itemsOf(v, listId);
  const { error } = await v.db.from('shopping_items').insert({ list_id: listId, user_id: v.userId, name: clean, qty: (qty ?? '').trim(), aisle: aisle?.trim() || classifyAisle(clean), checked: false, have: false, source: 'manual', from_meal_ids: [], edited: false, position: items.length });
  if (error) throw new Error(error.message);
  await touch(v, listId);
  await mirrorToPlan(v, listId);
  return detail(v, list);
}
export type ItemPatch = { name?: string; qty?: string; aisle?: string; checked?: boolean; have?: boolean };
/** name / qty changes mark the row `edited` (it then survives a re-plan); checked / have / aisle do not. */
export async function updateItem(v: VanaCtx, id: string, patch: ItemPatch): Promise<ShoppingListDetail> {
  const { data: row } = await v.db.from('shopping_items').select('*').eq('id', id).eq('user_id', v.userId).maybeSingle();
  if (!row) throw new Error('shopping item not found');
  const fields: Record<string, unknown> = {};
  if (patch.name !== undefined) { const n = patch.name.trim(); if (!n) throw new Error('name required'); if (n !== row.name) { fields.name = n; fields.edited = true; } }
  if (patch.qty !== undefined && patch.qty.trim() !== (row.qty ?? '')) { fields.qty = patch.qty.trim(); fields.edited = true; }
  if (patch.aisle !== undefined && patch.aisle.trim()) fields.aisle = patch.aisle.trim();
  if (patch.checked !== undefined) fields.checked = !!patch.checked;
  if (patch.have !== undefined) fields.have = !!patch.have;
  if (Object.keys(fields).length) { const { error } = await v.db.from('shopping_items').update(fields).eq('id', id).eq('user_id', v.userId); if (error) throw new Error(error.message); }
  await touch(v, row.list_id);
  await mirrorToPlan(v, row.list_id);
  return detail(v, await listRow(v, row.list_id));
}
/** Deleting a plan-built row is how "a meal that cannot be broken down" is edited away. Deleted outright it would
 *  come back on the next meal edit (every edit rebuilds the plan rows), so a plan row becomes a tombstone instead:
 *  `have=true, edited=true` — off the list, out of the count, kept by the merge, and one "Add back" from returning.
 *  A manual row is simply deleted. */
export async function deleteItem(v: VanaCtx, id: string): Promise<ShoppingListDetail> {
  const { data: row } = await v.db.from('shopping_items').select('*').eq('id', id).eq('user_id', v.userId).maybeSingle();
  if (!row) throw new Error('shopping item not found');
  const { error } = row.source === 'plan'
    ? await v.db.from('shopping_items').update({ have: true, edited: true, checked: false }).eq('id', id).eq('user_id', v.userId)
    : await v.db.from('shopping_items').delete().eq('id', id).eq('user_id', v.userId);
  if (error) throw new Error(error.message);
  await touch(v, row.list_id);
  await mirrorToPlan(v, row.list_id);
  return detail(v, await listRow(v, row.list_id));
}
