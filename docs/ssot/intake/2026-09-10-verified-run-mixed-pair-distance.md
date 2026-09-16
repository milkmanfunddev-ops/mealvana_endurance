type: spec-erratum
bundle: data-integrations@v1 (evidence) + daily-macros-dashboard (display)

## Why this matters
Live prod specimen (Xuan's verified run, 2026-09-10, phone screenshots + row query):
the timeline card and Active Energy sheet show **"8 mi · 44 min"** on a Garmin-verified
run that measured **5.01 mi / 44:15**. Mixed pair: planned distance beside measured
duration — exactly what the ruled D-1 display contract and L-2 planned/actual split
outlaw.

## Root observation (prod row, calories_burned=435, 2026-09-10)
`distance_miles = 8` (FS PLANNED — never overwritten) · `distance_meters = 8060.09`
(measured ≈ 5.01 mi — overwritten) · `actual_distance_miles = 5.00832` (measured).
The Garmin completion updated `distance_meters` and `actual_distance_miles` but left
`distance_miles` at the planned value — the row is internally inconsistent (its two
"distance" fields disagree by 60%), and the card reads the stale one.

## Disposition
Already ruled — remediation rides the handback: the L-2 planned/actual split makes
`distance_miles` planner-owned (so the card's VERIFIED state must read `actual_*`, per
the D-1 state table). The NEW defect for Lee pre-split: the completion write-path is
internally inconsistent (updates one mile field, not the other) — fix with the split.
Also live on the same screenshots: the BMR-embedded 435 (staged F22 erratum) and the
foam-roll 122 kcal unknown-sport fallback (F4a ruled → 0 + estimate flag) — both
expected to change visibly when their fixes land; noted for regression review.
