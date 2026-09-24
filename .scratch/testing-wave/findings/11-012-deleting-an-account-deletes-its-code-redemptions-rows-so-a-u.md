# 11-012 · Deleting an account deletes its code_redemptions rows, so a used code may work again after a new signup

- kind: ssot-conflict
- status: open
- ticket: 11
- run: w5-20260924T0840Z
- screen: Paywall ⋯ menu, Delete account
- decision: mp-535

**Steps.**
1. A new athlete redeems DEVCOACH30 and DEVCOACH18 (one `code_redemptions` row each).
2. The athlete deletes the account from the paywall ⋯ menu.
3. Read `code_redemptions` for the codes.

**Expected.**
A redemption outlives the account, so a giveaway that "works once in total" stays spent and a referral stays counted; an athlete who deletes and signs up again cannot redeem the same giveaway again.

**Actual.**
Both redemption rows went with the account (cascade on the user); per-code counts dropped from 2 back to 1. Not yet tried: whether a giveaway, or the same email after a new signup, can then redeem again. Written by the wave lead from the run's notes; the agent recorded it as a note, not a Finding.

**Evidence.**
- runs/11/notes.md (09:01:35 entry: "both redemption rows and the pairing gone (cascade)")
- runs/11/db-A-after-step6.txt, runs/11/db-A-after-delete.txt (code_redemptions total per code)

**Decision quote.**
> Every Code works once per account, and a giveaway works once in total unless its row allows more; the days a Code grants are set on its row. (mp-535)

**Triage.**

