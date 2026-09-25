# 25-005 · Timeline Meals after manual and built logs: untried edit and delete through the row menu, and whether the 250.5 kcal row can be corrected

- kind: followup-test
- status: triaged
- ticket: 25
- run: w14-20260924T2015Z
- screen: Timeline (Meals filter)
- decision: 

**Steps.**
1. After the three logs, Timeline → Meals showed W14-25 Manual oats (437 kcal), W14-25 Decimal kcal (0 kcal), W14-25 Built bowl (450 kcal), each with a ⋯ menu.

**Expected.**
- ⋯ → edit on the manual row (no items, totals only): the edit screen opens with the totals and a change saves.
- ⋯ → edit on the built row: both items shown and editable.
- ⋯ → edit on the 0-kcal row from 25-001: can the athlete put 250 kcal back?
- ⋯ → delete: the row goes is_deleted and leaves the day's totals.
- The daily totals at the top move by exactly the logged calories.

**Actual.**
Not run in ticket 25. Only this run's three rows showed; the four rows logged earlier today (wave 13) did not, which is the known empty-until-Food-opens problem (10-001, 26-001), not re-filed.

**Evidence.**
- runs/25/24-timeline-meals.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
