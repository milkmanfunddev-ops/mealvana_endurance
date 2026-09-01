# Notes — Pre-Workout Fuelling (hydration · carbohydrate · sodium)

Companion to the three SSOTs, which are kept to formulas, constants and invariants:

- [`pre-workout-hydration.md`](./pre-workout-hydration.md)
- [`pre-workout-carbs.md`](./pre-workout-carbs.md)
- [`pre-workout-sodium.md`](./pre-workout-sodium.md)

**One combined file, because the tier architecture is shared.** Three separate notes would
duplicate §1 three ways and drift.

This records **why the algorithms have the shape they do** (§1–3), **what they check out against in
the literature** (§4), and **what concerns remain** (§5). Trivial choices are not recorded; close
calls — where a second answer was genuinely defensible — are.

**Nothing here is ratified** — the three SSOTs are (carbs v2, hydration v6, sodium v3; Xuan,
2026-08-03), this file is not. Where this disagrees with an SSOT, the SSOT wins.

**Rulings recorded 2026-08-03**, so the next reader does not re-litigate them: the input domain caps
at **240 min** and the app is fixed to match (§3.9, D-016); the **6–8 % CE solution** is the
top-off item (§5.15); `unknown` → `pale` is **ratified** (§5.18); **D-001** (`isFasted`) and
**duration / IF scoping and demand scaling** are **deferred to a future SSOT** (§5.14, §5.17).

---

## 1 · The shared architecture

### 1.1 · Three tiers, because eating is event-shaped

The literature is organised this way even though no source names the tiers. J&G ch. 6 splits into
**"Carbohydrate Intake in the Hours Before Exercise"** (p. 148) and **"Carbohydrate Intake 30 to 60
Minutes Before Exercise"** (p. 149) — separate sections because they do different jobs — and ch. 17
adds a third:

> "Runners should plan for required carbohydrate and fluid intake 10 to 15 minutes before the start
> of the race… Most of the carbohydrate ingested at this time will become available to the muscle
> during the first part of the run." — p. 491

| Tier | Job |
|---|---|
| meal (2–4 h) | Liver and muscle glycogen; the substantive feeding |
| snack (30 min–2 h) | Liver top-up; the last feeding with meaningful digestion time |
| top-off (<30 min) | *Early during-exercise fuel*, delivered before the gun |

**Tiers stack.** An athlete waking three hours out passes through all three. That tracks a real
depletion clock — J&G p. 149: *"Liver glycogen concentrations are substantially reduced after an
overnight fast."* Thomas uses the plural for the same reason: *"Carbohydrate consumed in **meals
and/or snacks** during the 1–4 hours pre-exercise."*

**Caveat, recorded rather than buried:** the tier *structure* comes largely from J&G ch. 17, which
the authors state carries no citations. It is practice, not evidence. The **dose range** it carries
is cited (§3.1); the **partition** is not.

### 1.2 · The tier is a container, not a computation

Each nutrient computes from `timeBeforeWorkoutMin` alone; a tier renders what the engine returns.
**`targetBasis` is per-nutrient and per-minute and MUST NOT be derived from the tier**, because the
citation edges and the tier edges are different lines:

| Lead time | Carbohydrate basis | Fluid basis | Tier |
|---|---|---|---|
| 240–120 | cited | cited | **meal** |
| 120–60 | cited | design_choice | **snack** |
| 60–30 | design_choice | design_choice | **snack** |
| 30–0 | design_choice | design_choice | **top-off** |

The snack tier **straddles the carbohydrate citation edge at 60 minutes**. That is correct and must
not be "fixed" with a fourth tier — a user at t−75 should see a snack whose carbohydrate number is
cited and whose fluid number is ours, each labelled.

The 2–4 h band is worth naming: it is exactly the **intersection of Thomas 2016's two windows**
(carbohydrate 1–4 h, fluid 2–4 h) — the only region where both numbers we hand an athlete are cited.

### 1.3 · Why `T_REF` and `TIER_MEAL_MIN` are the same number in two places

Both equal 120. **They are not the same constant and neither justifies the other.**

- `T_REF` (hydration) is **epistemic** — the lower edge of Thomas's fluid window. It marks where our
  authority ends, not where physiology changes.
- `TIER_MEAL_MIN` (carbohydrate) is **physiological** — a low-fat solid meal is 30–60 % still in the
  stomach at 2 h (Tougas normal values, via the ANMS/SNM consensus). Below 2 h "meal" cannot mean
  *digested*.

Two independent justifications landing on one number is a strength. The failure mode is a future
reader noticing the duplication and deriving one from the other, at which point a change made for
gastric reasons silently moves the edge of a position statement's authority.

**Hence: two constants, one conformance assertion that they are equal, and a loud failure on
divergence.**

### 1.4 · Carbohydrate splits across tiers; fluid does not

This asymmetry is deliberate, and it is the shape both specs converged on independently.

- **Eating twice is normal.** Portions are physical objects, and there is a reason to hold some
  back — the top-off's job is early during-exercise fuel, not pre-workout fuel.
- **For fluid, earlier is strictly better.** Absorption, voiding and gut comfort all point the same
  way, and nothing argues for reserving a portion until t−15. So all pre-workout fluid goes to the
  earliest window that exists.

Consequence: the top-off tier's water is **owned by the carbohydrate spec** (the chase for a gel),
not by the hydration plan. One instruction, one owner, and the hydration plan showing zero there is
a statement rather than a gap.

---

## 2 · Hydration — why it has this shape

### 2.1 · One boundary, and it is epistemic

Thomas 2016 covers 2–4 hours and nothing else. `T_REF = 120` is the edge of what a position
statement will say. Above it the output is cited; below it every number is ours.

### 2.2 · What Thomas's window is — the dose is bounded

> "Athletes may achieve euhydration prior to exercise by consuming a fluid volume equivalent to
> 5-10 ml/kg BW in the 2 to 4 hours before exercise… **while allowing for sufficient time for excess
> fluid to be voided**."

"In the 2 to 4 hours before exercise" bounds the consumption at **both** ends. So `fluidMl` above
`T_REF` is the total for `[now, t−120]` — *finish it, don't stretch it to the gun.* ACSM 2007
corroborates structurally: ~5–7 ml/kg at ≥4 h, conditionally ~3–5 ml/kg at ~2 h, and **nothing
after**.

**This spec has now misread that one sentence three times, and it is worth recording as a standing
caution.** v4 read it as unbounded ("a total for `[now, start]`"). v5 read it as prohibitive
("Thomas reserves the last two hours"). Both were wrong in whichever direction suited the design at
the time. What the sentence supports:

| Claim | Status |
|---|---|
| The dose is consumed within the 2–4 h window | ✅ stated |
| The window ends where it does so excess has time to be voided | ✅ stated |
| Therefore drinking below 2 h is discouraged | ❌ **not stated** |
| 10 ml/kg is a maximum | ❌ **not stated** — see §2.4 |

**Thomas is silent below 2 h. Silent is not reserved.** One sentence is carrying an enormous amount
of structure in this spec; treat any new inference from it with suspicion.

### 2.3 · Below 2 h: three outputs, three kinds of claim

| Output | Claim | Standing |
|---|---|---|
| `low = 0` | **Nothing is required** | NATA 2017, near-verbatim |
| `target` | **What we recommend** | Ours, in a region no source addresses |
| `high` | **The most we recommend** | Cited maximum held outside its window, clamped by measured clearance |

`low = 0` rests on NATA's carve-out — *"Recreational athletes should not need to consume extra
fluids before activity but should begin exercise euhydrated."* **It does not rest on Thomas**; the
v5 note claiming Thomas's design "puts nothing there" was withdrawn (§2.2). NATA was always the
stronger leg.

### 2.4 · The urine check, and why 3–5 ml/kg is right

**Chosen:** ACSM 2007's conditional branch, verbatim, at ACSM's own placement and bounded by ACSM's
own maximum.
**Rejected:** capping the correction at 2.5 ml/kg (the headroom from Thomas's midpoint to 10 ml/kg).

The rejected version came from an error worth naming: **treating supersession as "overruled."**
Thomas 2016 *dropped* the dark-urine branch; it did not contradict it. Where a successor is silent
on a case its predecessor addressed, the predecessor is the only guidance that exists — a different
situation from citing a superseded *number* against a successor that gives a different one.

A second error compounded it: I repeatedly called 10 ml/kg **"Thomas's maximum."** It is the top of
a suggested dose range. Nowhere does the document say "no more than." Reading a ceiling into it —
then defending it as the source's — is the same failure as reading the window as a prohibition.

And the risk argument does not apply. Thomas's over-drinking warning is about intake *"in excess of
sweat and urinary losses."* An athlete with dark urine at t−120 has **measured a deficit**; giving
them more is correcting it, not exceeding it. The whole point of the check is that it changes what
"excess" means for that person.

**The rule this settles, and it generalises:** *keep the superseded document's structure; take the
magnitudes from the current one — unless the current one is silent on that branch, in which case
take both, and take its bounds too.* Here the +3–5 ml/kg and the 12 ml/kg plan cap both come from
ACSM 2007, so nothing is grafted onto a base it was never sized against.

**Where the cap actually binds.** The target is the *midpoint* of ACSM's 3–5, so the corrected plan
lands at 7.5 + 4 = **11.5 ml/kg** — under the cap, with 0.5 ml/kg of headroom. The cap therefore
does **not** clamp the target; it clamps the **band top**, where 7.5 + 5 = 12.5 is cut to 12. An
earlier draft wrote the cap as `min(meal + topUp, 12·BW)` on the target line, which is dead code —
it can never fire. Invariant 8a keeps the cap load-bearing by asserting the target stays under it,
so raising `TOPUP_ML_KG` past 4.5 fails loudly instead of quietly exceeding ACSM's own maximum. That grafting is exactly
what makes the existing drawer advisory wrong (§5.5).

**The band above `T_REF` does not depend on the check, and that is the point.** `fluidHighMl` is
displayed from entry — t−240 — while the check happens at t−120. A check-dependent bound would
either be uncomputable when first shown, or would move underneath the athlete part-way through the
plan. So the bound states what the **protocol** can sanction (`min(7.5 + 5, 12)` ml/kg), not what
this athlete's reading turned out to be; the check moves the **target** inside it. That is exactly
how the sub-2 h region already works — the band is fixed and hydration status moves the athlete
within it (§2.5).

The cost is a step in `fluidHighMl` at `T_REF` — 12·BW above, `min(10·BW, clearance)` below — which
now applies on every path rather than only the dark one. That is the same class as the `low` step:
above 2 h a protocol sanctions a correction, below it none exists and we hold 10. **Trading a
conditional bound for an unconditional step is the right way round**, because a bound that changes
with new information is a worse defect than a bound that changes at a stated boundary.

**The dark-path target step at `T_REF` is intentional.** 260 ml at 65 kg. It sits exactly where a voiding
gap becomes available: above 2 h an athlete can be given more because there is time to clear it.
Note the consequence — the t−121 dark athlete's *target* (747.5) exceeds the t−119 athlete's
*maximum* (650). That looks wrong and is not: the first plan spans two windows with a clearing gap,
the second is 90 minutes with none. **Do not "fix" it.**

### 2.5 · Why the check does nothing below 2 h

**Chosen:** `hydrationCheck` affects output only when `entry ≥ 120`.

Three reasons, and the first decides it:

- **There is nothing to evaluate.** ACSM's branch asks *did the base dose work?* An athlete who
  wakes at 90 minutes has drunk nothing.
- **`f(entry)` already encodes the assumption.** At its top end `f(120) = 7.5·BW`, the same number a
  fully prepared athlete drinks. The curve was built as the answer for someone arriving with
  nothing. Adding a correction on top applies the deficit assumption twice.
- **There is no time to use it.** The correction's purpose is absorption plus voiding. At t−45
  neither is available.

**The individualization is not lost — it moves into the band.** Below 2 h, `low = 0` covers the
already-hydrated athlete and `high = min(10·BW, clearance)` covers the dehydrated one, with the
fine print telling them which way to lean. For the population §5.12 describes, having the larger
number *available* rather than *recommended* is the safer form.

This also deleted a constant. An earlier draft tapered the correction by `min(entry,120)/120` so it
would behave below 2 h. Removing the branch removed the need for the taper — **one fewer unsourced
number in the spec.**

### 2.6 · All fluid to the earliest window — no snack/top-off split

**Chosen:** the whole sub-2 h plan goes to the earliest window that exists.
**Rejected:** duration weighting; midpoint weighting; a fixed top-off portion.

The rejected rules all produced the same artefact — at entry −35, duration weighting gave a snack of
**45 ml** against a top-off of **274 ml**. A sip and then a full drink.

The diagnosis matters more than the fix: **duration weighting imported a steady-sipping model into
an event-based architecture.** The tiers are feeding *occasions*; the drink that goes with one is an
occasion too, and its size should not scale with how wide the window happens to be. Midpoint
weighting was worse — a window of near-zero *width* still earned half the fluid, because the weight
came from the curve's height rather than the window's size.

Not splitting at all is better than any weighting, for four reasons:

- **We already made this call for the correction.** ACSM places it *"about 2 h before"*, and it needs
  absorption time. There is no principled reason to place the base differently from the correction.
- The top-off's fluid already has an owner (§1.4).
- It removes the constant entirely — nothing to invent, nothing to defend.
- It is the voiding rationale stated as a rule: *drink it as early as you can.*

**Consumption is still spread.** Allocation by occasion does not mean a bolus — 487 ml assigned to a
90-minute snack window is about 5 ml/min. The SSOT says so contractually.

### 2.7 · `tier` (int) — retire it, or renumber it?

**Chosen:** retire the integer; emit named strings.

The shipped client branches on **v1 semantics** — `1 = body-weight scaled, 2 = fixed 250 ml top-up,
3 = no hydration` — in `macro_explanation_service.fluid.dart:66` and
`macro_explanation_service.calculations.dart:643`, reading `pre_run_hydration_tier`. A Flutter
client and a Supabase edge function deploy separately and users run old builds, so **no integer
mapping is safe**: an old client receiving a new integer mis-renders silently.

Applies to carbohydrate too — `tiers` is an array of named strings, never an index. **Cost:** a
coordinated release (§5.3).

### 2.8 · `K` — which emptying coefficient, and from which paper?

**Chosen:** Mudie 2014's published mean, **3.2 h⁻¹** (T50 = 13 min), used verbatim.

| Paper | What it reports | Usable? |
|---|---|---|
| **Mudie 2014** (n = 12, 240 ml water, MRI) | *"an average first-order gastric emptying rate coefficient of 3.2 h⁻¹ (T50% of 13 min), with a range of 2.2−6.0 h⁻¹"* | **Yes** — a first-order coefficient in the exact form the model needs |
| **Grimm 2018** (n = 120) | 85 ± 13 % emptied at 30 min, model-**independent** AUC | No — *"model dependent parameters like t1/2 were not able to describe all different curves sufficiently well"* |
| **Bertoli 2022** (review) | T50 water ≈ 7 min; normal limit < 25 min | No — *"the T50 is heavily dependent on the model utilized"* |

**Why the mean and not the slow tail.** An earlier draft used 2.2 h⁻¹. The ceiling is a
**permission**, not a recommendation — a maximum designed for the 96th-percentile slow emptier
under-permits everyone else. And 2.2 h⁻¹ is not "the conservative end of a range": it is T50 ≈ 18.9
min against a mean of 13.0, roughly **+1.7 SD**.

*Direction trap:* Mudie's "T50 13 ± 1" is a **standard error in T50 space**, not an SD in rate
space. Always say *"the k of a T50-mean-plus-2-SD emptier"*, never a bare "mean + 1 SD."

**Live caveats.** Mudie: *"For about half of the subjects, the second part of the gastric emptying
curves deviated from the initial single exponential."* Tolerable because the ceiling binds only in
the first ~20 min. And Mudie dosed **240 ml of water in fasted, resting subjects**; larger boluses
empty faster initially (conservative), but food in the stomach does not, and the carbohydrate spec
guarantees food (§5.6).

### 2.9 · `A0_ML` and `R_CEILING` — one constant, or two?

**Chosen:** two, from two sources — `A0_ML = 250` (a dose) and `R_CEILING = 400` (a tolerated
residual).

The earlier design used one constant with the start-line dose at half of it. That was **two
constructions stacked**: the residual was itself converted from a published 500 ml through an
emptying constant we chose, then halved for a reason we invented. Under the current `K` the same
conversion lands on 225, not 250 — the tell that the number was an artefact.

- **`A0_ML = 250`** — J&G p. 493, 250 ml immediately before going on court. At `t = 0` everything
  drunk is still in the stomach, so this is simultaneously a published *dose* at the start line.
- **`R_CEILING = 400`** — NATA 2017, the only statement in the corpus quantifying a tolerated
  gastric volume. **Why 400 and not 600:** at 600 the clearance term would not bind at all below
  60 kg. This is the one place a value inside a cited band was chosen by us, and it is chosen
  conservatively.

### 2.10 · The gate — keep it, or drop it?

**Chosen:** keep, unchanged. `low = 0` says *nothing is required*; the gate says *we are not setting
a target at all*, which is the honest output when NATA's carve-out applies. The `null` vs `0`
distinction carries that. But the proxy is broader than its source (§5.4).

Note the deliberate asymmetry with carbohydrate (§3.5): fluid gates, food does not.

### 2.11 · Sodium — why there is no target

The mechanism is real and well cited. J&G ch. 9:

> "Because sodium is the major electrolyte in the extracellular fluids (accounting for 50% of plasma
> osmolarity)… **Even small reductions in plasma osmolarity invoke a marked increase in urine output
> (diuresis).**"

> "Plasma volume is more rapidly and completely restored if some sodium chloride (77 mmol/L) is
> added to the water consumed (Nose et al. 1988)."

**But no current source will quantify it for the pre-exercise case.** Thomas: *"may help with fluid
retention."* NATA Rec 18 (SOR: B): mechanism affirmed, no number, *"should be individualized."* The
only number in the lineage — 20–50 mEq/L — is Sawka 2007, superseded for dosing.

Setting a number would mean inventing one for the output where the physiological argument is most
seductive and the evidence most explicitly declines. The qualitative copy carries the whole
actionable content.

**Where it comes from is answered.** All three sources put pre-exercise sodium **with food** —
Thomas (*"fluids and foods"*), ACSM 2007 (*"salted snacks… at meals"*), J&G p. 252 (*"a salty
snack… eaten at the same time"*). The meal and snack tiers carry it natively; only the top-off is
open (§5.15).

### 2.12 · Sodium — the euhydration / hyperhydration boundary

**This is why §2.11 is a contractual non-goal rather than a passing note.**

J&G fig. 9.15 (Shirreffs et al. 1996): same fluid volume, 23 mmol/L sodium leaves mild dehydration
at 6 h; **61 mmol/L achieves hyperhydration.** Sodium is the variable that decides whether a large
intake is retained or voided — so "add sodium so it stays in" and "hyperhydrate" are the same lever
at different doses.

Hyperhydration is a different target state — J&G describes it as *"expanding blood volume and
**reducing plasma osmolarity**"* — with unstable evidence (*"several of these studies used control
conditions that represented dehydration rather than euhydration"*), a transient effect (*"much of
the fluid overload is rapidly excreted"*), a doping history, and a risk profile matching our users.

Two failure modes, and sodium moves them in opposite directions:

| | Cause | Sodium | Severity |
|---|---|---|---|
| Dilutional hyponatremia | Water in excess of sodium | **Protects** | Confusion → seizure → coma → death |
| Fluid overload | Volume in excess of need | **Worsens** (blunts the clearing diuresis) | Discomfort, full bladder, transient |

So the sodium copy is a **good trade**. What must never happen is sodium becoming an argument for a
*larger* fluid target.

### 2.13 · No absolute cap on `fluidHighMl`

An absolute ~1,000 ml ceiling was considered on J&G p. 240 (*"more than about 1 L… feels
uncomfortable for most people when exercising"*). **Dropped:** that is a gastric volume *during
exercise*, not a dose spread over hours, and capping a position statement's band with a textbook
aside would invert source precedence.

---

## 3 · Carbohydrate — why it has this shape

### 3.1 · The v1 citation was wrong

v1's constants table attributed **1 g/kg/hr** to Kerksick 2017. Four problems:

1. Kerksick's only pre-exercise sentence prints the unit as **g/kg/day**: *"It is commonly
   recommended to consume snacks or meals high in carbohydrate (1–4 g/kg/day) for several hours
   before higher-intensity (≥ 70% VO2max), longer duration (> 90 min) exercise."*
2. Its timing phrase is **"several hours before"**, not "1–4 h before".
3. **"1 g/kg/hr" appears nowhere in it.**
4. It is **background prose**, not a graded conclusion. Kerksick's numbered summary points contain
   no pre-exercise per-kg dose at all.

The phrasing v1 used is a faithful quotation of a source it did not name: **Thomas 2016 Table 2**,
itself citing **Burke 2011 Table II**. So the numbers were right and the attribution was wrong —
the smaller problem, but real, because nobody checked, and the thing nobody checked came with a
**scope condition** (exercise ≥ 60 min) that v1 dropped.

Re-citing also puts the whole `spec/fueling/` folder on one position statement for both hydration
and carbohydrate — one staleness dependency to watch instead of two (§5.9).

### 3.2 · The shape survives; it is the diagonal of the box

`carbPerKg = max(0.5, min(hoursBefore, 4.0))` is unchanged from v1, and an intermediate draft that
retired it was wrong.

What changed is how it is described. Thomas sanctions a **rectangle** — dose ∈ [1, 4] g/kg, time
∈ [1, 4] h — and never says dose is a function of time. Our function picks the **diagonal**: it
runs from exactly the floor of the cited band at t−60 to exactly its ceiling at t−240.

That is a much better description of the design intent than "1 g/kg/hr" — *maximally conservative
at one hour, maximally aggressive at four* — and it is checkable (invariant 4). But it is **ours**,
and the constants table now says so.

### 3.3 · Why the meal tier opens at 120, not 90

**Chosen:** 120. **Alternative:** 90, the value the app currently uses.

**90 minutes has neither a citation nor a physiological anchor.** It is a round number.

120 has two independent ones — and per §1.3 they must never be presented as supporting each other:

1. **Gastric.** The clinical standard meal for emptying studies is deliberately lean — 255 kcal,
   72 % carbohydrate, 24 % protein, **2 % fat**. Normal retention (Tougas, via ANMS/SNM):
   **37–90 % at 1 h, 30–60 % at 2 h, 0–10 % at 4 h.** At 90 minutes roughly half a low-fat solid
   meal is still in the stomach.
2. **Structural.** It is the edge of Thomas's fluid window, so the meal tier coincides with the
   region where both nutrients are cited (§1.2).

**What must not be claimed.** Even at 120, a solid meal is 30–60 % retained. The tier name is a
**portion and composition decision**, not a digestion guarantee. Nothing in the corpus requires an
empty stomach at the gun — our own fluid ceiling tolerates 400 ml of residual on NATA's authority.

**What it costs.** An athlete waking 100 minutes out never sees a meal. That is the *correct*
advice, but it makes the snack tier carry more — see §3.6 and the `renderAs` rule.

### 3.4 · Two bands, two jobs

**Chosen:** the plan band is Thomas's cited 1–4 g/kg; ±12.5 % is demoted to a per-tier solver
tolerance.

v1's ±12.5 % had three problems, in increasing severity:

- **It exceeded the cited range.** From about t−220 outward, `carbsHighG` reached **4.5 g/kg** at
  t−240 — above Thomas's 4. Symmetrically at t−60 the low fell to 0.875, below Thomas's 1.
- **It reported a sliver as if measured.** At t−60 the ±12.5 % band was 8 % of the sanctioned width.
- **It made `targetBasis: "evidenced_band"` mean two different things** in two files — in hydration
  *the band is cited, the point inside it is ours*; in carbs *the band is ours too*. Any consumer
  trusting that field across both specs was already wrong.

Reporting the cited band fixes all three and closes §5.2's "two band semantics in one drawer."
The ±12.5 % survives as what it always was: *how close the chosen food must land to that tier's
portion.* Useful, and not a claim about physiology.

**Cost:** leaving the window at t−60 steps `high` from 260 g down to 73 g. Same class as hydration's
`low` step at `T_REF` — the edge of a position statement's authority. Pin it; don't smooth it.

### 3.5 · Why carbohydrate has no gate, and fluid does

**Chosen:** carbohydrate never returns `null`; it returns a number with `targetBasis:
"design_choice"` when outside Thomas's scope.

- For fluid, NATA issues a **positive carve-out** — *"Recreational athletes should not need to
  consume extra fluids before activity."* A source affirmatively says nothing is needed. That
  justifies `null`.
- For food, **no source says the equivalent.** Thomas's row simply does not cover exercise under
  60 minutes. **Absence of coverage is not a carve-out.**

Emitting `null` for carbohydrate would assert something no source supports, in the direction of
telling athletes not to eat.

### 3.6 · The split: 60 / 30 / 10, and 75 / 25 without a meal

**Chosen:** fixed shares of the plan total — 60 / 30 / 10 when a meal window exists, 75 / 25 when it
does not, 100 % to the top-off below t−30.
**Rejected:** a fixed per-kg top-off portion (`min(0.5 g/kg, 25 % of the plan)`).

The fixed portion was introduced to make the top-off a physical object — a gel is a gel, and does
not scale with the clock. It worked in the meal window and degraded below it: at t−35 the plan total
falls to 37.9 g, of which a fixed 32.5 g top-off left the snack a **5.4 g crumb**. Capping it at
25 % removed that, but at the cost of a split that drifted — 58/29/12 at t−240 down to 50/25/25 at
t−120.

Fixed shares are the simpler contract and the one that survives inspection: *the athlete's plan is
divided the same way every time.* Xuan, 2026-08-03.

**What it costs, stated plainly.** The top-off is no longer a constant object:

| t (65 kg) | total | meal | snack | top-off |
|---|---|---|---|---|
| 180 | 195.00 | 117.00 | 58.50 | **19.50** |
| 120 | 130.00 | 78.00 | 39.00 | **13.00** |
| 105 | 113.75 | — | 85.31 | **28.44** |

Inside the meal window it runs **13–19.5 g — below one gel**, then more than doubles at t−105 where
the meal drops out and the split becomes 75/25. That second part is coherent (fewer feedings, bigger
each, and the plan total is continuous through the boundary); the first is a genuine cost, and the
food selector will be portioning half-gels at the low end of the meal window.

**If it becomes a problem, the lever is a minimum portion rule** — merge a tier into its neighbour
when its share falls below a threshold — not a return to the fixed portion, which reintroduces the
crumb at the other end. Not implemented; noted so the trade is on the record.

**D-002 is superseded — see §3.10.**

### 3.10 · Removing the 0.5 g/kg floor (D-002)

**Chosen:** `carbPerKg = min(t/60, 4.0)`. Xuan, 2026-08-03.
**Superseded:** `max(0.5, min(t/60, 4.0))`, ratified 2026-07-26 as a *"Mealvana design-choice minimum
for very short lead times (some carbs beat none)."*

The floor bound at exactly two points on the input grid — **t−15 and t−0** — and everything from
t−30 up was already the plain diagonal. What it bought was a non-zero recommendation at the gun.
What it cost:

| t (65 kg) | with floor | without |
|---|---|---|
| 30 | 32.50 (snack 24.38 · top 8.12) | unchanged |
| 15 | 32.50 (top 32.50) | **16.25** (top 16.25) |
| 0 | 32.50 (top 32.50) | **0** |

Three grid points reporting the same 32.5 g regardless of lead time. Removing the floor makes the
last three columns a clean taper.

**Correction, 2026-08-03.** Earlier drafts of this section also credited the removal with
eliminating "a 4× step in the top-off at t−30 (8.12 → 32.50) caused purely by the floor switching
on," and with halving that step. **Both claims are false.** The floor binds only where `t/60 < 0.5`,
i.e. strictly *below* t−30, so it never touched that boundary. The step is caused by the top-off's
share going 25 % → 100 % as the snack window closes, and it is **8.125 → 32.5 with the floor and
without it** — unchanged, in both versions, by construction. It is a share transfer, pinned by
invariant 7, not an artefact of anything the floor did.

The decision to remove the floor still stands; it just rests on the taper argument alone, which was
always the stronger leg. Recorded here because the erroneous claim was the *first* reason listed,
and a reader checking only the first reason would have found the whole change unmotivated.

**The consequence is `carbsG = 0` at t−0, and it is defensible rather than merely tolerated.** At the
gun there is no time to eat; there *is* time to drink, which is why hydration still returns 250 ml
there on J&G p. 493's authority. **You can drink at the gun and you cannot eat** — the two specs
disagreeing at t−0 is the physiology, not an inconsistency.

**Two things to watch.**

The band degenerates to `[0, 0]` at t−0, which over-states: nothing forbids a gel at the gun, and a
range of exactly zero reads as a prohibition. The SSOT requires the consumer to suppress the range
there rather than render it. A cleaner long-run answer would be a non-degenerate high bound below
the cited window, but nothing sources one, and inventing a ceiling to avoid an ugly render is the
failure `targetBasis` exists to catch.

And **zero is a statement, not an absence.** `carbsG = 0` with a `top_off` tier present is *there is
no time to eat*; `isFasted` returns an empty `tiers` array and `targetBasis: "none"`, which is *no
recommendation is being made*. A consumer that collapses them will misreport both — the same
`0` vs `null` discipline the hydration spec applies to `fluidLowMl`.

### 3.7 · Composition is the real lever, not the boundary

The literature sets **no meal/snack time threshold** — Thomas says *"meals and/or snacks during the
1–4 hours pre-exercise"*, one window, no split. That is not an oversight: **it controls the risk
with composition instead of timing.**

> "Choices high in fat/protein/fiber may need to be avoided…" — Thomas 2016 / Burke 2011

> "Athletes who frequently experience stomach problems should avoid breakfasts that are high in
> fiber, fat, and protein and **may want to avoid milk products**." — J&G p. 492

Mechanism, J&G p. 131: *"Several nutrients, such as fat, exert a strong inhibitory effect on gastric
emptying."* **Both source statements are conditional** — "may need to", "athletes who frequently
experience stomach problems" — which is why the strictest rung is gated on `gutTolerance == low`
rather than applied universally.

**The current food lists invert this.** They use richness — which means fat — as the portion-size
signal: *bagel and jam* is a snack, *bagel and cream cheese* is a meal. Tolerable if the meal tier
starts at 3 h; indefensible at 90 minutes. Four of eleven meals and four of eleven snacks are
fat-dominant, and the snack tier runs down to 30 minutes. **Six one-ingredient swaps fix it**, every
replacement on J&G's verbatim race-day list: raisins → honey; cream cheese → jam; peanut butter →
jam in the three snack entries; dates → ripe banana.

### 3.8 · `renderAs` — the same threshold problem in both specs

At t−119 the carbohydrate snack is **97.5 g** and the hydration snack is **487.5 ml** — both larger
than what a slightly-earlier athlete gets *labelled as a meal*. The numbers are right; the word is
wrong.

Both specs therefore emit a display hint rather than changing arithmetic: carbohydrate renders a
snack of ≥ 1.0 g/kg as **"light meal"**; hydration renders a snack of ≥ 5 ml/kg as **"bottle"**
rather than "glass". One decision, applied to both, because it is the same boundary and the same
reader confusion.

### 3.9 · The input domain is seventeen values, and the cap binds at the last one

**Corrected 2026-08-03.** Every earlier version of this section said the app collects lead time in
15-minute steps **0 to 180**, "thirteen values," and built two conclusions on it. The premise was
wrong. The shipped stepper is `min: 0, max: 480, step: 15` —
`cycling_tab_content.dart:91`, and `running_tab_content.dart:605` hand-rolls the same bound as
`value + 15 <= 480`. That is **33 values**, and it flows through unchanged
(`macro_generation_service.dart:283`, `hours_before = minutes / 60`).

**The ruling (Xuan, 2026-08-03): four hours is the product's design limit, so the app is wrong, not
the algorithm.** `INPUT_MAX_MIN` becomes **240** and the app is fixed to match — logged as
**D-016**. Everything below assumes the corrected domain: **seventeen values, 0 to 240.**

Why fixing the app is the better half of the trade, beyond it being the stated intent: 240 is
already `WINDOW_MAX`, so capping there makes the input domain and Thomas's window coincide exactly,
and three separate problems disappear at once rather than needing three separate patches.

**Conformance should enumerate, not sample.** Seventeen lead times at a given body weight *is* the
entire input space. Property tests over the continuum are still worth keeping — they protect against
a granularity change — but the grid is cheap to enumerate exactly and should be.

**`min(t/60, 4.0)` binds at exactly one grid point — t−240.** The earlier claim that the cap was
dead code was a consequence of the wrong domain, and it was wrong in the more dangerous direction:
at the true 480-minute maximum the product was producing 4 g/kg across *nine* grid points while this
file asserted 4 g/kg "must not be described as something we recommend." With the input capped at
240 the cap becomes live at the boundary and nowhere else — the product reaches Thomas's cited
ceiling exactly at the top of Thomas's cited window, with `evidenced_band`. That is the defensible
version. The cap stays, now guarding against a future `INPUT_MAX_MIN` increase rather than against
nothing.

**`WINDOW_MAX` is now the guard that reads as active and is not.** With the input capped at 240,
`inWindow`'s `t <= WINDOW_MAX` test can never fire false. It has inherited the status the 4 g/kg cap
just lost, and this note is the record so the next reader does not delete it as dead.

**And this is where §3.4's fix was incomplete.** Under the 480-minute domain, `t > 240` fell out of
`inWindow` and the plan band reverted to ±12.5 % — reaching **4.5 g/kg**, which is precisely the v1
defect §3.4 claims to have removed, reappearing at the far end. Capping the input at 240 is what
actually completes that fix; demoting ±12.5 % to a tier tolerance was necessary but not sufficient.

**Also note `t >= T_REF` collapses to one value for fluid.** On the corrected grid, all nine of
120 … 240 return 7.5·BW, because the cited band has no time dependence inside it. The fluid taper is
visible only in the eight columns below two hours.

**Standing caution.** Two load-bearing design conclusions rested on an unverified claim about the
app's own input widget, and neither was checked against the code for six versions. Claims about what
the product can produce belong in the same evidence discipline as claims about what the literature
says — cite the file and line, or do not assert them.

---

## 4 · Checked against the literature

### 4.1 · Sources retired from a load-bearing role

**Kerksick 2017**, from the pre-exercise dose row — §3.1. Still correct for during-exercise rates
and the 6–8 % solution used by `during-workout-carbs.md`.

**Rebound hypoglycaemia**, from any dosing or timing decision. Briefly treated as an argument
against carbohydrate in the 45–75 minute window. The evidence does not support that:

> "the overwhelming majority of more than 100 studies have shown either unchanged or enhanced
> endurance exercise performance after ingestion of carbohydrate in the hour before exercise and
> **no study has been able to confirm the findings of decreased performance**." — J&G p. 150

> "certain individuals may develop hypoglycemia… **although this was not a predictor of
> performance**." — J&G p. 150

Jentjens et al. 2003 (Eur J Appl Physiol 88:444–452) gave 0/25/75/**200 g** of glucose at t−45 to
nine trained cyclists: **six of nine** dropped below 3.5 mmol/L, with **no difference in time-trial
performance across any trial.** Jeukendrup & Killer 2010: *"Advice to avoid carbohydrate feeding in
the hour before exercise is unfounded."*

**It changes no number.** What survives is one line of fine print, plus the note that Thomas's own
mitigation runs the *opposite* way — *"ensuring at least 1 g/kg carbohydrate in the pre-event
meal."*

*Independence caveat:* Jeukendrup authors nearly every link in that chain — the two 2003 studies,
the 2010 review that adjudicates them, Burke 2011, and the textbook. Under our own precedence rule
that is one lab restated across five formats. It does not overturn the conclusion (the review counts
100+ studies it did not run, and the carbohydrate-skeptical Noakes et al. 2026 *Endocrine Reviews*
review does not raise the issue either), but the direction of any bias favours our product.

### 4.2 · Statement by statement

| Source statement | What the specs do | Verdict |
|---|---|---|
| **Thomas 2016** — fluid 5–10 ml/kg in the 2–4 h before | Implemented verbatim at `t ≥ 120` | ✅ exact |
| **Thomas 2016** — "while allowing sufficient time… to be voided" | Window terminates at t−120; copy says *finish two hours out* | ✅ |
| **Thomas 2016** — states no fluid maximum | `high` labelled *the most we recommend*, not "the cited maximum" | ✅ corrected — §2.4 |
| **Thomas 2016** — silent below 2 h | Everything below `T_REF` is `design_choice`; `low = 0` | ✅ |
| **Thomas 2016** — over-drinking is the primary cause of hyponatremia, compounded by intake in the hours before | `low = 0`, the taper, the gate; explicit non-goal in sodium | ✅ §5.12 |
| **Thomas 2016** — hyperhydration / plasma expanders | Explicit non-goal | ✅ |
| **Thomas 2016 Table 2** — carbohydrate 1–4 g/kg, 1–4 h, exercise ≥ 60 min | Cited plan band; `targetBasis` honours all three conditions | ✅ exact |
| **Thomas 2016** — "meals and/or snacks", no meal/snack threshold | Tiers are ours; the dose range is theirs | ⚠️ §3.3 |
| **Thomas 2016 / Burke 2011** — avoid high fat/protein/fibre | Contractual `composition` ladder | ✅ |
| **Thomas 2016** — during-exercise carbohydrate dampens pre-exercise effects | **Not implemented** | ⚠️ §5.17 |
| **Thomas 2016** — sodium "may help with fluid retention" | Qualitative copy only | ✅ |
| **ACSM 2007** — +3–5 ml/kg at ~2 h if urine dark or absent | The dark branch, at that placement, capped at ACSM's own 12 ml/kg | ✅ §2.4 |
| **ACSM 2007** — base 5–7 ml/kg | **Not used** — superseded by Thomas's 5–10 | ✅ |
| **NATA 2017** — 400–600 mL in the stomach optimizes emptying | `R_CEILING = 400` | ✅ |
| **NATA 2017** — recreational athletes need no extra pre-activity fluid | `low = 0`; the gate | ✅ / ⚠️ §5.4 |
| **NATA 2017 Rec 18** — individualize sodium | No target set | ✅ |
| **Mudie 2014** — 3.2 h⁻¹ mean, range 2.2–6.0 | `K = 3.2/60`, as published | ✅ exact |
| **Mudie 2014** — half of curves deviate later | Ceiling binds only in the first ~20 min | ✅ with caveat §2.8 |
| **Grimm 2018** — 85 ± 13 % emptied at 30 min | Our ceiling implies ~80 % cleared at 30 min | ✅ consistent |
| **Bertoli 2022** — normal T50 < 25 min | Our T50 = 13 min | ✅ |
| **Tougas/ANMS** — low-fat solid meal 30–60 % retained at 2 h | `TIER_MEAL_MIN = 120`; the tier name carries no digestion claim | ✅ §3.3 |
| **J&G p. 130** — emptying exponential and volume-dependent | Functional form of the fluid ceiling | ✅ |
| **J&G p. 131** — fat/protein/fibre slow emptying | Composition ladder | ✅ |
| **J&G p. 131** — dehydration and hyperthermia slow emptying | Not modelled — argues `K` is optimistic for the dosed population | ⚠️ §5.10 |
| **J&G p. 130** — ≥ 8 % CHO significantly inhibits emptying | Top-off drink capped at 8 %; still not modelled across the plan total | ⚠️ §5.6 |
| **NRC/IOM** — 5–8 % CHO differs from water by "little importance"; 12 % retards absorption and provokes GI distress; 2.5/5/10/15 % dose–response | Basis of the 8 % top-off ceiling; refutes the old "sports drink slows fluid" copy | ✅ §5.15 |
| **Millard-Stafford 1997** — 6 % and 8 % CE one hour pre-run beat water over the final 1.6 km | Supports a CE drink as pre-exercise carbohydrate | ✅ §5.15 |
| **Simpson 2011** — 65 g CHO-electrolyte gel + 250 ml water at t−15, +3.1 / +3.4 % TT | Supports the top-off tier's existence and its gel + water form | ✅ §5.15 |
| **Maughan 2016** — sports drink BHI ≈ water; only ORS and milk exceed it | Bounds the sodium copy; the CE drink earns no retention claim | ✅ §5.15, §4.4 |
| **J&G p. 149** — liver glycogen depleted overnight | Rationale for stacking tiers | ✅ |
| **J&G p. 150** — rebound hypoglycaemia not a performance predictor | Not used as a constraint | ✅ §4.1 |
| **J&G p. 246** — riboflavin confounds urine colour | Suppresses the check; in the fine print | ✅ |
| **J&G p. 252** — salty snack with pre-exercise fluid improves retention | Qualitative copy | ✅ |
| **J&G p. 491** — marathon: fluid and carbohydrate 10–15 min before | Top-off tier exists and is non-zero | ✅ |
| **J&G p. 492** — race-day food list | Reference set for the food selector | ✅ |
| **J&G p. 493** — 250 ml immediately pre-start | `A0_ML` | ✅ exact |
| **J&G fig. 9.15 / Shirreffs 1996** — 61 mmol/L achieves hyperhydration at the same volume | The reason sodium is a non-goal, not a lever | ✅ §2.12 |
| **Nose 1988** — plasma volume restored faster with 77 mmol/L NaCl | Mechanism only; magnitude not promised in copy | ✅ §4.4 |

### 4.3 · Sources evaluated and not used

**J&G p. 247, the ADA/DC "500 ml at t−15."** Four reasons it stays out: it sits under the heading
**"Ensuring Hydration *During* Exercise"**; the paragraph's only citation belongs to a **different
sentence**; there is **no matching reference-list entry** (the phrase "Canadian Dietetic" appears
exactly once in 617 pages); and it is scoped to "prolonged exercise." Under the current constants it
now falls *inside* our band at t−15 for `BW ≥ 50` — **coincidence, not corroboration.** It must not
be readmitted on the strength of fitting.

**J&G p. 131, "20–30 % … 70–80 % in 15 minutes."** The basis of `K` in earlier drafts. **No
citation** at that point; the nearest reference belongs to the following sentence, and *Training the
Gut for Athletes* does not contain the figure. Replaced by Mudie 2014.

**J&G p. 250 and p. 252 ("6 to 8 ml/kg about 2 hours before").** Labelled ACSM 2007 but reproducing
ACSM **1996** content — verified against the 1996 stand. A rendering of a fixed 500 ml, two
generations superseded. **Do not cite.** *(The sodium sentence in the p. 252 sidebar is used only as
mechanism, not as a dose.)*

**J&G p. 489, soccer's 0.5–1 L at 1.5–2 h.** Ch. 17 is uncited by the authors' own statement, and
soccer front-loads because FIFA restricts in-play drinking. A sport-model difference.

**J&G p. 496, "at least 1 g/kg … 1 to 3 hours prior."** The **type 1 diabetes** section. It is the
only per-kg pre-exercise carbohydrate figure in the book and will be the first hit for anyone
grepping. Do not cite.

**The anaesthesia / pre-operative fasting literature.** Searched for tolerated gastric volume,
deliberately not used — different question (aspiration under airway loss), disputed within its own
field. Signposted so the next reader does not re-walk it.

**ACSM 2007's base dose (5–7 ml/kg at ≥ 4 h).** Superseded by Thomas's 5–10. Not used. Its
**correction branch** is used, for the reason in §2.4 — the two are separable, and conflating them
is what breaks the existing drawer advisory (§5.5).

### 4.4 · Sodium — the scope caveat that keeps the copy honest

Nearly all the sodium-retention evidence is **post-exercise rehydration** literature, and J&G states
its own boundary conditions: *"Plain water is not the ideal rehydration beverage when rapid and
complete restoration of body fluid balance is necessary **and when all intake is in liquid form**."*
Both fail pre-workout. The mechanism is real; the **magnitude** is much smaller than the studies
imply.

**And a number trap.** Nose used **77 mmol/L**; J&G notes that is *"considerably higher than…
commercially available sports drinks, which usually contain 10 to 25 mmol/L."* "Have an electrolyte
drink" does not deliver the studied effect. Separately, the book prints *"77 mmol/L or 0.45 g/L"*;
77 mmol/L NaCl is **4.5 g/L**. Do not propagate the printed figure.

---

## 5 · Concerns

### 5.1 · What remains unsourced

- the **linear** interpolation of the fluid target below 2 h;
- holding 10 ml/kg **flat** below the fluid window (§2.3);
- **400 rather than 600** inside NATA's band (§2.9);
- **all fluid to the earliest window** (§2.6);
- the **tier boundaries** and the carbohydrate **split shares** 60/30/10 and 75/25 (§3.3, §3.6);
- the carbohydrate **dose running to zero at t−0** (§3.10);
- the **`unknown` → pale** default (§5.18);
- the **gate's thresholds** (§5.4).

All ratify as `design_choice`. None can move an output outside a cited endpoint — the containment
invariants enforce that.

### 5.2 · Two band semantics, one drawer

Both specs now use `[low, high]` as a **permissible range** (headroom), which closes the earlier
inconsistency. But carbohydrate *also* emits a per-tier ±12.5 % **tolerance**, and the two must not
be rendered alike. For fluid below 2 h the range is 0–650 ml at t−60 for a 65 kg athlete: any
"delivered within `[low, high]`" invariant is vacuous there and is excluded explicitly. The drawer's
range bar must show the marker **off-centre** and must not present the floor as an instruction.

### 5.3 · The `tier` integer cannot be renumbered — coordinated release required

Per §2.7. Order: update the client to `regime` / `tiers` and to consuming `gateTriggered` → change
the edge-function field names → ship the engine.

Related and independent: `fluid.dart:82` infers the gate as `isTier3 && durationMin < 60 && tempC <
30` rather than reading `gateTriggered`, which the spec emits and nothing consumes.

### 5.4 · The fluid gate's proxy is broader than its source

NATA's carve-out is about *recreational athletes*; the gate keys on duration and temperature, and
neither threshold is supported. The only cited duration figure is **30 minutes**, about intake
*during* exercise. **30 °C appears nowhere as a prescriptive threshold** — J&G table 9.4 puts
marathon sweat loss at 800–1,200 ml/h at **15–20 °C**, inside the gate's "cool" branch. A 55-minute
run at 18 °C is gated to no target while plausibly losing ~700 ml.

### 5.5 · The existing drawer advisory is fixed, not retired

*"If urine is still dark at 2 h out, add 3–5 ml/kg"* turns out to have been **right all along** —
right source, right timing, right increment. What was broken is that nobody defined the base it
attaches to: bolted onto our 7.5 midpoint with no cap it reaches 10.5–12.5 ml/kg. Attach it to the
cited midpoint **with ACSM's own 12 ml/kg total cap** and it works. That is now §2.4 and it is in
the engine rather than in drawer copy.

**What remains open is the rest of §5.5's original complaint:** everyone of a given weight still
gets the same number *below* 2 h, and above 2 h the only individualization is one binary. The
check is a real answer to this, not a complete one.

### 5.6 · The two specs collide on carbohydrate concentration

If the pre-workout carbohydrate is taken as a drink, at 65 kg:

| t | carbs | fluid | conc. | ml for 8 % | fluid ceiling |
|---|---|---|---|---|---|
| −60 | 65 g | 368.8 | 17.6 % | 812 | 650 |

**There is no volume inside the fluid band that dilutes it to the 6–8 % the same source
recommends.** The `composition` ladder mitigates it (top-off is liquid/gel, snack is solid) but
nothing enforces separation. The deeper version: **`K` is a water constant** measured on 240 ml of
plain water in fasted subjects, and the carbohydrate spec guarantees food in the stomach in exactly
the window where the clearance ceiling binds.

**Softened, 2026-08-03, but not closed.** Two findings from §5.15 change the size of this problem
without removing it. The threshold where concentration becomes *consequential* is **12 %**, not 8 %
— NRC/IOM find 5–8 % of "little importance" for emptying, and 12 % the point at which absorption is
retarded and GI distress appears. And Simpson 2011 ran ~11 % as a single 315 ml bolus at t−15 with a
performance gain and no reported incident. So the 17.6 % figure above is still out of bounds, but
the band of concern is 12 %+ rather than 8 %+, and the scenario that produces 17.6 % — *taking the
entire plan total as a drink* — is one the composition ladder already forbids. The top-off now
carries an explicit ≤ 8 % contractual ceiling (`pre-workout-carbs.md`), which is the first thing in
either spec that actually enforces a concentration rather than describing one.

What is genuinely unresolved is the `K` half: the constant remains a plain-water measurement applied
where a CE drink is now the *recommended* item. The direction is known (carbohydrate slows emptying,
so `K` is optimistic) and the magnitude at ≤ 8 % is, per the same NRC/IOM statement, small. Revisit
with §5.10 if GI complaints appear near the start line, not before.

### 5.7 · `targetBasis` above 4 hours — CLOSED

Hydration returns the cited band for all `t ≥ 120` with no upper branch, so it reports
`"evidenced_band"` at t−300. Carbohydrate's `targetBasis` **does** test `WINDOW_MAX`, so the two
specs disagreed above 4 h.

**Closed by the 240-minute input cap (§3.9).** Neither engine can be called above 4 h through the
UI, so the disagreement is unreachable. Both branches stay as defensive code and neither is worth
reconciling: doing so would mean choosing a basis for a region the product does not enter. If
`INPUT_MAX_MIN` is ever raised, this reopens — and reopens *first*, before the 4 g/kg cap.

### 5.8 · Visible steps, all intentional, all pinned

Four, and each is at the edge of some authority rather than a modelling artefact:

| Step | Where | Size (65 kg) |
|---|---|---|
| fluid `low` 0 → 5·BW | t−120 | 325 ml |
| fluid dark-path plan | t−120 | 260 ml |
| carbohydrate plan `high` 4 g/kg → ±12.5 % | t−60 | 260 → 73 g |
| carbohydrate tier transfers | t−120, t−30 | total unchanged |

A workout moved by one minute across any of these changes what the user sees. Either the chip
explains the boundary or it does not render the affected value.

### 5.9 · Thomas 2016 is stale in two known places

It describes **glycerol as WADA-prohibited**; glycerol was delisted in 2018. And it is ten years
old. Both hydration and carbohydrate now depend on it, so a newer joint position statement would
supersede the fluid band, the fluid window, the carbohydrate box **and** §5.4 in one move.

**Verified 2026-08-03 (PW-007): no successor exists, and it is worse than stale — it is expired.**
The published document states *"This position statement is in effect until December 31, 2019."*
Six and a half years past its own expiry, unreplaced.

**And ACSM still lists it as current**, next to position stands it published in 2023, 2024, 2025 and
2026. So the absence of a successor is not an oversight by a dormant body; sports nutrition simply
has not been revisited. *Exercise and Fluid Replacement (2007)* is likewise still on the roster,
which means **"superseded" is too strong for Sawka 2007 standing alone** — it is superseded *on the
base dose* by Thomas's 5–10 ml/kg, which is all §2.4 ever needed, and it was never withdrawn.

Three consequences:

1. **No number changes.** Thomas remains the best available guidance and both load-bearing quotes
   re-verified exact against the source PDF.
2. **The fine print cannot say "current".** It presently does. Name the statement and its date.
3. **This question now has a shelf life.** Re-check annually. The whole folder rests on one expired
   document, and the day a successor appears it moves four things at once.

**A near-miss, recorded because the next reader will hit the same search.** A summary attributed
*"5–7 mL·kg⁻¹ at least 4 hours before exercise"* to ACSM's 2023 Exertional Heat Illness consensus.
The actual document **states no pre-exercise fluid volume whatsoever** — that figure is Sawka 2007
bleeding into the search index. Admitting it would have readmitted the exact number §4.3 excludes.
**Check the document, never the summary.**

What EHI 2023 *does* contribute is corroboration from an ACSM source seven years newer than Thomas:
*"the use of commercial oral rehydration fluids is more effective than sports drinks with lower
sodium content"* — independently confirming the Maughan 2016 bound in §5.15, and naming urine
concentration among the standard self-assessment methods.

### 5.10 · The clearance ceiling barely binds

Adopting published constants moved `K` from 0.0192 to 0.0533 /min and the residual from 250 to
400 ml. **Both changes push the same way.** At 65 kg the clearance term used to bind out to t−50 and
now binds only to **t−9**; at or below 40 kg it never binds.

Three readings: (1) correct, and the old shape was an artefact of two constructed numbers;
(2) correct but no longer useful as a mechanism — the job of grounding the near-window numbers has
transferred to the target interpolation, the least sourced part of the spec; (3) optimistic for the
population being dosed, since Mudie's subjects were fasted, resting and euhydrated while J&G p. 131
says dehydration and hyperthermia both slow emptying.

**Ratify as-is; revisit if GI complaints appear near the start line.** The honest lever is not "pick
a slower percentile" but "find a study measuring emptying in exercising or heat-stressed subjects."
None was found.

### 5.11 · The sub-2 h fluid target is a design choice in a silent region

Not a departure from a stated rule — §2.2 withdrew that framing. Thomas neither prescribes nor
forbids here. So the sub-2 h target is an ordinary `design_choice`, which is a smaller sin than v5
claimed **and** removes the excuse that we were following the source.

Unaddressed: the extension is bounded on the **gastric** side only. A 100 kg athlete permitted
1,000 ml at t−30 will clear it from the stomach and will not have voided it. There is no renal term
and no source gives one; the mitigations are procedural (*empty your bladder*) and the fact that
`target`, not `high`, is what users follow.

### 5.12 · The over-drinking population is our population

> "Over-hydration is typically seen in **recreational athletes** since their work outputs and sweat
> rates are lower than competitive athletes, while their **opportunities and belief in the need to
> drink may be greater**." — Thomas 2016

> "Women generally have a smaller body size and lower sweat rates than males and appear to be at
> greater risk of over-drinking and possible hyponatremia." — Thomas 2016

J&G: *"symptomatic hyponatremia is more likely to occur in small, lean people who run slowly, sweat
less, and ingest large volumes of water or hypotonic fluids **before**, during, and even after the
event."* The cases come from slow finishers, not elites. And the one sentence naming a *window*
names ours — *"in the hours or days leading up to the event."*

**Why it is dangerous.** Sodium sets extracellular osmolality; dilute the outside and water moves
into cells. Most tissue accommodates swelling. The brain cannot — it is enclosed — so intracranial
pressure rises. J&G: *"swelling of the brain (dilutional encephalopathy) and accumulating
extracellular fluid in the lungs (pulmonary edema)"*; normal plasma sodium 140–144 mmol/L,
symptomatic below ~130, and *"when plasma sodium falls well below 120 mmol/L, the risk of brain
seizure, coma, and death increases."* **Rate matters more than level** — the brain defends against
slow falls by extruding solutes, which takes hours to days.

**The trap that makes it lethal:**

> "The symptoms of hyponatremia are **similar to those of dehydration**… The usual treatment for
> dehydration is administration of fluid intravenously and orally. **If this treatment is given to a
> hyponatremic individual, the consequences can be fatal.**"

The correct action and the intuitive action are opposites, and the intuitive one is what a hydration
app spends its time encouraging.

**This is why three decisions are load-bearing rather than cosmetic:** `fluidLowMl = 0`, the taper,
and the gate. A fourth now joins them: **the correction is conditional on a measurement**, so the
larger number reaches only athletes who demonstrated a deficit. Any future change that weakens one
should be read against this section.

### 5.13 · The engines are stateless with respect to prior intake

`fluidMl` is a window total; the engine has no input for what has already been drunk. **The tiers
are the state machine this was missing** — if each tier's allocation is logged, "you've had the
meal-tier fluid, here's what's left" becomes computable. Not implemented. Same for carbohydrate,
plus one of its own: the top-off tier is arguably part of the during-workout budget (J&G p. 491) and
nothing nets it against `during-workout-carbs.md`.

### 5.14 · D-001 — fasted returns zero — DEFERRED by ruling

Shipped behaviour, carried into carbohydrate v2 unchanged, still unratified. It is the largest
single behavioural branch in that spec and has never had a ruling. Pinned by a `characterization`
vector, which is a tripwire — not truth.

**Xuan, 2026-08-03: explicitly deferred to a future iteration.** This is now a *decision to defer*
rather than an oversight, which is the only thing that changes. Two things it must not be allowed to
become:

- **Ratifying carbs v2 does not ratify D-001.** The SSOT says so in its Deviations section. The
  vector stays `characterization`.
- **The branch is still unbounded.** `isFasted` returns zero carbohydrate for *any* session,
  including a four-hour one, and it is a user preference rather than a measured state. Whatever the
  future ruling is, it will almost certainly be narrower than "always zero." Do not let the deferral
  harden into ratification-by-silence — that is exactly how it survived from v1 to here.

### 5.15 · The top-off tier — RESOLVED: a 6–8 % CE solution

**Chosen (Xuan, 2026-08-03): a 6–8 % carbohydrate-electrolyte solution — an ordinary sports drink at
label strength — is the preferred top-off item.** Gel + water is the same answer unbundled and is
equally valid.

Hydration no longer places fluid there when a snack window exists, so the three-way collision
(keep-sugar-low vs sugar-yes vs sodium) had already collapsed to **one product question**: what goes
with the gel. The answer turns out to be that the gel and the water can be the same object, and the
objection that stood in the way — that the sugar would slow gastric emptying — does not survive
checking.

**What was verified.**

| Claim | Evidence | Verdict |
|---|---|---|
| A 6–8 % CE drink empties measurably slower than water | NRC/IOM *Fluid Replacement and Heat Stress*: *"any differences in gastric emptying that may exist among water and beverages with moderate (5 % to 8 %) concentrations of carbohydrate are of little importance in determining the efficacy of a beverage"* | ❌ **refuted at this concentration** |
| Concentration slows emptying at all | Same source, dose–response: 2.5 % glucose emptied as fast as saline alone; **5 %, 10 % and 15 % progressively slowed it** | ✅ true, but the curve is what matters |
| There is a concentration where it becomes a real problem | Same source: at **12 %**, fluid absorption is *"significantly retarded"* and *"closely associated with symptoms of gastrointestinal discomfort and failure to complete the required cycling task"* | ✅ — and 12 %, not 8 %, is where harm is documented |
| A CE drink pre-exercise beats water | **Millard-Stafford 1997** (15-km run in the heat): 1,000 ml of water vs 6 % vs 8 % CE one hour before; **the final 1.6 km was faster on both CE drinks than on water** | ✅ direct support |
| Carbohydrate at t−15 works | **Simpson 2011**: a 65 g CHO-electrolyte gel (35.5 g CHO) **with 250 ml water**, 15 min pre-exercise; time-trial distance **+3.1 % and +3.4 %** vs placebo | ✅ direct support |
| An electrolyte drink helps you *retain* fluid | **Maughan 2016** BHI: sports drink retains **the same as plain water**; only ORS and milk beat it | ❌ **refuted — see below** |

**So the tier's requirements are all satisfiable by one product**, and this is the only item on the
list that does all three: it delivers carbohydrate (the tier's contractual job), it empties at
essentially the rate of water, and it carries sodium — which is what closes the top-off row in
`pre-workout-sodium.md` that had been marked *open, requires ruling*.

**8 % is the contractual ceiling, and it is the conservative edge of two sources.** J&G p. 130 puts
measurable inhibition at ≥ 8 %; the NRC/IOM evidence puts *consequential* inhibition at 12 %. Taking
8 % rather than 10 % costs nothing — no product we would recommend sits between them — and it keeps
juice (~11 %), cola (~11 %) and over-mixed powder out on a stated line rather than a taste judgement.

**Note what Simpson's protocol implies about §5.6.** 35.5 g of carbohydrate in a gel plus 250 ml of
water is roughly **11 %** in the stomach, at t−15, and it improved performance without reported
incident. That does not license 11 % as a formulation — it is a single 315 ml bolus, not a sustained
drink — but it does mean the concentration collision is a smaller practical problem than §5.6's
arithmetic implies. Also worth noting: Simpson's 250 ml chase is the same volume as `A0_ML`, arrived
at independently from J&G p. 493.

**The retention claim does not transfer, and this is the trap.** It is tempting to justify the CE
drink twice — carbohydrate *and* "the sodium helps you hold the fluid." Maughan 2016 says a sports
drink retains no better than water, and §4.4 already establishes that commercial drinks carry
10–25 mmol/L against the 77 mmol/L of the retention literature. **The CE drink earns its place on
emptying rate and carbohydrate delivery only.** Any copy that upgrades it to a retention aid is
making the §4.4 error in a new location.

**And the shipped top-off list is still wrong**, not merely arguable: it mixes carbohydrate items
(gel, sports drink, energy juice) with **zero-carbohydrate** items (water, electrolyte tablet,
electrolyte packet). An athlete who receives "electrolyte tablet" gets no carbohydrate and believes
they are fuelled. The two lists must be split — and "energy juice," if it means juice, now fails the
8 % line as well.

### 5.16 · The meal tier compresses just above `T_REF`

At t−130 the cited fluid dose (487.5 ml at 65 kg) has ten minutes if the window truly terminates at
t−120. The mitigation is that the athlete is not cut off — but the copy should not tell someone at
t−130 to drink 500 ml in ten minutes. **Needs a ruling on whether the meal-tier fluid instruction
softens near the boundary.**

### 5.17 · Portion does not scale with session demand — DEFERRED to a future SSOT

The strongest decision variable in the literature for choosing inside the 1–4 g/kg box is **whether
carbohydrate can be consumed during the event** — Thomas says during-exercise intake *"dampens any
effects of pre-exercise carbohydrate intake"*, and J&G's 200–300 g figure is explicitly for when
during-fuelling is unavailable.

**We compute that already.** `during-workout-carbs.md` produces a g/hr rate and zeroes it for
swimming. Nothing connects the specs. `gutTolerance` is accepted and is used by the composition
ladder, but never touches a quantity.

**Xuan, 2026-08-03: deferred to a future SSOT** covering duration and intensity-factor scoping
across all three pre-workout documents. Until then the pre-workout plan is issued for **every**
workout, and lead time alone sets the portion. Recorded here so the deferral is a decision with a
scope, not an omission.

**What the future document has to solve, stated now while it is fresh:**

- **The premise is inverted.** Lead time is a *constraint* — how much can clear the stomach — not a
  *target*. A dose keyed to it means the hour the athlete happens to wake up sets how much they eat.
  The shape that fixes this without discarding anything built here is
  `carbsG = BW × min(demandGPerKg, t/60, 4.0)`: the diagonal stops being the answer and becomes the
  ceiling it always physiologically was. It engages the during-workout rate, gives `gutTolerance` a
  numeric job, and leaves every containment invariant intact except invariant 4, which would become
  ceiling-only (the target may fall below 1 g/kg inside the window, and `targetBasis` must drop to
  `design_choice` when it does).
- **The spread inside the qualifying population is the real cost, not the short sessions.** Even
  scoped to sessions the product would serve, a 95-minute steady run and a four-hour ride differ by
  roughly 3× in fuel demand and currently receive the identical number.
- **It collides with the daily budget, and nothing reconciles them.**
  `spec/daily-macros/baseline-macros.md` sets the daily carbohydrate baseline at **4.0 g/kg**. At
  t−240 the pre-workout plan alone is **4.0 g/kg** — the entire daily baseline in one pre-session
  block, and reachable on the ratified grid rather than hypothetically. `session-demand.md` adds
  carbohydrate on top for exactly the sessions that would qualify, so the two engines are sized
  independently and never meet. **This is the item that should open the future SSOT**, because it is
  a correctness problem in the day's plan rather than a refinement of the pre-workout one.

### 5.19 · A late answer, and the frozen lead time

Two things follow from the check being answered inside the card rather than at a scheduled moment.

**`timeBeforeWorkoutMin` has to be frozen at plan generation.** If it were re-read from the clock,
an athlete who planned at t−240 and answered at t−100 would fall through to the sub-2 h branch —
losing the meal-window dose they had already drunk and being handed a smaller total than before they
answered. The SSOT now states this explicitly. It was an unstated assumption in every version up to
v6, and the inline design is what surfaces it.

**And the correction has an expiry — at both ends.** It is offered only while the snack window is
actually open, which means `TIER_TOPOFF_MAX <= currentLead <= T_REF`, with `currentLead` read from
the clock rather than from the frozen entry.

*Late edge.* An answer supplied at t−20 would add 4 ml/kg with twenty minutes to drink it and no time
to void — the same compression problem as §5.16, and the correction's whole purpose is absorption
plus clearing. So the consumer stops asking at t−30. That boundary is not invented: it is where the
window the correction belongs to closes.

*Early edge — added 2026-08-03 (PW-020), and it was missing.* v6 as ratified stated only the late
bound, so the condition permitted the check from entry onward. An athlete who plans at t−240 would
be asked immediately, in the meal window, **before drinking the dose the check exists to evaluate.**
That is precisely the error §2.5 rejects below two hours — *there is nothing to evaluate* — and it is
worse here, because the athlete would be answering about a dose they have not yet taken and the
engine would treat the answer as a verdict on it.

The tell that this was an omission rather than a decision: the clause's own heading already said
**"while the snack window is open."** The prose was right and the condition under-enforced it. Worth
recording as a class of defect — a stated intent with a half-implemented predicate reads as
deliberate to every later reader, because the words look like they cover it.

**Unresolved:** an athlete who answers *dark* at t−35, with the correction landing in a five-minute
sliver of snack window. The amount is right and the time is not. Left as a concern rather than a
taper, because tapering the correction was the constant §2.5 deliberately deleted.

### 5.18 · The `unknown` branch default — RATIFIED as-is

`unknown` is treated as `pale` (no correction). The argument: `low = 0` says nothing is required;
§5.12 says over-drinking is the documented risk; and under-drinking is self-correcting during the
session in a way hyponatremia is not.

**The counter-argument is real.** The athlete who ignores a hydration prompt is plausibly also the
one who did not drink carefully, so defaulting them low defaults the least careful user to the least
fluid. Defaulting to `dark`, however, puts every non-responder at the top of the cited band —
precisely the "belief in the need to drink" pattern Thomas names.

**Xuan, 2026-08-03: ratified as-is.** Neither default is safe in both directions, so the choice was
made on which failure is recoverable: an under-drinking athlete corrects during the session, and a
hyponatremic one does not. The honest mitigation is **making the prompt hard to ignore**, not
picking a better default — and that is a design task on the card in §6, not an engine branch.

The `PROVISIONAL` marker is removed from the SSOT. What stays is the note that this is the one place
a `design_choice` decides an athlete's number rather than merely bounding it.

---

## 6 · Explanation layer — the drawer contract

**The drawer is not a ratification instrument:** where it disagrees with an SSOT, the SSOT wins.

**Rounding lives here, not in the engines.** Both emit exact values. v3 of the hydration spec
rounded in-engine to retire false precision — *"488 ml reads as measured; 500 ml reads as advice"* —
and that reasoning is unchanged for anything a user sees. What changed is that the outputs are now
continuous by construction, and in-engine rounding reintroduces 25 ml discontinuities into a
function the design worked to make smooth.

```
round25(v) = round(v/25)*25     floor25(v) = floor(v/25)*25     ceil25(v) = ceil(v/25)*25
```

Fluid: displayed target `round25(fluidMl)`; range `[floor25(low), ceil25(high)]`. Carbohydrate
rounds to 5 g.

**Carrying the semantics into the UI:**

- **Fluid above 2 h: phrase it with the terminal edge.** *"About 500 ml between now and two hours
  before you start"* — then stop. Not *"sip until you start."*
- **Fluid below 2 h: a window total to the gun**, sipped.
- **No progress ring, no `0 / N ml` counter, no completion state.** These render a recommendation as
  a requirement and contradict `fluidLowMl = 0`.
- **The urine cue rides with the number**, in every tier.
- **Carbohydrate: never show `carbsG` alone.** Show the tiers.
- **Honour `renderAs`** (§3.8) — a 97.5 g "snack" or a 487 ml "glass" is a labelling error.
- **Never render the plan band and the tier tolerance alike** (§5.2).

**The urine check is inline, not a notification.** It lives **inside the snack-window fluid card** —
the athlete meets it when they open the recommendation, which is the moment it is actionable. Do not
schedule it as a push, a banner, or a modal: it is a question about a number the athlete is already
looking at.

Four affordances: *pale · dark · haven't gone yet · not sure*. "Haven't gone yet" maps to `dark`
(ACSM's own branch covers "does not produce urine"); "not sure" maps to `unknown`.

Beside the options, one line of copy carries the riboflavin confounder — *"taking a multivitamin or
B-complex? Your urine will look yellow either way — choose 'not sure'."* This is **copy, not an
engine branch**: there is no supplement input in the spec, the confounder biases toward false dark
(a correction the athlete does not need), and `unknown` already lands on the conservative path. If
it ever becomes an input it should be a **profile flag**, not a per-session question — supplement
use is stable.

**What must not move when the answer arrives.** The card is already on screen when the athlete
answers, so the recompute has to be visually quiet. Invariant 8b guarantees it: the band, the tier
structure and `regime` are identical across all three values, and **only the target number
changes.** Animate that one figure; leave everything else alone. This is the concrete payoff of
unifying the band (§2.4) — before that change, answering would have moved the range bar too.

**Stop offering it once the snack window closes.** Past t−30 there is nowhere for the correction to
go, so the card drops the question rather than accepting an answer it cannot act on (§5.19).

**Calculation panel**, keyed on `regime` for fluid — the bare `BW × …` form is correct only in the
first:

| `regime` | Chain |
|---|---|
| `cited` | `BW × 7.5 = meal` → floor `BW × 5` → ceiling `BW × 10`; if dark, `+ BW × 4` |
| `extrapolated` | `target = 250 + (BW × 7.5 − 250) × t/120` → ceiling `BW × 10` → floor: *"nothing required if you're already hydrated"*. **Do not render a bare `BW × …` target line** |
| `clearance_bound` | as above, but ceiling reads `400 × e^(0.0533 × t)` — "capped by how fast fluid can leave your stomach" |
| `gated` | no chain; the gate copy |

**"The Full Story" panels.** S2 must cite 5–10 ml/kg to **Thomas 2016**, not 5–7 (that is superseded
ACSM 2007 — §4.3). S3 must attribute the decline to voiding, gut comfort and late fluid not being
absorbed by the start — **not** to absorption being impossible.

---

## 7 · Fine print — the asterisk copy

Ships with the numbers, never bare. Athlete-facing. Bracketed notes are the load each paragraph
carries — not for display.

---

### About these numbers\*

**Your pre-workout plan is a starting point, not a prescription.**

**Where the fluid number comes from.** For sessions two or more hours away we follow the current
joint position statement of the American College of Sports Medicine, the Academy of Nutrition and
Dietetics and Dietitians of Canada: **5–10 ml of fluid per kilogram of body weight**. Aim to
**finish it about two hours before you start** — the gap is deliberate, so your body has time to
clear what it doesn't need. Closer in, the number comes down toward a single glass. Those closer-in
numbers are our own judgement rather than a published figure.
*[§2.2 — the terminal edge; separates cited from design choice]*

**The top of the range leaves room for the urine check.** You'll see a range that runs a little
above the 5–10 figure. That headroom is there because the check below may add a top-up — it is not
an invitation to drink to the top. **Aim for the number, not the ceiling.**
*[§2.4 — the band is `min(7.5 + 5, 12)` ml/kg and is deliberately check-independent, so it is
displayed before the athlete has answered. Without this paragraph a `pale` athlete reads 12 ml/kg
as a personal allowance, which is the one place the band and §5.12's risk argument pull apart]*

**We'll ask you to check your urine two hours out.** Pale yellow means the drinking worked and
you're set. Dark — or nothing to check — means top up a little more before your snack. That one
look is the only thing that makes this number *yours* rather than an average.
*[§2.4. "Nothing to check" maps to dark, per ACSM 2007]*

**If you're already hydrated, you may not need any of it.** Under two hours out there's no minimum —
the range starts at zero. The number is what to aim for if you're topping up from a normal baseline,
not a quota.
*[§2.3; NATA 2017's carve-out]*

**The real check is your urine, not the number.** Aim for pale yellow before you head out. Both
current position statements make this the thing to watch, not the volume. One catch: a multivitamin
or B-complex turns urine yellow whatever your hydration — if you take one, skip the check.
*[J&G p. 246; also why the prompt is suppressed]*

**Empty your bladder before you start.** Ten minutes out is about right.
*[the procedural answer to excess fluid; the only mitigation for the renal gap in §5.11]*

**Eat to the clock, not to a total.** Two or more hours out, a proper low-fat meal has time to
settle. Between two hours and half an hour, keep it small and low in fat and fibre. In the last half
hour, stick to something liquid — a gel or a sports drink with a little water — because anything
solid is still in your stomach when you set off.
*[§3.7 — the composition ladder as reason rather than rule; the water belongs to this instruction,
not to the fluid plan]*

**Skip the peanut butter and the granola bar close in.** Fat is the single biggest brake on how fast
food leaves your stomach. Save it for the meal, not the last hour.
*[J&G p. 131; §3.7]*

**A salty snack with your pre-workout drink helps the fluid stay in.** Sodium is what stops it going
straight through you. This is about the meal and snack — food is where it belongs.
*[§2.11; sodium stated qualitatively, never quantified. **No retention claim may be attached to a
sports drink** — Maughan 2016 puts it level with plain water, §5.15]*

**In the last half hour, a sports drink is a good choice.** At normal strength it leaves your
stomach about as fast as water, it gives you the carbohydrate that window is for, and it brings
some sodium with it. A gel with a glass of water does the same job. What to avoid is anything
much sweeter — fruit juice, cola, or powder mixed strong — which sits in your stomach instead.
*[§5.15 — replaces the previous paragraph's claim that "a full-strength sports drink works against
you here." That was wrong at 6–8 % and is the one line in this document research overturned rather
than refined. The ≤ 8 % ceiling is contractual in `pre-workout-carbs.md`]*

**More is not safer.** Drinking beyond what you're losing is the main cause of exercise-associated
hyponatremia — dangerously low blood sodium. It isn't an inconvenient bathroom stop. The risk is
highest for smaller, leaner athletes running at an easier pace, who sweat less and are out there
longer. **And it looks exactly like dehydration** — confusion, weakness, feeling faint — so the
instinct to drink more makes it worse. If that happens during or after a session, treat it as an
emergency and get medical help rather than drinking through it.
*[§5.12. The misdiagnosis sentence is the single most useful thing we can tell a user on this topic]*

**A short easy session may not need the fluid at all.** Under an hour in cool conditions, normally
hydrated — you're probably fine as you are, and we won't show a fluid target. We'll still suggest
something to eat, because no guideline says to skip that.
*[§2.10 and §3.5 — explains the deliberate asymmetry to a user who sees one number and not the
other]*
