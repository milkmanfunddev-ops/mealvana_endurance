# Meal images: Mosaics are composed on the client

Status: accepted (2026-09-08, recorded 2026-09-11)

A Mosaic is two to four Tiles drawn into one frame by the app, at render time
(`MealImageMosaic`, `lib/shared/widgets/kyle_design/data/meal_image_mosaic.dart`). The server
stores only the list of Tiles in `meal_library.image_tiles`. No composed image exists in storage.

We chose this because a pre-rendered Mosaic would be a stored copy of every photograph in it, and
most grids contain a photograph we are not allowed to copy. On 2026-09-11, 428 of the 512 Meals
drawn as a grid or single Tile include at least one Unsplash or Pexels Tile, and those providers
require hotlinking ([0001](0001-meal-images-mirroring-is-decided-per-provider.md)). Pre-rendering
would have limited Mosaics to archive Tiles. Those are 269 of the 362 Tiles in the bank, but the
other 93 account for 778 of the 1,385 Tile placements across Meals.

Composing on the client also keeps three contracts that a single file cannot:

- A Tile that fails to load drops out and the grid re-flows to the next legal layout (MIM-5). A
  pre-rendered grid either loads whole or not at all.
- Credits are per Tile (MIM-6): a picture credits each distinct photograph it shows.
- Replacing one Tile in the bank repairs every Meal that uses it on the next fetch. `white-rice`
  appears in 139 grids; pre-rendered, a better rice photograph would mean re-rendering and
  re-uploading 139 files.

## Consequences

- **The judge has to draw the grid a second time.** Pass 8 and pass 10 judge a composed picture,
  so the pipeline has its own compositor (`scripts/meal-images/lib/compose-mosaic.mjs`). Nothing
  but tests keeps the two drawings the same. Both sides assert against one description,
  `scripts/meal-images/lib/mosaic-geometry.json`, and a change to the grid invalidates every
  stored Verdict on a `mosaic` or `tile` Meal. The re-measure protocol is in
  `docs/meal-images/README.md` under "Compositor parity".
- **Up to four image requests per card instead of one.** On a slow connection a grid loads cell by
  cell. Tiles are shared across Meals, so in a scrolling list many of those requests are
  answered from the image cache.

## What this rules out

- A single URL for a Meal's picture. Anything outside the Flutter app that wants to show one (a
  share card, an email, a push notification image, an Open Graph tag on a web page) has to either
  reimplement the grid or show the Meal's Dish photo only.
- CDN-side transforms on the whole picture (one resize, one crop, one blur-hash). Each applies per
  Tile.
- Letting a grid include a provider's photograph in any form that leaves their CDN, such as an
  exported or cached composite written to our storage.

If pre-rendering is ever wanted, it becomes possible only for grids made entirely of archive
Tiles, and each composite then carries the attribution and ShareAlike terms of the Tiles inside
it.
