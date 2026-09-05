type: spec-erratum
bundle: pre-workout-macros@v2
raised-by: QA sim-explore (Claude), 2026-08-26 — evidence for the app's `port-assumptions` Q1

## Why this matters
FC-2 says the feeding header shows DELIVERED only, and the app's carb figure does; but its fluid
figure is the engine's tier dose. On device the same header line carries two semantics — the
F-07 defect class FC-2 was written to close.

## Artifact + location
`spec/design/components/feeding-card.md` v1, FC-2: "A fluid tier still shows its fluid oz
('16oz · fluids')" — silent on whether that oz is delivered (Σ rows) or the tier dose
(`fluidTiers[].fluidMl`).

## What it says vs what the device shows
- Pre-Run Meal header "175g · 19oz": 175 g is Σ rows (moves with the stepper); 19 oz is the tier
  dose (`7.5·BW`) — the oatmeal row itself reports 44 oz. Stepping oatmeal 6.5 → 3.5 moves the
  carb figure 175 → 95 g and leaves 19 oz untouched (`runs/…/23b-down.png`).
- Snack header after Dark: "72g · 10oz" while its rows deliver 0 oz (already-covered branch, no row
  added) (`04-snack-expanded.png`, `21a-dark.png`).
So the athlete reads "19oz" as what the meal delivers, and it is not.

## Smallest correction
One sentence in FC-2 choosing one of: (a) fluid header = Σ rows' fluid, hidden when 0 (delivered-
only, consistent with the carb figure) — recommended; (b) fluid header = tier dose, labelled as an
aim ("aim 19oz"), which reintroduces an aim on the header against FC-2's own ruling. This is the
ruling the app's `2026-08-26-before-card-port-assumptions.md` Q1 asks for; QA's on-device reading
is (a).
