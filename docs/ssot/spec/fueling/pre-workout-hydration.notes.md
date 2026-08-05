# Notes — Pre-Workout Hydration

> **SUPERSEDED, 2026-08-03, by [`pre-workout.notes.md`](./pre-workout.notes.md)** — the combined
> hydration · carbohydrate · sodium notes, which is what the ratified SSOT points to. This file
> corresponds to hydration **v3/v5** and predates tiers, the urine check, the 12 ml/kg band top and
> the 240-minute input domain. **Do not cite it and do not update it.** Retained only for the source
> evaluation in its §3, which the combined file summarises rather than reproduces. Where it
> disagrees with anything ratified, it is simply out of date.

Companion to [`pre-workout-hydration.md`](./pre-workout-hydration.md), which is the SSOT and is
kept to the formula, the constants and the invariants. This file records:

- **why the algorithm has the shape it does** (§1);
- **the close calls** — decisions where a second answer was genuinely defensible, and which a
  future reader should re-examine rather than assume (§2);
- **what it checks out against in the literature** (§3), and **what concerns remain** (§4).

Trivial choices are not recorded. **Nothing here is ratified**; where it disagrees with the SSOT,
the SSOT wins.

---

## 1 · Why the algorithm has this shape

### 1.1 · One boundary, and it is epistemic

Thomas 2016 covers 2–4 hours before exercise and nothing else. Its complete pre-exercise fluid
guidance is one sentence:

> "Athletes may achieve euhydration prior to exercise by consuming a fluid volume equivalent to
> 5-10 ml/kg BW in the 2 to 4 hours before exercise to achieve urine that is pale yellow in color
> while allowing for sufficient time for excess fluid to be voided."

`T_REF = 120` is therefore not a physiological threshold — it is the edge of what a position
statement will say, and it is the only boundary in the algorithm. Above it the output is cited.
Below it the *shape* is ours, and `targetBasis` says so — but every **magnitude** the shape is
pinned to now comes from a named source (§1.5).

### 1.2 · Above 2 h: the band is cited, the point inside it is not

`low = 5·BW` and `high = 10·BW` are verbatim. `target = 7.5·BW` is **not** — Thomas names no point
in its range. `targetBasis: "evidenced_band"` is worded to carry exactly that distinction.

### 1.3 · Below 2 h: three outputs, three different kinds of claim

This is the structural idea the whole sub-2 h design rests on. The three numbers are not the ends
and middle of one interval; they answer different questions and have different standing.

| Output | Claim | Standing |
|---|---|---|
| `low = 0` | **Nothing is required.** An athlete already euhydrated may correctly drink nothing | NATA 2017, near-verbatim |
| `target` | **What we recommend** | Our interpolation between two cited endpoints |
| `high` | **The most that may be taken** | Cited maximum, clamped by measured physiology |

`low = 0` is supported directly:

> "Recreational athletes should not need to consume extra fluids before activity but should begin
> exercise euhydrated." — NATA 2017

and indirectly by Thomas's own framing: the volume is instrumental — *"to achieve urine that is
pale yellow"* — so an athlete already at the endpoint has nothing left to achieve.

`target` declines toward the start because the position statement leans that way without giving a
number. The stated purpose of its window is *"allowing for sufficient time for excess fluid to be
voided,"* and its only other remark touching the pre-event period is a caution: over-drinking
*"can also be compounded by excessive fluid intake in the hours or days leading up to the event."*

There is a second, independent reason it declines, about *purpose* rather than comfort: **fluid
still in the stomach at the gun has not hydrated the athlete yet.** It will be absorbed during the
session — which is what the during-workout plan already covers. Volume added very late is a head
start on delivery, not prehydration.

Note what the taper is **not**: it is not a claim that late fluid is harmful. Under the current
constants it runs from 250 ml at the gun to 7.5 ml/kg at t−120 — a decline of roughly 2×, not 4×.
See §2.5.

### 1.4 · The ceiling, and where it binds

```
high = min( 10·BW , R_CEILING·e^(Kt) )
```

Gastric emptying of a liquid bolus is first-order and volume-dependent (J&G 2019 p. 130):

> "The rate of gastric emptying of a fluid is highly dependent on the volume of the fluid in the
> stomach (Hunt and Donald 1954). Therefore, the rate of gastric emptying from a fluid bolus is
> exponential… The gastric-emptying phase is initially rapid, and when the volume is reduced, the
> rate of gastric emptying is reduced accordingly."

Mudie 2014 supplies the coefficient for that form directly, from MRI in fasted humans (§2.4).
`R_CEILING·e^(Kt)` is therefore the volume that leaves `R_CEILING` ml behind at the gun.

**It binds only near the start.** Handover, `t = ln(10·BW / R_CEILING)/K`:

| BW | ≤40 | 45 | 50 | 65 | 80 | 100 | 130 |
|---|---|---|---|---|---|---|---|
| handover (min) | never | 2.2 | 4.2 | 9.1 | 13.0 | 17.2 | 22.1 |

This is a **large change from earlier drafts**, where the clearance term shaped the whole
near-window ceiling (handover at ~50 min for a 65 kg athlete). Choosing published constants over
constructed ones moved it. That is the right trade on provenance and a real loss on shaping —
recorded as a concern in §4.10, not buried here.

### 1.5 · Every load-bearing magnitude is now a published number

The governing rule for this spec: *a load-bearing part must not be constructed by us.* Applied
literally, it retired four constants that were arithmetic on our part (`K` from a book sentence,
`R` from a converted figure, `A0` as half of `R`, the "slow tail" percentile choice) and replaced
them with three published values used at their published magnitude:

| Parameter | Value | Source | Used as |
|---|---|---|---|
| `A0_ML` | 250 ml | J&G 2019 p. 493 — 250 ml immediately pre-start | The dose at `t = 0` |
| `R_CEILING` | 400 ml | NATA 2017 — 400–600 ml in the stomach optimizes emptying | The residual the ceiling targets |
| `K` | 3.2 h⁻¹ | Mudie 2014 — published mean first-order coefficient | The emptying rate |

Nothing between them is scaled, halved, averaged across sources, or converted through a constant
we chose. What remains ours is the **shape**: a straight line between two cited endpoints, and the
decision to hold 10 ml/kg flat below the window. Those are labelled `design_choice`.

### 1.6 · What the number *is*: a window total, sipped, and subordinate to the urine cue

The algorithm was designed before anyone said out loud what `fluidMl` denotes, and the ambiguity
was ours, not the source's. Thomas 2016 says the volume is consumed *"in the 2 to 4 hours before
exercise"* — **a window integral, not a dose event.** Read that way, the cited band was always
cumulative, and carrying the same semantics below `T_REF` is not an extension at all.

So: `fluidMl` is **the total for the interval from now to the start**, taken in comfortable amounts
across whatever time remains. At t−120 that is two hours of sipping; at t−15 it is a glass over
fifteen minutes. The number scales with lead time *because lead time is the width of the window it
integrates over* — which is a cleaner statement of why the curve declines than any of the comfort
or absorption arguments in §1.3, and it subsumes them.

Two riders, both contractual (SSOT, "What `fluidMl` means"):

- **The urine cue outranks it.** Thomas's volume is explicitly instrumental — *"to achieve urine
  that is pale yellow in color."* The endpoint is the state, not the volume. Where the two
  disagree the athlete follows the cue. This is why `fluidMl` must never appear without it.
- **It is a recommendation, not a quota.** With `low = 0`, an athlete who drinks nothing is in
  spec. A progress ring, a "0 / 488 ml" counter, or anything else that renders the number as a
  target to be *completed* contradicts the spec — it converts a recommendation into a requirement
  and imports precision the number does not have.

The divided-dose part is ours. No source prescribes a pre-exercise sipping schedule; the nearest
statements — J&G p. 247's *"frequent consumption (every 15-20 minutes) of small volumes (120-180
ml)"* and NATA's 200 ml every 15–20 min — are both about drinking *during* exertion. It is a
design choice with a GI-comfort rationale (§1.3), labelled as one.

---

## 2 · Close calls

Decisions where a second answer was defensible. Each should be re-examined on its own terms rather
than inherited.

### 2.1 · `high` below 2 h — extend 10 ml/kg, or taper it down?

**Chosen:** hold the cited maximum flat and let gastric clearance pull it down near the start.
**Alternative:** taper `high` linearly from 10 ml/kg at t−120 to `R_CEILING` at the gun.

The taper has an appealing property: with a linear `low` it makes the target algebraically equal
to the band midpoint, so "target = midpoint of the band" would hold everywhere as one rule.

**Rejected because the taper is invented and the flat extension is not.** 10 ml/kg is the most
Thomas sanctions; nothing in the corpus suggests that *less* is permissible sooner. Substituting an
invented ceiling to make a tidy rule come out true is the failure `targetBasis` exists to catch,
and it makes the permissible range narrower than any source supports.

**Cost of the choice:** the band is wide — at 65 kg, t−45 it is 0–650 ml — and the target does not
sit at its midpoint. See §4.2. **And see §4.11:** the flat extension is bounded on the gastric side
only.

### 2.2 · `target` below 2 h — an interpolation, or the band midpoint?

**Chosen:** an explicit straight line from `A0_ML` at the gun to 7.5 ml/kg at t−120.
**Alternative:** compute it as `(low + high)/2`, keeping one rule for the whole range.

With `low = 0` the midpoint is just `high/2` — 325 ml at t−60 for a 65 kg athlete against the
interpolation's 369, and 325 vs 280 at t−15. Close in magnitude, but the midpoint would mean **the
recommendation is defined by the safety ceiling**, which is the wrong dependency: a change to
`R_CEILING` or `K` made for clearance reasons would silently move the recommended dose. Worse, it
would make the recommendation scale purely with body weight at exactly the point where the cited
evidence is a **fixed volume**, not a per-kg one.

**Kept separate so the safety bound and the recommendation can move independently.**

**Open:** the line's *shape* is linear, chosen for explicability — "it comes down evenly" survives
contact with a drawer. A geometric interpolation is the obvious alternative and would run lower in
the middle. Nothing sources either. This is the largest remaining unsourced element in the spec,
and it is deliberately the *least* load-bearing one: both of its endpoints are cited, so the error
it can introduce is bounded by the gap between them.

### 2.3 · `low` below 2 h — zero, or a tapered minimum?

**Chosen:** `low = 0` for all `t < T_REF`.
**Alternative:** taper the cited minimum, `5·BW·(t/120)` — 150 ml at t−60 for a 65 kg athlete.

The tapered minimum was the earlier design and it is the more conventional shape, but it **asserts
something no source does**: that at t−60 a 65 kg athlete must drink at least 150 ml. Nothing in the
corpus states any sub-2 h minimum. Zero is what "no requirement stated" actually means, and NATA
2017 states the positive case directly (§1.3).

It also **removes a contradiction with our own copy.** The fine print tells the athlete *"if you're
already pale, you likely need less than the number shows."* Under a tapered minimum, following that
advice puts them out of spec. Under a zero floor it does not.

**Costs, both real:**

- `low` becomes **discontinuous at `T_REF`** — a step from 0 to `5·BW` (325 ml at 65 kg). This is
  defensible: the step is exactly where the position statement's authority begins. It is pinned by
  a conformance vector so a later refactor cannot "smooth" it.
- The permissible range becomes maximally wide, and any invariant of the form *"delivered fluid
  within [low, high]"* becomes vacuous below 2 h. The SSOT excludes that window from such checks
  rather than letting them pass trivially. See §4.2.

**Tension to note:** QA's standing department rule is *"band width encodes execution latitude;
uncertainty goes in the confidence tag; a missing input goes in a branch."* A zero floor could be
read as putting the missing hydration-status input into width. The counter-argument is that zero
is genuinely *correct* for some athletes — that is latitude, not uncertainty — but the rule is QA's
and this is the case that tests it.

### 2.4 · `K` — which emptying coefficient, and from which paper?

**Chosen:** Mudie 2014's published mean, **3.2 h⁻¹** (T50 = 13 min), used verbatim.

Three primary papers were read in full and compared:

| Paper | What it reports | Usable as `K`? |
|---|---|---|
| **Mudie 2014** (Mol Pharm 11(9):3039–47; n = 12, 240 ml water, fasted, MRI) | *"an average first-order gastric emptying rate coefficient of 3.2 h⁻¹ (T50% of 13 min), with a range of 2.2−6.0 h⁻¹, would be a good starting point for the analysis"* | **Yes** — states a first-order coefficient in the exact form the model needs |
| **Grimm 2018** (Eur J Pharm Biopharm 127:309–17; n = 120) | 85 ± 13 % emptied at 30 min; emptying complete 15–60 min; model-**independent** AUC | No — *"model dependent parameters like t1/2 were not able to describe all different curves sufficiently well."* The paper explicitly declines to publish a t½ |
| **Bertoli 2022** (Neurogastroenterol Motil, review) | T50 for water ≈ 7 min; normal limit for zero-calorie liquid < 25 min | No — a review of heterogeneous methods; *"the T50 is heavily dependent on the model utilized"* (only 4 % of studies used the same model) |

Mudie is the only one of the three that hands over a first-order coefficient. It is used as
published; nothing is recomputed.

**The percentile question — why the mean and not the slow tail.** The earlier draft used a
slow-emptier constant equivalent to 2.2 h⁻¹, on the argument that the ceiling should protect the
person who empties slowest. Two things overturned it:

- **The ceiling is a permission, not a recommendation.** It answers *"what is the most I may take?"*
  A maximum designed for the 96th-percentile slow emptier under-permits everyone else. The
  recommendation — the number most users will actually follow — is `target`, and `target` is far
  below the ceiling everywhere.
- **2.2 h⁻¹ is not the "conservative end of a range," it is the tail.** Mudie's 2.2−6.0 is the
  observed spread, and 2.2 h⁻¹ is T50 ≈ 18.9 min against a mean of 13.0 min. With T50 = 13 ± 1 SEM
  at n = 12 (SD ≈ 3.5 min), 18.9 min sits at roughly **+1.7 SD, ~96th percentile for slowness** —
  not a mild safety margin. Note the direction trap here: the ±1 figure Mudie reports is in **T50
  space and is a standard error**, not a standard deviation in rate space. Always state which:
  *"the k of a T50-mean-plus-2-SD emptier,"* never a bare "mean + 1 SD."

**Live caveat, kept in view.** Mudie: *"For about half of the subjects, the second part of the
gastric emptying curves deviated from the initial single exponential."* The single-exponential form
is a good description of the **early, high-volume** phase and a poorer one of the tail — which is
tolerable here, because the ceiling only binds in the first ~20 minutes, i.e. exactly the phase the
fit describes well. Also: Mudie dosed **240 ml in fasted, resting subjects**. Our ceiling is applied
to doses several times larger, in athletes who may have eaten. Larger boluses empty *faster*
initially (J&G p. 130), so extrapolating up is conservative in the right direction; food in the
stomach is not, and is not modelled.

**What the mean costs.** A genuinely slow emptier following the ceiling at t−15 could start with
more in the stomach than intended. Mitigation is that the ceiling is a maximum almost nobody
targets, and the fine print says *"don't push fluid past comfort."* It is not a resolution — see
§4.5, which is the same missing-individualization gap in another guise.

### 2.5 · `A0_ML` and `R_CEILING` — one constant, or two?

**Chosen:** two constants from two sources — `A0_ML = 250` (a dose) and `R_CEILING = 400` (a
tolerated residual).
**Alternatives considered:** a single `R = 250` with `A0 = R/2`; or a single `R = 500` with
`A0 = 250`.

The earlier design used one constant for both jobs, with the start-line dose set at half of it.
That was **two constructions stacked**: the residual figure was itself converted from a published
500 ml through an emptying constant we had chosen, and then halved for a reason we invented. Under
the current `K` the same conversion lands on 225, not 250 — which is the tell that the number was
an artefact of the conversion rather than a finding.

Splitting them fixes both halves with citations:

- **`A0_ML = 250` — J&G 2019 p. 493**, 250 ml taken immediately before going on court. At `t = 0`
  everything drunk is still in the stomach, so this is simultaneously a published *dose* at the
  start line. Used at face value.
- **`R_CEILING = 400` — NATA 2017**: *"Maintaining 400 to 600 mL of fluid in the stomach optimizes
  gastric emptying."* This is the only statement found in the corpus that quantifies a **tolerated
  gastric volume around exercise**, and it is in a position statement the spec already cites.

**Why 400 and not 600.** NATA gives a band; we take its bottom. Taking the top would make the
clearance term almost entirely vestigial — at 600 it would not bind at all for any athlete under
60 kg, and only in the final ~4 minutes at 65 kg. 400 keeps it doing at least some work while
staying inside the cited range. **This is the one place a value inside a cited band was chosen by
us**, and it is chosen in the conservative direction.

**Why not `R = 500` with `A0 = 250`** (the variant that keeps one constant and takes the anchor
from J&G): 500 ml is above NATA's band and is not itself a residual figure anywhere; and at 500 the
clearance term stops binding entirely for any athlete ≤ 50 kg, which is the population the GI
argument most concerns.

**The coupling that used to exist is gone.** Changing the residual tolerance for GI-comfort reasons
no longer moves the recommended dose at the gun. That was the main structural argument for the
split, independent of provenance.

**Consequence to be aware of:** near-window targets roughly doubled versus the earlier draft
(125 → 250 ml at the gun, 170 → 280 at t−15), and the decline from t−120 to t−0 flattened from
about 4× to about 2×. If the near-window recommendation now feels too generous, the lever is
`A0_ML` — but it is cited, so lowering it means arguing with p. 493, not tuning.

### 2.6 · `tier` — retire it, or renumber it?

**Chosen:** retire the integer; emit a string `regime`.
**Alternative:** keep `tier` and renumber it for v4.

The shipped client branches on **v1 semantics** — `1 = body-weight scaled, 2 = fixed 250 ml
top-up, 3 = no hydration` — in `macro_explanation_service.fluid.dart:66` and
`macro_explanation_service.calculations.dart:643`, reading `pre_run_hydration_tier` from the edge
function. A Flutter client and a Supabase edge function deploy separately and users run old
builds, so **no integer mapping is safe**: an old client receiving a new integer mis-renders
silently rather than failing. A string cannot be silently misinterpreted.

**Cost:** a coordinated client-then-server-then-engine release. See §4.3.

### 2.7 · The gate — keep it, or drop it?

**Chosen:** keep, unchanged from v3.
**Alternative:** drop it, since `low = 0` now lets a hydrated athlete correctly drink nothing
anyway.

Kept because the two do different things: `low = 0` says *nothing is required*; the gate says *we
are not setting a target at all*, which is the honest output when NATA's carve-out applies. The
`null` vs `0` distinction carries that difference and must not be collapsed.

**But the proxy is broader than its source** — see §4.4. This is the weakest constant in the spec.

### 2.8 · Rounding — in the engine, or in the drawer?

**Chosen:** the engine emits exact values; the drawer rounds for display.
**Alternative:** keep v3's engine-side rounding (`floor` / half-away / `ceil` to 25 ml).

v3 introduced 25 ml rounding to retire false precision — *"488 ml reads as measured; 500 ml reads
as advice, which is what it is."* **That reasoning is unchanged and still correct for anything a
user sees.** What changed is where it costs something.

v3's output was a step function, so rounding cost nothing. v4's target and ceiling are continuous
by construction, and rounding **reintroduces 25 ml discontinuities into a function the design
worked to make smooth** — wherever a raw value crosses a granularity boundary, including exactly
at `T_REF`, where `5·BW` frequently lands on a multiple of 25. That forced the continuity invariant
to be stated on pre-rounding values with a caveat explaining why the obvious test fails. A rule
that requires a footnote in the invariant that tests it is in the wrong layer.

Moving it to the drawer keeps the user-facing benefit and buys three things: continuity holds on
the actual outputs, conformance vectors compare engine values rather than display artefacts, and
the solver allocates against an exact number (foods do not come in 25 ml increments either).

**Cost:** the drawer's header and the engine's `fluidMl` are no longer bit-identical, so the
drawer contract changes from *"target MUST equal `fluidMl`"* to *"target MUST equal
`round25(fluidMl)`"*. One rule, one layer — see §5.

### 2.9 · No absolute cap

An absolute ceiling of ~1,000 ml was considered, on J&G p. 240 (*"more than about 1 L… feels
uncomfortable for most people when exercising"*). **Dropped:** that figure is a gastric volume
*during exercise*, not a dose spread over 2–4 hours, and capping the cited 5–10 ml/kg band with a
textbook aside would put a secondary source above a position statement. The clearance ceiling is
the physiologically correct bound and is already in the formula. Consequence: `high` exceeds 1 L
above 100 kg, where it equals Thomas's own 10 ml/kg.

---

## 3 · Checked against the literature

### 3.1 · The containment property

Machine-checked across body weights 10–160 kg at 0.1-minute resolution over t = 0–240:

```
0  ≤  fluidLowMl ≤ fluidMl ≤ fluidHighMl  ≤  min(10·BW, R_CEILING·e^(Kt))
```

Zero violations, plus monotonicity of `fluidMl` in `t` and continuity of `fluidMl` and
`fluidHighMl` at `T_REF` over the same sweep.

**The algorithm never recommends, and never permits, more than the cited maximum, and never more
than can be cleared.** At `t ≥ 120` the output is a strict subset of Thomas's sanctioned range.
That is the whole non-contradiction claim, and it is a test rather than an assertion.

### 3.2 · Statement by statement

| Source statement | What the algorithm does | Verdict |
|---|---|---|
| **Thomas 2016** — 5–10 ml/kg in the 2–4 h before | Implemented verbatim at `t ≥ 120` | ✅ exact |
| **Thomas 2016** — "urine that is pale yellow" | Required output; the endpoint cue | ✅ |
| **Thomas 2016** — "allowing sufficient time for excess fluid to be voided" | Target declines toward the start; fine print adds the void-before-start step | ✅ / ⚠️ §4.11 |
| **Thomas 2016** — silent below 2 h | Everything below `T_REF` is `design_choice`; `low = 0` | ✅ |
| **Thomas 2016** — over-drinking "in the hours or days leading up to the event" compounds hyponatremia | Target declines toward the start; warning in fine print | ✅ |
| **Thomas 2016** — sodium in pre-exercise fluids aids retention | Qualitative copy only, no number | ✅ |
| **NATA 2017** — "Maintaining 400 to 600 mL of fluid in the stomach optimizes gastric emptying" | `R_CEILING = 400`, bottom of the band | ✅ |
| **NATA 2017** — issues no volumetric *prehydration* figure | Not cited for any dose | ✅ |
| **NATA 2017** — recreational athletes need no extra pre-activity fluid | `low = 0` below 2 h; the gate | ✅ / ⚠️ proxy — §4.4 |
| **NATA 2017** — 200 ml every 15–20 min during activity | Not modelled here; belongs to the during-workout spec | n/a |
| **NATA 2017 Rec 18** — individualize | Not implemented | ⚠️ §4.5 |
| **Mudie 2014** — mean first-order coefficient 3.2 h⁻¹, range 2.2–6.0 | `K = 3.2/60`, used as published | ✅ exact |
| **Mudie 2014** — half of subjects' curves deviate from a single exponential in the later phase | Ceiling binds only in the first ~20 min, i.e. the early phase | ✅ with caveat — §2.4 |
| **Grimm 2018** — 85 ± 13 % emptied at 30 min | Our ceiling implies 80 % cleared at 30 min | ✅ consistent |
| **Grimm 2018** — declines to publish a t½ | Not used as a source for `K` | ✅ |
| **Bertoli 2022** — normal T50 for zero-calorie liquid < 25 min | `K` gives T50 = 13 min, inside normal | ✅ |
| **J&G p. 130** — emptying is exponential and volume-dependent | Functional form of the ceiling | ✅ |
| **J&G p. 131** — dehydration and hyperthermia slow emptying | Not modelled; argues the ceiling is optimistic for the dosed population — §4.10 | ⚠️ |
| **J&G p. 130–131** — osmolarity irrelevant at 200–400 mOsm/L | Sodium content does not enter the model | ✅ |
| **J&G p. 130** — 2 % CHO slows emptying, ≥ 8 % significantly inhibits | Not modelled; handled in copy | ⚠️ §4.6 |
| **J&G p. 132** — running has the highest GI-symptom rate | Argues the decline toward the start | ✅ |
| **J&G p. 240** — > ~1 L in the stomach is uncomfortable *during exercise* | `high` exceeds 1 L only above 100 kg, where it equals Thomas's 10 ml/kg. Different quantity | ✅ §2.9 |
| **J&G p. 247** — keep gastric volume "as high as is comfortable" *during* exercise | Consistent with `R_CEILING` being a head start on delivery, not a pure cost | ✅ |
| **J&G p. 491** — marathon: fluid 10–15 min before the start | Target non-zero there (280 ml at t−15, 65 kg) | ✅ |
| **J&G p. 492** — marathon: at least 500 ml about 2 h before | Target at `t = 120`, 65 kg = **487.5 ml** | ✅ |
| **J&G p. 493** — tennis: 250 ml immediately pre-start | `A0_ML`; target at `t = 0` is exactly 250 ml | ✅ exact |
| **J&G p. 489** — soccer: 0.5–1 L at 1.5–2 h before | Our ceiling at t−90 (65 kg) is 650 ml; the top of that range is above it | ⚠️ §3.3 |
| **J&G p. 247** — ADA/DC: 500 ml about 15 min before prolonged exercise | Contained in our band for `BW ≥ 50` (ceiling 650 ml at 65 kg); our target there is 280 ml | ✅ contained, **not corroborated** — the source is unusable, §3.3 |
| **J&G p. 247** — "frequent consumption (every 15-20 min) of small volumes (120-180 ml)" | Nearest statement to our divided-dose advice, but it is about drinking *during* exertion | ⚠️ analogy only — §1.6 |
| **Thomas 2016** — "in the 2 to 4 hours before exercise" | All outputs are window-cumulative, not boluses | ✅ exact — §1.6 |
| **J&G p. 150** — carbohydrate at t−5 prevents rebound hypoglycaemia | Consistent: no zero region; fluid remains available at t−5 | ✅ |

### 3.3 · Sources evaluated and not used

**J&G p. 247, the ADA/DC 500 ml at t−15.** The full paragraph, verbatim, because the context is
load-bearing:

> "Guidelines for the amount of fluid to be consumed before, during, and after exercise can only be
> general because of the large variation in individual sweating responses. **The American and
> Canadian Dietetic Associations recommend that approximately 500 ml (17 fl oz) of fluid be
> consumed 2 hours before exertion and another 500 ml (17 fl oz) be consumed about 15 minutes
> before prolonged exercise.** In hot and humid environments, frequent consumption (every 15-20
> minutes) of small volumes (120-180 ml [4-6 fl oz]) of fluid are recommended throughout exertion.
> Detailed recommendations on fluid replacement strategies during and following exercise have been
> given in the ACSM position stand on exercise and fluid replacement (American College of Sports
> Medicine 2007)."

Four features of that context, all of which cut against using it:

- **It is not a prehydration passage.** It sits under the section heading **"Ensuring Hydration
  *During* Exercise."** The paragraph's subject is drinking during exertion; the pre-exercise
  figures are preamble, and the sentence immediately after is a during-exertion sipping schedule.
- **The paragraph's one citation belongs to a different sentence.** "(American College of Sports
  Medicine 2007)" is attached to *"detailed recommendations on fluid replacement strategies during
  and following exercise"* — not to the ADA/DC figures, which carry no marker and no year.
- **There is no matching reference-list entry.** The bibliography's only American Dietetic
  Association entries are a 1997 paper on dietary fibre and a 2007 position on *communicating*
  nutrition information. Nothing on sport nutrition; nothing with Dietitians of Canada. The phrase
  "Canadian Dietetic" appears **exactly once in 617 pages** — in this sentence.
- **It is scoped to "prolonged exercise,"** which the spec's gate only loosely proxies.

The attribution names two of the three bodies behind Thomas 2016 (ADA was renamed the Academy of
Nutrition and Dietetics in 2012), which *suggests* an earlier edition of the same joint statement;
**this could not be confirmed against a primary source, and the current edition of that lineage
contains no late top-up at all.**

An earlier draft used the figure as a corroborating "second anchor" for the residual constant. That
was wrong twice over — it is uncited, and it was not independent of the first anchor. **Under the
current constants it now falls inside our permissible band** (at t−15 our ceiling is
`min(10·BW, 890)`, so 500 ml is permitted for `BW ≥ 50`; below 50 kg it is still above our
ceiling). That is a coincidence of adopting Mudie's coefficient, **not corroboration** — nothing
about the figure's provenance improved. It must not be readmitted as support on the strength of
fitting.

Note also that it is a **two-dose schedule** — 500 ml at t−120 *and* 500 ml at t−15, ~1,000 ml
total, which exceeds our whole-window ceiling for any athlete under 100 kg. Comparing our single
t−15 target of 280 ml against its 500 ml top-up compares different quantities; see §4.13.

**J&G p. 131, "20–30 % … 70–80 % in 15 minutes."** This sentence was the basis of `K` in earlier
drafts. It carries **no citation at that point in the book**; the nearest reference (Jeukendrup
2017b) belongs to the following sentence, about dietary adaptation, and *Training the Gut for
Athletes* does not contain the figure either. Replaced by Mudie 2014, which is primary, and the
question is closed — see §2.4.

**J&G p. 489, soccer's 0.5–1 L at 1.5–2 h.** From ch. 17, which the authors state is uncited —
*"We do not include citations in this part of the chapter because the information has been
distilled from hundreds of articles"* — and the same chapter explains that soccer front-loads
because FIFA rules restrict in-play drinking. A sport-model difference, not a physiological one.

**J&G p. 250, "6 to 8 ml/kg about 2 hours before."** The sidebar is labelled ACSM 2007 but
reproduces ACSM **1996** content — verified against the 1996 stand directly (500 ml at ~2 h; sodium
0.5–0.7 g/L during exercise > 1 h). The per-kg figure is a rendering of a fixed 500 ml, not an
independent measurement, and its ancestor is two generations superseded. **It cannot corroborate
the 5–10 band.** Do not cite it.

**The anaesthesia / pre-operative fasting literature.** Searched as a possible source of tolerated
gastric volume, and deliberately **not used**. Its threshold quantities (the classic 25 ml / 1.5 ml
per kg "risk of aspiration" figures) answer a different question — aspiration risk under airway
loss — and are widely disputed within that field. Signposted here so the next reader does not
re-walk it.

**IOM / habituation.** Repeated exposure to gastric volume increases tolerance, which is why elite
endurance athletes train the gut. This means any single tolerated-volume constant is population
average, not a physical limit. Noted, not modelled — there is no input to key it on.

---

## 4 · Concerns

### 4.1 · Provenance is now clean; the shape is still ours

The blocking item in earlier drafts — `K` resting on an uncited textbook sentence — is **resolved**
(§2.4, §3.3). What remains unsourced is deliberate and labelled:

- the **linear** interpolation between the two cited endpoints (§2.2);
- holding 10 ml/kg **flat** below the window rather than tapering it (§2.1);
- the choice of **400 rather than 600** inside NATA's cited band (§2.5);
- the gate's thresholds (§4.4).

All four ratify as `design_choice`. None of them can move an output outside a cited endpoint.

### 4.2 · `[low, high]` is a permissible range, not a tolerance

With `low = 0` below 2 h the range is 0–650 ml at t−60 for a 65 kg athlete. It expresses
**headroom**, not execution latitude. Two consequences:

- Any invariant of the form "delivered fluid within `[low, high]`" is vacuous below `T_REF`. The
  SSOT excludes that window explicitly; it must not be left to pass trivially.
- The drawer's range bar must be built to show the marker **off-centre**, and must not present the
  floor as an instruction. It will look like a bug. It is not.

This is the largest UI-side risk in the spec.

### 4.3 · The `tier` field cannot be renumbered — coordinated release required

Per §2.6. Order of work: update the client to `regime` and to consuming `gateTriggered` → change
the edge-function field name → ship the engine.

Related and independent of v4: `fluid.dart:82` infers the gate as
`isTier3 && durationMin < 60 && tempC < 30` rather than reading `gateTriggered`, which the spec
emits and nothing consumes. Two sources of truth for one boolean, one of them in the UI.

### 4.4 · The gate's proxy is broader than its source

NATA's carve-out is about *recreational athletes*; the gate keys on duration and temperature, and
the literature does not support those thresholds:

- The only cited duration figure is **30 minutes, not 60**, and it concerns intake *during*
  exercise (J&G p. 242: *"Fluid intake during strenuous exercise of less than 30 minutes offers no
  advantage"*).
- **30 °C appears nowhere as a prescriptive threshold.** J&G table 9.4 puts marathon sweat loss at
  800–1,200 ml/h at **15–20 °C** — inside the gate's "cool" branch — and p. 242 notes sweat loss can
  exceed 1 L/h at 12 °C.

A 55-minute run at 18 °C is gated to no target while plausibly losing ~700 ml. Whether that is
acceptable is a product judgement, and it is the substance of the standing question: does a
pre-workout fluid target belong in the product for recreational users at all, or only for
competitive / endurance / hot-condition sessions?

### 4.5 · Everyone of a given weight gets the same number

Both position statements make hydration *status* the thing to assess, and NATA Rec 18 (SOR: B)
calls for individualization. The algorithm cannot distinguish an athlete who drank at 4 h from one
who woke twenty minutes ago carrying an overnight deficit. `low = 0` widens the range so that a
hydrated athlete is in spec drinking nothing, and the fine print hands over the same discriminators
the statements use — but that is a mitigation, not a resolution.

**This is the gap that would make the recommendation actually correct**, and no amount of curve
shaping substitutes for it. If a hydration-status input is added, the natural place for it is the
interpolation's start-line anchor or its slope, not a repositioning inside the band.

Note also the existing drawer advisory — *"if urine is still dark at 2 h out, add 3–5 ml/kg"* —
puts an athlete at **10.5–12.5 ml/kg, above Thomas's own 10 ml/kg ceiling** and above
`fluidHighMl`. It is sourced from the superseded Sawka 2007 protocol. Recommend retiring it.

### 4.6 · Carbohydrate, not sodium, is the drink-composition risk

Sodium does not affect gastric emptying — it does not appear among ch. 5's factors, and the only
route (osmolarity) is explicitly closed at sports-drink concentrations. It acts downstream:
intestinal absorption via glucose–sodium cotransport (p. 242) and renal retention (p. 249). The
ceiling is therefore sodium-independent.

Carbohydrate is different — p. 130: 2 % solutions *"show a tendency to empty slower than water,"*
and *"solutions of 8 % or more significantly inhibit gastric emptying."* A typical sports drink is
6–8 %. `pre-workout-sodium.md`'s copy says *"a salty snack or an electrolyte drink"*; following
that with a standard bottle slows the very clearance `K` assumes — and `K` is now a **water**
constant from a water study, which sharpens this. The copy should specify a **low-carbohydrate**
electrolyte drink, or salty food plus water.

### 4.7 · `targetBasis` above 4 hours

Thomas's window closes at 240 min. The algorithm returns the cited band for all `t ≥ 120` with no
upper branch, so it reports `"evidenced_band"` at t−300. The 4-hour cap was decided as copy rather
than code because it is a numerical no-op; it is a no-op for the numbers but not for the basis
field. Unresolved by design.

### 4.8 · The `low` step at `T_REF` is visible to users

A workout moved by one minute across the 2-hour line changes the displayed floor from 0 to
`5·BW`. Nothing about the recommendation changes — `target` and `high` are continuous — but a user
watching the range chip will see it jump. Either the chip explains the boundary or it does not
render the floor below 2 h.

### 4.9 · Thomas 2016 is ten years old

Authoritative for the claims cited here, and known to be superseded on at least one point — it
describes glycerol as WADA-prohibited, and glycerol was removed from the prohibited list in 2018.
Whether a newer joint position statement exists has not been verified; if one does, it supersedes
the band, the window and §4.4.

### 4.10 · The clearance ceiling barely binds any more — examine before ratifying

Adopting published constants moved `K` from 0.0192 to 0.0533 /min and the residual from 250 to
400 ml. **Both changes push the same way**, and the combined effect is large: for a 65 kg athlete
the clearance term used to bind out to t−50 and now binds only to **t−9**; for anyone at or below
40 kg it never binds at all. Practically, the sub-2 h ceiling is now `10·BW` almost everywhere,
with a short clearance taper in the last few minutes.

Three ways to read this, and they are not all the same:

1. **It is correct and the earlier shape was an artefact.** The old handover at t−50 was produced
   by two constructed numbers; measured constants say emptying is faster than the textbook sentence
   implied. On this reading nothing needs fixing.
2. **It is correct but no longer useful as a product mechanism.** The clearance ceiling was
   supposed to be the thing that made the near-window numbers feel physically grounded instead of
   arbitrary. That job has quietly transferred to the target interpolation, which is the *least*
   sourced part of the spec (§2.2). Worth being honest about.
3. **It is optimistic for the population being dosed.** Mudie's subjects were fasted, resting and
   euhydrated. J&G p. 131: dehydration and hyperthermia both slow emptying — and a hypohydrated
   athlete about to exercise in the heat is precisely who the pre-workout target exists for. The
   `K` we cite is measured on the wrong population in the unsafe direction, which is the strongest
   surviving argument for the slow-tail constant this draft rejected (§2.4).

**Recommendation: ratify as-is, revisit if GI complaints appear near the start line.** The lever, if
one is needed, is `K` — and the honest version of that lever is not "pick a slower percentile"
but "find a study that measures emptying in exercising or heat-stressed subjects." None was found.

### 4.11 · The sub-2 h ceiling is bounded on the gastric side only

Holding 10 ml/kg flat below 2 h extends a figure outside the window whose **entire stated
justification was the time that window provides** — *"while allowing for sufficient time for excess
fluid to be voided."* The clamp we added addresses the stomach. It does not address the kidney.

A 100 kg athlete permitted 1,000 ml at t−30 will clear it from the stomach, and the model says so
correctly — but they will not have voided the excess by the start, which is the thing Thomas's
2–4 h window exists to allow. There is no renal term in the model and no source in the corpus gives
one. Mitigations are procedural, not numeric: the fine print's *"empty your bladder before you
start"* and the fact that `target`, not `high`, is what users follow.

**This is the weakest link in the sub-2 h ceiling argument.** It is not fixable with the current
corpus; it is stated so that "the ceiling is bounded by physiology" is not read as more than it is.

### 4.12 · The start-line anchor is duration-blind

`A0_ML = 250` is applied to every session. For a 2-hour run with a fuelling plan, 250 ml at the gun
is a sensible head start on delivery. For a 60-minute session with no bottle, it is closer to pure
cargo — carried, not used.

The spec already knows `workoutDurationMin` (the gate uses it). If this distinction matters, the
lever is a **duration-conditional anchor**, not a smaller constant applied to everyone — lowering
`A0_ML` for all users to fix the short-session case would mean arguing with the p. 493 citation
that makes it defensible. Not implemented; noted so the option is on the record.

### 4.13 · The engine is stateless with respect to prior intake

`fluidMl` is the total for `[now, start]` (§1.6). The engine has no input for what the athlete has
already drunk inside that window, so **two athletes in materially different states get the same
number**: one who followed the plan at t−120 and reopens the drawer at t−15, and one who has drunk
nothing all morning, both see 280 ml at 65 kg. For the first that is roughly double-counting; for
the second it is arguably the correct remainder of a window that has mostly elapsed.

This is the same class of gap as §4.5 — missing state — but on the *intake* axis rather than the
*hydration-status* axis, and it is the more tractable of the two: the app already logs what the
user planned and consumed, so the subtraction is available in a way that hydration status is not.

**Not fixed here, deliberately.** Doing it properly means deciding what "already drunk" is scoped
to — everything since waking? since the window opened at t−240? — and that decision belongs with
the logging model, not with this formula. Until then the SSOT states the semantics and pushes the
subtraction to the consumer, which at least makes the omission visible rather than silent.

Worth noting what this looks like from the outside: the ADA/DC figure at §3.3 is a **two-dose
schedule** precisely because it is tracking state — 500 ml at t−120, then a top-up at t−15. Our
model answers "how much, from now" for a single query and has no notion of a second query. That is
a defensible product shape, but it means our t−15 number should not be read as a *top-up* on top of
an earlier dose. It is the whole remaining window's total for someone who asks once.

---

## 5 · Explanation layer — the drawer contract

**The drawer is not a ratification instrument:** where it disagrees with the SSOT, the SSOT wins.

**Rounding lives here, not in the engine** (§2.8). One helper, applied at the display boundary and
nowhere else:

```
round25(v) = round(v / 25) * 25          # half away from zero
floor25(v) = floor(v / 25) * 25          # the band rounds outward so it never narrows
ceil25(v)  = ceil (v / 25) * 25
```

Displayed target = `round25(fluidMl)`; displayed range = `[floor25(fluidLowMl), ceil25(fluidHighMl)]`.
A 65 kg athlete at 3 h therefore sees **500 ml [325–650]** against an engine value of 487.5.
Never display a raw engine value — 487.5 ml reads as measured, and it is not.

**Header.** `<planned> ml planned / <target> ml target`, range chip below.

- Displayed target MUST equal `round25(fluidMl)`; range chip MUST equal the rounded pair above.
- `planned` is what the user put in the plan — a *logging* value, not engine output. Do not diff it.
- Below 2 h the marker is deliberately off-centre and the floor is 0 — see §4.2, §4.8.

**Carrying the semantics into the UI** (§1.6). The number is a window total, sipped, subordinate to
the urine cue, and not a quota. That has to survive contact with the screen, and it is mostly about
what *not* to build:

- **Phrase it with the window, not as a dose.** *"About 500 ml between now and the start"*, not
  *"Drink 500 ml."* The unit of the recommendation is the interval, and saying so is what makes the
  number's decline near the start self-explanatory rather than mysterious.
- **No progress ring, no `0 / 500 ml` counter, no completion state.** Those render a
  recommendation as a requirement, and they contradict `fluidLowMl = 0` outright — an athlete who
  drinks nothing is in spec, and a UI that shows them at 0 % says otherwise.
- **The urine cue rides with the number, not three panels down.** It is the thing that outranks it.
- **If prior intake is logged inside the window, show the remainder** — `target − logged`, floored
  at 0 — and label it as such. The engine will not do this; see §4.13. If the app cannot yet do it
  either, the copy must at least say the number counts what you have already had.

**Calculation panel.** Four branches, keyed on `regime`. The bare `BW × …` form is correct only in
the first:

| `regime` | Chain to render |
|---|---|
| `cited` | `BW × 7.5 = target` → `floor = BW × 5` → `ceiling = BW × 10`, each shown rounded per above |
| `extrapolated` | `target = 250 + (BW × 7.5 − 250) × t/120` → `ceiling = BW × 10` → floor: *"nothing required if you're already hydrated"*. **Do not render a bare `BW × …` target line** — the constant term is what makes the number stop scaling near the start |
| `clearance_bound` | as `extrapolated`, but the ceiling reads `400 × e^(0.0533 × t)` — "capped by how fast fluid can leave your stomach" |
| `gated` | no chain; the gate copy in §6 |

**Worked example the drawer should carry (65 kg, 3 h):** `65 × 7.5 = 487.5 → 500` · floor `325` ·
ceiling `650`.

**"The Full Story" panels:** S1 euhydration · S2 where the band comes from · S3 why the number
declines · S4 early-morning workouts. S2 must cite 5–10 ml/kg to Thomas 2016, not 5–7. S3 must
attribute the decline to voiding, gut comfort, and the fact that late fluid has not been absorbed
by the start — **not** to absorption being impossible; absorption takes minutes (J&G p. 491) and
larger boluses empty faster initially (p. 130).

---

## 6 · Fine print — the asterisk copy

The fluid target ships with an asterisk, never bare. Athlete-facing. Bracketed notes are the load
each paragraph carries — not for display.

---

### About this number\*

**Your pre-run fluid target is a starting point, not a prescription.**

**Where it comes from.** For sessions two or more hours away we follow the current joint position
statement of the American College of Sports Medicine, the Academy of Nutrition and Dietetics and
Dietitians of Canada: **5–10 ml of fluid per kilogram of body weight**, taken across the two to
four hours before you start. We aim for the middle of that range. Closer to your session the
number comes down toward a single glass — partly because there's less time to clear what you don't
need, and partly because fluid drunk in the last few minutes hasn't been absorbed yet when you set
off. Those closer-in numbers are our own judgement rather than a published figure.
*[separates the cited band from the design choices; gives both correct reasons for the decline]*

**It's a total for the time you have left, not a glass to down.** The number covers everything
between now and the start — sip it across that time rather than drinking it in one go, and count
anything you've already had. Two hours out that's a bottle spread over two hours. Fifteen minutes
out it's a glass.
*[§1.6 — the window-cumulative semantics, stated to the athlete; §4.13's subtraction pushed to the
user until the app does it]*

**If you're already hydrated, you may not need any of it.** Under two hours out there's no minimum
— the range starts at zero. The number is what to aim for if you're topping up from a normal
baseline, not a quota.
*[`low = 0`; NATA 2017's carve-out, stated to the athlete]*

**The real check is your urine.** Aim for pale yellow — straw coloured — before you head out. Both
current position statements make this the thing to watch, not the volume. If you're already pale,
you likely need less than the number shows. If it's dark, you need more. One catch: if you take a
multivitamin or B-complex, urine colour won't tell you much — riboflavin turns it yellow whatever
your hydration.
*[the endpoint both statements endorse, plus the confounder from J&G 2019 p. 246]*

**Empty your bladder before you start.** Ten minutes out is about right. It's the simplest way to
carry less than you're holding.
*[the procedural answer to excess fluid; J&G 2019 p. 493. Also the only mitigation for §4.11]*

**If you're adding electrolytes, keep the sugar low.** A salty snack with water, or a
low-carbohydrate electrolyte drink, helps you hold onto the fluid. A full-strength sports drink
works against you here — the sugar slows how fast the fluid leaves your stomach.
*[§4.6]*

**More is not safer.** Drinking beyond what you're losing is the main cause of exercise-associated
hyponatremia — dangerously low blood sodium. It isn't just an inconvenient bathroom stop. The risk
is highest for smaller, leaner athletes running at an easier pace, who sweat less and are out
there longer. Don't push fluid past comfort.
*[Thomas 2016: "Over-drinking fluids in excess of sweat and urinary losses is the primary cause of
hyponatremia," and "It can also be compounded by excessive fluid intake in the hours or days
leading up to the event." Risk profile from J&G 2019 p. 246. Also the user-side mitigation for the
mean-emptier choice in §2.4]*

**A short easy session may not need this at all.** If you're heading out for under an hour in cool
conditions and you're normally hydrated, you're probably fine as you are — we won't show a target.
*[NATA 2017's recreational carve-out; explains the gate to a user who sees no number]*
