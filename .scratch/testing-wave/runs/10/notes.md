# Ticket 10, run w8-20260924T1418Z: notes

Device: wave-pool-1 (3BE82149-7D70-4664-B749-E637D34BE542). App built by the wave lead from
`433514bcfedc0100ce7d76416de44fb53fcf6b01` (main clone's `.scratch/testing-wave/app-build.json`,
built 14:17:19Z; the worktree's copy at the base commit still says `null`, known noise: the lead
writes it after the worktrees are cut). Not built here.

## Setup
- Slot claimed 14:18:03Z.
- 14:18:32 before-reads: db-D-before.txt, revenuecat-D-before.json. Match expected.md (row
  12:59:36.902, RevenueCat subscription expired / will_not_renew, no active entitlement).

## What happened, in order (UTC)
- 14:18:54 `simctl launch` started the app (pid 55368) but left SpringBoard in front; the mobile
  MCP's launch brought it forward. Known noise: a harness quirk, not the app (IMPROVEMENTS).
- 14:19 welcome (signed out) → I already have an account → Log in with email. Email typed with the
  MCP, password with `idb ui text` from a variable (never printed). No screenshot kept of the
  filled form (iOS shows the last typed character).
- Console at launch, signed out: `customer info updated {active: true, expires_at: 2027-09-15…}`
  (the copied dev simulator's last account) and again at 14:20:10 just before `logged in` switched
  to D (`active: false, expires_at 12:56:29`). Known: 03-002. The router went to /paywall; no app
  frame seen.
- 14:20:12 `/main` → redirect `/paywall`; the opening clip (app in use) plays, then the
  full-screen paywall. 14:20:32 screenshot 01: no close or back control. 14:20:41 ⋯ menu: Restore
  purchases, Redeem code, Manage subscription, Sign out, Delete account (02). Matches mp-280.
- 14:20:5x Monthly → Continue → Test Store sheet (03, "mealvana_pro_monthly", $9.95).
- **14:21:00 "Test valid purchase"** (console `purchase started` 09:20:52 local after the
  RevenueCat logIn; `customer info updated {active: true, expires_at 14:26:00}` and redirect to
  `/main` at 14:21:01.5Z). 14:21:04 Timeline, snackbar "Welcome to Mealvana Endurance!" (04, 10-002).
- 14:21:14 RevenueCat: `pro` (entla441faaeb4) expires 1790259960866 = 14:26:00.866Z; new
  subscription subTstc4654aa… `test_store`, active, will_renew, starts 14:21:00.866Z. The old one
  stays `expired`. (revenuecat-D-after-purchase.json)
- 14:21:20 row: `active_until 14:26:00.866`, `NORMAL`, `event_at 14:21:01.156` — **equal to
  RevenueCat to the millisecond** (db-D-after-purchase.txt). Same single row updated (count 1).
- 14:21:27 data: users 1, meal_plans 1 (d297659d confirmed), plan_meals 6, meal_logs 1
  (346a6d5b), shopping_lists 1, shopping_items 21, vana_conversations 1, vana_messages 3,
  user_entitlements 1 — unchanged from before (db-D-data-after-purchase.txt, db-D-meal-log.txt).
- 14:21:04–14:21:51 the timeline for today had no meal card; pull-down and Meals filter: still
  none (04, 05, 06). → 10-001.
- 14:22:03 Food → Plan: "Sep 20 – Sep 26 · 6 meals", the six plan meals (07). The Vana day note
  said "Looking at your day…" then, at 14:24, a real note (10). 14:22:13 Shopping: "Week of
  2026-09-20, Confirmed Sep 24, 2026", 21 items, 18 servings · 6 meals (08).
- 14:21:59 console: `meal_logs_last_sync` first written (with meal_plans, saved_meals,
  user_memories), when Food opened. 14:22:40 Timeline: EGGS AND W… 7:32 AM, 278 kcal (09).
- 14:24:40 Settings → Subscription: "Subscribed, Renews on September 24, 2026", Manage
  subscription, Redeem code (11). Same as ticket 09's screen; nothing new.
- 14:26:32 / 14:27:32 poll (poll-after-purchase.log): RevenueCat no active entitlement, row still
  14:26:00.866 (the 2–3 minute gap after a Test Store period end, known 06-002). 14:28:33:
  RENEWAL landed (row `event_at 14:27:51.547`), both say 14:31:00.866. Equal again.
- 14:28:48 Settings → Delete Account → dialog "This will permanently delete your account and all
  associated data…" (12) → Delete 14:28:52 → welcome screen (13).
- 14:29:07 dev: auth.users 0, users 0, and every data table 0 for D, user_entitlements 0
  (db-D-after-delete.txt). 14:29:08 RevenueCat: customer d88b5741 still there with `pro` active
  to 14:31:00.866 (revenuecat-D-after-delete.json). Known: 02-004 (store subscription keeps
  renewing after delete) and 02-005 (RevenueCat keeps the customer). No new Finding.
- Credentials row set to `deleted` at 14:29Z.

## Release
- Log stream stopped and app terminated 14:29:26Z; slot released 14:29:26Z. Simulator left for
  the wave lead.
- Token scan hit 4 lines, one the `sb-…-auth-token` User Defaults dump with the session's access
  token (the other 3 are BaseBoard machport lines, a harmless pattern match).
  console.log was deleted; console-excerpts.log keeps the Flutter router / RevenueCat /
  Subscription / analytics lines and the `*_last_sync` settings that 10-001 cites, with every
  token, device id and session id line removed. Password string: 0 hits in runs/10.
- Cost: no `COST spend` (no new Vana plan, no AI logging call). The Food tab's Vana day note is an
  automatic call the app made once Pro was back; not an agent-made plan or log.

## Console lines and what they are
- No Flutter error or exception lines in the whole run.
- `customer info updated {active: true, expires_at 2027-09-15}` while signed out: 03-002.
- On delete every `flutter.*_last_sync` key was set to nil (excerpt lines 45-74): as expected.

## Look-around, per screen
- Welcome / Log In / Email login: covered by tickets 02–07's Findings; nothing new tried.
- Paywall (lapsed) and its ⋯ menu, Test Store sheet: 10-003 (Annual, failed purchase, Cancel,
  a tap during the clip). Sign out / offline from the paywall: 09-011.
- Timeline right after resubscribing: 10-001 (bug), 10-002 (idea), 10-004 (cold relaunch, day
  change, workouts, net balance).
- Food → Plan / Shopping after resubscribing: the plan and list were all there; 10-005 covers the
  same-device and second-lapse paths. Plan-tab Vana note repeating itself: 09-002 (not seen repeat
  this time).
- Settings → Subscription: 09-001, 07-008, 07-011.
- Delete account from Settings while Pro is live: 02-004, 02-005, 02-016.

## Criteria against the run
- Slot taken 14:18:03 and released 14:29:26; console saved (as a token-free excerpt); look-around
  on every screen visited; Findings 10-001..10-005; nothing fixed. Met.
- Uses ticket 09's lapsed account D. Met.
- After buying: the Gate opened (14:21:01); RevenueCat and the row agreed on 14:26:00.866 at
  14:21:14/20 and again on 14:31:00.866 after the first renewal; plan d297659d (6 meals, 21-item
  list) on screen at 14:22:03 and in the DB; meal log 346a6d5b in the DB at 14:21:27 and on the
  timeline from 14:22:40, but not before Food was opened (10-001). Met, with 10-001.
- Deleted in the app at 14:28:52, credentials row `deleted`. Met.
