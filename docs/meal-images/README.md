# Meal library imagery

How `meal_library` rows get a picture, where those pictures come from, and what
we are and are not allowed to do with them.

Scripts: `scripts/meal-images/`. Dev only — `lib/db.mjs` hard-codes the dev
project ref so a stray env var cannot point a bulk write at prod.

## Why tiles instead of dish photos

Only ~250 of the 1,922 rows are `kind='recipe'`. The rest are *assemblies* —
compositional entries like "Barley, chard & pinto bean bowl" or
"Rice cake, cranberry + orange zest + white chocolate". **No photograph of those
dishes exists anywhere**, which is why literal dish matching stalled at 36.8%
coverage in the 2026-09-01 Wikimedia pass.

So a meal without a real photo is represented by a mosaic of its *principal
ingredients*, drawn from a shared bank. Tiles repeat across meals, but the
combination is unique to each meal, so the library does not look canned the way
a handful of shared "grain bowl" stock photos would.

## The fallback ladder

`meal_library.image_mode` records which rung a row landed on:

| mode | meaning |
|---|---|
| `dish` | a real photograph of the meal; `image_url` is used, tiles ignored |
| `mosaic` | 2-4 ingredient tiles in `image_tiles` |
| `tile` | exactly one ingredient tile |
| `none` | nothing usable — the card keeps its icon, and `image_blocked` is raised with `image_blocked_reason` so the population is countable |

`none` is a state, not an absence: the card draws the meal's icon in the space
the picture would occupy, so a rail of mixed rows does not go ragged
(`meal_card.dart`). A row can move up the ladder later simply by re-running
pass 3 after the bank grows.

The rules that pick the rung live in `scripts/meal-images/lib/ladder.mjs` —
`resolveMealImage(meal, bank)`, a pure function that touches no network, no
database and no model. Pass 3 is only the part that cannot be pure: it reads the
bank and the meals, applies the rules and writes the answers. So changing what a
meal shows is an edit to one function with an assertion beside it:

```bash
node --test scripts/meal-images/lib/ladder.test.mjs
```

Every rule in that file was argued for and should break exactly one test when it
changes.

## Compositor parity — read before touching the grid

The mosaic is drawn twice. `MealImageMosaic` draws it for the athlete, in
Flutter, and pass 8 draws it again as a file so a model can look at it and
record a verdict in `meal_library.image_verdict`.

**Every stored verdict is a statement about the picture the compositor drew.**
If the two drawings stop agreeing, those verdicts describe a picture no athlete
has ever seen: the sweep still costs real money, still fills the column, and
measures nothing. It is the one failure in this pipeline that leaves no trace —
the numbers look fine.

So there is one description of the grid, and neither side computes it:

| | |
|---|---|
| the description | `scripts/meal-images/lib/mosaic-geometry.json` — cell rectangles for 1-4 tiles, the hairline's width and colour, the fit |
| the formula behind it | `scripts/meal-images/lib/mosaic-geometry.mjs` |
| the file the judge sees | `scripts/meal-images/lib/compose-mosaic.mjs` (pass 8 calls it; also a CLI) |
| the picture the athlete sees | `lib/shared/widgets/kyle_design/data/meal_image_mosaic.dart` |

Both sides are asserted against the JSON, and the two drawings are compared
pixel for pixel from the same four source images:

```bash
node --test scripts/meal-images/lib/mosaic-geometry.test.mjs
flutter test test/shared/widgets/kyle_design/meal_image_mosaic_geometry_test.dart
```

Change the grid on one side alone and the other side's test fails: the cell
rectangles, the tile order within them, the hairline's width and colour, and
the fit are each asserted from the JSON on both sides. The pixel comparison
needs node and python3 with Pillow and skips where they are absent, so on a
machine without them the rectangle assertions are what is holding the line.

**A change to the geometry invalidates every stored verdict.** It is a re-measure,
not a redeploy: bump `version` in the JSON, then clear and re-run pass 8 —

```sql
update meal_library set image_verdict = null, image_verdict_reason = null,
                        image_verdict_at = null
 where image_mode in ('mosaic', 'tile');
```

(`dish` rows are a single photograph and are unaffected by the grid.) Pass 8
prints the geometry version it judged with at the top of every run.

v1 pins what the widget draws, which is not quite what pass 8 drew before it:
the separator was 2px rather than 1, and the cells were floor-divided rather
than rounded. No verdict had been written when v1 landed (2026-09-10), so there
was nothing to clear — the invariant starts clean.

To eyeball what the judge sees for a set of tiles, without spending anything:

```bash
node scripts/meal-images/lib/compose-mosaic.mjs --out /tmp/grid.png a.jpg b.jpg c.jpg
```

## Pipeline

```
01-build-bank.mjs      ingredients_json -> normalized slugs -> ingredient_images
02-fetch-images.mjs    search providers -> score -> tile -> storage/hotlink
05-vision-verify.ts    look at the pixels -> demote tiles that aren't the food
07-classify-separability.ts  can this meal be told by its parts at all?
03-assign-tiles.mjs    bank + ingredients -> image_tiles/image_mode/image_blocked
08-verify-meal-image.ts  compose what the athlete sees -> image_verdict  ($, hours)
09-image-report.mjs    count it all -> docs/meal-images/honesty.md
04-contact-sheet.mjs   (review) render the whole bank as a few PNGs
```

Run order is 01 -> 02 -> 05 -> 07 -> 03 -> 08 -> 09; pass 5 must precede pass 3,
because pass 3 only reads `status='ok'`, and pass 7 must precede it because a
transformed meal may not wear tiles. Pass 8 judges what pass 3 assigned, so it
comes after, and pass 9 only counts what 3 and 8 wrote.

All are idempotent, and all resume. Pass 2 only touches `status='pending'`,
pass 5 only tiles without a verdict, and pass 8 only meals without one — and
pass 8 writes each verdict as it reaches it rather than batching to the end, so
a run killed an hour in keeps every verdict it paid for. Passes 3 and 9
recompute from scratch every time.

**Pass 8 spends real money** — one frontier-model vision call per meal showing a
picture, about $5 for the library, several hours at `CONCURRENCY=5`. What each
run actually cost is in [honesty.md](honesty.md).

```bash
set -a; source secrets/image_apis.env; source secrets/ai_gateway.env; set +a
node scripts/meal-images/01-build-bank.mjs
node scripts/meal-images/02-fetch-images.mjs      # LIMIT= CONCURRENCY= to sample
deno run --allow-net --allow-read --allow-env --allow-sys \
  scripts/meal-images/05-vision-verify.ts        # RECHECK=1 to re-judge
node scripts/meal-images/03-assign-tiles.mjs
deno run --allow-net --allow-read --allow-write --allow-run --allow-env --allow-sys \
  scripts/meal-images/08-verify-meal-image.ts    # LIMIT= to sample, DRY=1 to price it
node scripts/meal-images/09-image-report.mjs --write
node scripts/meal-images/04-contact-sheet.mjs
```

## Where it landed (2026-09-08)

> **Do not quote the number below.** 94.5% is *coverage* — how many meals have a
> picture — and it counts fifteen meals represented by a photograph of water as
> fifteen covered meals. The number that means anything is honesty, measured per
> meal against the composed image: **[honesty.md](honesty.md)**.

**94.5% coverage — 1,816 of 1,922 meals**, from a bank of ~500 vision-checked
ingredient tiles. Baseline before this work was 36.8%.

| mode | rows | share |
|---|---|---|
| `dish` | 708 | 36.8% |
| `mosaic` | 835 | 43.4% |
| `tile` | 273 | 14.2% |
| `none` | 106 | 5.5% |

## Pass 5 — why vision verification exists

Text scoring reads TITLES, and archive titles are terse. The file behind
"Chorizo" is a vacuum-sealed supermarket packet; "Fusilli" is a pair of hands
on an empty table; "Rice" is a branded package; "Chicken" is a live bird. No
regex over the title can catch any of that.

Pass 5 runs Haiku over each tile through the Vercel AI Gateway (same pattern as
`supabase/functions/_shared/ai/model.ts`) and asks whether the ingredient is
actually visible as food. **It rejected 191 tiles — 27% of everything the text
scorer had accepted** (`wrong_food` 110, `packaging` 45, `people` 17,
`unclear` 11, `empty_scene` 8).

It is verification, not generation — nothing here creates an image. A failed
tile is *demoted*, not deleted: `status='rejected'` with `vision_ok=false` and
a `vision_reason`, keeping `image_url` for audit.

**A rare ingredient must clear a higher bar.** `TAIL_MIN_SCORE` (105) applies to
ingredients used by fewer than 8 meals, against `MIN_SCORE` (55) for the rest —
a wrong photo is worse than no photo, and the tail is where the archives return
something that merely shares a word.

## Licensing — read before changing anything

**Storage policy is per-provider and is not a performance choice.**
`providers.mjs` exports `MAY_MIRROR`:

| provider | licence | storage |
|---|---|---|
| Wikimedia Commons | CC0 / PD / CC-BY / CC-BY-SA | **mirrored** into the `meal-images` bucket |
| Openverse | CC (commercial-use subset only) | **mirrored** |
| Unsplash | Unsplash Licence | **hotlinked — must not be mirrored** |
| Pexels | Pexels Licence | **hotlinked — must not be mirrored** |

Unsplash's production-access checklist explicitly requires that photos are
hotlinked to the Unsplash CDN, that a download event is fired when a photo is
used, and that the photographer and Unsplash are both credited and linked.
Copying their files into our bucket would breach that and lose API access.
Pexels likewise expects hotlinking plus a link back.

`licenseOk()` rejects NonCommercial and NoDerivatives outright — we never guess
at an unknown licence string, we drop the candidate.

Every row keeps `license`, `creator`, `source_url` and `provider` so attribution
can be rendered wherever the image is.

### Rate limits

Enforced in `lib/ratelimit.mjs` as token buckets, because exceeding either
metered limit gets the key throttled:

- **Unsplash 50/hr** on a demo key (45 used, safety margin). Production is
  1,000/hr but must be applied for, and the application requires screenshots of
  in-app attribution — so it cannot be requested until the UI ships.
- **Pexels 200/hr**, 20,000/month.

Because Pexels allows only ~20s per ingredient, the metered libraries lead for
the top `STOCK_TOP` (default 450) ingredients by row-frequency — the ones that
appear on the most cards — and act only as a rescue for the long tail.
Wikimedia/Openverse are unmetered and carry the rest.

## Why the scorer is strict

Selection is fully automatic, so `lib/score.mjs` is the only thing between the
library and a wrong photo. Two failure modes it exists to prevent, both observed:

- **Botanical drift.** Commons is an encyclopedic archive, so a bare produce
  name returns the *organism*: "sweet potato" -> an *Ipomoea* flower, "olive
  oil" -> a mill. Hence the heavy `flower|blossom|vine|leaf|tree` penalty.
- **Composed-dish drift.** Over-correcting with `"<ingredient> food"` queries
  returns finished dishes instead: spinach -> cannelloni bake, avocado -> fruit
  salad. Hence the subject-purity rule that rewards titles *leading* with the
  ingredient and penalises comma/"and" lists.

Candidates are tried best-first down the ranking, because the top pick is often
a dead hotlink or a thumbnail too small to crop.

## Operational lessons (2026-09-08)

These all cost a run, and the guards for them are in the code:

- **A provider can go dark mid-run.** Openverse hung every request for ~20s.
  `lib/ratelimit.mjs` + the circuit breaker in `providers.mjs` drop a provider
  after 8 consecutive failures.
- **A network blip must not drain the queue.** One outage burned 1,110
  ingredients in seconds because the worker logged and moved on. It now retries
  each ingredient and parks all workers on a connectivity probe.
- **An unretried write ends a batch.** A single `504` on one PATCH killed a
  516-tile vision run at tile 88. `rest()` retries 408/429/5xx with backoff.
- **Rate limits, not concurrency, set the pace.** Unsplash's 50/hr demo cap
  forced 80s per ingredient (27h for the tail); Pexels' 200/hr forced 20s.
  Metered providers lead only for the top-ranked ingredients; the unmetered
  archives carry the tail, which runs ~16/min.
- **A `Range:`-paged read with no unique ordering is a silent data loss.**
  Postgres promises nothing about the order of two separate queries, so page 2
  can repeat page 1 and omit rows instead — and ordering by `rows_using.desc`
  is the same bug wearing a hat, because hundreds of slugs share a count. The
  omitted meals keep a stale `image_mode` and nothing says so. `selectAll` now
  appends the table's key to every order, and takes `{ key: 'slug' }` for
  `ingredient_images`.
- **A skip is not free just because it is correct.** Pass 8's first full sweep
  asked upload.wikimedia.org for five pictures at once, got 429s thirty meals
  in, and skipped **41 of the next 44 meals in seconds** — every skipped meal
  stayed unjudged, so nothing was corrupted, and the run still measured a fifth
  of the library while reporting success. A 429 is the host saying "slower",
  and `lib/fetch-tile.mjs` now says it back: per-host pacing that widens on a
  429 (honouring `Retry-After`) and narrows on success. Re-run: 0 skips in 300.
- **Normalization bugs are silent.** `\bwhole\b` matched inside hyphenated
  compounds, so `whole-grain crackers` became the unmatchable slug
  `-grain-crackers`. Compounds are stripped before the bare word; check
  `01-build-bank.mjs` output for slugs starting with `-`.

## Known issues

- **40 unlicensed hotlinks — FLAGGED, deliberately kept.** 40 meals across 24 food-blog
  hosts (`featherstonenutrition.com`, `recipetineats.com`, `teaforturmeric.com`)
  whose `image_credit` is a bare domain. These are og:image scrapes from the
  recipe-directions backfill: unlicensed hotlinks to identifiable small
  businesses, which also cost those sites bandwidth.

  Lee chose to keep them while the meal library is a prototype (2026-09-08,
  re-confirmed 2026-09-10) rather than spend the effort now. They carry
  `meal_library.image_unlicensed = true` so the debt is queryable rather than
  remembered.

  **Prod gate — this must be zero before any prod cutover:**
  `select count(*) from meal_library where image_unlicensed;`
- The 668 Wikimedia images from the 2026-09-01 pass are still hotlinked to
  `upload.wikimedia.org` rather than mirrored. Permitted but discouraged and
  fragile; re-running pass 2 against them would mirror them properly.
