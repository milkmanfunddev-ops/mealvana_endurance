# Ticket 117 verdicts (wave 40, run w40-20260926T1052Z, build 72d3723e)

| id | verdict | evidence (under `runs/117/`) | new Finding |
|---|---|---|---|
| 30-001 | pass | `db-before-signin-provider-rows.txt`, `db-after-signin-provider-rows.txt`, `db-after-signin-flagged-by-day.txt`, `db-after-second-signin.txt`, `notes.md` (sync fell back to UpcomingWorkouts at 10:54:04Z; no past FinalSurge row flagged; `provider_deleted_at` identical before and after both sign-ins) | none |
| 30-002 | pass | `db-after-signin-touched.txt` (`last_synced_at` 10:54:05+00 for a sync at 10:54:05Z) | 117-001 (the same fault remains in `integrations.last_sync_at`, outside 30-002's steps) |
| 30-006 | pass, with Findings | `11-day-*.png`, `12-day-25-bottom.png`, `13-…`, `14-…`, `16-…`, `17-today-pull-refresh.png`, `54-offline-day-*.png`, `db-week-activities.txt` (every day equals SQL, online and offline; same-minute order stable across visits) | 117-002, 117-003, 117-005 |
| 30-007 | pass, with Finding | `20-month-picker-sep.png`, `21-…`, `22-…`, `23-after-today-tap.png`, `24-…` (skipped-only days still carry no marker; day tap, arrows, Today and swipe-down all land) | 117-004 |
| 30-010 | pass (Turn Off Sharing not run) | `02-after-login-*.png`, `03-after-gotit.png`, `db-integrations-state.txt`, `62-…`, `notes.md` (What's New once per device; no sharing sheet for the `requires_reauth` TrainingPeaks, as ticket 64 intends; Keep Sharing and Turn Off Sharing unreachable on test@test.com; no run-made account has TrainingPeaks) | 117-013 |
| 29-004 | pass, partly run | `02-after-login-*.png`, `04-race-*.png`, `notes.md` (first sync ended 10:54:05Z, 5 s after Log In, under the What's New sheet, which covers the tab bar: switching tabs before the sync ends is not reachable; tabs switched 1.2-1.5 s apart right after, all rendered, no console line) | none |
| 29-003 | fail (offline leg passes; revoked-session leg fails; expiry leg not run) | `50-…`-`54-…`, `97-…`, `98-A-revoked-*.png`, `console-redacted.log`, `notes.md` | 117-008, 117-009, 117-011, 117-012 |
| 10-004 | pass | `92-A-signin-in-lapse-gap.png`, `93-…`, `94-…`, `95-…`, `96-…`, `db-A-rows-before-lapse.txt`, `db-A-after-resubscribe.txt` (meal, planned run and net balance on the Timeline after a cold relaunch and a day change, Food never opened) | 117-015 (harness: lapse) |
| 05-007 | pass | `05-007-cold-relaunch-online.mp4`, `05-007-cold-relaunch-offline.mp4`, `05-007-online-frames-sheet.png`, `05-007-offline-frames-sheet.png` (10 fps: no paywall frame online or offline; one and three black frames, 06-006) | none |
| 29-005 | fail (Notify Me) | `30-learn.png`, `31-…`, `32-…`-`37-…`, `38-learn-courses.png` (1.1 and 1.2 play and stop cleanly; no player error lines beyond simulator decoder noise; Courses renders) | 117-006 |
| 29-006 | pass, with Findings | `41-events-cold.png`, `42-event-cozumel.png`, `43-event-baton-rouge.png`, `45-new-event-form.png`, `46-…`, `db-events-before-new-event.txt`, `db-events-after-new-event.txt` (cold start, both details, New Event and back writes nothing; console clean) | 117-007, 117-014 |

Other Findings from this run: 117-010 (timeline keeps the last viewed day across sign-out and into another account).
