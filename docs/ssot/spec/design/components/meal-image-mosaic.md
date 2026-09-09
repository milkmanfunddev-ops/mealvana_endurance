# Design SSOT — Component: Meal Image Mosaic

**Status: PROPOSED v1 (Lee, 2026-09-08) — awaiting Xuan.** Drafted for the meal-library imagery
pass (`docs/meal-images/README.md`). Not yet on a spec-review page; no reference rendering.

**Component contract** — the picture of a meal, at any size. It renders whichever rung of the
image fallback ladder that meal reached: a single real photograph, or a mosaic of 2–4 photographs
of the meal's principal ingredients, or nothing.

**Why a mosaic exists at all:** most of `meal_library` is *assemblies* — "Barley, chard & pinto
bean bowl" — of which no photograph exists anywhere. Rather than ship a shared generic
"grain bowl" stock photo across hundreds of rows, a meal is depicted by its own ingredients. Tiles
repeat between meals; the *combination* does not.

**Tokens:** [`../tokens.md`](../tokens.md) — surface and hairline only. This component introduces
no colour of its own and tints no photograph.

**Data authority:** `meal_library.image_mode` and `image_tiles` as the server sends them
(`docs/meal-images/README.md`). This file contracts presentation only; it never decides which
image a meal gets, never reorders tiles, and never substitutes one.

## Contracts

* **MIM-1 — the mode decides the form.** `dish` → one photograph, full bleed. `mosaic` → an
  even grid of exactly the tiles given, in the order given. `tile` → one ingredient photograph,
  rendered identically to `dish`. `none` → a zero-size box.
* **MIM-2 — `none` shows nothing.** No icon, no placeholder glyph, no coloured panel, no meal
  name in a box (Lee, 2026-09-08). An absent picture is absent.
* **MIM-3 — tile count drives the grid.** 2 tiles → two equal columns. 3 → one full-height
  column left, two stacked right. 4 → 2×2. Never more than 4; never a ragged final row.
* **MIM-4 — every tile is square-cropped and centred** (`BoxFit.cover`). Tiles are equal size
  within a mosaic. The component never letterboxes and never distorts.
* **MIM-5 — a failed image collapses its cell, it does not error.** If one tile of a mosaic
  fails to load, the remaining tiles re-flow to the next legal grid for their count. If all
  fail, the result is MIM-2.
* **MIM-6 — attribution travels with the image.** Where the surface shows credit, it shows it
  for *every* distinct tile shown, not just the first. Unsplash credit must name the
  photographer **and** Unsplash, both linked; Pexels must link back. See
  `docs/meal-images/README.md` §Licensing.
* **MIM-7 — the hairline is the only separator.** Tiles are divided by a 1px surface-coloured
  gap, never by a border, shadow or rounded inner corner. Outer radius is the host's.
* **MIM-8 — no motion.** No cross-fade between tiles, no Ken Burns, no shimmer beyond the
  host's standard loading treatment.

## Sizes

One component, three call sites: card thumbnail (~56–72px), picker/rail tile (~120px), and
detail hero (full width, 16:10). The grid is identical at every size — a 2×2 of ingredients is
still legible at 56px because each cell is a single subject on a plain ground, which is why the
bank is curated for subject-only photography.
