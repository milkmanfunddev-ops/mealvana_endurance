# SSOT — Daily Macros: Energy Availability Safety Gate (RED-S)

**Status: RATIFIED v1 (Xuan, 2026-08-14).** Recorded 2026-07-28; Source: Notion
`daily_macro_calc_iteration4_spec` (FFM derivation, Formulas 17–18). **Engine:** B.
**Conformance target:** `calculate-daily-macros/formulas/safety.ts` (name match only — not yet
diffed).

**This is the only section of Engine B that can refuse to produce a plan.** It is safety-relevant
and should be treated as such in vectoring and in any deviation ruling.

## The rule
> After the workout is paid for, enough energy has to be left over for the body to run on. If it
> isn't, we raise the target; if it's far too low, we don't generate a plan at all and warn.

---

## FFM derivation

```
if body_fat_pct provided:
  ffm = weight_kg × (1 − body_fat_pct / 100)
else:
  ffm = weight_kg × 0.85     # MALE
  ffm = weight_kg × 0.78     # FEMALE
```

Male 75 kg without BF% → 63.75 kg. Female 62 kg without BF% → 48.36 kg. When BF% is present, FFM
and LBM are the same quantity by the same formula.

---

## Formula 17 — `checkEnergyAvailability(intake_kcal, session_kcal, ffm_kg)`

```
ea = (intake_kcal − session_kcal) / ffm_kg      # kcal per kg FFM per day

if   ea ≥ 45:  status = OK
elif ea ≥ 30:  status = SOFT_WARNING
elif ea ≥ 20:  status = HARD_WARNING
else:          status = BLOCK
```

| EA | Status | Action |
|---|---|---|
| ≥ 45 | `OK` | none |
| 30 – 45 | `SOFT_WARNING` | display an informational warning; **do not** change the numbers |
| 20 – 30 | `HARD_WARNING` | force intake upward to EA = 30 (Formula 18) |
| < 20 | `BLOCK` | **do not generate a plan**; display an urgent health warning |

**Boundaries are inclusive at the lower edge (`≥`).** EA exactly 45.0 is `OK`, exactly 30.0 is
`SOFT_WARNING`, exactly 20.0 is `HARD_WARNING`. Tolerance ±1.0.

| intake | session | FFM | EA | status |
|---|---|---|---|---|
| 4368 | 1479 | 64 | 45.1 | `OK` |
| 3500 | 1000 | 64 | 39.1 | `SOFT_WARNING` |
| 2500 | 800 | 64 | 26.6 | `HARD_WARNING` |
| 1800 | 900 | 64 | 14.1 | `BLOCK` |
| 1500 | 0 | 64 | 23.4 | `HARD_WARNING` |
| 3780 | 900 | 64 | 45.0 | `OK` (boundary) |
| 2720 | 800 | 64 | 30.0 | `SOFT_WARNING` (boundary) |
| 2180 | 900 | 64 | 20.0 | `HARD_WARNING` (boundary) |

---

## Formula 18 — `eaOverride(carb, prot, fat, session_kcal, ffm_kg, weight_kg)`

Applies only in the `HARD_WARNING` band. Raises intake to exactly EA = 30, splitting the shortfall
**60 % carbohydrate / 40 % fat**. Protein is never altered.

```
intake = carb×4 + prot×4 + fat×9
ea     = (intake − session_kcal) / ffm_kg

if ea ≥ 30:  return { carb, prot, fat, adjusted: false }
if ea <  20: return BLOCK

min_intake = 30 × ffm_kg + session_kcal
deficit    = min_intake − intake

ceiling  = 12.0 × weight_kg                       # the same clamp assembly step 9 applied
carb_add = (deficit × 0.6) / 4

if carb + carb_add > ceiling:                     # Q-006 RULED (Xuan, 2026-08-13)
    overflow_kcal = (carb + carb_add − ceiling) × 4
    carb          = ceiling
    fat          += (deficit × 0.4 + overflow_kcal) / 9
else:
    carb += carb_add
    fat  += (deficit × 0.4) / 9

return { carb: round(carb), prot, fat: round(fat), adjusted: true }
```

The ceiling branch makes the source's own edge-case row ("carb at ceiling → override adds to fat
only") true of the formula body. Energy is conserved either way — the redirected kcal land in fat at
9 kcal/g — so the post-override EA is exactly 30.0 on both paths. Protein is never touched, so the
protein ceiling cannot bind here.

Worked (reference athlete, FFM 64): carb 250 / prot 115 / fat 60, session 208 kcal.
`intake = 2000`, `ea = (2000 − 208)/64 = 28.0` → HARD_WARNING.
`min_intake = 30×64 + 208 = 2128`, `deficit = 128`.
`carb += 128×0.6/4 = 19.2 → 269`; `fat += 128×0.4/9 = 5.7 → 66`. New EA = exactly 30.0. ✓

| carb / prot / fat | session | EA before | result |
|---|---|---|---|
| 250 / 115 / 60 | 208 | 28.0 | carb 269, fat 66; EA → 30.0 |
| 200 / 100 / 55 | 543 | 18.0 | **BLOCK** — plan not generated |
| 500 / 140 / 120 | 300 | **52.2** | no change (EA ≥ 45) |
| 400 / 130 / 90 | 200 | **42.7** | no change (EA ≥ 30) |

The last two rows' EA values are **corrected** from the source page (which printed 46.3 and 40.3 —
neither reconciles with the formula at FFM 64, nor with any plausible alternative FFM). Recomputed
per [Q-008](OPEN-QUESTIONS.md#q-008), ruled 2026-08-13; outcomes were unaffected either way.

### Formerly gaps — both RULED (Xuan, 2026-08-13)

- **Carb ceiling — CLOSED.** The branch is now in the formula body above ([Q-006]
  (OPEN-QUESTIONS.md#q-006)). The source's edge-case table asserted the intended behaviour all
  along; the formula simply lacked it.
- **No downstream recompute — RULED as the contract.** TDEE, TEF and the fat residual are **not**
  recomputed after the override ([Q-009](OPEN-QUESTIONS.md#q-009)). Rationale: the override
  enforces a *floor* (EA = 30); it is not a better energy estimate, and recomputing opens a
  fat→intake→TEF→TDEE→fat convergence loop with no stopping rule. The returned `tdee` and
  `tef_kcal` therefore describe the **pre-override** macros, and the plan's `energy_basis` field is
  set to `"pre_override"` (else `"as_computed"`) so no consumer can present them as describing the
  delivered plan. The drawer/explanation layer MUST respect this — an athlete whose plan was raised
  by the safety gate sees intake above the stated TDEE, and that is correct, not a bug.

## Constants — provenance

| Constant | Value | Provenance |
|---|---|---|
| EA `OK` threshold | 45 kcal/kg FFM/day | **Uncited** in the SSOT doc. 45 is the widely used "optimal EA" figure and 30 the low-EA threshold in the RED-S / relative-energy-deficiency literature, but the page names no source |
| EA `SOFT_WARNING` threshold | 30 | as above |
| EA `BLOCK` threshold | 20 | **Uncited** |
| override target | EA = 30 | **Uncited** — a design choice to restore to the low-EA line, not to optimal |
| deficit split | 60 % carb / 40 % fat | **Uncited** |
| FFM estimate (male) | 0.85 × weight | **Uncited** |
| FFM estimate (female) | 0.78 × weight | **Uncited** |

Given this section can block a plan on health grounds, obtaining real citations for the three
thresholds should be a ratification prerequisite, not a follow-up.
