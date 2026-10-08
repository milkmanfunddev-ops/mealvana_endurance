# 30-004 · Onboarding Your daily plan leaves out the session protein bump on the Workout day (1.4 g/kg where the 150-min run needs 1.6)

- kind: ssot-conflict
- status: triaged
- ticket: 30
- run: w3-20261008T1255Z
- screen: Your daily plan
- decision: docs/ssot/spec/daily-macros/session-demand.md#Protein bump from today's sessions (Iteration 1, assembly step 3d)

**Steps.**
1. Onboarding as account B: Running + Cycling, no goal, Female, 1994, 173 cm, 62 kg (metric), gut High, sweat Heavy.
2. "Your daily plan" → Workout day ("Built around a long training session").
3. Same for account A: Male, 1994, 5 ft 8 in, 150 lb (68 kg), Running, gut Moderate, sweat Medium.

**Expected.**
The workout day is built around a long session (from code, `plan_preview_service.dart`: `defaultLongRunMinutes = 150`),
which is over 1.0 hr, so protein gets the 0.2 × weight bump: B 62 × 1.4 + 12.4 ≈ 99 g (1.6 g/kg); A ≈ 109 g. The carbs
shift a little after the fat-cap redistribution (B about 563 g instead of 576 g).

**Actual.**
Workout day protein is 1.4 g/kg on every day type: B 87 g, A 95 g (the same as the rest day). From code, unverified at
runtime: the preview passes `protG: baseline.protG` for all three days (`plan_preview_service.dart:177/187/200`), with no
session bump. The other preview numbers check out against the spec (fat cap 0.30 × TDEE / 9, carb-load floor 9.0 g/kg,
fat floor 0.8 g/kg, run ceiling 70 g/hr). The spec's README also asks that the preview not disagree with the post-onboarding plan.
B's numbers: Workout 576 g C / 87 g P / 126 g F / 3786 kcal; Rest 248 / 87 / 64 / 1916; Carb load 558 / 87 / 50 / 3030.
A's Workout: 655 / 95 / 143 / 4287.

**Evidence.**
- runs/30/30b2-03-daily-workout-scrolled.png (B workout day)
- runs/30/30b2-04-daily-rest.png
- runs/30/30b2-05-daily-carbload.png
- runs/30/30a-11.png (A workout day)

**Decision quote.**
> Strength qualifies on sport alone, at any duration. The endurance trigger is strictly `> 1.0 hr`.

**Triage.**
