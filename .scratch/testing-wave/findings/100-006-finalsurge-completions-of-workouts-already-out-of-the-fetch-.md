# 100-006 · FinalSurge completions of workouts already out of the fetch window are never read again (Sep 24 runs stay planned)

- kind: idea
- status: open
- ticket: 100
- run: w39-20260926T1013Z
- screen: Timeline (Sep 24); FinalSurge sync
- decision: 

**Steps.**
1. test@test.com, sign in on build 72d3723e (carries tickets 99 and 101).
2. Read the FinalSurge fetch in the console and the two workouts 29-002 named.

**Expected.**
The Sep 24 "Easy" (d67e6590) and "Run" (3de79f1a), which FinalSurge reported completed with actuals, are stored completed once the fix ships.

**Actual.**
The fetch starts at today (21 workouts, 2026-09-26 on), so the Sep 24 workouts are never read again. Both stay status planned, completed_at null, completion_type manual, actuals null. Only completions that arrive while the workout is inside the window count (the Sep 25 swim did). Idea: a one-time backfill of recent past days, or a fetch window that reaches back a few days.

**Evidence.**
- runs/100/db-fs-completed-activities.txt
- runs/100/console-redacted.log (search "WorkoutCompleted" and "Fetched 21 workouts")

**Decision quote.**
> 

**Triage.**

