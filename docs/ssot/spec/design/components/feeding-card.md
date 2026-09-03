# Design SSOT — Component: Feeding Card

**Status: RATIFIED v1 (Xuan, 2026-08-26).** Extracted 2026-08-26 from the reference rendering; reviewed on the spec-review page (10/10 checked; FC-2 ruled delivered-only and folded pre-ratification).
**Component contract** — one pre-workout feeding (a tier: meal · snack · top-off) with its window
label, its done/aim figures and its food rows. **Which feedings exist**, and what a row change does
to the summary stats, is the surface's
([`../surfaces/pre-workout-before-card.md`](../surfaces/pre-workout-before-card.md)).
**Tokens:** [`../tokens.md`](../tokens.md). **Numbers authority:** `spec/fueling/pre-workout-carbs.md`
v2 (`tiers[]`, shares, `LIGHT_MEAL_G_PER_KG`, `TIER_MEAL_MIN`, `TIER_TOPOFF_MAX`),
`pre-workout-hydration.md` v6 *Tier integration*, `pre-workout-food-composition.md` v3 (which foods).
**Reference rendering:** [`../renderings/pre-workout@v2.html`](../renderings/pre-workout@v2.html)
(ratified Xuan 2026-08-26).

## State model

```
tier      ∈ { MEAL, SNACK, TOP_OFF }        # from the engine's tiers[] — the card never invents one
expanded  ∈ { true, false }                 # the card's own state
carbs     : { delivered, aim } | none       # none on the fasted path
fluid     : oz | none                       # none when this tier carries no fluid
```

## Tier × title × window label × what it carries

| Tier | Title (default) | Window label | Fluid? |
|---|---|---|---|
| `MEAL` | **Pre-Run Meal** — always, never renamed | "FINISH BY 2H OUT" (+ "(15 MIN WINDOW)" when the plan's lead is 2 h–2 h 15) | the ≥ 2 h fluid dose sits here |
| `SNACK` | **Light Meal** iff carb aim ≥ `LIGHT_MEAL_G_PER_KG·BW`, else **Pre-Workout Snack** | "2H TO 30 MIN OUT" (or "NOW UNTIL 30 MIN OUT" when it is the first extant feeding) | only on a `dark` hydration answer, or as the whole fluid dose on a 30 min–2 h plan |
| `TOP_OFF` | **Top-Off** | "LAST 30 MIN" (or "NOW UNTIL THE START" / "NOW") | only as the whole fluid dose on a < 30 min plan |

- **FC-1 · The name comes from the engine, per a threshold — never hardcoded per card.** A `SNACK`
  whose carb aim reaches `LIGHT_MEAL_G_PER_KG·BW` (carbs v2) renders "Light Meal"; below it,
  "Pre-Workout Snack". The `MEAL` tier is always "Pre-Run Meal". A "snack" larger than the meal a
  slightly-earlier athlete gets is a labelling error, not a portion error (carbs `renderAs`).

## Header figures

- **FC-2 · The header shows DELIVERED only — RULED (Xuan, 2026-08-26, review flag).** "52g" with
  the label "carbs": the number is what the current foods deliver and moves with the steppers. **No
  aim in the header, and no "DONE / AIM" label** — "done" was the wrong word (the figure is what
  the plan currently carries, not what was consumed). A fluid tier still shows its fluid oz
  ("16oz · fluids"). The tier aim (`tiers[].carbsG`) stays engine data; after this ruling it is
  **not visible anywhere on the card** — the summary band is the only visible range. Supersedes
  the earlier delivered/aim pair.
- **FC-3 · The ±12.5 % per-tier match window (`rangeLowG/HighG`) is NOT shown to the athlete** — it
  is the food selector's internal tolerance (brief §1). The card shows the aim, never the tolerance.
- **FC-4 · A zero-carb feeding still renders if it carries fluid** — the start-line Top-Off shows
  "0g / 6oz", the card kept (carbs †; surface B-2). On the **fasted** path the card carries no carb
  figure at all (`carbs = none`), only fluid if any.

## Food rows

- **FC-5 · Each food row shows name, its own macros as an *observation* (e.g. "52g carbs · 120mg
  sodium"), and a ± stepper** (step and cap are the row's, e.g. 0.5 for chews). Sodium on a row is
  reported, never a target (sodium v3; fuel-stat F-2).
- **FC-6 · The hydration-check row is the first row of the SNACK card** on ≥ 2 h plans — it is the
  [`hydration-check`](./hydration-check.md) component, not a food. On a `dark`/`not-yet` answer the
  card gains a tagged "Water (cups) · added by hydration check" row (hydration-check state table).
- **FC-7 · "+ Add Food"** appends a food row (expanded only). The composition rules for what may be
  added are `pre-workout-food-composition.md` v3 — not restated here.

## Gestures

| # | Gesture | Contract |
|---|---|---|
| FC-G1 | Tap the card header | Toggles `expanded`; animates in place; never navigates |
| FC-G2 | ± on a food row | Changes that row's quantity (clamped to the row's cap); **emits a delivered-total change** — the header `delivered` and the surface's fuel-stat re-total (surface B-1). Does **not** move the aim |
| FC-G3 | Delivered-change emission | The card emits; it never repaints the summary itself. What re-totals the stat is the surface |

**The steppers' at-rest look, disc size, row layout are screenshot-held** (port loop) — only the
*data write* (FC-G2 → delivered) and the naming/figure contracts are here.

## Token usage

Accents (title, chip, stepper discs) render in `orange`/`cream`; the header `delivered` carb figure
renders in `electrolyte` — permitted by **Q-D8 (RULED Xuan 2026-08-26, option a)**, which widened
`electrolyte` to the per-workout fuel side. `tokens.md`.

## Conformance (design vectors)

- **Golden (L1):** MEAL (expanded, with hydration-check row + food rows), SNACK named "Pre-Workout
  Snack" and (separate) "Light Meal", TOP_OFF, a zero-carb-with-fluid card, a fasted card (no carb
  figure) — at token-resolved colors from the 63 kg mock.
- **Widget (L2):** FC-1 naming threshold (snack aim just under/over `LIGHT_MEAL_G_PER_KG·BW` →
  label flips); FC-2 header shows the delivered figure only — no aim, no DONE/AIM node (negative);
  FC-G2 write test (stepping
  a row changes delivered only, aim unchanged, emission fires); FC-6 hydration-check row present on
  ≥ 2 h SNACK, absent otherwise.
- **A golden may only be regenerated after this spec changes** — never to make a red test pass.

---

## AMENDMENT A1 — fasted path retired (staged; Xuan, 2026-09-03)
**Authority:** RULING-DESK 2026-09-03 option 2 on `intake/2026-08-31-fasted-food-suppression-mechanism.md`
(fasted is no longer a product state; class-c change staged in the food-recommendation bundle).
**Effective at that bundle's implementation — the ratified text above stands until then.**
- Inputs: `carbs` loses the `| none` arm and its comment "none on the fasted path" — carbs is
  always `{ delivered, aim }`. (The zero-carb case remains FC-4's *targeted* `[0,0]` — carbs † —
  not a `none`.)
- **FC-4** drops its second sentence ("On the **fasted** path …"); the zero-carb-with-fluid
  rendering rule is unchanged.
- Conformance golden list: "a fasted card (no carb figure)" **retires**; the app's mirror and the
  design manifest drop that golden in the same commit, message citing this amendment.
