type: ruling-request
bundle:

## Why this matters
Neither meeting proposal prevents a 35 mi / 45 min workout from being saved, and the plan screen renders the derived 4:00 /mi without complaint (frames `../ops/design/briefs/workout-editor-coupling-2026-08-18/screens/02,05`). The engines then fuel a physically impossible session and mark it ✅.

## The question (R5)
What speed/pace bands per sport are (a) **soft** — warn inline, offer a one-tap fix to the baseline, still saveable — and (b) **hard** — cannot save; and are the bands absolute or relative to the athlete's baseline?

## Options
1. **Two tiers (recommended): soft band per sport, absolute (placeholders to be ruled: cycling 8–30 mph · running 4:30–15:00 /mi · swimming 1:00–3:30 /100 m); hard block at ≤ 0 or > 3× the athlete's baseline (item 02).**
2. Soft-only (never block). Simplest; still lets a 46 mph ride into the engines if the athlete dismisses.
3. Relative-only bands (±X % of baseline). Adapts to elites/beginners but breaks for athletes with no profile default.

## What is already ruled (and what isn't)
- Nothing on input plausibility. Precedent for "the app is wrong, not the algorithm" ratified input domains: D-016 (`app/docs/ssot/DEVIATIONS.md`) capped the fueling-window stepper at 0–240 min.

## Suggested spec home
`spec/activity/editor-inputs.md` §plausibility, bands as a design-choice table; boundary vectors like D-016's.

## Gates
Design of the warning state (Claude Design state D in the ops brief); a boundary vector so the engines are never called with an out-of-band triple.
