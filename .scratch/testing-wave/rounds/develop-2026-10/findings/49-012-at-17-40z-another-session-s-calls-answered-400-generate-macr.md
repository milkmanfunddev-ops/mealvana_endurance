# 49-012 · At 17:40Z another session's calls answered 400 (generate-macros-v4, generate-nutrition-plan-v3, search-public-events, get-weather-forecast) and plan_generation_log inserts failed with 22P02

- kind: bug
- status: open
- ticket: 49
- run: w5-20261008T1719Z
- screen: none
- decision: 

**Steps.**
1. No action of this run: at 17:40:28-39Z this run was saving Edit Meal on the Timeline, which calls none of these functions. Likely ticket 48's or 50's run (onboarding / plan generation); the lead matches it.
2. Read non-200 `function_edge_logs` and warning `function_logs` for 17:19-17:49Z.

**Expected.**
Plan and macro calls answer 200; `plan_generation_log` accepts what generate-nutrition-plan-v3 writes.

**Actual.**
`POST | 400` for generate-macros-v4 (17:40:28.7, 17:40:29.0, 17:40:38.7Z), generate-nutrition-plan-v3 (17:40:31.0, 17:40:39.8Z), search-public-events (17:40:38.98Z), get-weather-forecast (17:40:39.36Z). Between them generate-nutrition-plan-v3 ran and logged `[PLAN-V3] plan_generation_log insert failed: code 22P02, invalid input syntax for type integer: "18.64"` (17:40:32.53Z) and `"117.9"` (17:40:35.18Z): a fractional value goes into an integer column, so those generation logs are lost. Not caused by this run; filed per RUNBOOK step 7.

**Evidence.**
- runs/49/edge-errors-1719-1749.txt — the 400 lines and the two 22P02 warnings

**Decision quote.**
> 

**Triage.**
