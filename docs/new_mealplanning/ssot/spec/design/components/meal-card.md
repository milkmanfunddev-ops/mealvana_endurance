# Design SSOT — Component: Meal Card

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.** Extracted from `MealCard` (prototype
`widgets.tsx`) and the Dart `MealCard`; used by the catalog, the rule part, the swap picker and day guidance.

## State model

```
state     ∈ { default, selected, excluded, in-plan, yours }
excludedBy: allergen name | null        # the athlete's allergy that hides it (catalog browse only)
inBatch   : servings | 0
showMacros: bool                        # the show_macros setting, passed by the host
```

## Contracts

| # | Contract |
|---|---|
| MC-1 | **Excluded cards are visible but inert** on the Meals tab: no tick, tag `<allergen>`, subtitle "Hidden by your allergy · <swaps or 'no swap listed'>". They never appear in a picker (MS-1) — the catalog shows them so the athlete understands why. |
| MC-2 | **One tag slot, priority order:** excluded → "In batch ×N" → context tone (Carb-load / Race-eve in `orange`; Recovery / Rest day / Pre-session neutral) → "Yours" (saved) → none. |
| MC-3 | **The subtitle is the catalog's `why`**, verbatim; the second line is `attributionShort` in the teal link colour + "No recipe" (assembly, `orange`) + "Batch" + prep ("no-cook" when 0 min). |
| MC-4 | **Macros only when `showMacros`**, as the `MacroPillRow` (kcal · C · P · F) — never when excluded. |
| MC-5 | **A card with `onToggle` is a button (`aria-pressed`)**; without it, a static row. |

## Conformance

Goldens: default, selected, excluded, in-batch, yours, with macros. Widget: MC-1 negative (excluded card
ignores taps), MC-2 priority. Suite: `vana_part_renderer_test.dart`, `widget_goldens_test.dart`.
