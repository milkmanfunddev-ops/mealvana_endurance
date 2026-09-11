# Design SSOT — Component: Meal Image Mosaic

**Status: PROPOSED v1.1 (Lee, 2026-09-08; icon state 2026-09-11) — authored app-side, awaiting
Xuan.** Drafted for the meal-library imagery pass (`docs/meal-images/README.md`). Not yet on a
spec-review page; no reference rendering. v1.1 adds MIM-9 and amends MIM-1, MIM-2 and MIM-5 to
match: a host may put the meal's icon in the picture's place.

**Component contract** — the picture of a meal, at any size. It renders whichever rung of the
image fallback ladder that meal reached: a single real photograph, or a mosaic of 2–4 photographs
of the meal's principal ingredients, or nothing of its own (the host's icon, MIM-9).

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
  rendered identically to `dish`. `none` → the host's fallback (MIM-9), or a zero-size box when
  the host gives none.
* **MIM-2 — `none` draws nothing of its own.** No placeholder glyph, no coloured panel, no meal
  name in a box (Lee, 2026-09-08). The component never invents a stand-in; the only thing that
  may stand in the picture's place is the host's fallback (MIM-9). v1.1 supersedes the 09-08
  wording "no icon": meal-imagery ticket 08 (Lee, 2026-09-10) asks for the icon to stay, at the
  picture's footprint.
* **MIM-3 — tile count drives the grid.** 2 tiles → two equal columns. 3 → one full-height
  column left, two stacked right. 4 → 2×2. Never more than 4; never a ragged final row.
* **MIM-4 — every tile is square-cropped and centred** (`BoxFit.cover`). Tiles are equal size
  within a mosaic. The component never letterboxes and never distorts.
* **MIM-5 — a failed image collapses its cell, it does not error.** If one tile of a mosaic
  fails to load, the remaining tiles re-flow to the next legal grid for their count. If all
  fail, the result is MIM-2: the host's icon where it gave one, never a blank slot.
* **MIM-6 — attribution travels with the image.** Where the surface shows credit, it shows it
  for *every* distinct tile shown, not just the first. Unsplash credit must name the
  photographer **and** Unsplash, both linked; Pexels must link back. See
  `docs/meal-images/README.md` §Licensing.
* **MIM-7 — the hairline is the only separator.** Tiles are divided by a 1px surface-coloured
  gap, never by a border, shadow or rounded inner corner. Outer radius is the host's.
* **MIM-8 — no motion.** No cross-fade between tiles, no Ken Burns, no shimmer beyond the
  host's standard loading treatment.
* **MIM-9 — the icon state takes the picture's place.** Direction from meal-imagery ticket 08
  (Lee): same footprint as a picture, a first-class state, no "missing image" affordance, token
  registry only. The specific treatment below is proposed app-side (2026-09-11) and not yet
  seen by Lee or Xuan. A fifth of the
  library has no honest picture, permanently, so a list will often mix pictures and icons. A
  host that keeps a leading element in its rows (the meal card) passes the meal's icon as the
  fallback, and the component draws it in the picture's own box and corners: same size, same
  outer radius, same position. Rows stay aligned; the list does not go ragged. The icon is a
  state, not an absence:
  * the meal's glyph on a flat tint of the host's own ink, the glyph at the host's secondary
    text weight. It borrows no accent token, because none of their meanings covers "this Meal
    has no picture";
  * no "missing image" or broken-picture glyph, no meal name, no border, no shimmer. Nothing
    about it may suggest that something failed to load;
  * the same state appears when every photograph failed to load (MIM-5), so an athlete on a
    bad connection sees the designed state rather than a blank square.

  The detail hero passes no fallback: a meal with no picture has no hero.

## Sizes

One component, three call sites: card thumbnail (~56–72px), picker/rail tile (~120px), and
detail hero (full width, 16:10). The grid is identical at every size — a 2×2 of ingredients is
still legible at 56px because each cell is a single subject on a plain ground, which is why the
bank is curated for subject-only photography.
