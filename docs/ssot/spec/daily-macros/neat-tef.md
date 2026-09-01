# SSOT — Daily Macros: NEAT, TEF & TDEE

**Status: RATIFIED v1 (Xuan, 2026-08-14).** Recorded 2026-07-28; Source: Notion
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

**The fat ceiling lives downstream, not here (Q-014 — RULED 2026-08-13).** `calculateTDEE`
returns the *uncapped* residual; assembly step 10b then caps fat at `0.30 × tdee / 9` and
redistributes the excess energy to carbohydrate (up to the 12 g/kg clamp; corner case: fat keeps
the remainder rather than energy being dropped). The split keeps this formula's convergence
mathematics and its regression tables intact — **every fat value in the tables below is the
pre-cap residual**, and the returned plan's fat is `min(that, 0.30 × tdee / 9)`. Redistribution
conserves energy, so every TDEE and TEF cell below is also the returned value.

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
| Pre-race, all layers — 798 / 159, NEAT 378 | 2 | 437 | **4202** | **60 (floor)** |

Rest-day convergence trace: pass 1 `0 → 225` (Δ 225, continue) · pass 2 `225 → 248` (Δ 23,
continue) · pass 3 `248 → 250` (Δ 2, **stop**).
Fat-at-floor trace: pass 1 `0 → 261` (Δ 261, continue) · pass 2 `261 → 261` (Δ 0, **stop**).

The pre-race row is **corrected** ([Q-007](OPEN-QUESTIONS.md#q-007), ruled 2026-08-13): the source
page assumed a 1050 kcal session, but the scenario's run (1.5 hr IF 0.82) costs
`11 × 75 × (0.82/0.75)² × 1.5 = 1479 kcal` — the figure the Iteration 4 EA table already used
(intake 4368 → EA 45.1 only works with 1479). TDEE is therefore `1908 + 378 + 437 + 1479 = 4202`,
not the printed 3773. *Fat* and *TEF* were unaffected either way (fat at its floor pins intake).

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
| fat floor | 0.8 g/kg | **Uncited** as a number. Direction citable: Thomas 2016 discourages chronic fat intake < 20 %E |
| fat ceiling (step 10b) | 0.30 × tdee kcal, i.e. 30 %E | **Q-014, ruled 2026-08-13.** The number is ISSN 2018's recommended ~30 %E, inside the AMDR 20–35 %E; the redistribute-to-carb rule is research-derived (see Literature — Q-014 basis); the exact 0.30 (vs 0.35) is a Mealvana design choice within the cited band |

## Literature — Q-014 basis (fat ceiling & redistribution)

- **Thomas DT, Erdman KA, Burke LM.** *Position of the Academy of Nutrition and Dietetics,
  Dietitians of Canada, and the American College of Sports Medicine: Nutrition and Athletic
  Performance.* Med Sci Sports Exerc. 2016;48(3):543–568. PMID 26891166. Fat intake *"should be in
  accordance with public health guidelines"* (AMDR 20–35 %E); athletes *"should be discouraged from
  chronic implementation of fat intakes below 20% of energy"*. No load-scaling of fat anywhere in
  the stand; daily carbohydrate bands (3–5 / 5–7 / 6–10 / 8–12 g/kg by training volume, verified
  verbatim) are the load-scaled macro.
- **Kerksick CM, et al.** *ISSN exercise & sports nutrition review update.* J Int Soc Sports Nutr.
  2018;15:38. DOI 10.1186/s12970-018-0242-y. Recommends *"a moderate amount of fat (approximately
  30% of daily caloric intake)"* — the source of the 0.30; notes *"up to 50%"* is *safely
  tolerated* under high-volume training (a tolerance bound, not a recommendation).
- **Burke LM, et al.** *Low carbohydrate, high fat diet impairs exercise economy and negates the
  performance benefit from intensified training in elite race walkers.* J Physiol.
  2017;595(9):2785–2807. PMID 28012184. Replicated: **Burke LM, et al.** PLoS ONE.
  2020;15(6):e0234027. The evidence against high fat as a training-day strategy.
- **Impey SG, et al.** *Fuel for the work required: a theoretical framework for carbohydrate
  periodization.* Sports Med. 2018;48(5):1031–1048. Day-to-day energy variation is carried by
  carbohydrate; fat is absent from the periodization framework — the basis for redistributing the
  capped excess to carbohydrate specifically.
- **Heikura IA, et al.** *A mismatch between athlete practice and current sports nutrition
  guidelines among elite female middle- and long-distance athletes.* Int J Sport Nutr Exerc Metab.
  2017. PMID 28387576. Elite microperiodization moves carbohydrate, not fat, on hard days.
- **Saris WH, et al.** *Study on food intake and energy expenditure during extreme sustained
  exercise: the Tour de France.* Int J Sports Med. 1989;10(Suppl 1):S26–S31. ~6,000 kcal/day with
  fat held near 23 %E and the surplus carried as carbohydrate. *(Volume/pages per secondary
  sources; PMID not verified.)*
- **Mountjoy M, et al.** *IOC consensus statement on relative energy deficiency in sport (RED-S):
  2018 update.* Br J Sports Med. 2018;52(11):687–697. Low energy availability harms performance,
  bone, immunity — the basis for the corner-case rule that energy is never dropped.
- **Fahrenholtz IL, et al.** *Within-day energy deficiency and reproductive function in female
  endurance athletes.* Scand J Med Sci Sports. 2018;28(3):1139–1146. PMID 29205517. Hours in
  within-day deficit associate with elevated cortisol and menstrual dysfunction — dropping energy
  on the heaviest days concentrates the deficit exactly where risk is highest.
