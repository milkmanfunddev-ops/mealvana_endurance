-- Supabase Schema V3 - Mealvana Endurance
-- Adds user-specific food management tables

-- =====================================================
-- USERS TABLE (Updated with notification preferences)
-- =====================================================
CREATE TABLE public.users (
    id UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    device_id TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    birthday DATE,
    height_feet INTEGER,
    height_inches INTEGER,
    weight_pounds NUMERIC(5,2),
    runs_with_water_bottle BOOLEAN DEFAULT false,
    food_preferences JSONB DEFAULT '{}'::jsonb,
    preferred_distance_unit TEXT DEFAULT 'miles' CHECK (preferred_distance_unit IN ('miles', 'kilometers')),
    preferred_pace_unit TEXT DEFAULT 'min_per_mile' CHECK (preferred_pace_unit IN ('min_per_mile', 'min_per_km')),
    gut_training_level TEXT DEFAULT 'moderate' CHECK (gut_training_level IN ('low', 'moderate', 'high')),
    onboarding_completed BOOLEAN DEFAULT false,
    last_active_at TIMESTAMPTZ DEFAULT now(),
    app_version TEXT,
    notifications_enabled BOOLEAN DEFAULT false,
    default_reminder_day INTEGER DEFAULT 4,
    default_reminder_hour INTEGER DEFAULT 17,
    default_reminder_minute INTEGER DEFAULT 0,
    default_reminder_recurring BOOLEAN DEFAULT false
);

-- Indexes
CREATE INDEX idx_users_device_id ON public.users(device_id);
CREATE INDEX idx_users_updated_at ON public.users(updated_at);

-- Trigger for updated_at
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- USER FOODS TABLE (NEW IN V3)
-- =====================================================
-- Stores custom foods that users have added or scanned
CREATE TABLE public.user_foods (
    id UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
    client_food_id TEXT,  -- Client-generated ID for offline sync
    barcode TEXT,         -- Barcode if scanned
    name TEXT NOT NULL,
    display_name TEXT,
    display_name_plural TEXT,
    description TEXT,
    image_address TEXT,
    serving_amount NUMERIC,
    serving_unit TEXT,
    calories_per_serving INTEGER,
    carbs_per_serving NUMERIC(10,2),
    protein_per_serving NUMERIC(10,2),
    fat_per_serving NUMERIC(10,2),
    sodium_mg INTEGER,
    fluid_ml_per_serving NUMERIC(10,1),
    product_type_id UUID REFERENCES public.product_types(id),
    is_electrolyte BOOLEAN DEFAULT false,
    to_exclude_from_solver BOOLEAN DEFAULT false,
    is_deleted BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    client_updated_at TIMESTAMPTZ,
    UNIQUE(device_id, client_food_id)
);

-- Indexes for user_foods
CREATE INDEX idx_user_foods_device ON public.user_foods(device_id);
CREATE INDEX idx_user_foods_barcode ON public.user_foods(barcode);
CREATE UNIQUE INDEX uq_user_foods_device_clientid ON public.user_foods(device_id, client_food_id);
CREATE INDEX idx_user_foods_device_not_deleted ON public.user_foods(device_id) WHERE is_deleted = false;

-- =====================================================
-- USER FOOD CATEGORIES TABLE (NEW IN V3)
-- =====================================================
-- Links user foods to timing categories
CREATE TABLE public.user_food_categories (
    user_food_id UUID NOT NULL REFERENCES public.user_foods(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES public.categories(id),
    PRIMARY KEY (user_food_id, category_id)
);

-- Indexes
CREATE INDEX idx_user_food_categories_user_food ON public.user_food_categories(user_food_id);
CREATE INDEX idx_user_food_categories_category ON public.user_food_categories(category_id);

-- =====================================================
-- USER HIDDEN FOODS TABLE (NEW IN V3)
-- =====================================================
-- Tracks which generic foods a user has hidden
CREATE TABLE public.user_hidden_foods (
    device_id TEXT NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
    food_id UUID NOT NULL REFERENCES public.foods(id) ON DELETE CASCADE,
    PRIMARY KEY (device_id, food_id)
);

-- =====================================================
-- NUTRITION PLANS TABLE (Existing)
-- =====================================================
CREATE TABLE public.nutrition_plans (
    id UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
    plan_data JSONB NOT NULL,
    distance_miles NUMERIC(5,2),
    pace_minutes_per_mile NUMERIC(5,2),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    plan_id TEXT NOT NULL,
    plan_name TEXT NOT NULL,
    total_calories INTEGER,
    notes TEXT,
    version INTEGER DEFAULT 1,
    last_modified_by TEXT,
    client_updated_at TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT false,
    conflict_resolution TEXT,
    UNIQUE(device_id, plan_id)
);

-- Indexes
CREATE INDEX idx_nutrition_plans_device_id ON public.nutrition_plans(device_id);
CREATE INDEX idx_nutrition_plans_created_at ON public.nutrition_plans(created_at DESC);
CREATE INDEX idx_nutrition_plans_plan_id ON public.nutrition_plans(plan_id);
CREATE INDEX idx_nutrition_plans_updated_at ON public.nutrition_plans(updated_at DESC);
CREATE INDEX idx_nutrition_plans_device_updated ON public.nutrition_plans(device_id ASC, updated_at DESC);

-- Trigger for updated_at
CREATE TRIGGER update_nutrition_plans_updated_at
    BEFORE UPDATE ON public.nutrition_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- CATEGORIES TABLE (Existing)
-- =====================================================
CREATE TABLE public.categories (
    id INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL
);

-- =====================================================
-- FOOD PREFERENCES TABLE (Existing)
-- =====================================================
CREATE TABLE public.food_preferences (
    id UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES public.users(device_id) ON DELETE CASCADE,
    food_name TEXT NOT NULL,
    preference TEXT NOT NULL CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE UNIQUE INDEX idx_food_preferences_device_food ON public.food_preferences(device_id, food_name);
CREATE INDEX idx_food_preferences_device_id ON public.food_preferences(device_id);
CREATE INDEX idx_food_preferences_preference ON public.food_preferences(preference);

-- Trigger for updated_at
CREATE TRIGGER update_food_preferences_updated_at
    BEFORE UPDATE ON public.food_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_food_preferences_updated_at();

-- =====================================================
-- PRODUCT TYPES TABLE (Existing)
-- =====================================================
CREATE TABLE public.product_types (
    id UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    name_plural TEXT NOT NULL,
    sort_order INTEGER,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- FOODS TABLE (Existing)
-- =====================================================
CREATE TABLE public.foods (
    id UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name TEXT,
    image_address TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    serving_amount NUMERIC,
    max_servings_before INTEGER,
    max_servings_during INTEGER,
    max_servings_after INTEGER,
    sodium_mg INTEGER,
    caffeine_mg INTEGER,
    potassium_mg INTEGER,
    fat_per_serving NUMERIC(10,2),
    carbs_per_serving NUMERIC(10,2),
    protein_per_serving NUMERIC(10,2),
    calories_per_serving INTEGER,
    fluid_ml_per_serving NUMERIC(10,1),
    show_in_preferences BOOLEAN DEFAULT false,
    display_name VARCHAR(100),
    display_name_plural VARCHAR(100),
    is_electrolyte BOOLEAN DEFAULT false,
    to_exclude_from_solver BOOLEAN DEFAULT false,
    product_type_id UUID REFERENCES public.product_types(id),
    description TEXT,
    serving_description TEXT
);

-- Indexes
CREATE UNIQUE INDEX uq_foods_lower_name ON public.foods(LOWER(name));
CREATE INDEX idx_foods_product_type_id ON public.foods(product_type_id);

-- =====================================================
-- FOOD CATEGORIES TABLE (Existing)
-- =====================================================
CREATE TABLE public.food_categories (
    food_id UUID NOT NULL REFERENCES public.foods(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES public.categories(id),
    PRIMARY KEY (food_id, category_id)
);

-- Indexes
CREATE INDEX idx_food_categories_food ON public.food_categories(food_id);
CREATE INDEX idx_food_categories_category_id ON public.food_categories(category_id);

-- =====================================================
-- FEEDBACK TABLE (Existing)
-- =====================================================
CREATE TABLE public.feedback (
    id UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
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
    plan_name TEXT,
    user_name TEXT,
    timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_feedback_created_at ON public.feedback(created_at);
CREATE INDEX idx_feedback_user_name ON public.feedback(user_name);
CREATE INDEX idx_feedback_satisfaction_level ON public.feedback(satisfaction_level);
CREATE INDEX idx_feedback_timestamp ON public.feedback(timestamp);

-- =====================================================
-- EDGE FUNCTIONS TABLE (Existing)
-- =====================================================
CREATE TABLE public.edge_functions (
    id UUID DEFAULT gen_random_uuid() NOT NULL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    code TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- =====================================================
-- ROW LEVEL SECURITY POLICIES
-- =====================================================

-- Users table policies
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own data" ON public.users FOR SELECT USING (true);
CREATE POLICY "Users can insert own data" ON public.users FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update own data" ON public.users FOR UPDATE USING (true);

-- User foods table policies
ALTER TABLE public.user_foods ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own user foods" ON public.user_foods FOR ALL USING (true) WITH CHECK (true);

-- User food categories table policies
ALTER TABLE public.user_food_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own user food categories" ON public.user_food_categories FOR ALL USING (true) WITH CHECK (true);

-- User hidden foods table policies
ALTER TABLE public.user_hidden_foods ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own hidden foods" ON public.user_hidden_foods FOR ALL USING (true) WITH CHECK (true);

-- Nutrition plans table policies
ALTER TABLE public.nutrition_plans ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can read own plans" ON public.nutrition_plans FOR SELECT USING (true);
CREATE POLICY "Users can insert own plans" ON public.nutrition_plans FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can update own plans" ON public.nutrition_plans FOR UPDATE USING (true);
CREATE POLICY "Users can delete own plans" ON public.nutrition_plans FOR DELETE USING (true);

-- Categories table policies (public read)
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read categories" ON public.categories FOR SELECT USING (true);

-- Food preferences table policies
ALTER TABLE public.food_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all operations on food_preferences" ON public.food_preferences FOR ALL USING (true) WITH CHECK (true);

-- Foods table policies (public read)
ALTER TABLE public.foods ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read foods" ON public.foods FOR SELECT USING (true);
CREATE POLICY "Dev: anon can modify foods" ON public.foods FOR ALL TO anon USING (true) WITH CHECK (true);

-- Food categories table policies (public read)
ALTER TABLE public.food_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read food_categories" ON public.food_categories FOR SELECT USING (true);
CREATE POLICY "Dev: anon can modify food_categories" ON public.food_categories FOR ALL TO anon USING (true) WITH CHECK (true);

-- Feedback table policies
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all operations on feedback" ON public.feedback FOR ALL USING (true);

-- Edge functions table policies
ALTER TABLE public.edge_functions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read edge_functions" ON public.edge_functions FOR SELECT USING (true);
CREATE POLICY "Dev: anon can modify edge_functions" ON public.edge_functions FOR ALL TO anon USING (true) WITH CHECK (true);

-- =====================================================
-- GRANTS
-- =====================================================

-- Grant permissions to all tables for all roles
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function for food preferences update
CREATE OR REPLACE FUNCTION update_food_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;