# Dev/Prod Implementation Roadmap

## Overview

Phased approach to establish two-environment setup (dev + prod) with unified schemas and automated deployments.

**Timeline:** 2-3 weeks
**Current Phase:** Phase 1
**Key Principle:** No migrations needed - establishing clean v1 baseline with 100% schema parity

## 📋 Prerequisites

**Before starting this roadmap, complete ALL tasks in `roadmap_lee.md` first!**

That document contains all manual setup steps that only you can do:
- Creating Supabase projects
- Collecting credentials
- Setting up GitHub secrets
- Creating git branches
- Testing local environment

**This roadmap contains only automated/code changes** that don't require manual credential entry.

---

## Phase 1: Clean V1 Schema Baseline (Week 1)

### Objective
Establish clean v1 schema with 16 unified tables (no migrations, fresh start)

### 1.1 Drift Schema Cleanup

**Objective**: Remove unused tables and establish 16-table v1 baseline

- [ ] **Edit** `/lib/shared/database/app_database.dart`:
  - Remove `import 'tables/brands_table.dart';`
  - Remove `import 'tables/carb_loading_table.dart';`
  - Remove `BrandsTable` from `@DriftDatabase` annotation
  - Remove `CarbLoadingTable` from `@DriftDatabase` annotation
  - Verify `schemaVersion = 1` (this IS our v1 baseline)

- [ ] **Delete** unused table files:
  ```bash
  rm lib/shared/database/tables/brands_table.dart
  rm lib/shared/database/tables/carb_loading_table.dart
  ```

- [ ] **Run** code generation:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

- [ ] **Generate** v1 schema snapshot:
  ```bash
  mkdir -p database_schemas/v1
  dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/
  ```

- [ ] **Verify** 26 tables in Drift:
  - Core (4): user_profiles, nutrition_plans, food_preferences, feedback
  - Food System (9): foods, product_types, categories, food_categories, user_foods, user_food_categories, user_hidden_foods
  - Content & Features (5): app_content, edge_functions, macro_targets, workout_notes, carb_loading_simple_plans

- [ ] **Update** `.gitignore`:
  ```gitignore
  # Database schemas (generated)
  database_schemas/
  drift_schemas/

  # Environment files with secrets
  .env
  .env.*.local
  ```

**Success Criteria**:
- ✅ Drift has exactly 26 tables (v1)
- ✅ Build runs without errors
- ✅ V1 snapshot saved in `database_schemas/v1/`
- ✅ .gitignore updated

### 1.2 Verify Supabase Projects

**Objective**: Confirm Lee has completed Supabase setup from `roadmap_lee.md`

**Prerequisites from `roadmap_lee.md`**:
- ✅ Dev project created
- ✅ Production project renamed
- ✅ All credentials collected and stored
- ✅ Local `.env.dev.local` and `.env.prod.local` files created

**Quick Verification**:
```bash
# Verify dev project exists
supabase projects list | grep "Dev"

# Verify prod project exists
supabase projects list | grep "Production"

# Should see both projects listed
```

**Success Criteria**:
- ✅ 2 Supabase projects exist (dev + prod)
- ✅ All credentials available in local env files
- ✅ Projects documented in `roadmap_lee.md`

### 1.3 Unified V1 Schema Migration

**Objective**: Deploy identical 16-table schema to both Supabase projects

- [ ] **Initialize Supabase CLI** (if not done):
  ```bash
  brew install supabase/tap/supabase  # If needed
  supabase init
  ```

- [ ] **Create migration file**:
  ```bash
  supabase migration new init_v1_unified_schema
  ```

- [ ] **Write complete DDL** for all 26 tables:

  **File**: `supabase/migrations/<timestamp>_init_v1_unified_schema.sql`

  ```sql
  -- Migration: init_v1_unified_schema
  -- Description: Initial v1 schema with 16 unified tables (100% parity with Drift)
  -- Date: 2025-10-06

  -- ============================================================================
  -- CORE TABLES (4)
  -- ============================================================================

  -- 1. user_profiles
  CREATE TABLE IF NOT EXISTS user_profiles (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    device_id TEXT NOT NULL UNIQUE CHECK (length(device_id) = 36),
    gender TEXT NOT NULL CHECK (gender IN ('male', 'female', 'other')),
    birthday TIMESTAMPTZ,
    height_feet INTEGER,
    height_inches INTEGER,
    weight_pounds REAL,
    runs_with_water_bottle BOOLEAN DEFAULT false,
    gut_training_level TEXT NOT NULL DEFAULT 'moderate'
      CHECK (gut_training_level IN ('low', 'moderate', 'high')),
    onboarding_completed BOOLEAN DEFAULT false,
    temp_plan_data TEXT,
    swipe_hint_shown BOOLEAN DEFAULT false,
    notifications_enabled BOOLEAN DEFAULT false,
    default_reminder_day INTEGER,
    default_reminder_hour INTEGER DEFAULT 17,
    default_reminder_minute INTEGER DEFAULT 0,
    default_reminder_recurring BOOLEAN DEFAULT false,
    app_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  CREATE INDEX idx_user_profiles_device_id ON user_profiles(device_id);
  CREATE INDEX idx_user_profiles_updated_at ON user_profiles(updated_at DESC);

  -- 2. nutrition_plans
  CREATE TABLE IF NOT EXISTS nutrition_plans (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    device_id TEXT NOT NULL CHECK (length(device_id) = 36),
    plan_id TEXT NOT NULL,
    plan_name TEXT NOT NULL,
    plan_data TEXT NOT NULL,
    distance_miles REAL,
    pace_minutes_per_mile REAL,
    total_calories INTEGER,
    notes TEXT,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE
  );

  CREATE INDEX idx_nutrition_plans_device_id ON nutrition_plans(device_id);
  CREATE INDEX idx_nutrition_plans_updated_at ON nutrition_plans(updated_at DESC);
  CREATE INDEX idx_nutrition_plans_is_deleted ON nutrition_plans(is_deleted)
    WHERE is_deleted = false;

  -- 3. food_preferences
  CREATE TABLE IF NOT EXISTS food_preferences (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    device_id TEXT NOT NULL CHECK (length(device_id) = 36),
    food_name TEXT NOT NULL,
    preference TEXT NOT NULL
      CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE,
    UNIQUE(device_id, food_name)
  );

  CREATE INDEX idx_food_preferences_device_id ON food_preferences(device_id);
  CREATE INDEX idx_food_preferences_preference ON food_preferences(preference);

  -- 4. feedback
  CREATE TABLE IF NOT EXISTS feedback (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    device_id TEXT CHECK (length(device_id) = 36),
    plan_name TEXT,
    satisfaction_level INTEGER,
    satisfaction_emoji TEXT,
    satisfaction_label TEXT,
    confidence_level INTEGER,
    confidence_label TEXT,
    reuse_intent TEXT,
    reminder_requested BOOLEAN DEFAULT false,
    missed_reasons TEXT,
    missed_other TEXT,
    reminder_day_of_week INTEGER,
    reminder_hour INTEGER DEFAULT 17,
    reminder_minute INTEGER DEFAULT 0,
    reminder_recurring BOOLEAN DEFAULT false,
    timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE
  );

  CREATE INDEX idx_feedback_device_id ON feedback(device_id);
  CREATE INDEX idx_feedback_created_at ON feedback(created_at DESC);

  -- ============================================================================
  -- FOOD SYSTEM TABLES (7)
  -- ============================================================================

  -- 5. categories
  CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
  );

  INSERT INTO categories (id, name) VALUES
    (1, 'before_run'),
    (2, 'during_run'),
    (3, 'after_run')
  ON CONFLICT (id) DO NOTHING;

  -- 6. product_types
  CREATE TABLE IF NOT EXISTS product_types (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_plural TEXT NOT NULL,
    sort_order INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  CREATE INDEX idx_product_types_sort_order ON product_types(sort_order);

  -- Seed product types
  INSERT INTO product_types (id, code, name, name_plural, sort_order) VALUES
    ('8a847f4f-8c26-41ef-a1e2-132b404be95e', 'gel', 'Gel', 'Gels', 10),
    ('fc915f1b-d541-45fa-ae5c-695ee41073db', 'chew', 'Chew', 'Chews', 20),
    ('d3908cb2-a21d-4ef1-8d33-c999d29eefcc', 'drink_mix', 'Drink mix', 'Drink mixes', 30),
    ('09930546-1942-485e-9728-bced1cf933a2', 'electrolyte_only', 'Electrolyte-only', 'Electrolyte-only', 40),
    ('b27bc986-1402-4e20-b022-a65b5ffbd4d2', 'sports_drink', 'Sports drink', 'Sports drinks', 50),
    ('6102eea1-2dfe-44cf-8863-b258c27262ef', 'bar', 'Bar', 'Bars', 60),
    ('666408c5-6d5b-4fc6-bda3-d6428e8362b9', 'waffle', 'Waffle', 'Waffles', 70),
    ('52a0ff7c-a0f5-4e26-b409-2a7ce3298f4d', 'capsule', 'Capsule', 'Capsules', 80),
    ('76c16c67-1746-47d7-adea-e5fc9dcd1f4d', 'real_food', 'Real food', 'Real foods', 90),
    ('cbcfd036-127c-43fb-88d5-34a9d9ba5db4', 'recovery_shake', 'Recovery shake', 'Recovery shakes', 100),
    ('3b5d6f2e-3d3a-4b6a-9e3b-5c7a1f0d7a10', 'quick_carbs', 'Quick carb', 'Quick carbs', 10),
    ('8f4f2c73-9a65-4d5a-b3be-9d5f9e2a1c2d', 'solid_carb_snacks', 'Solid carb snack', 'Solid carb snacks', 20),
    ('f2a8c4e1-7d82-4d9b-8b79-9a03e7b4a6c1', 'real_food_carbs', 'Real-food carb', 'Real-food carbs', 30),
    ('c7e2a1d4-5b6c-4f9d-8e2a-1a7c9b3e5d2f', 'hydration_with_carbs', 'Hydration with carbs', 'Hydration with carbs', 40),
    ('a1e2c3d4-b5a6-4c7d-8e9f-0a1b2c3d4e5f', 'electrolytes_fluids', 'Electrolytes & fluids', 'Electrolytes & fluids', 50),
    ('d4c3b2a1-6e5d-4c3b-8a9f-1e2d3c4b5a6f', 'protein_recovery', 'Protein & recovery', 'Protein & recovery', 60),
    ('cdd6a8f1-750c-4c78-93f7-ab706285ac7b', 'imported', 'Imported', 'Imported', 70)
  ON CONFLICT (id) DO NOTHING;

  -- 7. foods (abbreviated - add all nutrition columns)
  CREATE TABLE IF NOT EXISTS foods (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    name TEXT NOT NULL,
    display_name TEXT,
    image_address TEXT,
    description TEXT,
    instructions TEXT,
    nutritional_info TEXT,
    serving_amount REAL,
    serving_unit TEXT,
    serving_unit_plural TEXT,
    serving_qualifier TEXT,
    serving_size TEXT,
    serving_description TEXT,
    before_run_suitable BOOLEAN DEFAULT false,
    during_run_suitable BOOLEAN DEFAULT false,
    after_run_suitable BOOLEAN DEFAULT false,
    run_portable BOOLEAN DEFAULT false,
    requires_preparation BOOLEAN DEFAULT false,
    aid_station_available BOOLEAN DEFAULT false,
    is_electrolyte BOOLEAN DEFAULT false,
    max_servings_before INTEGER,
    max_servings_during INTEGER,
    max_servings_after INTEGER,
    sodium_mg INTEGER,
    caffeine_mg INTEGER,
    potassium_mg INTEGER,
    fat_per_serving REAL,
    carbs_per_serving REAL,
    protein_per_serving REAL,
    calories_per_serving INTEGER,
    fluid_ml_per_serving REAL,
    product_type_id TEXT,
    purchase_url TEXT,
    affiliate_source TEXT,
    show_in_preferences BOOLEAN DEFAULT false,
    preference_priority INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (product_type_id) REFERENCES product_types(id)
  );

  CREATE INDEX idx_foods_product_type_id ON foods(product_type_id);
  CREATE INDEX idx_foods_show_in_preferences ON foods(show_in_preferences)
    WHERE show_in_preferences = true;

  -- 8. food_categories
  CREATE TABLE IF NOT EXISTS food_categories (
    food_id TEXT NOT NULL CHECK (length(food_id) = 36),
    category_id INTEGER NOT NULL,
    PRIMARY KEY (food_id, category_id),
    FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
  );

  CREATE INDEX idx_food_categories_category_id ON food_categories(category_id);

  -- 9. user_foods
  CREATE TABLE IF NOT EXISTS user_foods (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    device_id TEXT NOT NULL CHECK (length(device_id) = 36),
    client_food_id TEXT,
    barcode TEXT,
    name TEXT NOT NULL,
    display_name TEXT,
    display_name_plural TEXT,
    description TEXT,
    image_address TEXT,
    serving_amount REAL,
    serving_unit TEXT,
    calories_per_serving INTEGER,
    carbs_per_serving REAL,
    protein_per_serving REAL,
    fat_per_serving REAL,
    sodium_mg INTEGER,
    fluid_ml_per_serving REAL,
    product_type_id TEXT,
    to_exclude_from_solver BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE,
    FOREIGN KEY (product_type_id) REFERENCES product_types(id)
  );

  CREATE INDEX idx_user_foods_device_id ON user_foods(device_id);
  CREATE INDEX idx_user_foods_barcode ON user_foods(barcode) WHERE barcode IS NOT NULL;
  CREATE INDEX idx_user_foods_is_deleted ON user_foods(is_deleted) WHERE is_deleted = false;

  -- 10. user_food_categories
  CREATE TABLE IF NOT EXISTS user_food_categories (
    user_food_id TEXT NOT NULL CHECK (length(user_food_id) = 36),
    category_id INTEGER NOT NULL,
    PRIMARY KEY (user_food_id, category_id),
    FOREIGN KEY (user_food_id) REFERENCES user_foods(id) ON DELETE CASCADE,
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
  );

  CREATE INDEX idx_user_food_categories_category_id ON user_food_categories(category_id);

  -- 11. user_hidden_foods
  CREATE TABLE IF NOT EXISTS user_hidden_foods (
    device_id TEXT NOT NULL CHECK (length(device_id) = 36),
    food_id TEXT NOT NULL CHECK (length(food_id) = 36),
    hidden_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (device_id, food_id),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE,
    FOREIGN KEY (food_id) REFERENCES foods(id) ON DELETE CASCADE
  );

  CREATE INDEX idx_user_hidden_foods_device_id ON user_hidden_foods(device_id);

  -- ============================================================================
  -- CONTENT & FEATURES TABLES (5)
  -- ============================================================================

  -- 12. app_content
  CREATE TABLE IF NOT EXISTS app_content (
    id TEXT PRIMARY KEY,
    version INTEGER NOT NULL DEFAULT 1,
    environment TEXT NOT NULL DEFAULT 'production',
    locale TEXT NOT NULL DEFAULT 'en',
    content TEXT NOT NULL DEFAULT '{}',
    is_active BOOLEAN DEFAULT true,
    last_sync_at TIMESTAMPTZ,
    is_cached BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  CREATE INDEX idx_app_content_env_locale ON app_content(environment, locale, is_active);
  CREATE INDEX idx_app_content_version ON app_content(version DESC);

  -- 13. edge_functions
  CREATE TABLE IF NOT EXISTS edge_functions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    code TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );

  CREATE INDEX idx_edge_functions_name ON edge_functions(name);
  CREATE INDEX idx_edge_functions_is_active ON edge_functions(is_active)
    WHERE is_active = true;

  -- 14. macro_targets
  CREATE TABLE IF NOT EXISTS macro_targets (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    device_id TEXT NOT NULL CHECK (length(device_id) = 36),
    distance_miles REAL NOT NULL,
    pace_minutes_per_mile REAL NOT NULL,
    weight_pounds REAL NOT NULL,
    gut_training_level TEXT NOT NULL,
    duration_minutes REAL,
    intensity_level TEXT,
    base_met REAL,
    adjusted_met REAL,
    hourly_calorie_burn REAL,
    total_calorie_burn REAL,
    pre_run_carbs_g REAL,
    pre_run_protein_g REAL,
    pre_run_fat_g REAL,
    pre_run_calories REAL,
    pre_run_hours_before REAL,
    during_run_carbs_g_total REAL,
    during_run_carbs_g_per_hour REAL,
    during_run_fluid_ml_total REAL,
    during_run_fluid_ml_per_hour REAL,
    during_run_sodium_mg_total REAL,
    during_run_sodium_mg_per_hour REAL,
    during_run_caffeine_mg_max REAL,
    post_run_carbs_g REAL,
    post_run_protein_g REAL,
    post_run_window_minutes REAL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE
  );

  CREATE INDEX idx_macro_targets_device_id ON macro_targets(device_id);
  CREATE INDEX idx_macro_targets_created_at ON macro_targets(created_at DESC);

  -- 15. workout_notes
  CREATE TABLE IF NOT EXISTS workout_notes (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    device_id TEXT NOT NULL CHECK (length(device_id) = 36),
    plan_id TEXT,
    note_text TEXT NOT NULL,
    workout_date TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE
  );

  CREATE INDEX idx_workout_notes_device_id ON workout_notes(device_id);
  CREATE INDEX idx_workout_notes_workout_date ON workout_notes(workout_date DESC);

  -- 16. carb_loading_simple_plans
  CREATE TABLE IF NOT EXISTS carb_loading_simple_plans (
    id TEXT PRIMARY KEY CHECK (length(id) = 36),
    device_id TEXT NOT NULL CHECK (length(device_id) = 36),
    race_date TIMESTAMPTZ NOT NULL,
    race_name TEXT,
    plan_data TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    FOREIGN KEY (device_id) REFERENCES user_profiles(device_id) ON DELETE CASCADE
  );

  CREATE INDEX idx_carb_loading_simple_plans_device_id
    ON carb_loading_simple_plans(device_id);
  CREATE INDEX idx_carb_loading_simple_plans_race_date
    ON carb_loading_simple_plans(race_date);

  -- ============================================================================
  -- ROW LEVEL SECURITY (RLS)
  -- ============================================================================

  -- Enable RLS on user-specific tables
  ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
  ALTER TABLE nutrition_plans ENABLE ROW LEVEL SECURITY;
  ALTER TABLE food_preferences ENABLE ROW LEVEL SECURITY;
  ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
  ALTER TABLE user_foods ENABLE ROW LEVEL SECURITY;
  ALTER TABLE user_food_categories ENABLE ROW LEVEL SECURITY;
  ALTER TABLE user_hidden_foods ENABLE ROW LEVEL SECURITY;
  ALTER TABLE macro_targets ENABLE ROW LEVEL SECURITY;
  ALTER TABLE workout_notes ENABLE ROW LEVEL SECURITY;
  ALTER TABLE carb_loading_simple_plans ENABLE ROW LEVEL SECURITY;

  -- RLS Policies for user_profiles
  CREATE POLICY "Users can read own profile"
    ON user_profiles FOR SELECT
    USING (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can update own profile"
    ON user_profiles FOR UPDATE
    USING (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can insert own profile"
    ON user_profiles FOR INSERT
    WITH CHECK (device_id = current_setting('app.device_id', true));

  -- RLS Policies for nutrition_plans
  CREATE POLICY "Users can read own nutrition plans"
    ON nutrition_plans FOR SELECT
    USING (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can insert own nutrition plans"
    ON nutrition_plans FOR INSERT
    WITH CHECK (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can update own nutrition plans"
    ON nutrition_plans FOR UPDATE
    USING (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can delete own nutrition plans"
    ON nutrition_plans FOR DELETE
    USING (device_id = current_setting('app.device_id', true));

  -- RLS Policies for other user-specific tables (simplified)
  CREATE POLICY "Users can manage own food preferences"
    ON food_preferences FOR ALL
    USING (device_id = current_setting('app.device_id', true))
    WITH CHECK (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can manage own feedback"
    ON feedback FOR ALL
    USING (device_id = current_setting('app.device_id', true))
    WITH CHECK (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can manage own user foods"
    ON user_foods FOR ALL
    USING (device_id = current_setting('app.device_id', true))
    WITH CHECK (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can manage own macro targets"
    ON macro_targets FOR ALL
    USING (device_id = current_setting('app.device_id', true))
    WITH CHECK (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can manage own workout notes"
    ON workout_notes FOR ALL
    USING (device_id = current_setting('app.device_id', true))
    WITH CHECK (device_id = current_setting('app.device_id', true));

  CREATE POLICY "Users can manage own carb loading plans"
    ON carb_loading_simple_plans FOR ALL
    USING (device_id = current_setting('app.device_id', true))
    WITH CHECK (device_id = current_setting('app.device_id', true));

  -- ============================================================================
  -- UPDATED_AT TRIGGERS
  -- ============================================================================

  CREATE OR REPLACE FUNCTION update_updated_at_column()
  RETURNS TRIGGER AS $$
  BEGIN
    NEW.updated_at = now();
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql;

  CREATE TRIGGER update_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_nutrition_plans_updated_at
    BEFORE UPDATE ON nutrition_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_food_preferences_updated_at
    BEFORE UPDATE ON food_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_foods_updated_at
    BEFORE UPDATE ON foods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_user_foods_updated_at
    BEFORE UPDATE ON user_foods
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_app_content_updated_at
    BEFORE UPDATE ON app_content
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_edge_functions_updated_at
    BEFORE UPDATE ON edge_functions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_workout_notes_updated_at
    BEFORE UPDATE ON workout_notes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

  CREATE TRIGGER update_carb_loading_simple_plans_updated_at
    BEFORE UPDATE ON carb_loading_simple_plans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
  ```

- [ ] **Test migration locally** (optional):
  ```bash
  supabase start
  supabase db reset
  supabase db diff  # Should be clean
  ```

- [ ] **Deploy to dev**:
  ```bash
  # Link to dev (use credentials from .env.dev.local)
  supabase link --project-ref <DEV_PROJECT_ID>

  # Deploy the migration
  supabase db push

  # Verify
  supabase db diff  # Should show no differences
  ```

- [ ] **Deploy to production**:
  ```bash
  # Link to prod (use credentials from .env.prod.local)
  supabase link --project-ref wvmvsodrvbkxfydabqed

  # Show what will change (safety check)
  supabase db diff

  # Deploy the migration
  supabase db push

  # Verify
  supabase db diff  # Should show no differences
  ```

- [ ] **Verify deployment in Supabase Dashboard**:
  - Dev: Check https://supabase.com/dashboard/project/<DEV_PROJECT_ID>/editor
  - Prod: Check https://supabase.com/dashboard/project/wvmvsodrvbkxfydabqed/editor
  - Confirm all 26 tables exist in both
  - Verify RLS policies are enabled

**Success Criteria**:
- ✅ Drift has 26 tables (v1)
- ✅ Both dev and prod Supabase projects have identical 26 tables
- ✅ No schema drift detected
- ✅ V1 snapshot saved in `database_schemas/v1/`

---

## Phase 2: GitHub Actions Testing (Week 2)

**Objective**: Validate automated deployments work correctly

### 2.1 Test Development Auto-Deploy

- [ ] **Push to develop branch**:
  ```bash
  # Make a small migration change
  supabase migration new add_test_comment

  # Add a comment to the migration file
  echo "-- Test deployment comment" >> supabase/migrations/<timestamp>_add_test_comment.sql

  # Commit and push
  git add supabase/migrations/
  git commit -m "Test dev auto-deploy"
  git push origin develop
  ```

- [ ] **Monitor GitHub Actions**:
  - Go to: https://github.com/YOUR_USERNAME/mealvana_endurance/actions
  - Verify "Deploy to Dev" workflow runs successfully
  - Check workflow logs for deployment confirmation

### 2.2 Test Production Manual Approval

- [ ] **Merge to main**:
  ```bash
  git checkout main
  git merge develop
  git push origin main
  ```

- [ ] **Approve production deployment**:
  - Go to: https://github.com/YOUR_USERNAME/mealvana_endurance/actions
  - Click on the "Deploy to Production" workflow
  - Click "Review deployments"
  - Click "Approve and deploy"
  - Monitor logs for successful deployment

### 2.3 Test Schema Drift Detection

- [ ] **Trigger drift check manually**:
  - Go to: https://github.com/YOUR_USERNAME/mealvana_endurance/actions
  - Click "Schema Drift Check" workflow
  - Click "Run workflow" button
  - Monitor execution

- [ ] **Verify drift detection works**:
  - Make a schema change directly in Supabase dashboard (add a comment to a table)
  - Wait for daily cron job or trigger manually
  - Verify GitHub issue is created when drift is detected

**Success Criteria**:
- ✅ Dev auto-deploys on push to develop
- ✅ Production requires manual approval
- ✅ Drift detection creates GitHub issues
- ✅ All workflows complete successfully

---

## Phase 3: Testing Infrastructure (Week 2-3)

**Objective**: Add comprehensive testing to CI/CD pipeline

### 3.1 Understand Current Test Structure

**Review existing test infrastructure**:
- Edge function tests (150+ tests in Vitest)
- Flutter/Dart tests (11+ tests and growing)
- Test fixtures and helpers
- Three-tier testing strategy

**Key Testing Docs**:
- `/docs/test/README.md` - Complete testing handbook
- `/docs/test/roadmap.md` - Testing implementation roadmap
- `/docs/test/riverpod_3_testing.md` - Riverpod testing patterns

### 3.2 Run Tests Locally

- [ ] **Test edge functions**:
  ```bash
  cd _archived/test/local_edge_functions
  npm install
  npm test  # Should see 150+ tests pass
  ```

- [ ] **Test Flutter/Dart code**:
  ```bash
  # Run all tests (excluding tagged edge tests)
  flutter test

  # Run edge integration tests
  flutter test --tags edge --dart-define-from-file=.env.test_supabase
  ```

### 3.3 Create GitHub Actions Testing Workflow

- [ ] **Create** `.github/workflows/test.yml`:
  ```yaml
  name: Run Tests

  on:
    pull_request:
      branches: [develop, main]
    push:
      branches: [develop, main]
    workflow_dispatch:

  jobs:
    flutter-tests:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4

        - uses: subosito/flutter-action@v2
          with:
            flutter-version: '3.24.0'
            channel: 'stable'

        - name: Install dependencies
          run: flutter pub get

        - name: Run Flutter tests
          run: flutter test --coverage

        - name: Upload coverage
          uses: codecov/codecov-action@v4
          if: always()
          with:
            file: ./coverage/lcov.info

    edge-function-tests:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4

        - uses: actions/setup-node@v4
          with:
            node-version: '20'

        - name: Install dependencies
          working-directory: _archived/test/local_edge_functions
          run: npm install

        - name: Run edge function tests
          working-directory: _archived/test/local_edge_functions
          run: npm test

    edge-integration-tests:
      runs-on: ubuntu-latest
      # Only run on manual trigger or schedule (uses dev Supabase)
      if: github.event_name == 'workflow_dispatch' || github.event_name == 'schedule'
      steps:
        - uses: actions/checkout@v4

        - uses: subosito/flutter-action@v2
          with:
            flutter-version: '3.24.0'
            channel: 'stable'

        - name: Install dependencies
          run: flutter pub get

        - name: Run edge integration tests
          run: flutter test --tags edge
          env:
            SUPABASE_URL: ${{ secrets.DEV_SUPABASE_URL }}
            SUPABASE_ANON_KEY: ${{ secrets.DEV_ANON_KEY }}
  ```

- [ ] **Test the workflow**:
  ```bash
  # Create a PR from develop to main
  # Verify tests run automatically
  ```

**Success Criteria**:
- ✅ Tests run on every PR
- ✅ Flutter tests pass (11+ tests)
- ✅ Edge function tests pass (150+ tests)
- ✅ Coverage reports uploaded
- ✅ Integration tests run on schedule/manual trigger

---

## Phase 4: Documentation Updates (Week 3)

**Objective**: Ensure all documentation reflects two-environment setup

### 4.1 Update Technical Documentation

- [ ] **Update** `/docs/database/README.md`:
  - Remove staging references
  - Update environment count (2 environments)
  - Update workflow diagrams

- [ ] **Update** `/CLAUDE.md`:
  - Update environment setup section
  - Update GitHub Actions references
  - Remove staging from all examples

### 4.2 Create Team Runbooks

- [ ] **Create** `/docs/runbooks/deployments.md`:
  - Standard deployment workflow
  - Emergency rollback procedures
  - Schema migration guidelines
  - Troubleshooting common issues

- [ ] **Create** `/docs/runbooks/schema-changes.md`:
  - How to create migrations
  - Testing migrations locally
  - Deploying to environments
  - Handling drift

**Success Criteria**:
- ✅ All documentation updated
- ✅ Runbooks created and reviewed
- ✅ Team understands workflows
- ✅ No staging references remain

---

## Phase 5: Production Cutover (Week 3)

**Objective**: Finalize production deployment and verify system health

### 5.1 Final Verification

- [ ] **Backup** current production database:
  ```bash
  # From Supabase dashboard
  # Settings → Database → Backups
  # Create manual backup before migration
  ```

- [ ] **Run final schema diff check**:
  ```bash
  supabase link --project-ref wvmvsodrvbkxfydabqed
  supabase db diff
  # Should be clean
  ```

- [ ] **Verify all GitHub Actions workflows**:
  - Deploy to Dev: ✅ Working
  - Deploy to Production: ✅ Working
  - Schema Drift Check: ✅ Working
  - Run Tests: ✅ Working

- [ ] **Test rollback procedure**:
  - Document how to rollback a migration
  - Test locally with `supabase db reset`

### 5.2 Go Live

- [ ] **Merge** to main branch
- [ ] **Approve** production deployment
- [ ] **Monitor** deployment logs
- [ ] **Verify** production health:
  - Check Supabase dashboard (all 26 tables present)
  - Verify RLS policies active
  - Test app connectivity

### 5.3 Post-Deployment Monitoring

- [ ] **Monitor** Sentry for errors (first 24 hours)
- [ ] **Check** Mixpanel events routing correctly
- [ ] **Verify** schema drift checks running daily
- [ ] **Document** lessons learned

**Success Criteria**:
- ✅ Production running on unified v1 schema
- ✅ Both environments operational
- ✅ Automated deployments working
- ✅ Zero downtime during cutover
- ✅ Monitoring confirms health

---

## Timeline Summary

| Phase | Duration | Status | Key Deliverables |
|-------|----------|--------|------------------|
| 1. Clean V1 Baseline | 1-2 days | 🔄 Ready | 16-table schema deployed to both environments |
| 2. GitHub Actions Testing | 1-2 days | 🔄 Ready | Verified auto-deploy and manual approval |
| 3. Testing Infrastructure | 2-3 days | 🔄 Ready | CI/CD pipeline with 160+ tests |
| 4. Documentation | 1-2 days | 🔄 Ready | Updated docs, runbooks created |
| 5. Production Cutover | 1 day | 🔄 Ready | Live on v1 unified schema |

**Total:** 2-3 weeks

---

## Success Metrics

### Schema Unification
- ✅ 26 tables in both Drift and Supabase
- ✅ 100% parity across dev and prod environments
- ✅ No schema drift detected
- ✅ V1 baseline documented

### Automation
- ✅ GitHub Actions deploy to both environments
- ✅ Daily drift detection operational
- ✅ Manual approval for production
- ✅ Automated testing on PRs (160+ tests)

### Testing Coverage
- ✅ 150+ edge function tests (Vitest)
- ✅ 11+ Flutter/Dart tests (growing)
- ✅ Three-tier testing strategy implemented
- ✅ CI/CD pipeline executing tests

### Zero Data Loss
- ✅ All existing data preserved
- ✅ Rollback procedures documented and tested
- ✅ Backups verified

### Team Enablement
- ✅ Documentation complete and accurate
- ✅ Workflows understood and tested
- ✅ Runbooks available for common tasks
- ✅ Deployment confidence high

---

**Last Updated**: 2025-10-06
**Status**: Ready for Phase 1
**Environments**: Dev + Production (2 total)
