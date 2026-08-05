# Pre-workout macros — implementation digest (bundle `pre-workout-macros@v1`)

**This file is a digest, not the SSOT.** The normative specs are
`spec/fueling/pre-workout-{hydration,carbs,sodium}.md`. Where this file and a spec
disagree, **the spec wins**. Regenerate this digest rather than editing it in place.

- Source repo: `git@github.com:milkmanfunddev-ops/mealvana_endurance_qa.git`
- Tag: `pre-workout-macros@v1`, commit `9ee1283`, ratified 2026-08-04 (Xuan)
- Synced into this repo: 2026-08-05 (see `SSOT_SOURCE.txt`)
- Ships: **pre-workout macro calculations only** (fluid ml, carbohydrate g, sodium)
- **During-workout and post-workout are out of scope and unchanged.**

| Slice | Version | Engine entry point |
|---|---|---|
| pre-workout-hydration | v6 | `OfflineMacroCalculator.calculatePreWorkoutHydration` |
| pre-workout-carbs | v2 | `OfflineMacroCalculator.calculatePreWorkoutCarbs` (see deviation below) |
| pre-workout-sodium | v3 | `calculatePreWorkoutHydration`, sodium fields |

Excluded from the bundle: `pre-workout-food-composition` (food selection/composition — a
separate bundle; the spec file does not exist yet).

`done_when`: all three conformance slices green via `conformance/run_dart.sh`.

---

## 1. Hydration — v6

### Constants

```
A0_ML            = 250.0     ml     start-line anchor              (Jeukendrup & Gleeson 2019 p.493)
R_CEILING        = 400.0     ml     gastric volume tolerated at t=0 (NATA 2017)
K                = 3.2 / 60  /min   first-order emptying           (Mudie 2014)   << MUST be computed
T_REF            = 120.0     min    lower edge of Thomas 2016's fluid window
TOPUP_ML_KG      = 4.0       ml/kg  dark-urine correction target   (ACSM 2007, midpoint of 3–5)
TOPUP_HIGH_ML_KG = 5.0       ml/kg  top of ACSM 2007's 3–5 band
PLAN_CAP_ML_KG   = 12.0      ml/kg  ACSM 2007's own maximum
```

Inline literals: `7.5` ml/kg (target, Thomas band midpoint), `5.0` ml/kg (cited floor),
`10.0` ml/kg (sub-2 h ceiling), `30` min (snack/top-off boundary), gate's `60` min / `30` °C.

`T_REF` and carbs' `TIER_MEAL_MIN` are both 120 **for unrelated reasons** — pinned equal by a
conformance assertion that fails loudly, never derived one from the other.

### Algorithm

```
temp = tempC ?? 22.0                                  # BEFORE the gate

# gate — the only short-circuit
if workoutDurationMin < 60 AND temp < 30:
    return { fluidMl: null, fluidLowMl: null, fluidHighMl: null, tiers: [],
             gateTriggered: true, regime: "gated", targetBasis: "none" }

t  = max(timeBeforeWorkoutMin, 0)
BW = bodyWeightKg
A0 = min(A0_ML, 7.5 * BW)                             # binds only below 33.3 kg
f  = (x) -> A0 + (7.5*BW - A0) * min(x, T_REF) / T_REF

if t >= T_REF:
    mealMl      = 7.5 * BW
    snackMl     = (hydrationCheck == "dark") ? TOPUP_ML_KG * BW : 0.0
    topOffMl    = 0.0
    fluidMl     = mealMl + snackMl
    fluidLowMl  = 5.0 * BW
    fluidHighMl = min(7.5*BW + TOPUP_HIGH_ML_KG*BW, PLAN_CAP_ML_KG*BW)   # min(12.5,12) -> 12·BW
    regime      = "cited"
    targetBasis = "evidenced_band"
else:
    mealMl = 0.0
    if t >= 30:  snackMl = f(t) ; topOffMl = 0.0
    else:        snackMl = 0.0  ; topOffMl = f(t)
    ceiling     = R_CEILING * exp(K * t)
    fluidMl     = snackMl + topOffMl
    fluidLowMl  = 0.0                                  # 0, NOT null
    fluidHighMl = min(10.0 * BW, ceiling)
    regime      = (ceiling < 10.0*BW) ? "clearance_bound" : "extrapolated"
    targetBasis = "design_choice"
```

Boundaries are **inclusive at the bottom**: `t == 120` takes the cited branch; `t == 30` is
snack. Gate thresholds are **strict `<`** and joined by **AND** — `dur == 60` does not gate,
`temp == 30` does not gate.

### `hydrationCheck`

Three-valued urine-colour reading — `pale` · `dark` · `unknown`, default `unknown`. **The only
individualization in the whole slice.**

- Affects output **only when `t >= T_REF`** (`+4 ml/kg` on `dark`). Below 2 h it is advisory copy.
- **Never touches `fluidLowMl` or `fluidHighMl`** (invariant 8b). The band is shown from entry
  (t−240) while the check happens at t−120; a check-dependent band would change under the user.
- `hydrationCheckUsed` echo is subtle: `unknown` normalises to `"pale"` **only inside the
  `t >= T_REF` branch**. Below T_REF the raw `"unknown"` passes through. Normalising at the top
  of the function fails four vectors.
- `timeBeforeWorkoutMin` is **frozen at plan generation**, never re-read from the clock — else an
  athlete who planned at t−240 and answers the check at t−100 would silently fall through to the
  sub-2 h branch and lose the dose they already drank.
- The **offer predicate** (when to ask) is a *consumer* concern, not engine code:
  `timeBeforeWorkoutMin >= T_REF AND currentLeadMin <= T_REF AND currentLeadMin >= 30`.
  `currentLeadMin` is read from the clock and is **not** `timeBeforeWorkoutMin`.

### Tiers

`tiers` is ordered **furthest-out first**, each `{tier, fluidMl}`. Names come from the carbs spec.

| `t` | tiers | count |
|---|---|---|
| `t >= 120` | `[{meal, 7.5·BW}, {snack, dark ? 4·BW : 0}, {top_off, 0}]` | 3 |
| `30 <= t < 120` | `[{snack, f(t)}, {top_off, 0}]` | 2 |
| `t < 30` | `[{top_off, f(t)}]` | 1 |
| gated | `[]` | 0 |

Fluid **never splits** — all of it goes to the earliest window that exists, because for fluid
earlier is strictly better (absorption, voiding, gut comfort all agree). Duration-weighting was
tried and rejected: at t−35 it produced a 45 ml snack against a 274 ml top-off.

### Worked grid, 65 kg

| t | check | plan | low | high | regime |
|---|---|---|---|---|---|
| 240 / 180 / 120 | pale/unknown | 487.5 | 325 | 780 | cited |
| 240 / 180 / 120 | dark | 747.5 | 325 | 780 | cited |
| 119.999 | any | 487.5 | 0 | 650 | extrapolated |
| 105 | any | 457.8125 | 0 | 650 | extrapolated |
| 90 | any | 428.125 | 0 | 650 | extrapolated |
| 75 | any | 398.4375 | 0 | 650 | extrapolated |
| 60 | any | 368.75 | 0 | 650 | extrapolated |
| 45 | any | 339.0625 | 0 | 650 | extrapolated |
| 30 | any | 309.375 | 0 | 650 | extrapolated |
| 29.999 | any | 309.375 | 0 | 650 | extrapolated |
| 15 | any | 279.6875 | 0 | 650 | extrapolated |
| 0 | any | 250 | 0 | 400 | clearance_bound |
| any (45 min, 22 °C) | any | null | null | null | gated |

Above `T_REF` the output is **time-independent** — 120 through 240 all give 7.5·BW.
`t > 240` returns the same as `t = 240`. Deliberate.

Three deliberate discontinuities at `t = 120`, all to be pinned rather than smoothed:
`fluidLowMl` steps 0 → 5·BW; `fluidHighMl` steps `min(10·BW, clearance)` → 12·BW on **every**
path; and on the dark path only, `fluidMl` steps by exactly 4·BW. The pale path is *continuous*
at both 120 and 30.

> The odd-looking consequence you must **not** "fix": the t−121 dark athlete's target (747.5)
> exceeds the t−119 athlete's maximum (650). The first plan spans two windows with a clearing
> gap; the second is 90 minutes with none.

---

## 2. Carbohydrate — v2

### Constants

```
TIER_MEAL_MIN   = 120.0   min      TIER_TOPOFF_MAX = 30.0   min     WINDOW_MAX = 240.0  min
SHARE_MEAL      = 0.60    SHARE_SNACK    = 0.30    SHARE_TOPOFF    = 0.10
SHARE_SNACK_NM  = 0.75    SHARE_TOPOFF_NM = 0.25
TIER_TOL        = 0.125   (±12.5 %, a solver tolerance — NOT a goal for the athlete)
```

### Algorithm

```
t = max(timeBeforeWorkoutMin, 0) ; BW = bodyWeightKg

if isFasted:                                # D-001 — UNRATIFIED, see §4
    return { carbsG: 0, carbsLowG: 0, carbsHighG: 0, tiers: [], targetBasis: "none" }

carbPerKg = min(t/60, 4.0)                  # NO 0.5 floor (v1 had one; removed)
total     = BW * carbPerKg                  # 0 at t=0: you can drink at the gun, not eat

if   t >= 120: meal=0.60·total ; snack=0.30·total ; topOff=0.10·total
elif t >=  30: meal=0         ; snack=0.75·total ; topOff=0.25·total
else:          meal=0         ; snack=0          ; topOff=total

carbsG = total

inWindow = (60 <= t <= 240) AND (workoutDurationMin >= 60)
if inWindow: carbsLowG = 1.0·BW ; carbsHighG = 4.0·BW ; targetBasis = "evidenced_band"
else:        carbsLowG = total·0.875 ; carbsHighG = total·1.125 ; targetBasis = "design_choice"

per tier: rangeLowG = carbsG·0.875 ; rangeHighG = carbsG·1.125
```

`carbPerKg = min(t/60, 4.0)` is the **diagonal** of Thomas 2016 Table 2's cited rectangle
(1–4 g/kg consumed 1–4 h before exercise > 60 min): exactly 1 g/kg at t−60, exactly 4 g/kg at
t−240. The `4.0` cap binds at **exactly one grid point** (t=240) and exists so that raising the
input ceiling cannot silently push past 4 g/kg. Do not delete it, and do not delete `WINDOW_MAX`
either — with the input capped at 240 that test can never fire false, but it is the mirror guard.

**Tier membership**: `meal` iff `t >= 120`; `snack` iff `t >= 30`; `top_off` **always** (except
fasted). Tiers *stack* — at t−180 the athlete gets all three feedings, and `carbsG` is the plan
**total**, not one feeding. A consumer that reads `carbsG` alone presents a plan total as a single
feeding — the exact misreading v1 encouraged. **Never show `carbsG` alone; show the tiers.**

### Two semantically distinct zeros

| | `carbsG` | `tiers` | `targetBasis` | means |
|---|---|---|---|---|
| `t = 0` | 0 | `[{top_off, 0}]` — present, carrying 0 | `design_choice` | there is no time to eat |
| `isFasted` | 0 | `[]` — empty | `none` | no recommendation is being made |

A consumer that collapses them misreports both. Band `[0,0]` at t=0 **must be suppressed**, not
rendered as "0 – 0".

Carbohydrate has **no gate** — deliberately asymmetric with hydration. NATA issues a positive
carve-out for *fluid*; no source says the equivalent about food, and absence of coverage is not a
carve-out. A 20-minute workout at t−10 still gets a number, tagged `design_choice`.

### Worked grid, 65 kg (dur ≥ 60)

| t | carbPerKg | total | band | basis | meal | snack | top_off |
|---|---|---|---|---|---|---|---|
| 240 | 4.00 | 260.0 | 65–260 | evidenced_band | 156.0 | 78.0 | 26.0 |
| 180 | 3.00 | 195.0 | 65–260 | evidenced_band | 117.0 | 58.5 | 19.5 |
| 120 | 2.00 | 130.0 | 65–260 | evidenced_band | 78.0 | 39.0 | 13.0 |
| 105 | 1.75 | 113.75 | 65–260 | evidenced_band | — | 85.3125 | 28.4375 |
| 60 | 1.00 | 65.0 | 65–260 | evidenced_band | — | 48.75 | 16.25 |
| 45 | 0.75 | 48.75 | 42.66–54.84 | design_choice | — | 36.5625 | 12.1875 |
| 30 | 0.50 | 32.5 | 28.44–36.56 | design_choice | — | 24.375 | 8.125 |
| 15 | 0.25 | 16.25 | 14.22–18.28 | design_choice | — | — | 16.25 |
| 0 | 0.00 | 0 | 0–0 | design_choice | — | — | 0 |

At t−240 the target sits **on** the band ceiling and at t−60 **on** the floor — correct, and must
not render as out-of-range. Duration never moves a gram; it only flips the band and the basis.

Two intentional boundary steps to pin, not smooth: at t=120 the meal's share transfers to the
snack (65.0 → 97.5 g); at t=30 the snack's share transfers to the top-off (24.4 → 32.5 g).
`carbsG` itself is **continuous** at both. Also expected: the plan-band step at t−60 where
`carbsHighG` drops 260 → 73.1 as the plan leaves Thomas's window.

---

## 3. Sodium — v3

> **Mealvana does not set a pre-workout sodium target. This is a deliberate decision, not an
> omission.**

The entire algorithm:

```
sodiumMg = sodiumLowMg = sodiumHighMg = null      # in every tier, and on the gate path
```

No constants, no coefficients, no thresholds, no clamps, no rounding, no branch.

- **`null`, not `0`.** Zero is a recommendation ("consume no sodium"); null means no target is
  set. **A `0` in any of the three fields is a conformance failure, not a near-miss.**
- The field types must widen from `int` to `int?`. This is source-breaking for every consumer.
- **No input** — body weight, duration, temperature, lead time, tier, `hydrationCheck` — changes
  any of the three.

### What survives

| | Behaviour |
|---|---|
| **Delivered ("observed") sodium** | The BEFORE phase reports the sodium its chosen foods contain. An **observation, not a target** — display with **no range bar, no target marker, no in-range/out-of-range state, no colour change**. It is not an engine input or output; it is summed downstream from the selected foods. Not clamped, floored, or capped. |
| **Qualitative copy** | "A salty snack or an electrolyte drink with your pre-run fluid helps that fluid stay in." Supported in words by both current position statements. **Do not quantify it** — the retention studies used 77 mmol/L, three to seven times a sports drink. |

This is exactly Xuan's "kept the observed sodium with no band": the *figure* survives, the *band*
does not.

### Food-selector contract

- The selector **must not treat a salted item as a defect** — *potato and salt* is doing its job.
- Per-tier engine action is `none` in all three tiers: do not strip salt from meal-tier items, do
  not strip electrolytes from top-off items. No sodium-based penalty, filter, or demotion in BEFORE.

### The contractual non-goal (reject at review)

> **Sodium exists here to help retain a euhydrating dose. It is never a reason to raise `fluidMl`.**
> Any future change that couples sodium to a larger fluid target crosses that line.

No code path may read a sodium value and feed it into `fluidMl` / `fluidHighMl`. Sodium is a
strict sink.

### Why the target was deleted (v1 → v3)

v1 shipped 450 mg [300–600] ≥ 2 h and 150 mg [100–200] in tier 2, resting solely on Sawka 2007's
20–50 mEq/L. That was **D-007**: at the 450 mg target the concentration was `75000 / BW` mg/L, so
the cited range held only for `65.2 kg ≤ BW ≤ 163 kg` — it over-concentrated **every athlete under
~65 kg**, undocumented. Real pre-workout food overshoots any plausible band anyway (an RXBAR plus
chews delivers 325 mg against a 100–200 mg band; a bagel with peanut butter ~737 mg), so the band
flagged normal food as defective. The constant was **removed rather than re-derived**.
Sodium individualization now lives entirely in `during-workout-sodium.md` (Baker 2016, n=506).

---

## 4. Open items carried by this bundle

| id | Slice | Status | What |
|---|---|---|---|
| **D-001** | carbs | **UNRATIFIED** | `isFasted` → zero pre-workout fuel. Shipped since v1, never team-discussed. Ruling PW-002 explicitly *deferred* it. Implement as written; do not build anything that depends on it being permanent. **Its vector `fasted-180-65` is marked `ratified` in `vectors/fueling/pre-workout-carbs.json` but the manifest and DEVIATIONS.md both require `characterization` — contradiction, raise with Xuan.** |
| **PW-019** | carbs | open | Thomas 2016 Table 2 reads `Before exercise > 60 min` (strict); the algorithm tests `>= 60`, so a 60-minute workout is reported `evidenced_band` on authority the source does not grant. Vector `dur-boundary-60-180-65` pins `>= 60` — implement that, expect a possible flip. |
| **PW-003** | hydration | ratified as-is | A 55-minute run at 18 °C is gated to no target while plausibly losing ~700 ml. Known weakness, logged not fixed. |
| **PW-013** | all | open | Retiring the integer `tier` needs a **coordinated release**: client → edge function → engine. A Flutter client and a Supabase edge function deploy separately and users run old builds, so no integer renumbering is safe. |
| **D-016 / PW-011** | all | **app fix Lee owes** | The app ships a **480-minute** lead-time stepper; the ratified input domain is **0–240 in 15-min steps**. Under 480 the band reaches 4.5 g/kg — the exact defect v2 claims to remove. Fix the steppers *and* clamp persisted values on load. Until then the product can feed the engine inputs the ratified grid does not cover. |
| **D-006** | hydration | open | Drawers render tier 1 only. Closed for sodium, still open for hydration. |
| — | carbs | blocked | `spec/fueling/pre-workout-food-composition.md` **does not exist**. `composition` is contractually a pass-through (mirror `tier` into it, as every vector does), so v2 is implementable — but the value set is formally undefined until that file lands. |

### Findings from the 2026-08-05 incorporation audit

- **During-carbs spec↔code divergence (pre-existing, needs a Xuan ruling — do NOT "fix" unilaterally).**
  `during-workout-carbs` conformance fails 3/11 vectors (`long-running-ceiling-cap` band_high 90→70,
  `ultra-running-cap` band_low 80→61, `swimming-zero` band_low 60→0). Cause is commit `a1b7b9ae`
  (2026-07-22): the engine now clamps the duration band by the sport ceiling (and widens a fully
  bound band ×0.875), while the ratified vectors assert the raw-band semantics the spec still
  describes. The engine still emits the raw values under `raw_band_low`/`raw_band_high`. The clamp
  was never ratified nor logged in DEVIATIONS.md. Resolution: Xuan either ratifies the clamp (and
  regenerates vectors) or rules it a deviation. `during-workout-hydration` (11/11) and
  `during-workout-sodium` (7/7) pass.
- **Latent CI break:** `docs/ssot/` is untracked, but
  `supabase/functions/generate-macros-v4/pre-workout-vectors.test.ts` reads the vector JSON from it
  and CI auto-discovers that test. **`docs/ssot/` must be committed together with the pre-workout
  code** or pr-validation fails on file-not-found.
- **Gap:** the during-workout vectors have no TS mirror test (pre-workout does). Sensible to add
  only after the band-clamp ruling — as written they'd fail against both engines.
- `_shared/nutrition/templates/pre-workout-targets.ts`'s stale `getSubPhaseTimingLabel` (pre-v2
  windows) was removed 2026-08-05; the ratified copy lives in
  `generate-nutrition-plan-v3/sub-phase-timing.ts`.

### Documentation traps

- `spec/fueling/pre-workout-hydration.notes.md` is **SUPERSEDED** (it describes v3/v5, predates
  tiers/urine check/12 ml/kg/240-min domain). The v6 spec's `§` references point at the *combined*
  `pre-workout.notes.md`, whose numbering differs. Do not cite the superseded file.
- `spec/fueling/pre-workout-hydration.html` is the **shipped v1 drawer** (6 ml/kg, 5–7 band,
  Sawka attribution — D-011 says that citation is wrong). Do not implement from it.
- `spec/fueling/pre-workout-sodium.html` is the **archived v1 design drawer**, and carries its own
  warning that its S2 panel's arithmetic is false. Do not read numbers out of it.
- `spec/fueling/pre-workout-carb-tiers.html` has correct v2 *math* but **stale v1-era prose** — its
  note still claims "4 g/kg is unreachable, because the grid stops at 3 hours." Under v2, 4 g/kg
  **is** reached at t−240.
- `spec/fueling/pre-workout-hydration-tiers.html` **is** a valid v6 explainer and its embedded JS
  `model()` reproduces all 21 hydration vectors exactly.
- Governance rule (`SSOT_REPO_NOTES.md`): where an `.html` and an `.md` disagree, **the `.md` wins**.

### Deviation from the manifest, recorded

The manifest names `OfflineMacroCalculator.calculatePreWorkoutTargets` as the carbs entry point.
We implement carbs v2 in a new, typed `calculatePreWorkoutCarbs` and have the legacy
`calculatePreWorkoutTargets` **delegate** its carb fields to it. Reason: `calculatePreWorkoutTargets`
also emits protein / fat / `meal_type` / water / sodium, none of which this bundle governs, and all
of which still feed food selection. Changing its whole shape would drag out-of-bundle behaviour.
The carb numbers are identical either way.

---

## 5. The BEFORE screen redesign

Xuan's Claude Design artifact **"pre-workout nutrition redesign v2"**
(`https://claude.ai/code/artifact/faa9dcad-cbc5-4a81-ab1d-350dbd865561`) is a **static visual
mockup**, not an interactive prototype — its controls do not respond, and it renders in a
cross-origin sandbox that cannot be scripted. A screenshot is archived at
`_artifact/pre-workout-redesign-v2-artifact.jpg`, and Xuan's **standalone bundled export is
checked in at `docs/pre-workout-macro.html`** (serve over HTTP to render — it is a JS-bundled
static design, one screen, no interactivity). Extracted styling facts: carbs/fluids values teal
`#1CF9CF` Sansita 28 px bold; sodium value dimmed cream `rgba(248,246,235,0.8)` — same size,
deliberately not teal; exactly two 3 px range bars (carbs, fluids) with diamond marker + tick and
end labels; feeding titles orange `#F78B14` Compadre 17 px; per-feeding values Sansita 16 px;
labels Apercu 11 px at 65 % cream.

What it shows, top to bottom:

- Activity header — back arrow, title (*Run – Long Run*), edit + delete icons, and a subtitle
  reading the frozen lead time (*Planned 3 hours ahead*).
- A **BEFORE** section header in amber with an ⓘ info affordance top-right (the drawer entry).
- **One row of three summary figures**: carbs (g), fluids, sodium (mg) — value above a small caps
  label, same rhythm as the existing screen.
- **Range bars under carbs and fluids only.** Each is a track with a marker and the two ends
  labelled (`50g … 140g`, `12 oz … 26 oz`).
- **Sodium has no bar, no marker, no ends** — matching sodium v3 and Xuan's "kept the observed
  sodium with no band".
- **Three stacked feeding cards**, furthest-out first, each with a disclosure chevron: **PRE-RUN
  MEAL** (`FINISH BY 2H OUT`), **PRE-WORKOUT SNACK** (`2H TO 30 MIN OUT`), **TOP-OFF**
  (`LAST 30 MIN`). Each shows its chosen food and its own per-feeding quantities on the right —
  carbs on all three, fluids on the meal card only.
- **No per-feeding sodium figure** anywhere, and no per-feeding range bars.

The numbers in the mockup are illustrative placeholders, not spec output (89 g / 16 oz / 310 mg
against a 50–140 g band is not what carbs v2 returns for a 3-hour lead).

### The working reference implementation

`spec/fueling/pre-workout-ui.html` is the interactive counterpart that *does* work, and it is
**the only drawer artifact in the bundle that is current with v6/v2/v3**. Serve it over HTTP
(`python3 -m http.server` from `spec/fueling/`) — `file://` will not load.

It is three things at once: a **live reference implementation** of carbs v2 and hydration v6 in
JS, an **interactive mockup** of the BEFORE card, and an **annotated design argument**. Its
thesis: *fill is what your food delivers, the white tick is what we suggest, the ends are the
permissible range; everything explaining where the number came from sits behind the ⓘ.*

Controls: four sliders — body weight (40–110 kg, step 5), **planned at** (0–240, step 15 — the
*frozen* lead time), **now** (0–`t`, the *clock* lead time), session duration (30–240) — plus an
ml/oz unit toggle and five presets (*Snack window · t−0 · Gated · Fasted · Reset plate*). The
phone mock has a Screen/Info-tab switch, three expandable feeding cards, a food picker per tier
that greys out rejected items **with the composition-ladder reason**, and the urine check inline
in the snack card (*Pale · Darker · Not gone yet · Not sure*).

Its two engine functions are a **faithful port** of the specs: every constant, share, threshold,
band and regime predicate matches, `K` is computed as `3.2/60`, and the band above `T_REF` is
correctly independent of `hydrationCheck` (invariant 8b). It also correctly models the *two
clocks* and the PW-020 check predicate.

### Discrepancies found in `pre-workout-ui.html` (raise with Xuan)

All are presentation/rounding/null-modelling, not engine math — but several contradict clauses the
specs mark binding. **These are UI-layer findings; none blocks the engine work.**

| # | Issue |
|---|---|
| **D-1** | **The one substantive bug.** `dFl` excludes top-off fluid *unconditionally* (`if(k!=="top")`). Below t−30 the top-off is the **only** tier, so the fluid meter can never move — add a 500 ml drink at t−15 and delivered stays 0 against a 279.7 ml target. The exclusion is only correct when a snack window exists. It also contradicts the page's own copy (*"There **is** time to drink, which is why the fluid number is not zero"*). |
| **D-2** | At `t = 0` the carb band renders as "0 … 0", which carbs v2 says the consumer **MUST** suppress. With the default plate this makes the top-off card compute `hi = 0` → state `over` → a fabricated error at the start line. |
| **D-3** | The per-feeding ±12.5 % solver tolerance still drives athlete-facing feedback — the *bar* was removed but `lo/hi` still produce a colour state and prose ("room for one more thing"). The brief says the tolerance "is not a range the athlete should see or aim at". Judgement call; needs ratification. |
| **D-4** | No provenance signal on the screen at all — the three chips live only in the info tab, while the brief says guideline- and Mealvana-derived numbers "**both appear on this screen at once, sometimes adjacent**" and must be tellable apart. |
| **D-5** | The carbs info-tab prose attributes a Mealvana design choice to the published guideline ("we scale it with how much time you have") under a **Published guideline** chip. Only the 1–4 g/kg *box* is Thomas 2016; the diagonal is ours. The fluid section handles the equivalent case correctly. |
| **D-6** | Rounding does not follow notes §6. Screen fluid ends are not rounded at all (780 where `ceil25` gives 800), and carb ends round the **floor up** (`r5(42.66) = 45`), narrowing the permissible floor — the floor25/ceil25 pattern exists precisely to widen, never narrow. |
| **D-7** | Gate and fasted paths return `0`, not `null`. Rendering branches on the flags so nothing is misreported on screen, but the data model conflates the two values both specs single out. |
| **D-8** | The fluid under-state is suppressed above `T_REF` too, where `5·BW` is a real cited floor — and the page's own info tab says the no-minimum rule applies *below* two hours. Self-contradictory; needs a ruling. |
| **D-9** | The meter autoscales (`max = Math.max(hi, delivered·1.06, target·1.15)`), so in the cited regime the printed end label no longer sits at the bar's edge. |
| **D-10** | The ml/oz toggle does not reach the info-tab formula chains — they hardcode `ml`. Same class as the 2026-08-03 units audit. |
| **D-11** | The `clearance_bound` regime is computed but never surfaced; notes §6 prescribes a different formula chain for it. |
| **D-12** | Required fine print missing: *"the plan is a starting point, not a prescription."* |
| **D-13** | Sources list omits Jeukendrup & Gleeson 2019 (source of `A0_ML = 250`, the exponential form, **and** the riboflavin caveat the page states unattributed) and Maughan 2016 (sole basis for the "electrolyte drink is not better than water" claim). |
| **D-14** | The carbs citation scope is described as time-only in the prose, but `evidenced_band` needs `dur >= 60` too — press *Gated* and carbs silently flips basis with no way to see it was session length. |

**Also worth flagging:** `pre-workout-ui.brief.md` §2 tells the consumer not to hardcode a feeding
name and cites `renderAs` — but carbs v2 **removed** `renderAs`. The HTML follows the ratified
spec, so **the brief is the stale document**, not the implementation.

### UI decisions that bind the engine consumer

- Three summary figures across one row — carbs, fluid, sodium.
- **Range bars: carbs yes, fluid yes, sodium no.** Delete the sodium target, marker, in-range
  state and colour change entirely.
- **Delete the per-feeding sodium figure.**
- Feedings show what they deliver and nothing else — one range bar per quantity, at the top.
- Below two hours the fluid bar has **no minimum** (`fluidLowMl = 0`), so a short fill is never a
  failure; only overshooting the far end is worth saying anything about.
- Three states must **never look alike**: a number that is zero · *no target set* (gated) ·
  *no recommendation at all* (fasted).
- Display rounding lives here, never in the engine: fluid `round25(fluidMl)` for the target and
  `[floor25(low), ceil25(high)]` for the band; carbohydrate rounds to **5 g**. Never display a raw
  engine value — `487.5 ml` reads as measured, and it is not.
- Occasion language (*sip / glass / bottle*) is a drawer threshold the consumer computes itself —
  the engine emits no `renderAs`.
