# SSOT — Daily Macros: Resting Metabolic Rate

**Status: RECORDED — awaiting ratification** (2026-07-28). Source: Notion
`daily_macro_calc_iteration1_spec` (Formula 1) and `daily_macro_calc_iteration5_spec`
(Formula 24). **Engine:** B. **Conformance target:** `calculate-daily-macros/formulas/rmr.ts`
(name match only — not yet diffed).

## The rule
> Your resting burn is measured if a device reports it, computed from lean mass if we know your
> body-fat percentage, and estimated from height/weight/age otherwise.

## The math (Formula 1 — `calculateRMR`)

Two formulas, selected by data availability. **Cunningham takes priority whenever LBM is known.**

```
LBM_kg = weight_kg × (1 − body_fat_pct / 100)      # only if body_fat_pct provided

if LBM known:                                       # Cunningham
  RMR = 500 + 22 × LBM_kg
else:                                               # Mifflin-St Jeor
  RMR = 10 × weight_kg + 6.25 × height_cm − 5 × age + (5 if MALE else −161)
```

## Source resolution (Formula 24 — `resolveRMR`)

```
if garmin_daily.BmrKilocalories exists:
  rmr = garmin value;         source = GARMIN
else:
  rmr = calculateRMR(athlete); source = FORMULA
```

Not gated on `mode` as written — see [Q-011](OPEN-QUESTIONS.md#q-011). If Garmin body composition
supplies a fresh `weight_kg` / `body_fat_pct`, the athlete profile is updated **before** RMR is
computed, so the new values propagate (see [`platform-resolution.md`](platform-resolution.md)).

## Constants — provenance

| Constant | Value | Provenance |
|---|---|---|
| Cunningham intercept | 500 | Named "Cunningham" in the Iteration 1 test page; **no citation in the SSOT doc** |
| Cunningham LBM coefficient | 22 kcal/kg LBM | as above |
| Mifflin-St Jeor coefficients | 10 / 6.25 / −5 | Named in the SSOT doc; standard published Mifflin-St Jeor |
| Mifflin sex offset | +5 MALE / −161 FEMALE | as above |

Neither formula carries a citation on the Notion page. Both are well-known published equations,
but this department records what the SSOT says: **provenance is asserted by name, not referenced.**
Flagged for ratification.

## Worked examples (verified)

| Input | RMR | Path |
|---|---|---|
| Male 75 kg, 178 cm, 34 yr, BF 14.7 % (LBM 64) | **1908** | Cunningham: 500 + 22 × 64 |
| Male 75 kg, 178 cm, 34 yr, no BF | **1698** | Mifflin: 750 + 1112.5 − 170 + 5 = 1697.5 |
| Female 62 kg, 165 cm, 29 yr, no BF | **1345** | Mifflin: 620 + 1031.25 − 145 − 161 = 1345.25 |
| Male 75 kg, BF **0 %** (edge) | **2150** | LBM = weight; 500 + 22 × 75. Must not error |
| Garmin `BmrKilocalories = 1920`, LBM known | **1920** | Garmin wins over Cunningham |

The reference athlete used throughout the source test pages is **male, 34 yr, 75 kg, 178 cm,
BF 14.7 % → LBM 64 kg, RMR 1908**.

## Tolerances (from the source test pages)
TDEE ±5 %. RMR itself is exact-checkable; the tolerance exists for the downstream chain.
