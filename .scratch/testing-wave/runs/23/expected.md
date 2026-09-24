# Ticket 23 expected records (written before the run, 2026-09-24 ~19:05Z)

Account: test@test.com (dev, user id 607f9dd5-6fa7-48ee-a628-720d4a0506a1), entitled
(user_entitlements active_until 2027-09-15). Shared with ticket 26 this wave (it logs three
non-AI meals today from Recent, Common, Recipes); only rows this run creates are judged.

## Before
- RevenueCat / entitlement: test@test.com is Pro (entitlement row active_until in the future). No change expected.
- meal_logs: no row for this account whose name/notes/items carry "W13-23".
- ai_usage / token_ledger: newest rows as in db-before.txt.

## After (one Describe call, one save)
- meal_logs: exactly one new row for this account, created between the before/after save times,
  with source = 'describe', log_date = today (device local date), is_deleted = false,
  items = the components the review screen listed, and calories / carbs_g / protein_g / fat_g
  equal to the sum of those items and to the numbers the app shows for the logged meal on the day.
- The meal shows on today's log in the app with the same name and the same numbers.
- ai_usage: one new row for function describe-meal in the call window (model, tokens, cost_usd).
- token_ledger / token_wallets: one debit for the call (the AI wallet moves by the call's cost).
- No row of ticket 26's is edited or deleted by this run.
