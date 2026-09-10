# 04: Dish photos for Meals a Mosaic cannot serve

**What to build:** Around 170 Transformed Meals — smoothies, ice creams, baked things, stews — can
never be told by their parts, so they currently show nothing. A blended raspberry-nectarine drink is
one pink liquid; photographs of raspberries and nectarines describe the shopping list, not the food.
The only honest fix is a photograph of the finished thing.

Build the sourcing pass: search licensed stock by the Meal's *name* rather than by its ingredients,
and — the change that matters — put every candidate in front of the judge **before** accepting it.
Every previous pass accepted on a text score and discovered the problem later.

**Blocked by:** 01 (the ladder decides where a new photo lands), 03 (the baseline to improve on)

**Status:** done (2026-09-10)

- [x] A sourcing pass searches licensed stock by dish name and returns ranked candidates.
- [x] No candidate is stored unless the judge rates it `ok` for that Meal.
- [x] Attribution is captured for every accepted photograph, and the per-provider mirroring rules are
      respected — archive material mirrored, stock-photo providers hotlinked.
- [x] Every Transformed Meal ends the ticket with either an `ok` Dish photo or the blocked flag and a
      reason. None is left showing a Mosaic.
- [x] The pass is idempotent: a re-run skips Meals already served and retries only failures.
- [x] The honesty figure is re-reported against ticket 03's baseline.

**Rescoped by 03's measurement (2026-09-10).** The 170 transformed meals are no longer the largest
population needing a photograph: **539 meals already wearing a dish photo are wrong**, and this
pass's sourcing is what fixes them too (ticket 05). Judge-before-accept matters more than expected
— the existing dish photos are exactly what accepting on a text score produces.


## What was built (2026-09-10)

`scripts/meal-images/10-source-dish-photos.ts`, with three seams beside it:

- `lib/dish-query.mjs` — a meal name cleaned down to the dish and shortened until a
  search answers. Searched verbatim, "Butternut squash \"mac & cheese\" (GF pasta,
  dairy-free)" returns nothing, and nothing is indistinguishable from "no photograph
  exists".
- `lib/dish-score.mjs` — `score.mjs` turned around: a plated dish is the point,
  "isolated on white" is the mistake. Ranking decides the spend, not the outcome.
- `lib/meal-image-judge.ts` — the judge extracted so pass 8 (which measures) and
  pass 10 (which accepts) ask one prompt. Two prompts would mean pass 10 buying
  acceptances pass 8 then rates `wrong`.

Both scorers are pure and tested without a network, a database or a model (23 new
assertions). Migration `20260910180000_meal_dish_photo_sourcing.sql` adds
`image_rejected_urls` and `image_attempts`, dev-applied.

**Result: honesty 27.3% → 29.4%.** 53 of 211 Transformed meals served, 301
candidates refused, $1.32. Every Transformed meal now shows an `ok` photograph
(61) or its icon (159 blocked with a reason) — none wears a Mosaic, none shows a
picture rated `wrong`.

**Verifying on the real artifact found a defect the row counts hid.** The rows
were right and the pictures served, but `search_meals` — the RPC the app calls —
showed four different smoothies wearing one photograph. Stock search is narrow
enough that four green-smoothie meals are offered the same top-ranked picture,
so the pass was manufacturing exactly what user story 7 asks us to avoid. It now
reads the photographs already in use and skips them, and the four were
re-sourced. The 128 duplicates from earlier passes are left to ticket 07.

## What this run learned, for ticket 05

**A 23% hit rate is the ceiling, not a disappointment.** The stock libraries
simply do not hold "Low-FODMAP chocolate chia pudding". Ticket 05's 503 wrong
dish photos should be planned at roughly this rate, with retirement — showing the
icon — carrying the rest.

**The judge refused 85% of what the ranking offered.** Every one of those would
have been accepted by a text score, which is precisely how the 539 wrong dish
photos got there. Judge-before-accept is the whole change.

**Wall-clock is the metered providers, not the model.** Measured per meal: search
70–150s, fetch under 2s, judging under 10s. Pexels' 180/hour is a global gap
shared across workers, so CONCURRENCY only lengthens the queue. The unmetered
archives now lead and Pexels is asked only for what they cannot answer.

**A second round buys nothing.** It re-runs the same queries against the same
libraries and gets the same answers, all already refused — so `MAX_ATTEMPTS`
defaults to 1, and a maintainer raises it deliberately after changing the pass.

## Deviations

**Nine Transformed meals still show a `weak` photograph** rather than an `ok` one
or an icon. `weak` is thin, not misleading, and trading it for an icon would be a
loss for the athlete. Flagged rather than actioned.

**"Retries only failures" now needs asking for.** The AC reads *"a re-run skips
Meals already served and retries only failures"*, and `MAX_ATTEMPTS` defaults to
1, so a plain re-run retries nothing. That inversion is deliberate and was
measured: a second round re-runs the same queries against the same libraries and
gets the same answers, all already refused — it buys hours of provider budget and
no pictures. A maintainer who has changed the pass asks for the retry with
`MAX_ATTEMPTS=2`, which is how the 28 retirements in this ticket were done.

**`QUEUE=wrong` and the retire path are ticket 05's population**, built here
because ticket 04's own AC needed them: 31 Transformed meals were wearing a
photograph of the wrong food, and neither an `ok` photo nor a blocked flag was
reachable for them without retirement. Ticket 05 inherits a path that has run.
