type: ruling-request
bundle:

## Why this matters
When the forecast lookup fails, the create-activity form silently pre-fills **68 °F / 60 % RH** and
generates a plan from it, with no mark that the conditions were guessed. Temperature and humidity
are ratified multipliers on the sweat-rate chain, and sodium inherits the fluid rate one-for-one, so
an unruled default propagates straight through two ratified engines and returns a confident number.
For a pilot coach in Florida the guess understates her sweat rate by **~38 %**. Nothing in the
fueling specs says what should happen when conditions are unknown.

## The question
When environmental conditions cannot be fetched for a planned session, what does the engine do?

## What is already ruled
`spec/fueling/during-workout-hydration.md` — the effective sweat-rate chain (RATIFIED):
```
tempMult     = clamp(1 + (tempC − 22)·0.04, 0.50, 1.80)
humidityMult = clamp(1 + max(0, humid% − 50)·0.002, 1.00, 1.10)
effective    = round3dp( clamp(base·tempMult·humidityMult·indoorMult, 0.30, 3.00) )   # L/hr
```
`spec/fueling/during-workout-sodium.md` — sodium is proportional to the ratified fluid output:
```
sodiumRateMgph = round( (recommendedFluidRateMlHr / 1000) · conc_mg_per_l )
```
Both specs assume `tempC` and `humid%` are **known inputs**. Neither states a default, a
missing-value branch, or any provenance requirement. Grepping the fueling family for the fallback
values returns nothing — 68/60 exists only in app code.

## The arithmetic
| | tempC | tempMult | humid% | humidityMult | combined |
|---|---|---|---|---|---|
| silent fallback | 20.0 (68 °F) | 0.920 | 60 | 1.020 | **0.938** |
| her actual day | 26.7 (80 °F) | 1.187 | 95 | 1.090 | **1.294** |

1.294 / 0.938 = **1.38** — the fallback understates effective sweat rate by ~38 %, and sodium by the
same factor, because sodium multiplies the post-floor/ceiling fluid rate. The plan reads as
authoritative either way; nothing on the surface distinguishes measured conditions from invented
ones.

## Observed behaviour (not ruled)
The failure copy `"Couldn't fetch weather. Enter manually or try again"` appears in three widgets
(`app/lib/features/nutrition_plan/presentation/widgets/new_activity/running_tab_content.dart:357`,
`shared/deck_conditions_section.dart:290`, `shared/environment_section.dart:369`). The numeric
steppers are nonetheless seeded 68 °F / 60 % and **Generate Plan stays enabled**, so the default
reaches the engine unless the athlete overtypes it. The generated plan carries no marker that the
conditions were assumed.

## Options
1. **Ratify a named default + provenance.** Keep generating, but the default becomes ruled spec text
   (with its rationale) and the output carries a conditions-assumed flag that display must surface.
   Cheapest; keeps the flow unblocked; the number is still a guess but an honest one.
2. **Refuse to generate until conditions are supplied.** Strongest correctness, worst ergonomics —
   blocks plan creation on a third-party outage, and offline planning is a real use.
3. **Generate on a widened band.** Treat unknown conditions as an uncertainty range rather than a
   point estimate (e.g. carry the fluid range instead of a single rate). Most faithful to what we
   actually know; largest change, and needs its own rule text for how the band is derived.
4. **Default from the athlete's location/season rather than a global constant.** Better guess, but
   it is still a guess and it needs its own provenance rule — does not remove the question.

## Recommendation
Option 1 at minimum, and it should be ruled even if a richer option follows: whatever the default
is, *silently substituting it is the defect*. The provenance flag is the part that matters — a plan
built on invented conditions must not be presentable as one built on measured conditions.

## Suggested spec home
`spec/fueling/during-workout-hydration.md`, as a post-ratification addition next to the sweat-rate
chain (the `intraday-display.md` §4b pattern), since that is where `tempC` / `humid%` enter. Sodium
inherits automatically and needs no separate text.

## Gates
App-side: whether Generate Plan stays enabled on fetch failure, and the conditions-assumed marker on
the plan surface. Engine-side: none unless option 3 wins, which would change the during-hydration
output shape and regenerate its vectors.

## Evidence
- Coach Claudia McCoy (pilot), 2026-09-08: screenshot of the create-plan form showing
  "Couldn't fetch weather", 68 °F, 60 % humidity, for a Florida session she reports as ~80 °F / 95 %.
- Correspondence + full state: `ops/emails/2026-09-08-claudia-progress-highlights.md`.
