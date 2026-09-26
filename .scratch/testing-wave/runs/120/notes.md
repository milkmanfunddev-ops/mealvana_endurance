# Ticket 120 run notes

- RUN: w39-20260926T1013Z. Slot claimed 10:13:37Z (100 also holds one).
- App build commit: 72d3723e7a441d607e5b39de19f8ff6d89cb8cf7 (installed by the lead; not built here).
- Worktree base: 9d9cca3f (checked, main clone mealplanning also at 9d9cca3f).
- Simulator: wave-pool-2 4D32E538-AB6C-4B23-B5D0-94ACEC722481, app data NOT cleared (leftover from the dev simulator).
- 10:14:05Z leftover local rows before launch (local-drift-00-before-launch.txt): 37129f7e (Lee) and
  607f9dd5 (test@test.com), none dirty; local plans (local-plans-00-before-launch.txt) hold the stale
  be6abf2f draft with 5 meals incl. "Brown rice, zucchini & chickpea"; no local 173cebb2.
- 10:14:32Z dev plans for test@test.com (db-00-test-plans-before.txt): week 09-20 confirmed plan is
  9be88811 (1 meal), 50390c90 draft, be6abf2f and 173cebb2 archived.
- 10:15:49Z first launch on the leftover data: signed out, Welcome (01-launch-leftover.png).
- 10:16:33Z 86-008 step 1: Log In with test@test.com and a made-up wrong password (12 characters, typed
  by hand; not a secret). Snackbar "Login failed. Please check your credentials."; form usable, fields
  kept (04-wrong-password-message.png). Console: AuthApiException invalid_credentials, `auth_flow_failed`.
- Password field cleared (16 backspaces), right password typed with CRED (10 dots counted = length 10).
  The screenshot taken after CRED type showed the last typed character in clear (iOS echoes it for a
  moment); deleted, never kept. Known harness hazard: screenshot >2 s after typing.
- 10:17:32.4Z Log In tapped, 10:17:33.2Z tapped again while busy (form dimmed, spinner: login-seq/t02).
  One `email_sign_in_success` (console 05:17:34 local), one navigation: Timeline 10:17:37, no second
  push (login-seq). 86-008 pass.
- 10:17:38Z Food tapped as soon as the tabs showed. login-seq/t07 (10:17:38): Plan tab "Sep 20 - Sep 26 ·
  5 meals" incl. "Brown rice, zucchini & chickpea bowl" = the stale local be6abf2f draft (dev: archived,
  no Brown rice). t08 (10:17:39) on: "1 meal", Sweet rice cake (dev's confirmed 9be88811).
  86-003 fail (08-plan-tab-stale-5-meals-101738.png, 07-login-plan-sequence-sheet.png).
- 10:17:48Z local Drift (local-drift-01-after-login-test.txt): every 37129f7e row gone, incl. its users
  row; only 607f9dd5 rows. 86-001 pass.
- 10:18:31Z local week 09-20 (local-plans-02-settled.txt): 9be88811 confirmed, 50390c90 archived (clean,
  updated_at 10:17:41Z). Dev 10:18:06Z (db-01-test-week0920-plans.txt): 50390c90 draft, created after
  9be88811's confirm. Cause by code reading: `applyServerPlan` (meal_plan_repository.dart:777-790)
  archives the week's other local plans whenever a confirmed plan is applied, on every pull, not only at
  confirm; its doc says it mirrors `confirm_meal_plan`. 86-002 fail.
- 10:18:50Z Plan options -> Previous plans (10-previous-plans.png): two unlabelled "Sep 20 - Sep 26" rows,
  "1 meal" and "5 meals"; no Draft mark. Not opened (opening may apply a plan locally; this run changes no
  plan on test@test.com).
- 10:20:13Z 86-010: Profile & Preferences, tapped "TrainingPeaks · Xuan Huang — tap to use": fields read
  Xuan / Huang / test@test.com; Save Changes -> "Preferences saved successfully". Dev
  (db-02 before: names null; db-03 after): first_name Xuan, last_name Huang, email test@test.com in
  public.users and auth.users. 86-010 pass. test@test.com's name changed from null to Xuan Huang
  (the write the prompt allows; ticket 119's 31-006 taps the same chip).
- 10:20:33Z `COST spend 39 chat 120` (1/5), then `simctl privacy reset all` for the app (app kept running).
- 10:20:54Z Food -> "Ask Vana anything": opens the full-screen chat directly, "Ask me anything", no opener
  and no "Open full screen" step. No vana_calls row for test@test.com since 10:13Z (db-04-vana-calls-test.txt):
  the chat spend bought nothing; the lead can count it back.
- 10:21:06Z Dictate -> Speech Recognition prompt (15-dictate-tap-prompt.png); Don't Allow -> Dictate stays,
  snackbar "Dictation needs Speech Recognition and Microphone access. Turn them on in iOS Settings ->
  Mealvana." (16-after-dont-allow.png). 10:21:25Z second tap: same line, no prompt (17-second-dictate-tap.png).
  86-005 pass. The snackbar covers the composer while shown; the dev build is "Endurance Dev" in iOS
  Settings, not "Mealvana" (dev-only wording mismatch, idea Finding).
- 10:22:01Z `netcut.sh launch` then `on --relaunch`: offline. The notification prompt came on this
  signed-in relaunch (never answered on this copy); Allow.
- 10:23:06Z Timeline -> + Add Food -> Manual: "W39 T120 offline toast", 321 kcal, 45 C, 12 P, 9 F, Save ->
  "Meal logged!". Local meal_logs f85f8d23 needs_upload = 1 (local-dirty-02-offline.txt). Also dirty
  without my doing: integrations 1d5c4700 training_peaks (last_sync_status error, "Token refresh failed:
  no answer", written by the offline relaunch at 10:22:08Z).
- 10:23:59Z Settings -> Sign Out -> Sign out, offline. Welcome with "You're offline, so your unsynced
  changes stay on this phone and sync the next time you sign in." for about 6 s
  (27-signout-offline-line.png, signout-offline-seq/); it covers "I already have an account" meanwhile.
- 10:24:18Z local (local-drift-03-after-offline-signout.txt): 607f9dd5 keeps only meal_logs 1 (dirty),
  integrations 1 (dirty TrainingPeaks), food_preferences 9 (kept: upload failed), users row. Every clean row gone.
- 10:24:33Z netcut off. Account B = lee+e2e-120-20260926T1024Z@rightpathprogramming.com (CRED new),
  auth user e5794d71-5a7c-4b59-8b4f-4e15fc119bb5. Onboarding: Running, PR goal, no pitfalls, Continue past
  Connect training, Personal info (empty, no suggestion from test@test.com's leftover TrainingPeaks row:
  29-B-personal-info.png), Male, defaults. 10:26:36Z Create Account, 10:26:54Z code from Gmail (10:26:38Z
  mail) -> onboarding paywall (30-B-after-verify.png).
- 10:27:08Z local (local-drift-04-after-B-signup.txt): test@test.com's dirty meal log and TrainingPeaks row
  still under 607f9dd5, plus B's users row and onboarding_surveys. 86-007's "stay for that account's next
  sign-in" holds while B is signed in.
- 10:27:18Z dev B (db-05-B-after-signup.txt): auth + public row, gender male, no entitlement. public.users.created_at
  = 00:26:53+00 while auth.users.created_at = 10:26:37Z: local users.created_at holds 05:26:53 (the
  simulator's local wall clock, UTC-5) as a UTC epoch, and the upload shifts it again. Bug filed.
- 10:28:05Z B paywall ⋯ Sign out: confirm reads Settings' text (86-004 wording holds). Welcome. B's rows
  gone, test@test.com's dirty rows stay (local-drift-05-after-B-signout.txt).
- Account C = lee+e2e-120-20260926T1028Zc@rightpathprogramming.com, auth user
  16035302-6752-4549-8d7d-629c3e118d2b. Same onboarding; 10:29:24Z Create Account, code 10:29:25Z mail,
  10:29:45Z onboarding paywall. 10:30:02Z Monthly -> Continue -> Test Store "Test valid purchase"
  (32-, 33-). Console: purchase succeeded mealvana_pro_monthly, active until 10:35:03Z. Timeline.
  CRED updated to paid/monthly.
- 10:30:10Z C signed in: its Timeline shows nothing of test@test.com; local keeps test@test.com's dirty
  meal log under 607f9dd5 (local-drift-06-C-signed-in.txt). 86-001/86-007 cross-account part holds.
- 06-004 (B unpaid, C paid monthly bought 10:30:02Z):
  - 10:30:32Z C Settings sign-out. Console 05:30:32.362 local: `GoRouter: redirecting to /paywall`
    before `[RevenueCatService] logged out` (05:30:32.647). Not seen on screen (no recording of that
    moment); filed as a follow-up.
  - 10:31:02Z B logs in (reverse direction, right after paid C): recording 34-B-login-after-C.mp4,
    frames 36-B-login-after-C-frames.png, B-after-C-seq/. Log In -> spinner -> paywall. The frames from
    3.2 s show the paywall's intro animation (phone-framed demo, "Today, September 21"), never B's tabs
    shell. Console: `logged in`, `active: false`, redirect /paywall. Pass.
  - 10:31:20Z B paywall ⋯ Sign out (console calls it `settings_sign_out_tapped`, same event as Settings).
  - 10:31:43Z C logs in (SDK last held B): recording 35-C-login-after-B.mp4, frames
    37-C-login-after-B-frames.png, C-after-B-seq/. Log In -> spinner -> Timeline, no paywall frame.
    Console: `logged in` then `active: true, expires_at 10:35:03Z`, no /paywall redirect. Pass.
- 10:32:41Z C Settings sign-out (to lapse). RevenueCat 10:33Z: active until 10:35:03Z
  (revenuecat-C-active-1033.json); dev user_entitlements C active_until 10:35:03Z, will_renew true.
- 10:33:15Z test@test.com (admin) logs in: Timeline shows "W39 T120 offline toast". Dev meal_logs
  f85f8d23 created 10:23:07Z, updated 10:33:16Z (db-06-offline-meal-uploaded.txt); local needs_upload 0;
  the dirty TrainingPeaks row uploaded too (its `error` status now on dev: app-made, not a test write).
  86-007 pass.
- 12-007: test@test.com is_admin true, but its Gate opened on the subscription: console 05:33:16
  `active: true, expires_at 2027-09-15` (Grant, dev user_entitlements active_until 2027-09-15), so the
  admin path (only checked with no access, mp-416) was not what opened it (db-07-admin-and-C-entitlements.txt).
  10:34:00Z admin Settings sign-out.
- 10:35:10Z C lapsed in RevenueCat (revenuecat-C-lapsed-1035.json; poller from 10:34:09Z, 20 s steps; seen
  live). CRED C -> lapsed.
- 10:35:34Z lapsed C logs in (SDK last held the admin): recording 39-C-lapsed-login-after-admin.mp4, frames
  40-C-lapsed-login-frames.png, C-lapsed-seq/. Console: `logged in`, `active: false, expires_at 10:35:03Z`,
  redirect /paywall; paywall intro animation, offer, ⋯ = Restore, Redeem code, Manage subscription, Sign
  out, Delete account; no close button. 12-007 pass.
- 10:36:18Z C paywall ⋯ Delete account -> Delete: Welcome; dev auth/public/entitlement rows 0
  (db-08-C-after-delete.txt). CRED C deleted.
- 10:37Z B login: my `idb ui text` dropped the email's last character (".co"), the attempt failed on the
  wrong address (my input, not the app; IMPROVEMENTS #35 again). Fixed the field, logged in -> paywall.
- 10:38:46Z B paywall ⋯ Delete account -> Delete: Welcome; dev auth/public rows 0 (db-09-B-after-delete.txt).
  CRED B deleted. Local database holds no user rows at the end (local-drift-09-end.txt).
- RevenueCat still keeps both deleted customers (known: Finding 02-005), not re-checked.
- 86-012: ticket 103's tests (sync_coordinator_upload_failure_test, pull_keeps_dirty_rows_test,
  edge_cases/network_failure_test): 28 pass (test-86-012-ticket103.txt). Device part not run: no safe way to
  make a server-refused row without a database write.
- Console (console-redacted.log): the IS_ADMIN loop offline (Finding 120-009). Known noise: TrainingPeaks
  token refresh 400 / "Token expired", V.O2 "Please reconnect" on every test@test.com sync (stale sandbox
  connections); the invalid_credentials block (deliberate wrong password); the offline stretch's
  SocketException / RevenueCat network errors / "Pre-logout upload failed" (netcut, expected).
- Edge requests 05:11-05:41 local (edge-requests-1013-1040.txt): all 2xx. analyze-meal-photo, kroger,
  lookup-product, redeem-code, garmin-push are ticket 100's run or Garmin pushes (known noise: not this run).
- Leftover accounts: none (both deleted in-app; both finished sign-up).
- The dirty TrainingPeaks row after the offline relaunch is the case existing Finding 118-002 already covers (known).
