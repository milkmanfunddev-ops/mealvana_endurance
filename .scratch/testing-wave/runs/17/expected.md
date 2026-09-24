# Ticket 17 expected records (RUN w12-20260924T1712Z)

Copied from the ticket's criteria and the decision it cites (mp-241). The run is judged against this.

## Account
- Dev admin test@test.com (user id `607f9dd5-6fa7-48ee-a628-720d4a0506a1`), entitled; no new account.

## RevenueCat
- Nothing read or written: the ticket is read-only on plans and needs no purchase. (The account is the
  Admin, which skips the paywall.)

## Dev database, before (read at 17:13 UTC, `db-plans-before.json`)
- `meal_plans` for the account: 40 rows, 26 with `is_deleted = false`.
- Week of 2026-09-20: one confirmed plan `be6abf2f` (4 meals, the Plan tab's plan), archived `54a02440` (1),
  `15b6b4f4` (4), `b82409d9` (0), `6f365c30` (2).
- Earlier weeks: confirmed `f2c0bc78` (09-13, 6), `a5b4c73c` (09-06, 4), `a89fbf86` (08-30, 3); a draft
  `fc9687ff` (09-13, 1) and a draft `968c5a59` (08-23, 0) that are neither archived nor confirmed; the rest archived.

## Expected on the sheet (criterion 3)
- Every archived and confirmed plan of the account that is not deleted, other than the plan on the Plan tab
  (`be6abf2f`), newest week first. Plans with no meals may be left out (the sheet's code drops them).
  That is 21 plans: the 24 archived/confirmed non-deleted rows minus `be6abf2f` minus
  `b82409d9` and `61c0e1ee` (0 meals).
- Each row: the week label for its `week_start` and its meal count equal to `count(plan_meals)`.
- Drafts are not archived or confirmed plans; a draft on the sheet is a mismatch.

## Expected on an opened plan (criterion 4)
- The meals shown equal the plan's `plan_meals` rows: same count, names, meal types (slots), servings and,
  where the view shows days, the days in `meal_plans.days`.

## After
- No row in `meal_plans` or `plan_meals` changes during the run (`db-plans-after.json` equals
  `db-plans-before.json` for this account).
