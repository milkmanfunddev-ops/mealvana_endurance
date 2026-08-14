# Design SSOT — Component: Energy Summary Card

**Status: RATIFIED v1 (Xuan, 2026-08-14).**
**Component contract** for the dashboard's summary card — **one component with three faces**, not
three cards. The face follows the active filter lens; the expansion state is the card's own.
**Tokens:** [`../tokens.md`](../tokens.md). **Numbers authority:**
`spec/daily-macros/intraday-display.md` (so-far arithmetic, band copy) and the engine outputs —
this file contracts *presentation*, never values.
**Reference rendering:** `prototypes/macro-dashboard/index.html` (all six faces verified 2026-08-14).

## State model

```
face      ∈ { ALL, WORKOUT, MEALS }     # driven by the surface's filter — never self-chosen
expanded  ∈ { true, false }             # the card's own state
```

**P-1 · Expansion persists.** `expanded` survives face switches (verified in the reference
rendering: Meals-expanded → Workout arrives expanded) **and** survives any timeline/card state
change elsewhere on the surface (surface rule S-4 — a workout swipe must not collapse this card;
reference-rendering defect W-8, do not encode).

## Faces — face × expansion × contents

| Face | Collapsed (the orienting number) | Expanded (the working detail) |
|---|---|---|
| `ALL` | `NET BALANCE` · net kcal · **band copy** | `NET ENERGY BALANCE` · the equation `eaten − burned = net` · `Eaten x / target` · `kcal to target` · Full Breakdown |
| `WORKOUT` | `TODAY'S WORKOUT` · `done · planned` kcal | `ACTIVE ENERGY` · done/planned + progress bar + one row per session (time · detail · kcal, planned rows dimmed) + `Projected by day's end` + Full Breakdown |
| `MEALS` | `DAILY BUDGET` · target kcal · `C · P · F` targets | `INTAKE TODAY` · `eaten / target` + three macro bars (logged vs target, per-macro accent) + Full Breakdown |

**P-2 · Collapsed and expanded may show *different quantities*, by design** — collapsed is the
single most decision-relevant number for that lens (net; done·planned; the budget), expanded is the
progress detail. This asymmetry is deliberate (notably MEALS: budget collapsed, intake expanded);
a future editor "fixing" the collapsed face to match the expanded one is regressing a decision.

**P-3 · Traceability per quantity:** net, eaten, burned-so-far, projected, remaining ("to
target" = target − logged) and the macro pairs all resolve per `intraday-display.md` §§1–3; the
band copy string comes from §2's registers verbatim. This card invents no arithmetic.

## Gestures

| # | Gesture | Contract |
|---|---|---|
| E1 | Tap chevron (or header) | Toggles `expanded`; animates in place; never navigates |
| E2 | Tap `Full Breakdown` | Opens the face's sheet (Today's Energy / Active Energy / Today's Fuel). The sheets are outside this contract |
| E3 | Face transition | Content crossfades/swaps in place; the card never unmounts (P-1 depends on it) |

## Conformance (design vectors)

- **Golden (L1):** six images — 3 faces × 2 expansion states — at token-resolved colors, from the
  canonical mock day (so the numbers in the goldens are themselves traced).
- **Widget/Patrol (L2):** E1 toggle; P-1 both ways (persistence across face switch AND across a
  workout-card swipe); P-3 spot-check (band copy string matches the §2 register for the mock net).
- **A golden may only be regenerated after this spec changes** — never to make a red test pass.
  Regeneration commits cite the spec change.

## Number-color contract (Q-D3 RULED, Xuan, 2026-08-14)

`electrolyte`'s meaning widened to the **burn/activity side** (see `tokens.md`), so the reference
rendering's colors are now the contract: **burn-side figures** (done, burned-so-far, projected
burn) render in `electrolyte`; **intake-side figures** (eaten, net balance, budget kcal) render in
`orange`. Macro bars keep their per-macro accents. A burn number in orange or an intake number in
electrolyte fails conformance — the hue *is* the axis label.
