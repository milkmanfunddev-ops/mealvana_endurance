# Ticket 69 — run notes

- RUN: w7-20261008T2311Z. Slot claimed 23:11:26Z.
- App: com.milkman.mealvanaendurance.dev built from commit ff4e0ffb (app-build.json agrees), on wave-pool-3
  (99AB368E-1158-4C81-BEEF-913087E4E74D). App data cleared by the lead.
- Worktree branch testing-wave/develop-2026-10/69 at f9a82e0b.
- Notification rule: the `notification-testing` skill is not on disk (IMPROVEMENTS #123). Read instead before
  checks 2-3: notification_service.dart, launch_trail.dart, root_app_widget.dart, ios/Runner/AppDelegate.swift.
- Shared account: ticket 68 writes food_preferences, meal_logs, user_foods, token-ledger debits on test@test.com
  and signs out/in once early; ignored here. FS/TP last_sync_at 23:11:36-37Z at start = 68's login sync.
- Start state read 23:13Z: db-integrations-start.txt, db-events-start.txt, db-activities-hidden-start.txt.
- 23:12Z log stream + launch: Welcome (a00-launch.png). ~23:13Z all three wave simulators (pool-1/2/3) went to
  Shutdown at once and the log stream died (signal 9); host memory was low (vm_stat ~4k free pages). Known noise:
  host/CoreSimulator, not app behaviour; 67 and 68 rebooted theirs. 23:16Z rebooted wave-pool-3, restarted the log
  stream (first console kept in SCRATCH, not evidence), relaunched: Welcome again.

## Check 1 — 50-002 (ticket 44): PASS 50-002 (first half); second half not run (no body-fat control)
- 23:17Z Build My Plan → sports: iOS notification prompt appeared over the sports screen on the first tap
  (b02-notif-prompt.png) → Allow. Running + Cycling, goal, obstacle, no imports, Male, birth year 1994 (default),
  Metric, height 173 cm (default), weight 62 kg (c1-body-comp-62kg.png), default dials.
- Your daily plan (c2/c3/c4): Workout day Protein 1.6 g/kg · 99 g; Rest day 1.4 g/kg · 87 g; Carb load 1.4 g/kg · 87 g.
  PASS 50-002.
- Back ×3 to Basic body composition: unit toggle, height wheel, weight wheel only; scrolled, nothing below
  (c5-body-comp-no-bodyfat.png). There is no body-fat control in onboarding, so "enter a body fat value, record the
  lean-mass Workout-day protein" cannot be run as written: not run, no control. Forward again → plan unchanged.
- Save My Plan → Create Your Account → Sign up with Email; password via CRED (password field focused, secure, fresh
  screenshot before each); code 544607 from Gmail (23:21:03Z) → Timeline. auth user dc939aa5-79f1-46e9-b059-7a8764117bd4
  (db-check1-auth-user.txt); users.weight_pounds 136.69 (= 62.0 kg), body_fat_pct null.
- 23:21:49Z Settings → Delete Account → Delete (c6-delete-dialog.png) → Welcome (c7-after-delete.png). auth.users and
  users rows gone (db-check1-after-delete.txt). CRED state deleted.
- Look-around (Body composition / Daily plan): one followup filed, see Findings list.
- Console noise at the 23:16Z launch: `error_reported {degraded, performance, SlowOperation}` startup.total 11733 ms.
  Known noise: first launch after the simulator reboot under host memory pressure; 08-009's ruling keeps the
  thresholds.

## Check 2 — 59 / 50-001 + 50-016 step 1: PASS 50-001, PASS 50-016 (step 1)
- Activity be55a023-b878-4a32-a166-2ab92b9a4815 (Run - Long Run, Oct 10 07:00, final_surge), db-check2-activities.txt.
  Payload file: top-level "payload":"reminder:be55a023-…" (SCRATCH/reminder.apns).
- 23:23:05Z terminate + relaunch signed out (Welcome). Home, push; first banner gone before the tap (23:23:21Z, no
  tap delivered, d01). Push again, tap at 23:23:34Z: tape `native ios_un_response_payload=…`, `… (consumed)`,
  `reminder_clicked`, `dispatch … handlerSet=true`, `HELD id=be55a023-… type=reminder (no session)`. The dev trail
  dialog opened on Welcome (d03-trail-dialog-held.png). The ticket's `(startup not routable)` is wave 5's wording;
  judged on `(no session)` per the lead's note.
- Same session: I already have an account → Log in with email → test@test.com (CRED, password field focused, fresh
  screenshot) → Log In 23:24:19Z → Timeline (d04). Tape: `DROPPED id=be55a023-… type=reminder (session changed:
  signed in)` at 18:24:20.542 local, then `startup snapshot refreshed (sign_in_profile_saved)`. No REPLAY line, no
  routing: the held tap was dropped, never replayed.
- `push` breadcrumb: never prints (code: report.breadcrumb in HeldNotificationTap._write). Sentry check below.
- Timeline → Home, push, tap 23:24:43Z: `(consumed)` → `routing id=be55a023-…` → `deepLinkTo /plan (seeded /
  beneath)` → Run - Long Run detail (d05-after-tap-2.png). No HELD line left unreplayed in the tape
  (plist-after-tap-coldstart.txt, launch_trail_previous).
- iOS notification permission: Allowed during check 1's onboarding (b02-notif-prompt.png).

## Check 3 — 59, cold start: PASS (59 cold-start half)
- 23:24:58Z terminate + relaunch signed in → TrainingPeaks write-back notice sheet (e01, expected after an app clear)
  → Close ("Closing this leaves sharing on"). Home, push, tap 23:25:26Z: `native …`, `(consumed)`, `dispatch`,
  `routing`, `deepLinkTo /plan (seeded / beneath)`; activity detail behind the trail dialog (e02-after-tap-coldstart.png).
- Terminate, plist read with plistlib: `flutter.ios_un_response_payload` absent (plist-after-tap-coldstart.txt).

## Check 4 — 55 / 50-003: PASS 50-003
- Before: `flutter.education.published_rows` present (2064 chars); `flutter.app_content_cache` absent from the prefs plist.
- 23:26:37Z `netcut.sh launch` then `netcut.sh on SCRATCH --relaunch` (process 33891). Console for that process:
  `[LAUNCH] region lookup offline: device fallback`, `[LAUNCH] version check offline: cached result`, `app_opened`;
  zero `error_reported`, no orange fault/degraded box. Timeline from local data (f01).
- No `expected_failure` console line for content/education (code map: these are now Sentry counts at Info, not
  printed). Settings → Debug console (Copy logs → simctl pbpaste, debug-console-offline-cold-start.txt; f03 Info
  filter): `[content] count expected_failure` ×2, `[education] Showing 5 cached education rows after a failed
  fetch`, `[education] count expected_failure` ×1, `[startup]` and `[privacy] count expected_failure`; no Warning or
  Error entries.
- Dev Sentry (sentry-dev-23-16-to-23-31.txt): nothing in 23:26-23:28Z.
- Learn offline: lessons 1.1, 1.2, 1.3 and the coming-soon cards from the cache (f02-learn-offline.png).
- 23:29Z `netcut.sh off`.
- Sentry note: a warning "onesignal init skipped: no app id configured yet" (area push) at 23:23:03Z carries user.id
  81D07A23-…, not this device (my launches tape it at Info only, no Sentry event); left for the lead to match to
  ticket 67's minutes.
- `push` breadcrumb (check 2): no later Sentry event came from that process (the only 607f9dd5 events in the window are
  ticket 68's), so the breadcrumb could not be seen; code is the only evidence it is written.

## Check 5 — 65 / 50-004: PASS 50-004
- "Test" 65379d67-…: list JUN 20 2026 (g01-events-list.png), detail "Saturday, June 20, 2026" (g02); row event_date
  2026-06-20, start_time 2026-06-20T08:58 (db-event-test-row.txt). Left as it is.
- 23:29:55Z New Event: Run, Half Marathon (default), name typed "tw69 2330" (autocapitalised to "Tw69 2330"), date
  Saturday, November 7, 2026 (default), start 11:30 PM (late on purpose: a UTC conversion would roll the date).
  Row f06c36ae-dcfd-4b26-8b05-1b1584cb1db1: event_date 2026-11-07, start_time 2026-11-07T23:30, origin manual
  (db-tw69-created.txt). Detail "Saturday, November 7, 2026".
- 23:30:26Z Edit Event → date Saturday, November 14 → Save: event_date 2026-11-14, start_time 2026-11-14T23:30
  (db-tw69-after-date-edit.txt), detail moved too (g07). Both columns move together.

## Check 6 — 50-011, Events: Findings 69-002, 69-003, 69-004; followup 69-005
- tw69: Edit Event, typed "tw69 unsaved" in Location, Back (X): left at once, no "discard changes?" prompt; the edit
  was dropped (row location null, updated_at unchanged, db-tw69-after-edit-back.txt; h01). Typing in Location ran a
  place search: "Unable to geocode" 404 → `⛔ [location] Error searching locations` + `error_reported {severity:
  fault, area: location}` (console 18:30:44 local) → Finding 69-003.
- Race Day Checklist on tw69 (h02): 12 default gear items; checked "Running shoes"; Add custom item "tw69 gel flask"
  → listed, 1/13 (h03).
- Delete tw69 (More options → Delete Event → Delete, 23:31:43Z): dialog text "…This will also delete any associated
  nut[rition plans]…" (h04). Server row gone at once (db-tw69-after-delete.txt, hard delete; the event had no linked
  activity, db-tw69-before-delete.txt). Snackbar "Event deleted successfully" but the screen stayed on the deleted
  event's Event Details (h05, h06 ~25 s later) → Finding 69-002. Back → My Events without tw69 (h07).
- tw69's create scheduled three carb_load notifications (`notif_scheduled … event_id: f06c36ae-…`, days 3/2/1); whether
  the delete cancels them was not checked (followup 69-005).
- "Test" (past): "Carb loading window has passed" is a disabled button (AX NotEnabled); tapping does nothing (g03).
- "IM NC 70.3" (origin training_peaks, location null, db-imnc-before.txt): Edit Event shows Triathlon with an empty
  Race Distance (i01). Location → "Raleigh" → picked "Raleigh, North Carolina" (i02, i03) → Save Changes refused:
  "Please select a race distance" (i04-after-save.png). A Location-only edit cannot be saved → Finding 69-004.
  Choosing a distance would be a write the ticket does not name, so I left with X: row unchanged, origin still
  training_peaks, location null (db-imnc-after-x.txt). The TrainingPeaks Sync Now keep/overwrite/duplicate question
  and the origin flip to manual: not run (blocked by 69-004), in 69-005.

## Check 7 — 50-012, Learn: Finding 69-007; followup 69-008
- Notify Me (code: `EducationInterestService.recordNotifyMe` sends analytics only; no table, no prefs key; row: none).
  Tapped "Premium Video Library" Notify Me twice (23:34Z): first → snackbar "We'll let you know", button "Noted"
  (disabled); second tap → nothing. Console: one `education_notify_me_tapped {card: Premium Video Library}` (j01).
  Leaving to a lesson and back kept "Noted".
- Lesson 1.1, Back 0.3 s after opening (before load): `education_video_opened` only; no closed, no completed (j02).
- Lesson 1.1, never played: idb taps/drags on the player's controls did nothing (play, +15 s, bar); the mobile MCP's
  tap and drag worked (its first call sent the app to the background, #50; relaunched, state kept). The drag went to
  the end (01:36); a nudge back to 95 % did not stick, so the scrub tested is 100 %, not 95 %. Back:
  `education_video_closed {percent_watched: 100, watched_sec: 96}` + `education_video_completed` → Finding 69-007.
- Lessons 1.2 (01:24) and 1.3 (01:07) load and play controls show; Back → closed with 0 % (j05, j06). Carousel holds
  1.1-1.5 (j08); dev has five published lessons, all with a video (db-education-content.txt), so "a lesson with no
  video": not run, none exists.

## Connected Apps section — started 23:37:55Z
- Start rows (db-integrations-ca-start.txt): vdot inactive, status/error null; TP active success; Garmin active
  success (last sync Sep 19). Screen on open (k01): FS and TP with Sync Now, Garmin "Sign in again… Reconnect" (no
  Sync Now), V.O2 Connect, Runna Connect.
- 23:38:08Z, first open of the screen: the app fired garmin-backfill by itself → 409 (token expired) → `⚠️ [garmin]`
  box + `error_reported degraded area garmin` → Finding 69-010. Same second the Garmin row became requires_reauth /
  reauth_required. The function log printed Garmin's invalid_grant body with the refresh token value → Finding 69-012
  (value cut from edge-23-16-to-23-44.txt).

## Check 8 — 55 / 50-007: PASS 50-007
- 23:38:15Z V.O2 Connect → iOS prompt (k02) → Cancel → card back on "Connect" (k03). Console: `integration_connect_started
  {vdot}`, then `expected_failure {area: vdot, reason: oauth_cancelled}`; no `error_reported`, no
  `integration_connect_failed`. Row unchanged (db-vdot-after-cancel.txt = start: inactive, null/null, updated 20:46:53).

## Check 9 — 66 / 50-008: PASS 50-008
- The prompt reads "“Mealvana” Wants to Use “vdoto2.com” to Sign In" (k02-vo2-ios-prompt.png).

## Check 10 — 63 / 50-006: PASS 50-006 (and 50-014 step 3)
- Before: server TP rows deleted_at null: 43 hidden false, 0 true (db-tp-hidden-before-disconnect.txt; ticket 63's close
  SQL held). Read-only Drift copy: 43 TP rows, hidden 0, needs_upload 0 (drift-tp-before-disconnect.txt). The device
  had pulled all 43.
- 23:39:06Z long-press TP Sync Now → "Disconnect TrainingPeaks?" (Cancel / Delete synced data / Disconnect, k04) →
  Disconnect. 23:39:10Z (4 s, no Sync Now, no sign-out): server 43 hidden true (db-tp-hidden-after-disconnect.txt);
  Drift copy 43 hidden, needs_upload 0 (uploaded). TP row inactive, status/error null. `integration_disconnected
  {training_peaks, reason: user_initiated}`. Card → Connect (k05).
- Connect → sandbox sign-in sheet (k06) → its X once (23:39:29Z): `expected_failure {area: training_peaks, reason:
  oauth_cancelled}`, no `error_reported`, card on Connect (k07). 50-014 step 3: PASS.
- Connect again: username field focused (zoomed sheet), typed lee.tri (autocapitalised "Lee.tri", accepted); tapped
  Password, fresh screenshot showed the cursor in Password (last field, down arrow grey) → `CRED type lee.tri`; dots
  only (k11 kept in SCRATCH, not RUNS). Log In → Save Password? Not Now → permission page (k13) → Allow 23:40:25Z.
  `integration_connect_success {training_peaks, athlete_name: Lee Martin}`; provider_athlete_id 2687398 (db-tp-athlete.txt).
- 23:40:39Z, before any Sync Now: server 0 hidden (43 false, db-tp-hidden-after-reconnect.txt); Drift copy 0 hidden,
  needs_upload 0 (drift-tp-after-reconnect.txt).
- September workout: server has four TP rows Sep 21-24; the Timeline on Thursday, September 24, Workout filter, lists
  "Rad Device Test Swim" (k20). Seen at 23:43Z, after check 12's Sync Now; the Drift copy already had it unhidden
  before that sync.

## Check 11 — 64 / 50-009: PASS 50-009
- vdot: last_sync_status null, last_sync_error null at start, after the cancel and at 23:42Z.
- TP after the reconnect (23:40:30Z): is_active true, last_sync_status pending, last_sync_error null
  (db-integrations-after-tp-reconnect.txt); after Sync Now success / null (db-integrations-after-tp-sync.txt).

## Check 12 — 60 / 50-010: PASS 50-010
- 23:42:04Z TP Sync Now → "Synced!", "Last synced: Just now" (k17, k18). Console: `integration_sync_started
  {training_peaks, device_id: AD95C56C-27EF-4AA2-ADA3-A1D804FF3698}` → `integration_sync_success {workouts_synced: 0,
  skipped_count: 0, events_count: 0}`; no `integration_connect_started`. device_id is the Settings "Device ID", not the
  user id 607f9dd5-…. Row: success, error null, last_sync_at 23:42:05.

## Check 13 — 50-014, Connected Apps: Finding 69-009; followup 69-011
- Write-back sheet after the reconnect's Allow (the only way to open it, from code) → Turn Off Sharing (23:41:01Z),
  used here instead of Keep Sharing so check 13 could run: pref `flutter.tp_writeback_enabled` 1 → 0, but the card's
  toggle stayed on (k15) until the screen was reopened (k16, off) → Finding 69-009.
- 23:42:40Z toggle "Write fuel plan to TrainingPeaks" on: card on, pref 1 (k19). Sharing left on.
- Runna: not run, no test calendar URL (`CRED list` has no Runna entry).
- Garmin Sync Now: not run, no Sync Now on the card (Garmin link expired, Reconnect only; 69-010).
- Delete synced data: not run (ticket).
- Card text after the reconnect read "Last synced: 16 minutes ago" while the row read pending / last_sync_at null
  (k15); in followup 69-011.

## Check 14 — 50-015, AI Credits: Finding 69-013
- 23:44Z signed in, `openurl …:///buy-credits` → iOS "Open in “Endurance Dev”?" → Open → AI Credits: balance 2487
  credits; packs "50 Credits $4.99", "250 Credits $19.99", "1 Credits $0.99" (m01) → Finding 69-013. "How credits work"
  names meal descriptions, photo analysis and Formula Kit coach insights. Restore and Buy not tapped.
- Back (top left) → Timeline, tape `back fallback: canPop=false — going home`.
- Wait for ticket 68: 23:45:23Z no `68-done`; polled every 60 s (and a 10 s until-loop); `SHARED/68-done` seen 23:50:19Z
  (~5 min wait). No `69-signout-…` flag needed.
- 23:50:38Z Settings → Sign Out → "Sign out?" → Sign out → Welcome. Then `openurl …:///buy-credits` signed out: no iOS
  prompt this time, the app stays on Welcome (m02); tape `startup snapshot refreshed (signed_out)`. It redirects to
  Welcome; the page never shows signed out, so its back control cannot be tried signed out.
- Note (not checked): the "nudge ARMED id=be55a023… fireAt 2026-10-09 19:00" local reminder was armed while signed in;
  whether Sign Out cancels it was not checked.

## Leftover accounts
- None. Check 1's account lee+e2e-69-20261008T2316Z@rightpathprogramming.com (auth id dc939aa5-79f1-46e9-b059-7a8764117bd4)
  deleted in the app; auth.users and users rows gone. CRED state deleted.

## End state
- Event tw69 (f06c36ae-…) deleted (row gone). "IM NC 70.3": never saved (69-004), location null, origin training_peaks.
  "Test" left as the lead's SQL leaves it.
- TrainingPeaks connected (active, success, athlete 2687398), sharing on (pref 1, toggle on). V.O2 disconnected (row
  unchanged). Runna never connected (no URL). Garmin: requires_reauth since 23:38:08Z (the app's own backfill hit the dead
  token; not a write this run chose).
- App signed out on Welcome on wave-pool-3. Notifications Allowed on this simulator. No AI calls, no COST spend, no
  RevenueCat reads or writes. Only SQL: SELECTs. One read of the live Drift file's schema with sqlite3 `.schema`
  (read-only; every count used a copy in SCRATCH).

## Summary
| Check | Result |
|---|---|
| 1 · 50-002 | PASS 50-002 (99 g / 1.6 g/kg; 87 g rest and carb load); body-fat half not run, no control (followup 69-001) |
| 2 · 59 / 50-001, 50-016 step 1 | PASS 50-001, PASS 50-016 step 1 (HELD no session → DROPPED session changed: signed in, no replay; second tap routes); breadcrumb not observable (followup 69-006) |
| 3 · 59 cold start | PASS (routes; ios_un_response_payload absent after terminate) |
| 4 · 55 / 50-003 | PASS 50-003 |
| 5 · 65 / 50-004 | PASS 50-004 |
| 6 · 50-011 | Findings 69-002, 69-003, 69-004; followup 69-005; sync half not run (blocked by 69-004) |
| 7 · 50-012 | Finding 69-007; followup 69-008; no-video lesson not run (none exists) |
| 8 · 55 / 50-007 | PASS 50-007 |
| 9 · 66 / 50-008 | PASS 50-008 |
| 10 · 63 / 50-006 | PASS 50-006 (43 hidden at once; 0 after reconnect before Sync Now; Sep 24 workout on Timeline) |
| 11 · 64 / 50-009 | PASS 50-009 |
| 12 · 60 / 50-010 | PASS 50-010 |
| 13 · 50-014 | Finding 69-009; followup 69-011; Runna not run (no URL), Garmin Sync Now not run (link expired); also 69-010, 69-012 |
| 14 · 50-015 | Finding 69-013; signed out → Welcome |

Fix tickets whose checks all passed here: 59, 55, 60, 63, 64, 65, 66 (and ticket 44's check, 50-002).
Connected Apps section started 23:37:55Z. App work ended 23:51Z.
