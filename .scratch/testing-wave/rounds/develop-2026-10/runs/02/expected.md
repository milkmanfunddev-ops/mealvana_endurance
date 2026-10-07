# 02 expected records (written before the run, 2026-10-07 11:05Z)

Run: w1-20261007T1103Z. Account: test@test.com, user id 607f9dd5-6fa7-48ee-a628-720d4a0506a1.
App build ce1a1527. Day: 2026-10-07 (simulator local time, CDT).

## Save path (read from code, develop-next @ 1c254461)

`MealReviewScreen._logMeal()` -> `MealLogController.logFromComponents` ->
`MealLoggingService.logFromComponents`: ONE `meal_logs` row per logged meal, the items stored as a
jsonb list in `meal_logs.items`, totals (`calories`, `carbs_g`, `protein_g`, `fat_g`,
`sodium_mg`) = the sum of the Review screen's items, `source = 'describe'`, `slot` = the chip picked
on Review (null = "Any time"), `log_date = 2026-10-07`, `eaten_at` from `eatenAtForLogDate`,
`notes` NOT passed (the AI note shown on Review is not saved; mealplanning 23-002 said the same).
The row is written local-first (Drift) and uploaded; the dev row should appear within a short sync.

## meal_logs

- Before (db-before.txt, 11:04Z): no rows for log_date >= 2026-10-06.
- After: exactly one new row with `created_at` inside this run's minutes, name from Review,
  `source = describe`, macros equal to the Review totals (calories integer; grams as shown, rounding
  aside) and equal to the Timeline card. Ticket 08 is read-only on this account, so any other new
  row today is unexpected.

## Credits

Server code (`supabase/functions/_shared/ai/credits.ts`, also what the deployed describe-meal v59
bundle carries, deployed 2026-10-06 12:28Z): cost `describe-meal` = 1, enforcement gated by the
`AI_CREDITS_ENFORCED` secret.

- Enforced: `ensure_free_credits` before the call, then one `token_ledger` row with
  `reason = debit_usage`, `ref = describe-meal`, `delta = -1`, and `token_wallets.balance` down by 1.
- Not enforced: `allowed: true, balance: -1`, no ledger row, no balance change.

Before (db-before.txt): `token_wallets.balance = 49897436`, `unit = usd_micro`,
`allowance = 3943863`, `allowance_monthly = 6000000`; newest ledger rows are `reserve_usage` /
`settle_usage` pairs in usd_micro from 2026-09-30 (a different, mealplanning-style accounting).
The develop-next server code knows nothing of usd_micro, so the wallet is in a unit the
deployed function does not count in. Whichever outcome shows, write it; the pill must equal what
the server's balance means. TokenPill shows `balance.clamp(0, 99999)`.

## Pill

The pill in the Describe tab header must match `token_wallets.balance` before and after.

## Edge logs

`describe-meal` request line(s) in the call's minutes, status 200, no error lines from any function
in the window.
