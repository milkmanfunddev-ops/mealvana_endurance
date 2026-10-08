# Ticket 50 — run notes

- RUN: w5-20261008T1720Z. Slot claimed 17:20:53Z (12:20:53 CDT).
- App: com.milkman.mealvanaendurance.dev built from commit 3cf7e2b9 (app-build.json agrees), on wave-pool-3
  (D96AEB7E-EC53-4B9B-88DC-A70A6CEE48DB). App data cleared by the lead.
- Worktree branch testing-wave/develop-2026-10/50 at a2e35a42.
- Notification rule: the `notification-testing` skill and `ops/docs/messaging-relay-and-testing.md` are not on
  disk on this machine (IMPROVEMENTS #101). Read instead before checks 2-3: notification_service.dart,
  launch_trail.dart, root_app_widget.dart (resume path), ios/Runner/AppDelegate.swift.
- Shared account: ticket 49 writes meal_logs/saved_meals/food_preferences on test@test.com; ignored here.

## Setup
- 17:21Z log stream started (PID in SCRATCH/logstream.pid); app launched with `netcut.sh launch` (network on) so check 7 needs no relaunch.
- Mobile MCP not used for the in-app screens (idb only).
- 17:23:31Z netcut on → offline login attempt (check 7, below) → 17:23:49Z netcut off → logged in as test@test.com.
  iOS notification permission prompt appeared after login: tapped Allow (needed for check 2).
- Login triggered a sync: FS and TP `last_sync_at` moved to 17:23:55Z (db-integrations-after-login.txt). Expected
  behaviour of the login path, not a write this run made on purpose.

## Check 1 — 40 / 32-001: words, no raw keys — PASS 32-001
- Log In (b01-post-onboarding-login.png, b02-email-login.png), Timeline (b05-after-allow.png), Learn (b06-learn.png),
  Settings (b07-settings.png), Sign Out dialog (b08-signout-dialog.png: "Sign out?", body, Cancel / Sign out),
  Connected Apps (b09-connected-apps.png). Each element list scanned for `word.word` key shapes: none.
  Cancelled the Sign Out dialog.

## Check 2 — 34 / 22-001: backgrounded notification tap — Finding 50-001 (PASS only for a signed-in launch)
- Path (a) used: `xcrun simctl push` with top-level `"payload":"reminder:be55a023-b878-4a32-a166-2ab92b9a4815"`
  (Run - Long Run, Oct 10 07:00, 180 min). The first push's banner timed out before the tap (17:25:51Z, d01/d02);
  push again and tap within ~1 s.
- Tap 1 (17:26:15Z), first session after the in-session login: payload consumed on that resume but
  `HELD … (startup not routable)`, never routed (d03, d04). Finding 50-001.
- Plist after terminate: `flutter.ios_un_response_payload` absent (plist-after-tap1.txt) — consumed and lost.
- Tap 2 (17:27:35Z), after a signed-in cold start: `routing` → `deepLinkTo /plan (seeded / beneath)`, landed on
  Run - Long Run detail (d07, d08), Back → Timeline. Plist after terminate: key absent (plist-after-tap-coldstart.txt).
- The signed-in cold start showed the TrainingPeaks write-back notice sheet (cleared prefs): tapped Close
  ("Closing this leaves sharing on"), d06-tp-notice.png. Expected after an app clear.

## Check 3 — 34 / 32-008: native write while backgrounded, taped on the same resume — PASS 32-008
- Probes 1-3 (17:29:15-17:29:44Z) wrote with `simctl spawn defaults write com.milkman.mealvanaendurance.dev …`:
  known noise: that domain form writes the simulator's GLOBAL Library/Preferences, not the app container, so the
  app never saw them (no line). Key deleted again with the same domain form (domain now absent). Not app behaviour.
- Probes 4-6 wrote `flutter.ios_un_willpresent` to the app container path (as 32-008 did), 1/2/3 s before resume
  from the icon. Each taped on its own resume: 12:30:16.485 (probe 4), 12:30:28.775 (probe 5), 12:30:42.085 (probe 6)
  local = 17:30Z. Screens e04-e06; console `[LAUNCH] native ios_un_willpresent=#9N … wave50-probe-N`.
- Both real taps in check 2 also taped `native ios_un_response_payload=…` on their own resume (5 of 5 overall).

## Check 4 — 46 / 32-002: two-slash link → Page Not Found → Go Home (signed in) — PASS (signed-in half)
- 17:31Z `openurl …://athlete/feedback` (two slashes), iOS "Open in Endurance Dev?" → Open. Page Not Found
  (f01-page-not-found-signed-in.png); Go Home → Timeline (f02-go-home-signed-in.png). Signed-out half: see end.

## Check 5 — 46 / 32-003, 32-004: /buy-credits by deep link — PASS 32-003, PASS 32-004
- `openurl …:///buy-credits` → AI Credits, enabled body (AI_CREDITS_ENABLED on in this build): balance 2489,
  packs 50/250/1 credits. "How credits work": "AI credits pay for meal descriptions, meal photo analysis and
  Formula Kit coach insights. …" — names all three; "conversation" appears 0 times (g01-buy-credits.png).
- Back (top-left) → Timeline; trail `back fallback: canPop=false — going home` (g02-after-back.png).
  Restore and Buy not tapped.

## Check 6 — 44 / 30-004 not run signed in (Finding 50-002); 29-001 — PASS 29-001
- Nutrition Targets (h01): Pre carbs Auto, During Run/Bike carbs 50.4 (pre-existing overrides).
- 17:32:40Z set Pre-Activity Carbs = 40, Save Changes. Row (db-users-after-override.txt): overrides gained
  `pre.carbsG 40`, updated_at moved; body_fat_pct (null), lifestyle mixed, training_phase base, sweat_* , Garmin
  timestamps (weight 2026-09-24 00:44:09, body fat 2026-04-22 12:16:04), typical_weekly_hours, carb_cycle_opt_in all
  unchanged vs db-users-before.txt. Limit: body_fat_pct and sweat_test_date are null before, so a null-wipe of
  those two would not show; the non-null ones (lifestyle, phase, sodium, both timestamps) prove the upsert kept them.
- 17:33:18Z cleared Pre carbs, Save → overrides back to exactly the start value (db-users-after-revert.txt).
  Override reverted. Body Composition reopened (h04): Mixed selected, body fat blank, 185 lb. Left without saving.

## Check 7 — 41 / 32-007: Finding 50-003; 41 / 32-015: PASS 32-015
- Offline login (17:23:31-17:23:49Z): screen "No connection. Check your network and try again." (c01),
  console `expected_failure {area: auth, reason: offline}` + `auth_flow_failed … NoConnectionException`; no
  `error_reported`. Converted: OK.
- Offline cold start 17:34:17Z (`netcut on --relaunch`): region lookup + version check → `expected_failure`
  (privacy, startup). But `error_reported` ×2 area content (app_content) and ×1 area education (lesson list) →
  Finding 50-003. Notification answer not exercised (permission already granted earlier).
- Offline lesson 1.1: "Failed to load video" + Retry (i03); `education_video_opened` then
  `expected_failure {area: education, reason: offline}`; no `error_reported`. Converted: OK.
- 17:35:32Z netcut off; Retry on the lesson loaded the video (i04) — 32-013 Learn path "offline → network back →
  Retry": works.
- 32-015: played 17:35:46Z, Back 17:36:02Z → `education_video_closed percent_watched 16`, no completed. Full play
  17:36:27-17:38:10Z → one `education_video_closed percent_watched 100` and one `education_video_completed`.

## Check 8 — 32-010: event "Test" date columns — Finding 50-004
- Event "Test" already existed (id 65379d67…, created June); this run did NOT create, edit or delete it (the
  lead's note said "delete it at the end": nothing to delete, the row predates the run, and deleting it is not a
  write the ticket names). List JUN 20 2026 (j01), detail Saturday, June 20, 2026 (j02); row event_date
  2026-07-17, start_time 2026-06-20T08:58 (db-event-test-row.txt). Code: athlete list/detail read start_time;
  calendar dots, carb nudge and all coach views read event_date.

## Check 9 — 32-012 (Finding 50-005) + 32-013 (followups 50-011 Events, 50-012 Learn, 50-013 Log a Meal)
- Event Details (Test, past) → More options: Edit Event / Delete Event (k01). Edit Event: typed "wave50" into
  Location, Back → no discard prompt, edit dropped; row unchanged (db-event-test-after-edit-back.txt).
- IM NC 70.3 (TrainingPeaks-imported): detail "Saturday, October 17, 2026 · 1 week away"; More options offers Edit and
  Delete like a manual event (k04, k05). Not tapped.
- `/welcome` signed in → full Welcome with Build My Plan (l01); I already have an account → Log In while signed in
  (l02); Back → Welcome; left by deep link `/main`. Build My Plan not tapped (would start onboarding on the shared
  account). Finding 50-005.
- Learn: offline → network back → Retry loads the video (check 7). Notify Me not tapped (its write is not named).
- Log a Meal: opens on Describe (credit counter 2488; was 2489 on AI Credits at 17:31Z: ticket 49's spend).
  Build a meal → "Start building your meal" empty state (m02). Scan barcode → iOS camera prompt → Don't Allow →
  "Camera access is off…" with "Search for the food instead" and Enter (m04): clear. Header Search with an empty
  field: nothing happens, no hint (m05). Recent shows saved meals incl. ticket 49's "Tw49 eggs toast banana";
  Common quick-adds; Manual form (m06-*). Nothing saved.

## Connected Apps section — started 17:42:14Z (12:42:14 CDT)

## Check 10 — 47 / 32-005: PASS 32-005 (card + no refresh); V.O2 disconnect itself not exercisable
- V.O2 was already inactive at the start (wave 3's disconnect): row is_active false, requires_reauth, English error.
  Card shows plain "Connect", no needs-reconnect pill (b09 at 17:24Z, n02 at 17:42Z). No V.O2 / vdot console line
  in four launches (17:21, 17:27, 17:34, 17:46Z), so no refresh on the dead token. Disconnecting V.O2 again was not
  possible (nothing to disconnect; no test login to connect first).
- TrainingPeaks disconnect (17:42:43Z) — the other half of 32-005: no token refresh before
  `integration_disconnected` (32-005 saw a refresh failure + error_reported there). Row: is_active false, tokens
  cleared, last_sync_status null, last_sync_error null (db-integrations-after-tp-disconnect.txt). Card → Connect.
- The stale English vdot error → Finding 50-009.

## Check 11 — 47 / 32-006 + 37: PASS 32-006, PASS 37 (TrainingPeaks)
- Reconnect 17:43:35-17:44:58Z: sandbox sheet; username field focused (n05), typed lee.tri (autocapitalised to
  "Lee.tri", accepted); password field focused, screenshot n07 confirmed (cursor in Password, last field) before
  `CRED type lee.tri`; dots only (n08). Save Password → Not Now. Permission page: no metrics scope listed (n10).
  Allow → write-back sheet → Keep Sharing (sharing was on before). Card: athlete "Lee Martin" (same as before).
- Sync Now 17:45:16Z: "Synced!", card "Last synced: Just now" without leaving the screen (n14). No
  TokenExpiredException, no metrics line, no error_reported. Row: active, success, last_sync_error null,
  last_sync_at 17:45:17, token expires 18:45:02 (db-integrations-after-tp-sync.txt).
- Relaunch 17:46:24Z: no refresh / token / error line in 30 s (n15).
- Sync Now tracks `integration_connect_started` → Finding 50-010.

## Check 12 — 32-011: Findings 50-006, 50-007, 50-008
- Hidden workouts after reconnect: 43 hidden locally at disconnect, 0 revived after reconnect + sync (sync only
  fetches 45 days ahead; all 43 are past); the hide never uploaded to the server (40 rows still unhidden there,
  needs_upload=1 locally, also after a relaunch). Finding 50-006.
- Delete synced data: SKIPPED. From code it hard-deletes server `activities` rows and `provider_raw_payloads` for the
  provider, which this ticket does not name.
- Reset push notifications: not tapped (OneSignal opt-out/in).
- V.O2 Connect (17:47:25Z): iOS prompt names the app "mealvana_endurance" (Finding 50-008); Cancel → card back to
  Connect, row unchanged, but `error_reported degraded area vdot` + Sentry event (Finding 50-007). No test login
  exists for V.O2, so connect cannot be completed.
- Runna Connect, TP "Turn Off Sharing" then the write-fuel checkbox, long-press discoverability: not run (in the
  Connected Apps followup 50-014).

## Check 4 (signed-out half) — PASS 32-002
- 17:49:29Z Settings → Sign Out → Sign out → Welcome (p01). Sign-out's dirty upload pushed the 43 TP hides to the
  server (db-tp-activities-after-signout.txt; added to 50-006).
- Signed out, `openurl …://athlete/feedback` (two slashes), twice: no iOS prompt, the app stays on Welcome (p02, p03).
  Page Not Found does not show signed out: from code (unverified) the router's redirect sends every non-public path
  without a session to `/welcome` before the errorBuilder. The athlete ends on Welcome, which is what 32-002 asks
  (signed in → Timeline, signed out → Welcome). Go Home could not be tapped signed out since the page never shows.

## Leftovers / end state (17:50Z)
- Override: reverted (db-users-end.txt = start value).
- Event "Test": untouched, nothing created or deleted.
- TrainingPeaks: connected again (active, success, error null; athlete Lee Martin). Write-back sharing kept on.
  Its 43 past workouts are now hidden_by_disconnect = true on the server (Finding 50-006) — the app's own disconnect
  path did that; they will not come back by sync.
- V.O2: left disconnected (it was already inactive at the start; no test login). Its row still carries the old
  English error (50-009).
- App left signed out on Welcome. iOS permissions granted on wave-pool-3: notifications Allowed, camera Denied.
- Simulator global prefs: the stray `flutter.ios_un_willpresent` key from probes 1-3 was deleted again.
- No accounts created. No AI calls, no COST spend. No RevenueCat reads or writes.

## Summary
| Check | Result |
|---|---|
| 1 · 40 / 32-001 | PASS 32-001 |
| 2 · 34 / 22-001 | Finding 50-001 (held after in-session login; routes fine from a signed-in launch) |
| 3 · 34 / 32-008 | PASS 32-008 (3/3, plus 2/2 real taps) |
| 4 · 46 / 32-002 | PASS 32-002 (signed in → Timeline; signed out → Welcome directly) |
| 5 · 46 / 32-003, 32-004 | PASS 32-003, PASS 32-004 |
| 6 · 44 / 30-004; 29-001 | 30-004 not run signed in → followup 50-002; PASS 29-001 |
| 7 · 41 / 32-007; 32-015 | Finding 50-003 (content + lesson list still error_reported); PASS 32-015 |
| 8 · 32-010 | Finding 50-004 |
| 9 · 32-012, 32-013 | Finding 50-005; followups 50-011, 50-012, 50-013 (+ 50-016 Welcome) |
| 10 · 47 / 32-005 | PASS 32-005 (card + no refresh; V.O2 already inactive, TP disconnect clean); 50-009 stale V.O2 error |
| 11 · 47 / 32-006 + 37 | PASS 32-006, PASS 37 (TP); 50-010 analytics |
| 12 · 32-011 | Findings 50-006, 50-007, 50-008; followups 50-014 (+ 50-015 AI Credits) |

Fix tickets: 40, 46 (both halves), 47 and 37 pass every check this ticket ran for them; 34 does not (50-001); 41 does not
(50-003); 44 not run (50-002).
Connected Apps section started 17:42:14Z. Run ended 17:50:40Z.
