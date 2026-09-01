# Description

Replaces the crude fixed multiplier with a dynamic energy model and adds critical safety guardrails. The macro pipeline from V1 remains unchanged — this version replaces the TDEE calculation (Step 8) and adds a safety layer (Step 9).

**Covers technical iterations 3 and 4 from the spec.**

## What it delivers

### Iteration 3: Dynamic NEAT + iterative TEF

- **Volume tier inference**: maps weekly training hours to athlete volume tier (Recreational → Professional), each with a calibrated base NEAT factor
- **Day modifier**: adjusts NEAT based on what kind of day it is (double session = 1.15×, training day = 1.10×, rest-after-hard = 0.90×)
- **Lifestyle modifier**: onboarding question (Desk/Mixed/Active/Very Active) scales NEAT further
- **Iterative TEF**: solves the circular dependency between TDEE, fat, and thermic effect of food via convergent iteration (typically 2–3 passes)
- **Prospective/retrospective mode parameter**: infrastructure for V3 Garmin integration — both modes run identical math in V2 but accept different input sources
- Key property: carb and protein are identical to V1 output — only TDEE and fat change

### Iteration 4: Safety + edge cases

- **RED-S / Energy Availability gate**: calculates EA = (intake − exercise kcal) / FFM. Soft warning at EA 30–45, hard override at EA 20–30 (forces intake upward), blocks plan generation below EA 20
- **Multi-session carb compounding**: when 2+ workouts in a day, each subsequent endurance session's carb demand scales by 1.1× (glycogen depletion effect)
- **Carb cycling opt-in**: on qualifying easy days (IF ≤0.80, duration ≤1.25h, not PEAK/RACE_WEEK), reduces carb baseline to 3.0 g/kg for "train low" adaptation. Requires explicit athlete opt-in
- **Masters adjustment**: protein ×1.15 for athletes 45+ (carried from V1 baseline)

## Why group these together

Iteration 3 (NEAT/TEF) and Iteration 4 (safety/edge cases) are tightly coupled — the EA safety check needs the accurate TDEE from the dynamic model, and carb compounding interacts with the NEAT day modifier for double-session days. Shipping them together ensures the safety rails are calibrated against the real energy model, not the placeholder.

## Spec & tests

- [Iteration 3 spec](https://www.notion.so/daily_macro_calc_iteration3_spec-326e3fdb754c80d99433d3819468d900?pvs=21) | [Iteration 3 tests](https://www.notion.so/daily_macro_calc_iteration3_tests-326e3fdb754c80298207c0fbe7eebcaa?pvs=21)
- [Iteration 4 spec](https://www.notion.so/daily_macro_calc_iteration4_spec-326e3fdb754c8032ad1fc068eb47195c?pvs=21) | [Iteration 4 tests](https://www.notion.so/daily_macro_calc_iteration4_tests-326e3fdb754c805a8956ede41fca6ffc?pvs=21)

# Comments

(Please feel free to provide comments below)