# 117-016 · generate-nutrition-plan-v3's during template fails its own carb check (106 g of 95 g, 112%) and falls back to the rule solver

- kind: bug
- status: open
- ticket: 117
- run: w40-20260926T1052Z
- screen: none (server, generate-nutrition-plan-v3)
- decision: 

**Steps.**
1. Account A (lee+e2e-117-20260926T1110Z, Running) on the Timeline: + Add Activity → Running, defaults (12 mi Run, today 7:30 am) → Generate Plan → Create Plan (11:16:42-11:17:25Z, ticket 117's 10-004 setup).
2. Read generate-nutrition-plan-v3's function logs for 11:17Z.

**Expected.**
The during template's optimized quantity search finds a candidate within its own carb validation, or the log says why no template fits the target.


**Actual.**
At 11:17:25Z the function logged `[DURING-TEMPLATE-SEARCH] Best candidate failed validation: carbs 112% (106g/95g)`, `[DURING-TEMPLATE] Optimized quantity search failed for template 1; trying sequential fill` and `[DURING-TEMPLATE] VALIDATION FAILED: carbs 112% (106g/95g) — returning null (will fall back to rule solver)`. The request answered 200 and the app showed a plan, so the athlete saw no error; the during fuelling came from the rule solver instead of the template. Not checked: what the rule solver's during block held, or whether this happens for every 12 mi run default. Filed by the wave lead from the wave's own edge extract (the run did not read function logs).


**Evidence.**
- runs/117/lead-edge-plan-generation.txt (function logs 06:16-06:17 local = 11:16-11:17Z, the three lines above)
- runs/117/lead-edge-requests-wave40.txt (generate-macros-v4 06:17:06, generate-nutrition-plan-v3 06:17:25, both 200)
- runs/117/notes.md (11:16:42 planned workout on A)

**Decision quote.**
> 

**Triage.**

