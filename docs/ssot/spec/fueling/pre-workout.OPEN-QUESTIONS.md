# Pre-Workout — Ratification Register

Everything left open after the three pre-workout SSOTs were ratified on **2026-08-03**
(carbs v2, hydration v6, sodium v3 — Xuan). **21 rows**; PW-007 is answered, PW-020 corrected in place and then partly superseded by PW-021 (2026-08-26).

Companion to [`pre-workout.notes.md`](./pre-workout.notes.md), which holds the reasoning. **This
file holds only status and ownership** — where a row needs an argument, it links to the notes
section that makes it. Same relationship as
[`spec/daily-macros/OPEN-QUESTIONS.md`](../daily-macros/OPEN-QUESTIONS.md) has to its specs, with
one difference: those are contradictions found *before* ratification and block it. **These do not
block ratification — they were ruled past it, deliberately.**

Code-vs-SSOT findings belong in [`DEVIATIONS.md`](../../DEVIATIONS.md). Rows here that also have a
deviation number carry it.

**Four kinds of row**, and the distinction is the point:

| | Meaning | Owner |
|---|---|---|
| **A · Deferred by ruling** | A decision was made *not to decide yet*, with a scope | Xuan — future SSOT |
| **B · Needs a ruling** | No decision yet; not blocking, but the SSOT is incomplete without it | Xuan |
| **C · Code must catch up** | The SSOT is ratified and the app disagrees with it | Lee |
| **D · QA's own work** | Nothing to rule on; we owe the artefact | QA |

---

## Index

| ID | Subject | Kind | Severity | Blocks vectors? |
|---|---|---|---|---|
| [PW-001](#pw-001) | Duration / IF scoping + demand scaling; the daily-macros collision | **A** | **high** | no |
| [PW-002](#pw-002) | D-001 — `isFasted` returns zero carbohydrate | **A** | **high** | no — pinned `characterization` |
| [PW-003](#pw-003) | The fluid gate's thresholds are unsupported by its source | **B** | medium | no |
| [PW-004](#pw-004) | Meal-tier fluid compresses just above `T_REF` | **B** | medium | no |
| [PW-005](#pw-005) | A `dark` answer arriving at t−35 | **B** | low | no |
| [PW-006](#pw-006) | Minimum-portion rule for the top-off inside the meal window | **B** | medium | no |
| [PW-007](#pw-007) | Is a newer joint position statement available? | **B** | **high** (staleness) | **ANSWERED 2026-08-03** — none exists; Thomas 2016 expired 2019-12-31. One copy ruling left |
| [PW-008](#pw-008) | `K` is a plain-water constant; a CE drink is now the recommended item | **B** | medium | no |
| [PW-009](#pw-009) | The sub-2 h extension has no renal term | **B** | low | no |
| [PW-010](#pw-010) | Prior-intake state: the tiers are the state machine, unbuilt | **B** | medium | no |
| [PW-019](#pw-019) | Thomas Table 2 reads `> 60 min`; the algorithm tests `>= 60` | **B** | low | **yes** — vectors must assert one |
| [PW-020](#pw-020) | The urine check had no early bound — offered during the meal window | **B** | medium | **yes** |
| [PW-021](#pw-021) | Live clock retired; the urine check is athlete-timed (stays in the snack card) | **B → RULED** | medium | **yes** — supersedes PW-020's `currentLeadMin` vectors |
| [PW-011](#pw-011) | D-016 — the app's 480-minute fueling-window stepper | **C** | **high** | **yes** |
| [PW-012](#pw-012) | Sodium: the app emits a number; the SSOT says `null` | **C** | **high** | **yes** |
| [PW-013](#pw-013) | The `tier` integer and the coordinated release | **C** | **high** | **yes** |
| [PW-014](#pw-014) | The shipped top-off list mixes carbohydrate and zero-carbohydrate items | **C** | **high** (safety-adjacent) | no |
| [PW-015](#pw-015) | The food lists use fat as the portion-size signal | **C** | medium | no |
| [PW-016](#pw-016) | Drawer: two band semantics, and the pinned marker | **C** | medium | no |
| [PW-017](#pw-017) | All vectors are obsolete across all three specs | **D** | **high** | **is** the vectors |
| [PW-018](#pw-018) | Explanation ⇄ engine conformance for the new output shape | **D** | medium | after PW-017 |

**Six rows gate the vector work** — PW-011, PW-012, PW-013 as code changes the vectors assert
against, PW-019 as a boundary they must pin one way or the other, and PW-017/PW-018 as the work
itself. Everything else can be ruled on at leisure without stalling conformance.

---

## A · Deferred by ruling

### PW-001
#### Duration / IF scoping, demand scaling, and the daily-macros collision
**Ruled 2026-08-03: deferred to a future SSOT covering all three pre-workout documents.** Until it
exists, the pre-workout plan is issued for **every** workout and lead time alone sets the portion.
Notes [§5.17](./pre-workout.notes.md).

Three things that document has to solve, in the order they matter:

1. **The daily-budget collision.** `spec/daily-macros/baseline-macros.md` sets the daily carbohydrate
   baseline at **4.0 g/kg**. At t−240 the pre-workout plan alone is **4.0 g/kg** — the whole daily
   baseline in one pre-session block, reachable on the ratified grid rather than hypothetically.
   `session-demand.md` adds carbohydrate on top for exactly the sessions that would qualify. The two
   engines are sized independently and never meet. **This is a correctness problem in the day's
   plan**, not a refinement of the pre-workout one, and it should open the document.
2. **The premise is inverted.** Lead time is a *constraint* (how much can clear the stomach), not a
   *target*. Keyed to it, the hour the athlete wakes up sets how much they eat. The shape that fixes
   it without discarding anything: `carbsG = BW × min(demandGPerKg, t/60, 4.0)` — the diagonal
   becomes the ceiling it always physiologically was.
3. **The spread inside the qualifying population**, not the short sessions, is the real cost. A
   95-minute steady run and a four-hour ride differ ~3× in demand and get the identical number.

**Interacts with:** PW-003 (the gate is the other half of "which sessions get a plan").

### PW-002
#### D-001 — `isFasted` returns zero carbohydrate
**Ruled 2026-08-03: deferred to a future iteration.** Notes [§5.14](./pre-workout.notes.md);
register entry in [`DEVIATIONS.md`](../../DEVIATIONS.md).

Shipped since v1, never team-discussed, carried into carbs v2 unchanged. **Ratifying carbs v2 did
not ratify D-001** — the SSOT says so in its Deviations section and the vector stays
`characterization` (a tripwire, not truth).

Two properties the future ruling will almost certainly narrow: the branch returns zero for *any*
session length including a four-hour one, and `isFasted` is a **user preference**, not a measured
state. Do not let the deferral harden into ratification-by-silence — that is exactly how it survived
v1 through v6.

---

## B · Needs a ruling

### PW-003
#### The fluid gate's thresholds are broader than its source
Notes [§5.4](./pre-workout.notes.md). The gate (`<60 min AND <30 °C` → no target) is a proxy for
NATA 2017's *recreational athlete* carve-out, but neither threshold is supported: the only cited
duration figure is 30 minutes and concerns intake *during* exercise, and **30 °C appears nowhere as
a prescriptive threshold** — J&G table 9.4 puts marathon sweat loss at 800–1,200 ml/h at 15–20 °C,
inside the gate's "cool" branch. A 55-minute run at 18 °C is gated to no target while plausibly
losing ~700 ml.

Ratified as-is because `low = 0` makes the consequence small. Fold into PW-001's document — it is
the same question (*which sessions get a plan*) asked about fluid instead of food.

### PW-004
#### Meal-tier fluid compresses just above `T_REF`
Notes [§5.16](./pre-workout.notes.md). At t−130 the cited dose (487.5 ml at 65 kg) has ten minutes
if the window truly terminates at t−120. The athlete is not cut off, but **the copy should not tell
someone at t−130 to drink 500 ml in ten minutes.**

**The ruling needed:** does the meal-tier fluid instruction soften near the boundary, and if so is
that copy or arithmetic? Copy is the cheaper answer and probably the right one.

### PW-005
#### A `dark` answer arriving at t−35
Notes [§5.19](./pre-workout.notes.md). The correction is offered only while the snack window is
open (current lead time ≥ 30 min). An athlete answering at t−35 gets the full 4 ml/kg landing in a
five-minute sliver of window. **The amount is right and the time is not.**

Left unresolved deliberately — tapering the correction would reintroduce the constant §2.5 was glad
to delete. Low severity: it needs an athlete to open the card in a narrow window.

### PW-006
#### Minimum-portion rule for the top-off inside the meal window
Notes [§3.6](./pre-workout.notes.md). Fixed 60/30/10 shares put the top-off at **13–19.5 g inside
the meal window — below one gel** — before it more than doubles at t−105 where the meal drops out.
The food selector will be portioning half-gels at the low end.

**If it becomes a problem the lever is a minimum-portion rule** (merge a tier into its neighbour
below a threshold), *not* a return to the fixed per-kg portion, which reintroduces the 5.4 g snack
crumb at the other end. Not implemented; on the record so the trade isn't re-discovered.

### PW-007
#### Is a newer joint position statement available? — **ANSWERED 2026-08-03**
Notes [§5.9](./pre-workout.notes.md).

**No successor exists. But Thomas 2016 formally expired on 31 December 2019** — verbatim from the
published document, not from a summary:

> "This position statement is in effect until December 31, 2019."
> *(approved by DC on November 17, 2015; approved by the ACSM Board of Trustees on November 20,
> 2015)*

Expired six and a half years, unreplaced.

**Yet ACSM still lists it as a current position stand.** *Nutrition and Athletic Performance (2016)*
is on the live roster next to stands ACSM has published since — Exertional Heat Illness (2023),
Weight Loss Intervention Strategies (2024), Blood Doping (2025), Resistance Training Prescription
(2026). This is not a body that went quiet; it has been publishing and has not revisited sports
nutrition. **Same for *Exercise and Fluid Replacement (2007)*, also still on the current roster** —
so Sawka 2007 is superseded *on the base dose* by Thomas's 5–10 ml/kg, exactly as §2.4 reasons, but
it was never withdrawn. Soften "superseded" to "superseded for the base dose" wherever it stands
alone.

**Both load-bearing quotes re-verified against the source PDF and exact** — the 5–10 ml/kg fluid
sentence and the 1–4 g/kg Table 2 row. One transcription error found: PW-019.

**Near-miss worth recording.** A search summary attributed *"5–7 mL·kg⁻¹ at least 4 hours before
exercise"* to the ACSM 2023 Exertional Heat Illness statement. The actual PDF **contains no
pre-exercise fluid volume at all** — no ml/kg, no prehydration timing. That figure is Sawka 2007
bleeding into the search index. Adding it on the strength of the snippet would have readmitted the
one number [§4.3](./pre-workout.notes.md) says not to use.

**What EHI 2023 does give us — corroboration, from an ACSM document seven years newer than Thomas:**

> "For athletes with signs and symptoms of dehydration… the use of commercial **oral rehydration
> fluids is more effective than sports drinks with lower sodium content**"

That independently confirms the Maughan 2016 BHI bound now written into `pre-workout-sodium.md` — a
sports drink is not a retention aid. It also names urine concentration among the standard
self-assessment methods, corroborating the check.

**Two consequences, and neither is a number change:**

1. **Copy.** The fine print says *"we follow the **current** joint position statement…"*. Calling a
   document that expired in 2019 "current" is a claim we cannot defend. Name it and its date
   instead. **Open — needs a copy ruling.**
2. **Watch, don't re-walk.** The answer has a shelf life. Re-check annually rather than ad hoc; the
   entire `spec/fueling/` folder rests on one expired document, and a successor would move the fluid
   band, the fluid window, the carbohydrate box and PW-003 in a single publication.

### PW-019
#### Thomas Table 2 reads `> 60 min`; the algorithm tests `>= 60`
Found while verifying PW-007. The situation column is **`Before exercise > 60 min`** — strict
inequality. `pre-workout-carbs.md` quoted it as `≥ 60 min` in two places and labelled it *verbatim*;
both are now corrected. The algorithm still computes
`inWindow = … AND (workoutDurationMin >= 60)` (`pre-workout-carbs.md:110`), so **a workout of
exactly 60 minutes is reported as `evidenced_band` on authority the source does not grant.**

One boundary value, so the practical effect is negligible — but it is a citation-fidelity defect in
a document whose whole claim is citation fidelity, and conformance will pin 59.999 / 60 either way.

**The ruling needed:** tighten the algorithm to `> 60` and match the source, or keep `>= 60` and
log it as a deliberate one-minute deviation. **Do not leave it undecided** — the vectors have to
assert one of them.

### PW-020
#### The urine check had no early bound — CORRECTED 2026-08-03
Raised by Xuan while reviewing the interface. Notes [§5.19](./pre-workout.notes.md).

v6 as ratified offered the check when `timeBeforeWorkoutMin >= T_REF` **and** current lead
`>= TIER_TOPOFF_MAX`. Only the *late* edge was bounded, so an athlete planning at t−240 would be
asked **immediately, in the meal window, before drinking the dose the check exists to evaluate.**

That is the same error [§2.5](./pre-workout.notes.md) rejects below two hours — *there is nothing to
evaluate* — and worse here, because the engine would treat an answer about an untaken dose as a
verdict on it.

**Corrected** to bound both edges: `TIER_TOPOFF_MAX <= currentLeadMin <= T_REF`, with `currentLeadMin`
read from the clock and explicitly **not** `timeBeforeWorkoutMin`. The clause's own heading already
said *"while the snack window is open"* — the prose was the intent and the predicate under-enforced it.

**Still open:** the correction changes engine-visible behaviour (`hydrationCheckUsed` can no longer
arrive during the meal window), so it wants a vector at each edge — `currentLead = 120.001 / 120`
and `29.999 / 30` — and a ruling on whether it warrants a hydration **v7** stamp or lands as an
erratum on v6.

**Class of defect worth remembering:** a stated intent with a half-implemented predicate reads as
deliberate to every later reader, because the words look like they cover the case.

### PW-021
#### Live clock retired — the urine check is athlete-timed — RULED 2026-08-26
**Ruled by Xuan, 2026-08-26**, while reviewing the pre-workout redesign v3 (Claude Design session;
findings register `docs/design-reconciliation/pre-workout-v2-vs-pre-workout.md`, F-02).

**The ruling.** Two parts, one amendment:

1. **No live window.** The athlete's planned start time is a guess; a "which feeding is live now"
   indicator is wrong more often than right and is not practical to follow. The BEFORE surface
   shows which feedings **exist** (set by `timeBeforeWorkoutMin` at plan creation) and never which
   one is **current**. `currentLeadMin` is **not** read from the clock by any consumer.
2. **The check is athlete-timed; it stays in the snack-window card.** Because there is no clock,
   hydration v6's `offerCheck` predicate (as corrected by PW-020) cannot be evaluated and is
   **retired**. The check is available for the life of any plan with `timeBeforeWorkoutMin >= T_REF`;
   the "not before you have drunk the dose / too late for the correction to land" edges move from a
   predicate into **copy** beside the question — *"Do this about two hours before you start, once
   you've finished your pre-run meal."* Its home is unchanged from v6 / notes §6 — **inside the
   snack-window feeding card** (a fluid-stat placement was tried the same day and reverted) — with
   the row labelled as a fluid instrument (*"adjusts your fluid target"*) so it is not read as food.
3. **No cue on the surface below 2 h** (Xuan, same day). Sub-2 h plans show the fluid figure and its
   band with nothing beneath; the pale-yellow cue for that region lives in the fine print (notes
   §7, paragraph 4 — *"if you're already hydrated, you may not need any of it"*), reachable from the
   surface's `?`. This narrows v6's *"any surface showing `fluidMl` MUST show the cue with it"* to:
   the cue is one tap away, not inline, below `T_REF`.

**What does not change.** The engine contract: `hydrationCheck` still only affects output at
`t >= T_REF`, the dark path still adds `TOPUP_ML_KG · BW` to the snack-window fluid, the band is
still check-independent (inv. 8b), and only `fluidMl` moves on the recompute.

**Supersedes** the two-clock half of PW-020: the edge vectors it asked for (`currentLead = 120.001 /
120 / 29.999 / 30`) are no longer meaningful and are withdrawn. The PW-020 defect it corrected (an
answer accepted before the dose is drunk) is now mitigated by copy, not enforced — a deliberate
trade for a rule athletes can follow.

**Amends** `pre-workout-hydration.md` v6 *The urine check — contractual* (the `offerCheck` block and
its two bullets). `pre-workout.notes.md` §6's placement ("inside the snack-window fluid card") stands. Folded as a
dated post-ratification addition; whether it earns a v7 stamp is decided with PW-020's open
question, not separately.

### PW-008
#### `K` is a plain-water constant; a CE drink is now the recommended item
Notes [§2.8](./pre-workout.notes.md), [§5.6](./pre-workout.notes.md),
[§5.10](./pre-workout.notes.md). `K = 3.2/60` is measured on **240 ml of plain water in fasted,
resting subjects** (Mudie 2014). The clearance ceiling it drives binds in the last ~9 minutes at
65 kg — exactly where `pre-workout-carbs.md` now recommends a 6–8 % CE drink.

Direction is known (carbohydrate slows emptying, so `K` is optimistic) and magnitude at ≤ 8 % is
small per NRC/IOM. Compounded by J&G p. 131: dehydration and hyperthermia both slow emptying, and
Mudie's subjects had neither.

**The honest lever is not "pick a slower percentile" but "find a study measuring emptying in
exercising or heat-stressed subjects."** None was found. Revisit if GI complaints appear near the
start line.

### PW-009
#### The sub-2 h fluid extension has no renal term
Notes [§5.11](./pre-workout.notes.md). The extension below `T_REF` is bounded on the **gastric** side
only. A 100 kg athlete permitted 1,000 ml at t−30 will clear it from the stomach and will **not**
have voided it. No source gives a renal term.

Mitigations are procedural (*empty your bladder* — in the fine print) and the fact that `target`,
not `high`, is what users follow. Low severity, but it is the one place the ceiling is knowingly
incomplete.

### PW-010
#### Prior-intake state: the tiers are the state machine, unbuilt
Notes [§5.13](./pre-workout.notes.md). Both engines are **stateless** with respect to what has
already been consumed. The tiers are exactly the missing state machine — log each tier's allocation
and *"you've had the meal-tier fluid, here's what's left"* becomes computable.

Carbohydrate carries an extra half: the top-off tier is arguably part of the **during-workout**
budget (J&G p. 491 — *"most of the carbohydrate ingested at this time will become available… during
the first part of the run"*) and nothing nets it against `during-workout-carbs.md`. That double-count
should be settled alongside PW-001, since both are cross-spec arithmetic.

---

## C · Code must catch up to the ratified SSOTs

### PW-011
#### D-016 — the app's fueling-window stepper allows 480 minutes
**[D-016](../../DEVIATIONS.md).** Ruled 2026-08-03: four hours is the design limit, **the app is
wrong, not the algorithm.** Notes [§3.9](./pre-workout.notes.md).

Fix: `max: 480` → `240` in the cycling / swimming / brick tabs; `value + 15 <= 480` → `<= 240` in
`running_tab_content.dart:605`. **Clamp persisted values on load** — activities already saved at
300–480 min will otherwise render a value the stepper cannot reach.

**Blocks vectors** because the ratified grid is 0–240; until the app agrees, conformance is asserting
against an input domain the product can exceed.

### PW-012
#### Sodium: the app emits a number, the SSOT says `null`
`pre-workout-sodium.md` is ratified at `sodiumMg = sodiumLowMg = sodiumHighMg = null`. The shipped
code emits a sweat-category-scaled figure — `offline_macro_calculator.dart:141`, 300 / 450 / 600 mg
by sweat-sodium category, then split across tiers (`:147–148`, snack at 50 % of the meal).

This is the **largest user-visible behaviour change** of the three specs and also the lowest-risk
one: no output-shape change, no new input, no coordinated release. It removes an invented number
whose only source (Sawka 2007's 20–50 mEq/L) is superseded for dosing.

**`null`, not `0`** — the distinction is contractual and a consumer that conflates them misreports.

### PW-013
#### The `tier` integer and the coordinated release
Notes [§2.7](./pre-workout.notes.md), [§5.3](./pre-workout.notes.md). The shipped client branches on
**v1 tier semantics** (`macro_explanation_service.fluid.dart:66`,
`macro_explanation_service.calculations.dart:643`, reading `pre_run_hydration_tier`). A Flutter
client and a Supabase edge function deploy separately and users run old builds, so **no integer
mapping is safe** — an old client receiving a new integer mis-renders silently.

**Release order:** update the client to `regime` / `tiers` and to consuming `gateTriggered` → rename
the edge-function fields → ship the engine.

Related and independent: `fluid.dart:82` **infers** the gate as `isTier3 && durationMin < 60 &&
tempC < 30` rather than reading `gateTriggered`, which the spec emits and nothing consumes.

### PW-014
#### The shipped top-off list mixes carbohydrate and zero-carbohydrate items
Notes [§5.15](./pre-workout.notes.md). The list carries gel, sports drink and energy juice alongside
**water, electrolyte tablet and electrolyte packet**. An athlete who receives "electrolyte tablet"
gets **no carbohydrate and believes they are fuelled** — the tier's entire contractual purpose,
silently unmet.

Split the two lists. And "energy juice", if it means juice (~11 %), now also fails the ratified
**≤ 8 %** top-off ceiling. Highest-severity item in section C that is not a release-coordination
problem.

### PW-015
#### The food lists use fat as the portion-size signal
Notes [§3.7](./pre-workout.notes.md). The current lists signal portion size with *richness*, which
means fat — *bagel and jam* is a snack, *bagel and cream cheese* is a meal. Tolerable if the meal
tier starts at 3 h; **indefensible now that the snack tier runs down to 30 minutes**, since fat is
the strongest brake on gastric emptying (J&G p. 131).

Four of eleven meals and four of eleven snacks are fat-dominant. **Six one-ingredient swaps fix it**,
every replacement drawn from J&G p. 492's verbatim race-day list: raisins → honey; cream cheese →
jam; peanut butter → jam in the three snack entries; dates → ripe banana.

### PW-016
#### Drawer: two band semantics, and the pinned marker
Notes [§5.2](./pre-workout.notes.md), [§6](./pre-workout.notes.md). Three rules the drawer must
honour and does not yet:

- **Never render the plan band and the tier tolerance alike.** `[carbsLowG, carbsHighG]` is a
  permissible range; `[tolLowG, tolHighG]` is how close the chosen food must land. Different jobs.
- **The marker is pinned at a band edge at both ends of the cited window** — 65 g = the floor at
  t−60, 260 g = the ceiling at t−240. Correct arithmetic; must not render as out-of-range.
- **No progress ring, no `0 / N ml` counter, no completion state.** These render a recommendation as
  a requirement and contradict `fluidLowMl = 0`.

Also open from [§5.5](./pre-workout.notes.md): below 2 h everyone of a given body weight still gets
the same number, and above it the only individualization is one binary. The urine check is a real
answer to this, not a complete one.

---

## D · QA's own work

### PW-017
#### All vectors are obsolete across all three specs
`vectors/fueling/pre-workout-{carbs,hydration,sodium}.json` all pin **v1**. The output shape changed
(`tiers` added, `hoursBefore` renamed, plan band re-based, sodium → `null`), so none survive.

Required coverage is specified per-spec in each SSOT's Conformance section. The shape of the work:

- **Enumerate the seventeen-point grid** (0–240 in 15-minute steps) rather than sampling it — at a
  given body weight that *is* the whole input space.
- Carbs: every cell of invariant 7's boundary table; `t = 240` asserting `carbPerKg == 4.0` exactly
  with `evidenced_band`; the plan-band step at t−60; the ≤ 8 % top-off exclusion.
- Hydration: both anchors, with **anchor A asserting `high == 12·BW`, not `10·BW`** (the v5 error);
  all three `hydrationCheck` values at `t ≥ 120` proving the **band is byte-identical** while the
  target differs; the clearance handover at 65 kg and 100 kg plus `BW = 40` where it never binds.
- Sodium: the three fields `null` in every tier and on the gate path, and **never `0`**.
- Cross-spec: `TIER_MEAL_MIN == T_REF` as a build-time assertion that fails loudly.

**One characterization vector, not a truth vector:** `isFasted` (PW-002).

### PW-018
#### Explanation ⇄ engine conformance for the new output shape
The second conformance layer — the drawer must show the number the engine computed. The new shape
gives qa-smoke more to check than v1 did: per-tier values summing to the plan total, `renderAs`
honoured (a 97.5 g "snack" or a 487 ml "glass" is a labelling error), and the band rendered with the
right semantics per PW-016.

Sequenced after PW-017 and after the PW-013 release, since there is nothing on screen to read until
the client consumes `tiers`.
