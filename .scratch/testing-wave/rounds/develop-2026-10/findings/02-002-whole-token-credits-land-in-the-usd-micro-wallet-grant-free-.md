# 02-002 · Whole-token credits land in the usd_micro wallet: grant_free +50 at sign-in, describe-meal debits 1 micro-dollar for a 0.0086 USD call

- kind: bug
- status: triaged
- ticket: 02
- run: w1-20261007T1103Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. Read `token_wallets` / `token_ledger` for test@test.com before the run (11:04Z): unit `usd_micro`, balance 49,897,436, newest ledger rows are `reserve_usage`/`settle_usage` pairs in usd_micro from 2026-09-30.
2. Sign in (the app calls `ensure-credits` at start, request 11:07:56Z).
3. Describe one meal and Analyze (describe-meal 200 at 11:08:38Z, console cost_usd 0.008616).
4. Read the wallet and ledger again.

**Expected.**
One accounting per wallet. develop-next's server code (`supabase/functions/_shared/ai/credits.ts`, also in the deployed describe-meal v59 bundle) counts whole tokens: cost `describe-meal: 1`, a free monthly grant (default 20). Against a whole-token wallet that is one `debit_usage −1 ref describe-meal` and the balance down by 1. A wallet kept in `usd_micro` should be charged by usage cost (here ~8,616 usd_micro), or not touched by whole-token code at all.

**Actual.**
Credits are enforced on dev, and the whole-token code writes into the usd_micro wallet:
- 11:07:55.98Z `grant_free +50 ref 2026-10 balance_after 49897486 unit usd_micro` (app start-up `ensure-credits`): a "50 free tokens" grant worth 50 micro-dollars.
- 11:08:38.92Z `debit_usage −1 ref describe-meal balance_after 49897485 unit usd_micro`: a call that cost 0.008616 USD (8,616 usd_micro) is charged 1 micro-dollar; `allowance` also drops by 1 (3943863 → 3943862).
The dev database carries the usd_micro wallet that mealplanning's reserve/settle accounting writes, while develop-next's functions (deployed 2026-10-06 12:28Z) count whole tokens. Each branch's AI calls now move the same balance in different units. Likely the mealplanning↔develop branch skew on the shared dev project; prod's schema should be checked before develop ships.

**Evidence.**
- runs/02/db-before.txt — usd_micro wallet and reserve/settle ledger before the run
- runs/02/db-wallet-at-pill.txt — grant_free +50 in usd_micro at sign-in
- runs/02/db-after.txt — debit_usage −1 ref describe-meal in usd_micro
- runs/02/edge-requests.txt — ensure-credits 11:07:56Z, describe-meal 11:08:38Z, both 200
- runs/02/expected.md — both credit outcomes from credits.ts written before the run

**Decision quote.**
> 

**Triage.**
fix ticket: develop's token model must work as intended end to end (Lee): tokens start at 50 and go down to 0, one per describe-meal, photo and formula-kit call, the pill shows the real balance, the wall at 0, token packs purchasable; the usd_micro skew with mealplanning's wallet is resolved as part of it, not studied further
