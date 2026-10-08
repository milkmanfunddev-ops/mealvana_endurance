/**
 * Tests for the garmin-push per-record failure log (testing-wave ticket 65,
 * Finding 18-012: "epochs processed 0, errors 45" named no cause).
 *
 * Run with: deno test --allow-env --allow-sys supabase/functions/_shared/garmin/push_log.test.ts
 */

import {
  assertEquals,
  assertMatch,
  assertStringIncludes,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  describeGarminError,
  type GarminLoopStats,
  GarminMappingMisses,
  logGarminMappingMiss,
  logGarminRecordFailure,
  logInboundGarminPayload,
} from "./push_log.ts";

function captureConsoleLog(run: () => void): string[] {
  const lines: string[] = [];
  const original = console.log;
  console.log = (...args: unknown[]) => {
    lines.push(
      args.map((a) => typeof a === "string" ? a : JSON.stringify(a)).join(" "),
    );
  };
  try {
    run();
  } finally {
    console.log = original;
  }
  return lines;
}

function captureConsoleError(run: () => void): string[] {
  const lines: string[] = [];
  const original = console.error;
  console.error = (...args: unknown[]) => {
    lines.push(
      args.map((a) => typeof a === "string" ? a : JSON.stringify(a)).join(" "),
    );
  };
  try {
    run();
  } finally {
    console.error = original;
  }
  return lines;
}

describe("describeGarminError", () => {
  it("names a PostgREST/Postgres error by its code", () => {
    const d = describeGarminError({
      code: "23505",
      message: "duplicate key value violates unique constraint",
      details: "Key (summary_id)=(x123) already exists.",
      hint: null,
    });
    assertEquals(d.kind, "23505");
    assertStringIncludes(d.message, "duplicate key");
  });

  it("names a thrown Error by its class", () => {
    const d = describeGarminError(new TypeError("boom"));
    assertEquals(d.kind, "TypeError");
    assertEquals(d.message, "boom");
  });

  it("names a not-found single() read as PGRST116", () => {
    const d = describeGarminError({
      code: "PGRST116",
      message: "JSON object requested, multiple (or no) rows returned",
    });
    assertEquals(d.kind, "PGRST116");
  });

  it("never throws on a non-error value", () => {
    assertEquals(describeGarminError(undefined).kind, "unknown");
    assertEquals(describeGarminError("just a string").kind, "unknown");
    assertEquals(describeGarminError("just a string").message, "just a string");
  });
});

describe("logGarminRecordFailure", () => {
  it("writes one console.error line carrying the record kind, the Garmin user id and the error kind", () => {
    const lines = captureConsoleError(() =>
      logGarminRecordFailure({
        kind: "epochs",
        garminUserId: "garmin-user-abc",
        summaryId: "x123-epoch",
        reason: "upsert_failed",
        error: { code: "23502", message: "null value in column" },
      })
    );
    assertEquals(lines.length, 1);
    const line = lines[0];
    assertStringIncludes(line, "[garmin-push]");
    assertStringIncludes(line, "kind=epochs");
    assertStringIncludes(line, "garminUserId=garmin-user-abc");
    assertStringIncludes(line, "summaryId=x123-epoch");
    assertStringIncludes(line, "reason=upsert_failed");
    assertStringIncludes(line, "errorKind=23502");
    assertStringIncludes(line, "null value in column");
  });

  it("logs a missing user mapping without an error object", () => {
    const lines = captureConsoleError(() =>
      logGarminRecordFailure({
        kind: "stressDetails",
        garminUserId: "garmin-user-zzz",
        reason: "no_user_mapping",
      })
    );
    assertEquals(lines.length, 1);
    assertStringIncludes(lines[0], "kind=stressDetails");
    assertStringIncludes(lines[0], "reason=no_user_mapping");
    assertMatch(lines[0], /errorKind=none/);
  });

  it("tells an unmapped Garmin user (PGRST116 or no error) apart from a failed mapping read", () => {
    const notFound = captureConsoleError(() =>
      logGarminMappingMiss("epochs", "garmin-user-abc", "e1", {
        code: "PGRST116",
        message: "no rows",
      })
    );
    assertStringIncludes(notFound[0], "reason=no_user_mapping");
    assertStringIncludes(notFound[0], "errorKind=none");

    const noError = captureConsoleError(() =>
      logGarminMappingMiss("epochs", "garmin-user-abc", "e1", null)
    );
    assertStringIncludes(noError[0], "reason=no_user_mapping");

    const readFailed = captureConsoleError(() =>
      logGarminMappingMiss("epochs", "garmin-user-abc", "e1", {
        code: "57014",
        message: "canceling statement due to statement timeout",
      })
    );
    assertStringIncludes(readFailed[0], "reason=mapping_read_failed");
    assertStringIncludes(readFailed[0], "errorKind=57014");
  });

  it("caps the error message so a 45-record fan-out stays one short line each", () => {
    const lines = captureConsoleError(() =>
      logGarminRecordFailure({
        kind: "epochs",
        garminUserId: "garmin-user-abc",
        reason: "upsert_failed",
        error: new Error("x".repeat(2000)),
      })
    );
    assertEquals(lines[0].length < 500, true);
  });
});

// Ticket 138 (112-010 / 121-010): leftover pushes are skipped, not errors.
describe("GarminMappingMisses", () => {
  it("counts an unmapped Garmin user as skipped and logs it once per request", () => {
    const misses = new GarminMappingMisses();
    const stats: GarminLoopStats & { processed: number } = { processed: 0, errors: 0 };
    const errors: string[] = [];
    const logs = captureConsoleLog(() => {
      errors.push(...captureConsoleError(() => {
        for (let i = 0; i < 5; i++) {
          misses.tally("epochs", "garmin-user-gone", `e${i}`, { code: "PGRST116", message: "no rows" }, stats);
        }
        misses.tally("stressDetails", "garmin-user-gone", "s1", null, stats);
      }));
    });
    assertEquals(stats.errors, 0);
    assertEquals(stats.skipped, 6);
    assertEquals(errors, []);
    assertEquals(logs.length, 1);
    assertStringIncludes(logs[0], "record skipped");
    assertStringIncludes(logs[0], "garminUserId=garmin-user-gone");
    assertStringIncludes(logs[0], "reason=no_user_mapping");
  });

  it("logs each distinct unmapped Garmin user once", () => {
    const misses = new GarminMappingMisses();
    const stats: GarminLoopStats & { processed: number } = { processed: 0, errors: 0 };
    const logs = captureConsoleLog(() => {
      misses.tally("epochs", "garmin-a", "e1", null, stats);
      misses.tally("epochs", "garmin-b", "e2", null, stats);
      misses.tally("epochs", "garmin-a", "e3", null, stats);
    });
    assertEquals(logs.length, 2);
    assertEquals(stats.skipped, 3);
  });

  it("keeps a failed mapping read as an error, every time", () => {
    const misses = new GarminMappingMisses();
    const stats: GarminLoopStats & { processed: number } = { processed: 0, errors: 0 };
    const lines = captureConsoleError(() => {
      const first = misses.tally("epochs", "garmin-a", "e1", { code: "57014", message: "timeout" }, stats);
      const second = misses.tally("epochs", "garmin-a", "e2", { code: "57014", message: "timeout" }, stats);
      assertEquals(first, "error");
      assertEquals(second, "error");
    });
    assertEquals(stats.errors, 2);
    assertEquals(stats.skipped, undefined);
    assertEquals(lines.length, 2);
    assertStringIncludes(lines[0], "reason=mapping_read_failed");
    assertStringIncludes(lines[0], "errorKind=57014");
  });
});

// ============================================================================
// logInboundGarminPayload (testing-wave ticket 61, Finding 49-011)
// ============================================================================

async function captureConsoleWarn(run: () => Promise<void>): Promise<string[]> {
  const lines: string[] = [];
  const original = console.warn;
  console.warn = (...args: unknown[]) => {
    lines.push(
      args.map((a) => typeof a === "string" ? a : JSON.stringify(a)).join(" "),
    );
  };
  try {
    await run();
  } finally {
    console.warn = original;
  }
  return lines;
}

interface UpsertCall {
  table: string;
  // deno-lint-ignore no-explicit-any
  row: Record<string, any>;
  // deno-lint-ignore no-explicit-any
  options: Record<string, any>;
}

/**
 * Stub for `client.from(table).upsert(row, options).select(cols)`, the chain
 * logInboundGarminPayload uses. Shaped after `buildSupabaseInsertStub` in
 * garmin-push/index.test.ts.
 */
function buildUpsertStub(
  // deno-lint-ignore no-explicit-any
  behaviour: { response?: { data: any; error: any }; throws?: boolean } = {},
  // deno-lint-ignore no-explicit-any
): { client: any; calls: UpsertCall[] } {
  const calls: UpsertCall[] = [];
  const client = {
    from: (table: string) => ({
      // deno-lint-ignore no-explicit-any
      upsert: (row: Record<string, any>, options: Record<string, any>) => {
        calls.push({ table, row, options });
        if (behaviour.throws) throw new Error("network down");
        return {
          select: (_cols: string) =>
            Promise.resolve(
              behaviour.response ?? { data: [{ summary_id: row.summary_id }], error: null },
            ),
        };
      },
    }),
  };
  return { client, calls };
}

describe("logInboundGarminPayload", () => {
  const UNMAPPED_GARMIN = "05fec9ca-1bde-4c7b-b2fe-8b8b852298a3";
  const SUMMARY = "24654452703";
  const MAPPED_USER = "550e8400-e29b-41d4-a716-446655440000";
  // A payload carrying fields that must never reach the log line.
  const payload = {
    summaryId: SUMMARY,
    activityType: "RUNNING",
    averageHeartRateInBeatsPerMinute: 151,
    deviceName: "forerunner955",
    startTimeInSeconds: 1759944539,
  };

  const kinds = [
    ["activity", "act"],
    ["activity_detail", "actdet"],
    ["activity_detail_full", "actdetfull"],
  ] as const;

  for (const [kind, prefix] of kinds) {
    it(`skips the write for an unmapped Garmin user and warns once (${kind})`, async () => {
      const { client, calls } = buildUpsertStub();
      const lines = await captureConsoleWarn(() =>
        logInboundGarminPayload(client, kind, UNMAPPED_GARMIN, null, SUMMARY, payload)
      );
      assertEquals(calls.length, 0, "no upsert for an unmapped user");
      assertEquals(lines.length, 1, lines.join("\n"));
      assertStringIncludes(lines[0], `key=${prefix}:${SUMMARY}`);
      assertStringIncludes(lines[0], `garminUserId=${UNMAPPED_GARMIN}`);
      assertStringIncludes(lines[0], "reason=no_user_mapping");
      for (const field of ["RUNNING", "151", "forerunner955", "1759944539"]) {
        assertEquals(lines[0].includes(field), false, `payload field ${field} leaked: ${lines[0]}`);
      }
    });
  }

  it("writes the mapped user's payload as today", async () => {
    const { client, calls } = buildUpsertStub();
    const lines = await captureConsoleWarn(() =>
      logInboundGarminPayload(client, "activity", UNMAPPED_GARMIN, MAPPED_USER, SUMMARY, payload)
    );
    assertEquals(lines, []);
    assertEquals(calls.length, 1);
    assertEquals(calls[0].table, "garmin_health_data");
    assertEquals(calls[0].row.user_id, MAPPED_USER);
    assertEquals(calls[0].row.garmin_user_id, UNMAPPED_GARMIN);
    assertEquals(calls[0].row.summary_id, `act:${SUMMARY}`);
    assertEquals(calls[0].row.data_type, "activity_raw");
    assertEquals(calls[0].row.data, payload);
    assertEquals(calls[0].options.onConflict, "summary_id");
    assertEquals(calls[0].options.ignoreDuplicates, true);
  });

  it("resolves without throwing when the upsert throws", async () => {
    const { client, calls } = buildUpsertStub({ throws: true });
    const lines = await captureConsoleWarn(() =>
      logInboundGarminPayload(client, "activity_detail", UNMAPPED_GARMIN, MAPPED_USER, SUMMARY, payload)
    );
    assertEquals(calls.length, 1);
    assertEquals(lines.length, 1);
    assertStringIncludes(lines[0], "inbound payload log failed (non-fatal)");
  });
});
