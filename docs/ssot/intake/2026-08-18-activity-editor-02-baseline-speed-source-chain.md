type: ruling-request
bundle:

## Why this matters
Item 01's recommended ruling (hold speed/pace, derive duration) needs a baseline speed. Lee's meeting objection was that none exists; the code shows one does — but its precedence and fallback constants are unratified design choices.

## The question (R2)
When the editor needs a speed/pace it wasn't given, where does it come from, in what order?

## Options
1. **This workout's current speed/pace → athlete profile default (`defaultCyclingSpeedMph` / `defaultRunningPaceMinPerMile` / Zone-2 swim pace) → sport fallback constant (recommended — ratifies what the code already does).** Fallback constants to be ratified explicitly as `targetBasis: design_choice`: 15 mph · 9:00 /mi · 2:00 /100 m today.
2. Profile default always wins over the workout's own value (re-baselines every edit; loses a deliberately entered pace).
3. Derive from recent completed activities of the same sport (better baseline; new data dependency; out of scope for the redesign).

## What is already ruled (and what isn't)
- Observed chain and constants: item 01 "Observed behavior". Not in any spec.
- Whether the athlete must be **shown** the baseline in use is a design question downstream of this ruling (the ops brief recommends a visible "your usual · 14 mph" chip).

## Suggested spec home
`spec/activity/editor-inputs.md` §baseline; constants in the same table style as `fueling/*` design-choice rows.

## Gates
Item 01; the design brief's baseline chip; a golden vector for "new activity, no profile default → fallback".
