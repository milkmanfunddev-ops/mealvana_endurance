# SSOT — Pre-Workout Carbohydrates

**Status: RATIFIED v2 (Xuan, 2026-08-04).** Supersedes v1 RATIFIED (Xuan, 2026-07-26).
**Amended 2026-09-04 — the plan band is `target ± 12.5 %` in ALL cases (Xuan, post-ratification
addition; see "The plan band" below). The v2 in-window `1–4 g/kg` band clause is SUPERSEDED.**
**Engine:** `OfflineMacroCalculator.calculatePreWorkoutTargets`
(`app/lib/features/nutrition_plan/data/offline_macro_calculator.dart:98`), mirrors
`generate-macros-v4/pre-workout.ts`. **Code implements v1.**
**Reasoning, close calls and concerns:** [`pre-workout.notes.md`](./pre-workout.notes.md).

> This file is the executable contract. Every "why" lives in the notes file.

## Scope of the cited band

**The cited 1–4 g/kg band applies to a workout of ≥ 60 minutes, for carbohydrate eaten 1–4 hours
before it** — Thomas 2016 Table 2's situation exactly: *"Pre-event fuelling. Before exercise
≥ 60 min."* Both conditions are required for `targetBasis: "evidenced_band"`:

- **Workout ≥ 60 min** — inclusive; a 60-minute session qualifies. **Duration, not sport type** —
  run, bike, swim, or any endurance modality; the pre-workout engine has no sport input.
- **Lead time 1–4 h** — a lower bound *and* an upper one. The app collects only up to 3 h, so the
  4 h edge is never reached in practice.

**This scopes the *citation*, not the output. The spec never gates.** A shorter workout, or a lead
time under an hour, still returns a carbohydrate number — tagged `targetBasis: "design_choice"`, not
`null`. Only `isFasted` returns nothing. (Why carbohydrate has no gate where hydration does: §3.5.)

**The dose function keeps its shape but loses its floor.** `carbPerKg = min(hoursBefore, 4.0)`.
Five things change:

1. **The citation.** v1's "1 g/kg/hr — Kerksick 2017" is wrong. "1–4 g/kg, 1–4 h" is
   **Thomas 2016 Table 2** (origin: **Burke 2011 Table II**); "1 g/kg/hr" appears in no source.
   Notes §3.1.
2. **The meal/snack boundary moves 90 → 120 min.** Notes §3.3.
3. ~~**The plan band becomes the cited 1–4 g/kg**; ±12.5% is demoted to a per-tier solver
   tolerance.~~ Notes §3.4. **SUPERSEDED by the 2026-09-04 amendment** — the band is
   `target ± 12.5 %` in all cases. What survives from this item is the *citation* change (item 1)
   and the tier tolerance; only the PLAN BAND reverted.
4. **Composition moves out.** Fat/fibre/protein guidelines and the food list now live in their own
   SSOT, `pre-workout-food-composition.md`; this document controls the carbohydrate *quantity* only.
5. **The 0.5 g/kg floor (D-002) is removed** — Xuan, 2026-08-03. It bound only at t−15 and t−0, and
   it made the plan flat across the last three grid points. Notes §3.10.

## Inputs

| Field | Type | Default |
|---|---|---|
| `bodyWeightKg` | double | required |
| `timeBeforeWorkoutMin` | double | required |
| `workoutDurationMin` | double | required |
| `isFasted` | bool | `false` |
| `gutTolerance` | enum | `low` · `moderate` · `high` · `unknown` → `unknown` |

`timeBeforeWorkoutMin` replaces v1's `hoursBefore`. Same quantity and unit as hydration — the two
specs MUST read one field.

**The input domain is discrete.** The app collects lead time in **15-minute steps from 0 to 240**,
so the engine is only ever called with seventeen values. The formulas below remain defined
continuously — a future granularity change must not require re-deriving them — but conformance
vectors SHOULD enumerate the grid rather than sample it, because seventeen cases is the whole
input space at a given body weight.

**The 240-minute ceiling is a ratified product decision (Xuan, 2026-08-04)**, and it is what makes
`INPUT_MAX_MIN` coincide with `WINDOW_MAX`. The app currently ships a **480-minute** stepper —
**D-016**, a code-side divergence to be fixed in the app, not accommodated here. Notes §3.9.

**At `t = 0` the plan is zero.** `carbsG = 0`, with the `top_off` tier present and carrying 0 —
distinguishable from the `isFasted` path, which returns an **empty** `tiers` array and
`targetBasis: "none"`. Zero here is a real statement (*there is no time to eat*), not an absence of
one. The drawer omits zero-valued tier cards; the engine still emits them so invariant 1 holds.

**The 4 g/kg cap binds at exactly one grid point.** `min(t/60, 4.0)` engages at `t = 240`, which is
also the input maximum — so the product *does* produce Thomas's cited ceiling, at the top of the
cited window, with `targetBasis: "evidenced_band"`. It is reachable but not extendable: the cap
exists so that raising `INPUT_MAX_MIN` cannot silently push past 4 g/kg. `WINDOW_MAX` is now the
guard that reads as active and is not — with the input capped at 240, `inWindow`'s upper test can
never fire false. Delete neither. Notes §3.9.

## Constants

```
TIER_MEAL_MIN    = 120.0    # min — meal tier opens here
TIER_TOPOFF_MAX  =  30.0    # min — top-off tier closes here
WINDOW_MAX       = 240.0    # min — outer edge of Thomas 2016's carbohydrate window

SHARE_MEAL       = 0.60     # when a meal window exists
SHARE_SNACK      = 0.30
SHARE_TOPOFF     = 0.10
SHARE_SNACK_NM   = 0.75     # when it does not ("no meal")
SHARE_TOPOFF_NM  = 0.25

TIER_TOL         = 0.125    # ±12.5% — the tolerance on every carb number: each tier's portion,
                            # and (in the design_choice regime) the plan total. One tolerance, used
                            # everywhere, so the tier windows always sum to the plan band exactly.
LIGHT_MEAL_G_PER_KG = 1.0   # snack at or above this renders as "light meal"

INPUT_STEP_MIN   = 15.0     # the app's input granularity
INPUT_MAX_MIN    = 240.0    # the app's maximum lead time — equals WINDOW_MAX by design
```

**`TIER_MEAL_MIN` is this file's constant.** `pre-workout-hydration.md` defines `T_REF` with the
same value for an **unrelated** reason — hydration's is the edge of Thomas's *fluid* window
(epistemic); this one is when a low-fat solid meal is materially cleared (physiological). Pinned
equal by conformance assertion, not shared code. Neither justifies the other. Notes §1.3.

## The algorithm

```
t  = max(timeBeforeWorkoutMin, 0)
BW = bodyWeightKg

if isFasted:                                       # D-001, shipped, still unratified — notes §5.14
    return { carbsG: 0, carbsLowG: 0, carbsHighG: 0, tiers: [], targetBasis: "none" }

carbPerKg = min(t/60, 4.0)                         # v1's max(0.5, …) floor removed — notes §3.10
total     = BW * carbPerKg                         # 0 at t = 0: you can drink at the gun, not eat

if t >= TIER_MEAL_MIN:                             # 60 / 30 / 10
    meal   = SHARE_MEAL   * total
    snack  = SHARE_SNACK  * total
    topOff = SHARE_TOPOFF * total
elif t >= TIER_TOPOFF_MAX:                         # 75 / 25
    meal   = 0
    snack  = SHARE_SNACK_NM  * total
    topOff = SHARE_TOPOFF_NM * total
else:
    meal   = 0 ; snack = 0 ; topOff = total        # only window open

carbsG = total

# plan band — AMENDED 2026-09-04: one rule, no regime split
carbsLowG  = total * (1 - TIER_TOL)
carbsHighG = total * (1 + TIER_TOL)

# targetBasis is UNCHANGED. It describes how the TARGET was derived — whether the
# target sits inside Thomas's cited box — and never described the band's width.
inWindow = (60 <= t <= WINDOW_MAX) AND (workoutDurationMin >= 60)
targetBasis = "evidenced_band" if inWindow else "design_choice"

# Each tier is a RANGE the food selector lands within, not a point: ±12.5% of that tier's portion.
for tier in tiers:
    tier.rangeLowG  = tier.carbsG * (1 - TIER_TOL)
    tier.rangeHighG = tier.carbsG * (1 + TIER_TOL)
```

**Outputs are exact. The engine does not round.** Same layering as hydration — notes §6.

**Each tier is a target *and* a range.** Real foods do not come in exact gram increments, so the
selector is not asked to hit a tier's `carbsG` exactly — it matches the closest available food
(honouring `composition`) to that tier's `[rangeLowG, rangeHighG]` = **±12.5 %** of the portion. The
window is guidance, not a hard gate: where the nearest real food falls just outside a small tier's
±12.5 % (a gel is a chunkier unit than ±12.5 % of a small top-off), the selector takes the closest
match. What is guaranteed is the plan total — see below.

**One tolerance, used everywhere — so the container always holds its contents.** ±12.5 % is applied
to each tier's portion *and* to the plan total, in **every** regime. Because the tier portions sum
to `total`, the tier windows sum to exactly the plan band — no floor, no special envelope, no
exception.

### The plan band — RULED (Xuan, 2026-09-04, post-ratification amendment)

**The plan band is `target ± 12.5 %` in all cases.** The v2 clause that published Thomas's
`[1·BW, 4·BW]` as the athlete's per-plan band whenever the window was open is superseded.

*Why.* **The cited 1–4 g/kg range is a statement about the literature, not a per-plan tolerance.**
Publishing it as the athlete's band rendered a 50 kg athlete a `50 g – 200 g` slider around a 50 g
target — a 150 g-wide band that dwarfs the plan it describes and reads on device as a defect
(Xuan, 2026-09-04, IMG_8893). A band is the tolerance around *this* plan; the evidence window
belongs in the citation table and the notes, which still carry it.

*What does NOT change.* The **target** derivation is untouched:
`total = min(t/60, 4.0) × BW`. Invariant 4 — containment of the TARGET in the cited box for
`60 <= t <= 240` — still holds, by construction and unchanged; that is the claim of
non-contradiction against Thomas 2016, and it was never a claim about the band. `targetBasis`
also keeps its values and its meaning.

**Tiers stack.** An athlete entering at t−180 receives meal, snack and top-off; at t−45, snack and
top-off; at t−20, only the top-off. `carbsG` is the **plan total**, not a single feeding.

**No gate.** NATA states a positive carve-out for *fluid*; **no source says the equivalent about
food.** Absence of coverage is not a carve-out, so a short session still gets a number — with
`targetBasis: "design_choice"`. Notes §3.5.

## Composition → separate SSOT

**This document controls the carbohydrate *quantity* only.** What a food in each tier may
contain — fat / fibre / protein thresholds, the approved food list, the exclusions and their
fixes — lives in [`pre-workout-food-composition.md`](./pre-workout-food-composition.md). That file
is the contract for the `composition` value the selector must honour.

The split: this spec answers *how much carbohydrate, in how many feedings*; the composition spec
answers *which foods are allowed in each feeding*. Each tier this spec emits carries a `composition`
tag (`meal` / `snack` / `top_off` → the class defined there); the tag's rules are not restated here.

## Outputs

| Field | Type | Notes |
|---|---|---|
| `carbsG` | double | exact g; **plan total** across all tiers |
| `carbsLowG` / `carbsHighG` | double | plan-level permissible range — **cited 1–4 g/kg inside the window** |
| `tiers` | array | ordered, furthest-out first; each `{tier, carbsG, rangeLowG, rangeHighG, composition}` |
| `targetBasis` | string | `"evidenced_band"` · `"design_choice"` · `"none"` |

`composition` is emitted per tier but its **value set and rules are defined in
`pre-workout-food-composition.md`** — this spec only carries the tag through, it does not define it.

**Two ranges, two jobs — do not present them alike.** `carbsLowG`/`carbsHighG` is the **plan-level
permissible range** (headroom — the whole plan: cited 1–4 g/kg inside the window, ±12.5 % of the
total outside it). `rangeLowG`/`rangeHighG` on each tier is the **food-match window**: ±12.5 % of
that feeding's portion. Same tolerance, two scopes — the first is *what the plan may be*, the second
is *how loosely one feeding may be matched*. Notes §3.4.

**No `renderAs`.** Occasion language (*top-off / snack / light-meal / meal*) is a **drawer** concern —
a threshold on `carbsG` the consumer computes itself — and belongs to the drawer contract, not this
math SSOT. The engine emits the `tier` and the grams; how the feeding is *worded* is not the SSOT's to
dictate.

**`tiers` is load-bearing.** A consumer reading only `carbsG` will present a plan total as one
feeding — the exact misreading v1 encouraged. **No `tier` integer, ever** — notes §2.7.

## Invariants (conformance must assert all)

1. `carbsG == sum(tiers[].carbsG)`.
2. `carbsLowG <= carbsG <= carbsHighG`.
3. `carbsG` is non-decreasing in `t`.
4. **Containment in the cited box.** For `60 <= t <= 240`: `1.0 <= carbsG/BW <= 4.0`. This is the
   whole non-contradiction claim against Thomas 2016. It holds by construction — `carbPerKg = t/60`
   traverses the box's diagonal from its floor at t−60 to its ceiling at t−240.
5. **Shares are exact.** `t >= 120` → 0.60 / 0.30 / 0.10 of `carbsG`; `30 <= t < 120` → 0.75 / 0.25;
   `t < 30` → 1.00 to the top-off. Assert to 1e-9, not approximately.
6. Tier membership is exactly: `meal` iff `t >= 120`; `snack` iff `t >= 30`; `top_off` always.
7. The boundary steps are **intentional** and must be pinned, not smoothed:
   at `t = 120` the meal's share transfers to the snack (65.0 → 97.5 g at 65 kg, total unchanged);
   at `t = 30` the snack's share transfers to the top-off (24.4 → 32.5 g, total unchanged).
   **`carbsG` itself is continuous at both.**
8. `isFasted` returns zeros and an empty `tiers` array, never `null`.
9. `composition` present on every tier.
10. **Cross-spec pin.** `TIER_MEAL_MIN == pre-workout-hydration.T_REF`; fail loudly on divergence.
11. **Tier windows are ±12.5 %, and sum to the plan band — in EVERY regime.** Each tier has
    `rangeLowG = carbsG·0.875` and `rangeHighG = carbsG·1.125`, with `rangeLowG <= carbsG <= rangeHighG`.
    Because the same 12.5 % governs the plan total, `Σ rangeLowG == carbsLowG` and
    `Σ rangeHighG == carbsHighG` **exactly** — assert equality. **Amended 2026-09-04:** this now holds
    unconditionally; the old cited-regime exception (band `[1·BW, 4·BW]`, with a tolerated undershoot
    near the 1 g/kg floor) is gone.
12. **The band is a pure function of the target, independent of `targetBasis`** (amended 2026-09-04).
    `carbsLowG == carbsG·0.875` and `carbsHighG == carbsG·1.125` for every input, INCLUDING the
    `evidenced_band` rows. A conformance suite must assert this on a cited-window row specifically —
    that row is where the superseded clause used to diverge, so it is the one that proves the
    amendment landed. Corollary: the two carb bands (pre-workout plan band, per-tier window) are now
    the SAME shape; any test pinning them as "deliberately different objects" is superseded.

## Constants — basis and confidence

| Constant | Value | Basis | Confidence |
|---|---|---|---|
| Dose range | 1–4 g/kg | **Thomas 2016 Table 2**, verbatim; origin **Burke 2011 Table II** | **High** |
| Window | 1–4 h before | Thomas 2016 Table 2, verbatim | **High** |
| Scope | exercise ≥ 60 min | Thomas 2016 Table 2 situation column, verbatim | **High** |
| `carbPerKg = hours` | — | **Mealvana design choice** — the diagonal of the cited box; no source pairs dose to time. Runs to 0 at t = 0 | Medium |
| Tiers exist as distinct feedings | — | J&G ch. 6 section structure + ch. 17 p. 491 | Medium |
| `TIER_MEAL_MIN = 120` | 120 min | Tougas/ANMS — a low-fat solid meal is 30–60 % retained at 2 h; 90 min claims something the physiology does not support | Medium |
| `TIER_TOPOFF_MAX = 30` | 30 min | **Mealvana design choice.** Cited practice is 10–15 min (J&G p. 491); 30 errs early | Low |
| Split with a meal window | 60 / 30 / 10 | **Mealvana design choice** — Xuan 2026-08-03 | Low |
| Split without one | 75 / 25 | **Mealvana design choice** — Xuan 2026-08-03 | Low |
| Floor of the plan total | **removed** | D-002 (ratified 2026-07-26) **superseded by Xuan, 2026-08-03** — notes §3.10 | — |
| `TIER_TOL` ±12.5 % | 0.875 / 1.125 | **Mealvana design choice** — explicitly not research | Low |

*(Fat / fibre / protein thresholds and the food list are basis'd in `pre-workout-food-composition.md`.)*

## Literature

- **Thomas DT, Erdman KA, Burke LM.** *ACSM Joint Position Statement.* Med Sci Sports Exerc.
  2016;48(3):543–568. **Governs the dose, window and scope.** Table 2:
  > | Situation | Carbohydrate targets |
  > | **Pre-event fuelling — Before exercise ≥ 60 min** | **1–4 g/kg consumed 1–4 h before exercise** |

  Also: *"consumption of carbohydrate during exercise… dampens any effects of pre-exercise
  carbohydrate intake on metabolism and performance"* — the modifier we do not yet implement (§5.17).

- **Burke LM, Hawley JA, Wong SHS, Jeukendrup AE.** *Carbohydrates for training and competition.*
  J Sports Sci. 2011;29(sup1):S17–S27. **Origin of the row** (Thomas's ref. 36), Table II.

- **Jeukendrup A, Gleeson M.** *Sport Nutrition.* 3rd ed. 2019. **Source of the tier structure only —
  never of a per-kg dose.** (The food list it also supplies is cited in
  `pre-workout-food-composition.md`.) Ch. 6 is organised as "in the hours before"
  (p. 148) and "30 to 60 minutes before" (p. 149); ch. 17 p. 491 adds the top-off:
  > "Runners should plan for required carbohydrate and fluid intake 10 to 15 minutes before the
  > start of the race… Most of the carbohydrate ingested at this time will become available to the
  > muscle during the first part of the run."

  **The book contains no per-kilogram pre-exercise carbohydrate figure for healthy athletes.** Its
  "at least 1 g/kg … 1 to 3 hours prior" (p. 496) is the **type 1 diabetes** section — do not cite.

- **Abell TL, et al.** *Consensus Recommendations for Gastric Emptying Scintigraphy.* J Nucl Med
  Technol. 2008;36(1):44–54 (Tougas normal values). Basis of `TIER_MEAL_MIN`: a standardised
  low-fat solid meal (255 kcal; 72 % CHO, 24 % protein, 2 % fat) shows normal gastric retention of
  **37–90 % at 1 h and 30–60 % at 2 h**.

- **Kerksick CM, et al.** *ISSN position stand: nutrient timing.* J Int Soc Sports Nutr.
  2017;14:33. **Retired from the pre-exercise dose row** — notes §4.1. Still correct for
  during-exercise rates and the 6–8 % solution used by `during-workout-carbs.md`.

## Worked examples — 65 kg, workout ≥ 60 min, exact g

**This is the entire input space at 65 kg** — the app produces no other lead time.

| t | meal | snack | top-off | **total** | g/kg | plan band | basis |
|---|---|---|---|---|---|---|---|
| 240 | 156.00 | 78.00 | 26.00 | **260.00** | 4.00 | 227.50 – 292.50 | evidenced_band |
| 225 | 146.25 | 73.125 | 24.375 | **243.75** | 3.75 | 213.28 – 274.22 | evidenced_band |
| 210 | 136.50 | 68.25 | 22.75 | **227.50** | 3.50 | 199.06 – 255.94 | evidenced_band |
| 195 | 126.75 | 63.375 | 21.125 | **211.25** | 3.25 | 184.84 – 237.66 | evidenced_band |
| 180 | 117.00 | 58.50 | 19.50 | **195.00** | 3.00 | 170.63 – 219.38 | evidenced_band |
| 165 | 107.25 | 53.625 | 17.875 | **178.75** | 2.75 | 156.41 – 201.09 | evidenced_band |
| 150 | 97.50 | 48.75 | 16.25 | **162.50** | 2.50 | 142.19 – 182.81 | evidenced_band |
| 135 | 87.75 | 43.875 | 14.625 | **146.25** | 2.25 | 127.97 – 164.53 | evidenced_band |
| 120 | 78.00 | 39.00 | 13.00 | **130.00** | 2.00 | 113.75 – 146.25 | evidenced_band |
| 105 | — | 85.3125 *(light meal)* | 28.4375 | **113.75** | 1.75 | 99.53 – 127.97 | evidenced_band |
| 90 | — | 73.125 | 24.375 | **97.50** | 1.50 | 85.31 – 109.69 | evidenced_band |
| 75 | — | 60.9375 | 20.3125 | **81.25** | 1.25 | 71.09 – 91.41 | evidenced_band |
| 60 | — | 48.75 | 16.25 | **65.00** | 1.00 | 56.88 – 73.13 | evidenced_band |
| 45 | — | 36.5625 | 12.1875 | **48.75** | 0.75 | 42.66 – 54.84 | design_choice |
| 30 | — | 24.375 | 8.125 | **32.50** | 0.50 | 28.44 – 36.56 | design_choice |
| 15 | — | — | 16.25 | **16.25** | 0.25 | 14.22 – 18.28 | design_choice |
| 0 | — | — | 0 | **0** | 0 | 0 – 0 † | design_choice |
| 180, `isFasted` | — | — | — | **0** | 0 | 0 – 0 | none |

Each tier column is the **aim**; the food-match window is **±12.5 %** of it — e.g. at t−180, 65 kg
the meal is 117.00 g (102.375 – 131.625), the snack 58.50 g (51.19 – 65.81), the top-off 19.50 g
(17.06 – 21.94). **The `plan band` column is ±12.5 % of the total in EVERY row** (amended
2026-09-04) and is exactly the sum of that row's tier windows. Before the amendment the thirteen
`evidenced_band` rows all read `65 – 260` — Thomas's evidence range, identical regardless of the
target; that is the clause this table's band column no longer follows. `basis` is unchanged and
still describes the TARGET.

† **At `t = 0` the band is `[0, 0]`.** The aim is 0 (no time to eat) and ±12.5 % of 0 is 0. That
over-states — nothing forbids a gel at the gun — so the consumer MUST suppress the range rather than
render "0 – 0". Notes §3.10.

**The top-off is 13–19.5 g inside the meal window** — below one gel — then steps to 28.4 g at t−105
where the meal drops out. Fewer feedings, bigger each. The plan total is continuous through it.
Notes §3.6.

**The step at t−60** is the plan band leaving Thomas's window: it switches from the cited
`[65, 260]` to ±12.5 % of the total, `[56.9, 73.1]` (65 kg) just under t−60. Same class as
hydration's `low` step at `T_REF` — the edge of a position statement's authority, not a modelling
artefact. Pin it.

## Deviations

Register: [`qa/DEVIATIONS.md`](../../DEVIATIONS.md). **Implementation is not authorization.**

- **D-001 — fasted → zero pre-workout fuel.** Shipped, never team-discussed. Xuan 2026-07-26:
  document only. Carried into v2 unchanged and still unratified. Notes §5.14.
- **D-016 — the app's fueling-window stepper allows 480 min; this spec caps at 240.** Code-side
  divergence, to be fixed in the app. Registered 2026-08-03. Notes §3.9.
- **D-002 — 0.5 g/kg floor.** ACCEPTED into the SSOT 2026-07-26; **SUPERSEDED by Xuan, 2026-08-03.**
  The floor bound only at t−15 and t−0, where it made the plan flat across the last three grid
  points and produced a 4× step in the top-off at t−30. Removed in favour of the plain diagonal.
  Its original rationale — *"some carbs beat none"* for very short lead times — is preserved down to
  t−15, where the diagonal itself gives 0.25 g/kg; at t−0 it is not, and that is deliberate. Notes
  §3.10.

## Conformance

Vectors: `qa/vectors/fueling/pre-workout-carbs.json` — **all v1 vectors obsolete**; the output shape
changed (`tiers` added, `hoursBefore` renamed, plan band re-based).
Runner: `qa/conformance/run_dart.sh pre-workout-carbs`.

Required coverage: all ten invariants (4, 5, 7 as property tests across BW 30–160); each tier
boundary from both sides — `t = 119.999/120` and `29.999/30` — asserting the total is continuous
while the split steps; `targetBasis` flipping on `workoutDurationMin` at 59.999/60 **and** on `t` at
59.999/60; the plan-band step at t−60; `isFasted`; the `composition` tag **present**
on every tier (its *values* are tested by `pre-workout-food-composition.md`'s conformance, not
here); and the cross-spec pin as a build-time assertion.
