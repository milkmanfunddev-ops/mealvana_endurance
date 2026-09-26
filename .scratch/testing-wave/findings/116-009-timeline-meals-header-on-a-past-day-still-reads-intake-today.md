# 116-009 · Timeline Meals header on a past day still reads INTAKE TODAY

- kind: bug
- status: triaged
- ticket: 116
- run: w32-20260925T2220Z
- screen: Timeline (Meals filter, header)
- decision: 

**Steps.**
1. test@test.com, Timeline, Meals filter, expand the header card.
2. Step back to Thu 24, Wed 23 … Sun 20 Sep.

**Expected.**
A past day's card is labelled for that day (for example "INTAKE" or the date), not "today".

**Actual.**
Every past day's expanded card reads "INTAKE TODAY" (Sep 20–24), e.g. "INTAKE TODAY 3,353 / 8,839 kcal" on Thursday 24. The All filter's card on the same days reads "NET ENERGY BALANCE" without "today", and Today's Fuel on Sep 24 reads "end of day".

**Evidence.**
- runs/116/06-meals-0924.png
- runs/116/06-meals-0922.png

**Decision quote.**
> 

**Triage.**

Held for Xuan (Lee, 2026-09-26): "Intake today" is ratified in her `energy-card.md`. Taken out of ticket 137; goes to Xuan with the SSOT pass.
