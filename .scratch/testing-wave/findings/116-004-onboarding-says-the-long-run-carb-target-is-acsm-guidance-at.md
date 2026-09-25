# 116-004 · Onboarding says the long-run carb target is ACSM guidance at your body weight; the ratified during-carbs math says body weight does not affect it

- kind: ssot-conflict
- status: open
- ticket: 116
- run: w32-20260925T2220Z
- screen: Onboarding (Your fueling plan)
- decision: docs/ssot/spec/fueling/during-workout-carbs.md#Gut multiplier · sport ceiling

**Steps.**
1. Build My Plan: Running, PR goal, energy crash, no training app, Male, 5 ft 8 in / 150 lb, gut training HIGH 1.2×.
2. Read the "We built your plan." screen.

**Expected.**
The long-run carb target's explanation follows the ratified during-carbs math: the duration band, scaled by the gut multiplier, capped at the sport ceiling, with body weight playing no part.

**Actual.**
It reads "LONG-RUN CARB TARGET 70 g/hr" and "Our recommendation for you: ACSM guidance at your body weight, scaled to your gut-training level." The 70 g/hr itself matches the running ceiling; the copy tells the athlete their weight set it, which the ratified spec rules out.

**Evidence.**
- runs/116/58-onb-8.png

**Decision quote.**
> - Body weight does NOT affect during-carbs (Jeukendrup 2014 — gut absorption isn't weight-scaled).

**Triage.**

