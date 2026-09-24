# Ticket 11, run w5-20260924T0840Z: expected records

Written before the app was touched. Dev project `vlmtsdzpnjnavdgytcmi` and the RevenueCat project
only. Decisions: mp-458 (codes are ours; coach's own code = coach + 30 days, athlete + coach code =
pending pairing, plain reasons), mp-535 (once per account, only a coach code pairs, never spent when
RevenueCat fails), mp-598 (sheet stays open on a refusal, closes with a message on success), mp-631
(this ticket's card).

## What the dev codes are (db-codes-before.txt, read by SELECT before the run)

| code | type | owner | perk_days | max_redemptions | window | redeemed by before the run |
|---|---|---|---|---|---|---|
| DEVCOACH30 | coach | test@test.com (607f9dd5-…) | 30 | none | from 2026-09-22, no end | test@test.com, 2026-09-22 |
| DEVCOACH18 | coach | test@test.com (607f9dd5-…) | 30 | none | from 2026-09-23, no end | test@test.com, 2026-09-23 |

Both codes belong to the dev admin, who is already an approved coach and has already redeemed both.
No other codes exist on dev. The owner has 7 active pairings (6 requested by coach, 1 by athlete)
and no pending one.

So for a new athlete both codes are "an athlete entering a coach code": each gives a pending
pairing with test@test.com and no days of Pro. **The "coach's own code" leg cannot be reached with
a fresh account** (the owner is fixed on the row and the run may not write to `codes`); that is
written as a Finding, not faked.

## Account A: `lee+e2e-11-<UTC time>@rightpathprogramming.com`, driven by hand

Signs up through onboarding, lands on the full-screen paywall (mp-457), with Redeem code in the ⋯
menu (mp-494). Then, in this order, from ⋯ → Redeem code:

| # | typed | server answer | screen | records after the step |
|---|---|---|---|---|
| 1 | a made-up code, `NOTACODE11` | 200 `{ok:false, reason:not_found}` | "We don't recognise that code. Check it and try again." under the field; sheet stays open | nothing new |
| 2 | an overlong code, 40 characters (the field's own cap; 45 typed to see the cap) | 400 `invalid_input` (over 32), read by the app as not_found | the same not-found line; sheet stays open | nothing new |
| 3 | `DEVCOACH30` | 200 `{ok:true, kind:paired, coach_user_id:607f9dd5-…}` | sheet closes; bottom message "Code redeemed. Your coach will see your request to pair."; still on the paywall (no Pro) | `code_redemptions` (DEVCOACH30, A); `coach_athlete_relationships` coach 607f9dd5 / athlete A, `status=pending`, `requested_by=athlete`; RevenueCat attribute `coach_code=DEVCOACH30`; no Grant |
| 4 | `DEVCOACH30` again | 200 `{ok:false, reason:already_redeemed}` | "You've already used that code."; sheet stays open | nothing new |
| 5 | `devcoach 30` (lower case, a space) | the same code after normalising: already_redeemed | "You've already used that code." | nothing new |
| 6 | `DEVCOACH18` | 200 `{ok:true, kind:paired}` (a different code, so a new claim; the pairing is already pending and is left as is) | sheet closes, the paired message | `code_redemptions` (DEVCOACH18, A); still one pairing row, pending; `coach_code` becomes `DEVCOACH18` |
| 7 | `DEVCOACH18` again | already_redeemed | "You've already used that code." | nothing new |

After step 7, for A:
- Dev database: `code_redemptions` exactly 2 rows (DEVCOACH30, DEVCOACH18); `coach_athlete_relationships`
  exactly 1 row, pending, requested_by athlete, coach test@test.com; no `coaches` row for A (A is not
  marked coach); `user_entitlements` 0 rows.
- RevenueCat: customer A exists, no active entitlement, no subscription, no promotional Grant;
  attribute `coach_code` present.
- The screen: still the paywall (a pairing gives no Pro, mp-458).
- `redeem-code` edge logs: four 200 `paired`/refusal answers and one 400 for the overlong code; no 5xx.

For test@test.com (the coach): its `code_redemptions` rows, `coaches` row and Grants are unchanged;
it gains one pending pairing with A while A exists.

## After Delete account from the paywall ⋯ menu

- The app lands on the welcome screen.
- Footprint for A's id (`sweep-accounts.mjs footprint`): no rows, which includes the two
  `code_redemptions` rows and the pairing (both cascade on the user).
- test@test.com's pairings are back to the counts in db-codes-before.txt.
- A failed delete is a Finding.

## Account P: the Patrol flow `redeem_code_flow_test.dart`, its own `lee+e2e-redeem-<millis>` address

The same wrong, overlong, DEVCOACH30, DEVCOACH30-again steps through the widgets, with the pairing
row read as the account (RLS lets an athlete read its own pairings), then the account deletes itself.
Its footprint is empty afterwards.
