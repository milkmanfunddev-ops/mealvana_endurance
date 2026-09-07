# SSOT — Daily Macros: Session Intensity, Energy Cost & Carb Demand

**Status: RATIFIED v1 (Xuan, 2026-08-14).** Recorded 2026-07-28; Source: Notion
`daily_macro_calc_iteration1_spec` (Formulas 3, 4, 5) and `daily_macro_calc_iteration4_spec`
(Formula 19). **Engine:** B. **Conformance target:**
`calculate-daily-macros/formulas/session.ts` (name match only — not yet diffed).

## The rule
> Each workout is reduced to a single intensity number, which drives both how many calories it
> burns and how many grams of carbohydrate it demands. Back-to-back endurance sessions on the same
> day demand progressively more.

---

## Formula 3 — `zoneDistributionToIF`

Collapses the three-bucket intensity split into one Intensity Factor, **square-weighted (RMS)** so
that hard minutes count disproportionately.

```
IF = sqrt(pct_conv × 0.68² + pct_tempo × 0.88² + pct_allout × 1.08²)
```

The three constants are the IF midpoints of each zone bucket. Because the weights are squared and
the percentages sum to 1, a pure-single-bucket distribution returns that bucket's midpoint exactly.

**Input validation is part of this formula:** the three percentages must sum to 1.0 within float
tolerance. `0.70 / 0.20 / 0.20` (sum 1.1) and `0 / 0 / 0` must be **rejected**, not normalized.

| Conv / Tempo / AllOut | IF |
|---|---|
| 100 / 0 / 0 | 0.680 |
| 0 / 100 / 0 | 0.880 |
| 0 / 0 / 100 | 1.080 |
| 70 / 20 / 10 | 0.771 |
| 30 / 40 / 30 | 0.894 |
| 50 / 0 / 50 | 0.902 |
| 70 / 20 / 20 | **reject** |
| 0 / 0 / 0 | **reject** |

Tolerance on IF: ±0.005.

---

## Formula 4 — `sessionCost` → kcal

```
BASE_RATE = { RUNNING: 11, CYCLING: 9, SWIMMING: 7, STRENGTH: 5 }   # kcal per kg per hour at IF 0.75

base = BASE_RATE[sport] × weight_kg

endurance (RUNNING, CYCLING, SWIMMING):
  kcal = base × (IF / 0.75)² × duration_hr        # quadratic in intensity
strength:
  kcal = base × (IF / 0.75)  × duration_hr        # linear in intensity
```

`0.75` is the reference IF at which the base rate applies. Endurance cost scales with the **square**
of relative intensity; strength scales linearly.

**Cost is exactly linear in body weight** — the source tests assert the ratio column holds exactly
(60 kg : 75 kg : 90 kg = 0.800 : 1.000 : 1.200), which is a stronger check than a tolerance band.

| Sport, duration, IF (75 kg) | kcal |
|---|---|
| running, 1.5 hr, 0.74 | 1205 |
| cycling, 1.25 hr, 0.93 | 1297 |
| cycling, 4.0 hr, 0.72 | 2488 |
| strength, 1.0 hr, 0.70 | 350 |
| running, 0.75 hr, 0.65 | 465 |
| running, 1.5 hr, 0.74 @ 60 kg | 964 |
| running, 1.5 hr, 0.74 @ 90 kg | 1446 |

---

## Formula 5 — `carbDemand` → grams

**Strength branch — RULED (Xuan, 2026-08-13, Q-003):** strength sessions do **not** use the
intensity ladder. They use a flat, intensity-independent rate:

```
if sport == STRENGTH:
    return 27 × duration_hr × (weight_kg / 75)     # IF ignored; no ×1.15 multiplier
```

The literature basis, in brief: resistance-exercise glycogen depletion tracks **duration and set
count, not load** (Robergs 1991 — identical depletion at 35 % and 70 % 1RM for equal work;
Hamidvand 2025 meta-analysis, 20 studies — depletion scales with minutes and sets and *falls* with
%1RM), so an intensity multiplier has the wrong shape. Whole-body glycogen cost of a moderate-hard
RT hour is ~25–45 g (Hamidvand 2025 converted to grams; MacDougall 1999), and 27 g/hr sits inside
that band. IF itself is an endurance construct (NP/FTP) with no gym meaning — TrainingPeaks scores
strength as a flat per-hour stress. **Tagging:** the *structure* (reduced flat rate, intensity-
independent) is research-derived, confidence B−; the *number* 27 is a Mealvana design choice
(defensible range 15–40 g/hr; no source publishes a per-hour RT figure), confidence C. This ruling
vindicates the Iteration 4 test row (27 + 69 = 96) and makes Iteration 1's full-day strength carb
(300 + 40 = 340) the stale cell — corrected in `assembly.md`.

**Endurance sports (RUNNING, CYCLING, SWIMMING)** — three steps.

**Step 1 — oxidation rate by intensity.** Piecewise-linear interpolation through anchor points,
expressed as g/hr for a **75 kg reference athlete**:

| IF | g/hr |
|---|---|
| 0.55 | 25 |
| 0.70 | 40 |
| 0.80 | 55 |
| 0.90 | 75 |
| 1.00 | 95 |
| 1.10 | 115 |

Clamped flat outside the table: below IF 0.55 → 25 g/hr; above IF 1.10 → 115 g/hr.

**Step 2 — duration and weight scaling:**
```
raw = rate_g_per_hr × duration_hr × (weight_kg / 75)
```

**Step 3 — long/intense multiplier:**
```
if duration_hr > 1.5 OR IF > 0.85:  return raw × 1.15
else:                                return raw
```

Both thresholds are **strict**: `duration = 1.5` exactly does **not** trigger; `IF = 0.85` exactly
does **not** trigger. The multiplier is applied once, not once per triggering condition.

| IF, duration (75 kg) | raw | after ×1.15 | multiplier? |
|---|---|---|---|
| 0.65, 0.75 hr | 26 | 26 | no (IF ≤ 0.85, dur ≤ 1.5) |
| 0.74, 1.5 hr | 69 | 69 | no (dur = 1.5, not > 1.5) |
| 0.88, 2.0 hr | 142 | 163 | yes (IF > 0.85) |
| 0.93, 1.25 hr | 101 | 116 | yes (IF > 0.85) |
| 0.72, 4.0 hr | 172 | 198 | yes (dur > 1.5) |
| 0.74, 1.5 hr @ 60 kg | — | 55 | no |
| 0.74, 1.5 hr @ 90 kg | — | 83 | no |
| 0.88, 2.0 hr @ 60 kg | — | 131 | yes |
| 0.88, 2.0 hr @ 90 kg | — | 196 | yes |

---

## Protein bump from today's sessions (Iteration 1, assembly step 3d)

A **max-override across sessions, never a sum**:

```
bump = 0
for each session:
  if sport == STRENGTH:        bump = max(bump, 0.3 × weight_kg)
  elif duration_hr > 1.0:      bump = max(bump, 0.2 × weight_kg)
```

Strength qualifies on sport alone, at any duration. The endurance trigger is strictly `> 1.0 hr`.
A strength hour plus a 1.5 hr run yields `max(22.5, 15) = 22.5 g`, not 37.5 g.

---

## Formula 19 — `multiSessionCarbCompound`

When **two or more** sessions occur on the same day, each subsequent *endurance* session's carb
demand is scaled by 1.1 per position. Strength never compounds and never advances the counter.

```
sorted = sessions.sortBy(start_time)
total_carb = 0;  endurance_index = 0;  max_prot_bump = 0

for s in sorted:
  IF        = zoneDistributionToIF(s)
  base_carb = carbDemand(IF, s.duration_hr, weight_kg)

  if s.sport in [RUNNING, CYCLING, SWIMMING]:
    total_carb += base_carb × 1.1 ^ endurance_index      # 1.0, 1.1, 1.21, 1.331, 1.4641 …
    endurance_index += 1
  else:                                                  # STRENGTH
    total_carb += base_carb                              # ×1.0, index unchanged

  if s.sport == STRENGTH:     max_prot_bump = max(max_prot_bump, 0.3 × weight_kg)
  elif s.duration_hr > 1.0:   max_prot_bump = max(max_prot_bump, 0.2 × weight_kg)

total_carb = min(total_carb, 12.0 × weight_kg)           # local cap, see note
return { session_carb: total_carb, prot_bump: max_prot_bump }    # UNROUNDED — see below
```

**Notes on this formula as written:**
- It applies the `12.0 × weight_kg` ceiling to the **session contribution alone**, before the
  baseline is added — while the assembly applies the same ceiling again to the total. The local cap
  is therefore redundant except in pathological cases. Recorded as-is.
- **RULED (Xuan, 2026-08-13, Q-002):** the source's `round()` on both return values is **removed**.
  Formula 19 returns unrounded, like the single-session path; rounding happens once, at assembly
  step 12, consistent with [R1](README.md#cross-cutting-rules). The table below shows the unrounded
  sums; the integers previously published (169, 222) are what step 12 produces from them — the
  ruling changes no end-of-pipeline number in these rows, only where the rounding happens. (It can
  shift a published multi-session expectation by ~1 g where a mid-pipeline round previously
  swallowed a fraction, e.g. `prot_bump = 22.5` now survives to the total.)

| Sessions (time order, 75 kg) | Compounding | session carb | prot bump |
|---|---|---|---|
| bike 2 hr IF 0.80, run 0.75 hr IF 0.78 | ×1.0, ×1.1 | 126.5 + 42.9 = **169** | 15 |
| swim 0.5 hr IF 0.70, bike 2 hr IF 0.80, run 1 hr IF 0.78 | ×1.0, ×1.1, ×1.21 | 20 + 139.2 + 62.9 = **222** | 15 |
| strength 1 hr IF 0.70, run 1.5 hr IF 0.74 | ×1.0 (no compound), ×1.0 (1st endurance) | 27 + 69 = **96** (strength flat rate — Q-003 RULED) | 22.5 |
| single: run 1.5 hr IF 0.74 | n/a | **69** | 15 |

The strength + run row previously disagreed with the source test table (formula said 40 + 69 = 109;
the table said 96). **RULED** — the table was right and encoded an unwritten rule: strength uses the
flat 27 g/hr rate above. [Q-003](OPEN-QUESTIONS.md#q-003).

## Constants — provenance

| Constant | Value | Provenance |
|---|---|---|
| zone IF midpoints | 0.68 / 0.88 / 1.08 | **Uncited**; described as "the IF midpoints for each zone bucket" |
| base metabolic rates | 11 / 9 / 7 / 5 kcal·kg⁻¹·hr⁻¹ | **Uncited** |
| reference IF | 0.75 | **Uncited** |
| endurance exponent | 2 (quadratic) | **Uncited** |
| strength exponent | 1 (linear) | **Uncited** |
| carb oxidation anchors | 25…115 g/hr | **Uncited**. The 90–120 g/hr top end is in the range modern multiple-transportable-carbohydrate research supports, but the SSOT asserts no source |
| reference weight | 75 kg | **Uncited** |
| long/intense multiplier | ×1.15 | **Uncited** |
| multiplier triggers | dur > 1.5 hr, IF > 0.85 | **Uncited** |
| compounding factor | 1.1 per endurance position | **Uncited** |
| strength flat carb rate | 27 g/hr @ 75 kg, IF-independent | **Structure research-derived** (Robergs 1991 PMID 2055849; Hamidvand 2025 PMC12717450; TrainingPeaks flat strength TSS); **number is a design choice** inside the 15–40 g/hr defensible band. Ruled Q-003, 2026-08-13 |
