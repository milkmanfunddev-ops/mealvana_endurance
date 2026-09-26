# Ticket 117, wave 40 notes

- RUN: `w40-20260926T1052Z`. Slot claimed 10:52:08Z (testing-wave-113 also holding).
- App on UDID `2D57B881-540A-4A8F-8C80-5E6CE3B34221` (wave-pool-2), built from commit
  `72d3723e7a441d607e5b39de19f8ff6d89cb8cf7` (carries fix ticket 42). Worktree at `6739f0fc`.
- App data cleared by the wave lead: expected to open signed out on Welcome, empty local database.
- Mac clock CDT (America/Chicago). Today is Sat 2026-09-26.
- Shared account: ticket 113 runs on test@test.com at the same time (meals "W40-113 …"); those moving is expected.

## Run log (UTC)
- 10:52 before sign-in: FinalSurge/TrainingPeaks rows since 09-13 read (`db-before-signin-provider-rows.txt`):
  no past FinalSurge row flagged; one TrainingPeaks row (09-21 Corpus Tempo Run) flagged 09-22 by an older build.
  Rows synced 10:23Z today (e.g. 09-26 Run - Long Run) already show `last_synced_at` 10:23:07+00 against
  `updated_at` 05:23:07 local: another session (113's sign-in, same build) already wrote UTC.
- 10:53 launch: `simctl launch` left SpringBoard in front; second `simctl launch` brought Welcome (signed out).
- 10:53:59.9 tapped Log In (test@test.com, password by `CRED type`, 10 dots = its length).
  Frames at +0.7 s steps (`02-after-login-1..6.png`): "Logging in…" spinner for ~2 s, then Timeline with the
  What's New sheet over it by ~10:54:03. Console: RevenueCat login 10:54:01.1, FinalSurge sync start 10:54:01.5,
  "Date-range endpoint unavailable (404), falling back to UpcomingWorkouts for 14 days" 10:54:04.0,
  "Integration sync complete for final_surge" 10:54:05.4. So the whole first sync ended ~5 s after Log In,
  while the What's New sheet covered the tab bar.
- 10:54:24 Got it on What's New. No TrainingPeaks sharing sheet followed (tabs_screen.dart: ticket 64 skips it
  when the TP connection needs a reconnect; `db-integrations-state.txt` shows training_peaks `requires_reauth`).
- 10:54:45-10:54:50 Food, Events, Learn, Timeline, 1.2-1.5 s apart (`04-race-*.png`), all rendered;
  no Flutter console line at all between 10:54:05.5 and 10:55.
- 10:55:20 SQL after sign-in: no FinalSurge row's `provider_deleted_at` changed (diff of before/after empty);
  the sync updated 3 rows (09-26 Run - Long Run, 10-01 Easy, 10-03 Fast Finish) with `last_synced_at`
  10:54:05+00 (UTC, correct) and `updated_at` 05:54:05 (local, `timestamp without time zone`, as before).
- 10:55:42 `integrations.last_sync_at` for final_surge/training_peaks/vdot reads 2026-09-26 05:54:0x+00: the CDT
  wall clock labelled UTC, 5 h off, the same fault as 30-002 in another table (Finding 117-001).
- known noise: TrainingPeaks token refresh 400 and VDOT "Please reconnect" at sign-in: the dev admin's
  integrations are expired (`requires_reauth`), the app reports them and carries on (same as wave 10).
- 10:56-11:00 week walk online (30-006): each day's cards match `db-week-activities.txt` (Sun 3, Mon 4, Tue 4, Wed 4 + brick,
  Thu 6, Fri 2, Sat 2). Past-day skipped workouts carry no time and sit out of time order (after the day's evening
  meals; on Wed between the 7:42 PM meals and the 9:00 PM brick) (Finding 117-002). Brick card still reads
  "BRICK 3 legs · 124 min", no title. Workout filter on Fri 25 heads the card "TODAY'S WORKOUT" (117-003).
  Horizontal swipe does not change the day (no swipe handler in fuel_timeline; not built, not filed).
  Timeline has no pull-to-refresh (no RefreshIndicator in fuel_timeline/macro_dashboard): the pull did nothing and
  logged nothing (117-005). Same-minute order (Thu's two Patrol H5 20:45, Wed's four 07:00) identical across three
  visits including a cold start and offline.
- Month picker (30-007): Sep 17-24 still carry no marker (skipped-only days); 16 and 25 green (completed), 26-30 orange
  rings. Tapping 21 went to Mon 21 and closed the sheet; month arrows went to Aug and Oct; Today moved the
  selection to 26 but left the sheet open until swiped down (117-004). The "Next day" arrow moves with the title's
  width: two taps at its old x opened the month picker instead (noted in 117-004).
- 11:01-11:02 Learn online (29-005): lesson 1.1 opened paused on its first frame, Play ran to 00:19, Back mid-play
  clean; 1.2 played to 00:09. Notify Me: two taps, no feedback at all; `coming_soon_section_widget.dart` has
  `onPressed: null` (117-006). Courses renders ("Structured Learning Paths", Coming Soon).
  known noise: MediaToolbox/VideoToolbox err=-12852/-12871/-12900 and CFNetwork -999 (cancelled) lines while the
  player opens and closes: simulator decoder and cancelled range requests; both lessons played.
  known noise: `education_video_completed` fires on leaving with percent_watched 29 and 12: by design
  (`video_player_screen.dart` tracks the watched share on exit), not a completion.
- 11:03 cold relaunch (online): iOS notification permission alert on this second launch; tapped Don't Allow
  (Allow would register a push token for the shared account).
- 11:03-11:04 Events (29-006): Cozumel detail ("1 month away" for Nov 23, 58 days out: 117-007), Baton Rouge
  ("Event completed", View Nutrition Plan); back from each fine. New Event only shows as an orange sliver under the
  tab bar (03-007 still true, re-checked); a tap on the sliver opened New Event; edge-swipe back wrote nothing
  (events count 5 and max updated_at unchanged, `db-events-*.txt`). Console clean apart from integration noise.
- 11:05:14 offline cold start (29-003) with `netcut.sh on --relaunch`: Timeline, Food, Events render from the local
  database; Learn shows "No videos available yet" (117-008). Food logged 11 `[VANA_TRANSPORT] Network error calling
  vana-action` boxes over 38 s, 4 in the first 1.5 s (117-009). Week walk offline equals the online walk. `[IS_ADMIN]` warning
  seen (known noise, 120-009). No exception or red screen.
- 11:08 network restored (netcut off).
- 11:08:53 Sign Out (test@test.com, local). 11:09:19 signed back in: no What's New (seen per device), no sharing
  sheet, and the Timeline opened on Sunday, September 20, the day last viewed before sign-out, not today (117-010).
  FinalSurge sync skipped ("data is fresh"); flags unchanged (`db-after-second-signin.txt`).
- 11:10:42 signed out of test@test.com for good (local). Nothing else was written to test@test.com by this run.
- 11:12:47 account A `lee+e2e-117-20260926T1110Z@rightpathprogramming.com` (user 69f071a8-74d9-4567-84b4-19d7a7c75a95)
  signed up (Running, email code from Gmail). A stray tap after Verify (the tap-by-label helper matched a label on the
  next screen) opened iOS's "wants to use google.com to Sign In" prompt; Cancel. Not an app problem.
- 11:13:45 Monthly bought through the Test Store; the new account's Timeline also opened on Sunday, September 20
  (`78-after-purchase.png`), the previous account's last-viewed day (117-010). RevenueCat and `user_entitlements`
  agree: active_until 11:18:46 (`revenuecat-A-after-purchase.txt`, `db-A-entitlement-after-purchase.txt`).
- 11:14:32 05-007 online cold relaunch recorded (`05-007-cold-relaunch-online.mp4`, ~15 fps source, extracted at 10 fps,
  `05-007-online-frames-sheet.png`): splash, spinner, one black frame (frame 61, 06-006 still true, re-checked),
  then Timeline on Today. No paywall frame.
- 11:15:34 05-007 offline cold relaunch (`netcut.sh on --relaunch`, recorded, `05-007-offline-frames-sheet.png`):
  splash, spinner, three black frames (70-72, ~0.3 s), Timeline. No paywall frame.
- 11:16:42 planned workout on A: Timeline "+ Add Activity", Running, defaults (12 mi Run, today 7:30 am), Generate Plan
  (first tap raised the iOS location prompt, Don't Allow, then Generate Plan again), Create Plan.
  Back walked through Adjust Your Macros and the create form (116-011, known).
- 11:18 meal on A: "+ Add Food", Manual, "W40-117 oats" 500 kcal 80C 20P 10F, Save ("Meal logged!").
  Timeline: meal 6:18 AM, 12 mi Run 7:30 AM Planned, Net balance +28 (`88-timeline-A-before-lapse.png`).
  Entitlement renewed at 11:18:46 to 11:23:46.
- 11:20:01 A signed out; 11:20:36 app data cleared with `clear-app.sh` (10-004 asks for a fresh install; no reinstall).
- Lapse did not hold (117-015): A's entitlement ended 11:23:46, RevenueCat showed no active entitlement at 11:24:51,
  then renewed at 11:25:28 while the cleared app sat on Welcome. The first lapsed sign-in (11:25:53) therefore landed on
  the Timeline, paid (`A-after-lapsed-signin.txt`, `90-A-lapsed-signin.png`): not a Finding, the account was paid again.
  Signed out (11:26:50), app terminated; polling (`A-renewals-while-signed-out.txt`): renewed again at 11:29:28 and
  11:37:29 with the app closed. RevenueCat v2 cancel refused ("not a Web Billing subscription",
  `revenuecat-A-cancel-response.txt`); that was the run's only write attempt on RevenueCat, and it changed nothing.
- 11:38:53 Log In timed 7 s after the period end (11:38:46): the lapsed full-screen paywall with its ⋯ menu
  (`92-A-signin-in-lapse-gap.png`). 11:39:13 resubscribed Monthly (Test valid purchase). The Timeline behind What's New
  showed the meal and the 12 mi Run at once (`93-A-after-resubscribe.png`).
- 10-004: 11:39:35 cold launch without opening Food: meal 6:18 AM, 12 mi Run 7:30 AM Planned, Net balance +6
  (`94-…`); Previous day (Fri 25, −2,006, empty) and Next day back to today: both rows and +6 again (`95-…`, `96-…`).
  Net balance drifted from +28 (11:19) to +21 (11:26) to +6 (11:39) with the same meal: it moves with the time of day
  (test@test.com's went +470, +462, +456 the same way). known noise: time-of-day burn, not a lost row.
- 29-003 revoked leg on A: 11:40:10 `global-logout.sh` (password grant + `/logout?scope=global`, 204; A's sessions and
  live refresh tokens 0). 11:40:19 cold start: signed in, every tab renders, eleven Vana 401 boxes, Vana card stuck on
  "Looking at your day…" (117-011). The expiry leg (wait out the 1 h access token) was not run (117-012).
- 11:41:34 A signed out, 11:41:51 signed in again, 11:42:07 Settings → Delete account → Delete: Welcome.
  `db-A-after-delete.txt`: auth user, meal_logs, activities, user_entitlements all 0. The RevenueCat customer and its
  Test Store subscription remain (the delete dialog says deleting does not cancel). CRED row set to deleted.
- 11:42:51 log stream stopped (PID), app terminated, slot released. Console 73 MB raw, 42 token-pattern lines; kept
  the app's own lines without them (`console-redacted.log`, 649 KB, rescan 0) and replaced the FinalSurge `s=` keys in
  WorkoutURL lines with `<redacted>`.
- Edge functions: no vana-action request from test@test.com online and no `vana_calls` row for it in this run's minutes (`db-vana-calls-test-account.txt`). A's revoked-session leg reached vana-action and got 401s (no model call). No AI call was made and nothing was spent.

## Leftover accounts
- none (A deleted in-app; no unconfirmed sign-up).
