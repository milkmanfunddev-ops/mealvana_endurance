> Mirrored from Notion: https://www.notion.so/daily_macro_calc_iteration2_spec-326e3fdb754c809ba0deeaf778dd1cf7
> Last edited (Notion): 2026-03-17T17:04:00.000Z
> **Authoritative source is Notion.** Edit there and re-mirror.

# Macro Calculator — Iteration 2 Spec

Extends Iteration 1 with multi-day awareness and periodization. Adds Steps 3–6 to the pipeline: yesterday's recovery debt, tomorrow's pre-load, weekly load ratio, and training phase modifiers. Still uses fixed 1.25× non-exercise multiplier.

All Iteration 1 functions remain unchanged. This iteration adds 4 new formulas and updates the assembly function.

---

## New Inputs (in addition to Iteration 1)

### Yesterday's Session

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| yesterday_tss | float | No | If unavailable, derive from: duration_hr × IF² × 100. If null, Step 3 is skipped. |
| yesterday_end_time | datetime | No | Used to compute hours_since for decay function. |

### Tomorrow's Session

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| tomorrow_tss | float | No | Estimated TSS of planned session. If all tomorrow fields null, Step 4 skipped. |
| tomorrow_duration_hr | float | No | Planned duration. |
| tomorrow_is_race | boolean | No | If true, triggers full carb-load override (9.0 g/kg). |

### Training Context

| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| training_phase | Enum: BASE, BUILD, PEAK, TAPER, RACE_WEEK, OFF_SEASON | Yes | BASE | Set by athlete in settings. |
| weekly_load_ratio | float | Yes | 1.0 | Iter 2 proxy: this_week_hours / typical_week_hours. Default 1.0 = neutral. |

### Output (same shape as v1, extended)

```
{ carb_g, prot_g, fat_g, tdee, rmr, session_kcal }
```

---

## New Formulas

### 7. recoveryDebt(yesterday_tss, hours_since, weight_kg)

If yesterday's TSS ≥ 150, add recovery carb/protein that decays linearly from 18h to 36h post-session.

```
if yesterday_tss is null OR yesterday_tss < 150:
  return { carb_add: 0, prot_add: 0 }

factor = clamp(1.0 − (hours_since − 18) / 18,  0,  1)

carb_add = 1.25 × weight_kg × factor
prot_add = 0.1  × weight_kg × factor
```

Key values: factor = 1.0 at ≤18h, 0.5 at 27h, 0.0 at ≥36h.

### 8. preLoadOverride(tomorrow_is_race, tomorrow_tss, tomorrow_duration_hr, current_carb, weight_kg)

Upward-only override — can only increase carb, never decrease.

```
if tomorrow_is_race OR tomorrow_tss > 200:
  return max(current_carb, 9.0 × weight_kg)

if tomorrow_tss > 120 OR tomorrow_duration_hr > 1.5:
  return current_carb + 1.5 × weight_kg

return current_carb
```

### 9. weeklyLoadAdjust(ratio, weight_kg)

Additive nudge based on weekly training load relative to typical.

```
ratio < 0.7  → carb: −1.0 × weight_kg,  prot: 0
ratio < 0.9  → carb: −0.5 × weight_kg,  prot: 0
ratio ≤ 1.1  → carb: 0,                  prot: 0
ratio ≤ 1.3  → carb: +0.5 × weight_kg,  prot: +0.1 × weight_kg
ratio > 1.3  → carb: +1.0 × weight_kg,  prot: +0.2 × weight_kg
```

### 10. phaseModifiers(phase)

Returns multiplicative scaling factors. Applied after all additive steps.

| Phase | carb_mod | prot_mod | fat_mod |
| --- | --- | --- | --- |
| BASE | 1.00 | 1.00 | 1.00 |
| BUILD | 1.08 | 1.05 | 1.00 |
| PEAK | 1.12 | 1.10 | 0.95 |
| TAPER | 0.88 | 1.00 | 1.05 |
| RACE_WEEK | 1.00 | 1.00 | 0.85 |
| OFF_SEASON | 0.80 | 1.00 | 1.10 |

RACE_WEEK carb_mod is forced to 1.00 so the taper multiplier doesn't undermine the carb-load protocol in Step 4.

### 11. dailyMacros_v2 (updated assembly)

Processing order is critical. Steps 1–2 reuse Iteration 1 logic.

```
1–2. Run Iteration 1 Steps 1–2 (baseline + today's sessions)
     → yields: carb, prot (before clamp), session_kcal, rmr

3.   Recovery debt (additive):
     hours_since = hours between yesterday_end_time and now
     debt = recoveryDebt(yesterday_tss, hours_since, weight)
     carb += debt.carb_add
     prot += debt.prot_add

4.   Pre-load override (upward only):
     carb = preLoadOverride(tomorrow_is_race, tomorrow_tss, tomorrow_dur, carb, weight)

5.   Weekly load (additive nudge):
     adj = weeklyLoadAdjust(weekly_load_ratio, weight)
     carb += adj.carb
     prot += adj.prot

6.   Phase modifiers (multiplicative):
     mods = phaseModifiers(training_phase)
     carb *= mods.carb_mod
     prot *= mods.prot_mod

7.   Clamp:
     carb = clamp(carb, 3.0 × weight, 12.0 × weight)
     prot = clamp(prot, 1.2 × weight, 2.5 × weight)

8.   TDEE + fat residual (still fixed 1.25× for Iter 2):
     tdee = rmr × 1.25 + session_kcal
     fat = max((tdee − carb×4 − prot×4) / 9,  0.8 × weight)

9.   Return { carb_g, prot_g, fat_g, tdee, rmr, session_kcal } (all rounded)
```

Implementation note: refactor Iteration 1's dailyMacros_v1 so the internal Steps 1–2 computation (before clamp and fat residual) is callable from v2. Steps 7–8 move to end of v2.

---

## Test Cases

Test cases are provided in a separate file (`iteration2_tests.md`) and should be run after implementation is complete. All Iteration 1 tests must also still pass.
