# Ticket 32 run notes

- RUN: w3-20261008T1256Z
- App build: a89ace2a (ROUND/app-build.json agrees), dev flavour, installed by the lead on wave-pool-3
  (3A0F104C-B259-4A9A-BF4A-5466AE21469A). App data cleared by the lead (signed out, empty DB and prefs).
- Slot claimed 12:56:48Z (testing-wave-32).

## Permission state at first launch
- First launch 12:57:43Z, signed out. No `push heal: permission=` line: signed out, the app logs
  `onesignal started; permission ask + heal wait for an athlete id` instead, so heal does not run.
  The simulator's BulletinBoard `VersionedSectionInfo.plist` has no section for the dev bundle:
  permission is not determined (never asked on this clone). No prompt on the signed-out launches.

## Step 1: 08-007 and 01-011 (ticket 28), and 22-002
- Cold launch 12:57:43Z: Welcome, no launch-trail dialog after 14 s (a01).
- Resume 1 (HOME, icon) 12:58:34Z, resume 2 12:58:45Z, resume 3 (openurl `welcome`, "Open in
  Endurance Dev?" -> Open) 12:59:37Z: no dialog on any (a03, a04, a05, a06). Console: no dialog line.
- Real push: `xcrun simctl push` of SCRATCH/fg-probe.apns (top-level `payload` key) at 12:59:52Z
  with the app in front: not delivered to the UN delegate (no `ios_un_willpresent` write, no banner),
  because the app has no notification authorization on this simulator. So the simulator push cannot
  feed the guard here; step 5 then answers the prompt Don't Allow, which keeps it so. **Real-payload
  half not run** -> followup-test for Lee's phone (filed).
- Instead, the guard was fed through the native store the way AppDelegate writes it
  (`simctl spawn defaults write <app plist> flutter.<key>`), not a real notification:
  - 13:00:28Z, app backgrounded: wrote `flutter.ios_un_willpresent="#0 payload=wave32-bg-probe ..."`;
    resume 13:00:31Z taped `native ios_un_willpresent=...` and exactly one dialog opened (a08).
  - 13:01:10Z, backgrounded again: wrote probe-2; resume 13:01:11Z did NOT tape it; console
    `trail dialog skipped: already shown this process` (a09: the same one dialog, not stacked).
  - 13:01:43Z wrote `flutter.ios_un_response_payload=wave32-bg-probe-3`; resume 13:01:48Z taped
    probe-2 (late by one resume), not probe-3; the next resume 13:02:08Z taped probe-3.
  - Killed-app half: terminated, wrote `flutter.ios_legacy_launch_payload=carb_event:wave32-killed-probe`,
    cold launch 13:02:41Z: `legacy_launch payload=... (consumed)`, `HELD id=wave32-killed-probe
    type=carb_event (startup not routable)`, exactly one dialog (a13). The key was removed.
    The HELD tap stays held on Welcome (signed out); watch whether it replays after sign-in.
  - Cold launch 13:03:19Z with stale `ios_un_willpresent` and `ios_un_response_payload` still set
    (22-001: never cleared): no dialog (a15). The guard ignores seeded lines.
- **PASS 08-007** (no dialog on a plain cold start or any resume; fires on real-payload evidence lines).
- **PASS 01-011** (one dialog per process; later evidence resumes log `already shown this process`).
- **22-002: new Finding** (see below): a native write made while backgrounded reached the trail on the
  same resume once (probe 1) and one resume late twice (probes 2 and 3). No `reload()` exists in
  `lib/` or in `LaunchTrail.pullNative()` (`launch_trail.dart` reads `prefs.getString` from the cached
  legacy instance; shared_preferences 2.5.3 `getString` reads `_preferenceCache`), so what refreshes
  the cache at all is not visible in the code.
- 22-001: no backgrounded tap could be made (no authorization); not re-checked. `ios_un_response_payload`
  stays set after it was taped, as 22-001 says (plutil read 13:03Z).

## Step 2: 08-020 (signed out offline)
- netcut launch 13:03:5xZ, `on --relaunch` offline since 13:03:59Z. Offline signed-out cold start:
  Welcome renders, no crash (b01).
- "I already have an account" -> Log in with email -> test@test.com, Log In at 13:05:18Z offline:
  no crash, no spinner left; the line under the form reads the raw content key
  `auth.login.error_no_connection` (b04, b05 at 14 s) instead of the default text in
  `assets/config/content_defaults.json` ("No connection. Check your network and try again.") -> Finding.
  The same tap sent two `error_reported severity: degraded` events (AuthRetryableFetchException,
  NoConnectionException) for an ordinary offline login -> in the same Finding.
- Operator slip, 13:04:3xZ: a `cred.mjs type ... --help` probe typed the test password into the
  focused Email field. It was never read back or captured: no screenshot was taken, only its length
  was read, and the field was cleared with backspaces to its placeholder before the real entry.
  Not submitted. Lead: no rotation needed unless you judge otherwise.
- netcut off 13:05:51Z.

## Step 3: 08-022 (signed out deep links)
- `/athlete/feedback`, `/buy-credits`, `/settings/food-preferences` (three-slash), each -> Welcome
  (b06, b07-*). No signed-in screen.
- `com.milkman.mealvanaendurance://athlete/feedback` (two slashes) signed out -> Welcome, not Page Not
  Found (b08). Reason from code: the host form makes the path `/feedback`; the router's session check
  (`app_router.dart` redirect, `currentSession == null` -> `/welcome`) runs before the errorBuilder.
  That is the sane fallback; the Page Not Found / Go Home half is re-run signed in at step 10.

## Step 4: sign in, 08-020 (kill during sync)
- Log In tap 13:07:16Z (online). The iOS notification prompt came up about 1 s later over the
  Timeline (c01), so the kill waited for step 5's 10 s: Don't Allow 13:07:33Z, Timeline visible
  13:07:35Z (c02), terminated 13:07:36Z (within 2 s of the Timeline being usable; first sync was
  still writing: `integrations.updated_at` for training_peaks/vdot moved at 13:08:1xZ, after relaunch).
- Relaunch 13:08:02Z: Timeline back with the account's data (LT 6:38, Foam Rolling 7:00, ticket 31's
  "tw31 eggs toast banana" 8:06), no reset, no crash, no prompt (c03). **PASS 08-020** (with step 2:
  signed-out offline cold start and offline sign-in: no crash; the raw key is its own Finding).
- c02 (first Timeline after sign-in) showed the reconnect notice with raw content keys
  `connections.reconnect_notice` / `connections.reconnect_notice_action` -> Finding. Not shown on the
  relaunch (c03).
- Sync writes the app made on its own at sign-in (not this run's action): final_surge last_sync_at
  13:07:23Z success; training_peaks / vdot `updated_at` 13:08:1xZ with `requires_reauth`.
- Known noise (ticket text: dead TP and V.O2 tokens): `error_reported` TrainingPeaksApiException x2
  (13:07:23-24Z), vdot TokenRefreshException (13:07:24Z).

## Step 5: 08-017 and 08-009 (ticket 22)
- Prompt launches: fresh install signed out (3 cold launches + netcut launches): never. First shown
  right after sign-in, in the same process (13:07:17Z). Not shown on the relaunch after the kill.
  Left up ~16 s, Don't Allow 13:07:33Z.
- Trail: `permission prompt wait 16805ms granted=false`, `notification permission answer:
  granted=false`, `push heal: permission=false optedIn=false (hydration wait 0ms)`, `push heal: no action`.
- No `error_reported ... SlowOperation` in that process or later. Timer durations are breadcrumbs/spans
  only (`performance_telemetry.dart` `_recordDuration`), never printed to the console, so
  `deferred.notifications`, `deferred.revenuecat`, `dashboard.activities.background_sync` and
  `dashboard.integration_sync` values are not readable here (ticket 17: read them in Sentry).
  Note: signed out, the permission ask waits for an athlete id, so the prompt ran after sign-in,
  outside the startup `deferred.notifications` step. **PASS 08-009** (no SlowOperation; the wait is
  taped). **PASS 08-017** (prompt appears once, at sign-in; Don't Allow sticks).
- After Don't Allow: `notif_scheduled` carb_load x3 (`notifications_enabled: false`) and a nudge
  ARMED line, 13:07:34Z: scheduling with permission off, as intended per the ticket.

## Step 6: 08-023 (Timeline order and net balance)
- Day with same-time activities: Wed Oct 7 (SQL: three activities at 07:00, the day 08-023 saw).
  Read 1 13:09:29Z (d02): R-CORE Routine, Bike, Swim (all Skipped); net −2,083.
  Read 2 after Events -> Timeline round trip 13:09:48Z (d03): R-CORE, Bike, Swim; −2,083.
  Read 3 after terminate + relaunch 13:10:15Z (d04): R-CORE, Bike, Swim; −2,083.
  Order stable. **PASS 08-023** (order half). Oct 7 is now a past day, so its balance is fixed (1440 min).
- Today's balance with no new log: −1,577 (13:07:35Z, c02), −1,579 (13:08:18Z, c03), −1,582
  (13:10:0xZ). Reason in code: `dashboard_assembler.dart:379-437`: `minutesSinceMidnight` for today is
  the clock, and `IntradayDisplay.burnedSoFar` prorates RMR and NEAT by elapsed minutes
  ("neat_so_far = neat_kcal × (waking_minutes_elapsed / total_waking_minutes)", intraday-display.md §1),
  truncating. The deficit grows ~1 kcal a minute by design. Not a Finding.
- Ticket 31's meal "tw31 eggs toast banana" (8:06 AM, today) was already on the Timeline at 13:07:35Z.

## Step 7: 08-008 (ticket 28) and 08-018 (Events)
- Events tab 13:10:44Z (e01): upcoming IRONMAN Cozumel; past Test, Baton Rouge Half, Test123, Test 1.
- Slow drag to the end (e02, 13:10:58Z): New Event frame y 690-746 pt; the floating bar had collapsed
  to the small trophy button at the bottom left (x<70), and the button sits fully clear above it.
  Tap 13:11:07Z -> New Event form (e03); Back without saving -> My Events.
- Upcoming event (e04, "7 weeks away") and past event "Test" (e05, "Event completed"): each opens Event
  Details; Back returns to the list.
- Pull to refresh 13:11:47Z (e06): list unchanged, no error.
- Swipe on "Test" 13:11:54Z: "Delete Event / Are you sure you want to delete "Test"?" (e07); Cancel ->
  card stays (e08). SQL `events` count for the account: 5 before (13:08:49Z) and 5 after (13:12:07Z)
  (db-events-before.txt, db-events-after.txt).
- **PASS 08-008**, **PASS 08-018**.
- Known noise on this account (ticket text): TrainingPeaks `invalid_grant` and V.O2 TokenRefreshException
  `error_reported` lines at 13:10:07-08Z (sync after relaunch).

## Step 8: 08-019 (Learn)
- Learn 13:12:31Z (f01). The Notify Me buttons read the raw key `learn.notify_me` (content Finding).
- Lesson 1.2: plays (f02, f03); mute toggles (f05, muted icon); fullscreen enters and exits (f07);
  -15 / +15 move 00:45 -> 01:00 (f08, f09 control bars). Controls auto-hide: a tap while hidden only
  reveals them (idb taps need reveal + tap in one go).
- Lesson 1.3 (off-screen: carousel swiped) opens and plays (f10).
- Notify Me handler read first: `EducationInterestService.recordNotifyMe` sends one analytics event
  (`education_notify_me_tapped`), no server write. Pro Videos tapped 13:16:06Z, Courses 13:16:21Z:
  each button becomes `learn.notify_me_noted`, with a toast `learn.notify_me_confirm` (raw keys, f11,
  f12). Analytics lines: `education_notify_me_tapped {card: Premium Video Library}` and
  `{card: Structured Learning Paths}`.
- `education_video_completed` is sent on leaving the player whatever was watched: 1.3 logged
  `percent_watched: 15` (08:16:04 local) -> idea Finding.
- Offline: netcut launch 13:16:4xZ, `on` 13:17:01Z, lesson 1.1: "Failed to load video" + Retry, no crash
  (f13, f14). It sent `error_reported {severity: fault, area: education, exception_type:
  PlatformException}` for an ordinary offline load -> Finding. netcut off 13:17:28Z.
- Note: an earlier `netcut on` at 13:16:3xZ shut 0 sockets because the app had been relaunched without
  the library (step 4's plain relaunch); that is why the second launch.
- **PASS 08-019** for the player paths; the raw keys and the fault event are separate Findings.

## Step 9: 08-016 (Recipes on a vegetarian account)
- Settings -> Diet, Allergies & Formulas (13:17:58Z, g02): Dietary Preference **Vegetarian**, 2 allergies.
  Settings itself shows more raw keys: `settings.delete_account_button`,
  `settings.profile_preferences_title`, `settings.profile_preferences_subtitle` (g01).
- Timeline "+ Add Food" -> Log a Meal sheet (h01), Recipes tab (h02, 13:18:27Z): 30 recipes, list in
  h03-recipes-list.txt (names cut at the last word). Meat or fish offered: Baked Salmon & Sweet Potato
  Recovery Bowl, Chicken & Brown Rice Recovery Bowl, Salmon Sushi, Smashed Avocado Toast with Smoked
  Salmon, Teriyaki Chicken Rice, Turkey & Avocado Recovery (…), Whole Wheat Pasta with Turkey (…).
  No marker on any of them.
- Query: `recipe_repository.dart:83-86` selects all `is_active` recipes ordered by name; nothing in
  `lib/features/recipes` or the sheet reads the diet. SSOT: diet rules exist for plan generation
  (`docs/ssot/spec/recommendation/generate-plan.md` H2: "The algorithm never *selects* a
  diet/allergy-violating ...") and for formula pins (`formula-pin-surface.md` FP-4a); none for the
  meal-log recipe list. Unfiltered with no rule: noted, and filed as an `idea` so triage can take the
  product question (not an ssot-conflict). Sheet closed with Back, nothing logged (13:19Z).

## Step 10: ticket 26 (08-003, 08-004, 08-005, 08-010, 08-011, 08-012, 08-014), signed in
- 13:19:38Z-13:20:52Z, each three-slash link: `/pro` (i01), `/settings/sport-settings`,
  `/settings/food-preferences-consolidated`, `/settings/food-preferences/add-food`, `/meal-log/manual`,
  `/meal-log/photo`, `/meal-log/describe`, `/meal-log/recent-saved`, `/meal-log/recipe` (i03-*): every
  one shows "Page Not Found / The page you're looking for doesn't exist." with Go Home. No console
  exception (no app log line at all for these navigations).
- **Go Home lands on Welcome, not the Timeline**, signed in (i02 at 5 s, i04, i05 at 25 s). The session
  is intact: `/settings` deep link right after shows "Signed in with Email test@test.com" (i06). Code:
  `app_router.dart:1111` errorBuilder `onPressed: () => context.go('/welcome')`; `/welcome` is a public
  route, so the redirect never sends a signed-in athlete on. -> Finding (retest of 08-022's Go Home).
- Two-slash `com.milkman.mealvanaendurance://athlete/feedback` signed in (13:22:04Z): Page Not Found
  (i07); Go Home -> Welcome after 5 s (i08). Same Finding.
- In-app half: Settings -> Diet, Allergies & Formulas opens and Back works (step 9, g02). The Log a Meal
  sheet's five tabs (Recent, Common, Recipes, Describe, Manual) all open (j01-*), 13:22:56-13:23:10Z.
  `/athlete/feedback` renders Coach Messages "No Messages Yet" with Back (i09).
  `/buy-credits` renders AI Credits (balance 2490, three packs, i10) but has **no Back or close**, and
  an edge swipe does nothing: deep-linked, the screen has no way out but another link. -> Finding.
- **PASS ticket 26 / 08-003, 08-004, 08-005, 08-010, 08-011, 08-012, 08-014** for the archive itself
  (every path unknown, nothing in the app lost a way in). The Go Home landing is a separate Finding.

## Step 11: ticket 27 (08-001, 08-002, 08-006)
- `/jade` 13:23:21Z: Page Not Found, no black screen (k01). Go Home -> Welcome (k02; same Finding as
  step 10).
- No Jade or Mealvana AI chat entry on Timeline, Events, Learn or Settings (element lists of every
  screen visited). "Mealvana AI" remains as the meal-estimate feature's name (Describe tab,
  `today_log_section.dart:244`, `edit_meal_log_screen.dart:367`), which ticket 27 keeps.
  But AI Credits' "How credits work" still reads "AI credits power coach insights, meal photo analysis,
  meal descriptions, and Mealvana AI conversations." (`buy_credits_screen.dart:328`, i10): it sells
  the archived chat -> Finding citing 08-002 / ticket 27.
- **Ticket 27 `/jade` half: PASS (08-001)**; 08-002: the entry points are gone, the credits copy is the
  new Finding; 08-006 went with the screen (not reachable). The thinking-status half is ticket 31's.

## Step 12: 08-021 (Sign Out)
- Settings -> Sign Out 13:23:48Z. The dialog shows only raw keys (l01): title
  `settings.sign_out_confirm_title`, body `settings.sign_out_confirm_body`, buttons
  `settings.confirm_cancel` and `settings.sign_out_confirm_action`. The text it should show
  (`content_defaults.json` `settings.*`): "Sign out?" / "You'll need to sign in again to use Mealvana.
  Your data stays with your account." / "Cancel" / "Sign out". No guest wording anywhere.
- Cancel (13:23:59Z): still signed in (l02). Sign Out 13:24:01Z: Welcome (l03); console
  `Signing out user with scope: SignOutScope.local`, `user_signed_out`. `/main`, `/settings`,
  `/events` deep links then all land on Welcome (l04): nothing of the account visible, no guest offer.
- Behaviour matches the intended text, so the old "as a guest" mismatch is gone. But the athlete reads
  four raw keys, so **08-021 is not passed**: it rides on the content Finding (same root).

## Connected Apps section (Lee, 2026-10-07), run LAST
- **Started 13:25:07Z** (signed back in as test@test.com, online; no prompt).
- Schema note: `integrations` has no `status` or `requires_reauth` columns (information_schema read
  13:08Z). Reads use `provider, is_active, token_expires_at, last_sync_at, last_sync_status,
  last_sync_error, updated_at` (no token columns). Section start: db-integrations-section-start.txt
  (training_peaks and vdot `is_active true`, `last_sync_status requires_reauth`).
- Connected Apps (m01): TrainingPeaks and V.O2 cards show only raw keys
  `settings.connection_reconnect_button`, `settings.connection_needs_reconnect`; Garmin shows
  `connections.garmin_sync_note` (content Finding). No visible Disconnect: the way is a long-press on
  the Reconnect / Sync Now pill (`integration_provider_card.dart:357-360`); the screen's hint "Tip:
  Long-press "Sync Now" to disconnect" sits below the fold.
- V.O2: long-press 13:26:20Z -> "Disconnect V.O2?" (Cancel / Delete synced data / Disconnect) (m02);
  **Disconnect** (hide, the default) 13:26:26Z. Console `integration_disconnected {provider: vdot}`,
  `Disconnect vdot: removed 14 workouts`. Row: `is_active false`, `token_expires_at null`, still
  `last_sync_status requires_reauth` (db-integrations-after-vo2-disconnect.txt). The card still reads
  "needs reconnect" with a Reconnect pill, before and after leaving the screen (m03, m04, m14) ->
  Finding (`Integration.needsReconnect` reads only `last_sync_status`, `integration.dart:93`).
- TrainingPeaks: long-press 13:26:55Z (m05), Disconnect 13:27:00Z. Before disconnecting, the app tried
  the dead refresh token again (08:27:01 local: `TrainingPeaksApiException: Token refresh failed
  (status: 400)` + `error_reported` degraded) -> in the Finding with the needs-reconnect state. Then
  `Disconnect training_peaks: removed 43 workouts`. Row `is_active false` (db-integrations-after-tp-disconnect.txt).
- Reconnect 13:27:13Z: in-app sheet oauth.sandbox.trainingpeaks.com (m07). Username `lee.tri`, password
  with `cred.mjs type lee.tri`. **Operator slip 13:27:3xZ**: the sheet zooms when the Username field
  takes focus, so the tap meant for Password landed in Username again and `CRED type` typed the
  TrainingPeaks password into the visible Username field; one screenshot (m08) caught it. That PNG
  was deleted at once (never committed), the field cleared with backspaces, and the password then went
  into the Password field reached with the keyboard's next-field arrow (m09). **Lead: rotate the
  lee.tri TrainingPeaks password**: it appeared in clear text in a screenshot this agent read.
- Log In 13:28:33Z -> iOS "Save Password?" -> Not Now; "Request for Permission" -> Allow 13:28:51Z (m10).
  The app then showed the TrainingPeaks sharing sheet ("Mealvana writes your plan to each TrainingPeaks
  workout ..."); chose **Keep Sharing** (the default; "Closing this leaves sharing on.") (m11).
  The connected TP athlete is now "Lee Martin" (it was "Xuan Huang" on the dead row).
- Sync Now 13:29:16Z -> "Synced!" (m13). Console: `TokenExpiredException[training_peaks]: Access token
  expired or invalid` from `getAthleteMetrics` on the token minted 30 s earlier, `error_reported
  degraded` -> Finding; `Event sync complete: 1 new`; `TrainingPeaks sync complete: 0 workouts
  imported`. The card said "Last synced: Sep 28 at 1:16 PM" until the screen was re-entered, then
  "Just now" (m13, m14) -> in the same Finding.
- **integrations row after reconnect** (db-integrations-after-tp-reconnect.txt, 13:29:4xZ):
  training_peaks `is_active true`, `token_expires_at 2026-10-08 14:28:55+00`, `last_sync_at
  2026-10-08 13:29:18+00`, `last_sync_status success`, `last_sync_error null`. vdot `is_active false`,
  `last_sync_status requires_reauth`. Live.
- Writes caused (named by the ticket, plus what they brought): the two disconnects hid 14 V.O2 and 43
  TrainingPeaks workouts locally; the reconnect's sync imported one event, "IM NC 70.3" (2026-10-17,
  origin training_peaks; events count 5 -> 6, db-events-after-tp-sync.txt) and 0 workouts. Its
  `created_at` reads "08:29:26" (local wall time in a `timestamp without time zone` column: the naive
  writer ticket 22's closing note lists for `events`; not filed again).
- Relaunch 13:30:22Z: no TrainingPeaks or V.O2 refresh failure in the next 40 s (no `invalid_grant`, no
  TokenRefresh line). **Pass for the section.** One new line: `[privacy] Region lookup failed`
  (TimeoutException after 2 s, online) + `error_reported degraded` -> in the network-noise Finding.
- Edge logs for the run window: edge-logs-run-window.txt (all 200; warnings are the ruled F4a line and a
  garmin-push "no device" for another user, c2c7e005…, not this run: lead's wave-wide extract).
- Side observation: event "Test" shows "Saturday, June 20, 2026" in the app, but its server row has
  `event_date 2026-07-17` and `start_time 2026-06-20T08:58` (db-event-test-row.txt) -> followup-test Finding.

## Verdicts (for the lead)
| Check | Verdict |
|---|---|
| 08-007 (ticket 28, guard) | PASS 08-007 |
| 01-011 (ticket 28, once per process) | PASS 01-011 |
| 22-002 (pullNative on resume) | new Finding 32-008 (late by one resume in 2 of 3 probes) |
| 22-001 | not re-checked (no deliverable notification); known, 22-001 / ticket 34 |
| real-payload half | not run on the simulator -> 32-009 (Lee's phone) |
| 08-020 (offline cold start, offline sign-in, kill during sync) | PASS 08-020 (raw key on the offline error is 32-001) |
| 08-022 (signed-out deep links, two-slash form, Go Home) | signed-out half passes; Go Home -> 32-002 |
| 08-017 (prompt timing) | PASS 08-017 |
| 08-009 (ticket 22, timer excludes the prompt) | PASS 08-009 |
| 08-023 (order, balance) | PASS 08-023 (order stable; balance drift by design, cited) |
| 08-008 (ticket 28, New Event clears the bar) | PASS 08-008 |
| 08-018 (Events paths, swipe cancel, count unchanged) | PASS 08-018 |
| 08-019 (Learn) | PASS 08-019 (raw keys 32-001; offline fault event 32-007; analytics idea 32-015) |
| 08-016 (Recipes on Vegetarian) | noted: unfiltered, no rule -> idea 32-014 |
| ticket 26 (08-003, 08-004, 08-005, 08-010, 08-011, 08-012, 08-014) | PASS for all seven (paths unknown, nothing lost); Go Home 32-002; /buy-credits no Back 32-003 |
| ticket 27 `/jade` half (08-001, 08-002, 08-006) | PASS 08-001, PASS 08-006 (not reachable); 08-002: entries gone, credits copy 32-004 |
| 08-021 (Sign Out) | behaviour passes; dialog is raw keys -> 32-001 (keep 08-021 open on it) |
| Connected Apps section | integrations row live, relaunch clean; 32-005, 32-006, followup 32-011 |

Other Findings: 32-007 (network noise to Sentry), 32-010 (event date columns disagree), 32-012, 32-013 (look-arounds).

## Known noise (not filed)
- TrainingPeaks `invalid_grant` / V.O2 TokenRefreshException `error_reported` lines up to 13:27:01Z:
  the account's dead tokens (ticket text). None after the reconnect and relaunch.
- Edge `sessionCost: unknown sport "other"` warnings: ruled F4a behaviour, says so in the line.
- Edge garmin-push 13:00:46Z "reached no device for user c2c7e005… (recipients=0)": another user whose
  device is not subscribed; the function handles it (does not count it as sent). Not this run.
- `onesignal: app id arrived AFTER initialize() — arming now (ordering guard, patch #3)` (13:02:46Z): the
  guard doing its job.

## Writes on the account
- Before the Connected Apps section: none by this run (events 5 -> 5). Automatic sign-in syncs updated
  `integrations.updated_at` / `last_sync_*` (the app's own behaviour).
- Connected Apps section (named): V.O2 and TrainingPeaks disconnected (14 + 43 workouts hidden
  locally), TrainingPeaks reconnected to the sandbox athlete "Lee Martin", Keep Sharing chosen, Sync Now
  imported event "IM NC 70.3" (events 5 -> 6). Ticket 31 reads the sharing sheet on its own simulator.
- Simulator-only writes (not the account): native UserDefaults keys `ios_un_willpresent`,
  `ios_un_response_payload` (left set), `ios_legacy_launch_payload` (consumed by the app).

## Leftover accounts
- None (no account created).
