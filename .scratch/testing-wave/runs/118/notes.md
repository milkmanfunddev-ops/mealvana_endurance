# Ticket 118 run notes

- RUN: w36-20260926T0031Z. WAVE 36. Slot claimed 2026-09-26T00:31Z.
- App on UDID 25D173F5-228D-4288-8DA3-B03A1BE691BF (wave-pool-1) built from commit
  72d3723e7a441d607e5b39de19f8ff6d89cb8cf7 (dev, IS_INTERNAL=true). Worktree HEAD 006f5ce5.
- 04-006: onboarding walked with Running / race-PR goal / Gut issues / no integration / Wave OneEighteen,
  female, 1992 / metric 173 cm 67 kg / HIGH gut, HEAVY sweat. Back x4 to "What's getting in the way?"
  (screens 14-16), forward x4 to Nutrition (17): every answer kept. Saved profile
  (db-04-006-new-profile.txt): female, 1992-07-01, metric, 5 ft 8 in, 147.71 lb, high, heavy.
- New account lee+e2e-118-20260926T0036Z@rightpathprogramming.com, id bf6eadb8-78ed-4ca5-ab04-c5d854bfa1f0,
  signed up 00:36:53Z, code from Gmail. Paywall shown after verify.
- known noise: public.users.created_at 2026-09-25 14:37+00 vs auth 00:36Z (10 h behind): already
  filed as 121-004.
- 11-005: DEVCOACH30 redeemed 00:38:18Z on the paywall. Message "Code redeemed. Your coach will see your
  request to pair." drawn above the plans tray (28-redeem-success-t1.png). code_redemptions row and a
  pending coach_athlete_relationships row to coach 607f9dd5 (test@test.com) (db-11-005-redeem.txt).
  Its accessibility frame is 0,452 402x388 (down to y 840), so `idb ui describe-point` on Continue
  returns the message; a real tap on Continue during a Restore message (00:38:58Z) did open the Test
  Store purchase sheet (30-continue-tapped-during-message.png), cancelled.
- 08-002: Redeem a code sheet (from paywall ⋯) lists `Button|Close` at 338,599 40x40 (27-redeem-sheet-paywall.png).
- New account deleted through the paywall ⋯ → Delete account at 00:39:45Z; auth, users and the pending
  pairing rows all gone (db-new-account-after-delete.txt). Credential row set to deleted.
- Dev testing-tools wrench (344,732 48x48) sits on the right end of Welcome's Build My Plan
  (01-welcome-wrench-over-build-my-plan.png; describe-point 360,757 answers "Open testing tools"),
  on the paywall's Monthly card and the top right of Continue (25-after-verify.png), and on the Redeem
  sheet's field and Redeem button (27). Filed as a new bug.
- test@test.com signed in 00:40:44Z. Sign-in sync 00:40:46-52Z: Final Surge success, TrainingPeaks refresh 400
  twice → requires_reauth "Token refresh refused. Please reconnect." (console still says "Token expired.
  Please reconnect."), V.O2 requires_reauth. Timeline showed no notice; What's New sheet opened (Got it under
  the wrench, 118-001). Connected Apps: Reconnect on TrainingPeaks and V.O2 (41).
- 12-002: wrench 344,732 48×48, Ask Vana 336,790 52×52, Send 342,778 44×44: centre tap on Ask Vana opened Vana
  at 00:46Z after `COST spend 36 chat 118` (00:45:57Z). One vana_calls row 6f1f833d (00:46:05Z), no other model
  call in the run.
- 18-005 / Browse: Vana conversation ec37f880-05e9-460f-8af0-cbb5e4403260 (general, "Quick question"). Browse
  opened by deep link `/vana/browse?c=ec37f880-…` (no model call). Picked Egg & Veggie Scramble (Recents) at
  00:48:03Z → new draft meal_plans 50390c90-9253-491d-9658-8fa846c58368 with plan_meals 37e594bd. The draft
  offers no Remove (second tap on the tick does nothing; the chat's plan bar reads 0 meals; Review plan does
  nothing): the pick was NOT removed; the draft is unconfirmed (118-004).
- 64-001 network leg: netcut launch 00:52:17Z, cut with relaunch 00:52:21Z, off 00:54:05Z, online relaunch
  00:56:31Z. During the cut: 1397 "[IS_ADMIN] is_admin read failed" lines (118-003). Local TrainingPeaks row went
  to `error` with the raw SocketException text, needs_upload=1; Connected Apps showed Sync Now and the write
  switch (118-002). Server stayed requires_reauth (updated 00:45:15Z and 00:54:28Z and 00:55:25Z by other
  sign-ins, probably ticket 119's). Online relaunch put the local row back to requires_reauth (00:56:39Z).
- known noise: RevenueCat "No packages could be found for offering with identifier founding" (07-004);
  "Date-range endpoint unavailable (404)" (Final Surge, 30-001); CoreHaptics/AVSystemController/CFBundle lines
  (simulator); plugin UIScene lifecycle deprecation notices (framework, no behaviour).
- known noise: Log a Meal's 253% chip (112-022).
- garmin-backfill 502 at 00:42:32Z (Garmin: Token is not active, rate limit): 118-016.
- The simulator had a hardware keyboard connected: `idb ui text` hides the on-screen keyboard; 23-001 was typed
  with the mobile MCP, which brought the software keyboard up.
- Paywall ⋯ menu for a never-paid account lists Restore purchases, Redeem code, Sign out, Delete account (no
  Manage): known noise, mp-494 shows Manage only for an account with a subscription (paywallHasSubscriptionProvider).
- Vana opener content: 118-008.
- End state: integrations TrainingPeaks and V.O2 requires_reauth, Final Surge and Garmin success (db-final.txt).
- Ended 01:00:24Z: log stream stopped, app terminated, slot released. Chat spend 1/5 used.
