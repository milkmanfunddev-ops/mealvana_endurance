# Design SSOT — Component: Meal Picker

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Extracted from the prototype
(`components/vana/widgets.tsx` `MealPicker` / `MealTile`) and the Dart `MealPickerCarousel`.
**Component contract** — the `meal_picker` part: one meal type, up to three meals, each tappable. **Which
meals** is the selection SSOT's (`../../selection/meal-suggestion.md` SG-1); **what a tap writes** is here.
**Numbers authority:** `MealRef` fields; the card invents no arithmetic.

## State model

```
meals      : MealRef[≤3]                      # from the part — never edited client-side
ticked     : {id}  = meals ∩ plan keys        # DERIVED from the draft plan, not stored on the part
pending    : {id}                             # a tap whose action has not returned
title      : from the part ("Three dinners to start", "Tap any — they go straight into your plan")
```

## Contracts

| # | Contract |
|---|---|
| MP-1 | **Tap = pick, untap = unpick.** Tapping a tile calls `pick_meals {meals:[ref], servings: 4, conversationId}`; tapping a ticked tile calls `unpick_meal`. There is no Add button, no confirm, no servings prompt — the plan bar is where servings change. |
| MP-2 | **Tick state is the draft, not memory.** A tile is ticked iff its `libraryMealId ?? id` is in the conversation draft — so a meal removed from the plan bar unticks in every picker that shows it, and a meal picked in one picker is ticked in a later one. |
| MP-3 | **A tile shows name · one-line why (2 lines max) · badges (No recipe · Batch · context) · kcal.** Attribution, macros beyond kcal and the detail live on the Meals tab (the tile is 188 px; pills would wrap — `macro-pill-row.md` note). |
| MP-4 | **"Other options" is on the card and among the chips** and sends `Give me other <type> options` — the server guarantees no repeat (SG-2). |
| MP-5 | **The header states plan membership:** "N in your plan" when any tile is ticked, else "tap to add". |
| MP-6 | **An empty picker renders the dashed "Nothing else fits those filters — try different words."** |

## Gestures

| # | Gesture | Write |
|---|---|---|
| MP-G1 | tap tile | `pick_meals` / `unpick_meal` → the returned `batch` replaces the draft; pending spinner until then |
| MP-G2 | horizontal scroll | none (snap per tile) |

## Conformance

Goldens: three-tile picker (one ticked), empty picker. Widget: MP-1 write test (tap → `pick_meals` with servings
4 and the conversation scope; second tap → `unpick_meal`); MP-2 derivation (a plan change re-ticks). Suite:
`vana_part_renderer_test.dart` + the plan-build Patrol flow.
