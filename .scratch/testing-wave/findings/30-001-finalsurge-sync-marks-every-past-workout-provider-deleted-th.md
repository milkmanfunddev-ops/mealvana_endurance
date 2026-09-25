# 30-001 · FinalSurge sync marks every past workout provider-deleted the day after it happens

- kind: bug
- status: triaged
- ticket: 30
- run: w10-20260924T1615Z
- screen: Timeline
- decision: 

**Steps.**
1. Sign in as test@test.com on a cleared app (the sign-in runs the FinalSurge integration sync; FinalSurge's date-range endpoint answers 404, so the sync falls back to UpcomingWorkouts from today).
2. Read `activities.provider_deleted_at` for the account's FinalSurge rows, grouped by workout day.

**Expected.**
A workout that has already happened and is still on FinalSurge keeps `provider_deleted_at` NULL. Only a workout removed upstream is soft-deleted.

**Actual.**
Every FinalSurge workout gets `provider_deleted_at` on the first sync after its day passes: 09-17 rows on 09-18, 09-18 on 09-19, 09-19 on 09-20, 09-20 on 09-21, 09-21 on 09-22, 09-22 on 09-23, 09-23 on 09-24 (13 rows in this week alone, all `status = planned`). The sync compares the upcoming-only remote window against every local FinalSurge row (`final_surge_sync_service.dart` fetches `getUpcomingWorkouts` from today; `change_detection_service.dart` flags any local provider id missing from the remote list), so a workout that simply fell out of the window reads as deleted upstream. One TrainingPeaks row (09-21 Corpus Tempo Run) shows the same pattern.
The timeline still shows these rows (as Skipped), so the athlete's week looks right today; coach mode filters `provider_deleted_at IS NULL` (`athlete_detail_controller.dart:139`, `coach_sync_handler.dart:124`), so a coach would see none of the athlete's past FinalSurge sessions. Not checked on the coach side in this run.

**Evidence.**
- runs/30/db-provider-deleted-by-day.txt
- runs/30/db-week-activities.txt (column 7 is provider_deleted_at)
- runs/30/console-excerpts.log (line 8: "Date-range endpoint unavailable (404), falling back to UpcomingWorkouts for 14 days")
- runs/30/screen-week-sessions.txt

**Decision quote.**
> 

**Triage.**
Fix ticket 42 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 117 when 92 was split (Lee, 2026-09-25).
