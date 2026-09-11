# Design SSOT — Component: Macro Pill Row

**Status: PROPOSED v1 (Lee, 2026-09-03) — awaiting Xuan.** Drafted for the Vana chatbot update
(`docs/new_mealplanning/vana-chatbot-update-plan.md` §4.2, Phase 1 item 4). Not yet on a
spec-review page; no reference rendering — the prototype shows macros as plain text facts and
this component is the first pill form.
**Component contract** — one compact horizontal strip of small pills stating what a meal carries:
`kcal · carbs · protein · fat`. A **fact strip**, not a status: it never judges the numbers, never
compares them to a target, and never colours by meaning. **Which meal, and whether the strip shows
at all**, is the surface's (`show_macros` setting; plan §4.2).
**Tokens:** [`../tokens.md`](../tokens.md) — neutral text-on-surface only (see *Token usage*).
**Numbers authority:** the `MealRef` / `PlanMeal` wire records (`contracts.ts`: `kcal`, `carbsG`,
`proteinG`, `fatG`) as the server sends them. This file contracts presentation only.

## State model

```
kcal      : int | none          # server value
carbs     : g   | none          # server value
protein   : g   | none          # server value
fat       : g   | none          # server value — optional on every surface
compact   ∈ { true, false }     # the host's choice: tile / plan-bar use vs card use
```

The row has no state of its own — no selection, no expansion, no gesture. It is inert.

## Pills

| Pill | Rendered as | Present when |
|---|---|---|
| kcal | `412 kcal` | `kcal` present |
| carbs | `58g C` | `carbs` present |
| protein | `31g P` | `protein` present |
| fat | `12g F` | `fat` present |

- **MP-1 · One short form, everywhere.** Grams carry a single capital-letter unit label after the
  figure — `C` · `P` · `F` — and kcal is spelled out (`kcal`). Never `58g carbs` on one surface and
  `58g C` on another; never `C: 58g`; never a unit without its figure. Order is fixed:
  kcal · carbs · protein · fat.
- **MP-2 · A missing macro drops its pill — never renders `0`.** `carbs = none` means the server
  did not state carbs; the pill is absent. A real `0g` (the server said zero) renders `0g C`.
  null ≠ 0 (fuel-stat F-1's rule, carried here).
- **MP-3 · The row renders nothing when kcal AND carbs are both none.** Protein or fat alone is
  not a macro strip worth a row; the host gets an empty box (zero size, no padding) and lays out
  as if the strip were not there.
- **MP-4 · No fiber, no sugar, no sodium.** `MealRef` does not carry them and this component does
  not synthesise or estimate them. Adding a pill is a spec change, not a widget option.
- **MP-5 · Rounding is presentational.** kcal renders as the server's integer; grams round to the
  whole gram for display. The component performs **no arithmetic** — no per-serving scaling, no
  plan totals, no summing across meals. A surface wanting a day or plan total must get it from the
  server, or not show it.
- **MP-6 · "At least" lives in the surrounding copy, not in the pills.** The minimum-target framing
  for a day belongs to the line above the plan (`mpTodayTargetLine`, already in
  `content_defaults.json`), which names the athlete's daily target. The pills state what a meal
  carries and nothing more — no `≥`, no `of N`, no target marker.

## Layout

- **MP-L1 · One line first.** The four pills fit one line at the narrowest supported width
  (iPhone SE, 320 pt) inside a meal card's text column; that is why MP-1's short form is short.
  Wrapping is permitted only as a last resort (a very narrow host) and wraps whole pills — a pill
  never breaks internally.
- **MP-L2 · `compact`** — smaller type and tighter padding for a 184 pt plan-bar tile or a plan
  tile's meta line. Same pills, same order, same rules; only the scale changes.
- **MP-L3 · Position on a host is the host's.** On `MealCard` and `PlanTile` the row sits **below**
  the tag strip (Yours · No recipe · Batch · prep minutes), and kcal moves out of the tag strip into
  the row so it is never shown twice. On a plan-bar tile it sits between the name and the
  chip/stepper row. On the Review sheet it sits under the slot chip of each meal row.

## Token usage

Neutral only: the pill fill is the surface's text colour at low alpha (`cream` on the dark ground,
`blackberry` on the light one), the text the same colour at reduced alpha. **No `orange`, no
`electrolyte`, no `dragonfruit`, no `yolk`** — the strip signifies nothing (tokens.md *meaning
contracts*): kcal is not daily-intake accent, a macro is not in or out of any band. A pill that
takes a meaning-bound colour fails conformance. Both themes.

## Traceability

Every figure maps to a named wire field (`kcal`, `carbsG`, `proteinG`, `fatG`) on the `MealRef` or
`PlanMeal` the host renders. This component invents no arithmetic, no threshold, and no colour
meaning.

## Conformance (design vectors)

- **Golden (L1):** full four-pill row and compact three-pill row (no fat), light and dark, at SE
  width inside a `MealCard`; a `PlanTile` with macros on; an expanded plan bar tile. The
  meal-planning goldens (`test/features/meal_planning/presentation/widget_goldens_test.dart`)
  carry these once the fixtures carry macros.
- **Widget (L2):** MP-1 — all four pills render with the exact short-form strings; MP-2 — a null
  protein drops exactly that pill, a real `0` renders `0g`; MP-3 — kcal and carbs both null renders
  no pill and no padding; both themes build without exception.
  `test/shared/widgets/kyle_design/macro_pill_row_test.dart`.
- **A golden may only be regenerated after this spec changes** — never to make a red test pass.

## Open for ratification

- **Q-MP1** — the letter form `58g C` vs a spelled-out `58g carbs` that would wrap on SE. Drafted
  as the letter form (MP-1) so the row holds one line; Xuan to confirm or rule the long form with
  a two-line layout.
- **Q-MP2** — whether fat should show by default on the plan bar's compact tile, or only kcal and
  carbs there. Drafted as all-present pills everywhere.
