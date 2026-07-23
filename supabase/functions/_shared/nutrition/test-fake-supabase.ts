/**
 * Test-only fake Supabase client for solver/cascade tests.
 *
 * Implements the small set of PostgREST operators the nutrition queries
 * actually use — `eq`, `filter(col,'ov','{a,b}')`, `or("col.is.null,col.ov.{x}")`,
 * `in` — so fixture pools are scoped exactly like production pools (category
 * and activity_type filtering included). Order/limit/select are no-ops.
 * Awaitable at any point in the chain, matching supabase-js thenable behavior.
 * `insert` records rows into `inserted[table]` so tests can assert writes.
 */

function parseBraceList(v: string): string[] {
  const inner = v.replace(/^\{/, "").replace(/\}$/, "");
  return inner.length === 0 ? [] : inner.split(",").map((s) => s.trim());
}

function overlaps(rowVal: unknown, values: string[]): boolean {
  if (!Array.isArray(rowVal)) return false;
  return rowVal.some((x) => values.includes(String(x)));
}

type Predicate = (row: Record<string, unknown>) => boolean;

function orClausePredicate(clause: string): Predicate {
  // Forms used in this codebase: `col.is.null`, `col.ov.{a,b}`, `col.cs.{a}`
  const isNull = clause.match(/^([\w]+)\.is\.null$/);
  if (isNull) return (row) => row[isNull[1]] == null;
  const ov = clause.match(/^([\w]+)\.ov\.(\{.*\})$/);
  if (ov) return (row) => overlaps(row[ov[1]], parseBraceList(ov[2]));
  const cs = clause.match(/^([\w]+)\.cs\.(\{.*\})$/);
  if (cs) return (row) => overlaps(row[cs[1]], parseBraceList(cs[2]));
  // Unknown clause: match nothing so tests fail loudly rather than silently.
  return () => false;
}

export function fakeSupabase(
  tables: Record<string, Record<string, unknown>[]>,
  // Returned as `any` so it can stand in for `SupabaseClient` at call sites;
  // the `inserted` record is still available for assertions.
  // deno-lint-ignore no-explicit-any
): any {
  const inserted: Record<string, Record<string, unknown>[]> = {};
  const from = (table: string) => {
    const predicates: Predicate[] = [];
    const resolve = () =>
      (tables[table] ?? []).filter((row) => predicates.every((p) => p(row)));
    // deno-lint-ignore no-explicit-any
    const b: any = {};
    const chain = () => b;
    b.select = chain;
    b.order = chain;
    b.limit = chain;
    b.eq = (col: string, val: unknown) => {
      predicates.push((row) => row[col] === val);
      return b;
    };
    b.filter = (col: string, op: string, val: string) => {
      if (op === "ov") {
        const values = parseBraceList(val);
        predicates.push((row) => overlaps(row[col], values));
      }
      return b;
    };
    b.or = (clauses: string) => {
      const preds = clauses.split(",").map((c) => orClausePredicate(c.trim()));
      predicates.push((row) => preds.some((p) => p(row)));
      return b;
    };
    b.in = (col: string, values: unknown[]) => {
      predicates.push((row) => values.includes(row[col]));
      return b;
    };
    b.single = () => {
      const rows = resolve();
      return Promise.resolve({ data: rows[0] ?? null, error: null });
    };
    b.insert = (row: Record<string, unknown>) => {
      (inserted[table] ??= []).push(row);
      return Promise.resolve({ data: null, error: null });
    };
    b.then = (
      // deno-lint-ignore no-explicit-any
      resolveFn: (v: any) => unknown,
      // deno-lint-ignore no-explicit-any
      rejectFn: (e: any) => unknown,
    ) =>
      Promise.resolve({ data: resolve(), error: null }).then(
        resolveFn,
        rejectFn,
      );
    return b;
  };
  return { from, inserted };
}
