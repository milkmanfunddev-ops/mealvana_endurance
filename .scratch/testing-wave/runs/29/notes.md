# Ticket 29 run notes

- RUN: w16-20260924T2100Z
- App build commit: 52c68764b2cde49951a27220a8dbdb3a463116f7 (prompt and app-build.json agree)
- Worktree base: c6441d944f45bb80d5d091849c482cc61ee41577
- Simulator: wave-pool-2 42D0EB9B-EFDB-4878-802C-741011EE894B
- Slot claimed 2026-09-24T21:00:20Z
- Account: test@test.com (shared with ticket 18 on wave-pool-1)

## Cold start 1 (signed out, empty database), 21:00:39Z
- Log stream started 21:00:37Z, app launched 21:00:39Z (pid 15526); Welcome showed by 21:00:47Z (01-cold-launch.png): logo, "Get more out of every session.", Build My Plan, "I already have an account", blue wrench dev button.
- Console at launch, console.log lines 657-3658 (Error/Fault level, no Flutter error or exception line):
  - known noise: UIKit "`UIScene` lifecycle will soon be required" Fault and the three Flutter "Plugin … uses deprecated application lifecycle events" lines (AppLinks, FlutterWebAuth2, GoogleSignIn): an iOS 26 deprecation warning for plugins, no effect today.
  - known noise: UIKit UIFocus "FlutterView implements focusItemsInRect", libCoreFSCache "fopen failed / Errors found! Invalidating cache", AudioToolbox "Failed to prepare AudioConverterService: -302", CFBundle "AddInstanceForFactory: No factory registered", CoreHaptics "Invalid audio session ID: 0", CoreMotion/locationd "could not read user … uid/gid" and "file does not exist... clearing": iOS simulator system logs with no app code in them (as run 30's and run 03's notes say).
  - known noise: RevenueCat "WARN: Using a Test Store API key": the dev debug build buys through the Test Store by design (spec, Purchases).
  - known: 07-004 (RevenueCat "No packages could be found for offering with identifier founding" and the three `credits` "unknown duration" WARNs).

## Sign-in and Timeline, 21:01-21:03Z
- 21:01:58Z Log In > Log in with email, test@test.com typed with idb, password with CRED type (02-login-options.png, 03-email-login.png). Signed in by 21:02:00Z; RevenueCat active, expires 2027-09-15T19:39:14Z (console 15827-15863).
- What's New "Shake to tell us what's wrong" sheet, then the TrainingPeaks "Your fuel plan goes to your coach" sheet stacked on first login (04-after-login.png, 05a-tp-sharing-sheet.png): known: 12-008 / 30-010. Tapped Got it, then Keep Sharing (keeps the default, no setting change).
- 21:02:54Z Timeline, Today, September 24 (06-timeline-tab.png): net balance −1,577 "deficit — time to eat", workouts Easy 5:32 AM, Foam Rolling Routine, Rad Device Test Swim, Run 7:28 AM, Patrol H5 ×n; no meal rows although the account has meal logs today: known: 10-001 / 26-001 (meal_logs sync only when Food opens).
- Console at sign-in (lines 15400-18120), all known noise:
  - TrainingPeaks "Token refresh failed (status: 400)", "[INTEGRATION_SYNC] … training_peaks … Token expired. Please reconnect.", vdot "Please reconnect your V.O2 account", FinalSurge "Date-range endpoint unavailable (404)": known noise, the dev admin's integration tokens are expired (runs 03, 12, 14, 16, 19, 30, 31; 03-008).
  - "No distance data available, using default for ActivityType.other/cycling" and "No intensity distribution hints available" (×27): known noise, fuelling-engine defaults for Patrol/other test activities (runs 16, 30).
  - RevenueCat founding/credits WARNs again at login: known: 07-004.
  - Metal "Compilation succeeded with:" warning: known noise, simulator GPU shader compiler.
- Surprise, filed as a Finding: FinalSurge's raw payload for today's "Easy" (05:32:02) and "Run" (07:28:33) carries `WorkoutCompleted: true`, `ActualTime` and `ActualDistanceMeters` (console 15997-16069), which final_surge_transformer.dart and matching.md (FS-2.1) say was "never observed"; both cards still show "Planned".
- Known noise: the red "Show accessibility issues" and blue "Open testing tools" floating buttons are debug-build dev tools (CLAUDE.md: dev ships visible); they sit over the Ask Vana button's corner.

Line numbers in this file from here on (and in the Findings) refer to console-redacted.log; the ones above were taken on console.log before redaction and sit up to 6 lines higher in the redacted file (6 token lines cut; for example the UIScene Fault was line 657, now 655). 05-timeline-tab.png shows the TrainingPeaks sheet right after Got it (same as 05a).

## Food, Events, Learn (cold start 1), 21:03-21:06Z
- 21:03:47Z Food opens on Plan (07-food-tab.png): Vana daily note card, "Sep 20 – Sep 26 · 4 meals", plan be6abf2f. Three of the four dinners show no kcal/macros: filed 29-001 (db-plan-be6abf2f-meals.txt, db-meal-library-ad.txt). Console: only "DailyBaselineCalculator.sessionCost: unknown sport "other"" (known noise: fuelling engine's ruled F4a default for `other` activities, runs 16/24/26/27).
- Food opening made no model call: vana-action `get_home` (16:03:51 local) only, vana_calls rows in window 0.
- Add meal / New meal plan: at rest they sit 10pt under the floating tab bar; scrolled to the end they clear it but for 6pt (12-food-plan-scrolled-bottom.png). Same pattern as known 03-007 (New Event), not refiled.
- 21:05:08Z Meals sub-tab (08-food-meals.png): Recents, My Foods, Assemblies, Recipes. Console clean.
- 21:05:24Z Shopping sub-tab (09-food-shopping.png): "Week of 2026-09-20 · Made Sep 24", 6 items (egg-scramble list 9bdc9556 of archived plan 54a02440): known 19-001 (db-shopping-lists.txt). Raw ISO list name: known 16-007. Console clean. Edge: `kroger` POST 400 at 16:05:28 and 16:09:02 local, 2-4 s after each Shopping open: known 20-008 (edge-requests.txt).
- 21:05:52Z Events (10-events-tab.png): IRONMAN Cozumel upcoming, four past events; New Event under the tab bar: known 03-007. Console clean.
- 21:06:18Z Learn (11-learn-tab.png): Mealvana 101 lessons 1.1/1.2 (plain panels, no thumbnail), Pro Videos Coming Soon / Notify Me, Courses. Console clean.

## Cold start 2 (signed in), 21:07:02Z
- Terminated 21:07:00Z, relaunched 21:07:02Z (pid 18547). iOS notification permission prompt at launch (13-cold2-launch.png): known 03-004 / 31-010; tapped Don't Allow.
- 21:07:28Z Timeline (14-cold2-timeline.png): meals now shown (W13-23 Lunch 404 kcal, W15-27 edited 610 kcal) and net +1,431 surplus, since the Food visit in cold start 1 synced meal_logs (known 10-001).
- Food Plan/Meals/Shopping, Events, Learn, Settings (15-cold2-*.png, 16-cold2-*.png): all render; no new console line.
- Console on cold start 2: same known noise as cold start 1 (UIScene Fault, simulator OS lines, Test Store key, 07-004 WARNs, TrainingPeaks 400 / V.O2 reconnect, `other` sport default), plus RevenueCat "WARN: The appUserID passed to logIn is the same as the one already cached. No action will be taken." (line 25935): known noise, a repeat logIn at cold launch with no effect (run 07 notes).
- 21:09:04Z Settings from the Food gear: Account (test@test.com, Sign Out, Delete Account), Subscription, Profile & Preferences, Appearance, Diet/Allergies/Formulas. Console clean. Back.

## Records (expected.md)
- DB writes on test@test.com since 21:00Z (db-writes-in-window.txt): meal_logs 0, saved_meals 0, vana_conversations 0, vana_messages 0, vana_calls 0. One draft plan 173cebb2 with one plan meal "Sweet rice cake with jam", a shopping list 813df86f and 5 shopping_items, all created 21:09:24-25Z by `vana-action pick_meals` (16:09:25 local). Not mine: my app was on Food > Shopping and then being terminated, and my console has no plan write; it matches ticket 18's Vana browse on wave-pool-1. Expected per the prompt, not a Finding here.
- vana-action `get_plan` 16:05:35, `recent_meals` 16:06:02, `get_meal` 16:08:40 fall at times my app was on Events/Learn: ticket 18's. Mine: get_home 16:02:39 / 16:03:51 / 16:08:26, recent_meals 16:05:12 / 16:08:57, get_shopping_list + list_shopping_lists 16:05:26-27 / 16:08:59-09:01, kroger 400 ×2. No COST spent.
- RevenueCat: no RC read beyond the SDK's own lines; ticket names no RC record, customer active to 2027-09-15T19:39:14Z per the SDK.

## Close
- 21:10:49Z log stream stopped (its own PID), app terminated, slot released. Console token scan: 6 lines in console.log (session token in the shared-preferences dump, IMPROVEMENTS #40); cut into console-redacted.log (33,209 lines), rescan 0, console.log deleted.
- Screens visited: Welcome, Log In (method picker), Log In (email), What's New sheet, TrainingPeaks sharing sheet, Timeline, Food Plan / Meals / Shopping, Events (My Events), Learn, notification prompt, Settings. Ask Vana not tapped: it opens a chat opener (spends COST chat), out of this read-only ticket.
- Findings filed: 29-001 (bug), 29-002 (idea), 29-003..006 (followup-test). Look-around for Welcome, Log In, sheets, Timeline, Food, Settings is already covered by earlier Findings (02-*, 12-008, 30-010, 14-006, 19-*, 20-*, 03-007, 27-*); not refiled.
