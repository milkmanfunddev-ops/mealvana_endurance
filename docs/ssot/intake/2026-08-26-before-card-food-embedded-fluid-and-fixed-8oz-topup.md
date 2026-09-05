> **RESOLVED 2026-09-03 (Xuan: "apply ADJ-1") → Q1 closed by catalog-conventions A3 (embedded water counts; band discipline → food-recommendation.md §5/§6); Q2 option (b) folded as hydration-check.md AMENDMENT A1 (shortfall ceil 0.5 cup, never fixed 8 oz, never past ceiling)**

> **DEFERRED 2026-08-27 (Xuan) → the food-recommendation ratification step.** Engine target and band are correct; this is a food-selection gap (ledger P13). Not resolved, not declined.

type: ruling-request
bundle: pre-workout-macros@v2
raised-by: QA sim-explore (Claude), 2026-08-26, charter pre-workout-before-card on app feature/pre-workout-before-card @ 8bac1c1e

## Why this matters
Two behaviours the ratified family leaves implicit make the FLUIDS stat alarm on plans the athlete
has not touched: (1) water carried inside solid foods counts as delivered fluid, (2) the dark-path
row is a fixed 8 oz rather than the shortfall. Together, a freshly generated 240-min plan opens at
44 oz against a 30 oz ceiling, and answering Dark at 24 oz delivered lands the athlete at 32 oz —
over the ceiling — by the check's own action.

## Q1 — does fluid embedded in a food row count toward the FLUIDS delivered figure?
Observed: "Oatmeal (½ cup dry)" ×6.5 reports 44 oz; the summary FLUIDS delivered = Σ rows including
that, so the marker is magenta on first open (bug filed ops `2026-08-26-generated-plan-fluid-exceeds-
v6-ceiling.md`). Surface B-1 says delivered = Σ of the matching macro over every row; nothing says
whether cooking water in oatmeal is "the matching macro" for hydration v6's `fluidMl` (a drink dose,
divided, sipped). Options: (a) count it (B-1 literal; then the selector must solve fluid to the v6
band, H6); (b) only drink-type rows (water, sports drink, coconut water, the tagged row) count —
food water is reported on the row but excluded from the stat; (c) count it but the selector never
lets food-embedded fluid exceed the band. Recommendation: (b) — the v6 dose is what the athlete
drinks; oatmeal's water is not a hydration instruction, and (b) makes the stat stable under carb
edits. Suggested home: surface B-1 (one sentence) + fuel-stat traceability row.

## Q2 — the dark-path water row: fixed 8 oz, or the shortfall?
Observed: delivered 24 oz, target raised to 28 oz, the app adds 8 oz → 32 oz, marker turns
dragonfruit. hydration-check.md state table says "8 oz water … unless already covered" (mock);
hydration v6 says the amount still to take is `fluidMl − intake`, floored at 0. Options: (a) keep a
fixed 1-cup row (simple, matches the rendering) and accept overshoot; (b) add `ceil to 0.5 cup` of
the shortfall (4 oz here); (c) add the full `TOPUP_ML_KG·BW` (10 oz at 73 kg) regardless.
Recommendation: (b) — it is the spec's own arithmetic and it never pushes the athlete over the
ceiling; note R-01 rounding makes the row 0.5-cup granular. Suggested home: hydration-check.md
state table DARK row.

## What it gates
The `fuelstat_fluid_overshoot` golden's meaning (an overshoot should be the athlete's doing), and
the selector's fluid handling. Neither blocks the build; both make the first-open state honest.
