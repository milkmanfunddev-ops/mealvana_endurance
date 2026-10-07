# 02-012 · Token pill on an account whose balance fits the pill: moves by the cost after a describe

- kind: followup-test
- status: open
- ticket: 02
- run: w1-20261007T1103Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. On an account of its own whose wallet is in whole tokens (balance under 99999), read the pill and `token_wallets.balance`.
2. Describe a meal (one AI logging spend); return to the sheet without relaunching; read the pill and the wallet again.

**Expected.**
Pill equals the balance before; after the call both drop by `creditCost('describe-meal')` = 1, and the pill updates without a relaunch.

**Actual.**


**Evidence.**
- runs/02/23-describe-pill-after.png — on test@test.com the clamped pill could not show the move (see 02-001)

**Decision quote.**
> 

**Triage.**

