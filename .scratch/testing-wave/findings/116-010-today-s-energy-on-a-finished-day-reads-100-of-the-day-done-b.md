# 116-010 · Today's Energy on a finished day reads 100% of the day done but projects burned 3,331 against 2,782 so far, from digestion of the target rather than what was eaten

- kind: bug
- status: open
- ticket: 116
- run: w32-20260925T2220Z
- screen: Today's Energy (Full Breakdown)
- decision: 

**Steps.**
1. test@test.com, Timeline, Thu 24 Sep (past), Full Breakdown > Today's Energy.

**Expected.**
On a finished day ("100% of the day done") "so far" and "by day's end" agree, or the projection says why it differs.

**Actual.**
Header "end of day · 100% of the day done"; "Burned 2,782 / 3,331 projected". WHERE THE BURN COMES FROM: Resting 1,901 / 1,901, Workout +0 / +0, Daily movement +546 / +546, Digestion +335 / +884, total 2,782 / 3,331. Digestion so far (335) is 10 % of the 3,353 kcal eaten; by day's end (884) is the target's TEF (daily_macro_targets.tef_kcal 884 for an 8,839 kcal target). A day that is over still projects digestion of food never eaten, so the two columns never meet. Same shape today: "Burned 1,839 / 3,064 projected" with digestion +76 / +306.

**Evidence.**
- runs/116/26-full-breakdown-0924.png
- runs/116/40-energy-breakdown-after-logs.png
- runs/116/db-daily-macro-targets-0920-0927.json

**Decision quote.**
> 

**Triage.**

