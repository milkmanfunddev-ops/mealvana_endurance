# Design SSOT — Component: Dish Photo

**Status: PROPOSED v1 (Lee, 2026-09-17) — authored app-side, awaiting Xuan.** Written from the
meal-imagery build (ADR 0003, `.scratch/meal-imagery-dish-or-nothing/spec.md`, tickets 01–06), which
shipped this presentation before it had a component file. No reference rendering yet.

**Component contract** — the one photograph of a dish, or nothing. A Meal shows a single Dish photo
or no picture at all: no placeholder box, no icon, no reserved space. Three forms share one
rule: a **thumb** in a row, a **hero** above a recipe, and a **credit line** under a hero.

**Relation to Meal Image Mosaic:** `meal-image-mosaic.md` stays valid for the kept Mosaic
capability, and its MIM-2 ("`none` draws nothing") is the same rule stated there. Meal surfaces no
longer build a Mosaic (ADR 0003); they build this.

**Tokens:** [`../tokens.md`](../tokens.md) — surface for the holding fill, ink and accent for the
credit line. This component introduces no colour of its own and tints no photograph.

**Data authority:** `meal_library.photo_url`, `photo_credit` and `photo_credit_url` as the server
sends them (ADR 0003). This file contracts presentation only: it never decides which photograph a
Meal gets, never rewords a credit, and never substitutes a picture.

## Contracts

- **DP-1 — absent draws nothing.** With no address, every form draws a zero-size box: no
  placeholder, no icon, no border, and no gap after it. A row without a photo starts at its name,
  and a list mixing rows with and without photos keeps its names and macros aligned.
- **DP-2 — a failed load collapses the same way.** A photograph that fails to load (a hotlink that
  has gone, a rate-limited host) collapses to exactly DP-1 and draws no broken-image glyph. A
  different address gets its own chance; the same address stays collapsed across rebuilds.
- **DP-3 — loading holds still.** While a photograph decodes, a plain surface fill holds its space.
  No shimmer, no spinner, no motion.
- **DP-4 — thumb.** A square of a given edge, filled edge to edge (cover). Corner radius defaults to
  a quarter of the edge. The gap after it is drawn only when the photograph is.
- **DP-5 — hero.** Full width at 16:10 (cover), corner radius 14. It is the shape a Tester's crop is
  locked to, so a preview shows exactly what athletes see.
- **DP-6 — credit line.** At most one line, and only when the photo carries a credit; a photograph
  with none shows no line. The wording is shown as stored, never composed here. When the credit
  link is an http(s) address with a host, the line is tappable and opens that page (the
  photograph's own page, not the photographer's profile); otherwise it is plain text.
- **DP-7 — credit as semantics.** Where there is no room for a line (thumbs, heroes), the credit is
  the image's screen-reader label. An uncredited photograph is left unlabelled rather than
  announced as an empty label.

## Implementation

`lib/shared/widgets/kyle_design/data/dish_photo.dart` — `DishPhotoThumb`, `DishPhotoHero`,
`DishPhotoCreditLine`. Meal surfaces compose them through
`lib/features/meal_planning/presentation/widgets/meal_photo_view.dart`, which only unpacks a
`MealPhoto` into the three fields.
