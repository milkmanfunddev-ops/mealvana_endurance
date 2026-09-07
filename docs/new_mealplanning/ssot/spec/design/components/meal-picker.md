# Design SSOT — Component: Meal Picker

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** prototype `components/vana/widgets.tsx` (`MealPicker` / `MealTile`).
**Code:** Dart `MealPickerCarousel`.
**Scope:** numbers authority `MealRef` fields — the card invents no arithmetic.

**What this file owns:** the `meal_picker` part's component contract — one meal type, up to three meals, each
tappable, and **what a tap writes**. **Which meals** are offered is the selection SSOT's
(`../../selection/meal-suggestion.md` SG-1), not this file's.

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
| MP-1 | **Tap the card body opens the meal's detail** (recipe, ingredients, cooking mode); **the tick is what picks it.** Tapping the tick (`meal_planning.picker_tick_<id>`) on an unticked tile calls `pick_meals {meals:[ref], servings: 4, conversationId}`; tapping a ticked tile's tick calls `unpick_meal`. **Revised 2026-09-04** — the whole card used to pick (D-020's sibling change, same 2026-09-03 evening: `MealPickerCarousel`'s `onOpen`/`onPick` split). There is no Add button, no confirm, no servings prompt — the plan bar is where servings change. A picked tile also shows a direct swap button (top-right) when the picker was given `onSwap`. |
| MP-2 | **Tick state is the draft, not memory.** A tile is ticked iff its `libraryMealId ?? id` is in the conversation draft — so a meal removed from the plan bar unticks in every picker that shows it, and a meal picked in one picker is ticked in a later one. |
| MP-3 | **A tile shows name · one-line why (2 lines max) · badges (No recipe · Batch · context) · kcal.** Attribution, macros beyond kcal and the detail live on the Meals tab (the tile is 188 px; pills would wrap — `macro-pill-row.md` note). |
| MP-4 | **"Other options" is on the card and among the chips** and sends `Give me other <type> options` — the server guarantees no repeat (SG-2). |
| MP-5 | **The header states plan membership:** "N in your plan" when any tile is ticked, else "tap to add". |
| MP-6 | **An empty picker renders the dashed "Nothing else fits those filters — try different words."** |

## Gestures

| # | Gesture | Write |
|---|---|---|
| MP-G1 | tap the tick | `pick_meals` / `unpick_meal` → the returned `batch` replaces the draft; pending spinner until then |
| MP-G2 | tap the card body | opens the meal detail screen (`onOpen`); no write |
| MP-G3 | horizontal scroll | none (snap per tile) |

## Conformance

Goldens: three-tile picker (one ticked), empty picker. Widget: MP-1 write test (tick tap → `pick_meals` with
servings 4 and the conversation scope; second tick tap → `unpick_meal`; card-body tap → `onOpen`, no write);
MP-2 derivation (a plan change re-ticks). Suite: `vana_part_renderer_test.dart` + the plan-build Patrol flow.
