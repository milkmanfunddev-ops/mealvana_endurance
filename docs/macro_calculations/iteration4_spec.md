> Mirrored from Notion: https://www.notion.so/daily_macro_calc_iteration4_spec-326e3fdb754c8032ad1fc068eb47195c
> Last edited (Notion): 2026-03-17T20:58:00.000Z
> **Authoritative source is Notion.** Edit there and re-mirror.

# Macro Calculator — Iteration 4 Spec

Adds safety and edge case handling. New Step 9 (EA safety gate), multi-session carb compounding (replaces naive sum in Step 2), and carb cycling opt-in (modifies baseline in Step 1). Steps 3–8 unchanged from Iteration 3.

All Iteration 1–3 functions remain unchanged. This iteration adds 4 new formulas and updates the assembly function.

---

## New Inputs (in addition to Iterations 1–3)

### Athlete Settings

| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| carb_cycle_opt_in | boolean | No | false | Enables train-low carb cycling on qualifying easy days. Athlete must explicitly opt in. |

No other new user inputs. EA check uses FFM (derived from existing body_fat_pct or estimated), multi-session compounding uses existing session list, masters adjustment uses existing age.

### FFM Derivation (used by EA check)

```
if body_fat_pct is provided:
  ffm = weight_kg × (1 − body_fat_pct / 100)
else:
  ffm = weight_kg × 0.85   (male)
  ffm = weight_kg × 0.78   (female)
```

### Output (extended from v3)

```
{ carb_g, prot_g, fat_g, tdee, rmr, session_kcal, neat_kcal, tef_kcal, mode, ea, ea_status }
```

---

## New Formulas

### 17. checkEnergyAvailability(intake_kcal, session_kcal, ffm_kg)

Energy Availability = energy remaining for basic body functions after exercise.

```
ea = (intake_kcal − session_kcal) / ffm_kg

if ea ≥ 45:  status = OK
elif ea ≥ 30: status = SOFT_WARNING
elif ea ≥ 20: status = HARD_WARNING
else:          status = BLOCK
```

| EA Range | Status | Action |
| --- | --- | --- |
| ≥ 45 | OK | No action |
| 30–45 | SOFT_WARNING | Display informational warning |
| 20–30 | HARD_WARNING | Force intake upward to EA = 30 (Formula 18) |
| < 20 | BLOCK | Do not generate plan. Display urgent health warning. |

### 18. eaOverride(carb, prot, fat, session_kcal, ffm_kg, weight_kg)

When EA is 20–30, force intake up to EA = 30. Split deficit 60% carb / 40% fat. Protein unchanged.

```
intake = carb × 4 + prot × 4 + fat × 9
ea = (intake − session_kcal) / ffm_kg

if ea ≥ 30:  return { carb, prot, fat, adjusted: false }
if ea < 20:  return BLOCK

min_intake = 30 × ffm_kg + session_kcal
deficit = min_intake − intake

carb += (deficit × 0.6) / 4
fat  += (deficit × 0.4) / 9

return { carb: round(carb), prot, fat: round(fat), adjusted: true }
```

### 19. multiSessionCarbCompound(sessions, weight_kg)

When 2+ sessions occur on the same day, each subsequent endurance session's carb demand is scaled by 1.1× per position. Strength sessions are not compounded. Protein bump remains max-override.

```
sorted = sessions.sortBy(start_time)
total_carb = 0
endurance_index = 0
max_prot_bump = 0

for s in sorted:
  IF = zoneDistributionToIF(s)
  base_carb = carbDemand(IF, s.duration_hr, weight_kg)

  if s.sport in [RUNNING, CYCLING, SWIMMING]:
    compound_factor = 1.1 ^ endurance_index    // 1.0, 1.1, 1.21, ...
    total_carb += base_carb × compound_factor
    endurance_index += 1
  else:  // STRENGTH
    total_carb += base_carb                     // no compounding

  // Protein bump: max override (same as Iter 1)
  if s.sport == STRENGTH:
    max_prot_bump = max(max_prot_bump, 0.3 × weight_kg)
  elif s.duration_hr > 1.0:
    max_prot_bump = max(max_prot_bump, 0.2 × weight_kg)

total_carb = min(total_carb, 12.0 × weight_kg)

return { session_carb: round(total_carb), prot_bump: round(max_prot_bump) }
```

Compounding factors: 1st endurance = ×1.0, 2nd = ×1.1, 3rd = ×1.21, 4th = ×1.331. Strength always ×1.0 regardless of position. `endurance_index` only increments for endurance sessions.

### 20. carbCycleAdjust(session_IF, session_duration_hr, opt_in, phase, baseline_carb, weight_kg)

On qualifying easy days, reduce carb baseline to 3.0 g/kg ("train low"). ALL four conditions must be true:

```
if not opt_in:                         return baseline_carb
if phase in [PEAK, RACE_WEEK]:         return baseline_carb
if session_IF > 0.80:                  return baseline_carb
if session_duration_hr > 1.25:         return baseline_carb   // 75 min

return 3.0 × weight_kg
```

Carb cycling applies to single-session days only. Multi-session days never qualify.

### 21. dailyMacros_v4 (updated assembly)

```
1.   Baseline (with carb cycling modification):
     base = baselineMacros(weight, lbm, age)
     carb = base.carb_g;  prot = base.prot_g
     If single session AND carb cycle qualifies:
       carb = carbCycleAdjust(IF, duration, opt_in, phase, carb, weight)

2.   Today's sessions (with compounding for multi-session):
     If 2+ sessions:
       compound = multiSessionCarbCompound(sessions, weight)
       session_carb = compound.session_carb
       prot_bump = compound.prot_bump
     Else:
       Single-session logic from Iter 1
     carb += session_carb;  prot += prot_bump

3–8. Unchanged from Iteration 3
     (recovery debt, pre-load, weekly, phase, clamp, TDEE+fat)

9.   NEW — EA Safety Check:
     intake = carb×4 + prot×4 + fat×9
     ea_result = checkEnergyAvailability(intake, session_kcal, ffm)
     If BLOCK: return error, do not generate plan
     If HARD_WARNING: override = eaOverride(carb, prot, fat, ...); apply

     Return { ..., ea: ea_result.ea, ea_status: ea_result.status }
```

---

## Test Cases

Test cases are provided in a separate file (`iteration4_tests.md`) and should be run after implementation is complete. All Iteration 1–3 tests must also still pass (with carb_cycle_opt_in=false).
