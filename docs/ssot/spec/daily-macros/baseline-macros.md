# SSOT — Daily Macros: Baseline Macros & Carb Cycling

**Status: RECORDED — awaiting ratification** (2026-07-28). Source: Notion
`daily_macro_calc_iteration1_spec` (Formula 2) and `daily_macro_calc_iteration4_spec`
(Formula 20). **Engine:** B. **Conformance target:**
`calculate-daily-macros/formulas/baseline.ts` (name match only — not yet diffed).

## The rule
> Before any workout is counted, every athlete gets a floor of carbs and protein sized to body
> weight (or lean mass, if known), with a bump for masters athletes. Athletes who opt in can trade
> that carb floor down on genuinely easy days ("train low").

## The math (Formula 2 — `baselineMacros`)

```
carb_g = 4.0 × weight_kg

prot_g = 1.8 × LBM_kg        if LBM known
       = 1.4 × weight_kg     if LBM unknown
if age ≥ 45: prot_g × = 1.15         # masters

fat_g  = 1.2 × weight_kg     # baseline only — always overridden by the fat residual
```

`fat_g` here is vestigial: the assembly always recomputes fat as the energy residual
(see [`neat-tef.md`](neat-tef.md)). It is recorded because the SSOT states it, but it never
reaches the output.

**Masters boundary is `≥ 45`, strictly.** Age 44 gets no multiplier; age 45 does.

## Carb cycling (Formula 20 — `carbCycleAdjust`)

Replaces the `4.0 × weight_kg` carb baseline with `3.0 × weight_kg` on qualifying easy days.
**All four conditions must hold**; any one failing returns the baseline unchanged.

```
if not carb_cycle_opt_in:            return baseline_carb
if phase in [PEAK, RACE_WEEK]:       return baseline_carb
if session_IF > 0.80:                return baseline_carb
if session_duration_hr > 1.25:       return baseline_carb    # 75 min

return 3.0 × weight_kg
```

Gating details that the test tables pin explicitly:
- **Single-session days only.** Two or more sessions never qualify, regardless of how easy each is.
- **Zero-session days never qualify** — there is no session to evaluate, so cycling does not fire
  and the baseline stays `4.0 × weight_kg`.
- Boundaries are inclusive on the qualifying side: `IF = 0.80` qualifies, `IF = 0.81` does not;
  `duration = 1.25 hr` qualifies, `1.267 hr` does not.
- Allowed in `BASE`, `BUILD`, `TAPER`, `OFF_SEASON`. Blocked only in `PEAK` and `RACE_WEEK`.
- Cycling reduces the **baseline**; session carb demand and recovery debt still add on top of the
  reduced figure.

## Constants — provenance

| Constant | Value | Provenance |
|---|---|---|
| carb baseline | 4.0 g/kg body weight | **Uncited** in the SSOT doc |
| protein baseline (LBM known) | 1.8 g/kg LBM | **Uncited** |
| protein baseline (no LBM) | 1.4 g/kg body weight | **Uncited** |
| masters multiplier | ×1.15 at age ≥ 45 | **Uncited** |
| fat baseline | 1.2 g/kg | **Uncited**; never observable in output |
| train-low carb baseline | 3.0 g/kg | **Uncited**; equals the carb floor clamp |
| cycling IF ceiling | 0.80 | **Uncited** |
| cycling duration ceiling | 1.25 hr (75 min) | **Uncited** |

Every constant in this section is unsourced on the Notion page. None is separated into
"research-derived" vs "Mealvana design choice" — that classification is exactly what ratification
needs to settle.

## Worked examples (verified, reference athlete 75 kg / LBM 64)

| Case | carb | prot |
|---|---|---|
| age 34, LBM 64 | 300 | 115.2 → **115** |
| age 45, LBM 64 | 300 | 115.2 × 1.15 = 132.5 → **132** |
| age 34, no BF% | 300 | 1.4 × 75 = **105** |
| age 45, no BF% | 300 | 105 × 1.15 = 120.75 → **121** |
| age 44, LBM 64 (boundary) | 300 | **115** — no multiplier |
| opt-in, IF 0.65, 0.75 hr, BASE | **225** | 115 |
| opt-in, IF 0.85, 0.75 hr, BASE | 300 (IF > 0.80) | 115 |
| opt-in, IF 0.70, 1.5 hr, BASE | 300 (dur > 1.25) | 115 |
| opt-in, IF 0.65, 0.75 hr, PEAK | 300 (phase blocked) | 115 |

Note the masters interaction with [R1](README.md#cross-cutting-rules): `115.2 × 1.15 = 132.48`
rounds to **132**, whereas pre-rounding to 115 first gives 132.25 → 132 as well. The two agree
here, but they do not agree in the fat residual — see [Q-001](OPEN-QUESTIONS.md#q-001).
