# Design SSOT — During card (+ "How We Calculate" drawer)

**Status: PROPOSED (recorded as-built 2026-09-03, for ratification).** The app is the reference
rendering (transition-card precedent). Evidence: `runs/2026-09-03-design-recording/01-launch.png`
(card), `02-during-drawer.png` / `03-drawer-sodium.png` (drawer). Math authority: the during-*
SSOTs + `food-recommendation.md` (selection). Sibling components: `fuel-stat.md` (stat trio),
`feeding-card.md` (row anatomy), `transition-card.md` (drawer pattern precedent).

## Contracts
| # | Contract |
|---|---|
| DC-1 | Header `DURING <SPORT>` in electrolyte accent + `?` (drawer affordance) + segmented control **Summary | By Hour**; Summary is the default face. |
| DC-2 | Stat trio CARBS · FLUIDS · SODIUM renders per `fuel-stat.md`: delivered figure above a band rail `[low, high]` with markers; delivered inside the band renders in the in-range accent. (Sodium here HAS a band — during sodium is targeted, unlike pre-workout's reported-only sodium; the two must never be conflated.) |
| DC-3 | Food rows use the standard feeding-row anatomy (icon chip, quantity-first label, chevron expander) + the dashed ADD FOOD pill (FC-7). The card renders what the plan holds — selection quality is the engine contract (`food-recommendation.md` §6), asserted there, not here. |
| DC-4 | `?` opens **"How We Calculate Your During <Sport> Targets"**: context chip (`Multi-Segment` on bricks), one section per stat with headline `<planned> planned / <target> target` + `Range: a–b` badge, the FORMULA LINES in accent — **two-layer conformance: every number and step in the formula lines must equal the ratified engine math** (verified line-for-line 2026-09-03: total-event-time → band → gut × → midpoint → sport ceiling; sweat-rate × replacement for fluid; fluid-rate × concentration for sodium). Expanders: Calculation · Watch: <topic> · The Full Story; per-section Helpful? 👍/👎. |
| DC-5 | **By Hour** buckets are client-derived (the engine sends `by_hour_data: null`); the tab renders per-hour apportionment of the summary — it must never show numbers that disagree with Summary's totals. |
| DC-6 | The drawer explains TARGETS only; no surface explains SELECTION (which step resolved, why these items). See Q-DC1. |

## Open questions
| Q | Question | Blocks |
|---|---|---|
| Q-DC1 | Should the drawer (or a row affordance) name the resolution step ("From your pinned formula" / "Built from the food library") — surfacing §10's step attribution to the athlete? | nothing — additive |

## Conformance
Goldens: card Summary face (run + brick variants), drawer per-stat sections. Widget: DC-2 band
presence for during-sodium (positive) vs pre-sodium (negative, F-2); DC-4 formula-line equality
against a known input (the two-layer check); DC-5 Summary/By-Hour totals agreement.
