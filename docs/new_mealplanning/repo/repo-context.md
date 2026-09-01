# Meal Planning — Repo Context

Reference doc for building a **meal planning** feature in Mealvana Endurance. Covers what already
exists in the codebase that a planner can reuse, the data model, relevant edge functions, prior
roadmap/design work, hard constraints, and the gaps a real planner needs to fill. All paths are
relative to the repo root (`/Users/leemartin/development/mealvana_endurance`).

This doc is the **repo** pillar. Figma, Notion, and prototype research live in sibling
directories (`docs/new_mealplanning/figma/`, `notion/`, `prototype/`) owned by other agents —
not duplicated here.

---

## 1. Existing features to build on

### 1.1 Recipes (`lib/features/recipes/`)

A small, curated, **read-only** recipe catalog — not a build-a-plan tool yet, but the closest
thing to "meal content" in the app today.

- **Domain** — `lib/features/recipes/domain/recipe.dart`:
  ```dart
  class Recipe {
    final String id;
    final String name;
    final String description;
    final List<String> ingredients;     // plain strings, not structured components
    final List<String> instructions;    // plain strings
    final int prepTimeMinutes;
    final int servings;
    final RecipeType type;              // breakfast|mains|snacks|workout_fuel|recovery
    final RecipeNutrition nutrition;    // calories, carbsG, proteinG, fatG, fiberG, sugarG, sodiumMg
    final String? imageUrl;
    final List<String>? tags;
    final bool isFavorite;              // ALWAYS false — see below
    final DateTime? createdAt, updatedAt;
  }
  ```
- **Repository** — `lib/features/recipes/data/repositories/recipe_repository.dart`. Read-only
  mirror pattern (same shape as the pre-workout template repos): Supabase `recipes` is source of
  truth (service-role writes only), Drift `RecipesTable` is the offline cache, **24h staleness**
  window (vs. the mixin's 1h default — recipes rarely change), hydrated on-demand via
  `ensureSynced(userId, {force})` when the Recipes screen opens (not startup sync-all). Images:
  stored as either a full `https://` URL or a bare filename resolved against the public
  `recipe-images` Supabase Storage bucket.
- **Favorites are NOT implemented.** `getFavoriteRecipes()` always returns `[]`,
  `toggleFavorite()` is a no-op — explicit `TODO` in the file to add a local favorites table (or
  reuse `saved_meals`).
- **Service** — `lib/features/recipes/application/recipe_service.dart`: thin facade adding
  `filterRecipesByTags`, `sortRecipes` (name/prepTime/calories/newest), `searchRecipes` (client-side
  substring match over name/description/ingredients/tags).
- **Screen** — `lib/features/recipes/presentation/screens/recipes_screen.dart`; also surfaced via
  `lib/features/meal_logging/presentation/screens/recipe_picker_screen.dart` for logging.
- **Consumed by meal logging**: `MealLog.recipeId` / `MealLogSource.recipe` link a log entry back
  to a recipe; `MealLogController.logRecipe(...)` scales a recipe by servings and logs it.

### 1.2 Meal logging (`lib/features/meal_logging/`)

The most fully-built adjacent feature — a retrospective food diary, not a forward planner, but it
owns the canonical `MealComponent`/`MealLog`/`SavedMeal` shapes a planner should reuse rather than
re-invent.

- **`MealLog`** (`domain/meal_log.dart`) — one logged meal. Fields: `id, userId, logDate
  ('yyyy-MM-dd' string), slot (MealSlot?), name, source (MealLogSource), components
  (List<MealComponent>), calories/carbsG/proteinG/fatG/sodiumMg (denormalized totals), photoPath,
  recipeId, savedMealId, notes, eatenAt, createdAt, updatedAt, isDeleted, needsUpload,
  localUpdatedAt`. Soft-delete tombstones only — never hard-deleted (must propagate through
  upsert-only sync). `slot` is **optional** (2026-07 redesign) — an untagged log is valid data.
- **`MealSlot`** (`domain/meal_slot.dart`) — `breakfast|lunch|dinner|snack`, wire values match a
  DB CHECK constraint.
- **`MealLogSource`** (`domain/meal_log_source.dart`) — `photo|manual|describe|saved|recipe|
  jade_baseline` (wire value `jade_baseline` — "prepopulated by Mealvana AI as part of a baseline
  daily plan", i.e. the app already has a source enum value reserved for AI-generated plan
  entries).
- **`MealComponent`** (`domain/meal_component.dart`) — the canonical food-item shape stored inside
  both `meal_logs.items` and `saved_meals.items` JSONB: `{ name, portion (free-text, e.g. "1
  cup"), calories?, carb_g?, protein_g?, fat_g?, sodium_mg? }`. All macro fields optional.
- **`SavedMeal`** (`domain/saved_meal.dart`) — an explicit user favorite ("My Meals"). Same
  component shape as `MealLog`, plus `lastUsedAt` (bumped on re-log, sorts the picker). Never
  auto-derived from logs — user must explicitly save. `mealFavoriteMatchKey` /
  `findFavoriteMatch` (`domain/meal_favorite_match.dart`) compute a JSON-encoded (name +
  component) identity signature to let the UI's favorite-star toggle find/match a `SavedMeal`
  against a `MealLog` without a back-link column.
- **`quick_assembly.dart`** — a **static, hardcoded** catalog (`kQuickAssemblies`) of ~10
  two-ingredient combos ("Banana + peanut butter" etc.) for the log screen's Quick tab, each with
  an emoji and pre-computed macros. This is the closest existing analog to "ingredient bundle"
  meal suggestions the archived roadmap docs describe — currently static, not AI- or
  training-load-driven.
- **`MealLogController`** (`presentation/providers/meal_log_providers.dart`, `@riverpod`
  `AsyncNotifier`) — the write API a planner's "log from plan" action should call directly:
  - `logManualMeal(...)`
  - `logSavedMeal(...)`, `logSavedMeals(...)`
  - `logRecipe(...)`
  - `logFromComponents({required name, slot?, required logDate, required source, required
    components, photoPath?, notes?, eatenAt?, logMethod?})` — the general-purpose entry point;
    `AiCoachMealCard`'s "Log it" button already calls this with `MealLogSource.describe`.
  All routed through `_runGuarded` (AsyncValue.guard wrapper), invalidate `recentMealsProvider`,
  and fire a `meal_logged` analytics event.
- **`showQuickLogConfirmSheet`** (`presentation/widgets/quick_log_confirm_sheet.dart`) — the
  shared bottom sheet every one-tap quick-log path (food, recipe, saved meal, recent, quick
  assembly) uses to confirm servings/time/slot before calling the controller. Reusable as-is for
  "confirm + log a planned meal."
- **AI-assisted logging**: `application/meal_ai_service.dart` (`MealAiService`, `@riverpod`)
  wraps `describe-meal` and `analyze-meal-photo` edge functions, typed exceptions
  (`MealAiException` with `offline|notFood|serverError`), throws `InsufficientCreditsException`
  on a 402 from the credits gate.
- **Screens**: `log_meal_screen.dart` (hub — composes recipe picker, barcode scan, AI describe/
  photo, quick assemblies, common ingredients), `describe_meal_screen.dart`,
  `photo_capture_screen.dart`, `build_meal_screen.dart`, `manual_log_screen.dart`,
  `recent_saved_picker_screen.dart`, `edit_meal_log_screen.dart`, `meal_review_screen.dart`.

### 1.3 Personal templates / personal formulas (`lib/features/personal_templates/`,
`lib/features/formula_kit/`)

Two distinct, historically-overlapping concepts for **user-authored fueling content**, both
scoped to single-workout nutrition (before/during/after a run/ride/swim), not daily meals:

- **`PersonalTemplate`** (`personal_templates/domain/personal_template.dart`) — a saved
  **nutrition-plan snapshot**: `id, userId, name, activityType, originalDurationMinutes,
  originalDistance, originalActivityTitle, planData (Map<String,dynamic> — full plan JSON),
  totalCarbsG/ProteinG/FatG/SodiumMg/FluidsMl/Calories, brickSegmentOrder, createdAt, updatedAt`.
  Legacy provenance tag `legacy_plan` plus newer `forked_formula`/`from_scratch_formula` (shared
  with `PersonalFormula`), `phase` (before/during, nullable), `customFoodIds` (references into
  `user_foods`).
- **`PersonalFormula`** (`formula_kit/domain/personal_formula.dart`) — a **reusable fueling
  recipe** tied to one workout phase, not a plan snapshot: `id, userId, name, provenance
  (FormulaProvenance: forkedFormula|fromScratchFormula), phase (FormulaPhase: before|during|
  after), sourceTemplateId/Kind, subPhase, digestSpeed, activities, durations, gutTraining,
  travelFriendliness, components (List<Map<String,dynamic>> — opaque, at least food_name+
  quantity), notes, coachInsightText/Marker (persisted AI insight, persist-unless-edited), total
  macros, isDeleted, needsUpload, localUpdatedAt`.
- **Formula Kit's "3 template tables"** are the **system-authored** catalog `PersonalFormula` can
  fork from: `pre_workout_templates`, `during_workout_templates`, `post_workout_templates` (see
  §2 for columns). Selection is phase- and scope-filtered (activity type, duration bracket, gut
  training level, sub-phase, digestion speed) by the plan-generation solver, with an optional
  **pin** override — see `FormulaPin`/`formula_pins` below.
- **`FormulaPin`** (`formula_kit/domain/formula_pin.dart`) — a user-declared preference signal:
  "when pins exist matching a workout's scope, plan generation tries pinned templates first."
  `TemplateKind` is a polymorphic ref enum: `preSystem|duringSystem|postSystem|personalFormula`
  (note: **not** `personal_templates` — only `personal_formulas` rows are pinnable).
- **View models** — `formula_kit/domain/formula_view.dart` (`BeforeFormulaView`,
  `DuringFormulaView`, `AfterFormulaView` — display-ready projections with
  `componentDisplayStrings`, `allergens`, `excludedDiets` already resolved for the card UI).
- **Repositories**: `pre_workout_templates_repository.dart`, `during_workout_templates_
  repository.dart`, `post_workout_templates_repository.dart` (read-only mirrors of system
  content, same 24h-ish staleness pattern as recipes), `personal_formulas_repository.dart` /
  `personal_templates_repository.dart` (offline-first, user-owned, dirty-tracked), `formula_pins_
  repository.dart`.
- **Screens**: `formula_library_screen.dart` (browse/filter by phase), `formula_detail_screen.dart`,
  `formula_editor_screen.dart` (build-your-own).
- **AI coach insight**: `application/coach_insight_controller.dart` calls the `ai-coach` edge
  function (`mode: "insight"`) to generate a 15–28 word coaching line about a draft formula — see
  §3.

### 1.4 `user_foods` (`lib/features/user_foods/`)

User-created custom foods (no dedicated domain class — shape lives on the Drift
`UserFoodsTable`/`UserFoodsTableCompanion`, built ad hoc). Repository: `data/user_foods_
repository.dart`, `UserFoodsRepository with SyncableRepository`, `repositoryKey: 'user_foods'`,
Level-1 in the sync dependency graph (depends only on `users`). Fields uploaded: `id, deviceId,
userId, clientFoodId, barcode, name, displayName, displayNamePlural, description, imageAddress,
servingAmount, servingUnit, servingSize, caloriesPerServing, carbsPerServing, proteinPerServing,
fatPerServing, sodiumMg, fluidMlPerServing, productType, categories, activityTypes,
isElectrolyte, toExcludeFromSolver, isDeleted, createdAt, updatedAt, clientUpdatedAt`.

**Known gap (still open per project memory, confirmed in code):** `user_foods` has **no
`allergens` or `excludedDiets` column** at all, unlike every catalog-backed food table (`foods`,
`catalog_products`, `template_foods`, `pre/during/post_workout_templates`). Since the allergy
filter (`ClientFoodPoolService`, §1.6) only inspects `allergens` on template/catalog rows, a
user-created custom food can **never** be excluded by the allergy filter. A meal planner that lets
users add custom foods must not silently inherit this bypass.

### 1.5 Daily macros (`lib/features/daily_macros/`)

The daily calorie/macro **target** a meal plan should be built to hit.

- **`DailyMacroTargets`** (`domain/daily_macro_targets.dart`): `id, userId, targetDate, carbG,
  protG, fatG, tdee, rmr, sessionKcal, neatKcal?, tefKcal?, mode ('prospective'|'race_week'),
  ea? (energy availability), eaStatus? (EaStatus: ok|softWarning|hardWarning|block),
  algorithmVersion (default 'v4'/'v5.0.0'), sources? (MacroSources — per-field GARMIN/FORMULA/
  MANUAL/NONE attribution for rmr/neat/weight/bodyFat + per-session), createdAt, updatedAt`.
- **Generation**: `DailyMacroService.calculateForDate()` checks the local Drift cache first, else
  calls the `calculate-daily-macros` edge function with profile + session + multi-day training
  context (yesterday/tomorrow TSS, weekly-hours ratio, training phase).
- **Repository**: `DailyMacroTargetsRepository` — **not** a full `SyncableRepository`; a Drift
  cache keyed by `(user_id, target_date)` with best-effort push to Supabase (silent-catch on
  failure, single Sentry capture/session) and **version-gated staleness** (rows whose
  `algorithm_version` doesn't match the client's expected version are treated as cache misses and
  purged).
- **Enums** (`domain/enums.dart`): `TrainingPhase` (base/build/peak/taper/raceWeek/offSeason),
  `Lifestyle`, `EaStatus`.

### 1.6 Nutrition plan (`lib/features/nutrition_plan/`)

The **single-workout** fueling plan (before/during/after a specific activity) — the app's most
mature nutrition-generation surface, and a strong reference architecture for a meal planner's
solver even though it operates at workout granularity, not daily/weekly.

- **`NutritionPlan`** (`domain/nutrition_plan.dart`): `id, name, sections (List<PlanSection>),
  macroTargets? (PlanMacroSummary), totalCalories?, notes?, runDateTime?, planRating? (1-3),
  journalNotes?, activityId? (FK to activities), version (optimistic concurrency), lastModifiedBy?
  (device id), clientUpdatedAt?, createdAt?, updatedAt?, isDeleted, conflictResolution (default
  `'last_write_wins'`)`.
- **No `nutrition_plans` Supabase table exists.** Plans are generated by the
  `generate-nutrition-plan-v3` edge function and persisted **embedded as JSON inside
  `activities.nutrition_plan_data`** (`NutritionPlanRepository.cachePlanLocally` →
  `database.activityDao.setActivityNutritionPlan`). A plan's sync/offline behavior is entirely
  piggybacked on the `activities` repository.
- **Generation**: `application/nutrition_plan_service.dart` +
  `application/client_plan/client_plan_service.dart` (on-device greedy solver mirroring the
  edge function) — `client_greedy_solver.dart`, `client_during_phase_solver.dart`,
  `client_food_pool_service.dart` (`ClientFoodPoolService`, `application/client_plan/
  client_food_pool_service.dart:68-113`) filters the candidate food pool by the user's
  `allergies` (a `Set<String>` of `Allergy.dbValue`) before solving: any candidate whose
  `allergens` overlaps the user's set is dropped **unless** the food is flagged `isEssential`.
- **Screens/controllers**: `activity_detail_screen.dart` (view a generated plan),
  `new_activity_screen.dart` + per-sport controllers (`running_input_controller.dart`,
  `cycling_input_controller.dart`, `swimming_input_controller.dart`, `brick_input_
  controller.dart`), `adjust_macros_screen.dart`/`macro_targets_controller.dart` (edit targets),
  `swap_food_screen.dart`/`swap_food_controller.dart` (in-plan substitution — a close analog to
  a meal-plan "swap this meal" action).

### 1.7 Food preferences + allergens (`lib/features/food_preferences/`,
`lib/features/onboarding/domain/allergy.dart`)

Two separate mechanisms, both enforced at the **food-catalog** level rather than on the
preference row itself:

- **`FoodPreference`** enum (`lib/features/auth/domain/user_preferences.dart`): `like|dislike|
  willingToTry` (dbValue `willing_to_try`), plus a 0–4 slider `preferenceLevel` and a `source`
  tag: `'manual' | 'allergy:{name}' | 'dietary:{name}'`. Choosing an allergy or dietary exclusion
  during onboarding **auto-sets a `dislike` preference** on matching foods via `saveFoodPreferences
  (source: ...)`; removing the allergy/diet undoes it via `removeFoodPreferencesBySource`.
- **`Allergy`** enum (`onboarding/domain/allergy.dart`): `dairy, eggs, fish, gluten, peanuts,
  sesame, shellfish, soy, treeNuts` (dbValue `tree_nuts`). Stored on `UserProfile.allergies`
  (synced from Postgres `users.allergies allergy_enum[]`) — **not** in `food_preferences`.
- **`FoodPreferencesRepository`** (`data/food_preferences_repository.dart`) — `with
  SyncableRepository`, Level-2 (depends on users+foods). `syncFromRemote` merges (doesn't
  clobber unsynced local prefs); `uploadDirtyRecords` batch-upserts everything for the user with
  `onConflict: 'user_id,food_name'` — **note: no per-row dirty flag yet**, so every save
  re-uploads the whole set (the repo's own comment flags this as a known gap).
- **Enforcement**: every food-bearing catalog table (`foods`, `catalog_products`,
  `template_foods`, `pre/during/post_workout_templates`) carries an `allergens`/`excluded_diets`
  array column. Client-side filtering happens in `ClientFoodPoolService` (§1.6); server-side, the
  edge-function solver uses `supabase/functions/_shared/nutrition/templates/diet-filter.ts`
  (`filterTemplatesByDiet`, `filterDrinksByDiet` — excludes a template if `excluded_diets`
  contains the user's `dietary_preference`, or `allergens` overlaps the user's `allergies`).
  **`user_foods` is exempt from this filter** (§1.4 gap).

### 1.8 Events (`lib/features/events/`) — user events + `public_events`

- **`Event`** (`domain/event.dart`) — the user's own race/goal: `id, userId, activityId?,
  eventType (ActivityType), eventSubtype? (race distance string), eventName?, location?,
  registrationUrl?, eventDate?, startTime?, goalTimeMinutes?, goalPaceMinutesPerMile?,
  predictedFinishTimeMinutes?, hasCarbLoading, carbLoadingDays?, carbLoadingStartDate?,
  hasNutritionPlan (deprecated — use activityId != null), bibNumber?, waveStartTime?,
  packetPickupInfo?, actualFinishTimeMinutes?, finalPlacement?, ageGroupPlacement?, createdAt,
  updatedAt, needsUpload?, localUpdatedAt?`. Drives carb-loading (§1.10) and calendar.
- **`PublicEvent`** (`domain/public_event.dart`) — read-only, admin-curated race catalog used
  purely for **autocomplete** when creating an `Event`: `id (int), eventName, eventType,
  eventSubtype?, location?, city?, state?, eventDate?, startTime?, registrationUrl?, websiteUrl?,
  description?, organizerName?, matchType? (exact|fuzzy), relevanceScore?`. Refreshed prod-only by
  the `/refresh-events` skill; dev mirrors prod.

### 1.9 Weather (`lib/features/weather/`)

- **`WeatherForecast`** (`domain/weather_forecast.dart`): `temperatureC, humidityPct,
  forecastAvailable, forecastDate, source (WeatherSource: forecast|historical|defaultValue),
  conditions?, windSpeedKmh?, precipitationMm?, fetchedAt`. `isFresh()` = fetched < 1h ago.
  `defaultForecast()` fallback = 20°C/60% humidity when unavailable.
- **Fetch**: `WeatherService.fetchWeatherForecast` calls a Supabase edge function (no dedicated
  remote table for the provider call). **Cached in a local-only Drift table**
  (`WeatherRepository`, bucketed by top-of-hour + lat/lon; 1h TTL for forecast, 24h for
  historical). **No Supabase `weather_forecasts` table exists** — this is a pure local
  performance cache, not part of the `SyncableRepository`/`ensureSynced` pattern at all.
- **Usage**: feeds sweat-rate/sodium/fluid computation in nutrition-plan generation and is
  surfaced in activity-creation flows (`environment_section.dart`, `deck_conditions_section.dart`).
  A weekly meal planner wanting "hot day → higher electrolyte/fluid meals" would need to either
  reuse this per-activity cache or add a day-level forecast fetch.

### 1.10 Carb loading (`lib/features/carb_loading/`)

The **closest existing thing to a multi-day meal plan** in the codebase — worth studying closely
as prior art even though it's carb-grams-per-meal-slot, not full macro/recipe planning.

- Purpose: pre-race carbohydrate loading (Featherstone Nutrition 8g-carb/kg methodology),
  1/2/3/7-day protocols tied to an `Event`.
- **Domain**: `CarbLoadingPlan` (legacy simplified variant — `raceDate, raceDistance,
  trainingVolume, dailyCarbTargetG, dailyServingsTarget, bodyWeightKg, carbsPerKgTarget,
  daySelections: Map<int, DayFoodSelections>`), `CarbLoadingFood` (global default catalog:
  `id, name, displayName(Plural)?, carbsPerServing, imageAddress?, isDefault, mealTypes`),
  `CarbLoadingUserFood` (user-added carb foods, can import from `user_foods` via
  `sourceUserFoodId`), `CarbLoadingDayMeal` (a logged/planned meal slot entry:
  `carbLoadingDayId, mealType, foodId?/userFoodId?, foodDisplayName?, quantity,
  carbsConsumed`).
- **Repositories**: `carb_loading_repository.dart`, `carb_loading_day_meal_repository.dart`,
  `carb_loading_food_repository.dart`, `carb_loading_user_food_repository.dart` — offline-first,
  `needs_upload`/`local_updated_at` columns present on the live schema.
- **Already has a shopping-list spec** (older, separate from the archived meal-planning
  prototype) — `docs/features/carb_loading/carb_loading.md` §3 "Shopping List" and
  `docs/features/carb_loading/roadmap.md` describe optional grocery-delivery integration, export
  formats (PDF/calendar/shopping app), and shopping-list generation error handling. **Worth
  reading directly before designing a new shopping-list feature** — may be reusable spec/UI.
- **Screens**: `carb_loading_protocol_selection_screen.dart`, `carb_loading_food_selection_
  screen.dart`, `carb_loading_day_detail_page.dart`, `create_custom_carb_loading_food_screen.dart`.

### 1.11 Activities / workout history & planned workouts (`lib/features/activities/`)

- **`Activity`** (`domain/activity.dart`, 559 lines) — a **single unified model for both planned
  and completed workouts**, distinguished by `status` (`ActivityStatus`: draft, planned,
  inProgress, completed, skipped, archivedForBrick). Carries sport-specific params, `isFasted`,
  completion data, **`nutritionPlanData`** (embedded JSON — where `NutritionPlan` actually lives,
  §1.6), `fuelLogData` (actual consumption logged), reminder settings, sync fields, and
  external-provider attribution (`syncedFromProvider`, `providerWorkoutId`, `providerWorkoutUrl`,
  `lastSyncedAt`, `needsNutritionRefresh`, `providerDeletedAt`, `scheduleChangedAt`, Garmin
  `garminSummaryId`/`garminDeviceName`, brick fields).
- **Repository**: `ActivitiesRepository with SyncableRepository`, `repositoryKey: 'activities'`.
  Garmin/TrainingPeaks/FinalSurge/VDOT integrations write/update rows via
  `connect_training_controller.dart` and provider sync services (server-to-server push for
  Garmin; match-only against TP/FS planned activities; naive local-day-bounds matching, not UTC —
  see project memory on the Garmin tz bug). A daily/weekly meal planner keying off "today's
  training load" should read from this repository, not re-integrate providers.

### 1.12 AI coach (`lib/features/ai_coach/`) — chat + generative-UI, directly reusable

This is the single most reusable surface for a **chat-forward** meal planner — a meal-suggestion
card renderer and multi-choice UI already ship.

- **Architecture** (FOA-layered): `presentation/screens/ai_coach_chat_screen.dart` →
  `presentation/providers/ai_coach_chat_controller.dart` (`AiCoachChatController`, `@riverpod`
  `AsyncNotifier`) → `data/ai_coach_chat_repository.dart` (`AiCoachChatRepository`) →
  `domain/{ai_coach_conversation,ai_coach_message,ai_coach_ui_part}.dart`.
- **Chat history storage**: remote-only, **no local Drift table**. Supabase `jade_conversations`
  (`id, user_id, title, created_at, updated_at, is_deleted`) and `jade_messages` (`id,
  conversation_id, user_id, role CHECK IN ('user','assistant'), content, metadata jsonb,
  created_at`) — the client never inserts; the `jade-chat` edge function persists both sides
  server-side. `AiCoachMessage.uiParts` hydrates from `metadata.ui_parts` (jsonb) on history load
  and accumulates live during streaming.
- **Generative UI parts** — `domain/ai_coach_ui_part.dart`, sealed `AiCoachUiPart` with two kinds
  today:
  - `AiCoachMealCardsPart` (`kind: 'meal_cards'`) — a list of `AiCoachMealSuggestion { name,
    description, kcal, carbG, proteinG, fatG, slot: MealSlot?, components: List<MealComponent> }`,
    rendered by `presentation/widgets/ai_coach_meal_card.dart` (`AiCoachMealCard`) as a Kyle-styled
    card: name, description, macro row, slot chip, and a **"Log it" button** that opens a bottom
    sheet then calls `MealLogController.logFromComponents(source: MealLogSource.describe)`
    directly.
  - `AiCoachChoicesPart` (`kind: 'choices'`) — `{ question, options: List<String> }`, rendered by
    `presentation/widgets/ai_coach_choice_buttons.dart`.
  - Unknown `kind` values are silently discarded at parse time (forward-compat — new server-side
    UI kinds degrade gracefully on older clients). **A "day grid" / "week plan" UI part does not
    exist yet** — would need to be added as a new `AiCoachUiPart` subtype + widget + server-side
    tool.
- **Trigger flow**: user types → `AiCoachChatController.send(text)`; also a one-shot "proactive
  opener" on first empty-conversation view (`loadOpener()`). `AiCoachChatRepository.
  _streamRequest()` POSTs to `${supabaseUrl}/functions/v1/jade-chat` via raw `http` (Supabase SDK
  doesn't support streaming), response is NDJSON (`{"type":"text"|"ui"|"done"|"error", ...}`)
  parsed line-by-line. A 402 response is parsed into `InsufficientCreditsException` and routed to
  the credits paywall.
- **System prompt already instructs day/week planning behavior**: `_shared/ai_coach/persona.ts`
  `buildSystemPrompt()` has an explicit **"Planning a day or week" section** telling the model to
  pull the athlete's *real* saved/logged foods first (`getSavedMeals`, `getLoggedMeals`) before
  inventing meals, then `getMacroTargets`/`getWorkouts`, then render via `showMealSuggestions`
  grouped by slot — i.e., the chat coach can already be asked "plan my meals today" and it will
  attempt exactly that, using the existing tool set (see §3).

### 1.13 AI credits (`lib/features/ai_credits/`) — metering, must gate any new AI call

- `application/credits_controller.dart` — `CreditsController` (`@Riverpod(keepAlive: true)`),
  the single in-memory balance cache; provisions the wallet once/month, subscribes to Postgres
  realtime on `token_wallets` for near-live balance updates (webhook credit delivery latency is
  unbounded — observed 12s–13min per repo comment).
- `data/credits_repository.dart` — read-only from the client (RLS read-own); all mutations are
  server-side.
- `domain/credit_wallet.dart` — `CreditWallet { balance, freePeriod, updatedAt }`.
- `domain/credit_packs.dart` — `kCreditsByProductId`: `mealvana_credits_50` (50),
  `mealvana_credits_250` (250), `_prod` SKU variants, `mealvana_credits_test_1` (1 credit, $0.99
  tester pack).
- **Cost source of truth is server-side**, `supabase/functions/_shared/ai/credits.ts`:
  ```ts
  export const CREDITS_ENFORCED = Deno.env.get('AI_CREDITS_ENFORCED') === 'true';
  export const FREE_MONTHLY_CREDITS = intEnv('AI_FREE_MONTHLY_CREDITS', 20);
  const DEFAULT_COSTS: Record<string, number> = {
    'ai-coach': 1, 'describe-meal': 1, 'analyze-meal-photo': 1, 'jade-chat': 1,
  };
  ```
  Per-action cost overridable via `AI_COST_<FN>` env var. `ensureAndCheckCredits(client, userId,
  fn)` checks balance **before** the model call (fails open — `allowed:true` — if enforcement is
  off or on any internal exception); `debitForUsage(client, userId, fn)` charges **after** a
  successful call only. A **new meal-planning AI action must register a cost key** in this map
  (or rely on the same default of 1) and call both functions around its edge-function logic — see
  §3 for the exact pattern already used by `jade-chat`/`describe-meal`/`analyze-meal-photo`.
- **Correction to prior project memory**: memory states "coach insights NOT metered." Current
  code contradicts this for the Formula Kit "ai-coach" insight function — it DOES call
  `ensureAndCheckCredits(..., 'ai-coach')` unless a deterministic rules-based insight
  short-circuits it (free, no credit check). Re-verify with Lee if designing new insight-style
  surfaces.

### 1.14 Carb loading, onboarding_surveys, content system — quick hits

- **`onboarding_surveys`** — captures, once per user: `sports` (list of `OnboardingSport`),
  `goals` (list of `OnboardingGoal`), `pitfalls` (list of `OnboardingPitfall`), plus a free-form
  `survey_payload` jsonb explicitly documented as "extend this instead of adding columns" (e.g.
  `tridot_notify`, `sweat_test_interest`, `declined_training_apps`, `connected_provider`). One row
  per user (`user_id` is the PK). `OnboardingSurveyRepository` follows the same offline-first
  local-write + non-blocking upload pattern as `formula_pins`, and correctly uses `onConflict:
  'user_id'` (a real PK — compliant with the partial-index gotcha).
- **Content system** — `lib/features/content/application/content_service.dart`
  (`ContentService`): in-memory `AppContent?` cache for synchronous reads.
  `getValue(String key, {String? defaultValue})` is **synchronous** with a triple fallback: cached
  value → provided default → the key itself as literal text. `initialize()` loads cache-or-
  defaults synchronously, then kicks off a non-blocking background refresh
  (`_checkForUpdatesInBackground`). Backed by Supabase `app_content` (`content jsonb`, versioned,
  environment/locale-scoped) with a hierarchical keyspace: `ui_text.*` for copy, `algorithm.*` for
  tunable nutrition parameters ("fat backend" — params change without a deploy). Per project
  memory, `app_content` is currently **empty on dev**, so the `defaultValue` fallback is
  load-bearing there today. Any new meal-planning UI copy must go through `ContentKeys` +
  `ContentService.getValue`, never a hardcoded string (see §5).

---

## 2. Data model

Source: `docs/dev_schema.txt` / `docs/prod_schema.txt` (live schema dumps, most current source —
more authoritative than individual migration files, which have mostly been squashed/archived).

### `recipes`
```
id uuid PK, name text, description text, ingredients jsonb, instructions jsonb,
prep_time_minutes int, servings int, type text CHECK IN (breakfast, mains, snacks,
workout_fuel, recovery), calories/carbs_g/protein_g/fat_g/fiber_g/sugar_g/sodium_mg numeric,
image_url text, tags jsonb, is_active bool, created_at, updated_at
```

### `meal_logs`
```
id uuid PK, user_id uuid, log_date date, slot text CHECK IN (breakfast, lunch, dinner, snack),
name text, source text CHECK IN (photo, manual, describe, saved, recipe, jade_baseline),
items jsonb, calories int, carbs_g/protein_g/fat_g/sodium_mg numeric, photo_path text,
recipe_id uuid (soft ref, no FK), saved_meal_id uuid (soft ref, no FK), notes text,
eaten_at timestamptz, created_at, updated_at, is_deleted bool
```

### `saved_meals`
```
id uuid PK, user_id uuid, name text, items jsonb, calories int,
carbs_g/protein_g/fat_g/sodium_mg numeric, photo_path text, last_used_at timestamptz,
created_at, updated_at, is_deleted bool
```

### System formula/template tables ("the 3 template tables" — pre/during/post)

**`pre_workout_templates`**:
```
id uuid, name text, base_category text, time_window text (display-only — see gotcha below),
digestion_speed text CHECK IN (Fast, Medium), allergens text[], serving_unit text,
min_servings/max_servings numeric, plus_banana bool, plus_sports_drink bool, notes text,
is_active bool, carbs_per_serving numeric default 25, protein_per_serving/fat_per_serving/
sodium_mg/fluid_ml numeric, template_type text CHECK IN (food, drink, electrolyte),
component_food_names text[], component_quantities jsonb, excluded_diets text[],
is_indivisible bool default true, fiber_per_serving numeric,
sub_phase text CHECK IN (full_meal, snack, top_up)  -- THE selection key per column comment
```
> **Gotcha (2026-08-05/06 incident, "Flat-50g scare"):** `time_window` is display-only —
> `sub_phase` is the actual selection key. Never string-match on `time_window`.

**`during_workout_templates`**:
```
id uuid, template_number int, name text, formula text, food_form text,
activity_types text[], duration_brackets text[], gut_training_levels text[],
component_food_names text[], component_carb_ratios jsonb, primary_to_secondary_ratio text,
allergens text[], excluded_diets text[], notes text, is_active bool,
selection_priority int
```

**`post_workout_templates`**:
```
id uuid, template_number int, name text, formula text, recovery_window text, recovery_type text,
activity_types text[], workout_intensity text[], component_food_names text[],
component_ratios jsonb, target_carb_protein_ratio text, allergens text[], excluded_diets text[],
notes text, is_active bool, travel_friendliness text CHECK IN (in_bag, cooler_friendly,
home_only), flavor_profile text, prep_effort text CHECK IN (grab_and_go, assemble, cook),
protein_anchor text, carb_sources text[], portions text, selection_priority int,
default_servings jsonb
```

**`personal_formulas`** (user-authored, phase-generic):
```
id uuid, user_id uuid, name text, provenance text CHECK IN (forked_formula,
from_scratch_formula), phase text CHECK IN (before, during, after), source_template_id uuid,
source_template_kind text CHECK IN (pre_system, during_system, post_system), sub_phase text,
digest_speed text, activities jsonb, durations jsonb, gut_training text,
travel_friendliness text, components jsonb, notes text,
total_carbs_g/protein_g/fat_g/sodium_mg/fluids_ml/calories int, created_at, updated_at,
is_deleted bool, coach_insight_text text, coach_insight_marker text
```

**`personal_templates`** (legacy, before/during only):
```
id uuid, user_id uuid, name text, activity_type text, original_duration_minutes int,
original_distance numeric, original_activity_title text, plan_data jsonb,
total_carbs_g/protein_g/fat_g/sodium_mg/fluids_ml/calories int, brick_segment_order text[],
provenance text default 'legacy_plan' CHECK IN (legacy_plan, forked_formula,
from_scratch_formula), phase text CHECK IN (before, during) — nullable,
source_template_id uuid, sub_phase text, digest_speed text, activities jsonb, durations jsonb,
gut_training text, custom_food_ids jsonb (array into user_foods.id)
```

Also present: `templates` (older pre-workout-only table) and `template_foods` (the shared
ingredient catalog referenced by `component_food_names` — has `food_group` G1–G9, `allergens`,
`excluded_diets`, macro/serving columns, `max_per_hr_*` gut-training caps, `min_increment`,
`sodium_top_up_eligible`).

### `formula_pins`
```
id uuid, user_id uuid, template_id uuid (polymorphic, no FK), template_kind text CHECK IN
(pre_system, during_system, post_system, personal_formula), created_at, updated_at, is_deleted
```

### `user_foods`
```
id uuid, device_id text, client_food_id text, barcode text, name text,
display_name/display_name_plural text, description text, image_address text,
serving_amount numeric, serving_unit text, calories_per_serving int,
carbs_per_serving/protein_per_serving/fat_per_serving numeric(10,2), sodium_mg int,
fluid_ml_per_serving numeric(10,1), is_electrolyte bool, to_exclude_from_solver bool,
is_deleted bool, created_at, updated_at, client_updated_at, categories category_enum[],
user_id uuid, product_type product_type_enum, activity_types activity_type_enum[],
serving_size text
```
**No `allergens`/`excluded_diets` column** — see §1.4 gap.

### `food_preferences`
```
id uuid, user_id uuid, food_name text, preference text CHECK IN (like, dislike,
willing_to_try), created_at, updated_at, preference_level smallint default 1,
preference_source text CHECK (manual OR LIKE 'allergy:%' OR LIKE 'dietary:%')
```
Allergen/diet data on the user side is on `users.allergies allergy_enum[]` and
`users.food_preferences jsonb`, **not** in this table. On the food/catalog side:
`foods.allergens allergy_enum[]`, `foods.excluded_diets dietary_preference_enum[]`,
`template_foods.allergens/excluded_diets text[]`, `catalog_products.allergens/excluded_diets
text[]`, and template-level `allergens`/`excluded_diets` on pre/during/post_workout_templates.

### `events` (user) / `public_events`
```
events: id text PK, user_id uuid, activity_id text, event_type activity_type_enum,
event_subtype event_subtype_enum, event_name text, location text, registration_url text,
event_date date, start_time text, goal_time_minutes int, goal_pace_minutes_per_mile real,
predicted_finish_time_minutes int, has_carb_loading bool, carb_loading_days int CHECK IN
(1,2,3,7), carb_loading_start_date timestamp, has_nutrition_plan bool, bib_number text,
wave_start_time text, packet_pickup_info text, actual_finish_time_minutes int,
final_placement int, age_group_placement int, created_at, updated_at, needs_upload bool,
local_updated_at timestamp

public_events: id bigint PK, event_name text, event_type activity_type_enum,
event_subtype event_subtype_enum, location/city/state text, country text default 'USA',
event_date date, start_time time, registration_url/website_url text, description text,
organizer_name text, is_active bool, source text, external_id text, created_at, updated_at,
search_vector tsvector GENERATED (full-text over name/location/city/state)
```
Also present: `events_coverage`, `events_refresh_runs` (crawl-state for `/refresh-events`).

### Weather — **no dedicated table**
Weather is inline on `activities`: `weather_conditions text, temperature_fahrenheit int,
humidity_percent int`. No `weather*` table exists in dev or prod. Confirmed via the full
`CREATE TABLE` list (52 tables total).

### AI chat / Jade history
```
jade_conversations: id uuid, user_id uuid, title text, created_at, updated_at, is_deleted bool
jade_messages: id uuid, conversation_id uuid, user_id uuid, role text CHECK IN (user,
  assistant), content text, metadata jsonb, created_at
jade_calls: id uuid, user_id uuid, conversation_id uuid, function_name text, model text,
  input_tokens int, output_tokens int, created_at   -- Jade-specific usage ledger
```

### AI credits (no table literally named `ai_credits`)
```
token_wallets: user_id PK, balance int default 0 CHECK >=0, free_period text, created_at,
  updated_at
token_ledger: id uuid, user_id uuid, delta int, reason text, ref text, balance_after int,
  created_at   -- the transactions/ledger table
ai_usage: id uuid, user_id uuid, function_name text, model text, input_tokens int,
  output_tokens int, created_at, cost_usd numeric   -- general (non-Jade) AI cost log
```

### `daily_macro_targets` (not `daily_macros`)
```
id uuid, user_id uuid, target_date date, carb_g/prot_g/fat_g real, tdee/rmr real,
session_kcal real default 0, neat_kcal/tef_kcal real, mode text default 'prospective',
ea real, ea_status text, calculation_input jsonb, algorithm_version text default 'v4',
needs_upload bool, created_at, updated_at
```

### `nutrition_plan(s)` — **table does not exist**
Nutrition plan data is embedded as JSONB on `activities.nutrition_plan_data` (and
`activities.fuel_log_data` for actual consumption). A `plan_generation_log` audit table exists
(targets/delivered/shortfalls/pin_decision/warnings jsonb) but is a generation-run log, not plan
storage.

### `onboarding_surveys`
```
user_id uuid PK, sports jsonb, goals jsonb, pitfalls jsonb, survey_payload jsonb,
completed_at timestamptz, created_at, updated_at
```

### `app_content`
```
id uuid, version int, environment text default 'production', locale text default 'en',
content jsonb, is_active bool, created_at, updated_at, created_by, updated_by
```

### `carb_loading_*` (adjacent multi-day meal-slot precedent)
```
carb_loading_plans: id text, user_id uuid, event_id text, total_days int CHECK IN (1,2,3,7),
  start_date, end_date, daily_carb_target_grams, daily_calorie_target, generated_at,
  algorithm_version text default 'v1.0', adherence_score real CHECK 0-1, completed_at,
  needs_upload, local_updated_at, updated_at
carb_loading_days: id text, carb_loading_plan_id text, plan_date, day_number,
  carb_target_grams, calorie_target, meal_count default 6, per-meal % splits (breakfast/
  morning_snack/lunch/afternoon_snack/dinner/evening_snack), logged_carbs_grams,
  logged_calories, completed bool, carb_protocol_g_per_kg default 8.0, needs_upload,
  local_updated_at, updated_at
carb_loading_foods: id uuid, name, display_name(_plural)?, carbs_per_serving real CHECK>0,
  image_address?, is_default default true, meal_types text[]
carb_loading_user_foods: id uuid, device_id, client_food_id?, name, display_name(_plural)?,
  carbs_per_serving, image_address?, barcode?, source_food_id?/source_user_food_id? uuid,
  is_deleted, meal_types text[], user_id uuid
carb_loading_day_meals: id uuid, carb_loading_food_id?/carb_loading_user_food_id? uuid
  (CHECK exactly one set), food_display_name?, quantity default 1 CHECK>0,
  carbs_consumed real CHECK>=0, meal_type text, carb_loading_plan_id text,
  carb_loading_day_id text
```

### Other food-catalog tables worth knowing about
- **`nutrition_products`** — canonical multi-source barcode→nutrition master (USDA FDC, Open
  Food Facts, user-submitted); `resale_ok` generated column excludes ODbL-licensed OFF data.
- **`catalog_products`/`catalog_variants`** (+ `catalog_items` materialized view,
  `catalog_sync_runs`) — Shopify-sourced commercial nutrition catalog (TheFeed), with
  `allergens`/`excluded_diets`/`is_electrolyte`/`is_liquid` classification.
- **`foods`** — original global food catalog with allergen/diet arrays and
  `before/during/after_run_suitable` flags — largely superseded by `template_foods` but still
  present.
- **`food_sport_phases`** — junction table for sport+phase-specific food suitability overrides.
- **`race_checklist_items` (Drift only)** — race-day gear/nutrition/logistics checklist has
  **no remote table** — purely local. `ChecklistItem { id, eventId, userId, category,
  itemName, sortOrder, isChecked, checkedAt, notes, isTemplateItem, createdAt, updatedAt }`,
  categories `gear|nutrition|logistics|pre_race|race_morning`. `GearTemplateService` generates a
  gender/sport-aware starter list.

---

## 3. Edge functions relevant to a meal planner

All AI functions route through the **Vercel AI Gateway** (`npm:ai@6`, `AI_GATEWAY_API_KEY`
secret) — see `supabase/functions/_shared/ai/model.ts` for model constants:
```ts
AI_COACH_MODEL        = env AI_COACH_MODEL/JADE_MODEL, default 'anthropic/claude-sonnet-4.6'  // jade-chat
DESCRIBE_MEAL_MODEL   = 'anthropic/claude-sonnet-4.6'   // reverted from Haiku 4.5 2026-07-30 (quality)
ANALYZE_MEAL_PHOTO_MODEL = 'anthropic/claude-sonnet-4.6'
COACH_INSIGHT_MODEL   = 'anthropic/claude-sonnet-4.6'   // ai-coach mode:"insight"
```

- **`jade-chat`** (`supabase/functions/jade-chat/index.ts`) — the athlete-facing streaming chat
  the Flutter `ai_coach` feature calls. System prompt from `_shared/ai_coach/persona.ts
  buildSystemPrompt()`: persona "Mealvana," warm/direct endurance coach; explicit non-scope list
  (no training plans/pacing, no medical advice, ED-safety redirect to NEDA 1-800-931-2237, no
  calorie-shaming); **"Planning a day or week" section** instructing the model to call
  `getSavedMeals`/`getLoggedMeals` first (use the athlete's real foods, don't invent), then
  `getMacroTargets`/`getWorkouts`, then `showMealSuggestions` grouped by slot; a
  baseline-establishment branch triggers when the user has no `meal_logs` in the last 14 days.
  **Tools** (`_shared/ai_coach/tools.ts`, `makeAiCoachTools(ctx)`): `getUserProfile`,
  `getMacroTargets`, `getWorkouts`, `getUpcomingEvents`, `getLoggedMeals`, `getSavedMeals`,
  `getWeather`, `getInSeasonProduce`, `getSalesNearby` (grocery-sales lookup — currently a
  documented **backlog** stub, see comment `// Ref: Mealvana Endurance — grocery sales
  integration backlog`), `showMealSuggestions`, `askChoice`, `logBaselineMeal`. Credits:
  `ensureAndCheckCredits(serviceClient, user.id, 'jade-chat')` before streaming (402 if
  insufficient — credit check runs regardless of opener vs. normal turn);
  `debitForUsage(..., 'jade-chat')` in `onFinish`, real turns only. Persistence: user message
  saved before the model call; assistant reply + `ui_parts` metadata saved in `onFinish` via
  `EdgeRuntime.waitUntil`; also inserts a `jade_calls` row and calls `logAiUsage()` (the `ai_usage`
  ledger). NDJSON protocol: `{"type":"text","delta":...}`, `{"type":"ui","part":{...}}`,
  `{"type":"done"}`, `{"type":"error","message":...}`.
- **`ai-coach`** (`supabase/functions/ai-coach/index.ts`) — a **different function**, Formula
  Kit's personal-formula "coach insight" one-liner (`mode:"insight"` only today; envelope
  reserves `mode`+`tools` for a future chat mode). Deterministic short-circuit
  (`_shared/coach_insight/insight.ts computeNutritionState`/`buildDeterministicInsight`) answers
  obvious gaps without calling the model (free, `source:"rules"`); credits are checked
  (`'ai-coach'`, cost 1) only on the model path.
- **`describe-meal`** (`supabase/functions/describe-meal/index.ts`) — free-text description →
  structured `MealAnalysisSchema` via `generateObject`. Max 2000 chars. Credits gated/debited,
  cost 1.
- **`analyze-meal-photo`** (`supabase/functions/analyze-meal-photo/index.ts`) — photo →
  structured `MealAnalysisSchema`; 422 if the model flags `not_food`. Credits gated, cost 1.
- **`generate-nutrition-plan-v3`** (`supabase/functions/generate-nutrition-plan-v3/index.ts`) —
  **not** an LLM feature; deterministic algorithmic before/during/after solver (template
  matching, LP fallback, brick handling). No credits, no model calls — the pattern to follow for
  any *deterministic* portion of a meal planner (e.g. macro-target-driven slot sizing) that
  shouldn't cost AI credits.
- **`ensure-credits`** (`supabase/functions/ensure-credits/index.ts`) — wallet provisioning +
  monthly free-grant RPC, called by `CreditsRepository.ensureWallet()`.
- **`_shared/ai/credits.ts`** — the shared metering module every AI edge function must import
  (`ensureAndCheckCredits`, `debitForUsage`, `creditCost`, `insufficientCreditsBody`,
  `CREDITS_ENFORCED`, `FREE_MONTHLY_CREDITS`). A new meal-planning AI endpoint should follow this
  exact call shape.
- **`_shared/nutrition/templates/diet-filter.ts`** — `filterTemplatesByDiet`/`filterDrinksByDiet`,
  the server-side allergen/diet exclusion logic mirrored client-side by `ClientFoodPoolService`.
- **`search-catalog`**, **`lookup-product`** — barcode/text product search over
  `catalog_products`/`nutrition_products` (used by barcode scanning + manual food entry); a
  planner adding "search for a food to add to a meal slot" would reuse these rather than
  building new search.

---

## 4. Prior meal-planning roadmap / design work

**`docs/_archived/mealplanning_prototype/`** — a 9-file, ~9,800-line body of prior design work
from an earlier attempt to build a **standalone web prototype** (not this Flutter app) for meal
planning. `docs/README.md` explicitly flags this directory as archived/superseded — nothing there
should be trusted as current architecture without re-verification — but the **product thinking is
still highly relevant**:

- **`01_meal_planning_landscape.md`** + **`01a_top_picks_summary.md`** — a 40+-app competitive
  survey. Names a 6-paradigm taxonomy (recipe library, questionnaire→static plan, parameter→
  generate→swap, training-calendar→carb-prescription→log, chatbot, card-stack-with-
  substitutions) and lands on the thesis: **no existing app bridges "you need 240g carbs today" to
  "here are 3 actual meals" without recipes** — that gap is the product opportunity. One-line
  design principle: *"solve what to eat today given today's training — without recipes or
  chatbots — using simple ingredient assemblies."* This directly informed the existing
  `kQuickAssemblies` static catalog in `meal_logging` (§1.2) and the "components not recipes"
  framing that should carry forward.
- **`02_me_website_new_stack.md`** — stack notes for a *different* prototype repo
  (TanStack Start + Convex + Clerk) — **not applicable to this Flutter/Supabase app**, included
  only for completeness.
- **`03_kyle_design_for_web.md`** — Kyle brand tokens translated to web (colors, type, spacing) —
  useful if a web meal-planning surface is ever built, but the Flutter app already has its own
  Kyle design system (`lib/shared/widgets/kyle_design/`) which is the actual source of truth here.
- **`04_user_data_inventory.md`** — an earlier data audit that flagged the exact gaps this
  feature needs to fill: **no meal-logging/food-diary table, no actual-vs-planned fuel tracking,
  no meal-timing preferences, coarse allergy model.** The first gap has since been closed (this
  doc's §1.2 `meal_logs`/`saved_meals` now exist) — the rest remain open, see §6.
- **`05_design_proposal.md`** — the master single-design spec (later split into 5 variants by
  file 06). Proposes new tables **`meal_plans`** (`id, user_id, week_start, coach_strip,
  generation_model, input_hash`) and **`meal_plan_meals`** (`slot` enum incl.
  pre/during/post_workout, `components` jsonb, `totals` jsonb, `locked` bool, `template_table`/
  `template_id` FK) — this is the **direct conceptual ancestor of what actually shipped** as
  `meal_logs`/`saved_meals` (§1.2/§2), though those shipped as a retrospective log, not a
  forward-planning grid. Explicit v1 **out-of-scope list**: pantry scanning, grocery list export,
  social/coach view, recipe steps, photo upload, meal logging/adherence tracking, race-calendar
  phasing, intra-day adaptation, custom meal templates ("My Rotation") — useful as a scope
  reference even though this was written for a different stack.
- **`06_five_uiux_approaches.md`** — 5 parallel UI variants (Calendar grid / Swipe stack / Column
  picker / Hybrid split-screen / Full chatbot) sharing one AI persona spec ("Jade" — since renamed
  to "Mealvana AI" in this app, commit `74165b52`) and one tool set nearly identical to what
  `jade-chat` ships today (`listFoods`, `listTemplates`, `getActivities`, `getMacroTargets`,
  `getUserPrefs`) — strong signal the current `jade-chat` tool set was directly informed by this
  design work.
- **`07_parallel_build_plans.md`** — pure process/worktree playbook for building the 5 variants in
  parallel; low product-content value beyond confirming variant names.
- **`08_landscape_supplement.md`** — deep-dive on AI coach personas (Noom's Welli, MacroFactor's
  KettleBot, HealthifyMe's Ria, Ollie's "chat-in-grid" pattern) and **5 recurring chatbot failure
  modes**: memory/context amnesia, decision fatigue transferred into the chat itself, the "Regen
  Trap" (full regen wipes locked work), scope overflow into medical advice, opaque confidence
  (can't tell personalized vs. generic). Directly relevant to `jade-chat`'s persona design.
- **`09_figma_analysis_and_widgets.md`** — decomposes an actual Kyle Figma "AI Assistant" flow
  (28 screens) into a 30-widget generative-UI catalog (`WIDGET_REGISTRY` pattern — tool-call →
  React component). The Flutter app's `AiCoachUiPart` sealed-class + `meal_cards`/`choices`
  pattern (§1.12) is the same architecture in miniature, with 2 of the ~30 proposed widgets built
  so far.

**`docs/database/meal_logging_jade_schema.sql`** (2026-06-11, 325 lines) — the schema that
**actually shipped**, confirming this doc's §2 tables (`meal_logs`, `saved_meals`, `recipes`,
`jade_conversations`, `jade_messages`, `jade_calls`, plus `meal-photos`/`recipe-images` storage
buckets). Its own header notes: "design follows the mealplanning_prototype web build adapted to
mobile" — i.e. it is the mobile-adapted, retrospective-logging subset of what file `05` proposed;
the forward-planning `meal_plans`/`meal_plan_meals` half was never built.

**Other roadmap signals found across `docs/`:**
- `docs/features/revenue_cat/{README,SETUP_GUIDE,implementation_roadmap}.md` — **"Meal planning"
  and "recipe import" are already scoped as Pro-tier (paid) monetization features** in the
  pricing model — relevant to how a new meal-planning feature should be paywalled.
- `docs/features/carb_loading/carb_loading.md` §3 "Shopping List" + `roadmap.md` — a pre-existing,
  separate shopping-list spec (grocery delivery integration, export formats, error handling) —
  read directly before designing a new shopping list.
- `docs/features/coach_mode/scenario-{structured,unstructured}.md` — coach-mode chat scenarios
  reference a "Generate Shopping List" button and "Weekly Training Meal Plan" as illustrative
  AI-coach outputs (not built, but describes an adjacent desired UX).
- `docs/_archived/contacts/henry_shoemaker.md` — real user-interview signal: the contact's pain
  point is explicitly "**daily** meal planning, not race day" — direct validation for this
  feature's problem space.
- `docs/_archived/design/ai_dietitian_ux.md` — an early, separate "AI Dietitian" persona sketch
  ("knows your training schedule, body composition, race-day weather, and what's in your
  pantry") that predates "Jade"/Mealvana AI.
- `docs/release/app_store_screenshots/LISTING_COPY.md` — App Store listing copy already
  references "meal planner, grocery lists" as an app feature (aspirational, not yet shipped).
- `docs/new_mealplanning/notion/` — 5 files (feature-discussion, interview-insight rounds,
  preference-test-plan, roadmap-card, user-interview-synthesis) exist but are **out of scope for
  this doc** (owned by another agent) — flagged here only so this doc's reader knows to cross-
  reference them.

---

## 5. Constraints a meal-planning feature must respect

From `CLAUDE.md` and `/docs`:

- **Offline-first, local-first writes.** Any new user-editable meal-plan entity should follow the
  `needs_upload`/`local_updated_at` + soft-delete (`is_deleted`) convention used by every
  offline-first table in this repo (`meal_logs`, `personal_formulas`, `user_foods`, `events`,
  `carb_loading_*`) — never hard-delete, and preserve local-first writes for athlete self-service
  flows (`docs/technical/sync-architecture.md`).
- **`SyncableRepository` + repository-level `ensureSynced`, not startup sync-all.** New
  repositories implement `repositoryKey`, `dependencies`, `syncFromRemote`, `uploadDirtyRecords`,
  and call sync on-demand from a controller's `build()` — never a global sync-all
  (`docs/technical/sync-architecture.md`; `lib/shared/data/syncable_repository.dart`). Default
  staleness is 1h; override it (as `recipes`/formula templates do at 24h) when content changes
  rarely.
- **FOA layers strictly enforced**: `presentation -> application -> domain <- data`. Screens are
  UI-only (state, navigation, composition, validation); business logic (API calls, transforms,
  calculations, analytics) lives in controllers/services. Controllers **must** use `@riverpod` +
  `AsyncNotifier` + `AsyncValue.guard()` (`docs/technical/foa-architecture.md`) — the
  `MealLogController`/`AiCoachChatController`/`DailyMacrosController` pattern is the template to
  copy.
- **No hardcoded user-facing strings** when the content system exists — go through
  `ContentService.getValue(ContentKeys.xxx, defaultValue: ...)`, not literal strings in widgets
  (§1.14). New meal-planning copy needs new `ContentKeys` entries and `app_content` seed data.
- **Use `MealvanaSnackbar`** (`lib/shared/widgets/kyle_design/feedback/mealvana_snackbar.dart`) —
  never a raw Flutter `SnackBar`.
- **Write-consistency policy** (`docs/technical/write-consistency-policy.md`): athlete
  self-service writes to their own meal plan stay `offline_first`. If a meal-planning feature ever
  supports **coach-on-athlete** writes (e.g. a coach assigning a plan to an athlete), that write
  must be `remote_ack_required` — success toast/navigation only after server acknowledgment, per
  the existing pattern for activities/events/carb-loading coach writes.
- **AI credits policy** (§1.13, §3): any new AI-generated meal-suggestion call must be gated
  through `ensureAndCheckCredits`/`debitForUsage` with a registered cost in
  `_shared/ai/credits.ts` `DEFAULT_COSTS`, exactly like `jade-chat`/`describe-meal`/
  `analyze-meal-photo`. Never call an AI Gateway model from an edge function without this gate.
- **PostgREST partial-unique-index gotcha**: never `onConflict` on a column backed by a partial
  unique index (fails 42P10) — always `onConflict: 'id'` (or a real full PK, as
  `onboarding_surveys` correctly does with `'user_id'`). And `uploadDirtyRecords()` swallows
  exceptions into a silent `UploadResult.failed()` — **always check the result**, don't assume
  success.
- **`time_window` vs `sub_phase` gotcha** (§2): if a meal planner ever reads `pre_workout_
  templates` directly, select on `sub_phase`, never string-match `time_window` (display-only).
- **`user_foods` allergen bypass** (§1.4): don't let a meal-planner-created custom food silently
  skip allergen filtering — either add allergen tagging to `user_foods` or exclude custom foods
  from AI-suggested meals until it's fixed.
- **Don't run `flutter build`** as assistant execution; run codegen after Riverpod/Drift
  annotation or schema changes; run `/task-checker` after major changes and before commit.

---

## 6. Gaps

What does **not** exist yet that a batch-cooking, chat-forward meal planner with a shopping list
and log-from-plan needs:

- **No forward-looking plan storage.** `meal_logs`/`saved_meals` are retrospective (what was
  eaten) and reference (favorites), not a plan for a future day/week. Nothing like the archived
  prototype's proposed `meal_plans`/`meal_plan_meals` tables exists. A real planner needs a new
  table (or a `MealSuggestion`-shaped `planned` status added to something close to `meal_logs`)
  representing "this meal is scheduled for this slot on this future date, not yet eaten," plus a
  distinct `MealLogSource`/provenance value for "logged from a plan" (today only
  `jade_baseline` hints at AI-generated plan content, and it's not wired to any UI).
- **No weekly/multi-day view at all.** Every existing screen (`log_meal_screen.dart`,
  `recipes_screen.dart`, `carb_loading_day_detail_page.dart`) is single-day or single-item. There
  is no "week grid" component, no day-to-day navigation for a plan, and no `AiCoachUiPart` kind
  for rendering a multi-day plan in chat (only single meal-suggestion cards and choice buttons
  exist today — §1.12).
- **No shopping/grocery list feature for meal planning.** `carb_loading` has its own separate,
  older shopping-list spec (`docs/features/carb_loading/carb_loading.md` §3) that's worth reusing
  or adapting, but there's no shared "aggregate ingredients across N planned meals into a grocery
  list" service, no grocery-list table, and `getSalesNearby` in `jade-chat`'s tool set is an
  explicitly documented **backlog stub** (grocery-sales lookup, not implemented).
- **No batch-cooking / meal-prep concept.** Nothing in the domain model represents "cook once,
  eat across N slots/days" — `Recipe.servings` exists but nothing tracks portioning a single
  cooked batch across multiple future `MealLog`/planned-meal rows, and there's no "leftover"
  tracking.
- **No pantry/inventory tracking.** No table or feature tracks what a user already has on hand;
  `docs/_archived/design/ai_dietitian_ux.md` sketched "knows what's in your pantry" as a concept,
  never built. Fridge/pantry-scan-to-plan (flagged in the archived landscape survey as a gap no
  competitor has closed either) doesn't exist.
- **Recipe favorites are stubbed out** (§1.1) — `RecipeRepository.getFavoriteRecipes()`/
  `toggleFavorite()` are no-ops. A planner that wants to suggest from favorited recipes needs this
  built first (or route through `saved_meals` instead, which does support favorites).
- **`Recipe.ingredients`/`instructions` are unstructured strings**, not `MealComponent` objects —
  unlike `MealLog`/`SavedMeal`, a recipe can't be macro-aggregated or partially swapped
  ingredient-by-ingredient without a parsing step. Structuring recipes onto `MealComponent` (or a
  richer shape) would let a planner treat recipes and manually-assembled meals uniformly.
- **No meal-timing preferences.** Flagged as a gap in the 2026-05 data-inventory audit and still
  true — nothing captures "I eat breakfast at 6am" / "I skip lunch on hard days," which a
  training-load-aware planner needs to place meals sensibly around workouts.
- **No day-level weather for meal planning.** `WeatherForecast` is cached per-activity (§1.9),
  1h/24h TTL, not fetched or cached at day granularity — a planner wanting "hot day → different
  electrolyte guidance across all meals" needs a new fetch/cache path, not just the activity-level
  one.
- **`food_preferences` upload has no per-row dirty flag** (§1.7) — every save re-uploads the
  user's entire preference set. Fine at today's scale; worth knowing before a planner starts
  writing preferences at higher frequency (e.g. "thumbs down" on an AI-suggested meal).
- **No "regenerate one slot without disturbing the rest of the plan" primitive.** The closest
  analog is `swap_food_screen.dart`'s in-plan food substitution for a single workout's nutrition
  plan (§1.6) — worth studying as a UX pattern, but nothing generalizes it to a multi-meal daily/
  weekly plan. The archived landscape survey specifically calls this failure mode out as the
  "Regen Trap" (§4) — a full regenerate that wipes locked/accepted choices — as a known chatbot
  pitfall to avoid.
- **`personal_templates`/`personal_formulas` are workout-fueling-scoped only** (before/during/
  after a specific activity), not meal-slot-scoped (breakfast/lunch/dinner/snack across a
  training-neutral day) — a daily meal planner needs its own selection/scoping model, it can't
  directly reuse Formula Kit's phase-based scope filters as-is.
