type: spec-erratum
bundle: pre-workout-macros@v2
raised-by: app coding agent, 2026-08-26 (feature/pre-workout-before-card)

## Why this matters

A golden note contradicts the ratified component contract it is meant to pin; whichever the
implementer follows, the other reads as a conformance miss at audit.

## The artifact + exact location

`conformance/design/pre-workout-before-card.goldens.yaml`, golden `feeding_meal_expanded`:

> notes: hydration-check row first, then food rows with steppers; header "52g · carbs" (FC-2 — no aim, no DONE/AIM)

## What it says vs. why that is wrong

The note places the hydration-check row in the **MEAL** card. Every other artifact places it in the
**SNACK** card:

- `spec/design/components/feeding-card.md` v1 **FC-6**: "The hydration-check row is the first row of
  the SNACK card on ≥ 2 h plans".
- `spec/design/surfaces/pre-workout-before-card.md` v1, Composition: "Hydration check … the first
  row of the SNACK card on ≥ 2 h plans"; B-3: "inserts the tagged water row into the SNACK feeding
  card".
- `spec/design/components/hydration-check.md` v1: "inside the snack-window card".
- The reference rendering (`pre-workout@v2.html`, `hydroHostId = 'snack'`).
- The gestures manifest's own `fc_hydration_row_placement`: "the FIRST row of the SNACK card".

## The smallest correction

Change the `feeding_meal_expanded` note to:

> notes: food rows with steppers; header "52g · carbs" (FC-2 — no aim, no DONE/AIM). No
> hydration-check row here — it is the first row of the SNACK card (FC-6).

## How the app implements it meanwhile

Per the handoff ("where the HTML and spec/design disagree, spec/design wins"; the note is not the
contract), the `feeding_meal_expanded` golden is blessed **without** the check row; the check-in-snack
placement is pinned by `fc_hydration_row_placement` and by the `check_dark` / `check_not_yet_covered`
goldens (snack card expanded).
