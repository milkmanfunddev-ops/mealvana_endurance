# User Data Inventory for AI Meal Planning Prototype

**Document Version:** 1.0  
**Date:** 2026-05-06  
**Purpose:** Catalog all user-facing data available in mealvana_endurance Supabase backend for AI meal planning web prototype design.

---

## Overview

This inventory describes the tables, columns, enums, constraints, and edge functions available in the mealvana_endurance Supabase PostgreSQL database that support meal planning logic. The prototype will connect to Supabase **dev** using JWT-authenticated user context and leverage existing RLS policies. All data references point to specific migration files and schema definitions in the `/Users/leemartin/development/mealvana_endurance/supabase/` directory.

---

## 1. Core User Data

### 1.1 Users Table
**Location:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/_archive/20251216203710_remote_schema.sql` (lines 1283–1350)

**Primary Key:** `id` (UUID, auth.users reference)

**Demographic & Biometric Fields:**
- `gender` (TEXT): Male, Female, Other, Prefer not to say
- `birthday` (DATE): For age calculation and context
- `height_feet` (INTEGER): User's height in feet
- `height_inches` (NUMERIC): Fractional inches
- `weight_pounds` (NUMERIC): Current body weight
- `body_fat_percentage` (NUMERIC, nullable): Optional body composition

**Dietary & Allergy Constraints:**
- `dietary_preference` (TEXT): Enum value from `dietary_preference_enum`
  - Options: `omnivore`, `vegetarian`, `pescatarian`, `vegan`, `mediterranean`, `paleo`, `keto`, `low_carb`
  - Source: `/Users/leemartin/development/mealvana_endurance/supabase/migrations/_archive_data/20251214120000_add_dietary_preference_and_allergies.sql`
- `allergies` (TEXT[]): Array of allergy enum values
  - Options: `dairy`, `eggs`, `fish`, `gluten`, `peanuts`, `sesame`, `shellfish`, `soy`, `tree_nuts`
  - Constraint Type: **HARD** (food cannot contain any allergen)

**Training/Athletic Context:**
- `gut_training_level` (TEXT, nullable): Assessment of digestive adaptation (low, medium, high)
- `gi_sensitivity` (TEXT, nullable): Gastrointestinal sensitivity level (low, medium, high)
- `cycling_ftp_watts` (INTEGER, nullable): Functional Threshold Power for cycling macro calculations
- `swimming_css_seconds_per_100m` (NUMERIC, nullable): Critical Swim Speed for swimming calculations
- `activity_level` (TEXT, nullable): General activity level classification

**Unit Preferences:**
- `weight_unit` (TEXT): 'lbs' or 'kg'
- `distance_unit` (TEXT): 'miles' or 'km'
- `temperature_unit` (TEXT): 'F' or 'C'
- `pace_unit` (TEXT): 'min_per_mile' or 'min_per_km'

**Notification & App Settings:**
- `notification_settings` (JSONB, nullable): User's notification preferences
- `updated_at` (TIMESTAMPTZ): Last profile modification

**RLS Policy:** Users can SELECT/UPDATE/DELETE their own row; service_role has full access.

---

### 1.2 Food Preferences Table
**Location:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/_archive/20251216203710_remote_schema.sql` (lines 1126–1137)

**Primary Key:** `id` (UUID)  
**Unique Constraint:** `(user_id, food_name)`

**Fields:**
- `user_id` (UUID): Foreign key to users table
- `food_name` (TEXT): Name of the food item
- `preference` (TEXT): Enum value from `food_preference_enum`
  - Options: `like`, `dislike`, `willing_to_try`
  - Constraint Type: **SOFT** for `dislike` (can be overridden if no alternatives available); **HARD** if combined with allergy
- `preference_level` (INTEGER): Slider value 0–4 indicating strength of preference
  - 0 = neutral, 4 = strong preference/aversion
- `created_at`, `updated_at` (TIMESTAMPTZ): Audit timestamps

**RLS Policy:** Users can SELECT/INSERT/UPDATE/DELETE own food preferences.

**Implementation Detail:** The Flutter app syncs food_preferences from Supabase to local Drift database (see `/Users/leemartin/development/mealvana_endurance/lib/features/food_preferences/data/food_preferences_repository.dart`, lines 38–108). Preferences are maintained during nutrition plan generation via the `selectPreWorkoutFoods` logic in edge functions.

---

## 2. Training Schedule & Activities

### 2.1 Activities Table
**Location:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/_archive/20251216203710_remote_schema.sql` (lines 684–800)

**Primary Key:** `id` (UUID)

**Core Schedule Fields:**
- `user_id` (UUID): Foreign key to users table
- `title` (TEXT): Activity name (e.g., "Long Run", "Brick Workout")
- `scheduled_date_time` (TIMESTAMPTZ): Planned start time of the activity
- `status` (TEXT): Enum from `activity_status_enum`
  - Options: `planned`, `in_progress`, `completed`, `cancelled`
- `activity_type` (TEXT): Sport type
  - Options: `running`, `cycling`, `swimming`, `brick`, `strength`, `yoga`, `other`

**Duration & Intensity:**
- `duration_minutes` (INTEGER): Total activity duration
- `intensity_level` (TEXT, nullable): Relative intensity classification (low, moderate, high, threshold, VO2max)
- `pace_target` (TEXT, nullable): Goal pace for running (e.g., "8:30 min/mile")

**Sport-Specific Numeric Fields:**
- **Running:** `distance_miles` (NUMERIC)
- **Cycling:** `distance_miles` (NUMERIC), `power_avg_watts` (NUMERIC, nullable), `elevation_gain_ft` (INTEGER, nullable), `terrain_type` (TEXT, nullable)
- **Swimming:** `distance_meters` (NUMERIC), `pace_per_100m_seconds` (NUMERIC), `water_temperature_c` (NUMERIC, nullable)
- **Brick:** `brick_segments` (JSONB array, see section 2.2)

**Nutrition Planning Fields:**
- `nutrition_plan_data` (JSONB, nullable): Prospective macro targets for this activity
  - Contains: `pre_carbs_g`, `pre_protein_g`, `during_carbs_g`, `post_carbs_g`, etc.
- `fuel_strategy` (TEXT, nullable): User's selected nutrition approach (e.g., "high_carb", "moderate", "lower")

**User Feedback:**
- `perceived_effort` (INTEGER, nullable): Post-activity RPE (Rate of Perceived Exertion) 1–10
- `energy_level_after` (TEXT, nullable): Subjective post-activity energy feeling
- `completion_date_time` (TIMESTAMPTZ, nullable): Actual completion timestamp

**RLS Policy:** Users can SELECT/INSERT/UPDATE/DELETE own activities.

### 2.2 Brick Segment Structure
When `activity_type = 'brick'`, the `brick_segments` JSONB column contains an array of segment objects:

```json
[
  {
    "sport": "swimming",
    "duration_minutes": 45,
    "distance_meters": 1500,
    "pace_per_100m_seconds": 110
  },
  {
    "sport": "cycling",
    "duration_minutes": 90,
    "distance_miles": 30,
    "power_avg_watts": 250
  },
  {
    "sport": "running",
    "duration_minutes": 30,
    "distance_miles": 5,
    "pace_target": "8:00 min/mile"
  }
]
```

Each segment must have a valid sport and positive duration_minutes.

---

## 3. Macro Targets & Nutrition Computation

### 3.1 Daily Macro Targets Table
**Location:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/20260326100002_create_daily_macro_targets.sql` (lines 2–23)

**Primary Key:** `id` (UUID)  
**Unique Constraint:** `(user_id, target_date)`

**Core Macro Columns:**
- `user_id` (UUID): Foreign key to users table
- `target_date` (DATE): The date these macros apply to
- `carb_g` (REAL): Target carbohydrate grams
- `prot_g` (REAL): Target protein grams
- `fat_g` (REAL): Target fat grams
- `tdee` (REAL): Total Daily Energy Expenditure (kcal)
- `rmr` (REAL): Resting Metabolic Rate (kcal)

**Activity & Energy Context:**
- `session_kcal` (REAL, default 0): Energy expended during planned activity
- `neat_kcal` (REAL, nullable): Non-Exercise Activity Thermogenesis
- `tef_kcal` (REAL, nullable): Thermic Effect of Food

**Calculation & Algorithm:**
- `mode` (TEXT, default 'prospective'): `prospective` (planned targets) or `retrospective` (actual logged data)
- `algorithm_version` (TEXT, default 'v4'): Which macro calculation algorithm was used (currently `v4`)
- `calculation_input` (JSONB, nullable): Full input used for calculation (weight, activity type, intensity, fasted status, temperature, humidity, etc.)
- `ea` (REAL, nullable): Energy Availability (kcal/kg FFM/day) for RED-S screening
- `ea_status` (TEXT, nullable): RED-S risk classification (low, moderate, high)

**RLS Policy:** Users can SELECT/INSERT/UPDATE/DELETE own daily macro targets.

**Key Note:** The `algorithm_version` field allows tracking which version of generate-macros-v4 produced the targets. The `calculation_input` JSONB preserves all inputs, enabling auditability and recalculation if needed.

---

## 4. Food Catalog & Templates

### 4.1 Foods Table
**Location:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/_archive/20251216203710_remote_schema.sql` (lines 1141–1200)

**Primary Key:** `id` (UUID)

**Identity & Classification:**
- `name` (TEXT): Food/ingredient name
- `product_type` (TEXT): Category (e.g., 'gel', 'bar', 'drink', 'whole_food')
- `activity_types` (TEXT[]): Array of sport types this food is suited for (e.g., `['running', 'cycling']`)
- `categories` (TEXT[]): Meal timing categories
  - Values: `before_run`, `during_run`, `after_run`, `transition`

**Nutritional Content (per serving):**
- `calories_per_serving` (INTEGER)
- `carbs_g` (NUMERIC)
- `protein_g` (NUMERIC)
- `fat_g` (NUMERIC)
- `sodium_mg` (INTEGER): Important for endurance hydration planning
- `caffeine_mg` (INTEGER, nullable): For pre-workout energy
- `sugar_g` (NUMERIC, nullable)
- `fiber_g` (NUMERIC, nullable)
- `serving_size` (TEXT): Textual description (e.g., "1 bar", "200 mL")
- `serving_grams` (NUMERIC, nullable): Weight of one serving

**Constraints:**
- `allergens` (TEXT[]): Allergy enum values (dairy, eggs, fish, gluten, peanuts, sesame, shellfish, soy, tree_nuts)
- `excluded_diets` (TEXT[]): Dietary patterns this food conflicts with (vegan, vegetarian, etc.)
  - Constraint Type: **HARD** (food cannot be recommended if user's dietary_preference is in excluded_diets)

**Serving Limits (per workout phase):**
- `max_servings_before` (NUMERIC, nullable): Max servings during pre-workout phase
- `max_servings_during` (NUMERIC, nullable): Max servings during activity
- `max_servings_after` (NUMERIC, nullable): Max servings during recovery

**RLS Policy:** Authenticated users can SELECT all foods; service_role can INSERT/UPDATE/DELETE.

### 4.2 Catalog Products & Variants
**Location:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/20260323100000_catalog_products_variants.sql`

**Catalog Products Table (lines 15–47):**
- One row per unique Shopify product
- Fields: `shopify_product_id`, `title`, `brand`, `product_type_id`, `categories`, `allergens`, `excluded_diets`, `is_electrolyte`, `is_liquid`, `activity_types`
- Classification metadata: `classification_source` ('claude' or 'manual'), `classification_confidence` (0.0–1.0)

**Catalog Variants Table (lines 52–95):**
- One row per flavor/size variant
- Fields: `shopify_variant_id`, `variant_title`, `barcode`, `sku`, `price_cents`, `available_for_sale`
- Nutrition per serving: `calories_per_serving`, `carbs_g`, `protein_g`, `fat_g`, `sodium_mg`, `caffeine_mg`, `sugar_g`, `fiber_g`, `servings_per_container`
- Foreign key: `catalog_product_id` (references catalog_products)

**RLS Policy:** Authenticated users can SELECT both tables; service_role can INSERT/UPDATE/DELETE (for Shopify sync).

**View:** `catalog_items` (line 118) provides backward-compatible join of products + variants for ease of querying.

### 4.3 Pre-Workout Templates
**Location:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/_archive/20260410010000_pre_workout_templates.sql`

**Purpose:** Seed library of macro-balanced pre-workout meal compositions for different scenarios.

**Key Fields:**
- `template_number` (INTEGER): Unique identifier
- `name` (TEXT): Human-readable template name (e.g., "High Carb Quick")
- `recovery_window` (TEXT): Time before workout ('immediate', 'meal', 'snack')
- `component_food_names` (TEXT[]): Array of food names that compose this template
- `component_ratios` (JSONB): Relative proportions or weights of each food
- `target_carb_protein_ratio` (NUMERIC, nullable): Desired macro ratio
- `allergens` (TEXT[]): Combined allergens of all components
- `excluded_diets` (TEXT[]): Dietary restrictions of this template

**RLS Policy:** Authenticated users can SELECT; service_role can INSERT/UPDATE/DELETE.

### 4.4 During-Workout Templates
**Location:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/20260406320000_during_workout_templates_complete.sql`

**Purpose:** Fuel strategies for activity (carb gels, sports drinks, electrolyte recommendations).

**Key Fields:**
- Similar structure to pre-workout templates
- `component_food_names` and `component_ratios` define drink/gel combinations
- Typically lower in protein, higher in rapidly-absorbable carbs and sodium

**RLS Policy:** Authenticated users can SELECT; service_role can INSERT/UPDATE/DELETE.

### 4.5 Post-Workout Templates
**Location:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/20260408200000_post_workout_templates.sql`

**Purpose:** Recovery meal/snack compositions for glycogen and protein replenishment.

**Key Fields:**
- `recovery_type` (TEXT): Meal category (`shake`, `smoothie`, `bowl`, `sandwich`, `snack`, `meal`)
- `recovery_window` (TEXT): When to consume ('immediate', '30min', '1hr', '2hr')
- `component_food_names` (TEXT[]) and `component_ratios` (JSONB)
- Emphasis on 3:1–4:1 carb:protein ratio

**RLS Policy:** Authenticated users can SELECT; service_role can INSERT/UPDATE/DELETE.

---

## 5. Available Edge Functions

All edge functions are located in `/Users/leemartin/development/mealvana_endurance/supabase/functions/`.

### 5.1 generate-macros-v4 (Primary)
**File:** `supabase/functions/generate-macros-v4/index.ts` (lines 1–206)

**Purpose:** Computes prospective macros for a single activity or brick workout with templated pre/during/post food recommendations.

**Input Type:** `MacroInputV4`
- `weight` (number), `weight_unit` (string)
- `hours_before` (number): Time available before activity
- `is_fasted` (boolean): Whether user has fasted
- `activity_type` ('running' | 'cycling' | 'swimming' | 'brick')
- Sport-specific fields: `run_distance`, `run_pace`, `distance_miles`, `speed_mph`, `distance_meters`, `pace_per_100m_seconds`, or `brick_segments`
- Environmental: `temp_c`, `humidity_pct` (optional, used for sweat rate calculation)
- User context: `diet`, `liked_foods`, `disliked_foods`, `allergies`, `sweat_sodium` ('low'|'average'|'high')

**Output:** Macro object containing:
- `pre_run_carbs_g`, `pre_run_protein_g`, `pre_run_fat_g`
- `pre_run_selections`: Array of selected food items from templates
- `pre_run_hydration_tier`: Hydration recommendation level
- `during_rate_g_per_h`, `during_total_g` (carbs by intensity/duration)
- `during_selections`: Drinks and electrolyte recommendations
- `post_run_carbs_g`, `post_run_protein_g` (recovery targets)
- `post_run_selections`: Recovery meal recommendations
- For brick workouts: `phases.during_segments` (per-segment calculations) and `phases.transitions` (inter-segment fueling)

**Algorithm:** "Comfort-Capped Hybrid" (Algorithm C)
- Uses range-based targets for all pre-workout macros
- Loads pre_workout_templates, during_workout_templates, post_workout_templates
- Applies user dietary constraints (allergies, disliked_foods, dietary_preference)
- Validates inputs and rejects invalid activity configurations
- For brick workouts, calculates total duration and applies gating logic (different strategy for <60 min vs >60 min efforts)

**RLS:** Callable by authenticated users; uses user context for filtering.

### 5.2 calculate-daily-macros (V4)
**Location:** `supabase/functions/calculate-daily-macros-v4/` (referenced in migrations but not fully documented in provided excerpts)

**Purpose:** Computes daily macro targets for a user on a given date, incorporating:
- Baseline TDEE from biometrics
- Training stimulus from scheduled/logged activities
- Energy availability (RED-S screening)

**Likely Input:** User ID, target date, body metrics, activity summary

**Output:** Daily macro targets row (carbs, protein, fat, TDEE, RMR, session_kcal) for caching in daily_macro_targets table.

### 5.3 generate-nutrition-plan-v3 (Legacy)
**Referenced in architecture; now superseded by generate-macros-v4.**

**Purpose:** Older holistic plan generation; kept for backward compatibility if needed.

---

## 6. Authentication & RLS Policies

### 6.1 Supabase Auth Integration

The app uses Supabase's built-in PostgreSQL Row Level Security (RLS) enforced via `auth.uid()` context.

**Standard User-Level Policy Pattern:**
```sql
CREATE POLICY "Users can manage own data"
    ON {table_name} FOR ALL USING (auth.uid() = user_id);
```

Applied to:
- `users` (users can SELECT/UPDATE own row)
- `food_preferences` (users can manage own preferences)
- `activities` (users can manage own activities)
- `daily_macro_targets` (users can manage own targets)

### 6.2 Public Catalog Policies

Templates and catalog tables are **readable** by authenticated users but **write-protected** to service_role:

```sql
CREATE POLICY "Authenticated read on {table_name}"
    ON {table_name} FOR SELECT TO authenticated USING (true);

CREATE POLICY "Service role full access on {table_name}"
    ON {table_name} FOR ALL TO service_role USING (true) WITH CHECK (true);
```

Applied to:
- `pre_workout_templates`
- `during_workout_templates`
- `post_workout_templates`
- `catalog_products`
- `catalog_variants`
- `foods`

### 6.3 Prototype Integration

The web prototype must:
1. Authenticate with Supabase JWT (obtained from Supabase auth session)
2. Pass JWT in Authorization header for all Supabase API calls
3. Rely on RLS to enforce user isolation (backend ensures `auth.uid()` context is set)
4. Call edge functions directly with authenticated context
5. Query tables via `supabase.from('table_name').select()` — RLS policies automatically filter to current user

---

## 7. Data Gaps & Recommendations

### 7.1 Known Gaps

1. **Meal Logging / Food Diary:** No current table for logging eaten foods/meals. The prototype will **generate** meal plans but cannot currently track adherence without a new table.
   - **Recommendation:** Add `meal_log` table with user_id, logged_date_time, food_id/quantity, meal_type (breakfast/lunch/snack/dinner), if detailed tracking is needed.

2. **Workout Fueling Actuals:** `activities` table has `nutrition_plan_data` (prospective) but no column for actual fuel consumed during the activity.
   - **Recommendation:** Add `actual_fuel_consumed` (JSONB) to activities to log real vs planned macros.

3. **Gut Training Progression:** `gut_training_level` is captured but not tracked over time. No table for gut training history.
   - **Recommendation:** Add versioned tracking if adaptive fueling strategies are needed.

4. **Preferred Meal Timing:** No table for user's preferred meal times (breakfast at 7am, lunch at 12pm, etc.) separate from activity schedules.
   - **Recommendation:** Add `meal_timing_preferences` table or JSONB column to users for personalized meal scheduling.

5. **Food Intolerance Details:** Current `allergies` enum covers major allergens but lacks nuance (e.g., lactose intolerance ≠ dairy allergy, FODMAP sensitivity, histamine).
   - **Recommendation:** Extend to `intolerances` array or link to a food_intolerances table with severity levels.

### 7.2 Assumptions for Prototype

- Prototype assumes user **weight is current** and does not auto-update if user edits it
- Prototype assumes **upcoming activities are scheduled in advance** (not real-time activity detection)
- Prototype assumes **liked/disliked foods are already populated** (or will be populated via onboarding)
- Edge function results are **prospective only** (not adaptive based on actual consumption feedback)

---

## 8. Quick Reference: Tables for Meal Planning Query

| Table | Key Columns | Use Case | RLS Read Access |
|-------|-------------|----------|-----------------|
| `users` | weight_pounds, height_feet/inches, dietary_preference, allergies, gut_training_level, cycling_ftp_watts, swimming_css_seconds_per_100m | User biometrics & constraints | Own row only |
| `food_preferences` | user_id, food_name, preference, preference_level | User's liked/disliked foods | Own user_id only |
| `activities` | scheduled_date_time, activity_type, duration_minutes, distance_miles, brick_segments, nutrition_plan_data | Upcoming workouts to plan for | Own user_id only |
| `daily_macro_targets` | target_date, carb_g, prot_g, fat_g, tdee, algorithm_version, calculation_input | Daily macro targets | Own user_id + date |
| `foods` | name, product_type, categories, allergens, excluded_diets, carbs_g, protein_g, fat_g, sodium_mg, caffeine_mg, max_servings_before/during/after | Food/ingredient master list | All (read-only) |
| `catalog_products`, `catalog_variants` | title, brand, categories, allergens, excluded_diets, is_electrolyte, nutrition fields | Commercial product search | All (read-only) |
| `pre_workout_templates` | name, component_food_names, component_ratios, target_carb_protein_ratio, allergens, excluded_diets | Pre-workout meal templates | All (read-only) |
| `during_workout_templates` | name, component_food_names, component_ratios | During-activity fuel templates | All (read-only) |
| `post_workout_templates` | name, recovery_type, component_food_names, component_ratios | Recovery meal templates | All (read-only) |

---

## 9. Summary for Developers

To build the AI meal planning prototype:

1. **Fetch user context:** Query `users` table (own row) for weight, height, dietary_preference, allergies, gut_training_level, cycling_ftp_watts, swimming_css_seconds_per_100m.

2. **Load food constraints:** Query `food_preferences` (own user_id) and cross-reference with `foods.excluded_diets` and `foods.allergens` to build constraint lists.

3. **Understand upcoming workouts:** Query `activities` (own user_id, status = 'planned', scheduled_date_time >= today) to see what activities need fueling.

4. **Retrieve macro targets:** Query `daily_macro_targets` (own user_id, target_date) to see if daily macros already calculated.

5. **Call generate-macros-v4 edge function** for each activity to get AI-selected food recommendations pre/during/post.

6. **Filter recommendations by constraints:**
   - Hard constraints: Remove foods with allergens in `users.allergies`, exclude foods where `food.excluded_diets` includes `users.dietary_preference`
   - Soft constraints: Deprioritize foods in `food_preferences` with preference = 'dislike' or low preference_level

7. **Display meal plans** using recommended foods + quantities from edge function output.

---

## 10. Appendix: File Locations

- **Dietary & Allergy Enums:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/_archive_data/20251214120000_add_dietary_preference_and_allergies.sql`
- **Full Schema Snapshot:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/_archive/20251216203710_remote_schema.sql`
- **Daily Macro Targets:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/20260326100002_create_daily_macro_targets.sql`
- **Catalog Schema:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/20260323100000_catalog_products_variants.sql`
- **Pre-Workout Templates:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/_archive/20260410010000_pre_workout_templates.sql`
- **During-Workout Templates:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/20260406320000_during_workout_templates_complete.sql`
- **Post-Workout Templates:** `/Users/leemartin/development/mealvana_endurance/supabase/migrations/20260408200000_post_workout_templates.sql`
- **Edge Function (Primary):** `/Users/leemartin/development/mealvana_endurance/supabase/functions/generate-macros-v4/index.ts`
- **Food Preferences Sync:** `/Users/leemartin/development/mealvana_endurance/lib/features/food_preferences/data/food_preferences_repository.dart`

