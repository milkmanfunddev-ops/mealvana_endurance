# 01-018 · Check the onboarding daily plan preview numbers against the nutrition SSOT

- kind: followup-test
- status: open
- ticket: 01
- run: w1-20261007T1103Z
- screen: Your daily plan
- decision: 

**Steps.**
1. Male, born 1994, 5 ft 8 in, run + bike, goal "race a PR", gut Moderate, sweat Medium, no training platform: read the Workout day tab of "Your daily plan".
2. Compare carbs, protein, fat and calories with `docs/ssot/` (spec and vectors) for the same inputs.

**Expected.**
Numbers match the SSOT's workout-day targets for these inputs.

**Actual.**
Not judged in this run. Seen: 154 lb (70 kg) → carbs 9.5 g/kg (666 g), protein 1.4 g/kg (98 g), fat 2.1 g/kg (145 g), 4361 kcal for a "workout day" built around a long session; 152 lb → 9.0 / 1.4 / 2.0 g/kg, 4088 kcal. Fat at 2 g/kg and 4,000+ kcal look high enough to check.

**Evidence.**
- runs/01/16-onboarding-9.png

**Decision quote.**
> 

**Triage.**

