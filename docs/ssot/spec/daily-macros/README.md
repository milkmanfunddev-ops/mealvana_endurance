# SSOT — Daily Macro Calculation (Engine B)

**Status: RATIFIED v1 (Xuan, 2026-08-14).** Distilled 2026-07-28 from the Notion page
[Daily Macro Calculation](https://app.notion.com/p/326e3fdb754c80199486c17ecf9947cd) and its ten
child pages (five iterations × spec + tests). Nothing here has been ruled on by Xuan yet; this is
PLAN.md Phase 1 **step 2 (record)**. Step 3 (ratify) and step 4 (vector) come next.

**Engine:** B — daily macros. **Server-only** (`calculate-daily-macros` edge function); there is
no Dart mirror, so vectors will run against the edge function, not `OfflineMacroCalculator`.
**Explanation layer:** none identified yet (no results drawer for daily macros) — so the
two-layer conformance story is, for now, one layer: engine ⇄ spec.

**Scope:** Iterations 1–5. **Iteration 6 (daily progression proration) is deliberately excluded**
at Xuan's instruction (2026-07-28) and is not recorded anywhere in this directory.

## Provenance of the source pages

| Iteration | Subject | Spec page last edited |
|---|---|---|
| 1 | Baseline RMR, TDEE, macro needs from today's workouts | 2026-03-17 |
| 2 | Multi-day context: yesterday, tomorrow, weekly, training phase | 2026-03-17 |
| 3 | Dynamic NEAT, iterative TEF, prospective/retrospective modes | 2026-03-17 |
| 4 | Safety + edge cases: RED-S/EA gate, multi-session, carb cycling | 2026-03-17 |
| 5 | Platform integration (Garmin / TrainingPeaks / Final Surge) | 2026-03-19 |

The iterations are a **build history**, not a domain decomposition. This directory reorganizes
them by section (one file per section, per `CLAUDE.md`), targeting the **final v5 behaviour**.
Where an iteration superseded an earlier rule, only the superseding rule is stated as the SSOT and
the superseded one is noted as lineage.

## Sections

| File | Formulas (Notion numbering) |
|---|---|
| [`rmr.md`](rmr.md) | 1 · 24 |
| [`baseline-macros.md`](baseline-macros.md) | 2 · 20 |
| [`session-demand.md`](session-demand.md) | 3 · 4 · 5 · 19 |
| [`multi-day-context.md`](multi-day-context.md) | 7 · 8 · 9 · 10 |
| [`neat-tef.md`](neat-tef.md) | 12 · 13 · 14 · 15 · CTL tier table |
| [`energy-availability.md`](energy-availability.md) | FFM derivation · 17 · 18 |
| [`platform-resolution.md`](platform-resolution.md) | 22 · 23 · 25 · 26 · 27 |
| [`assembly.md`](assembly.md) | 6 · 11 · 16 · 21 · 28 (the pipeline) |
| [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md) | — the register of contradictions found while distilling |

Formula 21/28 numbering gaps in the source (no formula 6-as-numbered vs 6-as-assembly) are the
Notion doc's own; the mapping above is what the pages actually contain.

## Inputs (union across iterations 1–5)

### Athlete profile
| Field | Type | Req | Default | Notes |
|---|---|---|---|---|
| `sex` | `MALE` \| `FEMALE` | yes | — | Only used for Mifflin-St Jeor and the FFM estimate |
| `age` | int (years) | yes | — | Masters protein multiplier at ≥ 45 |
| `weight_kg` | float | yes | — | |
| `height_cm` | float | yes | — | |
| `body_fat_pct` | float 0–100 | no | null | If present → `LBM = weight_kg × (1 − body_fat_pct/100)` |
| `lifestyle` | `DESK` \| `MIXED` \| `ACTIVE` \| `VERY_ACTIVE` | no | `MIXED` | Set once at onboarding |
| `typical_weekly_hours` | float | no | null | Infers volume tier; null → `MODERATE` |
| `carb_cycle_opt_in` | bool | no | `false` | Explicit opt-in; enables train-low |

UX labels for `lifestyle` (from the Iteration 3 spec): "Desk-based day" / "Mixed: some movement" /
"On your feet most of the day" / "Physically demanding work".

### Session (zero or more per day)
| Field | Type | Req | Notes |
|---|---|---|---|
| `sport` | `RUNNING` \| `CYCLING` \| `SWIMMING` \| `STRENGTH` | yes | |
| `duration_hr` | float | yes | |
| `start_time` | datetime | (multi-session) | Sort key for compounding |
| `pct_conversational` | float 0–1 | yes | Z1–Z2 |
| `pct_tempo` | float 0–1 | yes | Z3–Z4 |
| `pct_allout` | float 0–1 | yes | Z5+ |

**Validation:** `pct_conversational + pct_tempo + pct_allout == 1.0` within float tolerance.
`0.70 / 0.20 / 0.20` (sum 1.1) and `0 / 0 / 0` must both be **rejected**, not coerced.

### Multi-day context
| Field | Type | Req | Default | Notes |
|---|---|---|---|---|
| `yesterday_tss` | float | no | null | Fallback derivation: `duration_hr × IF² × 100`. **Sum across all of yesterday's sessions** (ratified 2026-07-29, Q-013). Null → recovery-debt step skipped |
| `yesterday_end_time` | datetime | no | null | Yields `hours_since` for the decay. For a multi-session yesterday, the **last** session's end time |
| `tomorrow_tss` | float | no | null | |
| `tomorrow_duration_hr` | float | no | null | |
| `tomorrow_is_race` | bool | no | null | Triggers the 9.0 g/kg carb-load floor |
| `training_phase` | `BASE` \| `BUILD` \| `PEAK` \| `TAPER` \| `RACE_WEEK` \| `OFF_SEASON` | yes | `BASE` | Athlete setting |
| `weekly_load_ratio` | float | yes | `1.0` | `this_week_hours / typical_week_hours` |

### System / platform
| Field | Type | Req | Default | Notes |
|---|---|---|---|---|
| `mode` | `PROSPECTIVE` \| `RETROSPECTIVE` | yes | `PROSPECTIVE` | Identical math; selects which data is passed in |
| `garmin_connected` | bool | no | `false` | OAuth |
| `tp_connected` | bool | no | `false` | TrainingPeaks **or** Final Surge |

Platform payload fields are enumerated in [`platform-resolution.md`](platform-resolution.md).

## Output

```
{ carb_g, prot_g, fat_g, tdee, rmr, session_kcal,   // v1
  neat_kcal, tef_kcal, mode,                        // + v3
  ea, ea_status,                                    // + v4
  sources, delta,                                   // + v5
  energy_basis }                                    // + Q-009 ruling, 2026-08-13
```

All macro/energy values **rounded at return**. `delta` is `null` except in retrospective
recalculation (Q-012 ruling). `sources` tags the origin of each resolved variable.
`energy_basis` is `"pre_override"` when the EA override adjusted the plan — meaning `tdee` and
`tef_kcal` describe the pre-override macros — else `"as_computed"` (Q-009 ruling).

## Cross-cutting rules

**R1 — Round only at the boundary. RATIFIED as a ruling (Xuan, 2026-08-13,
[Q-001](OPEN-QUESTIONS.md#q-001)).** Intermediate carb/protein values are carried **unrounded**
through the whole pipeline; rounding happens once, on the returned object. Originally derived, not
quoted — the integration tests only reconcile under it (rest-day fat 80 requires unrounded protein
115.2; the old strength-day case was equally decisive) — and now explicit. Consequences of the
ruling: Formula 19's mid-pipeline `round()` is deleted (Q-002); the Iteration 3 rest-day "81" is a
stale cell; fat is vectored **exact-match**, not ±15 %.

**R2 — Energy conversion.** Carbohydrate and protein at 4 kcal/g, fat at 9 kcal/g throughout.

**R3 — Fat is the bounded residual.** Fat is never targeted directly; it absorbs whatever energy
is left after carb and protein, floored at `0.8 × weight_kg` and **capped at 30 %E of target
energy (Q-014, ruled 2026-08-13)** — excess above the cap redistributes to carbohydrate up to the
12 g/kg clamp, and is never dropped. In practice the cap binds on most training days, so fat sits
near 30 %E and carbohydrate carries the day-to-day variation. Every phase/context modifier
therefore moves carbohydrate, directly or via redistribution.

**R4 — Clamps are the last word on carb and protein**, applied after all additive and
multiplicative adjustments: carb ∈ `[3.0, 12.0] × weight_kg`, protein ∈ `[1.2, 2.5] × weight_kg`.
The one exception is the EA override (step 11), which can raise carb *after* the clamp — see
[Q-006](OPEN-QUESTIONS.md#q-006).

**R5 — Order is load-bearing.** Additive steps (recovery debt, weekly load) precede the
upward-only pre-load override precedes multiplicative phase modifiers precede clamping. Reordering
changes results. The full order is in [`assembly.md`](assembly.md).

## Conformance target

`app/supabase/functions/calculate-daily-macros/` — `index.ts`, `pipeline.ts`, `types.ts` and
`formulas/{rmr,baseline,session,multi-day,neat-tef,safety,resolve}.ts`, with existing test files
`index.test.ts`, `index.integration.test.ts`, `iteration5.test.ts`. The module names line up
one-to-one with the sections here, but **no spec ⇄ code diff has been run yet** — nothing in this
directory is a claim about what the code does. Per the governance rule, when that diff happens,
code behaviour that this SSOT does not state goes to `DEVIATIONS.md`, never back into these files.
