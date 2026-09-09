/**
 * A fake PostgREST client for the shared Vana modules.
 *
 * The Vana modules take a `VanaCtx` whose `db` / `admin` are supabase-js clients, so a test can
 * drive them with no database and no network by handing them one of these. It is deliberately
 * dumb: rows in, filters applied in memory, rows out. Fixture rows are producer-shaped — exactly
 * what the tables return, snake_case and all — so a test never feeds a module its own output.
 *
 * Supported chain: select / insert / update / upsert / delete, eq / neq / gt / gte / lt / lte /
 * is / in / like / ilike, order (multi-key, in call order), limit / range, single / maybeSingle,
 * and awaiting the builder directly. `rpc()` dispatches to handlers the test supplies.
 *
 * Every write is recorded on `writes` so a test can assert what reached the database without
 * reading it back through the same fake.
 */

// deno-lint-ignore no-explicit-any
export type Row = Record<string, any>;
export type Tables = Record<string, Row[]>;

export interface Write {
  op: 'insert' | 'update' | 'upsert' | 'delete';
  table: string;
  /** The payload as the caller passed it (array for multi-row insert/upsert). */
  // deno-lint-ignore no-explicit-any
  values?: any;
  /** The rows the write matched / produced. */
  rows: Row[];
}

export interface FakeDbOptions {
  /** `rpc(name, args)` handlers. An unhandled name resolves to `{ data: null, error: … }`. */
  // deno-lint-ignore no-explicit-any
  rpc?: Record<string, (args: any) => unknown>;
  /** Force an error from one table, to exercise a module's failure path. */
  errors?: Record<string, string>;
  /** Column defaults per table, applied to inserted rows the way Postgres would. Without these a
   *  freshly inserted row is missing `is_deleted`, and the next `eq('is_deleted', false)` misses it. */
  defaults?: Record<string, Row>;
}

type Filter = (r: Row) => boolean;
type Sort = { column: string; ascending: boolean };

const val = (r: Row, col: string) => r[col];
const cmp = (a: unknown, b: unknown): number => {
  if (a == null && b == null) return 0;
  if (a == null) return 1; // nulls last, like PostgREST's default
  if (b == null) return -1;
  if (typeof a === 'number' && typeof b === 'number') return a - b;
  return String(a) < String(b) ? -1 : String(a) > String(b) ? 1 : 0;
};

/** Deep-ish clone so a caller mutating a returned row cannot corrupt the fixture. */
const clone = <T>(x: T): T => (x == null ? x : JSON.parse(JSON.stringify(x)));

export class FakeDb {
  readonly tables: Tables;
  readonly writes: Write[] = [];
  /** Every `from(table)` the modules touched, in order — a cheap check that a query even ran. */
  readonly reads: string[] = [];
  private readonly opts: FakeDbOptions;

  constructor(tables: Tables = {}, opts: FakeDbOptions = {}) {
    this.tables = clone(tables);
    this.opts = opts;
  }

  defaultsFor(table: string): Row {
    return this.opts.defaults?.[table] ?? {};
  }

  rows(table: string): Row[] {
    return (this.tables[table] ??= []);
  }

  from(table: string): QueryBuilder {
    this.reads.push(table);
    return new QueryBuilder(this, table, this.opts.errors?.[table] ?? null);
  }

  // deno-lint-ignore no-explicit-any
  rpc(name: string, args?: any): Promise<{ data: unknown; error: { message: string } | null }> {
    const h = this.opts.rpc?.[name];
    if (!h) return Promise.resolve({ data: null, error: { message: `fake db: no rpc handler for ${name}` } });
    try {
      return Promise.resolve({ data: clone(h(args)), error: null });
    } catch (e) {
      return Promise.resolve({ data: null, error: { message: (e as Error).message } });
    }
  }

  /** Writes recorded against one table, newest last. */
  writesTo(table: string, op?: Write['op']): Write[] {
    return this.writes.filter((w) => w.table === table && (!op || w.op === op));
  }
}

type Mode = 'select' | 'insert' | 'update' | 'upsert' | 'delete';

export class QueryBuilder implements PromiseLike<{ data: unknown; error: { message: string } | null }> {
  private filters: Filter[] = [];
  private sorts: Sort[] = [];
  private limitN: number | null = null;
  private mode: Mode = 'select';
  // deno-lint-ignore no-explicit-any
  private payload: any = null;
  private returning = false;
  private onConflict: string | null = null;

  constructor(private readonly db: FakeDb, private readonly table: string, private readonly forcedError: string | null) {}

  // ---- verbs
  select(_cols?: string) {
    if (this.mode === 'select') this.mode = 'select';
    else this.returning = true;
    return this;
  }
  // deno-lint-ignore no-explicit-any
  insert(values: any) { this.mode = 'insert'; this.payload = values; return this; }
  // deno-lint-ignore no-explicit-any
  update(values: any) { this.mode = 'update'; this.payload = values; return this; }
  // deno-lint-ignore no-explicit-any
  upsert(values: any, opts?: { onConflict?: string }) { this.mode = 'upsert'; this.payload = values; this.onConflict = opts?.onConflict ?? null; return this; }
  delete() { this.mode = 'delete'; return this; }

  // ---- filters
  eq(col: string, v: unknown) { this.filters.push((r) => String(val(r, col)) === String(v)); return this; }
  neq(col: string, v: unknown) { this.filters.push((r) => String(val(r, col)) !== String(v)); return this; }
  gt(col: string, v: unknown) { this.filters.push((r) => cmp(val(r, col), v) > 0); return this; }
  gte(col: string, v: unknown) { this.filters.push((r) => cmp(val(r, col), v) >= 0); return this; }
  lt(col: string, v: unknown) { this.filters.push((r) => cmp(val(r, col), v) < 0); return this; }
  lte(col: string, v: unknown) { this.filters.push((r) => cmp(val(r, col), v) <= 0); return this; }
  is(col: string, v: unknown) { this.filters.push((r) => (v === null ? val(r, col) == null : val(r, col) === v)); return this; }
  in(col: string, vs: unknown[]) { this.filters.push((r) => vs.map(String).includes(String(val(r, col)))); return this; }
  like(col: string, pat: string) { const re = new RegExp('^' + pat.replace(/%/g, '.*') + '$'); this.filters.push((r) => re.test(String(val(r, col) ?? ''))); return this; }
  ilike(col: string, pat: string) { const re = new RegExp('^' + pat.replace(/%/g, '.*') + '$', 'i'); this.filters.push((r) => re.test(String(val(r, col) ?? ''))); return this; }
  not(col: string, op: string, v: unknown) {
    if (op === 'is') this.filters.push((r) => (v === null ? val(r, col) != null : val(r, col) !== v));
    else this.filters.push((r) => String(val(r, col)) !== String(v));
    return this;
  }

  // ---- shaping
  order(column: string, opts?: { ascending?: boolean; nullsFirst?: boolean }) { this.sorts.push({ column, ascending: opts?.ascending !== false }); return this; }
  limit(n: number) { this.limitN = n; return this; }
  range(from: number, to: number) { this.limitN = to - from + 1; return this; }

  // ---- terminals
  async single() {
    const { data, error } = await this.run();
    if (error) return { data: null, error };
    const rows = data as Row[];
    if (rows.length !== 1) return { data: null, error: { message: `fake db: expected 1 row from ${this.table}, got ${rows.length}` } };
    return { data: rows[0], error: null };
  }
  async maybeSingle() {
    const { data, error } = await this.run();
    if (error) return { data: null, error };
    const rows = data as Row[];
    return { data: rows.length ? rows[0] : null, error: null };
  }
  // deno-lint-ignore no-explicit-any
  then<T1 = any, T2 = never>(onfulfilled?: ((v: { data: any; error: { message: string } | null }) => T1 | PromiseLike<T1>) | null, onrejected?: ((r: unknown) => T2 | PromiseLike<T2>) | null): PromiseLike<T1 | T2> {
    return this.run().then(onfulfilled, onrejected);
  }

  // ---- execution
  private matching(): Row[] {
    return this.db.rows(this.table).filter((r) => this.filters.every((f) => f(r)));
  }
  private shape(rows: Row[]): Row[] {
    let out = rows.slice();
    for (const s of [...this.sorts].reverse()) {
      out = out.sort((a, b) => (s.ascending ? cmp(val(a, s.column), val(b, s.column)) : -cmp(val(a, s.column), val(b, s.column))));
    }
    if (this.limitN != null) out = out.slice(0, this.limitN);
    return clone(out);
  }

  // deno-lint-ignore no-explicit-any
  private async run(): Promise<{ data: any; error: { message: string } | null }> {
    await Promise.resolve();
    if (this.forcedError) return { data: null, error: { message: this.forcedError } };
    const store = this.db.rows(this.table);
    switch (this.mode) {
      case 'select':
        return { data: this.shape(this.matching()), error: null };
      case 'insert': {
        const vs: Row[] = (Array.isArray(this.payload) ? this.payload : [this.payload]).map((r: Row) => ({ id: crypto.randomUUID(), created_at: new Date().toISOString(), ...this.db.defaultsFor(this.table), ...clone(r) }));
        store.push(...vs);
        this.db.writes.push({ op: 'insert', table: this.table, values: clone(this.payload), rows: clone(vs) });
        return { data: clone(vs), error: null };
      }
      case 'upsert': {
        const keys = (this.onConflict ?? 'id').split(',').map((k) => k.trim());
        const vs: Row[] = (Array.isArray(this.payload) ? this.payload : [this.payload]).map((r: Row) => clone(r));
        const out: Row[] = [];
        for (const v of vs) {
          const i = store.findIndex((r) => keys.every((k) => String(r[k]) === String(v[k])));
          if (i >= 0) { store[i] = { ...store[i], ...v }; out.push(store[i]); }
          else { const row = { id: crypto.randomUUID(), created_at: new Date().toISOString(), ...this.db.defaultsFor(this.table), ...v }; store.push(row); out.push(row); }
        }
        this.db.writes.push({ op: 'upsert', table: this.table, values: clone(this.payload), rows: clone(out) });
        return { data: clone(out), error: null };
      }
      case 'update': {
        const hit = this.matching();
        for (const r of hit) Object.assign(r, clone(this.payload));
        this.db.writes.push({ op: 'update', table: this.table, values: clone(this.payload), rows: clone(hit) });
        return { data: this.shape(hit), error: null };
      }
      case 'delete': {
        const hit = this.matching();
        this.db.tables[this.table] = store.filter((r) => !hit.includes(r));
        this.db.writes.push({ op: 'delete', table: this.table, rows: clone(hit) });
        return { data: clone(hit), error: null };
      }
    }
  }
}

export const fakeDb = (tables: Tables = {}, opts: FakeDbOptions = {}) => new FakeDb(tables, opts);
