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

function cap(s: string): string {
  return s.length > MESSAGE_CAP ? `${s.slice(0, MESSAGE_CAP)}…` : s;
}
