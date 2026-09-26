# 116-012 · Vana's Plan-tab day note says aim for 835C carbs, macro shorthand instead of words

- kind: idea
- status: triaged
- ticket: 116
- run: w32-20260925T2220Z
- screen: Food (Plan tab, Vana note)
- decision: 

**Steps.**
Idea, from follow-up 14-010. test@test.com's confirmed plan 666be167 holds a day note for Sat 26 Sep: "Long run day needs fuel—aim for 835C carbs; pasta with extra avocado at dinner, …". The figure is right (daily_macro_targets 2026-09-26 carb_g 835) but "835C" is the timeline's macro shorthand, not words an athlete reads in a sentence; the fallback note says "At least 295g carbs". A deleted plan (8ebeb6da) has "support 835C target". Idea: day notes say grams in words ("835 g of carbs"). Related: the plan's day_notes run 2026-09-25 to 2026-10-01 while the Plan tab header reads "Sep 20 – Sep 26".

**Expected.**


**Actual.**


**Evidence.**
- runs/116/db-plans-week0920-before.json
- runs/116/db-daily-macro-targets-0920-0927.json

**Decision quote.**
> 

**Triage.**

Fix ticket 134, Meal plans and Vana (Lee, 2026-09-26). Ruling: the day note says "835 g of carbs", never macro shorthand (134). Closed by the retest after it merges. Record: `triage-20260926.md`.
