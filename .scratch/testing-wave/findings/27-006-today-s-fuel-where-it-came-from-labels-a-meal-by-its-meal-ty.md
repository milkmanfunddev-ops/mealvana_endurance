# 27-006 · Today's Fuel Where it came from labels a meal by its meal type (Lunch, Snack) instead of its name

- kind: idea
- status: closed
- ticket: 27
- run: w15-20260924T2039Z
- screen: Today's Fuel (Daily, Where it came from)
- decision: 

**Steps.**
1. Timeline → Meals → Full Breakdown → Today's Fuel → expand "Where it came from · 9 logged".

**Expected.**
Each row names the meal the athlete logged, so it can be matched to the timeline.

**Actual.**
Rows with a meal type show only the type: "SNACK 2:08 PM 168 kcal", "LUNCH 2:08 PM 404 kcal", "SNACK 2:09 PM 300 kcal", "LUNCH 3:43 PM" (my "W15-27 edited"). Rows without one show the name ("Rolled oats and Raisins", "W14-25 Decimal kcal"). Two snacks at 2:08 and 2:09 can only be told apart by their numbers. Idea: show the meal name with the type as a tag. The totals and row count (9) matched SQL.

**Evidence.**
- runs/27/23-where-it-came-from.png

**Decision quote.**
> 

**Triage.**
Fix ticket 80 (the wave lead, 2026-09-25: Lee asked for every bug fix that can be done without him). Closed by the retest after it merges.
Moved to retest ticket 116 when 92 was split (Lee, 2026-09-25).

Run by retest ticket 116 (run w32-20260925T2220Z, build e3367d2c): pass.
