# 69-001 · Follow-up: onboarding daily plan, lean-mass protein (no body-fat field in onboarding), Imperial 62 kg, a masters birth year

- kind: followup-test
- status: triaged
- ticket: 69
- run: w7-20261008T2311Z
- screen: Your daily plan (onboarding)
- decision: 

**Steps.**
1. 50-002's second half asked to enter a body fat value in onboarding and read the lean-mass Workout-day protein.
   Onboarding has no body-fat control (Basic body composition = units, height, weight only). Try the lean-mass path
   where body fat can be entered: signed in, Settings → Body Composition → body fat, then the plan's Workout-day
   protein (expect the 1.8 × lean-mass baseline plus the session bump, not 1.6 g/kg).
2. Onboard with 62 kg on the Imperial wheel (whole pounds, 137 lb): does Workout day still read 99 g / 1.6 g/kg?
3. Onboard with a birth year of 1980 or earlier (age ≥ 45): Workout and Rest protein should carry the ×1.15 masters
   multiplier; check the numbers and the g/kg line agree.
4. Running only, and Cycling only, with no import: does the Workout-day bump still apply (session longer than 1 h)?

**Expected.**
Each path shows protein that matches the baseline rule (1.4 × kg, or 1.8 × lean mass, ×1.15 at 45+) plus the
Workout-day bump only on Workout day; the g/kg and g figures agree.

**Actual.**
Not run. This run checked only 62 kg Metric, Running + Cycling, birth year 1994: Workout 1.6 g/kg · 99 g, Rest and
Carb load 1.4 g/kg · 87 g (PASS 50-002).

**Evidence.**
- runs/69/c5-body-comp-no-bodyfat.png Basic body composition has no body-fat field
- runs/69/c2-daily-plan-workout.png Workout day 1.6 g/kg · 99 g

**Decision quote.**
> 

**Triage.**
- triaged · retest ticket C (onboarding plan, Events, Learn, Connected Apps; with fix tickets 70 and 52 if a Runna URL lands in CRED), cut after fix wave 8 for test wave 9 · Lee, 2026-10-09
