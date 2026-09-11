# 07: No repeated photograph in one rail

**What to build:** 135 photographs are shared by more than one Meal — two different oatmeals point
at the same Wikimedia file. Reuse across the library is fine and was agreed; the same photograph
appearing twice in one rail on screen is not, because the rail reads as though it is repeating
itself.

**Blocked by:** None (can start immediately)

**Status:** done (2026-09-11)

- [x] Two Meals visible in the same rail never show the same photograph.
- [x] The choice is deterministic: the same data produces the same result every time.
- [x] A Meal that loses its photograph to this rule still shows something — its Mosaic if it has one,
      otherwise its icon.
- [x] Reuse across different rails, and across the library, is unaffected.

**Added by ticket 05 (2026-09-10).** Pass 10's "already in use" check now keys on
a photograph's source page as well as its address, so a mirrored archive photo is
recognised after a restart. Still shared: an açaí bowl (`S-058`, with two other
açaí meals) and "White bread with jam" (`S-008`, with "White bread & jam"); and
`D-037` / `L-027` (chicken tikka masala) wear two different Wikimedia files of
what looks like one picture — the perceptual case.

**Done (2026-09-11).** `picturesForList` (`lib/features/meal_planning/domain/list_pictures.dart`)
decides what each card in a list draws; every list of `MealCard`s uses it (search and filter
results, Recents, the swap screen and the swap picker). The horizontal rails draw no pictures.
A photograph is identified by its address without the query string, or by its source page;
`search_meals` now returns `image_source_url`, `image_creator` and `image_license`
(`20260911120000_search_meals_photo_source.sql`, dev only). Mosaic cells don't count: they are
shared ingredient Tiles by design.

On dev that is 33 photographs worn by 91 Meals, 12 of them (5 photographs) only visible by
source page. The açaí bowls and the two white-bread-and-jam Meals are in that 12. No Dish photo
carries a Mosaic today, so a Meal that loses its photograph shows its icon. `D-037` / `L-027`
are two different photographs from one shoot, not one file; this rule does not catch them, and
a difference hash would not either (16 of 64 bits apart).

