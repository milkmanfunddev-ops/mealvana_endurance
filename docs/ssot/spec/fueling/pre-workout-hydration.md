# SSOT — Pre-Workout Hydration

**Status: RATIFIED v6 (Xuan, 2026-08-04).** Supersedes v3 (Xuan, 2026-07-30).
**Engine:** `OfflineMacroCalculator.calculatePreWorkoutHydration`, mirrored by the
`generate-macros-v4` edge function. **Not yet implemented — code implements v1.**
**Reasoning, close calls and concerns:** [`pre-workout.notes.md`](./pre-workout.notes.md) — one
combined notes file covers hydration, carbohydrate and sodium, because the tier architecture is
shared.

> This file is the executable contract: formula, constants, output shape, invariants. Nothing
> else. Every "why" lives in the notes file.

**Scope.** The cited **5–10 ml/kg** band is Thomas 2016's, and it is scoped to the **2–4 hours
before exercise** — sport-agnostic, examples only. Everything below `T_REF` is a Mealvana design
choice (`targetBasis` says so). Separately, the output **gates** to `null` for a short, cool session
(`workoutDurationMin < 60 AND tempC < 30`) — but that gate is *ours* (a NATA recreational carve-out
proxy), **not** part of Thomas's scope. This banner scopes the citation and names the gate; it does
not itself gate anything.

**What changed from v5.** The plan is now delivered in **tiers** shared with
`pre-workout-carbs.md`, and it carries a **conditional correction** driven by a urine check at the
2-hour mark. The sub-2 h curve is unchanged. Notes §2.2–2.4.

## Inputs

| Field | Type | Default |
|---|---|---|
| `bodyWeightKg` | double | required |
| `workoutDurationMin` | double | required |
| `timeBeforeWorkoutMin` | double | required — **captured at plan generation and frozen**, see below |
| `tempC` | double? | `22` when null |
| `hydrationCheck` | enum | `pale` · `dark` · `unknown` → **`unknown`** |

**`hydrationCheck` only affects output when `timeBeforeWorkoutMin >= T_REF`.** Below 2 h it is
advisory copy, not a code path — see notes §2.5.

**The input domain is discrete.** The app collects lead time in **15-minute steps from 0 to 240**,
so the engine is only ever called with seventeen values. The formula stays continuous — the
invariants are stated over the continuum so a granularity change cannot break them — but
conformance vectors SHOULD enumerate the grid. Note that `t >= T_REF` collapses to a **single
output** on this grid (all nine of 120 … 240 give 7.5·BW), because the cited band has no time
dependence inside it; the taper is visible only in the eight columns below two hours.

The 240-minute ceiling is a ratified product decision (Xuan, 2026-08-04) shared with
`pre-workout-carbs.md`, and it makes the input maximum coincide with the outer edge of Thomas's
window. The app currently ships a **480-minute** stepper — **D-016**, a code-side divergence to be
fixed in the app, not accommodated here.

**`timeBeforeWorkoutMin` is the lead time at *plan generation*, and it is frozen for the life of the
plan.** It is not re-read from the clock. A recompute triggered by `hydrationCheck` arriving later
MUST reuse the original value — otherwise an athlete who planned at t−240 and answers the check at
t−100 would silently fall through to the sub-2 h branch and lose the meal-window dose they already
drank.

## Constants

```
A0_ML       = 250.0        # ml — start-line anchor                     (J&G 2019 p. 493)
R_CEILING   = 400.0        # ml — gastric volume tolerated at t = 0     (NATA 2017)
K           = 0.0533333    # per min — 3.2 h⁻¹, first-order emptying    (Mudie 2014)
T_REF       = 120.0        # min — lower edge of Thomas 2016's fluid window
TOPUP_ML_KG      = 4.0     # ml/kg — dark-urine correction, target      (ACSM 2007, midpoint of 3–5)
TOPUP_HIGH_ML_KG = 5.0     # ml/kg — top of ACSM 2007's 3–5 band
PLAN_CAP_ML_KG   = 12.0    # ml/kg — ACSM 2007's own maximum for the same protocol
```

`K` MUST be computed as `3.2 / 60`. Every constant is a literature value at its published
magnitude; none is derived, scaled or averaged by us.

**`T_REF` is this file's constant.** `pre-workout-carbs.md` defines `TIER_MEAL_MIN` with the same
value for an unrelated reason. Pinned equal by conformance assertion, **not** shared code. Either
may move without the other. Notes §1.3.

## The algorithm

```
# gate
if workoutDurationMin < 60 AND tempC < 30:
    return { fluidMl: null, fluidLowMl: null, fluidHighMl: null, tiers: [],
             gateTriggered: true, regime: "gated", targetBasis: "none" }

t  = max(timeBeforeWorkoutMin, 0)
BW = bodyWeightKg
A0 = min(A0_ML, 7.5 * BW)                       # guard; binds only below 33.3 kg
f  = (x) -> A0 + (7.5*BW - A0) * min(x, T_REF) / T_REF

if t >= T_REF:
    mealMl    = 7.5 * BW                        # Thomas 2016 midpoint, consumed in [t, 120]
    topUpMl   = (hydrationCheck == "dark") ? TOPUP_ML_KG * BW : 0.0
    snackMl   = topUpMl                         # ACSM 2007 places the correction at ~2 h
    topOffMl  = 0.0
    fluidMl     = mealMl + snackMl              # 7.5 ml/kg, or 11.5 on the corrected path
    fluidLowMl  = 5.0 * BW                      # Thomas's cited floor
    fluidHighMl = min(7.5*BW + TOPUP_HIGH_ML_KG*BW, PLAN_CAP_ML_KG*BW)     # min(12.5, 12) -> 12
                                                # NOT conditioned on hydrationCheck — see below
    regime      = "cited"
    targetBasis = "evidenced_band"
else:
    mealMl = 0.0
    if t >= 30:  snackMl = f(t) ; topOffMl = 0.0
    else:        snackMl = 0.0  ; topOffMl = f(t)
    ceiling     = R_CEILING * exp(K * t)
    fluidMl     = snackMl + topOffMl
    fluidLowMl  = 0.0
    fluidHighMl = min(10.0 * BW, ceiling)
    regime      = (ceiling < 10.0 * BW) ? "clearance_bound" : "extrapolated"
    targetBasis = "design_choice"
```

**Outputs are exact. The engine does not round.** Rounding belongs to the drawer — notes §6.

- **All pre-workout fluid goes to the earliest window that exists.** There is no snack/top-off
  split. Notes §2.6.
- `t > 240` returns the same values as `t = 240`. Deliberate; notes §5.7.
- The clearance term binds below `t = ln(10·BW / R_CEILING)/K` — ~9 min at 65 kg, ~17 at 100 kg,
  never for `BW ≤ 40`. It is always inside the top-off tier (invariant 9).

## What `fluidMl` means — contractual

**Above `T_REF`: a dose for `[now, t−120]`, then stop.** Thomas 2016 bounds its window at both
ends — *"in the 2 to 4 hours before exercise… while allowing for sufficient time for excess fluid
to be voided."* Consumer copy MUST say **finish about two hours before you start**, not *sip until
you start*.

**Thomas is silent below 2 h — silent, not prohibitive.** It bounds its own dose; it does not
forbid other fluid. Everything below `T_REF` is ours and `targetBasis` says so. Notes §2.3.

**In every regime:**

1. **Divided, not single-dose.** Allocation is by *occasion*; consumption within a window is still
   spread. A snack-window volume is sipped across the window, not drunk at one moment.
2. **The engine is stateless** about prior intake. If intake has already occurred, the amount still
   to take is `fluidMl` minus that intake, floored at 0. The engine does not subtract — notes §5.13.
3. **The urine cue outranks the number.** Any surface showing `fluidMl` MUST show the cue with it.
4. **It is a recommendation, not a quota.** With `fluidLowMl = 0` below `T_REF`, an athlete who
   drinks nothing is in spec. No progress ring, no `0 / N ml` counter, no completion state.
   Notes §5.12.

## The urine check — contractual

`hydrationCheck` is **collected by the consumer, not scheduled by the engine.** It is surfaced
inline with the snack-window fluid recommendation — the athlete meets it when they open that card,
not as a notification. Presentation is in notes §6; the engine only consumes the value.

This is the **only** individualization in the spec and the only thing that moves the number off a
body-weight function.

**The plan is therefore computed at least twice** — once at generation with `unknown`, and again
when a value arrives. Two consequences, both binding:

- The engine MUST be **pure** with respect to `hydrationCheck`: same inputs, same outputs, no
  dependence on call order or wall-clock time.
- Because the band is check-independent (invariant 8b), **only `fluidMl` changes on the recompute.**
  `fluidLowMl`, `fluidHighMl`, the tier structure and `regime` are all stable. That is what lets the
  answer land inline without the card rearranging itself.

**The correction is offered only while the snack window is open.** Both edges bind:

```
offerCheck =  timeBeforeWorkoutMin >= T_REF            # frozen entry — the branch exists at all
          AND currentLeadMin       <= T_REF            # the meal window has closed
          AND currentLeadMin       >= TIER_TOPOFF_MAX  # the snack window has not
```

**`currentLeadMin` is read from the clock and is NOT `timeBeforeWorkoutMin`.** The first is now, the
second is frozen at plan generation; this is the one place they are deliberately different.

- **Above `T_REF` the check is premature.** The base dose is consumed in `[entry, 120]`, so an
  athlete at t−200 has not yet drunk the thing the check evaluates — the same error §2.5 rejects
  below 2 h, and worse here, because the answer would be treated as a verdict on an untaken dose.
- **Below `TIER_TOPOFF_MAX` it is too late.** The snack window has closed and there is nowhere for
  the correction to go; the consumer stops offering it rather than applying it late.

**PW-020, ratified 2026-08-04.** v6 as first written stated only the lower bound while its own
heading said "while the snack window is open" — the prose was the intent and the predicate
under-enforced it. Notes §5.19.

| `hydrationCheck` | Effect at `t ≥ 120` | Basis |
|---|---|---|
| `pale` | none | Thomas 2016 — the endpoint was reached |
| `dark` (or no urine produced) | `+4 ml/kg` in the snack window | ACSM 2007's conditional branch |
| `unknown` | **treated as `pale`** — PROVISIONAL, requires ruling. Notes §2.5 | Mealvana design choice |

**The check moves the target only. `fluidLowMl` and `fluidHighMl` above `T_REF` are the same on
every path**, because the band is displayed from entry (t−240) while the check happens at t−120 —
a check-dependent band would be uncomputable at entry, or would change underneath the user
mid-plan. `fluidHighMl` states what the *protocol* can sanction (base + largest correction, clamped
at ACSM's maximum), not what this athlete's reading turned out to be. Notes §2.4.

**Below `T_REF` the check changes nothing.** The athlete has drunk nothing, so there is no result
to evaluate, and `f(entry)` already encodes the arriving-with-nothing assumption. The pale/dark
distinction is carried there by `fluidLowMl = 0`, the high bound, and the fine print. Notes §2.5.

**Riboflavin confounds the reading** — J&G p. 246: *"this simple test cannot be reliably used if the
athlete is taking vitamin supplements, because some of the excreted water-soluble B vitamins add a
yellowish hue to urine."* The bias runs toward **false dark**, i.e. toward a correction the athlete
does not need. There is no engine input for supplement use; the mitigation is **copy beside the
options** letting the athlete self-select into "not sure" → `unknown`. Notes §6.

## Tier integration

Tiers are defined by `pre-workout-carbs.md` (`meal` 120–240 · `snack` 30–120 · `top_off` 0–30).

| entry | meal | snack | top_off |
|---|---|---|---|
| `≥ 120` | `7.5·BW` | correction only (0 if pale) | 0 |
| `30 – 120` | — | **all of `f(entry)`** | 0 |
| `< 30` | — | — | **all of `f(entry)`** |

**The tier is a presentation container.** `targetBasis` is per-nutrient and per-minute and MUST NOT
be derived from the tier.

**The top-off tier carries no hydration when a snack window exists.** The water taken with a gel is
carbohydrate delivery and belongs to `pre-workout-carbs.md` — notes §2.6.

## Outputs

| Field | Type | Notes |
|---|---|---|
| `fluidMl` | double? | exact ml; **plan total** across all tiers |
| `fluidLowMl` / `fluidHighMl` | double? | exact ml; permissible range |
| `tiers` | array | ordered, furthest-out first; each `{tier, fluidMl}` |
| `gateTriggered` | bool | |
| `regime` | string | `"cited"` · `"extrapolated"` · `"clearance_bound"` · `"gated"` |
| `targetBasis` | string | `"evidenced_band"` · `"design_choice"` · `"none"` |
| `hydrationCheckUsed` | string | echo of the value actually applied |

**No `renderAs`.** Portion language (*sip / glass / bottle*) is a **drawer** concern — a threshold on
`fluidMl` the consumer computes itself — and lives in notes §6, not in this math contract. The engine
emits the number; how it is worded is not the SSOT's to dictate.

**`tier` (int) is RETIRED.** Not emitted. Notes §2.7.

**`fluidLowMl = 0`, not `null`.** Zero means *nothing is required*; `null` (gate path) means *no
statement is made*. A consumer that conflates them will misreport both.

## Invariants (conformance must assert all)

1. `0 <= fluidLowMl <= fluidMl <= fluidHighMl` wherever non-null, for **all** body weights.
2. `fluidMl == sum(tiers[].fluidMl)`.
3. `fluidMl` is non-decreasing in `t` on **both** the pale and dark paths.
4. **Pale-path continuity** at `t = 120` and `t = 30`: `|value(b+ε) − value(b−ε)| < 1e-6·BW`.
5. **The dark-path step at `t = 120` is intentional**: `plan(120⁺) − plan(120⁻) == 4·BW`. Pin it.
6. Anchor A, `t = 120`, pale: `low = 5·BW`, `plan = 7.5·BW`, **`high = 12·BW`**. The ceiling is
   `12·BW` on *every* path above `T_REF`, including pale — see invariant 8b and notes §2.4.
   (Versions through v5 wrote `10·BW` here. It contradicted invariants 8 and 8b, the algorithm and
   the worked table; ten vectors — `cited-boundary-120-65-pale` among them — assert `12·BW`, so an
   engine built from the old line failed its own conformance set.)
7. Anchor B, `t = 0`: `low = 0`, `plan = min(250, 7.5·BW)`, `high = min(10·BW, 400)`.
8. `fluidHighMl == 12·BW` for all `t >= 120`; `fluidHighMl <= 10·BW` for all `t < 120`.
   **Neither is "Thomas's maximum"** — Thomas states no maximum. 10 ml/kg is the most we recommend
   in a region no protocol covers; 12 ml/kg is ACSM 2007's own protocol maximum. Notes §2.4.
8b. **The band above `T_REF` is independent of `hydrationCheck`.** Assert that `fluidLowMl` and
   `fluidHighMl` are byte-identical across all three check values at the same `t` and `BW`. Only
   `fluidMl` may differ.
8a. **The plan cap has teeth, and it binds on the band, not the target.** Assert
   `fluidMl <= PLAN_CAP_ML_KG·BW` (today 11.5 ≤ 12, with headroom) **and** that
   `fluidHighMl == 12·BW` on the dark path — i.e. that `min(12.5, 12)` selected the cap. Raising
   `TOPUP_ML_KG` past 4.5 must fail the first assertion rather than silently exceed ACSM's own
   maximum.
9. **Clearance containment.** `ln(10·BW / R_CEILING)/K <= 30` for all `BW <= 198` — the
   clearance-bound region is always strictly inside the top-off tier.
10. **Cross-spec pin.** `T_REF == pre-workout-carbs.TIER_MEAL_MIN`; assert equality and fail loudly
    on divergence rather than deriving one from the other.
11. Gate path returns `null`/`null`/`null` and an empty `tiers` array, never `0`.

**Explicitly NOT an invariant:** "delivered fluid falls within `[low, high]`" is vacuous below
`T_REF` once `low = 0`. Exclude that window rather than letting the check pass trivially.

## Constants — basis and confidence

| Constant | Value | Basis | Confidence |
|---|---|---|---|
| Band at `t ≥ 120` | 5–10 ml/kg | Thomas 2016, verbatim | **High** |
| Window bounded at both ends | 2–4 h | Thomas 2016 — "while allowing for sufficient time for excess fluid to be voided"; ACSM 2007's structure corroborates | **High** |
| Endpoint cue outranks the volume | — | Thomas 2016 — the volume exists "to achieve urine that is pale yellow in color" | **High** |
| Dark-urine correction | target 4, band 3–5 ml/kg at ~2 h | **ACSM 2007**, verbatim. Superseded document, but Thomas dropped the branch without replacing it — notes §2.4. The target is the band's midpoint (Mealvana rule, same as 7.5) | Medium |
| Plan cap | 12 ml/kg | ACSM 2007's own maximum for the same protocol (5–7 + 3–5). **Is the band top** — `min(12.5, 12)`, unconditional above `T_REF` | Medium |
| Target at `t ≥ 120` = midpoint | 7.5 ml/kg | **Mealvana rule** — no source names a point in the range | Medium |
| `low = 0` below 2 h | 0 | NATA 2017's recreational carve-out | **Medium** |
| `high` = 10 ml/kg extended below 2 h | — | **Mealvana design choice** — the cited ceiling held outside its window, clamped by clearance | Low |
| Any fluid recommended below 2 h | — | **Mealvana design choice** in a region no source addresses | Low |
| `A0_ML` | 250 ml | J&G 2019 p. 493 | Medium |
| `R_CEILING` | 400 ml | NATA 2017 — "Maintaining 400 to 600 mL of fluid in the stomach optimizes gastric emptying" | Medium |
| `K` | 3.2/60 | Mudie 2014 — published mean coefficient | Medium |
| Linear taper of the sub-2 h target | — | **Mealvana design choice** | Low |
| All fluid to the earliest window | — | **Mealvana design choice** — absorption + voiding; consistent with ACSM's placement of the correction | Low |
| `unknown` treated as `pale` | — | **Mealvana design choice, PROVISIONAL** | Low |
| Gate `<60 min AND <30 °C` | no target | **Mealvana design choice** — proxy for NATA's carve-out | Low |

## Literature

- **Thomas DT, Erdman KA, Burke LM.** *ACSM Joint Position Statement. Nutrition and Athletic
  Performance.* Med Sci Sports Exerc. 2016;48(3):543–568. **Governs the band and the window.**
  > "Athletes may achieve euhydration prior to exercise by consuming a fluid volume equivalent to
  > 5-10 ml/kg BW (~2-4 ml/lb) in the 2 to 4 hours before exercise to achieve urine that is pale
  > yellow in color while allowing for sufficient time for excess fluid to be voided."

  Nothing follows for the final two hours, and **no maximum is stated anywhere**. On over-drinking:
  > "Over-drinking fluids in excess of sweat and urinary losses is the primary cause of hyponatremia
  > (blood sodium ≤135 mmol/L)… It can also be compounded by excessive fluid intake in the hours or
  > days leading up to the event."

- **Sawka MN, et al.** *ACSM Position Stand: Exercise and Fluid Replacement.* Med Sci Sports Exerc.
  2007;39(2):377–390. **Superseded for the base dose. Cited for the correction branch only**,
  because Thomas dropped it without replacing it:
  > "If the individual does not produce urine, or the urine is dark or highly concentrated, s/he
  > should slowly drink more beverage (for example, another ~3–5 mL·kg⁻¹) about 2 h before the
  > event."

  **Do not use its 5–7 ml/kg base.** That is what Thomas 2016 replaced.

- **McDermott BP, et al.** *NATA Position Statement.* J Athl Train. 2017;52(9):877–895. Source of
  `R_CEILING` (*"Maintaining 400 to 600 mL of fluid in the stomach optimizes gastric emptying"*)
  and of `low = 0` (*"Recreational athletes should not need to consume extra fluids before
  activity"*).

- **Mudie DM, et al.** Mol Pharm. 2014;11(9):3039–3047. **Source of `K`:**
  > "an average first-order gastric emptying rate coefficient of 3.2 h⁻¹ (T50% of 13 min), with a
  > range of 2.2−6.0 h⁻¹, would be a good starting point for the analysis."

- **Jeukendrup A, Gleeson M.** *Sport Nutrition.* 3rd ed. 2019. **Source of `A0_ML` (p. 493) and the
  exponential form (p. 130) only.** Do not cite its p. 247 ADA/DC figure, its p. 250 sidebar, or its
  p. 252 "6–8 ml/kg" sidebar — notes §4.3.

## Worked examples — 65 kg, exact ml

| t | check | meal | snack | top-off | **plan** | low | high | regime |
|---|---|---|---|---|---|---|---|---|
| 240 | pale/unknown | 487.5 | 0 | 0 | **487.5** | 325 | 780 | cited |
| 240 | **dark** | 487.5 | 260.0 | 0 | **747.5** | 325 | 780 | cited |
| 180 | pale/unknown | 487.5 | 0 | 0 | **487.5** | 325 | 780 | cited |
| 180 | **dark** | 487.5 | 260.0 | 0 | **747.5** | 325 | 780 | cited |
| 120 | pale/unknown | 487.5 | 0 | 0 | **487.5** | 325 | 780 | cited |
| 119.999 | any | — | 487.5 | 0 | **487.5** | 0 | 650 | extrapolated |
| 90 | any | — | 428.125 | 0 | **428.125** | 0 | 650 | extrapolated |
| 60 | any | — | 368.75 | 0 | **368.75** | 0 | 650 | extrapolated |
| 45 | any | — | 339.0625 | 0 | **339.0625** | 0 | 650 | extrapolated |
| 30 | any | — | 309.375 | 0 | **309.375** | 0 | 650 | extrapolated |
| 29.999 | any | — | 0 | 309.375 | **309.375** | 0 | 650 | extrapolated |
| 15 | any | — | 0 | 279.6875 | **279.6875** | 0 | 650 | extrapolated |
| 5 | any | — | 0 | 259.8958 | **259.8958** | 0 | 522.2421 | **clearance_bound** |
| 0 | any | — | 0 | 250 | **250** | 0 | 400 | **clearance_bound** |
| 180 | (45 min, 22 °C) | null | null | null | **null** | null | null | gated |

Dark-path **target** step at `T_REF`: 50 kg → 200 ml · 65 kg → 260 ml · 100 kg → 400 ml.
`fluidHighMl` also steps at `T_REF` — 12·BW above, `min(10·BW, clearance)` below — on **every**
path. Both intentional; notes §2.4.

## Conformance

Vectors: `qa/vectors/fueling/pre-workout-hydration.json` — **currently pins v1; all 9 obsolete.**
Runner: `qa/conformance/run_dart.sh pre-workout-hydration`.

Required coverage: all eleven invariants (3, 4, 5, 8, 9 as property tests); both anchors exactly;
the pale-path continuity at both boundaries and the dark-path step at `T_REF`; the clearance
handover at 65 kg (t−9.1) and 100 kg (t−17.2) plus `BW = 40` where it never binds; `BW < 33.3`
(the `A0` guard); `BW > 100`; `tempC: null`; all three `hydrationCheck` values at `t ≥ 120` — asserting the **band is identical across all
three** (invariant 8b) while the target differs — **and** proof that all three produce identical
output below `T_REF`; gate path asserting `null`, not `0`;
and the cross-spec pin as a build-time assertion.
