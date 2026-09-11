/**
 * Matcher-executor write-path tests — data-integrations@v1 Stage B.
 *
 * The DECISIONS are pinned by the 41 vectors (matcher.test.ts); these
 * tests pin what the executor WRITES for the decisions that gained new
 * write paths: the M-3 upgrade stamp (atomic, unstamped-only), B-2'
 * sequential leg stamping into brick_metadata with the parent stamped
 * from the first leg, B-4 transition folding by positional identity, and
 * the B-5 duplicate no-op.
 */

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.168.0/testing/asserts.ts";
import { runGarminActivityPipeline } from "./matcher_executor.ts";
import { FAKE_USER_ID, FakeDb, type FakeRow } from "./matching_vectors_harness.ts";
import type { GarminActivitySummary } from "./types.ts";

function garmin(
  overrides: Partial<GarminActivitySummary> & { summaryId: string },
): GarminActivitySummary {
  return {
    userId: "garmin-user-1",
    userAccessToken: "",
    activityType: "running",
    startTimeInSeconds: Date.parse("2026-09-10T15:10:00Z") / 1000,
    startTimeOffsetInSeconds: 0,
    durationInSeconds: 44 * 60,
    ...overrides,
  } as GarminActivitySummary;
}

function row(overrides: Partial<FakeRow> & { id: string }): FakeRow {
  return {
    user_id: FAKE_USER_ID,
    status: "planned",
    activity_type: "running",
    scheduled_date_time: "2026-09-10T07:00:00",
    garmin_summary_id: null,
    provider_workout_id: null,
    deleted_at: null,
    duration_minutes: 45,
    created_at: "2026-09-01T00:00:00Z",
    ...overrides,
  } as FakeRow;
}

Deno.test("M-3 upgrade stamps a mark-done row in place; replay is a duplicate no-op", async () => {
  const db = new FakeDb([
    row({
      id: "A",
      status: "completed",
      actual_duration_minutes: 45,
    }),
  ]);

  const first = await runGarminActivityPipeline(
    db,
    FAKE_USER_ID,
    garmin({ summaryId: "g23" }),
    "[test]",
  );
  assertEquals(first.kind, "upgraded");
  const upgraded = db.get("A")!;
  assertEquals(upgraded.garmin_summary_id, "g23");
  assertEquals(upgraded.status, "completed");
  assertEquals(db.inserts.length, 0); // the legacy duplicate row never appears

  // The same push again: the row is stamped now — duplicate, not a second
  // upgrade, and still no insert (M-0 one-row invariant).
  const replay = await runGarminActivityPipeline(
    db,
    FAKE_USER_ID,
    garmin({ summaryId: "g23" }),
    "[test]",
  );
  assertEquals(replay.kind, "duplicate");
  assertEquals(db.inserts.length, 0);
});

Deno.test("B-2' sequential legs stamp brick_metadata; parent takes the first leg's id; all legs -> verified state", async () => {
  const brick = row({
    id: "BR1",
    activity_type: "brick",
    status: "planned",
    duration_minutes: null,
    brick_metadata: {
      total_duration_minutes: 90,
      segments: [
        { order: 1, sport: "cycling", duration_minutes: 60 },
        { order: 2, sport: "running", duration_minutes: 30 },
      ],
    },
  });
  const db = new FakeDb([brick]);

  const leg1 = await runGarminActivityPipeline(
    db,
    FAKE_USER_ID,
    garmin({
      summaryId: "gb1",
      activityType: "cycling",
      startTimeInSeconds: Date.parse("2026-09-10T07:00:00Z") / 1000,
      durationInSeconds: 58 * 60,
    }),
    "[test]",
  );
  assertEquals(leg1.kind, "brick");
  assert(leg1.kind === "brick" && leg1.verified === false);
  const afterLeg1 = db.get("BR1")!;
  assertEquals(afterLeg1.status, "completed");
  assertEquals(afterLeg1.garmin_summary_id, "gb1"); // first leg stamps the parent
  // deno-lint-ignore no-explicit-any
  const meta1 = afterLeg1.brick_metadata as any;
  assertEquals(meta1.segments[0].garmin.summary_id, "gb1");
  assertEquals(meta1.segments[1].garmin, undefined);
  assertEquals(db.inserts.length, 0); // no standalone leg row (B-5)

  const leg2 = await runGarminActivityPipeline(
    db,
    FAKE_USER_ID,
    garmin({
      summaryId: "gb2",
      activityType: "running",
      startTimeInSeconds: Date.parse("2026-09-10T08:10:00Z") / 1000,
      durationInSeconds: 29 * 60,
    }),
    "[test]",
  );
  assertEquals(leg2.kind, "brick");
  assert(leg2.kind === "brick" && leg2.verified === true);
  // deno-lint-ignore no-explicit-any
  const meta2 = db.get("BR1")!.brick_metadata as any;
  assertEquals(meta2.segments[1].garmin.summary_id, "gb2");
  assertEquals(db.inserts.length, 0);

  // Re-push of a stamped leg: B-5 no double import.
  const dup = await runGarminActivityPipeline(
    db,
    FAKE_USER_ID,
    garmin({
      summaryId: "gb1",
      activityType: "cycling",
      startTimeInSeconds: Date.parse("2026-09-10T07:00:00Z") / 1000,
      durationInSeconds: 58 * 60,
    }),
    "[test]",
  );
  assertEquals(dup.kind, "duplicate");
  assertEquals(db.inserts.length, 0);
});

Deno.test("B-4 transitions fold into brick_metadata positionally, never a standalone row", async () => {
  const brick = row({
    id: "BR1",
    activity_type: "brick",
    status: "planned",
    duration_minutes: null,
    brick_metadata: {
      total_duration_minutes: 90,
      segments: [
        {
          order: 1,
          sport: "cycling",
          duration_minutes: 60,
          garmin: {
            summary_id: "gb1",
            start: "2026-09-10T07:00:00",
            duration_minutes: 58,
          },
        },
        { order: 2, sport: "running", duration_minutes: 30 },
      ],
    },
  });
  const db = new FakeDb([brick]);

  const outcome = await runGarminActivityPipeline(
    db,
    FAKE_USER_ID,
    garmin({
      summaryId: "gbT",
      activityType: "BIKE_TO_RUN_TRANSITION", // unmapped variant, now -> transition
      startTimeInSeconds: Date.parse("2026-09-10T07:58:00Z") / 1000,
      durationInSeconds: 2 * 60,
    }),
    "[test]",
  );
  assertEquals(outcome.kind, "transition_folded");
  // deno-lint-ignore no-explicit-any
  const meta = db.get("BR1")!.brick_metadata as any;
  assertEquals(meta.transitions.T1.summary_id, "gbT");
  assertEquals(meta.transitions.T1.duration_minutes, 2);
  assertEquals(db.inserts.length, 0); // never a standalone row
});

Deno.test("guard refusal falls to insert and leaves the plan open", async () => {
  const db = new FakeDb([
    row({ id: "A", status: "planned", duration_minutes: 45 }),
  ]);
  const outcome = await runGarminActivityPipeline(
    db,
    FAKE_USER_ID,
    garmin({
      summaryId: "g15",
      durationInSeconds: Math.round(8.9 * 60), // 19.8% of 45 -> refused
      startTimeInSeconds: Date.parse("2026-09-10T06:00:00Z") / 1000,
    }),
    "[test]",
  );
  assertEquals(outcome.kind, "inserted");
  assertEquals(db.get("A")!.status, "planned"); // the plan stays open
  assertEquals(db.inserts.length, 1);
  assertEquals(db.inserts[0].status, "completed");
});

Deno.test("DI-7 seam: completing a row leaves every planner field byte-identical", async () => {
  const db = new FakeDb([
    row({
      id: "A",
      status: "planned",
      duration_minutes: 60,
      distance_miles: 8.0,
      distance_meters: 12874.7,
      pace_target_minutes_per_mile: 7.5,
    }),
  ]);
  const before = JSON.stringify({
    duration_minutes: db.get("A")!.duration_minutes,
    distance_miles: db.get("A")!.distance_miles,
    distance_meters: db.get("A")!.distance_meters,
    pace_target_minutes_per_mile: db.get("A")!.pace_target_minutes_per_mile,
  });

  const outcome = await runGarminActivityPipeline(
    db,
    FAKE_USER_ID,
    garmin({
      summaryId: "g44",
      durationInSeconds: 44 * 60,
      startTimeInSeconds: Date.parse("2026-09-10T06:03:00Z") / 1000,
    }),
    "[test]",
  );
  assertEquals(outcome.kind, "completed");

  const after = db.get("A")!;
  const planners = JSON.stringify({
    duration_minutes: after.duration_minutes,
    distance_miles: after.distance_miles,
    distance_meters: after.distance_meters,
    pace_target_minutes_per_mile: after.pace_target_minutes_per_mile,
  });
  assertEquals(planners, before); // L-2 split: the plan survives completion
  assertEquals(after.actual_duration_minutes, 44);
  assertEquals(after.status, "completed");
});

Deno.test("tombstone drop writes nothing", async () => {
  const db = new FakeDb([
    row({ id: "A", status: "deleted", garmin_summary_id: "g1" }),
  ]);
  const outcome = await runGarminActivityPipeline(
    db,
    FAKE_USER_ID,
    garmin({ summaryId: "g1" }),
    "[test]",
  );
  assertEquals(outcome.kind, "dropped");
  assertEquals(db.inserts.length, 0);
  assertEquals(db.updates.length, 0);
});
