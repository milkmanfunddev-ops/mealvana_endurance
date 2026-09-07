# Repo research — meal library consistency

## 1. QuickAssembly catalog (`lib/features/meal_logging/domain/quick_assembly.dart`)

10 fixed two-ingredient (mostly) combos, lightest → most substantial. Each `MealComponent` has name, portion, calories, carbG, proteinG, fatG (macros satisfy `calories ≈ carb*4 + protein*4 + fat*9`).

1. **Banana + peanut butter** 🍌 — Banana 1 medium (105 kcal/27C/1.3P/0.4F); Peanut butter 1 tbsp (94/3.2/4.0/8.0)
2. **Greek yogurt + honey** 🍯 — Greek yogurt 3/4 cup (100/6/17/0.7); Honey 1 tbsp (64/17/0.1/0)
3. **Rice cake + almond butter** 🌾 — Rice cake 2 cakes (70/15/1.4/0.6); Almond butter 1 tbsp (98/3/3.4/9)
4. **Oatmeal + raisins** 🥣 — Rolled oats 1/2 cup dry (150/27/5/2.5); Raisins 2 tbsp (54/14/0.6/0.1)
5. **Eggs + toast** 🍳 — Eggs 2 large (140/1.2/12/10); Whole-grain toast 2 slices (138/26/6/2)
6. **Cottage cheese + fruit** 🍓 — Cottage cheese 1/2 cup (110/6/14/2.5); Mixed berries 1/2 cup (40/9/0.6/0.3)
7. **Protein shake + banana** 💪 — Whey protein shake 1 scoop in water (130/4/25/2); Banana 1 medium (105/27/1.3/0.4)
8. **Chocolate milk** 🥛 — Low-fat chocolate milk 1 cup/240ml (158/26/8/2.5) — single component
9. **Apple + cheese** 🍎 — Apple 1 medium (95/25/0.5/0.3); Cheddar cheese 1 oz/28g (113/0.4/7/9)
10. **Date energy balls** ⚡ — Medjool dates 3 dates (201/54/1.8/0.3) — single component

## 2. Common ingredients (`lib/features/meal_logging/domain/common_ingredients.dart`)

~40-item single-ingredient library (`kCommonIngredients`), USDA-representative per-serving macros incl. sodium, grouped:
- **Protein**: Chicken breast (4oz/115g), Ground turkey 93/7 (4oz), Salmon (4oz), Egg (1 large), Egg whites (1/2 cup), Greek yogurt plain (3/4 cup), Cottage cheese (1/2 cup), Tuna canned in water (3oz drained), Turkey deli slices (3oz), Tofu firm (4oz), Whey protein powder (1 scoop)
- **Grains & starches**: Rolled oats (1/2 cup dry), White rice cooked (1 cup), Brown rice cooked (1 cup), Quinoa cooked (1 cup), Sweet potato (1 medium baked), Potato (1 medium baked), Whole wheat bread (1 slice), Pasta cooked (1 cup), Flour tortilla (1 medium 8")
- **Fruit**: Banana, Apple, Blueberries (1 cup), Strawberries (1 cup sliced), Orange
- **Vegetables**: Broccoli (1 cup cooked), Spinach (2 cups raw), Mixed greens salad (2 cups), Avocado (1/2 medium)
- **Legumes**: Black beans cooked (1/2 cup), Chickpeas cooked (1/2 cup), Lentils cooked (1/2 cup), Hummus (2 tbsp)
- **Dairy & fats**: Milk 2% (1 cup), Almond milk unsweetened (1 cup), Cheddar cheese (1 oz), Mozzarella cheese (1 oz), Almonds (1 oz/~23), Peanut butter (1 tbsp), Almond butter (1 tbsp), Olive oil (1 tbsp), Butter (1 tbsp)
- **Sweeteners**: Honey (1 tbsp), Maple syrup (1 tbsp)

Note: this file explicitly calls itself an "interim dataset" pending a USDA-backed searchable ingredient table.

## 3. Seeded recipes / saved meals / food catalog

### Existing recipe seed data — `docs/database/recipes_seed.sql` ("Curated Recipe Catalog Seed Data v2")
30 recipes seeded into `public.recipes`, split into 5 categories (`type` CHECK): **breakfast (6)**, **mains (8)**, **snacks (5)**, **workout_fuel (5)**, **recovery (6)**. This is the closest existing analog to the ~400-meal library being built — match its tone/format/portion style. Representative entries:
- Breakfast: Overnight Oats with Banana & Honey; Avocado Egg Toast with Everything Seasoning; Overnight Steel-Cut Oats with Chia & Berries; Greek Yogurt Parfait with Granola & Berries; Banana Protein Pancakes; Smashed Avocado Toast with Smoked Salmon
- Mains: Simple White Pasta with Marinara & Chicken; Whole Wheat Pasta with Turkey Bolognese; Quinoa Power Bowl with Chickpeas & Tahini; Salmon Sushi Bowl; Black Bean & Sweet Potato Tacos; Red Lentil & Vegetable Soup; Teriyaki Chicken Rice Bowl; Egg & Veggie Scramble
- Snacks: Rice Cakes with Almond Butter & Jam; Cottage Cheese & Pineapple Bowl; Banana & Date Energy Smoothie; Apple Slices with Peanut Butter; Sourdough Toast with Honey & Peanut Butter
- Workout fuel: Homemade Honey & Salt Energy Gel; Salted Onigiri Rice Balls; Medjool Date & Sea Salt Bites; Banana & Rice Peanut Butter Chews; White Rice & Banana Bowl
- Recovery: Chocolate Milk Recovery Shake; Chicken & Brown Rice Recovery Bowl; Baked Salmon & Sweet Potato Recovery Bowl; Tart Cherry & Protein Recovery Smoothie; Turkey & Avocado Recovery Wrap; Warm Spiced Oat & Protein Porridge

Each row has: `id, name, description, ingredients (jsonb string array), instructions (jsonb string array), prep_time_minutes, servings, type, calories, carbs_g, protein_g, fat_g, fiber_g, sugar_g, sodium_mg, image_url, tags (jsonb string array), is_active, created_at, updated_at`. Macro sanity rule stated in the file: `calories ≈ (carbs_g*4)+(protein_g*4)+(fat_g*9)`, all values **per serving**. Tags are freeform strings (e.g. `["overnight","high-carb","make-ahead","banana","meal-prep"]`) — **no allergen/diet tag columns on `recipes` today** (see gap below).

### Table shapes (from `docs/database/meal_logging_jade_schema.sql` + Drift mirrors)

**`recipes`**
```
id uuid PK, name text, description text default '', ingredients jsonb (string array),
instructions jsonb (string array), prep_time_minutes int default 0, servings int default 1,
type text CHECK IN ('breakfast','mains','snacks','workout_fuel','recovery'),
calories/carbs_g/protein_g/fat_g/fiber_g/sugar_g/sodium_mg numeric default 0,
image_url text, tags jsonb (string array, nullable),
is_active bool default true, created_at, updated_at
```
RLS: authenticated users can SELECT where `is_active`; no insert/update/delete policy — **content is service-role-managed only**, i.e. the new 400-meal library would land here via a seed migration exactly like `recipes_seed.sql`.

**`saved_meals`** (user favorites, not seed content)
```
id uuid, user_id uuid, name text, items jsonb (array of food components),
calories int, carbs_g/protein_g/fat_g/sodium_mg numeric, photo_path text,
last_used_at timestamptz, created_at, updated_at, is_deleted bool
```

**`meal_logs`** (retrospective, what was eaten)
```
id uuid, user_id uuid, log_date date, slot text CHECK IN ('breakfast','lunch','dinner','snack'),
name text, source text CHECK IN ('photo','manual','describe','saved','recipe','jade_baseline'),
items jsonb, calories int, carbs_g/protein_g/fat_g/sodium_mg numeric, photo_path text,
recipe_id uuid (soft ref), saved_meal_id uuid (soft ref), notes text, eaten_at timestamptz,
created_at, updated_at, is_deleted bool
```

**`foods`** master catalog (`lib/shared/database/tables/foods_table.dart`) — this is the table that already carries the exact allergen/diet tagging scheme:
```
id uuid, name, image_address, created_at, serving_amount,
max_servings_before/during/after int, categories text[] (category_enum), activity_types text[],
sodium_mg/caffeine_mg/potassium_mg int, fat_per_serving/carbs_per_serving/protein_per_serving real,
calories_per_serving int, fluid_ml_per_serving real,
show_in_preferences bool, is_electrolyte bool, to_exclude_from_solver bool, is_essential bool,
display_name/display_name_plural, serving_description, description, instructions,
nutritional_info jsonb, serving_unit/serving_unit_plural/serving_qualifier/serving_size,
product_type_id, purchase_url, affiliate_source, preference_priority,
allergens text[] default '{}' -- values: dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts
excluded_diets text[] default '{}' -- values: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb
```

No archived catalog seed SQL specifically for `recipes` other than `recipes_seed.sql`; other seed files under `supabase/migrations/_archived/` (`20251008000001_seed_carb_loading_foods.sql`, `20251008000003_seed_core_data.sql`, `20251214130000_populate_food_allergens_and_diets.sql`, `20260212000002_seed_template_data.sql`) seed the `foods`/`carb_loading_foods`/`template_foods` catalogs and the `allergens`/`excluded_diets` population, not recipes — useful precedent for how allergen/diet arrays get populated in bulk if needed, but not meal content itself.

## 4. Food preferences / allergen enforcement

Two separate, only-loosely-coupled mechanisms (per `docs/new_mealplanning/repo/repo-context.md` §1.7 and `lib/shared/database/tables/food_preferences.dart`):

- **`food_preferences` table** (per-food like/dislike, NOT allergen data itself):
  ```
  id, user_id, food_name text, preference text CHECK IN ('like','dislike','willing_to_try'),
  preference_level int 0-4 default 2, preference_source text default 'manual'
    -- 'manual' | 'allergy:{name}' | 'dietary:{name}'
  created_at, updated_at
  ```
  Choosing an allergy/diet during onboarding **auto-sets a `dislike` preference** on matching foods via `saveFoodPreferences(source: 'allergy:gluten' | 'dietary:vegan' ...)`; removing it undoes via `removeFoodPreferencesBySource`. This is a *derived* row, not a source of truth for allergen data.
- **Actual allergen/diet source of truth is on the food-catalog side**, as array columns: `foods.allergens allergy_enum[]`, `foods.excluded_diets dietary_preference_enum[]`; same pattern on `template_foods`, `catalog_products`, and all three workout-template tables (`pre/during/post_workout_templates.allergens` / `.excluded_diets`). The user's own allergy list lives on `users.allergies allergy_enum[]` (not in `food_preferences`).
- **Enforcement is matching, not tagging on the meal**: server-side, `supabase/functions/_shared/nutrition/templates/diet-filter.ts` (`filterTemplatesByDiet`, `filterDrinksByDiet`) excludes a template if `excluded_diets` contains the user's `dietary_preference`, or `allergens` overlaps the user's `allergies`. Client-side, `ClientFoodPoolService` does the equivalent filtering. **`user_foods` is exempt from this filter today** — a known gap.
- Implication for the meal library: give each meal an `allergens text[]` and `excluded_diets` (or `diets_ok`) array using the **exact enum values** already in use — Allergens: `dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts`; Diets: `omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb` — matching the brief's hard constraints exactly, and matching the codebase's existing enum values.
- Note: `docs/business_logic/food-preferences-system-overview.md` describes an older/legacy `device_id`-based scheme (`upsert_food_preferences`, `+20/+5/0` scoring) that predates the `user_id` + allergen-array model above — the current source of truth is the `foods`/template `allergens`/`excluded_diets` columns plus `diet-filter.ts`, not that doc's device-based flow.

## 5. Daily macro target model (`calculate-daily-macros` edge function, v4.0.0)

Per `supabase/functions/calculate-daily-macros/README.md` and `formulas/baseline.ts`:

- **Baseline (Iteration 1)**: `carb_g = 4.0 × weight_kg`, `protein_g = 1.8 × lbm_kg` (or `1.4 × weight_kg` if LBM unknown), `fat_g = 1.2 × weight_kg` as a starting point before session/context adjustments; fat is ultimately calculated as a residual from TDEE with a 0.8 g/kg floor.
- **Protein bumps**: `+0.3 g/kg` for strength sessions, `+0.2 g/kg` for endurance sessions >1hr.
- **Clamped final ranges**: `carb_g` clamped to **3.0–12.0 g/kg**, `protein_g` clamped to **1.2–2.5 g/kg**.
- **Pre-load override** (race day or high TSS): **9.0 g/kg carb**; moderate pre-load: **+1.5 g/kg**.
- **Masters adjustment**: protein ×1.15 for athletes 45+.
- Worked examples from the README:
  - **Rest day** (75kg, desk lifestyle, no sessions): `carb_g: 300` (~4.0 g/kg), `prot_g: 115` (~1.53 g/kg).
  - **Hard training day** (75kg, 1.5h running session): `carb_g: 369` (~4.9 g/kg), `prot_g: 130` (~1.73 g/kg).
  - **Pre-race carb loading** (75kg, peak phase + tomorrow-is-race): `carb_g: 798` (~10.6 g/kg), `prot_g: 159` (~2.1 g/kg).
- This matches the brief's sports-nutrition anchors (5–8 g/kg training-day carbs, up to 10-12 g/kg carb-load; 1.6–2.2 g/kg protein) closely enough to use as-is — the app's clamp ceiling (12 g/kg carb, 2.5 g/kg protein) is slightly wider than the brief's anchor range, so staying inside the brief's numbers is safe.
- (The `docs/business_logic/macro-formulas-audit.md` and `nutrition-plan-v3-algorithm.md` files are about **pre/during/post-workout formula selection**, not the daily target model — see item 6.)

## 6. Pre/during/post-workout "formula" template structure (tagging scheme to mirror)

Confirmed identical tagging pattern across all three system template tables (Drift table defs + `docs/new_mealplanning/repo/repo-context.md` §2):

- **`pre_workout_templates`**: `allergens text[]`, `excluded_diets text[]`, plus `sub_phase CHECK IN (full_meal, snack, top_up)` as the real selection key (NOT `time_window`, which is display-only — flagged as a past incident/"gotcha"), `digestion_speed CHECK IN (Fast, Medium)`, `template_type CHECK IN (food, drink, electrolyte)`, `component_food_names text[]`, `component_quantities jsonb`, `carbs_per_serving` (default 25), `protein_per_serving/fat_per_serving/sodium_mg/fluid_ml`, `fiber_per_serving`, `is_indivisible bool`.
- **`during_workout_templates`** (`lib/shared/database/tables/during_workout_templates_table.dart`): `allergens text[]` default `[]`, `excluded_diets text[]` default `[]`, plus `activity_types text[]`, `duration_brackets text[]` (e.g. `["90-150 min","150-240 min"]`), `gut_training_levels text[]`, `food_form text`, `component_food_names text[]`, `component_carb_ratios jsonb`, `selection_priority int`.
- **`post_workout_templates`** (`lib/shared/database/tables/post_workout_templates_table.dart`): `allergens text[]` default `[]`, `excluded_diets text[]` default `[]`, plus `activity_types text[]`, `component_food_names text[]`, `component_ratios jsonb`, `default_servings jsonb`, `target_carb_protein_ratio text`, `travel_friendliness CHECK IN (in_bag, cooler_friendly, home_only)`, `flavor_profile text`, `prep_effort CHECK IN (grab_and_go, assemble, cook)`, `protein_anchor text`, `carb_sources text[]`, `selection_priority int`, `portions text`.

Values in the `allergens`/`excluded_diets` arrays already use the exact strings named in the brief (`dairy, eggs, fish, gluten, ...` / `vegan, vegetarian, ...`). **Recommendation**: the new meal library should add matching `allergens text[]` and `excluded_diets text[]` (or a `diets_ok` positive-list, per the brief's own output spec) columns onto `recipes` (they don't exist there yet) so filtering can reuse the same `diet-filter.ts` pattern used for the workout templates.

## 7. `docs/new_mealplanning/repo/repo-context.md` — §6 Gaps summary

What's missing for a real batch-cooking, chat-forward meal planner with shopping list + log-from-plan:

- **No forward-looking plan storage** — `meal_logs`/`saved_meals` are retrospective/favorites only; nothing like a `meal_plans`/`meal_plan_meals` table exists (an archived prototype proposed this). No `MealLogSource` value for "logged from a plan" exists (`jade_baseline` hints at AI-generated content but isn't wired to any UI).
- **No weekly/multi-day view** — every screen (`log_meal_screen.dart`, `recipes_screen.dart`, `carb_loading_day_detail_page.dart`) is single-day/single-item; no week-grid component, no `AiCoachUiPart` kind for a multi-day plan in chat.
- **No shopping/grocery list feature for meal planning** — `carb_loading` has its own older shopping-list spec but no shared "aggregate ingredients across N planned meals" service/table; `getSalesNearby` in jade-chat's tools is an explicit unbuilt backlog stub.
- **No batch-cooking / meal-prep concept** — `Recipe.servings` exists but nothing tracks portioning one cooked batch across multiple future meal-log rows; no leftover tracking.
- **No pantry/inventory tracking** — never built (only sketched in an archived design doc).
- **Recipe favorites are stubbed out** — `RecipeRepository.getFavoriteRecipes()`/`toggleFavorite()` are no-ops; a planner suggesting from favorites should route through `saved_meals` instead.
- **`Recipe.ingredients`/`instructions` are unstructured strings**, not `MealComponent` objects — unlike `MealLog`/`SavedMeal`, a recipe can't be macro-aggregated or ingredient-swapped without a parsing step.
- **No meal-timing preferences** — nothing captures "breakfast at 6am" / "skip lunch on hard days."
- **No day-level weather for meal planning** — `WeatherForecast` is cached per-activity only (1h/24h TTL), not at day granularity.
- **`food_preferences` upload has no per-row dirty flag** — every save re-uploads the entire preference set (fine at current scale, flagged as a future cost).
- **No "regenerate one slot without disturbing the rest of the plan" primitive** — closest analog is `swap_food_screen.dart`'s single-workout food substitution; nothing generalizes to a multi-meal plan. Explicitly called out as avoiding the "Regen Trap" failure mode (full regenerate wiping locked choices).
- **`personal_templates`/`personal_formulas` are workout-fueling-scoped only** (before/during/after an activity), not meal-slot-scoped (breakfast/lunch/dinner/snack, training-neutral) — a meal planner needs its own selection model, can't reuse Formula Kit's phase-based filters directly.

**Relevance to the 400-meal library**: the library will most naturally land as new rows in `recipes` (service-role-managed, same shape as `recipes_seed.sql`), extended with `allergens`/`excluded_diets` array columns to match the rest of the catalog's tagging scheme — but the *planning* layer that would schedule/shop/batch-cook from those meals does not exist yet per this gaps list, so the meal-library work is prerequisite content, not a full planner.
