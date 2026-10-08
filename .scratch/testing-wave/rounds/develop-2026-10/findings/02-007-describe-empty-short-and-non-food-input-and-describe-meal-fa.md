# 02-007 · Describe: empty, short and non-food input, and describe-meal failing offline or out of credits

- kind: followup-test
- status: closed
- ticket: 02
- run: w1-20261007T1103Z
- screen: Log a Meal (Describe tab)
- decision: 

**Steps.**
1. Analyze with the field empty, with fewer than 5 characters, and with non-food text ("my bike ride") — check which spend a token.
2. With `netcut.sh on`, Analyze a real description: the error shown, no ledger row, no wallet change.
3. On an account of its own with balance 0 (whole-token wallet), Analyze: the 402 `insufficient_credits` path and its paywall sheet.

**Expected.**
Validation stops empty/short input before any call; non-food text gets a clear answer; a failed or refused call shows a MealvanaSnackbar-style error and writes no `debit_usage` row (credits.ts: "failed calls aren't charged").

**Actual.**


**Evidence.**
- runs/02/07-describe-typed.png — Describe tab with text, Analyze button with its 1-token chip
- Old Finding: mealplanning-2026-09 23-003 (Describe input edges) and 23-005 (describe-meal failing offline / monthly cap)

**Decision quote.**
> 

**Triage.**
retest ticket 31 (retest: meal logging), wave 3 (Lee: all 27 followups into four retest tickets)

**Closed (wave 3, 2026-10-08).** run in ticket 31; a and b pass; c re-filed as 31-003
