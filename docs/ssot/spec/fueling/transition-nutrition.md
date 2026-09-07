# SSOT — Transition Nutrition (T1/T2/…: macro targets only)

**Status: RATIFIED v1 (Xuan, 2026-09-01).** Drafted 2026-08-31/09-01; five review-thread revisions folded before ratification (TC review artifact e4542244); Q-TN1–TN4 remain OPEN — the ratified defaults (transition_min 3, flat 30 g clamp) stand until ruled.
**Scope (per Xuan, 2026-09-01): the MACRO recommendation for a brick transition — nothing else.**
Which foods fill the target, whole-unit rounding, and item counts are the food-recommendation
bench's (`qa/food-recommendation`); the ratified constraint C4 (`spec/domain/catalog-conventions.md`:
whole units, ≤2 items + water) governs that layer. Transition *identity* is `spec/domain/brick.md`
R8 (positional). Multi-segment hydration redistribution and its 300 ml carve-out constant remain
the reserved slice in `during-workout-hydration.md` — not absorbed here.
**Research basis:** `transition-nutrition.notes.md` — headline finding: no position stand or
practitioner guide doses the transition itself; fueling is ONE continuous, duration-scaled hourly
schedule and the transition is an *ingestion opportunity*. Dose = the schedule's next tick,
placed at the gap. All conditionality is deterministic at plan time (the engine generates the
feeding schedule, so "did a gap open" is arithmetic).

## The math (PROPOSED)

```
effective_gap_min = pre_buffer + transition_min + settle(next_sport)
dose_g            = clamp( round( rate_gph × effective_gap_min / 60 ) , 0 , 30 )
band              = [0, 30]        # every transition; 0 is a legitimate value
```

- **T-1 — Dose formula.** `dose_g = clamp(round(rate_gph × effective_gap_min / 60), 0, 30)`;
  band `[0, 30]` on every transition; 0 is a legitimate value.
- **T-2 — Rate source.** `rate_gph` is the during-workout carb rate the engine assigns the NEXT
  segment under the during-carbs slice: band keyed by **cumulative event time through that
  segment** (per that slice's multi-segment note — NOT the segment's own duration, NOT the whole
  event's total) → gut multiplier → midpoint → **the next sport's ceiling** (running 70 ·
  cycling 120 · swimming 0). So the next leg shapes the rate twice: its position in event time
  picks the band, and its sport caps it. **No new rate math**; swim's ceiling 0 ⇒ a transition
  into a swim doses 0.
- **T-3 — Zero-intake legs extend the gap.** A zero-intake previous leg contributes its whole
  duration to `effective_gap_min` (a swim: nothing could be eaten during it).
- **T-4 — Rounding.** Whole grams (fuel-stat M-5 precedent).
- **T-5 — Sodium and fluid: no transition-specific demand; rendered as tallies, never targets
  (Xuan's review directive, 2026-09-01).** The continuous hydration/sodium schedule owns them; a
  drink taken at a transition is *placement* of that schedule, not an extra target.
  **Evidence check (per that directive):** no position stand (ACSM/AND/DC 2016; ACSM 2007
  fluid-replacement; ISSN) and no practitioner source pulled (PF&H, SiS, GSSI SSE #114,
  Jeukendrup's practical plans) suggests a fixed transition sodium or fluid amount — the closest
  is the practitioner "gel with a mouthful/sip of water" cue, which is placement guidance, not a
  quantity. The engine's current fixed 300 ml (+ sodium riding it at sweat concentration) is
  uncited; its fate belongs to the reserved multi-segment hydration slice.)

### Constants (Mealvana design choices, practitioner-derived — notes L2/L3/L5)
| Constant | Value | Basis |
|---|---|---|
| `pre_buffer` | 15 min | last feeding lands ~15 min before a leg ends (L3) |
| `settle(bike)` | 10 min | minimal intake while settling onto the bike (L2) |
| `settle(run)` | 15 min | run gut tolerance; resume within ~15 min (L5, Pfeiffer 2011 asymmetry) |
| clamp | 30 g | **Mealvana design choice — no direct per-bolus citation exists in the sources pulled.** Anchored indirectly: 30 g across a typical ~30-min effective gap ≈ the 60 g/h glucose-oxidation guideline (Jeukendrup 2014); the practitioner "one gel in transition" norm agrees, as does C4's whole-unit ceiling. Soft by design: an athlete-edited row may exceed it (the band flags, never blocks); whether it should scale with gut training is Q-TN4 |
| `transition_min` default | 3 min | when the plan carries no measured/planned stop time (the creation form collects none today), use 3 — the middle of the practitioner 2–5 min window; a provided value always wins |

## What this replaces (characterization — never ratified)
`generate-macros-v4/brick-workout.ts:776-783`: 0 g below 180 min total, then `weight × 0.3 g/kg`
(first transition) / `0.35 g/kg` (later). Retired on ratified grounds: the during-carbs SSOT
states body weight does not affect during-exercise carb absorption (Jeukendrup 2014), and the
180-min cliff has no source. The fixed-tier output (~22–26 g at 73 kg) sits inside this spec's
band, so existing plans move modestly.

## Worked examples (the oracle checks these before any vector is emitted)
| # | Event | Transition | rate_gph | gap (min) | dose |
|---|---|---|---|---|---|
| W1 | bike 60 → run 45 (total 105, moderate gut) | T1 (→run), 5 min | band 45–60 → mid 52.5, run ceil 70 → 52.5 | 15+5+15 = 35 | 52.5×35/60 = 30.6 → **30 g** (clamp) |
| W2 | run 20 → bike 20 (total 40, moderate gut) | T1 (→bike), 2 min | band 0–30 → mid 15, bike ceil 120 → 15 | 15+2+10 = 27 | 15×27/60 = 6.75 → **7 g** |
| W3 | swim 35 → bike 180 → run 110 (total 325) | T1 (→bike), 3 min | cumulative through bike 215 → band 60–90 → mid 75, bike ceil 120 → 75 | 35+3+10 = 48 (swim extends gap) | 75×48/60 = 60 → **30 g** (clamp) |
| W4 | any → swim | T (→swim) | swim ceiling 0 → 0 | — | **0 g** |

*W2 shows the honest macro answer for short bricks: small but nonzero; whether 7 g becomes one
item or none is the selection layer's C4 call, not this spec's.*

## Open questions
| Q | Question | Blocks |
|---|---|---|
| Q-TN1 | **Max gap:** past what gap is a "brick" two sessions with their own pre/post phases (deferred in from `brick.md`)? Proposed shape: a single minutes threshold; value needs a ruling. | brick.md eligibility carries no gap rule until ruled |
| Q-TN2 | Should `pre_buffer` depend on the PREVIOUS sport (eating in a run's final 15 min is harder than a bike's)? v1 uses one constant. | nothing — refinement only |
| Q-TN3 | Should `transition_min` be exposed as a user input on the brick creation form, or stay a silent 3-min default? (Raised on review 2026-09-01: the form collects no stop time today.) | the creation-form design only — the math takes whatever value arrives |
| Q-TN4 | Should the 30 g clamp scale with gut-training level (the during slice already scales the RATE 0.7/1.0/1.2×; e.g. clamp 30 default / 40 for high), or stay flat with the athlete's manual edit as the escape hatch? (Raised on review 2026-09-01: Xuan takes a 40 g Enervit in transition without trouble.) | the clamp constant + the card's band rail follow whatever is ruled |

## Dependencies & conformance
- Inherits the during-carbs core (`during-workout-carbs.md` — status *recorded*, one open
  boundary question there; ratifying THIS spec does not ratify that slice).
- Vectors: `vectors/fueling/transition-nutrition.json` via `spec-to-vectors` (oracle from this
  file, verified against W1–W4 first). Inputs: ordered segments (sport, duration), gut level,
  transition minutes. Expected: per-transition `dose_g` + band.
- Seam: targets must *reach* the consumer — `brick.md` R8's producer-shaped seam test (D-008).
