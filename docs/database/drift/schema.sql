-- Mealvana Endurance Drift SQLite Database Schema
-- Version: 1
-- Generated: 2025
-- Total Tables: 27 (100% synced with Supabase - complete parity)

-- ============================================================================
-- SYNCED TABLES (13) - These tables sync with Supabase
-- ============================================================================

-- 1. user_profiles (maps to Supabase 'users' table)
CREATE TABLE IF NOT EXISTS user_profiles (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    device_id TEXT NOT NULL,                       -- Device identifier for device-based auth
    gender TEXT NOT NULL,                          -- male, female, other
    birthday TEXT NOT NULL,                        -- ISO 8601 date
    height_feet INTEGER NOT NULL,                  -- Height in feet
    height_inches INTEGER NOT NULL,                -- Additional inches
    weight_pounds REAL NOT NULL,                   -- Body weight in pounds
    gut_training_level TEXT NOT NULL,              -- low, moderate, high
    has_completed_onboarding INTEGER NOT NULL DEFAULT 0,  -- Boolean (0/1)
    app_version TEXT,                              -- App version string
    created_at TEXT NOT NULL,                      -- ISO 8601 datetime
    updated_at TEXT NOT NULL,                      -- ISO 8601 datetime
    temp_plan_data TEXT,                           -- Drift-only: Temporary plan storage
    swipe_hint_shown INTEGER DEFAULT 0,            -- Drift-only: UI state tracking

    -- Constraints
    UNIQUE(device_id),
    CHECK (gender IN ('male', 'female', 'other')),
    CHECK (gut_training_level IN ('low', 'moderate', 'high')),
    CHECK (height_feet >= 0),
    CHECK (height_inches >= 0 AND height_inches < 12),
    CHECK (weight_pounds > 0)
);

-- 2. nutrition_plans
CREATE TABLE IF NOT EXISTS nutrition_plans (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    device_id TEXT NOT NULL,                       -- Foreign key to user_profiles.device_id
    plan_id TEXT NOT NULL,                         -- Unique plan identifier
    plan_data TEXT NOT NULL,                       -- JSON containing full plan details
    created_at TEXT NOT NULL,                      -- ISO 8601 datetime
    updated_at TEXT NOT NULL,                      -- ISO 8601 datetime
    is_deleted INTEGER NOT NULL DEFAULT 0,         -- Soft delete flag

    -- Constraints
    UNIQUE(device_id, plan_id),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE
);

-- 3. food_preferences
CREATE TABLE IF NOT EXISTS food_preferences (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    device_id TEXT NOT NULL,                       -- Foreign key to user_profiles.device_id
    food_name TEXT NOT NULL,                       -- Name of the food
    preference TEXT NOT NULL,                      -- like, dislike, willing_to_try
    created_at TEXT NOT NULL,                      -- ISO 8601 datetime
    updated_at TEXT NOT NULL,                      -- ISO 8601 datetime

    -- Constraints
    UNIQUE(device_id, food_name),
    CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE
);

-- 4. feedback
CREATE TABLE IF NOT EXISTS feedback (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    device_id TEXT,                                -- Foreign key to user_profiles.device_id (nullable)
    feedback_type TEXT NOT NULL,                   -- survey, plan_rating, general
    feedback_data TEXT NOT NULL,                   -- JSON containing feedback details
    created_at TEXT NOT NULL,                      -- ISO 8601 datetime
    synced INTEGER NOT NULL DEFAULT 0,             -- Whether synced to Supabase

    -- Constraints
    CHECK (feedback_type IN ('survey', 'plan_rating', 'general'))
);

-- 5. foods
CREATE TABLE IF NOT EXISTS foods (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    name TEXT NOT NULL,                           -- Food name
    label TEXT,                                    -- Display label
    product_type_id TEXT,                          -- Foreign key to product_types.id
    carbs_g REAL NOT NULL DEFAULT 0,              -- Carbohydrates in grams
    protein_g REAL NOT NULL DEFAULT 0,            -- Protein in grams
    fat_g REAL NOT NULL DEFAULT 0,                -- Fat in grams
    sodium_mg REAL NOT NULL DEFAULT 0,            -- Sodium in milligrams
    water_ml REAL NOT NULL DEFAULT 0,             -- Water content in milliliters
    created_at TEXT NOT NULL,                      -- ISO 8601 datetime
    updated_at TEXT NOT NULL,                      -- ISO 8601 datetime

    -- Constraints
    CHECK (carbs_g >= 0),
    CHECK (protein_g >= 0),
    CHECK (fat_g >= 0),
    CHECK (sodium_mg >= 0),
    CHECK (water_ml >= 0),
    FOREIGN KEY (product_type_id) REFERENCES product_types(id)
);

-- 6. product_types
CREATE TABLE IF NOT EXISTS product_types (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    name TEXT NOT NULL,                           -- Type name (gel, bar, chews, etc.)
    description TEXT,                              -- Type description
    created_at TEXT NOT NULL,                      -- ISO 8601 datetime
    updated_at TEXT NOT NULL,                      -- ISO 8601 datetime

    -- Constraints
    UNIQUE(name)
);

-- 7. categories
CREATE TABLE IF NOT EXISTS categories (
    id INTEGER NOT NULL PRIMARY KEY,               -- Integer ID
    name TEXT NOT NULL,                           -- before_run, during_run, after_run
    display_name TEXT NOT NULL,                    -- UI display name
    sort_order INTEGER NOT NULL DEFAULT 0,         -- Display order

    -- Constraints
    UNIQUE(name),
    CHECK (name IN ('before_run', 'during_run', 'after_run'))
);

-- 8. food_categories (many-to-many junction table)
CREATE TABLE IF NOT EXISTS food_categories (
    food_id TEXT NOT NULL,                         -- Foreign key to foods.id
    category_id INTEGER NOT NULL,                  -- Foreign key to categories.id

    -- Constraints
    PRIMARY KEY (food_id, category_id),
    FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
);

-- 9. user_foods
CREATE TABLE IF NOT EXISTS user_foods (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    device_id TEXT NOT NULL,                       -- Foreign key to user_profiles.device_id
    client_food_id TEXT NOT NULL,                  -- Client-side generated ID
    name TEXT NOT NULL,                           -- Food name
    barcode TEXT,                                  -- Barcode if scanned
    brand TEXT,                                     -- Brand name
    carbs_g REAL NOT NULL DEFAULT 0,              -- Carbohydrates in grams
    protein_g REAL NOT NULL DEFAULT 0,            -- Protein in grams
    fat_g REAL NOT NULL DEFAULT 0,                -- Fat in grams
    sodium_mg REAL NOT NULL DEFAULT 0,            -- Sodium in milligrams
    water_ml REAL NOT NULL DEFAULT 0,             -- Water content in milliliters
    serving_size TEXT,                              -- Serving size description
    serving_unit TEXT,                              -- Serving unit (g, ml, etc.)
    notes TEXT,                                     -- User notes
    is_deleted INTEGER NOT NULL DEFAULT 0,         -- Soft delete flag
    created_at TEXT NOT NULL,                      -- ISO 8601 datetime
    updated_at TEXT NOT NULL,                      -- ISO 8601 datetime

    -- Constraints
    UNIQUE (device_id, client_food_id),
    CHECK (carbs_g >= 0),
    CHECK (protein_g >= 0),
    CHECK (fat_g >= 0),
    CHECK (sodium_mg >= 0),
    CHECK (water_ml >= 0),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE
);

-- 10. user_food_categories (junction table for user foods)
CREATE TABLE IF NOT EXISTS user_food_categories (
    user_food_id TEXT NOT NULL,                    -- Foreign key to user_foods.id
    category_name TEXT NOT NULL,                   -- Category name

    -- Constraints
    PRIMARY KEY (user_food_id, category_name),
    CHECK (category_name IN ('before_run', 'during_run', 'after_run')),
    FOREIGN KEY (user_food_id) REFERENCES user_foods(id) ON DELETE CASCADE
);

-- 11. user_hidden_foods
CREATE TABLE IF NOT EXISTS user_hidden_foods (
    device_id TEXT NOT NULL,                       -- Foreign key to user_profiles.device_id
    food_id TEXT NOT NULL,                         -- Foreign key to foods.id

    -- Constraints
    PRIMARY KEY (device_id, food_id),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE,
    FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE
);

-- 12. app_content (dynamic content management)
CREATE TABLE IF NOT EXISTS app_content (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    content_key TEXT NOT NULL,                     -- Unique key for content item
    content_data TEXT NOT NULL,                    -- JSON containing content
    version INTEGER NOT NULL DEFAULT 1,            -- Content version
    created_at TEXT NOT NULL,                      -- ISO 8601 datetime
    updated_at TEXT NOT NULL,                      -- ISO 8601 datetime

    -- Constraints
    UNIQUE(content_key)
);

-- 13. edge_functions
CREATE TABLE IF NOT EXISTS edge_functions (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    function_name TEXT NOT NULL,                   -- Edge function name
    function_code TEXT NOT NULL,                   -- Function code
    is_active INTEGER NOT NULL DEFAULT 1,          -- Whether function is active
    version INTEGER NOT NULL DEFAULT 1,            -- Function version
    created_at TEXT NOT NULL,                      -- ISO 8601 datetime
    updated_at TEXT NOT NULL,                      -- ISO 8601 datetime

    -- Constraints
    UNIQUE(function_name)
);

-- ============================================================================
-- LOCAL-ONLY TABLES (6) - These tables exist only in Drift, not in Supabase
-- ============================================================================

-- 14. macro_targets (nutrition target calculations)
CREATE TABLE IF NOT EXISTS macro_targets (
    id TEXT NOT NULL PRIMARY KEY,                  -- Unique identifier

    -- Pre-run macros
    pre_run_carbs_g REAL NOT NULL,                -- Pre-run carbohydrates (g)
    pre_run_protein_g REAL NOT NULL,              -- Pre-run protein (g)
    pre_run_fat_cap_g REAL NOT NULL,              -- Pre-run fat cap (g)
    pre_run_fluids_ml REAL NOT NULL,              -- Pre-run fluids (ml)
    pre_run_sodium_mg REAL NOT NULL,              -- Pre-run sodium (mg)

    -- During-run macros
    during_carb_rate_g_per_h REAL NOT NULL,       -- Carb intake rate (g/hr)
    during_carb_total_g REAL NOT NULL,            -- Total carbs during run (g)
    during_fluid_rate_ml_per_h REAL NOT NULL,     -- Fluid intake rate (ml/hr)
    during_fluid_total_ml REAL NOT NULL,          -- Total fluids during run (ml)
    during_sodium_rate_mg_per_h REAL NOT NULL,    -- Sodium intake rate (mg/hr)
    during_sodium_total_mg REAL NOT NULL,         -- Total sodium during run (mg)
    during_mass_norm_rate_g_per_h REAL,           -- Mass-normalized rate (g/hr) - nullable

    -- Post-run macros
    post_run_carbs_g REAL NOT NULL,               -- Post-run carbohydrates (g)
    post_run_protein_g REAL NOT NULL,             -- Post-run protein (g)
    post_run_fluids_ml REAL NOT NULL,             -- Post-run fluids (ml)
    post_run_sodium_mg REAL NOT NULL,             -- Post-run sodium (mg)

    -- Run metrics
    distance_mi REAL NOT NULL,                     -- Distance in miles
    duration_h REAL NOT NULL,                      -- Duration in hours
    pace_min_per_mile REAL NOT NULL,              -- Pace in minutes per mile
    calories_gross_kcal REAL NOT NULL,            -- Gross calories burned (kcal)
    met REAL NOT NULL,                            -- Metabolic Equivalent of Task

    -- Metadata
    calculation_rule TEXT NOT NULL,                -- Rule used for calculation
    timestamp TEXT NOT NULL,                       -- ISO 8601 datetime
    is_user_modified INTEGER NOT NULL DEFAULT 0,   -- Whether user modified values
    modified_fields TEXT NOT NULL DEFAULT '',      -- Comma-separated list of modified fields

    -- Constraints
    CHECK (pre_run_carbs_g >= 0),
    CHECK (pre_run_protein_g >= 0),
    CHECK (pre_run_fat_cap_g >= 0),
    CHECK (pre_run_fluids_ml >= 0),
    CHECK (pre_run_sodium_mg >= 0),
    CHECK (during_carb_rate_g_per_h >= 0),
    CHECK (during_carb_total_g >= 0),
    CHECK (during_fluid_rate_ml_per_h >= 0),
    CHECK (during_fluid_total_ml >= 0),
    CHECK (during_sodium_rate_mg_per_h >= 0),
    CHECK (during_sodium_total_mg >= 0),
    CHECK (post_run_carbs_g >= 0),
    CHECK (post_run_protein_g >= 0),
    CHECK (post_run_fluids_ml >= 0),
    CHECK (post_run_sodium_mg >= 0),
    CHECK (distance_mi > 0),
    CHECK (duration_h > 0),
    CHECK (pace_min_per_mile > 0),
    CHECK (calories_gross_kcal >= 0),
    CHECK (met > 0)
);

-- 15. workout_notes (user journal entries)
CREATE TABLE IF NOT EXISTS workout_notes (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    userId TEXT NOT NULL,                          -- Foreign key to user_profiles.id (NOT device_id)
    planId TEXT,                                   -- Optional reference to nutrition_plans.id
    noteText TEXT NOT NULL,                        -- Note content
    rating INTEGER,                                 -- Optional rating (1-5 scale)
    createdAt TEXT NOT NULL,                       -- ISO 8601 datetime
    updatedAt TEXT NOT NULL,                       -- ISO 8601 datetime

    -- Constraints
    CHECK (rating IS NULL OR (rating >= 1 AND rating <= 5)),
    FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
);

-- 16. carb_loading_plans
CREATE TABLE IF NOT EXISTS carb_loading_plans (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    userId TEXT NOT NULL,                          -- Foreign key to user_profiles.id
    raceDate TEXT NOT NULL,                        -- ISO 8601 datetime
    raceDistance TEXT NOT NULL,                    -- half_marathon, marathon, 50k, etc.
    trainingVolume TEXT NOT NULL,                  -- low, moderate, high
    planData TEXT NOT NULL,                        -- JSON containing full plan
    createdAt TEXT NOT NULL,                       -- ISO 8601 datetime
    updatedAt TEXT NOT NULL,                       -- ISO 8601 datetime
    isActive INTEGER NOT NULL DEFAULT 1,           -- Whether plan is active

    -- Constraints
    CHECK (raceDistance IN ('5k', '10k', 'half_marathon', 'marathon', '50k', '50mi', '100k', '100mi')),
    CHECK (trainingVolume IN ('low', 'moderate', 'high')),
    FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
);

-- 17. carb_loading_simple_plans
CREATE TABLE IF NOT EXISTS carb_loading_simple_plans (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    userId TEXT NOT NULL,                          -- Foreign key to user_profiles.id
    raceDate TEXT NOT NULL,                        -- ISO 8601 datetime
    raceDistance TEXT NOT NULL,                    -- half_marathon, marathon, 50k, etc.
    trainingVolume TEXT NOT NULL,                  -- low, moderate, high
    dailyCarbTargetG INTEGER NOT NULL,             -- Daily carb target in grams (e.g., 500g)
    dailyServingsTarget INTEGER NOT NULL,          -- Daily servings (e.g., 10 servings)
    bodyWeightKg REAL NOT NULL,                    -- Body weight in kilograms
    carbsPerKgTarget REAL NOT NULL,                -- Target carbs per kg (e.g., 8g/kg)
    daySelectionsJson TEXT NOT NULL,               -- JSON containing food selections by day
    createdAt TEXT NOT NULL,                       -- ISO 8601 datetime
    updatedAt TEXT NOT NULL,                       -- ISO 8601 datetime
    isActive INTEGER NOT NULL DEFAULT 1,           -- Whether plan is active

    -- Constraints
    CHECK (raceDistance IN ('5k', '10k', 'half_marathon', 'marathon', '50k', '50mi', '100k', '100mi')),
    CHECK (trainingVolume IN ('low', 'moderate', 'high')),
    CHECK (dailyCarbTargetG > 0),
    CHECK (dailyServingsTarget > 0),
    CHECK (bodyWeightKg > 0),
    CHECK (carbsPerKgTarget > 0),
    FOREIGN KEY (userId) REFERENCES user_profiles(id) ON DELETE CASCADE
);

-- 18. carb_loading_days (individual day entries within carb loading plans)
CREATE TABLE IF NOT EXISTS carb_loading_days (
    id TEXT NOT NULL PRIMARY KEY,                  -- UUID
    carb_loading_plan_id TEXT NOT NULL,            -- Foreign key to carb_loading_plans.id

    -- Day information
    plan_date TEXT NOT NULL,                       -- ISO 8601 date
    day_number INTEGER NOT NULL,                   -- Day sequence (1, 2, 3, etc. - 1 = first day, last number = race day - 1)

    -- Daily targets
    carb_target_grams INTEGER NOT NULL,            -- Target carbohydrates in grams
    carb_protocol_g_per_kg REAL NOT NULL,          -- Carbohydrate protocol formula (e.g., 8.0 for 8g/kg bodyweight) - enables UI to display "8g/kg bodyweight" instead of just "610g carbs target"
    calorie_target INTEGER,                        -- Target calories (nullable)
    meal_count INTEGER NOT NULL DEFAULT 6,         -- Number of meals (breakfast, snack, lunch, snack, dinner, evening)

    -- Meal distribution (percentages that sum to 1.0)
    breakfast_percent REAL NOT NULL DEFAULT 0.25,       -- Breakfast meal percentage
    morning_snack_percent REAL NOT NULL DEFAULT 0.10,   -- Morning snack percentage
    lunch_percent REAL NOT NULL DEFAULT 0.25,           -- Lunch percentage
    afternoon_snack_percent REAL NOT NULL DEFAULT 0.15, -- Afternoon snack percentage
    dinner_percent REAL NOT NULL DEFAULT 0.20,          -- Dinner percentage
    evening_snack_percent REAL NOT NULL DEFAULT 0.05,   -- Evening snack percentage

    -- Progress tracking
    logged_carbs_grams INTEGER NOT NULL DEFAULT 0, -- Carbs logged so far
    logged_calories INTEGER NOT NULL DEFAULT 0,    -- Calories logged so far
    completed INTEGER NOT NULL DEFAULT 0,          -- Whether day is completed (boolean 0/1)

    -- Constraints
    UNIQUE (carb_loading_plan_id, plan_date),
    CHECK (day_number > 0),
    CHECK (carb_target_grams > 0),
    CHECK (carb_protocol_g_per_kg > 0),
    CHECK (meal_count > 0),
    CHECK (breakfast_percent >= 0.0 AND breakfast_percent <= 1.0),
    CHECK (morning_snack_percent >= 0.0 AND morning_snack_percent <= 1.0),
    CHECK (lunch_percent >= 0.0 AND lunch_percent <= 1.0),
    CHECK (afternoon_snack_percent >= 0.0 AND afternoon_snack_percent <= 1.0),
    CHECK (dinner_percent >= 0.0 AND dinner_percent <= 1.0),
    CHECK (evening_snack_percent >= 0.0 AND evening_snack_percent <= 1.0),
    CHECK (logged_carbs_grams >= 0),
    CHECK (logged_calories >= 0),
    FOREIGN KEY (carb_loading_plan_id) REFERENCES carb_loading_plans(id) ON DELETE CASCADE
);

-- 19. brands (brand information for affiliate marketing)
CREATE TABLE IF NOT EXISTS brands (
    id TEXT NOT NULL PRIMARY KEY,                  -- Brand identifier
    name TEXT NOT NULL,                           -- Brand name
    websiteUrl TEXT,                              -- Brand website URL
    affiliateProgramUrl TEXT,                      -- Affiliate program URL
    affiliateNetwork TEXT,                         -- Affiliate network name
    defaultAffiliateUrl TEXT,                      -- Default affiliate link
    notes TEXT,                                    -- Additional notes

    -- Constraints
    UNIQUE(name)
);

-- ============================================================================
-- INDEXES
-- ============================================================================

-- Performance indexes for common queries
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_device_id ON nutrition_plans(device_id);
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_created_at ON nutrition_plans(created_at);
CREATE INDEX IF NOT EXISTS idx_food_preferences_device_id ON food_preferences(device_id);
CREATE INDEX IF NOT EXISTS idx_feedback_device_id ON feedback(device_id);
CREATE INDEX IF NOT EXISTS idx_feedback_synced ON feedback(synced);
CREATE INDEX IF NOT EXISTS idx_foods_product_type_id ON foods(product_type_id);
CREATE INDEX IF NOT EXISTS idx_user_foods_device_id ON user_foods(device_id);
CREATE INDEX IF NOT EXISTS idx_user_foods_barcode ON user_foods(barcode);
CREATE INDEX IF NOT EXISTS idx_workout_notes_userId ON workout_notes(userId);
CREATE INDEX IF NOT EXISTS idx_workout_notes_planId ON workout_notes(planId);
CREATE INDEX IF NOT EXISTS idx_carb_loading_plans_userId ON carb_loading_plans(userId);
CREATE INDEX IF NOT EXISTS idx_carb_loading_simple_plans_userId ON carb_loading_simple_plans(userId);
CREATE INDEX IF NOT EXISTS idx_carb_loading_days_plan_date ON carb_loading_days(carb_loading_plan_id, plan_date);

-- ============================================================================
-- END OF SCHEMA - Version 1
-- ============================================================================