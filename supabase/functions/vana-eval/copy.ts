/**
 * The throwaway copy of an Eval athlete (eval-v2 ticket 02, spec "vana-eval").
 *
 * A Run never touches the Eval athlete it starts from. `vana-eval` creates a dev auth user for the Run, seeds it
 * from the snapshot, lets Vana read and write it through her normal tools, and deletes it when the Run ends. This
 * module owns the data side of that: which tables a snapshot holds, how a snapshot becomes rows of a new user,
 * how the copy is read back, and how it is removed.
 *
 * A snapshot is producer-shaped: rows exactly as `select *` returns them from each table, keyed by table name,
 * plus the id of the user they belong to. Seeding gives every row a fresh id and rewrites every reference to an
 * old id (the user's, or another snapshot row's) to the new one, nested JSON included, so a copy's plan points
 * at the copy's conversation and never at the source's. Ids the snapshot does not own (the meal library) stay.
 *
 * Every write goes through the service role: the copy's rows are seeded before the copy has a session, and the
 * users row carries the flags only the service role may set. The copy is never an admin.
 */
import type { Db } from '../_shared/vana/env.ts';

// deno-lint-ignore no-explicit-any
export type Row = Record<string, any>;

/** The tables an Eval athlete snapshot holds: everything Vana reads or writes for one athlete. Parents before
 *  children, so seeding in this order satisfies every foreign key and removing in reverse order does too
 *  (`meal_plans.conversation_id` and `meal_logs.plan_meal_id` do not cascade). */
export const COPY_TABLES = [
  'users', 'onboarding_surveys', 'activities', 'events', 'daily_macro_targets', 'user_memories', 'user_foods',
  'saved_meals', 'vana_conversations', 'vana_messages', 'meal_plans', 'plan_meals', 'meal_logs',
  'shopping_lists', 'shopping_items', 'plan_debriefs', 'meal_feedback', 'user_feedback',
] as const;
export type CopyTable = typeof COPY_TABLES[number];

export interface AthleteSnapshot {
  /** The user the rows belong to: the source athlete's id in an Eval athlete, the copy's id in a Run's snapshot. */
  user_id: string;
  tables: Partial<Record<CopyTable, Row[]>>;
}

/** The column that says whose row it is. */
export const ownerColumn = (t: CopyTable) => (t === 'users' ? 'id' : 'user_id');
/** A column that orders a table's rows the same way every read. */
export const orderColumn = (t: CopyTable) => (t === 'onboarding_surveys' ? 'user_id' : 'id');

/** How long a copy may live before the sweep removes it. A Run takes minutes; this is for one that died mid-way. */
export const COPY_MAX_AGE_MS = 2 * 3600_000;

export class BadSnapshotError extends Error {}

/** A snapshot as the request sent it, checked: an object with a user id, a users row for that user, and only
 *  tables this module knows. Anything else is a 400 before a user is created. */
export function parseSnapshot(raw: unknown): AthleteSnapshot {
  const s = raw as { user_id?: unknown; tables?: unknown } | null;
  if (!s || typeof s !== 'object' || typeof s.user_id !== 'string' || !s.user_id) throw new BadSnapshotError('snapshot.user_id is required');
  if (!s.tables || typeof s.tables !== 'object' || Array.isArray(s.tables)) throw new BadSnapshotError('snapshot.tables must be an object');
  const tables = s.tables as Record<string, unknown>;
  for (const [t, rows] of Object.entries(tables)) {
    if (!(COPY_TABLES as readonly string[]).includes(t)) throw new BadSnapshotError(`snapshot table ${t} is not one vana-eval copies`);
    if (!Array.isArray(rows) || rows.some((r) => !r || typeof r !== 'object' || Array.isArray(r))) throw new BadSnapshotError(`snapshot table ${t} must be an array of rows`);
  }
  const users = (tables.users ?? []) as Row[];
  if (users.length !== 1 || users[0].id !== s.user_id) throw new BadSnapshotError('snapshot.tables.users must hold exactly the row for snapshot.user_id');
  return { user_id: s.user_id, tables: tables as AthleteSnapshot['tables'] };
}

/** Every string in `x` that is a key of `ids`, replaced by its value, at any depth. */
function remap(x: unknown, ids: Map<string, string>): unknown {
  if (typeof x === 'string') return ids.get(x) ?? x;
  if (Array.isArray(x)) return x.map((y) => remap(y, ids));
  if (x && typeof x === 'object') return Object.fromEntries(Object.entries(x).map(([k, y]) => [k, remap(y, ids)]));
  return x;
}

/** The rows to insert for a copy owned by `userId`, per table in seeding order. Pure. */
export function copyRows(snapshot: AthleteSnapshot, userId: string, email: string): [CopyTable, Row[]][] {
  const ids = new Map<string, string>([[snapshot.user_id, userId]]);
  for (const t of COPY_TABLES) for (const r of snapshot.tables[t] ?? []) if (t !== 'users' && typeof r.id === 'string') ids.set(r.id, crypto.randomUUID());
  return COPY_TABLES.filter((t) => (snapshot.tables[t] ?? []).length > 0).map((t) => {
    const rows = (snapshot.tables[t] ?? []).map((r) => remap(r, ids) as Row);
    // The copy is a test account: never an admin, marked internal, and its email is its own.
    if (t === 'users') for (const r of rows) Object.assign(r, { email, is_admin: false, is_internal: true });
    return [t, rows];
  });
}

/** Seeds a copy for `userId` from `snapshot`. Throws on the first table that will not insert. */
export async function seedCopy(admin: Db, snapshot: AthleteSnapshot, userId: string, email: string): Promise<void> {
  for (const [t, rows] of copyRows(snapshot, userId, email)) {
    const { error } = await admin.from(t).insert(rows);
    if (error) throw new Error(`seeding ${t}: ${error.message}`);
  }
}

const PAGE = 1000;
/** A copy as it stands: every copy table's rows for `userId`, read with the service role. Empty tables are left
 *  out, so a before and an after compare table by table. */
export async function readCopy(admin: Db, userId: string): Promise<AthleteSnapshot> {
  const tables: AthleteSnapshot['tables'] = {};
  for (const t of COPY_TABLES) {
    const rows: Row[] = [];
    for (let from = 0; ; from += PAGE) {
      const { data, error } = await admin.from(t).select('*').eq(ownerColumn(t), userId).order(orderColumn(t)).range(from, from + PAGE - 1);
      if (error) throw new Error(`reading ${t}: ${error.message}`);
      rows.push(...((data ?? []) as Row[]));
      if ((data ?? []).length < PAGE) break;
    }
    if (rows.length) tables[t] = rows;
  }
  return { user_id: userId, tables };
}

/** Removes a copy's rows, children first, then its users row. The auth user goes separately (it cascades the
 *  call logs, conversations and wallet). Throws on the first table that will not delete. */
export async function removeCopyRows(admin: Db, userId: string): Promise<void> {
  for (const t of [...COPY_TABLES].reverse()) {
    const { error } = await admin.from(t).delete().eq(ownerColumn(t), userId);
    if (error) throw new Error(`removing ${t}: ${error.message}`);
  }
}
