# 17-002 · Previous plans sheet lists a still-open draft as an earlier plan

- kind: bug
- status: triaged
- ticket: 17
- run: w12-20260924T1712Z
- screen: Previous plans (sheet) and the earlier plan view
- decision: 

**Steps.**
1. Sign in as test@test.com. Food → Plan → ⋮ → Previous plans.
2. Tap the second "Sep 13 – Sep 19 · 1 meal" row (the fifth row of the sheet).

**Expected.**
The sheet lists archived and confirmed plans (ticket 17's criterion). A draft that was never confirmed or archived is not an earlier plan.

**Actual.**
The row opens "Sep 13 – Sep 19 · 1 meal", "An earlier plan. View only.", with "Quinoa, mixed veg & walnuts ×9": the meal of fc9687ff, whose status is `draft` (created 2026-09-17 00:52 UTC, after that week's plan f2c0bc78 was confirmed at 00:27, so mp-241's archive-on-confirm did not cover it). The server's `list_plans` returns every non-deleted plan whatever its status, and the client filters only the current plan and empty plans. Nothing on the row says it was a draft. A second, empty draft (968c5a59, week of Aug 23) takes one of the 20 places `list_plans` returns (see 17-001) and is then dropped for having no meals.

Open product question: should a past week's leftover draft appear in the athlete's plan history, and if so, marked as a draft?

**Evidence.**
- runs/17/14-opened-plan-sep13-draft-1meal.png — the opened draft.
- runs/17/db-plan-meals-fc9687ff.json — its one stored meal (servings 9).
- runs/17/db-plan-meals-50b8190b.json — the other Sep 13 one-meal plan (archived, Mushroom risotto), ruling it out.
- runs/17/db-sheet-vs-sql.txt — row 5.

**Decision quote.**
> 

**Triage.**

Fix ticket 73 (Lee, 2026-09-25). Closed by the retest after it merges.
