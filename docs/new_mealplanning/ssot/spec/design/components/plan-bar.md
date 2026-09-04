# Design SSOT — Component: Plan Bar (the provisional plan in chat)

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Extracted from `PlanBar` / `PlanTile` /
`ReviewSheet` / `MealSheet` (prototype `planbar.tsx`) and the Dart plan bar. The research's "selected meals
tray", done as the real server-acked draft (update plan §4.1 S22: "MET, better").

## State model

```
plan      : MealPlan | null           # the conversation's draft, from get_plan {conversationId}
open      ∈ { minimized, expanded }   # starts MINIMIZED; every new turn re-minimizes
n         = |plan.meals|
review    ∈ { closed, open }          # the Review sheet
confirmed = plan.status == confirmed
```

## Constants

```
REVIEW_AT = 3          # Review becomes the primary button at ≥ 3 meals (secondary before)
DEFAULT_SERVINGS = 4
```

## Contracts

| # | Contract |
|---|---|
| PB-1 | **Pinned above the composer from the first turn**, title "Your plan · N meals" (N in `orange` when > 0). Minimized by default and **re-minimized on every new turn** so Vana's reply is never hidden behind it. |
| PB-2 | **Below REVIEW_AT the bar coaches:** "K more and the week starts to take shape." Expanded with 0 meals: "Tap a meal above and it lands here." |
| PB-3 | **Every tile carries its own actions:** × (remove, with an Undo snackbar that re-adds with the same servings and session), a `− ×n +` stepper (min 1), the slot chip; tap the body → the meal sheet (servings · Swap · Remove). Actions live on the card, never as chips (`../../intent/` §2.4). |
| PB-4 | **Review → the Review sheet:** meals grouped by cooking session when batch cooking is on (Cook Sunday · Top-up Wednesday · Make fresh), flat otherwise ("made the night of"); steppers and × inline; the primary button "Confirm plan · build shopping list"; "Keep planning" closes. |
| PB-5 | **Confirm lives here, not in Vana's chips and not in the bar header.** After confirm the button reads "Plan confirmed" and is disabled; the bar is gone from the next conversation. |
| PB-6 | **The swap picker inside the meal sheet** shows up to 4 same-type meals not already in the plan; picking swaps in place (P-7). |
| PB-7 | **Macros on tiles / review rows** follow `show_macros` via `MacroPillRow` (compact on tiles). |

## Gestures

| # | Gesture | Write |
|---|---|---|
| PB-G1 | tap title | toggles `open` (no write) |
| PB-G2 | × | `remove_meal {planMealId}`; Undo → `pick_meals` with previous servings + session |
| PB-G3 | stepper | `set_servings {planMealId, servings}` (client clamps ≥ 1; the server treats ≤ 0 as remove) |
| PB-G4 | Confirm | `confirm_plan {conversationId}` → `batch` + `shopping_list` parts → the ConfirmedCard |

## Conformance

Goldens: minimized 0 / minimized 2 (coaching line) / expanded 3 (primary Review) / review sheet grouped /
review sheet flat / confirmed. Widget: PB-1 re-minimize on a new message; PB-G2 undo restores servings and
session; PB-5 negative (no Confirm chip from the model — vana-eval `no_chips` on wrap-up). Patrol: plan build.
