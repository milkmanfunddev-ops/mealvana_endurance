type: ruling-request
bundle: intent@v1

## Why this matters
Confirms the interim call is actually settled — this is filed for completeness/traceability, not because it's
genuinely contested.

## The question
Should macro numbers show by default on meal cards / plan tiles (framed as minimums tied to the daily target),
with `show_macros` as an opt-out toggle? This already shipped (`show_macros` default ON, `MacroPillRow` in
`MealCard`/`PlanTile`/plan bar/`ReviewSheet`) under a call Xuan made verbally on 2026-05-20 ("runners want to
see numbers").

## Options
- **Confirm as-shipped.** Macros on by default, `show_macros` opt-out. Matches Xuan's own 2026-05-20 statement.
- **Reverse to opt-in.** Would contradict Xuan's own prior statement; no evidence motivating this.

## Recommendation
Confirm as-shipped — this is barely a judgment call. Filed here mainly so the register has a clean paper trail
back to the 2026-05-20 meeting note rather than resting on Lee's memory of it.

## Gates
None — this call is already live in the app; a reversal would be a real (if unlikely) product change.

## Suggested spec home
`OPEN-QUESTIONS.md` Q-4 (mark RATIFIED once Xuan confirms in writing).
