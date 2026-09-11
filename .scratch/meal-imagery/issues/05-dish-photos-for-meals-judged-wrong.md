# 05: Dish photos for Meals judged wrong

**What to build:** Ticket 03 produces a list of Meals whose current picture actively misrepresents
them. On sample that is roughly half of all Mosaics, and it includes most of the 197 Recipes still
wearing ingredient Tiles — the Meals most likely to have a real photograph somewhere.

A Tile may be a finished dish (decided 2026-09-10), so the tile bank is not being purged. Instead,
Meals whose Mosaic is judged wrong are fixed individually, using ticket 04's sourcing pass. A Dish
photo outranks a Mosaic in the ladder, so a successful sourcing simply replaces it.

**Blocked by:** 03 (the list of wrong Meals), 04 (the sourcing pass)

**Status:** done (2026-09-10)

- [x] Every Meal whose verdict is `wrong` is either re-served with an `ok` Dish photo or falls back
      to blocked with a reason.
- [x] No Meal ends the ticket still displaying an image rated `wrong`.
- [x] Recipes wearing Tiles are included in the population, whatever their verdict.
- [x] A replaced Mosaic's Tiles are cleared, so no Meal carries both.
- [x] The honesty figure is re-reported, and the remaining blocked population is broken down by
      reason.

**Sized by 03's measurement (2026-09-10):** 910 meals are rated `wrong` — 539 `dish`, 367 `mosaic`,
4 `tile` — ordered by reach in `docs/meal-images/honesty.md` and listable in full with
`node scripts/meal-images/09-image-report.mjs --wrong`. The dish half was not anticipated: these
meals have a photograph of the wrong food, so "a dish photo outranks a mosaic" does not rescue them
and each needs re-sourcing on its own.


## What was built (2026-09-10)

Commits `34879c75`, `c4cd0e0e` and this one. Pass 10 already had a `QUEUE=wrong`
and a retire path from ticket 04, but retirement only ever touched dish
photographs. Four changes closed the gap:

- **The ladder remembers what the judge refused** (rule 4 in `lib/ladder.mjs`).
  A refused grid is stored on the meal in `image_rejected_mosaics` (migration
  `20260910200000_meal_rejected_mosaics.sql`, dev-applied) and never offered to
  that meal again; the meal resolves to `none` with `grid_refused`. Without
  this, pass 3 recomputes from scratch and hands every retired meal back the
  grid it was retired from.
- **Retiring is its own pure module** (`lib/retire.mjs`, 16 tests): any rung,
  every refusal remembered, the verdict cleared with the picture.
- **A fallback grid is judged before the meal is left.** A meal whose wrong
  photograph falls back to a grid keeps it only if the judge rates it `ok`.
- **Queues combine** (`QUEUE=wrong,recipes`), and `recipes` is new. A meal out
  of rounds but still showing a wrong picture is retired without searching.

Pass 3 now reads `image_rejected_mosaics`; a dry re-run changes nothing.

## Result

**Honesty 29.4% → 75.3%**, 0 meals rated `wrong`, 0 unjudged, 0 carrying both
a photograph and tiles, 0 showing nothing without the blocked flag. Of the
932 meals: 77 found an `ok` photograph, 55 fell back to a grid rated `ok`, 50
recipes kept a grid that was not wrong, and the rest show their icon.

Blocked, by reason: `grid_refused` 689, `multi_part_single_tile` 198,
`transformed` 160, `no_bank_tile` 71. Coverage fell 80.9% → 41.8%. About $8,
of which the ledger records $0.57 (see `docs/meal-images/honesty.md`).

## Deviations

**A `weak` fallback is blocked, not kept (Lee, 2026-09-10).** Ticket 04 kept
`weak` photographs as thin rather than misleading. Here the fallback grid of a
meal that was showing the wrong food must be `ok`, which is what the first AC
reads. The first run had already kept 13 `weak` fallbacks; they were retired
through the same `retire()` and the run was restarted on the new rule.

**Two meals still share a photograph with another meal**, and two chicken
tikka masala meals wear near-identical files. The contact sheet caught five
shared placements that the stored-address check had let through across run
restarts; the check now keys on the source page too, and two of the four
re-sourced. The rest are ticket 07's.

**`IDS=` now overrides the queue** rather than narrowing it: the repair above
was on meals no queue describes (served, `ok`, shared).
