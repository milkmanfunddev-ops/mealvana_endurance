# 17-004 · Previous plans rows show only week and meal count, so nine Sep 13 plans look alike

- kind: idea
- status: open
- ticket: 17
- run: w12-20260924T1712Z
- screen: Previous plans (sheet)
- decision: 

**Steps.**
1. Each row on the sheet shows the week and the meal count only. test@test.com has nine rows reading "Sep 13 – Sep 19", two of them "6 meals" and two "1 meal"; nothing says which one was the week's confirmed plan (f2c0bc78), which were archived drafts, or when each was made. Plans of the same week also tie on `updated_at` to the microsecond (15b6b4f4, b82409d9, 6f365c30), so their order on the sheet is arbitrary.
2. Idea: show the confirmed plan first in each week and mark it (or show only the confirmed plan per week, with the archived drafts behind it), add the date the plan was made or its first meal names, and break `updated_at` ties by `created_at`.

**Expected.**
An athlete can find last week's plan on the sheet without opening every row.

**Actual.**
Not run (idea).

**Evidence.**
- runs/17/08-previous-plans-sheet.png — the rows.

**Decision quote.**
> 

**Triage.**
