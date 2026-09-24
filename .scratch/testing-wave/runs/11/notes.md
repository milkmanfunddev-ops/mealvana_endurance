# Ticket 11, run w5-20260924T0840Z: notes

Device: pool simulator wave-pool-2 (037DAF3E-…), iOS 26.2, claimed fresh (cloned from the dev
simulator). The dev app was uninstalled before each build, so both installs were clean.

## Setup (not app problems)
- The worktree had no `.env` files. `.env` and `.env.dev.local` were copied from the main clone and
  an empty `.env.prod.local` was written (all gitignored, not committed). Nothing prod was used.
- `run_dev.sh` ran detached with stdin held open (`tail -f /dev/null |`), as ticket 12 found
  necessary; console in `console.log`.
- Driven with idb (describe-all, tap, text, key 42 for backspace) and `simctl io` screenshots.
  The mobile MCP was not used.
- Build lock: taken for the `run_dev.sh` build (released at "Flutter run key commands") and for the
  Patrol build. During the Patrol build the lock was released about a minute early by a wait loop
  that matched the word "error" in a Swift Package Manager warning; it was taken again at once and
  held until "Completed building" (285.6 s). Ticket 05's build lock was not held at that time.
- First typed code: `idb ui text "notaco"` then `"de11"` into the freshly opened sheet arrived as
  `NOTDE11` (three letters lost). It could not be made to happen again (10 letters in one call, one
  at a time, and upper case all arrived whole), so it is put down to idb typing while the sheet's
  autofocus was still settling, not to the upper-case formatter. The code sent was still a made-up
  code and was refused as expected.
- The overlong code was sent twice (03:57:45 and 03:58:08 local): the second time backspace went
  nowhere because the field had lost focus after the answer, so Redeem resent the same 40 characters.
  Both refused the same way.

## What happened, in order (UTC)
- 08:40 slot taken; 08:4x codes read by SELECT (db-codes-before.txt); expected.md written.
- 08:55:42 account A signed up: lee+e2e-11-20260924T0855Z@… (id fa482af4-…), confirmed at creation,
  landed on the paywall. Credentials row added.
- 08:56:16 A's records before any code (db-A-before-codes.txt, revenuecat-A-before-codes.json): as
  expected (no redemptions, no pairing, no entitlement; RC customer with no entitlement).
- ⋯ menu: Restore purchases, Redeem code, Sign out, Delete account (05-paywall-menu.png).
- 08:56:51 made-up code → "We don't recognise that code. Check it and try again.", sheet open.
- 08:57:45 40-character code → same line, sheet open (server 400, app reads as not found).
- 08:58:41 DEVCOACH30 → sheet closed, "Code redeemed. Your coach will see your request to pair.",
  still on the paywall. DB: one redemption, one pending athlete-requested pairing with test@test.com;
  RC: `coach_code=DEVCOACH30`, no entitlement (db-A-after-step3.txt, revenuecat-A-after-step3.json).
- 08:59:19 DEVCOACH30 again → "You've already used that code.", sheet open.
- 08:59:40 `devcoach 30` (lower case, a space; the field upper-cases it to `DEVCOACH 30`) → "You've
  already used that code." The server normalises it to DEVCOACH30.
- 09:00:00 DEVCOACH18 → paired message again; second redemption row; the pairing unchanged; RC
  `coach_code` now DEVCOACH18 (11-002).
- 09:00:23 DEVCOACH18 again → "You've already used that code."
- 09:01:35 ⋯ → Delete account → Delete → welcome. delete-user 200. Footprint empty; both redemption
  rows and the pairing gone (cascade); code counts and the coach's pairings back to
  db-codes-before.txt (db-A-after-delete.txt). RC customer remains with `coach_code` (02-005, known).
- 09:07–09:08 Patrol `redeem_code_flow_test.dart` on a fresh install: passed, 1/1, 49 steps, 0
  skipped (patrol-redeem.log). redeem-code answered 200, 400, 200 (paired), 200 for its account
  a51994ad-…; it deleted itself (delete-user 200); footprint empty (db-P-after-flow.txt,
  edge-logs-patrol.txt).

## Against expected.md
Every step matched expected.md on screen, in the database, in RevenueCat and in the edge logs. The
coach test@test.com's `coaches` row, code redemptions and Grants did not change
(revenuecat-coach-before.json, revenuecat-coach-after.json). Not matched, because it could not be
reached: the coach's-own-code leg (11-001).

## Console lines and what they are
- `[CODES] redeem-code answered 400` with `invalid_input, code is required` twice: the overlong
  code, expected (logged as a warning by design); the wording is 11-003.
- Swift Package Manager and UIScene warnings at build: toolchain noise.
- No error or exception lines from launch to the delete.
- Token scan (`eyJ…`, `Bearer`, `sk_`, `sbp_`) over console.log and patrol-redeem.log: no hits.

## Test runs in the worktree (before the device claim)
- `flutter analyze integration_test/flows/redeem_code_flow_test.dart`: no issues.
- `node --test test/scripts/patrol-targets.test.mjs`: green with the new exclusion.
- `flutter test test/shared/ci_config_contract_test.dart`: 14 pass, 1 fails, and the failure is
  there at the base without this ticket's change (11-011). Without the exclusion the new flow would
  also have failed "M1 and Codemagic dev lanes run the same flow list".

## Look-around, per screen
Welcome, onboarding (Sports, Goals, Pitfalls, Connect training, Personal info, Body composition,
Nutrition settings, Plan reveal, Daily plan preview), Create Your Account, Sign Up with Email,
Paywall and its ⋯ menu, the Redeem code sheet, the Delete account confirm.
- Onboarding, signup, paywall menu and delete paths were already listed by tickets 02, 03 and 04
  and are not written again. 02-001 (prefilled personal info) did not recur on this clean install.
- Redeem code sheet: 11-004 (40-character cap), 11-006 (offline and timeout), 11-007 (double tap,
  close mid-request, reopen, software keyboard), 11-008 (the code kinds dev has no rows for).
- Paywall after a success: 11-005 (the message covers Continue), 11-002 (second code, same coach).
- Beyond the screens: 11-009 (the coach's side of a code pairing), 11-010 (Redeem code from the
  Subscription screen, mp-495).
