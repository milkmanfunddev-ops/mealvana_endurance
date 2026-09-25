# 128: Browse and Swap show the right meals and say the truth

**Status:** in-progress (wave 31, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Seven fixes on Browse meals, the meal detail and the two swap lists, from wave 29, with Lee's rulings of 2026-09-25.
1. **Recents holds still (88-006).** `MealCatalogController.build` paints local Recents, then `_loadServerRails` replaces them when `recent_meals` returns 1.8-5.2 s later, so a tap lands on a different meal. Once a rail is shown its order does not change under the finger: merge the server's rows in without reordering what is shown, or hold the rail until the server answers.
2. **The detail says "In your plan" (88-007, Lee).** For a meal already in the conversation's draft, the detail shows the "In your plan" state (`mpBrowseAdded`) and no Add button, matching the Browse card's tick. No toast claims an add that did not happen. Watch `conversationDraftProvider(pickConversationId)`.
3. **The chat's swap picker skips plan meals (88-009, Lee).** Never the meal being swapped, never a meal already in the plan, the same as the Plan tab's Swap screen. `SwapPicker` takes `excludeIds` but never passes it to `searchMeals`, and it does not set `requireNutritionNumbers` either; `showMealSheet` gets a new `excludeIds` from each call site.
4. **No research notes as subtitles (89-003).** `MealCard` falls back to `meal.why` when `subtitle` is null; ticket 60 fixed only Browse. Remove the `why` fallback from `MealCard` so no card anywhere shows the research note, and pass ingredients on Swap and the swap picker. A saved meal whose only item is its own name shows no subtitle rather than repeating its name (`meals.ts:72`).
5. **Browse opens on its own rails (89-008).** Browse and the Meals tab share one `mealCatalogControllerProvider`, which keeps the Meals tab's query ("spinach") while `LazyIndexedStack` keeps that tab mounted. Browse opens with no search and its rails. Keying the provider by surface is preferred over clearing the Meals tab's search.
6. **The heart remembers (89-009, Lee).** The heart reads the saved state on open (Drift `SavedMeal.libraryMealId`) and tapping a filled heart removes the meal from My Foods (`SavedMealsRepository.softDelete`), with a toast through the content system.
7. **Name the source athlete in the research notes (88-010, Lee).** `meal_library.why` holds the research files' evidence text word for word, and about 14 rows start "his " or "her ", meaning the source athlete (AD-014/015/016: David Rother, `docs/new_mealplanning/assembly-library-research/dinner-a.json:660,706,750`; others in `dinner-b.json`, `lunch-c.json`, `breakfast-c.json`). Migration `20260925172800_meal_library_why_names_the_source.sql` rewrites those rows by id so each names its source; read every row's research entry before writing its text.

**Findings:** 88-006, 88-007, 88-009, 89-003, 89-008, 89-009, 88-010.

**Decisions:** none on the page; Lee's rulings in the terminal (88-007, 88-009, 89-009, 88-010).

**Touches:** lib/features/meal_planning/application/meal_catalog_controller.dart, lib/features/meal_planning/presentation/widgets/meal_rail.dart, lib/features/meal_planning/presentation/widgets/meal_catalog_browser.dart, lib/features/meal_planning/presentation/screens/recents_screen.dart, lib/features/meal_planning/application/meal_photos_controller.dart, lib/features/meal_planning/presentation/screens/vana_browse_screen.dart, lib/features/meal_planning/presentation/screens/meal_detail_screen.dart, lib/features/meal_planning/application/meal_detail_controller.dart, lib/features/meal_planning/presentation/widgets/swap_picker.dart, lib/features/meal_planning/presentation/widgets/meal_sheet.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart (showMealSheet call sites :966, :1082), lib/features/meal_planning/presentation/widgets/plan_bar.dart (showMealSheet call site :268), lib/features/meal_planning/presentation/screens/swap_meal_screen.dart, lib/features/meal_planning/presentation/widgets/meal_card.dart, supabase/functions/_shared/vana/meals.ts, supabase/migrations/20260925172800_meal_library_why_names_the_source.sql, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

- [ ] Controller test: a server Recents answer that arrives after the first paint does not reorder the shown rail.
- [ ] Widget tests: the detail for a meal in the draft shows "In your plan" and no Add; the swap picker excludes the swapped meal and the plan's meals; `MealCard` with no subtitle shows no research note; Browse opens on rails while the Meals tab holds a query.
- [ ] Seam test through the real notifier for the heart: save then unsave writes and soft-deletes the saved meal; reopen reads it as saved.
- [ ] The migration touches only the "his "/"her " rows, by id; a SQL check after it finds none left.
- [ ] `flutter analyze` clean on touched files; deno vana tests. Deploy (migration, then vana-action if `meals.ts` changed): wave lead.

Next: /implement-lee testing-wave
