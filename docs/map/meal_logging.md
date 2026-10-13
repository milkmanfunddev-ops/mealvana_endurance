# Meal logging

domain: 4 Log what you ate · folders: `lib/features/meal_logging/` (45 files), `lib/features/barcode_scanning/` (9),
`lib/features/recipes/` (3), `lib/features/user_foods/` (1), `lib/features/food_preferences/` (2), `lib/features/nutrition/` (2)

Everyday food, logged into the day's timeline. One screen, "Log a Meal", holds every way to log; the workout fuel
log is a different screen (`nutrition_plan/fuel-log.md`).

## What athletes can do here

- **Open it.** "+ Add Food" on the Timeline (for the selected day; the title reads "Log — Oct 3" for a past day),
  "Add Food" on a carb-loading slot page, or a slot recommendation (which pre-fills the search).
- **Search anything.** "Search anything to add…" looks in favourites, recents, recipes and common ingredients (a
  strip of cards labelled "Favorite" / "Recent" / "Recipe" / "Ingredient"), the athlete's own foods ("My Foods"),
  the curated catalogue, and, only when fewer than five results came back, USDA and Open Food Facts ("More
  Results"). A typed barcode number looks the product up.
- **Pick a tab.** "Recent" (saved meals with a star, swipe to remove with Undo; the last 25 meals), "Common"
  ("Quick add" combos and 44 "Ingredients"), "Recipes" (chips "All", "Breakfast", "Mains", "Snacks", "Workout
  Fuel", "Recovery"), "Describe" (opens first), "Manual".
- **Describe it.** "Describe what you ate and Mealvana AI will estimate the macros." → "What did you eat?" (5 to
  2000 characters), optional "Camera" / "Gallery" photo ("Photo attached"), "Analyze" (costs one token; "Review
  again" is free for the same input). Then "Review & Log": a confidence badge ("High / Medium / Low confidence —
  please review"), "Meal name", "Meal type" chips, the items (swipe right "Remove", swipe left "Swap", "Edit item"),
  the AI's note, "Log this meal". Errors: "That doesn't sound like food or drink…", "Add a bit more: at least 5
  characters…", "Camera access is off…", "Could not read that photo…".
- **Type it.** "Manual": "Meal name" (required), "Meal type", "Time eaten", "Calories (kcal)", "Carbs (g)",
  "Protein (g)", "Fat (g)", "Add more detail" (Sodium, Notes), "Save".
- **Scan it.** The barcode icon → "Scan to Add Food" (flash, "Reset", "Switch", "Enter" a code of 8 to 14 digits);
  "Product Not Found" offers "Try Another" / "Create Manually". Then "Log Food": per-serving macros, "Servings",
  meal slot chips (default Snack), "Log Food".
- **Confirm a quick log.** Everything except Manual, barcode and Describe goes through one sheet: the name and
  macros, "Servings" (0.5 to 10), "Time eaten" with "Change", "Meal type (optional)" ("Any time", "Breakfast",
  "Lunch", "Dinner", "Snack", "Morning Snack", "Afternoon Snack", "Evening Snack"), "Log it" → "Meal logged!".
- **Build a meal.** "Build a meal" in the app bar: "Start building your meal", "+ Add food" (search and tabs
  "Recipes", "Common", "Manual"), "Start from a saved meal / recent", "Meal name", "Time eaten", "Meal type", notes,
  "Also save as a favorite", "Log meal". Leaving asks "Discard this meal?".
- **Edit or remove a logged meal.** On the Timeline a meal row shows "N kcal · C · P · F"; tap it for "Edit food",
  "Remove" ("Meal deleted · Undo"), "Save as favorite". "Edit Meal": the photo ("Re-scan photo" costs a token and
  asks "Replace items?"), name, type, time, items or plain macros, notes, "Save changes" → "Meal updated".
- **On a carb-loading day** the meal type is the loading slot and the meal lands in that slot's card. Logging from
  a slot page keeps the slot for food, ingredient and Common taps; recipes, saved meals, recents, Manual, barcode
  and Describe pick their own.
- **AI tokens.** The fortune-cookie pill beside Describe shows the balance (pink under three) and opens "Refill
  tokens" ("Each analysis costs 1 token. Top up to keep going.", "Starter" / "Best value" packs). At zero: "Out of
  AI credits · You've used all your AI credits. Get more to keep using AI features." → "Get credits". See `ai_credits.md`.

Where the buttons live: `meal_logging` (Log a Meal, Review & Log, Build a Meal, Edit Meal, the quick-log sheet) ·
`barcode_scanning` · `macro_dashboard` (the meal row and its menu) · `carb_loading` (slot page) · `ai_credits`
(pill, sheet, dialog) · `shared/controllers/food_search_controller.dart` (the search cascade).

## What the data means

`meal_logs` (phone and Supabase, offline first): `log_date`, `eaten_at`, `name`, `slot` (seven values or empty),
`source` (photo | manual | describe | saved | recipe | jade_baseline), `items` (JSON components), `calories`,
`carbs_g`, `protein_g`, `fat_g`, `sodium_mg`, `notes`, `photo_path`, `recipe_id`, `saved_meal_id`, `servings` (> 0),
`is_deleted`. `saved_meals` (favourites), `user_foods`, `recipes` (+ `recipe-images` bucket, refreshed daily),
`food_preferences`, `nutrition_products` (server cache of USDA / Open Food Facts), `catalog_products` /
`catalog_variants`, the `meal-photos` bucket (location and device data stripped before upload). Functions:
`describe-meal`, `analyze-meal-photo` (both one token, nothing charged on failure), `search-catalog`,
`search-nutrition-products`, `lookup-product`. Analytics: `meal_logged` {slot, source, method, log_date},
`meal_log_updated/deleted/restored`, `meal_saved_as_favorite`, `saved_meal_deleted/restored`, `log_meal_opened`,
`diary_opened/closed`, `log_method_selected`, `meal_ai_action_tapped/started/completed/failed/validation_failed`,
`meal_ai_photo_attached`, `barcode_scanner_opened/scanned/entered/lookup_failed`. The log method is analytics only,
not stored. `meals_logged_bulk` never fires.

## What already exists to reuse

- `presentation/providers/meal_log_providers.dart` (`MealLogController`: every meal write), `application/meal_logging_service.dart`
  (totals), `data/meal_log_repository.dart` + `saved_meals_repository.dart`, `application/meal_ai_service.dart` (AI calls, photo
  upload, credit errors), `describe_analysis_controller.dart` (keeps the paid result so going back doesn't charge twice),
  `draft_meal_controller.dart` (Build a Meal).
- Widgets: `quick_log_confirm_sheet.dart`, `meal_component_editor.dart` (shared by Review, Edit, Build),
  `slot_chip_selector.dart` / `optional_slot_chip_selector`, `unified_meal_search_results.dart`, `common_ingredients_section.dart`,
  `manual_log_form.dart`, `meal_analysis_skeleton.dart`; `barcode_scanning/` (`barcode_scanner_screen`, `log_scanned_food_screen`,
  `barcode_scanner_service`); `ai_credits/` (`token_pill`, `token_cost_chip`, `token_top_up_sheet`, `insufficient_credits_paywall`).

Don't add: another meal-write path (the controller), another search (the cascade). Dead: `meal_log_method_sheet.dart`
→ `today_log_section.dart` → `meal_log_row.dart` → `domain/meal_favorite_match.dart` (one dead chain),
`consumed_progress_widget.dart`, `nutrition/domain/nutrition_data.dart`, `showSlotPickerSheet`, `todayDateString`,
`logSavedMeals`, `RecipeService.toggleFavorite` / `getFavoriteRecipes`; `notes/` holds only a README. Archived
screens (photo, describe, manual, recent/saved, recipe, the Jade chat) live under `_archived/`. Gardening: stale
comments at `log_meal_screen.dart:122,946-952,1167`, `meal_log_providers.dart:239`, `slot_chip_selector.dart:45-47`,
`app_router.dart:242-251`, `app_config.dart:160-163`, `edit_meal_log_screen.dart:621-638`, `meal_log_source.dart:4,19`;
every search or catalogue tap is reported as method `common`.

## Links

- **qa:** no meal-logging spec yet; `spec/design/surfaces/macro-dashboard.md:21` (meal card), `spec/domain/catalog-conventions.md`,
  `spec/design/surfaces/carb-loading-dashboard.md` (slot page reuses this path).
- **ops open work:** bugs `meal-built-from-search-saves-zero-components`, `recommended-food-tap-logs-wrong-food`,
  `barcode-lookup-fails-in-first-logging-session`, `seeded-foods-invisible-for-24h-staleness-gate`, `meal-card-dead-action-pills`,
  `food-row-names-truncate-at-narrow-width`, `honey-catalog-row-not-marked-vegan-excluded`, `cookie-balance-stale-on-auth-change` ·
  feature-requests `sale-driven-meal-planning`, `make-food-preferences-findable-for-the-tuner`,
  `decision-anonymous-user-at-the-paywall`, `decision-paywall-offer-mode-vs-hard-gate`.
- **Related map pages:** `macro_dashboard.md` · `carb_loading.md` · `ai_credits.md` · `nutrition_plan/fuel-log.md` · `settings.md`
  (Food Likes & Dislikes, allergies).
