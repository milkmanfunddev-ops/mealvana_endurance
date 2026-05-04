> Mirrored from Notion: https://www.notion.so/daily_macro_calc_iteration3_spec-326e3fdb754c80d99433d3819468d900
> Last edited (Notion): 2026-03-17T17:25:00.000Z
> **Authoritative source is Notion.** Edit there and re-mirror.

# Macro Calculator — Iteration 3 Spec

Replaces the fixed 1.25× non-exercise multiplier with a dynamic NEAT model and explicit iterative TEF. Adds prospective/retrospective mode parameter. Steps 1–7 are unchanged from Iteration 2. Only Step 8 is replaced.

All Iteration 1–2 functions remain unchanged. This iteration adds 4 new formulas and updates the assembly function.

---

## New Inputs (in addition to Iterations 1–2)

### Athlete Profile (new onboarding fields)

| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| lifestyle | Enum: DESK, MIXED, ACTIVE, VERY_ACTIVE | No | MIXED | Set once at onboarding. UX labels: "Desk-based day" / "Mixed: some movement" / "On your feet most of the day" / "Physically demanding work" |
| typical_weekly_hours | float | No | null | Average training hours/week. Used to infer volume tier. If null, defaults to MODERATE tier. |

### System-Level

| Field | Type | Required | Default | Notes |
| --- | --- | --- | --- | --- |
| mode | Enum: PROSPECTIVE, RETROSPECTIVE | Yes | PROSPECTIVE | In Iter 3 both modes run identical math. The difference is which session data is passed in: planned (prospective) or user-corrected (retrospective). Infrastructure for Iter 5 Garmin integration. |

---

## New Formulas

### 12. inferVolumeTier(typical_weekly_hours)

| Weekly Hours | Volume Tier | base_neat |
| --- | --- | --- |
| < 5 | RECREATIONAL | 0.30 |
| ≥5 and < 8 | MODERATE | 0.25 |
| ≥8 and < 12 | SERIOUS | 0.20 |
| ≥12 and < 18 | HIGH_VOLUME | 0.17 |
| ≥ 18 | PROFESSIONAL | 0.13 |

If typical_weekly_hours is null → default to MODERATE (0.25).

### 13. getDayModifier(today_sessions, yesterday_tss)

Evaluate conditions in this order (first match wins):

| Condition | Day Type | Modifier |
| --- | --- | --- |
| 2+ sessions today | DOUBLE | 1.15 |
| 1+ session today with duration ≥ 0.75 hr | TRAINING | 1.10 |
| No sessions today AND yesterday_tss ≥ 150 | REST_AFTER_HARD | 0.90 |
| All other cases | REST | 1.00 |

### 14. calculateNEAT(rmr, volume_tier, day_modifier, lifestyle)

```
LIFESTYLE_MOD = { DESK: 0.90, MIXED: 1.00, ACTIVE: 1.15, VERY_ACTIVE: 1.25 }

neat_factor = base_neat[volume_tier] × day_modifier × LIFESTYLE_MOD[lifestyle]
NEAT = rmr × neat_factor
```

### 15. calculateTDEE(rmr, neat, session_kcal, carb_g, prot_g, weight_kg)

Replaces the fixed `rmr × 1.25 + session_kcal` from Iterations 1–2.

**The problem:** TDEE = RMR + NEAT + TEF + session_kcal. But TEF = total_intake × 0.10, and total_intake includes fat, and fat = (TDEE − carb×4 − prot×4) / 9. So TDEE depends on TEF, which depends on fat, which depends on TDEE. This is a circular dependency.

**The solution:** Iterate. Start by computing TDEE without TEF. Use that to estimate fat, then intake, then TEF. Plug TEF back in to get a better TDEE. Repeat until the TEF estimate stops changing meaningfully.

**What "delta" means:** The difference in TEF between consecutive passes: `delta = |tef_this_pass − tef_previous_pass|`. When delta is small enough, the answer has converged and further passes won't change the result.

**Why it always converges:** Each pass, TEF changes by a fraction of the previous change. Pass 1→2 might shift TEF by 35 kcal. Pass 2→3 would shift it by ~4 kcal. Pass 3→4 by ~0.4 kcal. The series converges geometrically because TEF is only 10% of intake, and fat (which absorbs the TDEE change) converts at 9 kcal/g — so each kcal of TEF change only produces ~0.11 kcal of further TEF change.

**Stopping rule:** Stop when `delta < 10 kcal`. In practice, 2 passes always suffice — the maximum observed delta after pass 2 is ~35 kcal (which would produce a pass 3 delta of ~4 kcal, well under threshold). But implement it as a loop with a stopping condition, not a hardcoded "do exactly 2 passes":

```
function calculateTDEE(rmr, neat, session_kcal, carb_g, prot_g, weight_kg):

  fat_floor = 0.8 × weight_kg
  prev_tef = 0
  tef = 0
  max_passes = 5           // safety limit; never actually reached

  for pass in 1..max_passes:
    tdee = rmr + neat + tef + session_kcal
    fat = max((tdee − carb_g×4 − prot_g×4) / 9,  fat_floor)
    intake = carb_g×4 + prot_g×4 + fat×9
    new_tef = intake × 0.10

    delta = abs(new_tef − tef)
    tef = new_tef

    if delta < 10:          // converged
      break

  // Final TDEE with converged TEF
  tdee = rmr + neat + tef + session_kcal
  fat = max((tdee − carb_g×4 − prot_g×4) / 9,  fat_floor)

  return { tdee: round(tdee), fat_g: round(fat), tef: round(tef), neat_kcal: round(neat) }
```

**Special case — fat at floor:** When carb and protein are so high that fat gets clamped to the floor (0.8 × weight), intake is fixed regardless of TDEE. This means TEF is the same on every pass, delta = 0 on pass 1, and the loop exits immediately. This happens on carb-loading days.

**Expected pass counts:**
- Fat at floor (carb-load days): 2 passes (pass 1 delta is large but pass 2 delta = 0 because intake is fixed)
- Normal days: 3 passes (pass 1 delta ~225, pass 2 delta ~23, pass 3 delta ~2)
- Never observed: 4+ passes

### 16. dailyMacros_v3 (updated assembly)

Steps 1–7 are identical to Iteration 2. Only Step 8 changes.

```
1–7. Run Iteration 2 Steps 1–7
     → yields: carb, prot (clamped), session_kcal, rmr

8.   Dynamic NEAT + iterative TEF (REPLACES fixed 1.25×):
     volume_tier = inferVolumeTier(athlete.typical_weekly_hours)
     day_mod = getDayModifier(sessions, yesterday_tss)
     neat = calculateNEAT(rmr, volume_tier, day_mod, athlete.lifestyle)
     result = calculateTDEE(rmr, neat, session_kcal, carb, prot, weight)
     fat = result.fat_g

9.   Return { carb_g, prot_g, fat_g, tdee, rmr, session_kcal,
              neat_kcal, tef_kcal, mode }
```

Key property: carb and protein are identical to Iteration 2 output. Only TDEE and fat change.

---

## Test Cases

Test cases are provided in a separate file (`iteration3_tests.md`) and should be run after implementation is complete. All Iteration 1–2 tests must also still pass.
