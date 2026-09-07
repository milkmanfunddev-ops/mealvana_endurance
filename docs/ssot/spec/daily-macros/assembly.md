# SSOT — Daily Macros: The Assembly Pipeline

**Status: RATIFIED v1 (Xuan, 2026-08-14).** Recorded 2026-07-28; Source: Notion assembly formulas
`dailyMacros_v1` … `dailyMacros_v5` across Iterations 1–5. **Engine:** B.
**Conformance target:** `calculate-daily-macros/pipeline.ts` + `index.ts` (name match only — not
yet diffed).

## The rule
> The order the adjustments run in *is* the specification. Additive before override before
> multiplicative before clamp; energy accounting last; safety gate very last.

---

## The v5 pipeline (the SSOT)

This is the final state after five iterations. Steps are numbered as the pipeline, not as the
Notion formula numbers.

```
0.  VALIDATE
    Each session's pct_conversational + pct_tempo + pct_allout == 1.0 (float tolerance).
    Reject otherwise — do not normalize.

1.  RESOLVE GLOBAL INPUTS                                    [platform-resolution.md]
    If Garmin body composition present → update athlete weight_kg / body_fat_pct FIRST,
      so every weight-dependent value below uses the new figures.
    rmr          = resolveRMR(garmin_daily, athlete)          # F24 → rmr.md
    tomorrow     = resolveTomorrow(tp_data, manual_tomorrow)  # F25
    weekly_ratio = resolveWeeklyRatio(tp_data, manual_ratio)  # F26

2.  RESOLVE PER-SESSION INPUTS                               # F22
    For each session → { session_kcal, IF, TSS, duration, sources }
    (Where kcal_source == FORMULA, sessionCost is computed from the RESOLVED IF/duration.)

3.  BASELINE                                                 [baseline-macros.md]
    carb = 4.0 × weight
    prot = 1.8 × LBM   (or 1.4 × weight if no LBM);  × 1.15 if age ≥ 45
    If EXACTLY ONE session AND carbCycleAdjust qualifies → carb = 3.0 × weight   # F20

4.  TODAY'S SESSIONS                                         [session-demand.md]
    if 2+ sessions:  { session_carb, prot_bump } = multiSessionCarbCompound(...)  # F19 (returns UNROUNDED — Q-002)
    else:            session_carb = carbDemand(IF, duration, weight)              # F5
                       # STRENGTH: flat 27 g/hr × dur × (weight/75), IF ignored — Q-003
                     prot_bump    = 0.3×weight if STRENGTH else 0.2×weight if dur > 1.0 else 0
    carb += session_carb
    prot += prot_bump
    session_kcal = Σ resolved per-session kcal

5.  RECOVERY DEBT (additive)                                 # F7 → multi-day-context.md
    carb += debt.carb_add;  prot += debt.prot_add

6.  PRE-LOAD OVERRIDE (upward only)                          # F8
    carb = preLoadOverride(tomorrow.is_race, tomorrow.tss, tomorrow.duration, carb, weight)

7.  WEEKLY LOAD (additive)                                   # F9
    carb += adj.carb;  prot += adj.prot

8.  PHASE MODIFIERS (multiplicative)                         # F10
    carb *= mods.carb_mod;  prot *= mods.prot_mod
    (mods.fat_mod is returned and NOT applied — RULED vestigial, Q-004; see multi-day-context.md)

9.  CLAMP
    carb = clamp(carb, 3.0 × weight, 12.0 × weight)
    prot = clamp(prot, 1.2 × weight, 2.5 × weight)

10. ENERGY ACCOUNTING                                        [neat-tef.md]
    volume_tier = inferVolumeTier(typical_weekly_hours)   # or the CTL table when TP supplies CTL
    day_mod     = getDayModifier(sessions, yesterday_tss)              # F13
    neat        = resolveNEAT(mode, garmin_daily, session_kcal, rmr,
                              volume_tier, day_mod, lifestyle)         # F23 (falls back to F14)
    { tdee, fat, tef } = calculateTDEE(rmr, neat, session_kcal,
                                       carb, prot, weight)             # F15 — iterative

10b. FAT CEILING (Q-014 — RULED 2026-08-13)
    fat_cap = 0.30 × tdee / 9
    if fat > fat_cap:
        excess_kcal = (fat − fat_cap) × 9
        headroom    = 12.0 × weight − carb            # the step-9 clamp's remaining room
        carb += min(excess_kcal / 4, headroom)
        fat   = fat_cap + max(0, excess_kcal − headroom × 4) / 9   # corner case: fat keeps remainder
    TDEE and TEF are NOT recomputed — redistribution conserves energy, so intake, TEF,
    TDEE and EA are unchanged. Target ≡ TDEE survives this step.

11. EA SAFETY GATE (last)                                    [energy-availability.md]
    ffm    = from body_fat_pct, else 0.85×weight (M) / 0.78×weight (F)
    intake = carb×4 + prot×4 + fat×9
    { ea, ea_status } = checkEnergyAvailability(intake, session_kcal, ffm)   # F17
    if BLOCK:         return an error — DO NOT generate a plan
    if HARD_WARNING:  apply eaOverride(...) to carb and fat                  # F18
                      (F18 re-clamps carb at 12×weight and routes overflow to fat — Q-006 RULED)
    (SOFT_WARNING and OK change no numbers)
    TDEE and TEF are NOT recomputed after the override — Q-009 RULED. The returned
    energy figures describe the PRE-override macros; energy_basis says so.

12. RETURN (round here, and only here — see R1)
    { carb_g, prot_g, fat_g, tdee, rmr, session_kcal,
      neat_kcal, tef_kcal, mode, ea, ea_status, energy_basis, sources, delta }
    energy_basis = "pre_override" if the step-11 override adjusted the plan, else "as_computed".
    A consumer MUST NOT present tdee/tef as describing the delivered macros when
    energy_basis == "pre_override".
```

## Why the order matters

- **Additive before multiplicative** (5,7 before 8): a phase modifier scales the recovery debt and
  the weekly nudge too, not just the baseline. Reordering would leave them unscaled.
- **Pre-load between the two additive steps** (6 between 5 and 7): the race carb-load is a `max`
  floor evaluated *before* the weekly nudge, so the weekly nudge can still push above 9 g/kg. The
  verified pre-race example lands at 712.5 pre-phase, not 675.
- **Clamp after phase** (9 after 8): a `PEAK` multiplier cannot push carb past 12 g/kg.
- **Energy accounting after the clamp** (10 after 9): fat is the residual of the *final* carb and
  protein, so any earlier ordering would compute fat against numbers that later change.
- **Fat ceiling after energy accounting, before the gate** (10b between 10 and 11): the cap needs
  the converged TDEE, and the gate must see the post-cap plan — a cap running after the gate could
  silently change what the gate approved. Like the EA override, 10b is a documented post-clamp
  carb adjustment; unlike it, 10b conserves energy exactly.
- **EA gate last** (11): it needs `fat`, which needs TDEE, which needs the final carb and protein.
  The override sits outside every clamp and every recompute **by ruling** (2026-08-13): F18 now
  carries its own ceiling branch ([Q-006](OPEN-QUESTIONS.md#q-006) — the one re-clamp that exists),
  and TDEE/TEF are deliberately not recomputed ([Q-009](OPEN-QUESTIONS.md#q-009)) — the override
  enforces a floor, it does not re-estimate energy, and recomputing would open a second convergence
  loop (fat→intake→TEF→TDEE→fat) with no stopping rule. `energy_basis` makes the choice visible to
  consumers instead of silent.

## Iteration lineage (what superseded what)

| Iteration | Pipeline change | Superseded |
|---|---|---|
| 1 (`v1`) | Steps 3, 4, 9 + `TDEE = RMR × 1.25 + session_kcal`, fat residual | — |
| 2 (`v2`) | Inserts steps 5–8 before the clamp; moves clamp + fat to the end | v1's step order |
| 3 (`v3`) | Replaces the fixed 1.25× with dynamic NEAT + iterative TEF (step 10); adds `mode` | **`RMR × 1.25` is dead** |
| 4 (`v4`) | Carb cycling into step 3; compounding into step 4; adds step 11 | v1's naive multi-session sum |
| 5 (`v5`) | Adds steps 1–2 (resolution) ahead of everything; `resolveNEAT` inside step 10 | manual-only inputs |

The Iteration 2 spec's phrase "Run Iteration 1 Steps 1–2" is a numbering slip on the source page —
Iteration 1's own steps 1–2 are RMR and baseline only, excluding sessions, while the parenthetical
says "baseline + today's sessions". Read it as **"everything before the clamp"**, which is what the
worked examples require. Recorded here rather than in the register because the intent is
unambiguous from the examples.

## Invariants (regression contracts across iterations)

These are the properties the source test pages assert *between* iterations. They are the
highest-value vectors in this engine because each one pins a whole layer at once.

| # | Invariant |
|---|---|
| **I1** | With `yesterday = null`, `tomorrow = null`, `phase = BASE`, `ratio = 1.0`, v2 output is **identical** to v1 |
| **I2** | v2 → v3 changes **only** `tdee` and `fat_g`. `carb_g` and `prot_g` must be identical |
| **I3** | With `carb_cycle_opt_in = false` and single sessions, v4 output is **identical** to v3 |
| **I4** | With `garmin_connected = false` and `tp_connected = false`, v5 output is **identical** to v4, and no `GARMIN`/`TP*` source tag appears |
| **I5** | `PROSPECTIVE` and `RETROSPECTIVE` on identical inputs produce identical output (the mode itself changes no math) |
| **I6** | Session cost is exactly linear in body weight (ratio 60:75:90 = 0.800:1.000:1.200 exactly, not within tolerance) |
| **I7** | Carb ∈ `[3.0, 12.0] × weight` and protein ∈ `[1.2, 2.5] × weight` in every returned plan — **except** where the step-11 EA override raises carb afterwards (Q-006) |
| **I8** | `0.8 × weight ≤ fat ≤ 0.30 × tdee / 9` — floor and Q-014 ceiling — **except** the corner case where the 12 g/kg carb clamp saturates, where fat may exceed its cap rather than energy being dropped |
| **I10** | Step 10b conserves energy exactly: `carb×4 + prot×4 + fat×9` is identical before and after the cap-and-redistribute. TEF, TDEE and EA are byte-identical across 10b |
| **I9** | When fat is above its floor, TDEE ≈ `(RMR + NEAT + session_kcal) / 0.9`, approached from **below** by the `delta < 10` early exit — never equal to it |

## Full-day worked examples (Iteration 1 path, reference athlete 75 kg / LBM 64 / RMR 1908)

Restated under the Q-014 cap (30 %E, excess → carb). Pre-cap values in parentheses where changed.

| Today's session | carb | prot | fat | TDEE |
|---|---|---|---|---|
| none (rest) | 302 (300) | 115 | 80 ‡ | 2385 |
| run 1.5 hr IF 0.74 | 498 (369) | 130 | 120 (177) | 3590 |
| bike 4.0 hr IF 0.72 | 723 (498) | 130 | 162 (262) | 4873 |
| strength 1.0 hr IF 0.70 | 341 (327) | 138 | 91 (97) | 2735 |
| bike 1.25 hr IF 0.93 | 514 (416) | 130 | 123 (166) | 3682 |

‡ The rest day's *displayed* fat is unchanged by the cap: unrounded 80.467 caps to 79.5, which
rounds to 80 — but 2.175 g of carb moved (300 → 302.175 → 302). A vector asserting the fat cell
alone would miss the cap entirely here; assert carb too.

† (superseded marker — see ‡ above) Reconciles only with unrounded intermediates — [R1](README.md#cross-cutting-rules), **RULED
2026-08-13** ([Q-001](OPEN-QUESTIONS.md#q-001)): carry unrounded, round once at return; vector fat
exact-match, not ±15 %. The strength row was the decisive case for R1 under the old 40 g demand
(unrounded protein 137.7 gave fat 92; rounded 138 gave 91). **The row above is restated under the
Q-003 ruling** (strength carb 300 + 27 = 327, fat residual (2735 − 1308 − 550.8)/9 = 97.4 → 97);
the source page's 340/92 pinned the superseded 40 g reading.

## Full-pipeline worked examples (Iteration 2 path)

| Scenario | today | yesterday | tomorrow | phase | ratio | carb | prot |
|---|---|---|---|---|---|---|---|
| rest, no context | none | none | none | `BASE` | 1.0 | 300 | 115 |
| hard intervals, build, overreach | bike 1.25 hr IF 0.93 | none | none | `BUILD` | 1.15 | ≈ 488 | ≈ 144 |
| rest after long ride | none | TSS 208, 16 h | none | `BASE` | 1.05 | ≈ 394 | ≈ 123 |
| pre-race, all layers | run 1.5 hr IF 0.82 | TSS 220, 20 h | race | `PEAK` | 1.25 | ≈ 798 | ≈ 159 |
| taper rest + de-load | none | none | none | `TAPER` | 0.75 | ≈ 231 | 115 |

Conflict cases pinned by the source: carb of 950 → clamped down to 900; taper+de-load carb of 180 →
clamped **up** to 225; carb 798 / prot 159 → fat at the 60 g floor with intake exceeding TDEE,
which the SSOT calls correct; `RACE_WEEK` preserves a pre-load-inflated carb because its carb_mod
is 1.00.

## Tolerances (from the source test pages)

carb ±5 % · protein ±5 % · fat ±15 % · TDEE ±5 % · NEAT ±5 % · IF ±0.005 · EA ±1.0.

These are the source's tolerances for hand-checking an implementation. **Vectors generated from
this SSOT must be exact-match** (abs tol 1e-3, sibling convention) — the formulas are
deterministic, and [Q-001](OPEN-QUESTIONS.md#q-001) is now **RULED** (R1: unrounded intermediates,
round once at return), so the ±15 % fat band has no remaining job.
