# Meal library imagery

How `meal_library` rows get a picture, where those pictures come from, and what
we are and are not allowed to do with them.

Scripts: `scripts/meal-images/`. Dev only — `lib/db.mjs` hard-codes the dev
project ref so a stray env var cannot point a bulk write at prod.

## Where it stands (2026-09-11)

**Honesty is 75.3%.** 1,447 of 1,922 active meals either show a picture the judge
rated `ok` or show their icon with a recorded reason. No meal shows a picture
rated `wrong`. The live figures, the breakdown by mode and reason, and what each
run cost are in [honesty.md](honesty.md), regenerated from the database by pass 9.

Coverage, the share of meals showing any picture at all, is 41.8% (804 meals).
It is not a measure of quality and should not be quoted as one. The two numbers
count different things:

- Coverage counts a meal as done when it shows a picture, whatever the
  picture is of.
- Honesty counts a meal as done when it shows a picture the judge rated
  `ok` for that meal, or shows its icon on purpose. A `weak` picture counts
  toward coverage and not toward honesty.

The library once reported 94.5% coverage (2026-09-08). That figure counted
fifteen meals shown with a photograph of water as fifteen covered meals. When
the judge first looked at every meal (2026-09-10), coverage was 80.3% and
honesty 27.3%, and 539 of the 708 dish photos were of the wrong food. Coverage has
fallen since because wrong pictures were retired, and a meal with no honest
picture shows its icon rather than a wrong one.

## Why tiles instead of dish photos

Only ~250 of the 1,922 rows are `kind='recipe'`. The rest are *assemblies* —
compositional entries like "Barley, chard & pinto bean bowl" or
"Rice cake, cranberry + orange zest + white chocolate". **No photograph of those
dishes exists anywhere**, which is why literal dish matching stalled at 36.8%
coverage in the 2026-09-01 Wikimedia pass.

So a Separable meal without a real photo is represented by a mosaic of its
*principal ingredients*, drawn from a shared bank. A Transformed meal (a
smoothie, a bake) cannot be told by its parts, so it gets a dish photo or its
icon. Tiles repeat across meals, but the
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
the picture would occupy, with the picture's corners, so a rail of mixed rows
does not go ragged (`meal_card.dart`, component contract MIM-9). On a card, a
photograph that fails to load falls back to the same icon rather than leaving a
blank slot. The detail screen passes no fallback, so a meal with no picture has
no hero, and a hero whose photograph fails to load collapses. A row can move up the ladder later simply by re-running pass 3 after the
bank grows.

**One photograph, one card per list.** Reusing a photograph across the
library is fine; a list showing it on two Meals at once reads as though it is
repeating itself. `picturesForList` (`lib/features/meal_planning/domain/list_pictures.dart`)
decides what each card in a list draws: the first Meal wearing a photograph
keeps it, and a later one falls back to its Mosaic if it carries one, otherwise
to its icon. Only a photograph standing for the whole Meal counts, a Dish photo
or a one-thing Meal's Tile; Mosaic cells are shared ingredients by design. Two
photographs are the same one when their address (without its query string) or
their source page matches, because a mirrored archive photo is stored once per
Meal. `search_meals` returns `image_source_url` for that reason. Nothing is
stored: the Meal itself, the detail screen and every other list are unaffected.
No Dish photo carries a Mosaic today (the ladder writes `image_tiles` only when
there is no `image_url`), so in practice the fallback is the icon.

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

**The ladder remembers what the judge refused.** A grid the judge refused for a
meal is kept in `meal_library.image_rejected_mosaics` (its photographs in
drawing order), and the ladder never offers that grid to that meal again: the
meal resolves to `none` with the reason `grid_refused`. Pass 3 recomputes every
meal from scratch, so without this a re-run would hand every retired meal back
the picture it was retired from. The memory is of the picture, not the meal —
once pass 2 replaces one of the tile photographs, the grid is a different
picture and the ladder offers it again, unjudged.

## Compositor parity — read before touching the grid

The mosaic is drawn twice. `MealImageMosaic` draws it for the athlete, in
Flutter, and pass 8 draws it again as a file so a model can look at it and
record a verdict in `meal_library.image_verdict`. It is drawn on the client
because most grids contain a photograph we may not store a copy of
([ADR 0002](../adr/0002-mosaics-are-composed-on-the-client.md)).

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
10-source-dish-photos.ts search stock by DISH NAME -> judge -> image_url  ($, hours)
09-image-report.mjs    count it all -> docs/meal-images/honesty.md
04-contact-sheet.mjs   (review) render the whole bank as a few PNGs
```

Run order is 01 -> 02 -> 05 -> 07 -> 03 -> 08 -> 10 -> 09; pass 5 must precede pass 3,
because pass 3 only reads `status='ok'`, and pass 7 must precede it because a
transformed meal may not wear tiles. Pass 8 judges what pass 3 assigned, so it
comes after, and pass 9 only counts what 3 and 8 wrote.

All are idempotent, and all resume. Pass 2 only touches `status='pending'`,
pass 5 only tiles without a verdict, and pass 8 only meals without one — and
pass 8 writes each verdict as it reaches it rather than batching to the end, so
a run killed an hour in keeps every verdict it paid for. Pass 10 remembers every
candidate the judge refused, so a re-run never pays for the same refusal twice.
Passes 3 and 9 recompute from scratch every time.

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
deno run --allow-net --allow-read --allow-write --allow-run --allow-env --allow-sys \
  scripts/meal-images/10-source-dish-photos.ts   # QUEUE=transformed|blocked|wrong|recipes|all
node scripts/meal-images/09-image-report.mjs --write
node scripts/meal-images/04-contact-sheet.mjs
```

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

## Pass 10 — where the judge sits

Pass 2 and the 2026-09-01 Wikimedia pass both accepted a picture on a text
score and let something else find out later. Pass 8's first measurement is what
that produces: of the 708 meals carrying a real photograph, **539 were of the
wrong food** — a carton of raw eggs for "Eggs & turkey bacon on toast", a
food-court interior for "Congee with pickled vegetables". Every one of them
scored well on the words, because a title is a weak description of a picture.

So pass 10 moves the judge from the end of the pipeline to the middle of it. A
candidate is searched for by **dish name**, fetched, composed exactly as the
athlete would see it, and shown to the same judge pass 8 grades the library
with. Only `ok` is stored, and it is stored together with the verdict that
accepted it — so a sourced picture arrives already measured and pass 8 has
nothing to re-judge.

| | |
|---|---|
| what to search for | `lib/dish-query.mjs` — a name cleaned down to the dish, then shortened until a search answers |
| which candidate to look at first | `lib/dish-score.mjs` — `score.mjs` turned around: a plated dish is the point, "isolated on white" is the mistake |
| the question | `lib/meal-image-judge.ts` — one prompt, shared with pass 8 |

Both new files are pure and tested without a network, a database or a model:

```bash
node --test scripts/meal-images/lib/dish-query.test.mjs scripts/meal-images/lib/dish-score.test.mjs
```

**Ranking decides the spend, not the outcome.** A better ranking is fewer paid
calls before an `ok`; the judge decides what is kept. That division is why the
scorer is allowed to be crude.

A refusal is a verdict that was paid for, so the URL goes into
`meal_library.image_rejected_urls` and no later run shows the judge that picture
again.

**A meal gets one round, and a re-run does nothing by default.** This is not the
retry loop the ingredient bank has, and the difference is real: pass 2 stops at
the first candidate that downloads, so its second round genuinely reaches a
different picture. A pass 10 round already walks `MAX_JUDGED` candidates, and
the next one re-runs the same queries against the same libraries for the same
answers — every one of them already refused. It would spend hours of provider
budget re-learning what the first round learned. So a second round is bought
only when *the pass itself* has changed — a better query builder, another
provider — with `MAX_ATTEMPTS=2`, deliberately.

When a meal runs out of rounds still showing a picture rated `wrong` — a
photograph, a grid or a single tile — that picture is retired
(`lib/retire.mjs`) and the ladder answers again without it. A wrong picture is
worse than no picture, and an icon is a state rather than an absence. A meal
whose photograph was of the wrong food may still be entitled to a good grid,
so the rung it drops to is judged before the pass leaves it. Only `ok` keeps it
— a meal that was showing the wrong food does not get to keep a thin grid in
its place (Lee, 2026-09-10) — so a `weak` or `wrong` grid is refused and the
meal lands on its icon with `grid_refused`. A meal already out of
rounds is retired without being searched again.

A fallback grid whose tiles could not be downloaded is left unjudged rather than
guessed at. So after a run that retired anything, run pass 8 (it judges only
meals with no verdict), and if it rates any of those `wrong`, run pass 10 once
more on the same queue: those meals are out of rounds, so they are retired
straight to their icon without another search. Retiring is tested on its own:

```bash
node --test scripts/meal-images/lib/retire.test.mjs
```

A recipe wearing an `ok` or `weak` grid keeps it when no photograph is found:
the pass was looking for something better there, not repairing something wrong.

```bash
QUEUE=transformed  meals a Mosaic can never serve (the default)
QUEUE=blocked      every meal the ladder found nothing for
QUEUE=wrong        meals whose current picture was judged `wrong`, any rung
QUEUE=recipes      recipes wearing ingredient tiles, whatever their verdict
QUEUE=all          blocked and wrong
QUEUE=wrong,recipes   queues combine; this one is ticket 05's population
SEPARABILITY=transformed   narrow any queue to one separability
MAX_ATTEMPTS=2     give meals already attempted one more round
```

## Looking at them together — what the judge cannot see

The judge rates one picture, alone, against one meal. Two failures survive that
by construction, and both were found by putting the sourced photographs on a
contact sheet and looking:

```bash
SUBJECT=meals SINCE=<iso> node scripts/meal-images/04-contact-sheet.mjs
```

**A picture can pass while its subject is packaging.** "Baby food pouch, ultra
race-week snack" was accepted on a photograph of a supermarket shelf, price tags
included. The judge described exactly that — *"Ella's Kitchen … pouches on a
store shelf"* — and still rated it `ok`, because it does depict the meal. The
prompt names "packaging or branding as the subject" as `wrong`; the judge
weighed matching the meal above it. One row, handed back. Whether the prompt
should be sharpened is a real question and a costly one: a prompt change
re-values every verdict in the table, exactly as a geometry change does.

**Two meals can repeat each other without sharing a URL.** Three chocolate-milk
meals (`AS-196`, `AS-364`, `S-083`) looked like three photographs of one mug.
They are one: the same Wikimedia file, mirrored three times under three meal
ids, byte-identical. Pass 10 now keys "already in use" on the source page, and
a list keys on it too (below). What neither can see is two *different*
photographs of one plate: `D-037` and `L-027` (chicken tikka masala) wear two
files from the same shoot. A difference hash puts them 16 bits apart of 64, far
outside any duplicate threshold, so only a look at the contact sheet finds that
kind.

Neither is visible in the honesty figure, which is the point of the sheet.

## Licensing — read before changing anything

**Storage policy is per-provider and is not a performance choice.** Why, and
what reversing it would cost:
[ADR 0001](../adr/0001-meal-images-mirroring-is-decided-per-provider.md).
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

### How the app credits a photograph

The app builds each credit from those fields (`KyleImageCredit` in
`lib/shared/widgets/kyle_design/data/meal_image_mosaic.dart`), not from the
stored `image_credit` line:

- Unsplash: "Photo by *name* on *Unsplash*", both linked, both carrying
  `utm_source=mealvana&utm_medium=referral`. The name opens the photograph's
  page; we do not store the photographer's profile URL.
- Pexels: "Photo by *name* on *Pexels*", the name opening the photograph's page
  and Pexels linking back.
- Creative Commons: "Photo by *name* on Wikimedia Commons (CC BY-SA 4.0)", with
  the licence spelled one way whatever way it was stored. Openverse photographs
  are credited to the site they live on (usually Flickr), taken from
  `source_url`.
- A recipe-page photograph with no provider: "Photo on *host*", linking the page.

A picture credits every distinct photograph it shows once, keyed on the
photograph's source page. The detail hero shows the credits and opens them on
tap. Card thumbnails are too small for a visible line, so they carry the same
text as their screen-reader label.

`search_meals` sends a dish photo's `image_url` and `image_credit` only, so a
card's label for a dish photo is that stored line as written. The detail screen
gets the structured fields from `get_meal`.

### Rate limits

Enforced in `lib/ratelimit.mjs` as token buckets, because exceeding either
metered limit gets the key throttled:

- **Unsplash 50/hr** on a demo key (45 used, safety margin). Production is
  1,000/hr but must be applied for, and the application requires screenshots of
  in-app attribution. Linked credits shipped in meal-imagery ticket 06; the
  screenshots come from the meal detail hero of a meal with an Unsplash tile.
  One gap remains against Unsplash's guideline: the photographer's name links
  to the photograph's page, not their profile, because the pipeline drops
  `user.links.html` (Pexels: `photographer_url`). Close it before applying.
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

- **30 unlicensed hotlinks — FLAGGED, deliberately kept.** 30 meals across 19 food-blog
  hosts (`norecipes.com`, `urbanblisslife.com`, `blondekimchi.com`) whose
  `image_credit` is a bare domain (40 across 24 hosts on 2026-09-08; retiring
  pictures the judge rated wrong has taken ten of them away since). These are og:image scrapes from the
  recipe-directions backfill: unlicensed hotlinks to identifiable small
  businesses, which also cost those sites bandwidth.

  Lee chose to keep them while the meal library is a prototype (2026-09-08,
  re-confirmed 2026-09-10) rather than spend the effort now. They carry
  `meal_library.image_unlicensed = true` so the debt is queryable rather than
  remembered.

  **Prod gate — this must be zero before any prod cutover:**
  `select count(*) from meal_library where image_unlicensed;`
  The gate is a step in the cutover runbook
  (`supabase/migrations/cutover/meal_planning/`, `03_image_gate.sql`), which
  raises rather than returning a number, so it cannot be read past.
- 133 dish photos from the 2026-09-01 Wikimedia pass are still hotlinked to
  `upload.wikimedia.org` rather than mirrored (668 when the pass ran; the rest
  were judged wrong and retired). Permitted but discouraged and
  fragile; re-running pass 2 against them would mirror them properly.
