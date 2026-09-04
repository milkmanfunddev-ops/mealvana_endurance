# Design SSOT — Component: Plan Tile (the Plan-tab row)

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** prototype `plan.tsx`, `swipe-row.tsx` (`PlanTile` / `PlanList` / `SwipeRow` / `TileSheet`).
**Code:** the Dart tile (plan-tab-v2 decisions, 2026-08-31).
**Scope:** the Plan-tab row only — see `../surfaces/food-plan-tab.md` for the surface it's composed into.

**What this file owns:** the Plan-tab row's swipe/edit-mode state machine and contracts (PT-1..PT-6) — swipe-
to-swap/remove, undo, the tile sheet, axis lock, and that plan-tab writes carry no conversation scope (PT-6).

## State model

```
meal       : PlanMeal
edit       ∈ { view, edit }          # Edit mode: steppers + swap/remove buttons replace the ×servings label
dx         : px                      # swipe travel while dragging
```

## Constants

```
SWIPE_THRESHOLD = 88 px      # travel that commits
SWIPE_MAX       = 120 px     # clamp
AXIS_LOCK       = 6 px       # movement before the gesture is classified x or y
UNDO_TOAST      = 5 s        # remove toast with Undo; plain toasts 2.5 s
```

## Contracts

| # | Contract |
|---|---|
| PT-1 | **A tile is icon · name · slot chip · "×servings"**; when some were eaten, "K of N left" beside the chip. No chevron, no detail route, no pips, no "Cook Sun" (plan-tab-v2). |
| PT-2 | **Swipe right = Swap, swipe left = Remove.** The reveal's opacity tracks travel; releasing past the threshold commits, otherwise snaps back. A direction with no handler moves at 15 % (resistance), never commits. |
| PT-3 | **Remove is undoable for 5 s** ("Removed <name> · Undo"); undo re-adds with the same servings and session. |
| PT-4 | **Tap (view mode) opens the tile sheet:** servings stepper (1–14), Swap (→ the full-catalog swap page), Remove; Done closes. In edit mode the tile is not tappable. |
| PT-5 | **Vertical scroll is never stolen** — the gesture locks to the axis of the first 6 px of travel. |
| PT-6 | **Plan-tab writes carry no conversation scope — ⚖️ interim (Lee, 2026-09-03).** They land on the week's active plan (P-2). |

## Gestures

| # | Gesture | Write |
|---|---|---|
| PT-G1 | swipe ≥ 88 px right | navigate to swap for `planMealId` (write happens on the swap page: `swap_meal`) |
| PT-G2 | swipe ≥ 88 px left | `remove_meal {planMealId}`; Undo → `pick_meals` |
| PT-G3 | stepper (sheet / edit) | `set_servings` |

## Conformance

Goldens: tile view, tile with "2 of 4 left", edit mode. Widget/Patrol: PT-2 commit and snap-back at 87/88 px,
resistance in the unhandled direction, PT-3 undo, PT-5 axis lock (a mostly-vertical drag scrolls). Suite:
`plan tile` tests under `test/features/meal_planning/presentation/`.
