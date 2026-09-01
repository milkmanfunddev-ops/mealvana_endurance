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
