# 23-005 · Describe with describe-meal failing, offline, or with the monthly AI budget under a tenth

- kind: followup-test
- status: triaged
- ticket: 23
- run: w13-20260924T1903Z
- screen: Log a Meal (Describe)
- decision: 

**Steps.**
1. Offline (IMPROVEMENTS #36 netcut) tap Analyze: the message shown, no charge in token_ledger.
2. On an account whose budget pill reads under 10% (dragonfruit) and then at 0%: Analyze, the insufficient-credits path (top-up sheet), no row written.
3. describe-meal answering an error (e.g. a gateway refusal): the snackbar text and that the typed description stays in the field.

**Expected.**
A clear message each time, the text kept, nothing logged, and no charge for a call that never ran.

**Actual.**
Not run. This run's account (test@test.com) reads 255% on the pill, well above the limit.

**Evidence.**
- runs/23/06-add-food.png: budget pill at 255%.
- runs/23/db-ai-usage-ledger-after.txt: the wallet after one call.

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
