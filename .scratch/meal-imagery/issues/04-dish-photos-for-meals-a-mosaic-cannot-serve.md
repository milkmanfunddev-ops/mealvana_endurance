# 04: Dish photos for Meals a Mosaic cannot serve

**What to build:** Around 170 Transformed Meals — smoothies, ice creams, baked things, stews — can
never be told by their parts, so they currently show nothing. A blended raspberry-nectarine drink is
one pink liquid; photographs of raspberries and nectarines describe the shopping list, not the food.
The only honest fix is a photograph of the finished thing.

Build the sourcing pass: search licensed stock by the Meal's *name* rather than by its ingredients,
and — the change that matters — put every candidate in front of the judge **before** accepting it.
Every previous pass accepted on a text score and discovered the problem later.

**Blocked by:** 01 (the ladder decides where a new photo lands), 03 (the baseline to improve on)

**Status:** ready-for-agent

- [ ] A sourcing pass searches licensed stock by dish name and returns ranked candidates.
- [ ] No candidate is stored unless the judge rates it `ok` for that Meal.
- [ ] Attribution is captured for every accepted photograph, and the per-provider mirroring rules are
      respected — archive material mirrored, stock-photo providers hotlinked.
- [ ] Every Transformed Meal ends the ticket with either an `ok` Dish photo or the blocked flag and a
      reason. None is left showing a Mosaic.
- [ ] The pass is idempotent: a re-run skips Meals already served and retries only failures.
- [ ] The honesty figure is re-reported against ticket 03's baseline.

**Rescoped by 03's measurement (2026-09-10).** The 170 transformed meals are no longer the largest
population needing a photograph: **539 meals already wearing a dish photo are wrong**, and this
pass's sourcing is what fixes them too (ticket 05). Judge-before-accept matters more than expected
— the existing dish photos are exactly what accepting on a text score produces.
