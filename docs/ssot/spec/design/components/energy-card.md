# Design SSOT — Component: Energy Summary Card

**Status: RATIFIED v1 (Xuan, 2026-08-14) + v2 amendment — the LOAD face — RULED (Xuan,
2026-09-24, carb-loading interview, post-ratification addition; intake
`2026-09-24-carb-loading-amend-b-energy-card-v2-load-face.md`). See §LOAD-face amendment below;
conformance manifests extend when the carb-loading bundle ships.**
**Component contract** for the dashboard's summary card — **one component with three faces**, not
three cards. The face follows the active filter lens; the expansion state is the card's own.
**Tokens:** [`../tokens.md`](../tokens.md). **Numbers authority:**
`spec/daily-macros/intraday-display.md` (so-far arithmetic, band copy) and the engine outputs —
this file contracts *presentation*, never values.
**Reference rendering:** [`../renderings/macro-dashboard@v1.html`](../renderings/macro-dashboard@v1.html)
(ratified Xuan 2026-08-25; frozen copy of `prototypes/macro-dashboard/index.html` @ `5a22ca8`; all six faces verified 2026-08-14).

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

## LOAD-face amendment — RULED (Xuan, 2026-09-24, carb-loading interview)

Amends the v1 contract on four clauses; everything else stands unchanged.

1. **Fourth face:** `face ∈ { ALL, WORKOUT, MEALS, LOAD }`. `LOAD` is chosen by the **surface**
   (the viewed day falls inside a carb-loading plan the athlete created — data, not a setting,
   never the filter lens) and **replaces the All-lens face** on loading days; `WORKOUT`/`MEALS`
   stay one tap away, untouched.
2. **E1 suppressed on LOAD** — the face is collapsed-only: one row, continuous 26 px loader bar
   (⅔) + pace words (⅓, value over label). Anatomy and numbers:
   `spec/fueling/carb-loading.md` CL-7..CL-9 + §2a copy register; glow/material tokens await the
   desk ruling (amendment c).
3. **P-1 becomes remember-not-clear across LOAD:** `expanded` survives crossing a face with no
   expansion — ALL-expanded → LOAD → WORKOUT arrives expanded.
4. **E2 on LOAD** opens the **carb-loading breakdown page** (read-only overlay; prototype v17:
   protocol chips navigate protocol days, back chevron restores the origin day) — ruled into
   release-1 scope at the interview (Q-CL6), replacing the net-balance-pager stub.

Conformance additions (staged with the carb-loading bundle; rewritten per Q-D9): L1 goldens for
the LOAD face — collapsed AND expanded × today / future / past; L2 — face selection is
data-driven (no LOAD off-plan), E1 toggles on LOAD, P-1 plain persistence across LOAD, E2
destination from the expanded face, §2a copy strings verbatim incl. `N g to go` (clamp-at-0
case pinned) and `pace N g by now`.

## Number-color contract (Q-D3 RULED, Xuan, 2026-08-14)

`electrolyte`'s meaning widened to the **burn/activity side** (see `tokens.md`), so the reference
rendering's colors are now the contract: **burn-side figures** (done, burned-so-far, projected
burn) render in `electrolyte`; **intake-side figures** (eaten, net balance, budget kcal) render in
`orange`. Macro bars keep their per-macro accents. A burn number in orange or an intake number in
electrolyte fails conformance — the hue *is* the axis label.
