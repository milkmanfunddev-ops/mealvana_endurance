-- Mealvana Endurance Database Schema - Core Tables
-- This creates all the core tables for the application
-- Run this in Supabase SQL Editor

-- ==============================================
-- USERS TABLE
-- ==============================================
CREATE TABLE IF NOT EXISTS users (
    device_id TEXT PRIMARY KEY,
    gender TEXT NOT NULL CHECK (gender IN ('male', 'female', 'other')),
    birthday DATE NOT NULL,
    height_feet INTEGER NOT NULL CHECK (height_feet BETWEEN 3 AND 8),
    height_inches INTEGER NOT NULL CHECK (height_inches BETWEEN 0 AND 11),
    weight_pounds NUMERIC NOT NULL CHECK (weight_pounds > 0),
    runs_with_water_bottle BOOLEAN DEFAULT false,
    gut_training_level TEXT DEFAULT 'moderate' CHECK (gut_training_level IN ('low', 'moderate', 'high')),
    onboarding_completed BOOLEAN DEFAULT false,
    app_version TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================
-- CATEGORIES TABLE (for food categorization)
-- ==============================================
CREATE TABLE IF NOT EXISTS categories (
    id INTEGER NOT NULL PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
);

-- Insert default categories
INSERT INTO categories (id, name) VALUES 
    (1, 'before_run'),
    (2, 'during_run'),
    (3, 'after_run')
ON CONFLICT (id) DO NOTHING;

-- ==============================================
-- FOODS TABLE (with structured serving data)
-- ==============================================
CREATE TABLE IF NOT EXISTS foods (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    instructions TEXT,
    nutritional_info JSONB DEFAULT '{}',
    serving_amount NUMERIC DEFAULT 1,
    serving_unit TEXT DEFAULT 'serving',
    serving_unit_plural TEXT,
    serving_qualifier TEXT,
    image_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================
-- FOOD_CATEGORIES TABLE (many-to-many join)
-- ==============================================
CREATE TABLE IF NOT EXISTS food_categories (
    food_id UUID NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
    category_id INTEGER NOT NULL REFERENCES categories(id),
    PRIMARY KEY (food_id, category_id)
);

-- ==============================================
-- FOOD_PREFERENCES TABLE
-- ==============================================
CREATE TABLE IF NOT EXISTS food_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,
    food_name TEXT NOT NULL,
    preference TEXT NOT NULL CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================
-- NUTRITION_PLANS TABLE
-- ==============================================
CREATE TABLE IF NOT EXISTS nutrition_plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,
    plan_id TEXT NOT NULL,
    plan_name TEXT NOT NULL,
    plan_data JSONB NOT NULL,
    total_calories INTEGER,
    distance_miles NUMERIC,
    pace_minutes_per_mile NUMERIC,
    notes TEXT,
    version INTEGER DEFAULT 1,
    last_modified_by TEXT,
    client_updated_at TIMESTAMPTZ,
    is_deleted BOOLEAN DEFAULT FALSE,
    conflict_resolution TEXT DEFAULT 'last_write_wins',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================
-- FEEDBACK TABLE
-- ==============================================
CREATE TABLE IF NOT EXISTS feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    satisfaction_level INTEGER CHECK (satisfaction_level BETWEEN 1 AND 3),
    satisfaction_emoji TEXT NOT NULL,
    satisfaction_label TEXT NOT NULL,
    app_feedback TEXT,
    suggestions TEXT,
    plan_name TEXT,
    user_name TEXT,
    timestamp TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================
-- APP_CONTENT TABLE
-- ==============================================
CREATE TABLE IF NOT EXISTS app_content (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    environment TEXT NOT NULL CHECK (environment IN ('development', 'staging', 'production')),
    locale TEXT NOT NULL DEFAULT 'en-US',
    content JSONB NOT NULL DEFAULT '{}',
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================
-- INDEXES
-- ==============================================

-- Users indexes
CREATE INDEX IF NOT EXISTS idx_users_onboarding ON users (onboarding_completed);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users (created_at);

-- Foods indexes
CREATE INDEX IF NOT EXISTS idx_foods_name ON foods (name);
CREATE INDEX IF NOT EXISTS idx_foods_created_at ON foods (created_at);

-- Food categories indexes
CREATE INDEX IF NOT EXISTS idx_food_categories_food_id ON food_categories (food_id);
CREATE INDEX IF NOT EXISTS idx_food_categories_category_id ON food_categories (category_id);

-- Food preferences indexes
CREATE UNIQUE INDEX IF NOT EXISTS idx_food_preferences_device_food ON food_preferences (device_id, food_name);
CREATE INDEX IF NOT EXISTS idx_food_preferences_device_id ON food_preferences (device_id);
CREATE INDEX IF NOT EXISTS idx_food_preferences_preference ON food_preferences (preference);

-- Nutrition plans indexes
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_device_id ON nutrition_plans (device_id);
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_plan_id ON nutrition_plans (plan_id);
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_created_at ON nutrition_plans (created_at);
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_active ON nutrition_plans (device_id, is_deleted, updated_at);

-- Feedback indexes
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON feedback (created_at);
CREATE INDEX IF NOT EXISTS idx_feedback_satisfaction ON feedback (satisfaction_level);

-- App content indexes
CREATE INDEX IF NOT EXISTS idx_app_content_env_locale ON app_content (environment, locale);
CREATE INDEX IF NOT EXISTS idx_app_content_active ON app_content (is_active, version);

-- ==============================================
-- TRIGGERS FOR AUTO-UPDATING TIMESTAMPS
-- ==============================================

-- Function to update updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to all relevant tables
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_foods_updated_at ON foods;
CREATE TRIGGER update_foods_updated_at BEFORE UPDATE ON foods FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_food_preferences_updated_at ON food_preferences;
CREATE TRIGGER update_food_preferences_updated_at BEFORE UPDATE ON food_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_nutrition_plans_updated_at ON nutrition_plans;
CREATE TRIGGER update_nutrition_plans_updated_at BEFORE UPDATE ON nutrition_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_app_content_updated_at ON app_content;
CREATE TRIGGER update_app_content_updated_at BEFORE UPDATE ON app_content FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE users IS 'User profiles and biometric data - device-based authentication';
COMMENT ON TABLE categories IS 'Food timing categories (before_run, during_run, after_run)';
COMMENT ON TABLE foods IS 'Food database with structured serving information';
COMMENT ON TABLE food_categories IS 'Many-to-many relationship between foods and categories';
COMMENT ON TABLE food_preferences IS 'User food preferences (like, dislike, willing_to_try)';
COMMENT ON TABLE nutrition_plans IS 'Generated nutrition plans with versioning and conflict resolution';
COMMENT ON TABLE feedback IS 'User satisfaction feedback (1-3 scale)';
COMMENT ON TABLE app_content IS 'Dynamic app content for localization and A/B testing';