# Design SSOT — Transition card (+ explanation drawer)

**Status: RATIFIED v1 (Xuan, 2026-09-01).** Recorded as-built 2026-09-01, revised through the review (TC-2 ×2, TC-4); Q-TC1 remains OPEN. Extracted from the live
app (branch `fix/activity-update-preserves-device-fields`, dev sim) at Xuan's direction — no
standalone HTML prototype exists; the app IS the reference rendering. Evidence:
`qa/runs/2026-09-01-brick-transition-design.md` (+ screenshot folder). Math authority:
`spec/fueling/transition-nutrition.md` (PROPOSED); identity authority: `spec/domain/brick.md` R8.
Recording ≠ endorsement: rows marked **[defect]** are observed but ruled wrong, and must change
at implementation — they are listed so the ratified card is fully specified.

## Placement
One card per transition, between the two segment DURING cards, on the single plan/event surface
both access paths reach (creation flow and dashboard brick card — verified identical surface).

## Contracts
| # | Contract |
|---|---|
| TC-1 | Title is **positional**: `TRANSITION <i>` (matches brick.md R8). Never sport-pair. Subtitle: "Quick refuel between segments". Leading 🔁 icon in `electrolyte` accent. |
| TC-2 | Stat trio on the card: **CARBS · FLUIDS · SODIUM**, semantics per evidence basis (Xuan's comment-rules, 2026-09-01: target+range only where literature supports one; fluids over protein). **CARBS renders `delivered/target` with band [0,30]** — the only stat with a literature-derived target (T-1: the next tick of the ratified hourly schedule). **FLUIDS and SODIUM render as plain tallies (delivered only)** — no transition-specific target exists in any position stand or practitioner source (T-5): the as-built sodium `265/248mg` pair drops its target half, and the as-built fixed 10 oz fluid target is not rendered as a target. **PROTEIN is dropped from the card** (as-built it renders a permanently-0 stat with no basis; a transition never carries a protein recommendation). |
| TC-3 | Food rows use the standard feeding-row component (icon chip, quantity-first label, chevron expander) + ADD FOOD. Selection constraints are C4's (whole units, ≤2 items + water) — owned by catalog-conventions, enforced by the selection layer, asserted here only as "the card renders what the plan holds". |
| TC-4 | `?` opens the drawer **"How We Calculate Your Transition <i> Targets"**: chip `T1 / T2`, one section per stat, `Calculation` and `The Full Story` expanders, per-section Helpful? 👍/👎. Headline per TC-2 semantics: **carbs** shows `<delivered> planned / <target> target` with the T-1 formula line in accent; **fluids and sodium (tallies)** show delivered only, and their section explains that no transition target exists — the continuous during schedule owns them (T-5) — never a formula implying one. This is the explanation layer: **every number and formula shown must equal the ratified math** (two-layer conformance — drawer number == engine number). |
| TC-5 | Copy register (drawer): intro + Full Story copy must be **sport-pair-aware or sport-neutral**. As-built "between the swim and bike segments" / "bridges the swim gap and offsets wetsuit heat" on a run→bike brick is **[defect]** (run log F-D). Post-ratification the carb section's "use this time to take in quick-digesting carbs" must agree with a nonzero target (F-C resolves). |
| TC-6 | The Adjust-Your-Macros aggregate table has **no transition representation** as built (F-G). **[ruling needed]**: fold transition dose into the DURING column, or add a row/footnote. Undecided — Q-row below. |

## Open questions
| Q | Question | Blocks |
|---|---|---|
| Q-TC1 | Aggregate representation (TC-6): DURING column absorbs the transition dose, or transitions get their own line on Adjust Your Macros? | the aggregate table spec only |

## Conformance
`conformance/design/transition-card.yaml` (to be written at implementation): TC-1 positional
title on a bike→run brick (the D-008 order), TC-2 paired delivered/target rendering per stat,
TC-4 drawer formula lines equal to the ratified spec's math for a known input, TC-5 copy free of
swim/wetsuit references on non-swim bricks. Golden screenshots hold the rest (layout, hues).
