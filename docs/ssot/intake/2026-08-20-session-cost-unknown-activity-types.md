type: ruling-request
bundle: daily-macros-dashboard@v3

## Why this matters
The app must price EVERY activity type the platforms and the athlete can produce (foam rolling, core, aqua routines, yoga, tri/duathlon/brick, "other"), but F4's BASE_RATE names exactly four sports. The current code fallback prices everything unknown as RUNNING (11 kcal/kg/hr, quadratic) — a 60-min foam-roll shows ~750 kcal (bug filed ops-side). Until ruled, any fix is an invented rate.

## The question
What does `sessionCost` (F4) return for an activity whose sport is not RUNNING / CYCLING / SWIMMING / STRENGTH — specifically (a) mobility/recovery work (foam rolling, stretching, yoga, "aqua routine"), (b) composite types (triathlon, duathlon, brick, multisport), (c) genuinely unknown "other"?

## What is already ruled
`spec/daily-macros/session-demand.md` F4: BASE_RATE = {RUNNING 11, CYCLING 9, SWIMMING 7, STRENGTH 5} kcal·kg⁻¹·hr⁻¹ at IF 0.75; endurance quadratic, strength linear; cost linear in weight. The table itself is flagged "Uncited" in the spec's own citation audit. Nothing names other types; carb demand (F5) has the same four-sport shape.

## Options
1. **Mobility class added:** MOBILITY ≈ 2.5 kcal/kg/hr, linear in IF (like strength), for foam rolling/stretching/yoga/aqua-routine types; composites decompose by legs where the platform supplies them, else price as the dominant leg; true "other" → strength rate 5 with a `sources`-style estimate flag.
2. **Exclude non-endurance from session demand:** mobility contributes 0 (it is NEAT-scale work already covered by the NEAT model); composites decompose; unknown → 0 + flag. Cleanest for double-counting, but a 45-min hard aqua class genuinely burns something.
3. **Single conservative fallback:** anything unmapped → STRENGTH rate (5, linear). Minimal spec change; composites still wrong.

## Recommendation
Option 1 for the classes we can name + option 2's zero for true unknowns, with the flag. Whatever is chosen, the RUNNING fallback must die.

## Suggested spec home
`session-demand.md` F4 (BASE_RATE table + an explicit unknown-sport clause), cross-referenced from F5 carb demand; vectors gain unknown-sport rows.

## Gates
App: replace `?? 11` in daily_baseline_calculator.dart sessionCost (+ its TS twin in the deployed engine) per the ruling; one vector row per new class; dashboard papercut resolves.
