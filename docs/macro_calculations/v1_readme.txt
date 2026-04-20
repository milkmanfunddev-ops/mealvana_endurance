# Description

The foundational engine. Takes an athlete's profile + today's workouts and returns daily carb, protein, and fat gram targets. Then extends with multi-day awareness: yesterday's recovery debt, tomorrow's pre-load, weekly training load, and training phase modifiers.

**Covers technical iterations 1 and 2 from the spec.**

## What it delivers

### Iteration 1: Baseline RMR, TDEE, and macro targets

- Calculates RMR via Cunningham (if body fat known) or Mifflin-St Jeor
- Baseline macros: 4.0g carb/kg, 1.8g protein/kg LBM (1.4g/kg if LBM unknown), age-adjusted protein for 45+
- Per-session calorie cost based on sport, duration, and intensity (zone-weighted IF calculation)
- Carb demand via piecewise interpolation from intensity factor, with duration/intensity multiplier for long or hard sessions
- Protein bump for strength sessions (+0.3g/kg) and endurance sessions >1hr (+0.2g/kg)
- Fat calculated as residual from TDEE after carb and protein calories, with 0.8g/kg floor
- Clamped ranges: carb 3–12 g/kg, protein 1.2–2.5 g/kg

### Iteration 2: Multi-day context

- **Recovery debt**: after yesterday's hard session (TSS ≥ 150), adds recovery carbs/protein that decay linearly from 18h to 36h post-session
- **Pre-load override**: if tomorrow is race day or high-load (TSS >200), carb target overridden upward to 9.0 g/kg; for moderately hard tomorrows (TSS >120 or >1.5h), adds 1.5 g/kg
- **Weekly load adjustment**: additive carb/protein nudge based on this week's hours vs. typical (±1.0 g/kg carb at extremes)
- **Training phase modifiers**: multiplicative scaling by phase (BASE/BUILD/PEAK/TAPER/RACE_WEEK/OFF_SEASON) — e.g., BUILD = 1.08× carb, PEAK = 1.12× carb + 1.10× protein

## Key design decisions

- Fixed 1.25× non-exercise activity multiplier (replaced in V2 with dynamic NEAT)
- Pipeline is sequential and deterministic — each step's output feeds the next
- All formulas are pure functions for testability
- Rachel (science advisor) to QA the calculation methodology

## Spec & tests

- [Iteration 1 spec](https://www.notion.so/daily_macro_calc_iteration1_spec-326e3fdb754c80ba918cd4e5afc4e64a?pvs=21) | [Iteration 1 tests](https://www.notion.so/daily_macro_calc_iteration1_tests-326e3fdb754c809e938bdf688be8c400?pvs=21)
- [Iteration 2 spec](https://www.notion.so/daily_macro_calc_iteration2_spec-326e3fdb754c809ba0deeaf778dd1cf7?pvs=21) | [Iteration 2 tests](https://www.notion.so/daily_macro_calc_iteration2_tests-326e3fdb754c80f7a48dc23d8c14fc73?pvs=21)

# Comments

(Please feel free to provide comments below)