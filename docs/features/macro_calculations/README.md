# Daily Macro Calculator — Spec Index

Notion is the authoritative source for these specs; the markdown files in this directory are read-only mirrored snapshots. Edit in Notion and re-mirror — do not edit these files directly.

**Notion root:** [Daily Macro Calculation](https://www.notion.so/Daily-Macro-Calculation-326e3fdb754c80199486c17ecf9947cd)

## Iterations

1. **Iteration 1 — Baseline RMR, TDEE, and macros.** Establishes RMR (Cunningham/Mifflin-St Jeor), zone-weighted IF, session calorie cost, carb demand, and the Step 1–8 assembly with fixed 1.25× non-exercise multiplier.
   - Status: implemented in v4.0.0
   - [Spec](./iteration1_spec.md) · [Tests](./iteration1_tests.md) · [Notion spec](https://www.notion.so/daily_macro_calc_iteration1_spec-326e3fdb754c80ba918cd4e5afc4e64a) · [Notion tests](https://www.notion.so/daily_macro_calc_iteration1_tests-326e3fdb754c809e938bdf688be8c400)

2. **Iteration 2 — Multi-day context.** Adds yesterday's recovery debt, tomorrow's pre-load override, weekly load adjust, and training phase modifiers; still uses fixed 1.25× non-exercise multiplier.
   - Status: implemented in v4.0.0
   - [Spec](./iteration2_spec.md) · [Tests](./iteration2_tests.md) · [Notion spec](https://www.notion.so/daily_macro_calc_iteration2_spec-326e3fdb754c809ba0deeaf778dd1cf7) · [Notion tests](https://www.notion.so/daily_macro_calc_iteration2_tests-326e3fdb754c80f7a48dc23d8c14fc73)

3. **Iteration 3 — Dynamic NEAT + iterative TEF.** Replaces the fixed 1.25× non-exercise multiplier with volume tier × day modifier × lifestyle NEAT plus a convergent TEF loop, and introduces the prospective/retrospective mode parameter.
   - Status: implemented in v4.0.0
   - [Spec](./iteration3_spec.md) · [Tests](./iteration3_tests.md) · [Notion spec](https://www.notion.so/daily_macro_calc_iteration3_spec-326e3fdb754c80d99433d3819468d900) · [Notion tests](https://www.notion.so/daily_macro_calc_iteration3_tests-326e3fdb754c80298207c0fbe7eebcaa)

4. **Iteration 4 — Safety and edge cases.** Adds the EA safety gate (with HARD_WARNING override and BLOCK), multi-session carb compounding (1.1^n for endurance), and opt-in train-low carb cycling on qualifying easy days.
   - Status: implemented in v4.0.0
   - [Spec](./iteration4_spec.md) · [Tests](./iteration4_tests.md) · [Notion spec](https://www.notion.so/daily_macro_calc_iteration4_spec-326e3fdb754c8032ad1fc068eb47195c) · [Notion tests](https://www.notion.so/daily_macro_calc_iteration4_tests-326e3fdb754c805a8956ede41fca6ffc)

5. **Iteration 5 — Garmin + TrainingPeaks/Final Surge integration.** Adds resolve functions that prefer measured platform data (session kcal, daily active/BMR kcal, TP IF/TSS/CTL/ATL, body comp) over formula estimates without changing the underlying nutritional formulas.
   - Status: in progress on `feat/macro-iter5-garmin`
   - [Spec](./iteration5_spec.md) · [Tests](./iteration5_tests.md) · [Notion spec](https://www.notion.so/daily_macro_calc_iteration5_spec-328e3fdb754c80149d4ec49f61f6e502) · [Notion tests](https://www.notion.so/daily_macro_calc_iteration5_tests-328e3fdb754c8084b164d40cb9a32fd9)
