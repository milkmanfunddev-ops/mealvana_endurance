# 08 run notes

- RUN: w1-20261007T1105Z. Ticket 08, wave 1, round develop-2026-10.
- App build: `ce1a1527` (ROUND/app-build.json), installed on wave-pool-3 (9D1318E5-…), app data NOT cleared (leftover-data ticket).
- Slot claimed 11:05Z.
- Part A account (from the local DB `users` row, confirm on screen): test@test.com.

## Part A (first launch 11:06:05Z, pid 98596)

- Before: user_version 22, 40 tables (`db-tables-before.txt`), develop-lineage v22 (Vana tables + `activities.duration_source`, no `users.home_*`). Signed-in user row: test@test.com.
- The mobile MCP's first call (11:06:10Z) failed (WebDriverAgent start timeout) and left SpringBoard in front; `simctl launch` at 11:06:51Z brought the SAME process (pid 98596) back, so the cold start was not repeated. The app sat in the background for ~40 s of its first minute; this colours the slow-operation timings below.
- On screen: "Launch trail (dev)" dialog over the Timeline (dev-only tape: push heal permission=false optedIn=false; launchDetails no notification). Dismissed. Timeline for Today, Oct 7: Bike, R-CORE Routine, Swim (Planned), net balance −483 kcal (`a02-after-relaunch-front.png`, `a03-timeline-test-account.png`).
- After: user_version 22, same 40 tables (`db-tables-after.txt`, diff empty), row counts unchanged (activities 380, events 5, meal_logs 115, meal_plans 6, plan_meals 17, user_memories 22). Orphan Vana tables kept.
- Console: no DatabaseReset / deleteAndResync / DriftRemoteException / "schema is corrupted" line. (The "Schema validation passed" line is report.debug and did not print either; absence of the failure path is the evidence.)
- Known noise: TrainingPeaks token refresh 400 invalid_grant (x2) and V.O2 TokenRefreshException (degraded) — dead refresh tokens on test@test.com, Sentry ticket 22. Not filed.
- Known noise: `DailyBaselineCalculator.sessionCost: unknown sport "other"` — ruled F4a behaviour (session-demand.md F4a, 2026-09-10) for the R-CORE Routine activity; a log line, not an error.
- Known noise: plugin "uses deprecated application lifecycle events" (AppLinksIos, FlutterWebAuth2, GoogleSignIn) — Flutter UIScene deprecation warnings from third-party plugins.
- NOT noise: four SlowOperation degraded reports (deferred.notifications 10987 ms, deferred.revenuecat 14972 ms, dashboard.activities.background_sync 29200 ms, dashboard.integration_sync 29194 ms) -> Finding.

## Part B (sign-out 11:08:25Z, sign-in 11:09:26Z)

- Settings → Account showed "Signed in with Email / test@test.com" before sign-out (`a04-settings.png`). Sign Out → Welcome. Log In → Log in with email, email typed, password via `cred.mjs type` (10 dots read back).
- Fast tab switch: tabs appeared 5 s after the Log In tap; Events, Learn, Timeline, Events tapped back to back (idb, ~0.75 s per tap, done 3 s after tabs appeared). No error, Events rendered (`b05`). 29-004 not reproduced.
- Timeline, Events (1 upcoming, 4 past), Learn (Mealvana 101 1.1-1.3, Pro Videos/Courses Coming Soon), lesson 1.1 played to 00:07 then Back to Learn, Settings: all rendered, console clean apart from the known TP/V.O2 noise. Events New Event button hidden under the tab bar -> 08-008.
- Offline cold start: `netcut.sh launch` 11:11Z, `on --relaunch` 11:11:31Z (pid 1630), `off` 11:12:49Z; no slow proxy started. OS notification permission prompt appeared first (tapped Don't Allow; -> 08-017), then the dev Launch trail dialog twice (-> 08-007), then the Timeline from the local DB (same three activities, net balance −489). No crash.
- Known noise (offline, expected): SocketException 'Network is unreachable' for education_content, app_config, TrainingPeaks oauth, app.mealvana.io/api/region; reported as degraded (education, startup "Version check failed; using cached result", privacy "Region lookup failed; falling back to device signals", sync, vdot NetworkException). Each falls back and the app carries on; offline was forced by netcut.
- Known noise: TrainingPeaks 400 invalid_grant and V.O2 TokenRefreshException again after sign-in and on later resumes (Sentry ticket 22).
- Ticket 02's meal log on test@test.com did not appear on my Timeline during the run (not a Finding; timing).

## Part C (deep links 11:13Z-11:18Z)

- URL form that worked: `com.milkman.mealvanaendurance:///<path>` (three slashes). The single-slash form `com.milkman.mealvanaendurance:/athlete/feedback` also worked. The two-slash form `com.milkman.mealvanaendurance://athlete/feedback` opened "Page Not Found" (host taken as `athlete`) -> 08-022. The first openurl showed iOS's "Open in Endurance Dev?" confirmation; later ones did not.
- /jade: read-only check first: test@test.com has 5 non-deleted jade_conversations (`db-jade-conversations.txt`, SELECT on dev), so `hasHistory` is true and no opener fires. Console showed no jade-chat request. No AI call was made in the run; no COST spend.
- Results: /pro renders, X dead (08-003); /settings/sport-settings renders light theme, no Back (08-004, 08-005); food-preferences-consolidated renders (Vegetarian, 2 allergies), Back dead (08-003); add-food renders, Back -> Timeline; /athlete/feedback "Coach Messages / No Messages Yet", Back -> Timeline; the five /meal-log/* render, no Back (08-004); /jade renders history, Back -> black screen (08-001); /buy-credits renders balance 49897485 credits, no Back (08-004). Nothing tapped beyond open/Back; no save, no purchase.
- Describe screen's pill shows 99999 while AI Credits shows 49897485: token_pill.dart clamps the display to 99999 (from code), so known, not filed.
- The mobile MCP's tap at 11:14Z again brought its helper to the front (SpringBoard); `simctl launch` returned to the same pid 1630. Environment, not the app.
- Console: no Flutter error line for any dead Back/close tap (go_router pop on an empty stack is silent).

## Close

- Log stream stopped by PID 11:20Z, app terminated. No accounts made. No RevenueCat or DB writes. The only dev DB reads: app_config versions (not saved, shown in expected.md) and jade_conversations ids.
- console.log 21 MB raw, 9 token lines; `console-redacted.log` keeps the Flutter lines only (187 KB), scan clean.
