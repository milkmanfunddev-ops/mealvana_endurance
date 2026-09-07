> **RESOLVED 2026-09-03 → labeled override (option 3); folded to food-recommendation.md §1a; design iteration gated**

type: ruling-request
bundle: (food-recommendation ratification / Formula Kit policy)

## Why this matters
A pinned formula is served to an athlete who is ALLERGIC to it, at portions beyond the template's own maximum — P18's ×6.5 oatmeal was this mechanism, reproduced today at ×3.5 for gluten-allergic Ravi.

## The question
Should an in-scope pin bypass (a) the allergen filter, (b) the diet filter, (c) the dislike filter, (d) the [min,max_servings] scale clamp? Today it bypasses ALL FOUR ("locked Formula Kit policy 2026-05-21: in-scope pins are honored unconditionally" — `generate-macros-v4/pre-workout.ts` pin override; `bypassScaleClamp` in `pre-workout-scoring.ts:88-99`).

## Evidence (F-33, F-20 — probe register)
- Sim 2026-08-31: Ravi (allergies gluten+dairy) with a pinned "Oatmeal" meal template → "Oatmeal (½ cup dry) ×3.5 · 94g · 24oz" honored (`runs/2026-08-31-food-recommendation-probe/23.png`, `25.png`); row max_servings=3.
- The 2026-08-26 ×6.5 (P18) is the same mechanism at a larger carb target.

## Options
1. Pins bypass preference filters (dislike/diet) but NEVER allergens; clamp respected with shortfall reported (recommended — allergy is a safety input, not a preference).
2. Pins bypass everything but the card labels the conflict ("pinned despite your gluten allergy") — informed override.
3. Status quo (unconditional) — ratify it explicitly if so.
Note: the athlete pinned Oatmeal BEFORE declaring the allergy (or vice versa) — the ruling should also say what happens to existing pins when allergies change.

## Gates
P18 close-out; portion-cap enforcement; pin UX copy.

## Suggested spec home
New `spec/domain/formula-pins.md` (pin semantics are cross-engine domain policy, like brick.md), referenced from pre-workout-food-composition.

> **Producer note 2026-09-01 (Xuan, in-session):** the unconditional override — including allergy/diet — is an *intentional no-choice*: a pin is the athlete's explicit word and outranks their stored preferences. Recommendation accordingly shifts to **option 3 (ratify the status quo)**, with the desk confirming it as the written rule; the existing-pins-when-allergies-change question stays open for the same ruling.

> **Producer note 2026-09-02 (dossier thread):** Xuan is weighing the labeled-override variant ("pin honored + visible conflict label — we won't fail silently") and flagged that it needs design effort — a Claude Design iteration for the conflict label (copy, placement, pin-time vs plan-time, keep-anyway affordance) is to accompany that option if ruled. Thread kept open on the dossier as his reminder.

## RULING (Xuan, 2026-09-03, RULING-DESK block — option 3 as presented on the dossier)
**Pins are honored unconditionally AND the card labels the conflict** ("pinned despite your gluten
allergy") — informed override, never silent. Verbatim from the block: "Need another design effort -
please offer suggestions and prompts that i can directly take to claude design. Also worth deciding:
does the warning appear at pin time, plan-generation time, or both?" → the conflict-label UX goes to
a Claude Design iteration (prompts delivered 2026-09-03); warn-timing (pin-time / plan-time / both)
stays an OPEN sub-question for that iteration.
