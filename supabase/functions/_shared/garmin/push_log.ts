/**
 * Per-record failure log for garmin-push.
 *
 * Finding 18-012 (testing-wave): a fan-out push logged "epochs processed 0,
 * errors 45" and nothing else, because the epoch and stress loops counted a
 * missing user mapping and an upsert error without writing a line. Every
 * failed record now goes through `logGarminRecordFailure`, one short line
 * each: the record kind, the Garmin user id (the mapping key, not a person),
 * the summary id, the reason, and the error's kind (Postgres/PostgREST code
 * or the Error class). Never the access token, never the record payload.
 */

/** Which failure branch a record died in. */
export type GarminRecordFailureReason =
  | "no_user_mapping"
  | "mapping_read_failed"
  | "upsert_failed"
  | "processing_threw"
  | "matcher_error"
  | "missing_summary_id"
  | "activity_not_found";

export interface GarminRecordFailure {
  /** Push array the record came from: "epochs", "stressDetails", ... */
  kind: string;
  garminUserId: string | null | undefined;
  summaryId?: string | number | null;
  reason: GarminRecordFailureReason;
  /** The caught error or the PostgREST `error` object, when there is one. */
  error?: unknown;
}

export interface GarminErrorDescription {
  /** Postgres/PostgREST code, Error class name, or "unknown". */
  kind: string;
  message: string;
}

const MESSAGE_CAP = 200;

/**
 * Names an error by the most specific handle it carries. A PostgREST error
 * is a plain object with `code`; a thrown Error has a class name.
 */
export function describeGarminError(err: unknown): GarminErrorDescription {
  if (err == null) return { kind: "unknown", message: "" };
  if (typeof err === "string") return { kind: "unknown", message: cap(err) };
  if (typeof err === "object") {
    const o = err as Record<string, unknown>;
    const code = typeof o.code === "string" && o.code.length > 0
      ? o.code
      : null;
    // A bare object with no message (e.g. a matcher outcome) has nothing
    // readable to print; "[object Object]" would only add noise.
    const message = typeof o.message === "string" ? o.message : "";
    if (code) return { kind: code, message: cap(message) };
    if (err instanceof Error) {
      return { kind: err.name || "Error", message: cap(message) };
    }
    return { kind: "unknown", message: cap(message) };
  }
  return { kind: "unknown", message: cap(String(err)) };
}

/** One `console.error` line per failed record. */
export function logGarminRecordFailure(failure: GarminRecordFailure): void {
  const described = failure.error === undefined
    ? { kind: "none", message: "" }
    : describeGarminError(failure.error);
  const parts = [
    `[garmin-push] record failed kind=${failure.kind}`,
    `garminUserId=${failure.garminUserId ?? "none"}`,
    `summaryId=${failure.summaryId ?? "none"}`,
    `reason=${failure.reason}`,
    `errorKind=${described.kind}`,
  ];
  if (described.message) {
    parts.push(`message=${JSON.stringify(described.message)}`);
  }
  console.error(parts.join(" "));
}

/** PostgREST's code for `.single()` finding no row. */
const NOT_FOUND = "PGRST116";

/**
 * A `garmin_user_mappings` lookup came back empty. PGRST116 (or no error at
 * all) means the Garmin user is simply not mapped on this project; any other
 * code means the read itself failed, which is a different fault.
 */
export function logGarminMappingMiss(
  kind: string,
  garminUserId: string | null | undefined,
  summaryId: string | number | null | undefined,
  mappingError: unknown,
): void {
  const code = mappingError && typeof mappingError === "object"
    ? (mappingError as { code?: unknown }).code
    : undefined;
  const readFailed = mappingError != null && code !== NOT_FOUND;
  logGarminRecordFailure({
    kind,
    garminUserId,
    summaryId,
    reason: readFailed ? "mapping_read_failed" : "no_user_mapping",
    error: readFailed ? mappingError : undefined,
  });
}

/** The counters every push loop keeps; `skipped` is added on first use. */
export interface GarminLoopStats {
  errors: number;
  skipped?: number;
}

/**
 * Per-request tally of `garmin_user_mappings` misses.
 *
 * `tally` classifies the miss like [logGarminMappingMiss]: a failed read
 * (any code but PGRST116) is logged as an error and counted in
 * `stats.errors`; an unmapped Garmin user is counted in `stats.skipped` and
 * logged ONCE per Garmin user id for the whole request, however many
 * records the fan-out carries for them.
 */
export class GarminMappingMisses {
  private readonly loggedUnmapped = new Set<string>();

  tally(
    kind: string,
    garminUserId: string | null | undefined,
    summaryId: string | number | null | undefined,
    mappingError: unknown,
    stats: GarminLoopStats,
  ): "skipped" | "error" {
    const code = mappingError && typeof mappingError === "object"
      ? (mappingError as { code?: unknown }).code
      : undefined;
    const readFailed = mappingError != null && code !== NOT_FOUND;
    if (readFailed) {
      logGarminRecordFailure({
        kind,
        garminUserId,
        summaryId,
        reason: "mapping_read_failed",
        error: mappingError,
      });
      stats.errors++;
      return "error";
    }

    stats.skipped = (stats.skipped ?? 0) + 1;
    const key = garminUserId ?? "none";
    if (!this.loggedUnmapped.has(key)) {
      this.loggedUnmapped.add(key);
      console.log(
        `[garmin-push] record skipped kind=${kind} garminUserId=${key} ` +
          `summaryId=${summaryId ?? "none"} reason=no_user_mapping ` +
          `(further records for this Garmin user in this request are skipped silently)`,
      );
    }
    return "skipped";
  }
}

function cap(s: string): string {
  return s.length > MESSAGE_CAP ? `${s.slice(0, MESSAGE_CAP)}…` : s;
}

/**
 * Persist an inbound Garmin payload verbatim, BEFORE any gate can drop it.
 *
 * Why this exists (2026-08-24): an athlete's pool swim was recorded natively by
 * a Forerunner 955, reached Final Surge and Bevel Health through Garmin's API,
 * and never appeared in our `activities` table. Every drop point in this
 * function was audited and cleared — sport mapping normalizes case, no
 * tombstone existed, the planned matcher would have matched, the insert
 * fallback admits swimming — so the payload either never arrived or was
 * discarded somewhere unlogged. We could not tell which, because inbound
 * ACTIVITY payloads were never persisted (`garmin_health_data` held only
 * daily/epoch/sleep/stress/body-composition) and the Supabase log tables
 * return nothing through the Management API. That question must be a lookup,
 * not archaeology.
 * See ops/data/bug-reports/2026-08-24-final-surge-completed-workouts-import-as-planned.md
 *
 * Storage note: reuses `garmin_health_data`'s generic (data_type, data jsonb)
 * shape rather than adding a table — deliberately, so this ships as a function
 * deploy with no migration. Every existing reader of that table filters on
 * data_type (app: body_composition; engine: daily / body_composition), so a new
 * type is invisible to all of them. `summary_id` carries a GLOBAL unique, hence
 * the `act:` / `actdet:` prefix and the conflict-ignore.
 *
 * MUST NOT THROW. This diagnoses a path that already loses activities silently;
 * a logging failure that aborted the enclosing try would make the very bug it
 * exists to catch worse.
 *
 * Unmapped Garmin user (ticket 61, Finding 49-011): `user_id` is NOT NULL
 * with a foreign key to `users`, so a write with no mapped user 23502s. The
 * payload belongs to nobody on this project, so it is not kept: one
 * `console.warn` line names the key and the Garmin user id (never the
 * payload) and the function returns. That line is the D9 record.
 *
 * Lives in `_shared/garmin/push_log.ts` rather than garmin-push/index.ts so a
 * test can import it (index.ts calls serve() at module load).
 */
export async function logInboundGarminPayload(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  kind: "activity" | "activity_detail" | "activity_detail_full",
  garminUserId: string | null | undefined,
  userId: string | null,
  summaryId: string | null | undefined,
  payload: unknown,
): Promise<void> {
  try {
    const prefix = kind === "activity"
      ? "act"
      : kind === "activity_detail"
      ? "actdet"
      : "actdetfull";
    // The `nosummary` fallback reads startTimeInSeconds off the PAYLOAD, so it
    // only ever produced a unique key when the payload was itself a summary.
    // For `activity_detail_full` the payload is the whole detail object, whose
    // startTimeInSeconds lives under `.summary` — so every full capture for an
    // athlete keyed to `...:0` and `ignoreDuplicates` silently discarded all
    // but the first (found 2026-09-22: three rows existed table-wide, one per
    // athlete, all from the hours after deploy). Callers now pass an id derived
    // from the activity itself; the fallback stays as a last resort only.
    const key = summaryId
      ? `${prefix}:${summaryId}`
      : `${prefix}:nosummary:${garminUserId ?? "unknown"}:${
        // deno-lint-ignore no-explicit-any
        (payload as any)?.startTimeInSeconds ??
          // deno-lint-ignore no-explicit-any
          (payload as any)?.summary?.startTimeInSeconds ?? "0"
      }`;
    if (userId == null) {
      console.warn(
        `[garmin-push] inbound payload log skipped key=${key} ` +
          `garminUserId=${garminUserId ?? "none"} reason=no_user_mapping`,
      );
      return;
    }
    const { data: inserted, error } = await supabase
      .from("garmin_health_data")
      .upsert({
        user_id: userId,
        garmin_user_id: garminUserId ?? null,
        summary_id: key,
        data_type: kind === "activity"
          ? "activity_raw"
          : kind === "activity_detail"
          ? "activity_detail_raw"
          : "activity_detail_full",
        calendar_date: new Date().toISOString().slice(0, 10),
        data: payload,
      }, { onConflict: "summary_id", ignoreDuplicates: true })
      .select("summary_id");

    // A conflict-ignore that writes nothing is indistinguishable from a
    // successful write unless we look. That indistinguishability is exactly
    // what hid the collision above for a day, so say so out loud.
    if (error) {
      console.warn(`[garmin-push] inbound payload log error for ${key}:`, error);
    } else if (Array.isArray(inserted) && inserted.length === 0) {
      console.warn(
        `[garmin-push] inbound payload log wrote NOTHING for ${key} ` +
          `(duplicate summary_id) — payload not retained`,
      );
    }
  } catch (err) {
    // Swallow deliberately — see the contract above.
    console.warn("[garmin-push] inbound payload log failed (non-fatal):", err);
  }
}
