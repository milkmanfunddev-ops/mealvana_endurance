# SSOT — Daily Macros: NEAT, TEF & TDEE

**Status: RECORDED — awaiting ratification** (2026-07-28). Source: Notion
`daily_macro_calc_iteration3_spec` (Formulas 12–15) and `daily_macro_calc_iteration5_spec`
(CTL tier table). **Engine:** B. **Conformance target:**
`calculate-daily-macros/formulas/neat-tef.ts` (name match only — not yet diffed).

## The rule
> Everything you burn that isn't your resting rate and isn't the workout itself — fidgeting,
> commuting, standing, digesting — is modelled explicitly instead of assumed to be a flat 25 %.

**Lineage:** Iterations 1–2 used a fixed `TDEE = RMR × 1.25 + session_kcal`. Iteration 3 replaced
that entirely. The fixed multiplier is **superseded** and is not the SSOT; it survives only as the
baseline in the v2-vs-v3 regression tables.

---

## Formula 12 — `inferVolumeTier(typical_weekly_hours)`

Higher training volume implies a *lower* NEAT fraction — serious athletes rest more between
sessions.

| Weekly hours | Tier | `base_neat` |
|---|---|---|
| `< 5` | `RECREATIONAL` | 0.30 |
| `≥ 5, < 8` | `MODERATE` | 0.25 |
| `≥ 8, < 12` | `SERIOUS` | 0.20 |
| `≥ 12, < 18` | `HIGH_VOLUME` | 0.17 |
| `≥ 18` | `PROFESSIONAL` | 0.13 |

`null` → `MODERATE` (0.25). `0` hours → `RECREATIONAL` (it is `< 5`, not a null). Boundaries are
inclusive at the lower edge: 4.9 → RECREATIONAL, 5.0 → MODERATE, 8.0 → SERIOUS, 12.0 →
HIGH_VOLUME, 18.0 → PROFESSIONAL.

### CTL variant (Iteration 5)
When TrainingPeaks supplies CTL, it **replaces** weekly hours as the tier input:

| CTL | Tier | `base_neat` |
|---|---|---|
| `< 30` | `RECREATIONAL` | 0.30 |
| `≥ 30, < 55` | `MODERATE` | 0.25 |
| `≥ 55, < 85` | `SERIOUS` | 0.20 |
| `≥ 85, < 120` | `HIGH_VOLUME` | 0.17 |
| `≥ 120` | `PROFESSIONAL` | 0.13 |

CTL 0 → RECREATIONAL. Stale CTL (> 30 days old) is used anyway — staleness detection is explicitly
deferred by the SSOT.

---

## Formula 13 — `getDayModifier(today_sessions, yesterday_tss)`

**First match wins**, evaluated top to bottom:

| Condition | Day type | Modifier |
|---|---|---|
| 2+ sessions today | `DOUBLE` | 1.15 |
| ≥ 1 session today with duration ≥ 0.75 hr | `TRAINING` | 1.10 |
| no sessions today AND `yesterday_tss ≥ 150` | `REST_AFTER_HARD` | 0.90 |
| everything else | `REST` | 1.00 |

Reading the ordering carefully: a day with **one short session (< 0.75 hr) after a hard
yesterday** falls through to `REST` (1.00), *not* `REST_AFTER_HARD` — because the third rule
requires zero sessions. One session of exactly 0.75 hr is `TRAINING`. `yesterday_tss = null` with
no sessions is `REST`.

`yesterday_tss` is the **sum** across yesterday's sessions, per the Q-013 ruling — see
[`multi-day-context.md`](multi-day-context.md#aggregation-when-yesterday-had-multiple-sessions).
This is the second consumer of the ≥ 150 threshold, so a double yesterday that clears the gate
flips `REST` → `REST_AFTER_HARD` here as well as switching on recovery debt, moving NEAT by −10 %.

---

## Formula 14 — `calculateNEAT(rmr, volume_tier, day_modifier, lifestyle)`

```
LIFESTYLE_MOD = { DESK: 0.90, MIXED: 1.00, ACTIVE: 1.15, VERY_ACTIVE: 1.25 }

neat_factor = base_neat[volume_tier] × day_modifier × LIFESTYLE_MOD[lifestyle]
NEAT        = rmr × neat_factor
```

Purely multiplicative, no clamp. Observed range across legal combinations: 0.105
(pro / rest-after-hard / desk) to 0.431 (recreational / double / very active) — i.e. 201 to
822 kcal at RMR 1908, both stated as valid by the SSOT.

| Tier × day × lifestyle (RMR 1908) | factor | NEAT |
|---|---|---|
| 0.20 × 1.00 × 0.90 — serious, rest, desk | 0.180 | 343 |
| 0.20 × 1.10 × 0.90 — serious, training, desk | 0.198 | 378 |
| 0.20 × 0.90 × 0.90 — serious, rest-after-hard, desk | 0.162 | 309 |
| 0.30 × 1.00 × 1.15 — recreational, rest, active | 0.345 | 658 |
| 0.13 × 1.15 × 1.00 — pro, double, mixed | 0.149 | 285 |
| 0.20 × 1.00 × 1.00 — serious, rest, mixed | 0.200 | 382 |

In retrospective mode with a Garmin daily summary, NEAT is **measured, not modelled** — see
[`platform-resolution.md`](platform-resolution.md), Formula 23.

---

## Formula 15 — `calculateTDEE(...)` — iterative TEF

**The circularity.** `TDEE = RMR + NEAT + TEF + session_kcal`, but `TEF = intake × 0.10`, and
intake includes fat, and fat is the residual `(TDEE − carb×4 − prot×4) / 9`. TDEE depends on
itself.

**The resolution.** Iterate to a fixed point, starting from TEF = 0.

```
function calculateTDEE(rmr, neat, session_kcal, carb_g, prot_g, weight_kg):
  fat_floor  = 0.8 × weight_kg
  tef        = 0
  max_passes = 5                        # safety limit; never reached in practice

  for pass in 1..max_passes:
    tdee    = rmr + neat + tef + session_kcal
    fat     = max((tdee − carb_g×4 − prot_g×4) / 9, fat_floor)
    intake  = carb_g×4 + prot_g×4 + fat×9
    new_tef = intake × 0.10

    delta = abs(new_tef − tef)
    tef   = new_tef
    if delta < 10: break               # converged

  tdee = rmr + neat + tef + session_kcal      # recompute with the converged TEF
  fat  = max((tdee − carb_g×4 − prot_g×4) / 9, fat_floor)
  return { tdee: round(tdee), fat_g: round(fat), tef: round(tef), neat_kcal: round(neat) }
```

**Convergence is geometric.** A kcal of TEF change produces only ~0.11 kcal of further TEF change
(TEF is 10 % of intake; fat absorbs the change at 9 kcal/g). Typical deltas: pass 1 ≈ 225–440,
pass 2 ≈ 23–35, pass 3 ≈ 2–4.

**Two regimes:**
- **Fat above its floor** — intake tracks TDEE exactly, so the loop converges to the closed form
  `TDEE = (RMR + NEAT + session_kcal) / 0.9`. Typically **3 passes**.
- **Fat clamped at the floor** — intake is fixed regardless of TDEE, so TEF is identical on every
  pass and `delta = 0` on pass 2. Exactly **2 passes**. This is the carb-loading case.

**The stopping rule is observable and must be implemented as a loop.** Because `delta < 10` exits
*before* the exact fixed point, the returned TDEE lands a few kcal short of the closed form —
e.g. rest-day desk returns **2501**, while `(1908 + 343.4) / 0.9 = 2501.6`. An implementation that
computes the closed form directly, or that hardcodes "exactly 2 passes", is **wrong** and will
miss by an amount large enough to see. The source test page calls this out explicitly as the key
test. 4+ passes has never been observed.

| Scenario (carb / prot / session, NEAT) | passes | TEF | TDEE | fat |
|---|---|---|---|---|
| Rest day — 300 / 115 / 0, NEAT 343 | 3 | 250 | 2501 | 93 |
| 90-min run — 369 / 130 / 1205, NEAT 378 | 3 | 388 | 3879 | 209 |
| Rest after long ride — 394 / 123 / 0, NEAT 309 | 2 | 261 | 2478 | **60 (floor)** |
| Pre-race, all layers — 798 / 159, NEAT 378 | 2 | 437 | 3773 | **60 (floor)** |

Rest-day convergence trace: pass 1 `0 → 225` (Δ 225, continue) · pass 2 `225 → 248` (Δ 23,
continue) · pass 3 `248 → 250` (Δ 2, **stop**).
Fat-at-floor trace: pass 1 `0 → 261` (Δ 261, continue) · pass 2 `261 → 261` (Δ 0, **stop**).

The pre-race row assumes a session cost of 1050 kcal, which does not match the 1479 kcal that the
same scenario's session produces elsewhere in the source — see
[Q-007](OPEN-QUESTIONS.md#q-007). The *fat* and *TEF* values are unaffected (fat is at its floor,
so intake is fixed) but the TDEE is.

### Lifestyle sensitivity (rest day, serious tier, RMR 1908)
| Lifestyle | NEAT | TDEE | fat |
|---|---|---|---|
| `DESK` (0.90) | 343 | 2501 | 93 |
| `MIXED` (1.00) | 382 | 2544 | 98 |
| `ACTIVE` (1.15) | 439 | 2608 | 105 |
| `VERY_ACTIVE` (1.25) | 477 | 2650 | 110 |

### Invariant: carb and protein are untouched by this section
v2 → v3 changes **only** TDEE and fat. Carb and protein must be bit-identical. This is the
regression the source test page pins:

| Scenario | v2 TDEE | v3 TDEE | v2 fat | v3 fat |
|---|---|---|---|---|
| Rest day, desk | 2385 | 2501 | 81 † | 93 |
| 90-min run, desk | 3590 | 3879 | 177 | 209 |
| Rest after hard, desk | 2385 | 2478 | 60 (floor) | 60 (floor) |
| Active-job rest day | 2385 | 2608 | 81 † | 105 |

† The Iteration 1 test page gives 80 g for the same rest day. The discrepancy is rounding of
intermediate protein — see [Q-001](OPEN-QUESTIONS.md#q-001).

---

## The `mode` parameter

`PROSPECTIVE` and `RETROSPECTIVE` run **identical math** in Iteration 3. The only difference is
which session data is passed in — planned vs user-corrected. Same inputs must produce byte-identical
output in either mode; `mode` is echoed in the return object. It exists as infrastructure for the
Iteration 5 platform integration, where the two modes start drawing on different sources.

## Constants — provenance

| Constant | Value | Provenance |
|---|---|---|
| `base_neat` by tier | 0.30 / 0.25 / 0.20 / 0.17 / 0.13 | **Uncited** |
| volume-hour boundaries | 5 / 8 / 12 / 18 hr | **Uncited** |
| CTL boundaries | 30 / 55 / 85 / 120 | **Uncited** |
| day modifiers | 1.15 / 1.10 / 0.90 / 1.00 | **Uncited** |
| `TRAINING` duration gate | 0.75 hr | **Uncited** |
| lifestyle modifiers | 0.90 / 1.00 / 1.15 / 1.25 | **Uncited** |
| TEF fraction | 0.10 of intake | **Uncited**; 10 % is the conventional mixed-diet TEF figure |
| convergence threshold | delta < 10 kcal | **Mealvana implementation choice** — the doc presents it as a stopping rule, and it is observable in output |
| `max_passes` | 5 | **Mealvana implementation choice** — safety limit |
| fat floor | 0.8 g/kg | **Uncited** |
