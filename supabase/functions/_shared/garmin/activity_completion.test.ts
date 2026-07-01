import {
  assertEquals,
  assertExists,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { describe, it } from "https://deno.land/std@0.168.0/testing/bdd.ts";

import {
  buildGarminCompletionUpdate,
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
