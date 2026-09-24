# Ticket 24 expected records (written before the run, 2026-09-24 ~20:16Z)

Account: test@test.com (dev, user id 607f9dd5-6fa7-48ee-a628-720d4a0506a1), entitled
(user_entitlements active_until 2027-09-15). Shared with ticket 25 this wave (wave-pool-2, logs meals by
hand and builds a meal from foods on 2026-09-24); its rows are expected and not judged here. Earlier
waves' 09-24 rows (38c4f0ed, 00a120e5, f952f981, 46b1d076) are expected.

## Before (db-before.txt)
- Entitlement: Pro, active_until in the future. No change expected.
- meal_logs: 79 rows total; no row carries "W14-24" in name or notes; no source='photo' row today.
- ai_usage / token_ledger newest at 19:07:54Z (ticket 23's describe call). Wallet balance 11,636,181 usd_micro.

## After (one photo analysis, one save)
- A food photo is in the simulator's Photos library (method in notes.md).
- COST: `cost.mjs spend 14 logging 24` spent once before Analyze.
- meal_logs: exactly one new row for this account created in the save window, source = 'photo',
  log_date = 2026-09-24 (device local date), is_deleted = false, name or notes carrying "W14-24",
  items = the components the Review screen listed, calories / carbs_g / protein_g / fat_g = the sum
  of the items = the numbers the app shows for the meal. photo_path set to a path under the user's id
  in the meal-photos bucket (and the object exists).
- The meal shows on today's timeline in the app with the same name and numbers.
- ai_usage: one new analyze-meal-photo row in the call window (model, tokens, cost_usd).
- token_ledger / token_wallets: reserve then settle for the call; balance falls by cost_usd.
- jade_calls: one analyze-meal-photo row in the call window.
- No row of ticket 25's or earlier waves' is edited or deleted by this run.
