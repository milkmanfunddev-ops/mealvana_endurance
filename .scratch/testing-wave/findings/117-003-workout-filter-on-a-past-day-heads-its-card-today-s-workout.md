# 117-003 · Workout filter on a past day heads its card TODAY'S WORKOUT

- kind: bug
- status: triaged
- ticket: 117
- run: w40-20260926T1052Z
- screen: Timeline (Workout filter)
- decision: 

**Steps.**
1. test@test.com, Timeline, Previous day to Friday, September 25 (today is Sat 26).
2. Tap the Workout filter.

**Expected.**
The summary card names the day it shows ("Friday's workout" or "Workout"), not today.

**Actual.**
The card reads "TODAY'S WORKOUT 352 done · 0 planned" on Friday, September 25. The number has no unit, and "0 planned" sits next to a skipped (planned, not done) R-CORE Routine in the list below it.

**Evidence.**
- runs/117/14-day-25-filter-workout.png

**Decision quote.**
> 

**Triage.**

Held for Xuan (Lee, 2026-09-26): "Today's Workout" is ratified in her `energy-card.md`. Taken out of ticket 137; goes to Xuan with the SSOT pass.
