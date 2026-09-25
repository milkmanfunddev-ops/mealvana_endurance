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
  logGarminMappingMiss,
  logGarminRecordFailure,
} from "./push_log.ts";

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
