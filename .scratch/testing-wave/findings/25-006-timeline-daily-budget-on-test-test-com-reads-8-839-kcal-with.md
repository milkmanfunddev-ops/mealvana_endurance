# 25-006 · Timeline daily budget on test@test.com reads 8,839 kcal with 475 g fat; check the numbers behind it

- kind: followup-test
- status: triaged
- ticket: 25
- run: w14-20260924T2015Z
- screen: Timeline (Meals filter, header)
- decision: 

**Steps.**
1. Signed in as test@test.com, Timeline → Meals on 2026-09-24.

**Expected.**
A daily budget whose parts add up and look like one athlete's day.

**Actual.**
The header reads "DAILY BUDGET 8,839 kcal · 1007C · 134P · 475F". 475 g of fat alone is about 4,275 kcal, and the day holds six planned workouts, several of them Patrol leftovers ("Patrol H5 …", 120 min each). Run 23 saw the same 8,839 kcal. Not checked against calculate-daily-macros-v6 or the SSOT here (out of scope for ticket 25); it may be correct for this many workouts, but the fat figure looks wrong.

**Evidence.**
- runs/25/24-timeline-meals.png
- runs/25/04-home.png (the day's planned workouts)

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 92 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 116 when 92 was split (Lee, 2026-09-25).
