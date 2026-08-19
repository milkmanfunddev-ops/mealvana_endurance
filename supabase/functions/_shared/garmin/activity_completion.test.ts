import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  buildGarminCompletionUpdate,
  enrichCompletedGarminActivity,
  getGarminLocalDayBounds,
} from "./activity_completion.ts";

describe("garmin activity completion helpers", () => {
  it("builds local day bounds using Garmin timezone offset", () => {
    const bounds = getGarminLocalDayBounds({
      startTimeInSeconds: 1711582200, // 2024-03-28T04:50:00Z
      startTimeOffsetInSeconds: -18000, // UTC-5 -> 2024-03-27 local
      durationInSeconds: 1800,
    });

    assertEquals(bounds.scheduledDate, "2024-03-27");
    assertEquals(bounds.nextDate, "2024-03-28");
    assertEquals(bounds.startOfDayNaive, "2024-03-27 00:00:00");
    assertEquals(bounds.endOfDayNaiveExclusive, "2024-03-28 00:00:00");
  });

  it("builds completion update fields including completed_at and actual metrics", () => {
    const update = buildGarminCompletionUpdate(
      {
        startTimeInSeconds: 1711612800, // 2024-03-28T13:20:00Z
        startTimeOffsetInSeconds: -18000,
        durationInSeconds: 2700,
      },
      {
        duration_minutes: 45,
        distance_meters: 5200,
        distance_miles: 3.231,
        average_heart_rate: 142,
        max_heart_rate: 168,
        calories_burned: 380,
        average_pace_minutes_per_mile: 8.65,
      },
    );

    assertEquals(update.status, "completed");
    // Bug 3a6e3fdb: completing a matched planned activity must replace the
    // planned start with the ACTUAL Garmin start, in local-naive form
    // (1711612800 UTC at -5h = 2024-03-28 03:00:00 local).
    assertEquals(update.scheduled_date_time, "2024-03-28T03:00:00");
    assertEquals(update.completed_at, "2024-03-28T08:45:00.000Z");
    assertEquals(update.duration_minutes, 45);
    assertEquals(update.actual_duration_minutes, 45);
    assertEquals(update.distance_meters, 5200);
    assertEquals(update.actual_distance_miles, 3.231);
    // Displayed mileage is reconciled to the actual synced distance, not the
    // planned distance.
    assertEquals(update.distance_miles, 3.231);
    assertEquals(update.average_heart_rate, 142);
    assertEquals(update.max_heart_rate, 168);
    assertEquals(update.calories_burned, 380);
    assertExists(update.updated_at);
    assertExists(update.last_synced_at);
  });

  it("overwrites planned distance with a zero actual distance (start/stop run)", () => {
    // A run that was started and immediately stopped: Garmin reports 0 distance.
    // The planned activity showed 12 mi; completion must reconcile it to 0 so
    // the day's mileage (and distance-derived calories) aren't inflated.
    const update = buildGarminCompletionUpdate(
      {
        startTimeInSeconds: 1711612800,
        startTimeOffsetInSeconds: -18000,
        durationInSeconds: 30,
      },
      {
        duration_minutes: 1,
        distance_meters: 0,
        // Mapper now emits distance_miles: 0 for a 0 m run.
        distance_miles: 0,
        calories_burned: 2,
      },
    );

    assertEquals(update.distance_meters, 0);
    assertEquals(update.actual_distance_miles, 0);
    assertEquals(update.distance_miles, 0);
    assertEquals(update.calories_burned, 2);
  });

  it("writes actual start time even when metrics are omitted", () => {
    const update = buildGarminCompletionUpdate(
      {
        startTimeInSeconds: 1711612800,
        startTimeOffsetInSeconds: 0,
        durationInSeconds: 0,
      },
      {},
    );

    assertEquals(update.scheduled_date_time, "2024-03-28T08:00:00");
  });

  it("leaves planned distance untouched when Garmin omits distance", () => {
    // No distance reported at all (e.g. some indoor activities) → don't zero a
    // legitimate planned workout; distance fields are simply not written.
    const update = buildGarminCompletionUpdate(
      {
        startTimeInSeconds: 1711612800,
        startTimeOffsetInSeconds: -18000,
        durationInSeconds: 2700,
      },
      {
        duration_minutes: 45,
        calories_burned: 400,
      },
    );

    assertEquals("distance_meters" in update, false);
    assertEquals("distance_miles" in update, false);
    assertEquals("actual_distance_miles" in update, false);
    assertEquals(update.calories_burned, 400);
  });
});

// ============================================================================
// enrichCompletedGarminActivity — losing webhook payloads backfill metric gaps
// ============================================================================

/**
 * Supabase-shaped stub for the enrich chain:
 *   from().select().eq().eq().eq().is().limit() -> {data, error}
 *   from().update(u).eq().eq()                  -> {error}
 */
function buildSupabaseEnrichStub(
  // deno-lint-ignore no-explicit-any
  existingRows: any[],
): {
  // deno-lint-ignore no-explicit-any
  client: any;
  capturedUpdate: () => Record<string, unknown> | null;
} {
  let captured: Record<string, unknown> | null = null;
  const selectChain = {
    eq: () => selectChain,
    is: () => selectChain,
    limit: () => Promise.resolve({ data: existingRows, error: null }),
  };
  const client = {
    from: (_table: string) => ({
      select: (_cols: string) => selectChain,
      update: (u: Record<string, unknown>) => {
        captured = u;
        const updateChain = {
          eq: () => updateChain,
          then: (
            // deno-lint-ignore no-explicit-any
            resolve: (v: any) => void,
          ) => resolve({ error: null }),
        };
        return updateChain;
      },
    }),
  };
  return { client, capturedUpdate: () => captured };
}

describe("enrichCompletedGarminActivity", () => {
  const USER = "550e8400-e29b-41d4-a716-446655440000";

  it("backfills zero duration/distance from a richer losing payload", async () => {
    // Preliminary `activities` payload won the race and wrote 0s; the
    // richer `activityDetails` payload must fill them in (bug 3a6e3fdb).
    const stub = buildSupabaseEnrichStub([{
      id: "act-1",
      duration_minutes: 0,
      actual_duration_minutes: 0,
      distance_meters: 0,
      distance_miles: 0,
      actual_distance_miles: 0,
      average_heart_rate: null,
      max_heart_rate: null,
      calories_burned: null,
      average_pace_minutes_per_mile: null,
    }]);

    const outcome = await enrichCompletedGarminActivity(
      stub.client,
      USER,
      "summary-1",
      {
        duration_minutes: 60,
        distance_meters: 16093.4,
        distance_miles: 10,
        average_heart_rate: 150,
        calories_burned: 700,
      },
      "[test]",
    );

    assertEquals(outcome.kind, "enriched");
    const update = stub.capturedUpdate();
    assertExists(update);
    assertEquals(update!.duration_minutes, 60);
    assertEquals(update!.actual_duration_minutes, 60);
    assertEquals(update!.distance_meters, 16093.4);
    assertEquals(update!.distance_miles, 10);
    assertEquals(update!.actual_distance_miles, 10);
    assertEquals(update!.average_heart_rate, 150);
    assertEquals(update!.calories_burned, 700);
    // Enrichment must never flip status or rewrite timing fields.
    assertEquals("status" in update!, false);
    assertEquals("completed_at" in update!, false);
    assertEquals("scheduled_date_time" in update!, false);
  });

  it("reports no_gaps when the completed row already has real metrics", async () => {
    const stub = buildSupabaseEnrichStub([{
      id: "act-1",
      duration_minutes: 45,
      actual_duration_minutes: 45,
      distance_meters: 8000,
      distance_miles: 4.97,
      actual_distance_miles: 4.97,
      average_heart_rate: 140,
      max_heart_rate: 165,
      calories_burned: 400,
      average_pace_minutes_per_mile: 9.1,
    }]);

    const outcome = await enrichCompletedGarminActivity(
      stub.client,
      USER,
      "summary-1",
      { duration_minutes: 46, distance_meters: 8100, distance_miles: 5.03 },
      "[test]",
    );

    assertEquals(outcome.kind, "no_gaps");
    assertEquals(stub.capturedUpdate(), null);
  });

  it("does not write zeros over gaps (losing payload must be richer)", async () => {
    const stub = buildSupabaseEnrichStub([{
      id: "act-1",
      duration_minutes: 0,
      distance_meters: 0,
    }]);

    const outcome = await enrichCompletedGarminActivity(
      stub.client,
      USER,
      "summary-1",
      { duration_minutes: 0, distance_meters: 0, distance_miles: 0 },
      "[test]",
    );

    assertEquals(outcome.kind, "no_gaps");
  });

  it("reports not_found when no completed row matches the summary id", async () => {
    const stub = buildSupabaseEnrichStub([]);

    const outcome = await enrichCompletedGarminActivity(
      stub.client,
      USER,
      "summary-404",
      { duration_minutes: 60 },
      "[test]",
    );

    assertEquals(outcome.kind, "not_found");
    assertEquals(stub.capturedUpdate(), null);
  });
});

// ============================================================================
// Sync beats skip (workout-card v2 G6, platform-resolution SKIPPED addition
// 2026-08-17): the matcher MUST consider status='skipped' rows, under the
// RULED key (platform id, else same sport + start ±15 min), before the
// day-wide planned window — and the atomic completion write must be able to
// land on them.
// ============================================================================

import {
  findMatchingPlannedActivity,
  findMatchingSkippedActivity,
  GARMIN_COMPLETABLE_STATUSES,
} from "./activity_completion.ts";

/** Records every filter of every query so the test can assert the key. */
function buildRecordingStub(
  // deno-lint-ignore no-explicit-any
  answer: (filters: Record<string, unknown>[]) => any[],
) {
  const queries: Record<string, unknown>[][] = [];
  const client = {
    from: (_table: string) => ({
      select: (_cols: string) => {
        const filters: Record<string, unknown>[] = [];
        queries.push(filters);
        // deno-lint-ignore no-explicit-any
        const chain: any = {
          eq: (col: string, v: unknown) => (filters.push({ eq: [col, v] }), chain),
          in: (col: string, v: unknown) => (filters.push({ in: [col, v] }), chain),
          is: (col: string, v: unknown) => (filters.push({ is: [col, v] }), chain),
          gte: (col: string, v: unknown) => (filters.push({ gte: [col, v] }), chain),
          lte: (col: string, v: unknown) => (filters.push({ lte: [col, v] }), chain),
          lt: (col: string, v: unknown) => (filters.push({ lt: [col, v] }), chain),
          order: () => chain,
          limit: () => Promise.resolve({ data: answer(filters), error: null }),
        };
        return chain;
      },
    }),
  };
  return { client, queries };
}

const has = (filters: Record<string, unknown>[], op: string, col: string) =>
  filters.find((f) => Array.isArray(f[op]) && (f[op] as unknown[])[0] === col);

describe("sync beats skip — findMatchingSkippedActivity", () => {
  const USER = "550e8400-e29b-41d4-a716-446655440000";
  // 2026-08-14 17:30 local (UTC-5) — the canonical mock day's planned run.
  const run = {
    startTimeInSeconds: Date.UTC(2026, 7, 14, 22, 30) / 1000,
    startTimeOffsetInSeconds: -18000,
    durationInSeconds: 5400,
  };

  it("matches a status='skipped' row by summary id first", async () => {
    const stub = buildRecordingStub((filters) =>
      has(filters, "eq", "garmin_summary_id") ? [{ id: "w2", title: "Run" }] : []
    );
    const match = await findMatchingSkippedActivity(
      stub.client, USER, "running", run, "g-run-99",
    );
    assertEquals(match?.id, "w2");
    const q = stub.queries[0];
    assertEquals(has(q, "eq", "status")?.eq, ["status", "skipped"]);
    assertEquals(has(q, "eq", "garmin_summary_id")?.eq, ["garmin_summary_id", "g-run-99"]);
  });

  it("falls back to same sport + start within ±15 min (the ruled key)", async () => {
    const stub = buildRecordingStub((filters) =>
      has(filters, "gte", "scheduled_date_time") ? [{ id: "w2", title: "Run" }] : []
    );
    const match = await findMatchingSkippedActivity(
      stub.client, USER, "running", run, null,
    );
    assertEquals(match?.id, "w2");
    const q = stub.queries[stub.queries.length - 1];
    assertEquals(has(q, "eq", "status")?.eq, ["status", "skipped"]);
    assertEquals(has(q, "eq", "activity_type")?.eq, ["activity_type", "running"]);
    // 17:30 local ± 15 min, naive local form.
    assertEquals(has(q, "gte", "scheduled_date_time")?.gte, ["scheduled_date_time", "2026-08-14 17:15:00"]);
    assertEquals(has(q, "lte", "scheduled_date_time")?.lte, ["scheduled_date_time", "2026-08-14 17:45:00"]);
  });

  it("findMatchingPlannedActivity tries the skipped tier before the planned window", async () => {
    const stub = buildRecordingStub((filters) =>
      has(filters, "eq", "status") && has(filters, "eq", "status")?.eq?.toString().includes("skipped") &&
        has(filters, "gte", "scheduled_date_time")
        ? [{ id: "w2", title: "Run" }]
        : []
    );
    const match = await findMatchingPlannedActivity(
      stub.client, USER, "running", run, null,
    );
    assertEquals(match?.id, "w2");
    // No day-wide planned query was needed once the skipped tier matched.
    assertEquals(stub.queries.some((q) => has(q, "in", "status")), false);
  });

  it("with no skipped match, the day-wide planned/draft window still runs", async () => {
    const stub = buildRecordingStub((filters) =>
      has(filters, "in", "status") ? [{ id: "w9", title: "Planned run" }] : []
    );
    const match = await findMatchingPlannedActivity(
      stub.client, USER, "running", run, null,
    );
    assertEquals(match?.id, "w9");
  });

  it("the atomic completion write can land on a skipped row", () => {
    assertEquals(GARMIN_COMPLETABLE_STATUSES.includes("skipped"), true);
    assertEquals(GARMIN_COMPLETABLE_STATUSES.includes("planned"), true);
    assertEquals(GARMIN_COMPLETABLE_STATUSES.includes("deleted"), false);
    // ...and it clears the skip: completion status is 'completed'.
    const update = buildGarminCompletionUpdate(run, {});
    assertEquals(update.status, "completed");
    assertExists(update.actual_time);
    // actual_time is NAIVE LOCAL, matching scheduled_date_time and the
    // column type (timestamp without time zone): 22:30 UTC at −05:00 is
    // 17:30 local, no zone suffix (the timestamptz round-trip shift caught
    // on dev 2026-08-19).
    assertEquals(update.actual_time, "2026-08-14T17:30:00");
    assertEquals(update.scheduled_date_time, update.actual_time);
  });
});
