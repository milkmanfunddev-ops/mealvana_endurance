# Ticket 86 run notes

- RUN: w25-20260925T1324Z. Slot claimed 13:24:01Z.
- App build commit: 5e05f8a6393d73c1cf5306fe5f271c05bc24d2f2 (installed by the lead; not built here).
- Worktree base: b07959a7 (checked).
- Simulator: wave-pool-1 F4B54D93-BFDB-48A4-9354-840C9BB55202, app data NOT cleared (leftover from the dev simulator).
- Leftover local rows before launch: runs/86/local-drift-00-before-launch.txt. Two users' rows
  (37129f7e Lee, 607f9dd5 test@test.com); test@test.com's rows include a TrainingPeaks integration
  named "Xuan Huang" with an email (the 02-001 source), plus FinalSurge, Garmin, VDOT; Lee's has Runna.
- 13:25:15Z first launch on the leftover data, signed out, Welcome (01-launch-leftover.png). No notification
  prompt showed (the simulator is a copy of the dev simulator, which has answered it before; 03-004 needs a
  never-answered install). Console line 6496: `[SubscriptionService] customer info updated {active: true,
  expires_at: 2027-09-15T19:39:14.000Z}` on Welcome with nobody signed in, before `[RevenueCatService]
  configured`. This state was left by whatever build signed the dev simulator out (not known to this run), so
  03-002 is judged later, after a sign-out done by this build.
- 13:26:18Z Log In as test@test.com (email). Screenshots every ~0.6 s: login-seq/, sheet 02-login-sequence-sheet.png.
  The form stays dimmed with the spinner t01-t07, t08 is the tabs shell. No enabled form in between (12-003).
- 13:26:42Z local Drift after login (local-drift-01-after-login-test.txt): Lee's 37129f7e rows all still there
  (activities 58, meal_logs 24, meal_plans 4, plan_meals 10, events 3, carb_loading_plans 3,
  food_preferences 46, integrations 1 Runna). Signing in as another account clears nothing; ticket 33 clears
  only on sign-out, so rows left by a sign-out made before the fix stay for good (14-004, filed).
- 13:26:42Z the local copy also held test@test.com's be6abf2f as `draft` with 5 meals incl. "Brown rice,
  zucchini & chickpea bowl" (local-plans-after-login.txt), i.e. the 14-003 stray is the account's own stale
  local row, not another account's. By 13:27:05Z the Plan tab showed "Sep 20 - Sep 26 · 4 meals" without it
  (04-food-tab.png), and by 13:27:42Z the local row was gone and be6abf2f `confirmed` with 4.
- 13:27:42Z local 173cebb2 (this week) reads `archived`, dev reads `draft` (local-plans-week0920-1328.txt,
  db-test-week0920-plans.txt). Filed as a follow-up.
- 13:28:07Z cold relaunch signed in: `logIn waiting for configure` x2, `configured`, `logIn skipped: already
  identified` x2. No "SDK not configured" (09-013). Known noise on every test@test.com launch: TrainingPeaks
  token refresh 400 and V.O2 "Please reconnect" (the test account's stale sandbox connections), FinalSurge debug dump.
- 13:28:10Z the iOS notification prompt appeared over the timeline on the signed-in relaunch
  (06-notification-prompt-after-signed-in-relaunch.png): so the permission had NOT been answered on this
  simulator, and the first launch at 13:25 signed out on Welcome showed no prompt. That is the 03-004 retest
  (a never-answered install launched signed out). Allow was tapped.
- 13:28:45Z Settings delete confirm reads "Delete account?" / "This permanently deletes your account and all of
  its data. This cannot be undone." Cancel. Sign-out dialog "Sign out?" / "You'll need to sign in again to use
  Mealvana. Your data stays with your account." (09-, 10-settings-*.png).
- 13:29:04Z Sign out from Settings: `customer info updated {active: false}`, `[RevenueCatService] logged out`,
  Welcome. No "Pro entitlement clear failed". Local rows of 607f9dd5 all gone (local-drift-02-...).
- 13:29:25Z relaunch signed out: first status `active: false`, every RevenueCat request is for
  `$RCAnonymousID:b5237a08…` (03-002).
- 13:29:50Z account A = lee+e2e-86-20260925T1329Z@rightpathprogramming.com (CRED new), user 4dbde602-69d1-48cb-b984-2ca707702256.
  Onboarding: Running, PR goal, no pitfalls, "I don't use training plan apps" (13:30:45Z). Connect training
  listed Runna as "Connect" although Lee's leftover Runna row is local (correct: not this session's).
  Personal info empty, no TrainingPeaks tag; no Riverpod assertion in the console (14-personal-info.png).
  Male, 150 lb, gut high, sweat heavy. Plan reveal "We built your plan." (no name); long-run pencil, slider
  70 -> 85 (`plan_target_edited {from: 70, to: 85}`). Plan reveal still shows "Connect now" (ticket 94 item 2,
  known leftover, not filed). Daily plan preview: no Connect with Garmin card (18-daily-preview.png).
- 13:32:54Z Create Account -> Verify your email. 13:33:17Z code 123456 -> "That code is wrong or has expired.
  Check the digits, or tap Resend for a new one." (21-wrong-code.png). The six digits did not submit on their
  own (ticket 94 item 3, known leftover).
- 13:33:44Z real code (Gmail, 13:32:55Z mail). First status after `email_verification_completed` is `active:
  false`; never `active: true`; `[RevenueCatService] logged in` then `/paywall?onboarding=1`.
- 13:34:12Z dev: users.email = signup address, first/last name null, gut high, sweat heavy,
  nutrition_target_overrides `{"duringRun": {"carbRateGPerH": 85}, "duringCycling": {}}`; no user_entitlements
  row (db-A-after-signup.txt). RevenueCat customer exists, no active entitlement (revenuecat-A-*.json).
- Paywall first frame showed a phone-mockup animation of a plan (22-onboarding-paywall.png), then the offer
  ($69.00/yr, $9.95/mo). Prices and the ⋯ menu (Restore, Redeem, Sign out, Delete; no Manage for a never-paid
  account) are ticket 87's area; not judged here.
- 13:34:40Z paywall ⋯ Delete account confirm reads exactly as Settings' (24-paywall-delete-confirm.png); Cancel.
- 13:35:13Z paywall ⋯ Sign out: `[RevenueCatService] logged out`, Welcome, no "Pro entitlement clear failed"
  (count in the whole console: 0). A's local rows gone. The paywall's sign-out text differs from Settings'
  (Finding 86-004).
- 13:35:43Z second login as test@test.com; Food at 13:35:51Z (8 s): 4 meals, correct. No A rows locally.
- 13:36:20Z Settings > Profile & Preferences: title "Profile & Preferences", Back at top (28-profile-preferences.png).
- 13:36:40Z `COST spend 25 chat 86` (1/5), then `simctl privacy reset all` for the app (so Speech Recognition
  is unanswered). 13:36:54Z Ask Vana: opener (one vana_calls row, vana.opener.general, haiku, $0.021,
  db-vana-calls-test.txt), no permission prompt. Open full screen: Dictate button, still no prompt.
  13:37:32Z tap Dictate -> Speech Recognition prompt; Don't Allow; Dictate disappears (Finding 86-005).
- 13:38:22Z Settings sign-out of test@test.com again: clean. 13:38:53Z log in as A -> paywall (active false).
  13:39:08Z ⋯ Delete account -> Delete: Welcome, RevenueCat logged out; dev public.users and auth.users have no
  row (db-A-after-delete.txt); RevenueCat still has the customer with no entitlement (known: Finding 02-005).
- Edge requests 08:22-08:41 local (edge-requests-1324-1344.txt): this run's are sync-all-data, ensure-credits,
  vana-action, vana-chat 08:37:04, calculate-daily-macros, delete-user 08:39:09 (all 200). redeem-code 400s at
  08:30:10, redeem-code 200s, revenuecat-webhook, delete-user 08:32:26 and the kroger calls are ticket 87's
  run (known noise: the other run's codes and account, per the prompt).
- Console errors, all known noise: TrainingPeaks token refresh 400 / "Token expired" and V.O2 "Please
  reconnect" on every test@test.com sync (the test account's stale sandbox connections); the
  InvalidVerificationCodeException block is the deliberate wrong code.
- Look-around follow-ups filed: 86-007 (sign-out offline, local wipe vs unsynced rows), 86-008 (Log In),
  86-009 (Verify your email), 86-010 (Profile & Preferences suggestion), 86-011 (paywall delete offline).
