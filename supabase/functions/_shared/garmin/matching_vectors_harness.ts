/**
 * Matcher-tier conformance harness — data-integrations@v1 Stage B.
 *
 * Loads the ratified matching vectors
 * (docs/ssot/vectors/integrations/matching.json, tag data-integrations@v1)
 * and provides the shared plumbing every matcher-tier runner uses:
 *   - vector types (incoming signal / candidate rows / expected decision)
 *   - a fake PostgREST-style client over an in-memory `activities` table so
 *     the REAL matcher code runs unmodified against vector-defined state
 *   - decision comparison that asserts gate identity AND action (the
 *     vectors' own note: "verdict alone is insufficient")
 *
 * Two runners consume this:
 *   1. matching_vectors_red_run.ts — the MANDATORY red-first run: drives
 *      today's earliest-first pipeline exactly as garmin-push orchestrates
 *      it, proving the harness sees current behavior before any rewrite.
 *   2. matcher.test.ts — the permanent conformance suite over the
 *      rewritten matcher tier (Stage B deliverable).
 */

// ---------------------------------------------------------------------------
// Vector types (shape pinned by the vectors file; see its `note` field)
// ---------------------------------------------------------------------------

export interface VectorIncomingActivity {
  summaryId?: string;
  sport?: string;
  activityType?: string;
  parentSummaryId?: string;
  isParent?: boolean;
  startLocal: string; // naive local, YYYY-MM-DDTHH:MM
  durationMin: number; // may be fractional (0.15 = 9 s)
}

export interface VectorIncoming extends VectorIncomingActivity {
  source: "garmin" | "platform";
  provider?: string;
  planId?: string;
  signalKind?: "completion" | "planned-import";
  sequence?: VectorIncomingActivity[];
  parentMatchedRowId?: string;
  context?: string;
  tzNote?: string;
}

export interface VectorSegment {
  order: number;
  sport: string;
  durationMin: number;
}

export interface VectorCandidate {
  rowId: string;
  status: string;
  sport: string;
  slotLocal?: string;
  matchedStartLocal?: string;
  garminSummaryId?: string | null;
  providerWorkoutId?: string;
  plannedDurationMin?: number;
  recordedDurationMin?: number;
  matchedDurationMin?: number;
  totalDurationMin?: number;
  segments?: VectorSegment[];
  createdOrder?: number;
}

export interface VectorExpected {
  gate: string;
  action: string;
  matchedRowId?: string;
  insertedSport?: string;
  parentVerified?: boolean;
  legStamps?: Record<string, string>;
  reboundPlanId?: string;
  displacedRescoredTo?: string;
  standaloneRow?: boolean;
}

export interface MatchingVector {
  id: string;
  status: string;
  inputs: { incoming: VectorIncoming; candidates: VectorCandidate[] };
  expected: VectorExpected;
  why: string;
}

/** Observed decision — same vocabulary as VectorExpected. */
export type ObservedDecision = VectorExpected & { notes?: string[] };

export function loadMatchingVectors(path: string): MatchingVector[] {
  const raw = JSON.parse(Deno.readTextFileSync(path));
  return raw.vectors as MatchingVector[];
}

/** Default vectors path relative to the repo root. */
export const MATCHING_VECTORS_RELATIVE_PATH =
  "docs/ssot/vectors/integrations/matching.json";

/**
 * Resolve the vectors file from this module's location so the runner works
 * from any cwd (deno test runs from wherever the invoker sat).
 */
export function defaultVectorsPath(): string {
  const here = new URL(".", import.meta.url).pathname;
  // .../supabase/functions/_shared/garmin/ -> repo root is 4 levels up
  return `${here}../../../../${MATCHING_VECTORS_RELATIVE_PATH}`;
}

// ---------------------------------------------------------------------------
// Time helpers (vector-naive-local <-> forms the matcher code uses)
// ---------------------------------------------------------------------------

/** 'YYYY-MM-DDTHH:MM[:SS]' -> epoch seconds, treating the naive local time
 * as UTC (offset 0), which round-trips exactly through
 * garminTimestampToLocalNaiveISO. */
export function naiveLocalToEpochSeconds(naive: string): number {
  const withSeconds = naive.length === 16 ? `${naive}:00` : naive;
  return Date.parse(`${withSeconds}Z`) / 1000;
}

/** Normalize either 'T' or space separated naive timestamps for string
 * comparison, padding seconds. */
export function normalizeNaive(ts: string): string {
  let s = ts.replace(" ", "T");
  if (s.length === 16) s = `${s}:00`;
  return s;
}

// ---------------------------------------------------------------------------
// In-memory activities table + fake PostgREST client
// ---------------------------------------------------------------------------

export interface FakeRow {
  [key: string]: unknown;
  id: string;
  user_id: string;
  status: string;
  activity_type: string;
  scheduled_date_time: string | null;
  garmin_summary_id: string | null;
  provider_workout_id: string | null;
  deleted_at: string | null;
  duration_minutes: number | null;
}

export const FAKE_USER_ID = "vector-user-1";

/** Build the in-memory table from a vector's candidates, preserving the
 * candidate list order (PostgREST returns unspecified order without an
 * explicit ORDER BY; insertion order is the faithful emulation). */
export function rowsFromCandidates(candidates: VectorCandidate[]): FakeRow[] {
  return candidates.map((c) => ({
    id: c.rowId,
    user_id: FAKE_USER_ID,
    status: c.status,
    activity_type: c.sport,
    scheduled_date_time: normalizeNaive(
      c.slotLocal ?? c.matchedStartLocal ?? "2026-09-10T07:00",
    ),
    garmin_summary_id: c.garminSummaryId ?? null,
    provider_workout_id: c.providerWorkoutId ?? null,
    deleted_at: c.status === "deleted" ? "2026-09-09T00:00:00" : null,
    duration_minutes: c.plannedDurationMin ??
      c.recordedDurationMin ??
      c.matchedDurationMin ??
      c.totalDurationMin ??
      null,
    title: c.rowId,
    brick_metadata: c.segments
      ? {
        total_duration_minutes: c.totalDurationMin ?? null,
        segment_order: c.segments.map((s) => s.order),
        segments: c.segments.map((s) => ({
          order: s.order,
          sport: s.sport,
          duration_minutes: s.durationMin,
        })),
      }
      : null,
    created_order: c.createdOrder ?? 0,
  }));
}

type Filter = (row: FakeRow) => boolean;

class FakeQuery {
  #db: FakeDb;
  #filters: Filter[] = [];
  #order: { column: string; ascending: boolean } | null = null;
  #limit: number | null = null;
  #select: string | null = null;
  #mode: "select" | "update" | "insert" = "select";
  #updateFields: Record<string, unknown> | null = null;
  #insertRow: Record<string, unknown> | null = null;
  #single = false;

  constructor(db: FakeDb) {
    this.#db = db;
  }

  select(sel?: string) {
    if (this.#mode === "select") this.#select = sel ?? "*";
    else this.#select = sel ?? "id"; // .update(...).select('id') / insert
    return this;
  }
  update(fields: Record<string, unknown>) {
    this.#mode = "update";
    this.#updateFields = fields;
    return this;
  }
  insert(row: Record<string, unknown>) {
    this.#mode = "insert";
    this.#insertRow = row;
    return this;
  }
  single() {
    this.#single = true;
    return this;
  }
  eq(column: string, value: unknown) {
    this.#filters.push((r) => this.#norm(column, r[column]) === this.#norm(column, value));
    return this;
  }
  is(column: string, value: unknown) {
    this.#filters.push((r) => r[column] === value);
    return this;
  }
  in(column: string, values: unknown[]) {
    this.#filters.push((r) => values.includes(r[column]));
    return this;
  }
  gte(column: string, value: unknown) {
    this.#filters.push((r) =>
      String(this.#norm(column, r[column])) >= String(this.#norm(column, value))
    );
    return this;
  }
  lte(column: string, value: unknown) {
    this.#filters.push((r) =>
      String(this.#norm(column, r[column])) <= String(this.#norm(column, value))
    );
    return this;
  }
  lt(column: string, value: unknown) {
    this.#filters.push((r) =>
      String(this.#norm(column, r[column])) < String(this.#norm(column, value))
    );
    return this;
  }
  order(column: string, opts?: { ascending?: boolean }) {
    this.#order = { column, ascending: opts?.ascending ?? true };
    return this;
  }
  limit(n: number) {
    this.#limit = n;
    return this;
  }

  #norm(column: string, v: unknown): unknown {
    if (column === "scheduled_date_time" && typeof v === "string") {
      return normalizeNaive(v);
    }
    return v;
  }

  #matching(): FakeRow[] {
    let rows = this.#db.rows.filter((r) => this.#filters.every((f) => f(r)));
    if (this.#order) {
      const { column, ascending } = this.#order;
      rows = [...rows].sort((a, b) => {
        const av = String(a[column] ?? "");
        const bv = String(b[column] ?? "");
        return ascending ? av.localeCompare(bv) : bv.localeCompare(av);
      });
    }
    if (this.#limit !== null) rows = rows.slice(0, this.#limit);
    return rows;
  }

  // Thenable so `await query` resolves like the real client.
  // deno-lint-ignore no-explicit-any
  then(resolve: (v: { data: any; error: any }) => void) {
    resolve(this.#execute());
  }

  // deno-lint-ignore no-explicit-any
  #execute(): { data: any; error: any } {
    if (this.#mode === "select") {
      const rows = this.#matching();
      const data = this.#single ? rows[0] ?? null : rows;
      if (this.#single && rows.length === 0) {
        return { data: null, error: { code: "PGRST116" } };
      }
      return { data, error: null };
    }
    if (this.#mode === "update") {
      const rows = this.#matching();
      for (const row of rows) Object.assign(row, this.#updateFields);
      this.#db.updates.push({
        fields: { ...this.#updateFields },
        rowIds: rows.map((r) => r.id),
      });
      return {
        data: this.#select ? rows.map((r) => ({ id: r.id })) : null,
        error: null,
      };
    }
    // insert
    const row = this.#insertRow as FakeRow;
    const summary = row.garmin_summary_id;
    if (
      summary != null &&
      this.#db.rows.some(
        (r) => r.user_id === row.user_id && r.garmin_summary_id === summary,
      )
    ) {
      return { data: null, error: { code: "23505" } };
    }
    this.#db.rows.push(row);
    this.#db.inserts.push(row);
    const data = this.#single ? { id: row.id } : [{ id: row.id }];
    return { data, error: null };
  }
}

export class FakeDb {
  rows: FakeRow[];
  inserts: FakeRow[] = [];
  updates: Array<{ fields: Record<string, unknown>; rowIds: string[] }> = [];

  constructor(rows: FakeRow[]) {
    this.rows = rows;
  }

  from(table: string) {
    if (table !== "activities") {
      throw new Error(`FakeDb only models activities (got ${table})`);
    }
    return new FakeQuery(this);
  }

  get(id: string): FakeRow | undefined {
    return this.rows.find((r) => r.id === id);
  }
}

// ---------------------------------------------------------------------------
// Decision comparison — gate identity AND action, plus every optional field
// the vector pins.
// ---------------------------------------------------------------------------

export function compareDecision(
  expected: VectorExpected,
  observed: ObservedDecision,
): string[] {
  const mismatches: string[] = [];
  const check = (field: keyof VectorExpected) => {
    const want = expected[field];
    if (want === undefined) return;
    const got = observed[field];
    if (JSON.stringify(got) !== JSON.stringify(want)) {
      mismatches.push(
        `${field}: expected ${JSON.stringify(want)}, got ${
          JSON.stringify(got ?? null)
        }`,
      );
    }
  };
  check("gate");
  check("action");
  check("matchedRowId");
  check("insertedSport");
  check("parentVerified");
  check("legStamps");
  check("reboundPlanId");
  check("displacedRescoredTo");
  check("standaloneRow");
  return mismatches;
}

/** Render a per-vector result line for run reports. */
export function formatResult(
  id: string,
  mismatches: string[],
  notes?: string[],
): string {
  const status = mismatches.length === 0 ? "GREEN" : "RED  ";
  const detail = mismatches.length === 0 ? "" : ` — ${mismatches.join("; ")}`;
  const noteStr = notes && notes.length > 0 ? ` [${notes.join(" | ")}]` : "";
  return `${status} ${id}${detail}${noteStr}`;
}
