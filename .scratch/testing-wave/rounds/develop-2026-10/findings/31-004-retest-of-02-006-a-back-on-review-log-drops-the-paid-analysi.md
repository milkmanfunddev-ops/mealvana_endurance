# 31-004 · Retest of 02-006 (a): Back on Review & Log drops the paid analysis and the typed text; getting back to Review costs another token

- kind: bug
- status: triaged
- ticket: 31
- run: w3-20261008T1256Z
- screen: Review & Log
- decision: fix ticket 45 (Review - decision:  Log: empty name, non-food, Back keeps the analysis, swap rounding)

**Steps.**
1. Describe "my bike ride", Analyze (one token).
2. On Review & Log tap Back (top-left) without logging.
3. Tap + Add Food to reopen the Log a Meal sheet.

**Expected.**
Back returns to the Describe tab with the text kept, and the analysis can be reopened without paying again (02-006: "Back loses nothing it should keep and never charges twice for one analysis").

**Actual.**
Back closes both Review and the sheet and lands on the Timeline. Reopening the sheet shows an empty "What did you eat?" field and Analyze still priced at 1 token; the Review result is gone, so seeing it again needs a new Analyze and a second token. The same happens after a successful food analysis (the route is the same; checked only with "my bike ride" to avoid a fourth spend).

**Evidence.**
- runs/31/50-bike-back.png — Timeline right after Back
- runs/31/51-sheet-after-back.png — sheet reopened: empty field, Analyze 1
- runs/31/db-spend3.txt — one debit for the analysis that was thrown away

**Decision quote.**
> 

**Triage.**

