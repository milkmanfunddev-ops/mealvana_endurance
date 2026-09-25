# 23-003 · Describe tab input edges: empty, under 5 characters, non-food text, a very long description, Analyze tapped twice, Back while analyzing

- kind: followup-test
- status: triaged
- ticket: 23
- run: w13-20260924T1903Z
- screen: Log a Meal (Describe)
- decision: 

**Steps.**
1. Analyze with the field empty, then with 4 characters ("eggs"): the "Please describe your meal" check, no AI call.
2. Analyze a non-food description ("my car keys"): what describe-meal returns and what the screen says. Costs one logging call.
3. A very long description (a full day of eating, 1,000+ characters, emoji): read it back, analyze, count items. Costs one logging call.
4. Tap Analyze twice quickly: one describe-meal request or two (edge logs, ai_usage, token_ledger).
5. Back while "Reading your description..." shows: whether the wallet is still charged (token_ledger reserve/settle) with nothing to log, and whether a late result pushes Review & Log onto another screen.

**Expected.**
1 is blocked locally with no request. 2 shows a clear message and logs nothing. 3 works or says the text is too long. 4 sends one request. 5 either cancels or keeps the charge visible, and never pushes Review on top of an unrelated screen.

**Actual.**
Not run (one AI call spent this wave by this ticket; each of 2, 3, 4 and 5 costs one more).

**Evidence.**
- runs/23/06-add-food.png: the Describe tab.

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
