# Transition nutrition (T1/T2) — research notes

**Status: RESEARCH NOTES (first pass, 2026-08-31) — input to the SSOT session, NOT a spec.**
Bundle branch: `qa/brick-transition-nutrition`. Fills the slice both ratified during-workout
specs reserved: `during-workout-hydration.md` §scope ("Multi-segment tri (T1/T2 transitions +
redistribution, `calculateBrickHydration`) is a SEPARATE follow-up slice") and
`during-workout-carbs.md` §deferred (brick penalty ×0.8, cumulative-event-time banding).
Primary-source verification of every number below is still owed before ratification —
this pass is web-search depth, not paper-in-hand depth.

## The headline finding (negative, and load-bearing)

**No position stand or peer-reviewed guideline assigns a nutrition dose to the transition
itself.** ACSM/AND/DC 2016, the ISSN nutrient-timing stand, and the triathlon reviews
(Jeukendrup 2011, J Sports Sci; Jeukendrup 2014, Sports Med) all prescribe **hourly rates
scaled by total event duration**, continuous across the whole event. The transition appears in
the literature only as an **ingestion opportunity** — a moment when eating is *possible*
(you cannot eat while swimming; gut tolerance is poor while running) — never as a separate
demand window with its own carb/sodium/fluid requirement.

Consequence for the model: **transition fuel = the next scheduled tick of the continuous
hourly plan, placed at the transition because that's when the athlete can take it.** The
demand driver is cumulative event time (which `during-workout-carbs.md:46` already ratified
for the band); the transition contributes *placement*, not *quantity*.

## The numbers the continuous schedule uses (to verify against primary sources)

| Nutrient | Guideline | Source (to pull in full) |
|---|---|---|
| Carbs, total event <45 min | none needed (mouth rinse at most) | Jeukendrup 2014 duration framework |
| Carbs, 1–2.5 h | 30–60 g/h | ACSM/AND/DC 2016 position |
| Carbs, >2.5–3 h | up to 90 g/h, multiple transportable (≈2:1 glu:fru) | ACSM/AND/DC 2016; Jeukendrup 2014 |
| Fluid | individualized by sweat rate; ~0.4–0.8 L/h typical start point; keep BM loss <2 %, avoid overdrinking | ACSM 2007 fluid-replacement stand (Sawka) — **not re-verified this pass** |
| Sodium | no per-transition dose anywhere; practice ranges 300–1000 mg/L of fluid (sweat-concentration-driven, up to ~2000 mg/L for salty sweaters); mainly relevant >2 h | practitioner literature; ISSN — **needs a primary anchor** |

## Practitioner consensus on the two transitions (not position-stand grade)

- **T1 (swim→bike):** take a gel (~25–30 g) + fluid in or just after T1 — the swim is a
  zero-intake leg, so T1 *front-loads the bike's hourly budget*; it is not additive to it.
  The bike is the eating window ("fuel the bike, save the run").
- **T2 (bike→run):** feed **only if a gap has opened** since the last bike feeding (rule of
  thumb: skip if you fed in the final ~15 min of the bike; take a gel + sips if it's been
  ~20+ min). Again: the same schedule, next tick — not a T2 ration.
- Run-leg tolerance < bike-leg tolerance supports the app's run-after-bike reduction in
  spirit; **the specific ×0.8 factor has no citation yet** — hunt one or mark it a Mealvana
  design choice in the spec.

## What this implies for the SSOT session (proposed, for Xuan to rule)

1. **Transition identity is positional/temporal** (`T{i+1}`, a gap between segments), with the
   sport pair as a label — the literature gives sport pairs no nutritional meaning, only gut
   tolerance of the *following* segment. This also happens to resolve the app's
   naming-collision bug in the simplest direction.
2. **Transition dose = f(gap length, elapsed cumulative time, next-segment tolerance)** under
   the one continuous hourly rate — not a lookup table of T1/T2 rations.
3. **Training bricks** (the app's actual case: transitions of seconds-to-minutes) get a
   degenerate dose ≈ 0 with an optional "this is your chance to drink" placement cue.
4. A **maximum-gap** rule (intake Q7) follows naturally: past some gap the "brick" is two
   sessions with their own pre/post phases — the literature's continuous-schedule frame breaks
   down when the gap is long enough to digest a meal. Number needs a ruling.
5. Leg count: with per-gap dosing there is no mathematical obstacle to a 4th leg (H10's
   "T1/T2 only" becomes "per gap") — max-3 returns to being purely a product/UX ruling.

## Sources this pass leaned on (web-search grade)

- Position of AND/DC/ACSM 2016, Nutrition and Athletic Performance (J Acad Nutr Diet / MSSE)
- Jeukendrup 2014, "A Step Towards Personalized Sports Nutrition: Carbohydrate Intake During
  Exercise", Sports Med 44(S1) — duration-scaled framework
- Jeukendrup 2011, "Nutrition for endurance sports: marathon, triathlon, and road cycling",
  J Sports Sci 29(S1)
- ISSN position stand: Nutrient Timing (2017)
- Practitioner: eatforendurance.com 70.3/IM fueling guide; NEVERSECOND long-distance guide;
  Science in Sport triathlon guide; roadmancycling "Fuel the Bike, Save the Run"

## Second pass (2026-08-31): the practitioner / logistics layer

A confirming data point first: **Jeukendrup's own practitioner writing doesn't dose transitions
either** — his mysportscience half-distance plan and his TrainingPeaks 70.3 article give only the
hourly target (60 g/h) and say nothing about T1/T2. The absence in the practical literature of the
field's leading figure is strong evidence the continuous-schedule frame is the intended model, not
an academic simplification.

What the practitioner sources DO add is a **logistics/tolerance rulebook** around the transition
boundary — adoptable as Mealvana design choices with attribution:

| # | Practical rule | Source(s) |
|---|---|---|
| L1 | T1: one gel (~25–30 g) + mouthful of water in/just after T1 — front-loads the bike budget while tolerance is highest | Precision Fuel & Hydration; eatforendurance |
| L2 | …but settle first: minimal intake the first ~10–15 min of the bike; "start fuelling by km 15" | SiS Ironman guide; PF&H |
| L3 | Last bike feeding light and ~15–30 min before T2 (gel/sips, nothing solid); finish the bottle before dismount — you lose it at T2 | Roadman; eatforendurance |
| L4 | T2 feeding is CONDITIONAL: skip if fed in the final ~15 min of the bike; gel + water if ~20+ min gap or a slow transition | eatforendurance; PF&H |
| L5 | Resume run intake early (within ~5 km) even if unintuitive; gels taken WITH water, not sports drink | gritandmileage; SiS |
| L6 | Gut tolerance is leg-asymmetric: severe GI distress ~4 % in cycling vs up to 32 % in Ironman running (Pfeiffer 2011) — run leg gets liquids/gels, no solids/fiber/fat near T2 | GSSI SSE #114 (de Oliveira); Pfeiffer et al. 2011, MSSE |
| L7 | The bike is the pantry: carry on the bike (bento/taped), plan around aid-station spacing, nothing new on race day, train the gut | multiple; Jeukendrup (gut training) |

**Mapping to spec candidates:** L2/L5 → a post-transition "settle window" parameter per following
sport (bike ~10–15 min, run ~10 min); L3 → a pre-T2 no-solid buffer; L4 → the conditional-tick rule
(dose at transition iff gap since last feeding > threshold, default ~15–20 min); L6 → the citation
trail for the run-tolerance reduction (supports the ×0.8 *direction*; still no source for the
factor itself); L1 → T1 placement cue. Each would enter the spec marked **Mealvana design choice,
practitioner-derived** — none is position-stand grade.

**Authoritative practitioner sources to keep on the shelf:** Asker Jeukendrup (mysportscience /
CORE); Precision Fuel & Hydration (Andy Blow — sweat/sodium case-study database); GSSI Sports
Science Exchange (esp. SSE #114 GI distress); Science in Sport guides; the IRONMAN coaching
ecosystem (TrainingPeaks, LifeSport). Books not yet pulled: Jeukendrup *Sport Nutrition*; Burke
*Clinical Sports Nutrition* (triathlon chapter); Friel *Triathlete's Training Bible*; Ryan *Sports
Nutrition for Endurance Athletes* — check each for a transition section before the SSOT session.

## Proposed model v0 (2026-08-31, discussion with Xuan) — PROPOSED, not ratified

Xuan's simplification request: phase 1 establishes the CARB AMOUNT only; everything conditional/
food-shaped (L1/L3/L5/L7) moves to the food-recommendation phase — mirroring the pre-workout
layering (macros bundle ratified grams, food-composition ratified foods).

Key resolution of the "too conditional" worry: **at plan time the conditionality is deterministic.**
The T2 rule "feed only if a gap opened since the last feed" references the feeding schedule the
engine itself generates, so the gap is computable from leg durations + the ratified hourly rate.

**Formula (carbs, per transition):**
```
effective_gap_min = pre_buffer(prev_leg) + transition_min + settle(next_leg)
dose_g            = clamp( rate_gph × effective_gap_min / 60 , 0 , 30 )
```
- `rate_gph` = the ratified during-workout carb rate at that cumulative event time
  (`during-workout-carbs.md` — cumulative time, not segment time, already ratified). Swim legs
  are zero-intake (ratified), so a swim extends the gap backward across the whole leg.
- New constants to ratify (Mealvana design choices, practitioner-derived L2/L3/L5):
  `pre_buffer` ≈ 15 min; `settle` ≈ 10 min → bike, ≈ 15 min → run; clamp 30 g (one-gel bolus).
- **Derivation check:** 60 g/h × (15+0+15)/60 = 30 g = the universal "one gel at the transition";
  rate 0 (short brick) → 0 g; swim-first → clamps to 30 g in T1. The T1/T2 asymmetry emerges from
  `settle(next_leg)`; no per-sport-pair table.
- **Band:** [0, 30] for every transition (Xuan's initial [10,30] T1 floor rejected in discussion —
  a 40-min brick must be allowed 0). Target from the formula; band is what conformance asserts.
- Sodium & fluid at the transition: dose 0 in phase 1 (continuous schedule; a transition sip is
  placement, owned by food/timing phase). Revisit only if the SSOT session disagrees.

Phase 2 (food recommendation) then owns: gel-with-water, no-solids-near-T2, product format per
leg, carry logistics — i.e., L1/L3/L5/L7 verbatim.

## Observed in the wild (anecdotal, Xuan, ~Aug 2026 — no recording)

A brick plan recommended **~3 gels for one transition** (≈75 g vs the engine's own 22–26 g
target). Code-traced candidate mechanisms (any could produce it; edge logs decide):
1. Template-0 validation failure → LP fallback over the transition pool with
   `maxFoodItems: 3, maxServingsCap: 2, enforceWaterMin: true` — chasing 300 ml water + sodium
   with a pool of gels/chews can stack 3 gel-like packets (`brick-handler.ts:290-305`).
2. Sport-pair naming collision (repeat legs → two `T2`s) stacking two transitions' foods
   under one label.
3. `generateTransitionPhase` passes `durationMinutes = 60` to the during solver — an hour's
   gut-cap headroom for a minutes-long window (`brick-handler.ts:230`).
Diagnosis path: `[PLAN-V3-BRICK]` console lines + `logFormulaCascade(phase: "transition:*")`
in the generate-nutrition-plan-v3 edge logs name the branch and targets per transition.
**Phase-2 vector candidate:** a transition's food list ≤ 1 carb unit + fluid — kills all three.
