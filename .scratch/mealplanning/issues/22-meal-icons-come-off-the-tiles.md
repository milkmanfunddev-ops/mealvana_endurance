# 22: Meal icons come off the tiles

**Status:** done (wave 1, 2026-09-15)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee mealplanning`

**What to build:** A meal with no photo shows a plain placeholder on the Meals tab, the plan tiles, the plan bar and the review sheet. The 23-key classifier and the stored icon key on library, saved and plan meals stay exactly as they are. The glyph set and the icon tile widget are deleted.

**Decisions:** mp-145; approved as mp-300.

**Touches:** lib/features/meal_planning/presentation/widgets/meal_card.dart, lib/features/meal_planning/presentation/widgets/plan_tile.dart, lib/features/meal_planning/presentation/widgets/plan_bar.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/presentation/widgets/meal_icon_glyphs.dart

- [x] No tile, card, plan bar row or review sheet row draws an icon; a missing photo shows the plain placeholder.
- [x] The classifier, the icon key and its copy on add and swap are untouched (existing tests still pass).
- [x] The glyph file and the icon tile widget are removed; goldens for the plan tile and the meal card are regenerated.

Next: /implement-lee mealplanning
