# 02-001 · Token pill shows 99999 while token_wallets.balance is 49,897,486

- kind: bug
- status: open
- ticket: 02
- run: w1-20261007T1103Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. Sign in as test@test.com on a cleared app (11:07Z).
2. Timeline → "+ Add Food"; the Log a Meal sheet opens on Describe.
3. Read the token pill beside the prompt; read `token_wallets.balance` for the account at the same minute.
4. Analyze one description, open the sheet again and read the pill.

**Expected.**
The pill equals `token_wallets.balance` (ticket 02 step 1: "Note the token pill's number and the SQL balance; they must match"), and moves when the server debits.

**Actual.**
The pill reads **99999** before and after the call. `token_wallets.balance` is 49,897,486 (11:08:06Z) and 49,897,485 after the describe-meal debit; the wallet's `unit` is `usd_micro`. The pill (`TokenPill`, `'${value.balance.clamp(0, 99999)}'`) clamps the raw usd_micro number, so it shows neither the balance nor the debit. An athlete on this wallet sees a fixed 99999 that never moves. See 02-002 for why a usd_micro wallet meets whole-token code on develop-next.

**Evidence.**
- runs/02/06-log-meal-sheet.png — pill 99999 before the call
- runs/02/db-wallet-at-pill.txt — balance 49897486 usd_micro at 11:08:06Z
- runs/02/23-describe-pill-after.png — pill still 99999 after the debit
- runs/02/db-after.txt — balance 49897485 after the debit

**Decision quote.**
> 

**Triage.**

