-- Mealvana Endurance Complete Database Schema
-- Last Updated: Current
-- Database: PostgreSQL (Supabase)

-- ============================================
-- FEEDBACK TABLE
-- ============================================
-- Stores user feedback for nutrition plans
CREATE TABLE public.feedback (
    id                 UUID DEFAULT uuid_generate_v4() NOT NULL PRIMARY KEY,
    satisfaction_level INTEGER NOT NULL CHECK (satisfaction_level >= 1 AND satisfaction_level <= 3),
    satisfaction_emoji TEXT NOT NULL,
    satisfaction_label TEXT NOT NULL,
    app_feedback       TEXT,
    suggestions        TEXT,
    plan_name          TEXT,
    user_name          TEXT,
    timestamp          TIMESTAMP WITH TIME ZONE,
    created_at         TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX idx_feedback_created_at ON public.feedback (created_at DESC);
CREATE INDEX idx_feedback_satisfaction ON public.feedback (satisfaction_level);

-- RLS Policies
CREATE POLICY "Allow feedback submissions" ON public.feedback
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Allow feedback reading" ON public.feedback
    FOR SELECT USING (true);

-- ============================================
-- APP CONTENT TABLE
-- ============================================
-- Stores dynamic content and configuration
CREATE TABLE public.app_content (
    id          UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    version     INTEGER DEFAULT 1 NOT NULL,
    environment TEXT DEFAULT 'production' NOT NULL,
    locale      TEXT DEFAULT 'en' NOT NULL,
    content     JSONB NOT NULL,
    is_active   BOOLEAN DEFAULT true NOT NULL,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by  UUID,
    updated_by  UUID
);

-- Indexes
CREATE INDEX idx_app_content_active ON public.app_content (is_active);
CREATE INDEX idx_app_content_env_locale ON public.app_content (environment, locale);
CREATE INDEX idx_app_content_version ON public.app_content (version);

-- Trigger for updated_at
CREATE TRIGGER update_app_content_updated_at
    BEFORE UPDATE ON public.app_content
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies
CREATE POLICY "Allow public read access to app_content" ON public.app_content
    FOR SELECT USING (true);

CREATE POLICY "Allow authenticated insert to app_content" ON public.app_content
    FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Allow authenticated update to app_content" ON public.app_content
    FOR UPDATE USING (auth.role() = 'authenticated');

-- ============================================
-- USERS TABLE
-- ============================================
-- Stores user profiles and preferences
CREATE TABLE public.users (
    id                      UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    device_id               TEXT NOT NULL UNIQUE,
    created_at              TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at              TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    gender                  TEXT CHECK (gender IN ('male', 'female', 'other')),
    birthday                DATE,
    height_feet             INTEGER,
    height_inches           INTEGER,
    weight_pounds           NUMERIC(5, 2),
    runs_with_water_bottle  BOOLEAN DEFAULT false,
    food_preferences        JSONB DEFAULT '{}',
    preferred_distance_unit TEXT DEFAULT 'miles' CHECK (preferred_distance_unit IN ('miles', 'kilometers')),
    preferred_pace_unit     TEXT DEFAULT 'min_per_mile' CHECK (preferred_pace_unit IN ('min_per_mile', 'min_per_km')),
    gut_training_level      TEXT DEFAULT 'moderate' CHECK (gut_training_level IN ('low', 'moderate', 'high')),
    onboarding_completed    BOOLEAN DEFAULT false,
    last_active_at          TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    app_version             TEXT
);

-- Indexes
CREATE INDEX idx_users_device_id ON public.users (device_id);
CREATE INDEX idx_users_updated_at ON public.users (updated_at);

-- Trigger for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies
CREATE POLICY "Users can read own data" ON public.users
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own data" ON public.users
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own data" ON public.users
    FOR UPDATE USING (true);

-- ============================================
-- FOODS TABLE
-- ============================================
-- Master food database with nutritional information
CREATE TABLE public.foods (
    id                    UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name                  TEXT NOT NULL,
    icon_path             TEXT,
    description           TEXT,
    instructions          TEXT,
    nutritional_info      JSONB DEFAULT '{}',
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Serving information
    serving_amount        NUMERIC,
    serving_unit          TEXT,
    serving_unit_plural   TEXT,
    serving_qualifier     TEXT,
    serving_size          TEXT,
    
    -- Phase suitability flags
    before_run_suitable   BOOLEAN DEFAULT false,
    during_run_suitable   BOOLEAN DEFAULT false,
    run_portable          BOOLEAN DEFAULT false,
    requires_preparation  BOOLEAN DEFAULT false,
    aid_station_available BOOLEAN DEFAULT false,
    
    -- Serving limits
    max_servings_before   INTEGER,
    max_servings_during   INTEGER,
    
    -- Nutritional values per serving
    calories_per_serving  INTEGER,
    carbs_per_serving     NUMERIC(10, 2),
    protein_per_serving   NUMERIC(10, 2),
    fat_per_serving       NUMERIC(10, 2),
    sodium_mg             INTEGER,
    caffeine_mg           INTEGER,
    potassium_mg          INTEGER,
    fluid_ml_per_serving  NUMERIC(10, 1)
);

-- RLS Policies
CREATE POLICY "Anyone can read foods" ON public.foods
    FOR SELECT USING (true);

-- ============================================
-- CATEGORIES TABLE
-- ============================================
-- Food category definitions
CREATE TABLE public.categories (
    id   INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL
);

-- Insert standard categories
INSERT INTO public.categories (id, name) VALUES
    (1, 'before_run'),
    (2, 'during_run'),
    (3, 'after_run'),
    (4, 'hydration'),
    (5, 'recovery');

-- RLS Policies
CREATE POLICY "Anyone can read categories" ON public.categories
    FOR SELECT USING (true);

-- ============================================
-- FOOD_CATEGORIES TABLE
-- ============================================
-- Junction table linking foods to categories
CREATE TABLE public.food_categories (
    food_id     UUID NOT NULL REFERENCES public.foods(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES public.categories(id),
    PRIMARY KEY (food_id, category_id)
);

-- Indexes
CREATE INDEX idx_food_categories_food ON public.food_categories (food_id);
CREATE INDEX idx_food_categories_category_id ON public.food_categories (category_id);

-- RLS Policies
CREATE POLICY "Anyone can read food_categories" ON public.food_categories
    FOR SELECT USING (true);

-- ============================================
-- FOOD_PREFERENCES TABLE
-- ============================================
-- User-specific food preferences
CREATE TABLE public.food_preferences (
    id         UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    device_id  TEXT NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
    food_name  TEXT NOT NULL,
    preference TEXT NOT NULL CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Comments
COMMENT ON TABLE public.food_preferences IS 'Stores user food preferences (like, dislike, willing_to_try) linked by device_id';
COMMENT ON COLUMN public.food_preferences.device_id IS 'References users.device_id - user who owns this preference';
COMMENT ON COLUMN public.food_preferences.food_name IS 'Name of the food item (should match foods.name)';
COMMENT ON COLUMN public.food_preferences.preference IS 'User preference: like, dislike, or willing_to_try';

-- Indexes
CREATE UNIQUE INDEX idx_food_preferences_device_food ON public.food_preferences (device_id, food_name);
CREATE INDEX idx_food_preferences_device_id ON public.food_preferences (device_id);
CREATE INDEX idx_food_preferences_preference ON public.food_preferences (preference);

-- Trigger for updated_at
CREATE TRIGGER update_food_preferences_updated_at
    BEFORE UPDATE ON public.food_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies
CREATE POLICY "Allow all operations on food_preferences" ON public.food_preferences
    FOR ALL USING (true) WITH CHECK (true);

-- ============================================
-- NUTRITION_PLANS TABLE
-- ============================================
-- Stores generated nutrition plans
CREATE TABLE public.nutrition_plans (
    id                    UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    device_id             TEXT NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
    plan_data             JSONB NOT NULL,
    distance_miles        NUMERIC(5, 2),
    pace_minutes_per_mile NUMERIC(5, 2),
    created_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at            TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    plan_id               TEXT NOT NULL,
    plan_name             TEXT NOT NULL,
    total_calories        INTEGER,
    notes                 TEXT,
    version               INTEGER DEFAULT 1,
    last_modified_by      TEXT,
    client_updated_at     TIMESTAMP WITH TIME ZONE,
    is_deleted            BOOLEAN DEFAULT false,
    conflict_resolution   TEXT,
    UNIQUE (device_id, plan_id)
);

-- Indexes
CREATE INDEX idx_nutrition_plans_device_id ON public.nutrition_plans (device_id);
CREATE INDEX idx_nutrition_plans_created_at ON public.nutrition_plans (created_at DESC);
CREATE INDEX idx_nutrition_plans_plan_id ON public.nutrition_plans (plan_id);
CREATE INDEX idx_nutrition_plans_updated_at ON public.nutrition_plans (updated_at DESC);
CREATE INDEX idx_nutrition_plans_device_updated ON public.nutrition_plans (device_id ASC, updated_at DESC);

-- Trigger for updated_at
CREATE TRIGGER update_nutrition_plans_updated_at
    BEFORE UPDATE ON public.nutrition_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- RLS Policies
CREATE POLICY "Users can read own plans" ON public.nutrition_plans
    FOR SELECT USING (true);

CREATE POLICY "Users can insert own plans" ON public.nutrition_plans
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Users can update own plans" ON public.nutrition_plans
    FOR UPDATE USING (true);

CREATE POLICY "Users can delete own plans" ON public.nutrition_plans
    FOR DELETE USING (true);

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Generic updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to upsert food preferences
CREATE OR REPLACE FUNCTION upsert_food_preferences(
    p_device_id TEXT,
    p_preferences JSONB
)
RETURNS VOID AS $$
DECLARE
    food_key TEXT;
    food_preference TEXT;
BEGIN
    -- Delete existing preferences for this device
    DELETE FROM public.food_preferences WHERE device_id = p_device_id;
    
    -- Insert new preferences
    FOR food_key, food_preference IN SELECT * FROM jsonb_each_text(p_preferences)
    LOOP
        INSERT INTO public.food_preferences (device_id, food_name, preference)
        VALUES (p_device_id, food_key, food_preference);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- GRANTS
-- ============================================

-- Grant permissions to different roles
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO service_role;