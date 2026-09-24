# Ticket 09, run w7-20260924T1219Z: notes

Device: pool simulator wave-pool-2 (4E0B6999-…), iOS 26.2. The app was uninstalled before the build
and again before the Patrol run.

## Build under test
Worktree base `43261837` (mealplanning). Paywall tickets in the build, from `git log --grep paywall`:
waves 1–10 closed, so 01, 02, 03, 08 (wave 1); 04, 06, 07, 14 (2); 09, 11, 15 (3); 12, 16 (4);
17 (5); 18 (6); 19, 21 (7); 20 (8, "the write guard, refused-write error, PlanEndedHost and
plan-ended bar come out"); 05 (9); 13 (10). Ticket 20 is in, so the run was allowed.

## Setup (not app problems)
- The worktree had no `.env*` files. `.env.dev.local` was copied from the main clone. The main
  clone's `.env` holds the prod Supabase URL, so it was not copied: `.env` and `.env.prod.local`
  were created empty (pubspec bundles all three; `main_dev.dart` loads only `.env.dev.local`).
- Driven with idb (taps from the accessibility tree, `idb ui text` in 8-character chunks for the
  address) and `simctl io` screenshots. The mobile MCP was not tried (it cannot drive pool devices).
- Locks: slot 12:19:08Z. Simulator claimed 12:24Z. Build lock 12:24:11Z → 12:28:18Z (released at
  "Flutter run key commands"; "Xcode build done 164.4s"). Patrol build under the lock
  13:04:19Z → 13:08:0xZ (released at "Completed building", 197.6 s). Simulator, build and slot
  released at 13:41:13Z.
- `timeout` is not installed on this Mac, so the first Patrol attempt died at once with exit 127
  (command not found; nothing ran, its log was deleted). The run used
  `perl -e 'alarm shift; exec @ARGV' 3300 patrol test …` instead. Known noise: a missing shell
  tool, not the app; the IMPROVEMENTS entry on Patrol timeouts should say which command to use.
- Cost: `cost.mjs spend 7 plan 09` once (wave 7 plan 1/3). The meal was logged with Common →
  quick add, which makes no AI call, so no logging spend. Two `vana-chat` calls were made in all,
  both refused with 403 before the model: one by hand (the criterion) and one inside the Patrol flow.

## Cancel or lapse
The Test Store could not be cancelled: Settings → Subscription → Manage subscription opened a blank
Safari Start Page (09-001), and the Test Store sheet has no cancel. So **the Test Store monthly's
own lapse stood in for the cancellation**, as the ticket allows. No Grant was used. RevenueCat
turned auto-renew off by itself at the fourth renewal (12:51Z, `will_not_renew`), which gave a
cancelled-but-still-paid window from 12:51:39Z to 12:56:29.761Z, then the end.

## What happened, in order (UTC)
- 12:28 app on welcome. 12:28–12:30 onboarding with ticket 05's answers (Running, performance,
  pitfalls skipped, no training app, female, defaults, gut high, sweat heavy, plan reveal, daily
  preview, Save My Plan).
- 12:30:26 account D signed up: `lee+e2e-09-20260924T1229Z@…` (stored lowercased), id
  d88b5741-f2f2-455c-b2dc-c346d904b01b, confirmed at creation. Onboarding paywall. Row added to the
  credentials file at once.
- 12:31:07/13 before-checks: RevenueCat customer, no active entitlement, no subscription; `users` 1
  (onboarded), `user_entitlements` 0. As expected.md says.
- 12:31:29 Monthly → Continue → Test Store sheet → "Test valid purchase". The What's New sheet over
  the timeline (known, 05-004 / 12-008; the paywall window was not filmed this run).
- 12:31:58 RevenueCat `pro` until 12:36:29.761, `test_store`, `sandbox`, active, `will_renew`. Row
  `active_until 12:36:29.761`, `NORMAL`, `event_at 12:31:29.947`. **Equal.** Webhook
  INITIAL_PURCHASE logged 12:31:30.8Z.
- 12:32:40 one meal logged: + Add Food → Common → Eggs + toast → Breakfast → Log it ("Meal
  logged!"; meal_logs 346a6d5b).
- 12:33:09 Food → New meal plan. iOS asked for Speech Recognition first (09-004), Don't Allow.
  12:33:46 Just decide for me → "Your plan · 6 meals" → Review plan → 12:34:36 Confirm plan.
  Plan d297659d `confirmed`, 6 plan meals, 1 shopping list with 21 items, 1 conversation with 3
  messages (db-D-after-plan-and-log.txt). The Plan tab's Vana note repeats itself (09-002); one
  dish shows a dev test photo (09-003).
- 12:34:54 / 12:35:45 before the end, app open: RevenueCat and the row both 12:36:29.761.
- 12:35:26 Settings → Subscription ("Subscribed, Renews on September 24, 2026") → Manage
  subscription → blank Safari (09-001). Back to the app, then the Timeline, left in the foreground.
- 12:36–13:20 a background poll read RevenueCat and the row every minute (poll-lapse.log). Each
  period end was followed by 2–3 minutes with no active entitlement in RevenueCat and the row in
  the past, until the RENEWAL landed (12:39:31, 12:43:34, 12:47:37, 12:51:37). Known, 06-002.
  The app fetched nothing in that time (no `customer info` line in the console from 12:31 to
  13:01), so on this run renewals were not driven by app fetches; that answers 07-003's open
  question the way the wave lead's review note suspected.
- 12:51:47 the fourth renewal carried `will_not_renew`; RevenueCat and the row both said
  12:56:29.761. The app stayed open. No CANCELLATION event came (09-012).
- **12:56:29.761 the end.** 12:56:51 RevenueCat: no active entitlement. The app, left in the
  foreground, stayed on the timeline (21-foreground-after-end-1258Z.png at 12:58:10,
  22-foreground-1302Z.png just before 13:01:29). Known, 05-005 (mp-457 does not say how soon a
  running app must notice); no new Finding. Clock gaps: no wait here was longer than planned, so
  the end was seen live, by poll, to the minute.
- 12:59:36.902 EXPIRATION webhook moved the row's `active_until` from 12:56:29.761 to 12:59:36.902
  (09-009, as mp-609 clause 4 says).
- 13:01:29 Home, 13:01:33 back to the app (resume): the SDK logged `customer info updated
  {active: false, expires_at: 12:56:29}` and the router redirected to `/paywall`. The full-screen
  paywall, no close or back control; a left-edge back swipe did nothing; ⋯ showed Restore
  purchases, Redeem code, Manage subscription, Sign out, Delete account
  (24-lapsed-paywall-resume.png, 25-lapsed-paywall-menu.png). No sheet, no plan-ended bar, no
  read-only app behind it. **No SSOT-conflict with mp-457 or mp-280 was seen.**
- 13:02:21 one `vana-chat` call with D's own access token (password sign-in by API): **HTTP 403
  `{"error":"pro_required"}`** (api-vana-chat-lapsed.txt).
- 13:02:27 terminate; 13:02:36 cold launch: splash, spinner, then the paywall (its opening clip of
  the app in use runs first); the router went `/` → `/main` → `/paywall` in 4 ms with no app frame
  on screen (26-cold-relaunch-frames.png). The notification prompt came up over it (known,
  03-004), Don't Allow. Signed in; the same ⋯ menu (27-…, 28-…).
- 13:03:23/24 after the lapse: RevenueCat no active entitlement (the subscription record still
  says `active`, 09-010); row `active_until 12:59:36.902`. **D's data is all still there**: users 1,
  meal_plans 1 (confirmed), plan_meals 6, meal_logs 1, shopping_lists 1 (21 items),
  vana_conversations 1 (3 messages), user_entitlements 1 (db-D-data-after-lapse.txt).
- Account D is kept, Lapsed, for ticket 10 and marked so in the credentials file. Not deleted.

## Criteria against the run
- Before the end: app open; RevenueCat expiry equals `active_until` at 12:31:58, 12:34:54,
  12:35:45 and through every renewal once it landed, including the cancelled-but-paid window
  (12:51–12:56). The 2–3 minute gaps after each period end are 06-002.
- After the end: signed in; full-screen paywall on resume and on cold relaunch; no close; the five
  menu items; the server refused the AI call. The row and RevenueCat disagree on the end date by
  3 min 7 s after the EXPIRATION (09-009).
- Data kept, by SQL.

## Console lines and what they are
- console.log (flutter run, 12:24–13:02:27Z): Swift Package Manager fetch lines and UIScene
  warnings at build are toolchain noise. No error or exception lines. `[RevenueCatService] logged
  in` appears several times around signup and purchase; same account, no visible effect (noted in
  05's notes; 03-002 covers SDK identity). Ends with "Lost connection to device" from the
  deliberate terminate.
- console-relaunch-oslog.log (unified log after the cold launch): `logIn skipped: SDK not
  configured` twice before `configured` (startup ordering, as ticket 06 noted, no effect). No error
  or exception lines.
- Token scan (`eyJ…`, `Bearer `, `sk_`, `sbp_`, and the account's password prefix) over every file
  in runs/09: no hits, so console.log is committed whole.

## Look-around, per screen
Onboarding, Create Your Account, Sign Up with Email, the onboarding paywall and the Test Store
sheet were walked as in tickets 04–06 and are covered by their Findings. New this run:
- Log a Meal (Common, quick-add sheet): 09-005.
- Food: Vana new-plan chat: 09-004 (permission), 09-008 (Back mid-generation).
- Review plan: 09-006. Food Plan tab after confirm: 09-002, 09-003, 09-007.
- Settings → Subscription (paid, Test Store): 09-001. Other paths there are 07-008 and 07-011.
- Timeline in the foreground across the end: 05-005 (known).
- Paywall (lapsed) and its ⋯ menu: 09-011 (sign out and back in, offline relaunch). Manage,
  Restore and Redeem for a lapsed Test Store account are 05-008; resubscribing is ticket 10.

## Patrol: integration_test/flows/cancellation_flow_test.dart
Written by this run, listed in `runner_exclusions.json` as clean-install and in
`integration_test/README.md`. `flutter analyze` on the file is clean;
`node --test test/scripts/patrol-targets.test.mjs` passes 11/11. It signs up
`lee+e2e-cancel-<millis>`, buys Monthly, checks the Gate opens and the row is in the future, waits
in the foreground until the row's `active_until` has stayed in the past for 6 minutes (cap 38),
presses Home and reopens the app, checks the full-screen paywall (no close/back, not poppable),
the session is still the account's, the five ⋯ items, one `vana-chat` 403 `pro_required`, the
`users` and Entitlement rows kept, then deletes itself from the paywall menu.
- Run 1 (13:04Z): exit 127, `timeout` not found; nothing ran (see Setup).
- Run 2 (13:04–13:41Z): **passed 1/1, 42 steps, 1952 s**. Account d3ac6e0c bought at ~13:08:57Z,
  lapsed after 13:33:57Z, and deleted itself; auth, users and entitlement rows 0 afterwards and no
  `lee+e2e-cancel-*` account left on dev (db-P-after-flow.txt).
