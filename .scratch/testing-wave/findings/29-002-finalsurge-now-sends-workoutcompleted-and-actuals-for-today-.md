# 29-002 · FinalSurge now sends WorkoutCompleted and actuals for today's runs (FS-2.1 says never observed), yet the timeline cards still say Planned

- kind: idea
- status: triaged
- ticket: 29
- run: w16-20260924T2100Z
- screen: Timeline
- decision: 

**Steps.**
1. Cold start the dev app, log in as test@test.com (FinalSurge connected).
2. Read the console's FinalSurge transform lines for today's workouts.
3. Look at today's timeline cards; `SELECT` the two activities by provider_workout_id.

**Expected.**
matching.md (FS-2.1) and final_surge_transformer.dart say FinalSurge completion signals (`WorkoutCompleted`, `ActualTime`, `ActualDistanceMeters`) have "never been observed" and that Xuan's one-time probe settles it. Once FS does send them, M-1.3's revive path and a DONE_VERIFIED card with the measured values (integrations-data-display.md) would be expected for a completed FS workout.

**Actual.**
The dev account's FinalSurge feed sends them today. "Easy" (WorkoutKey d67e6590, WorkoutTime 05:32:02) has `WorkoutCompleted: true`, `ActualTime: 2021.254`, `ActualDistanceMeters: 5704.1698`; "Run" (3de79f1a, 07:28:33) has `WorkoutCompleted: true`, `ActualTime: 2154.255`, `ActualDistanceMeters: 6218.839`, and `WorkoutDate` is naive (`2026-09-24T00:00:00`). The app uses the actuals only as fallbacks for the planned fields ("Using ActualTime as fallback", "Using ActualDistanceMeters as fallback"): the Easy card reads "8 mi · 34 min" (planned 8 mi, but actual 3.5 mi) and the Run card "3.9 mi · 36 min", both marked Planned. In the database both rows are `status planned`, `completed_at null`, `actual_*` null, `completion_type manual`. Idea: this is the probe the spec was waiting for (a real completed FS payload with naive timestamps). Xuan or Lee can decide whether FS completion should now mark the card done and store the actuals. Not an app bug on its own, since the spec calls the FS path unverified.

**Evidence.**
- runs/29/console-redacted.log lines 15993-16068 (the two FS payloads and transform results)
- runs/29/06-timeline-tab.png (Easy and Run cards marked Planned)
- runs/29/db-fs-activities-today.txt (both activities planned, actuals null)

**Decision quote.**
> 

**Triage.**

Fix ticket 99 (Lee, 2026-09-25): build it now: FinalSurge completion marks the workout done and stores the actuals, specced app-side awaiting Xuan. Closed by retest ticket 100 after it merges.
