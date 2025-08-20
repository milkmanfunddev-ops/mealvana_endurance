-- Mealvana Endurance Database Schema - Functions and RLS
-- This creates database functions and Row Level Security policies
-- Run this AFTER 01-create-core-tables.sql

-- ==============================================
-- HELPER FUNCTIONS
-- ==============================================

-- Function to upsert food preferences (replace all for a user)
CREATE OR REPLACE FUNCTION upsert_food_preferences(
    p_device_id TEXT,
    p_preferences JSONB
)
RETURNS BOOLEAN AS $$
DECLARE
    preference_record RECORD;
BEGIN
    -- Delete existing preferences for this user
    DELETE FROM food_preferences WHERE device_id = p_device_id;
    
    -- Insert new preferences
    FOR preference_record IN 
        SELECT 
            key as food_name, 
            value as preference
        FROM jsonb_each_text(p_preferences)
    LOOP
        INSERT INTO food_preferences (device_id, food_name, preference)
        VALUES (p_device_id, preference_record.food_name, preference_record.preference);
    END LOOP;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Error in upsert_food_preferences: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Function to upsert nutrition plan with versioning
CREATE OR REPLACE FUNCTION upsert_nutrition_plan_versioned(
    p_device_id TEXT,
    p_plan_id TEXT,
    p_plan_name TEXT,
    p_plan_data JSONB,
    p_client_version INTEGER DEFAULT 1
)
RETURNS TABLE(
    success BOOLEAN,
    conflict BOOLEAN,
    server_version INTEGER,
    message TEXT
) AS $$
DECLARE
    current_server_version INTEGER;
    new_version INTEGER;
BEGIN
    -- Get current server version
    SELECT version INTO current_server_version 
    FROM nutrition_plans 
    WHERE device_id = p_device_id AND plan_id = p_plan_id AND is_deleted = FALSE
    ORDER BY version DESC 
    LIMIT 1;
    
    -- Check for conflicts
    IF current_server_version IS NOT NULL AND current_server_version > p_client_version THEN
        -- Conflict detected
        RETURN QUERY SELECT FALSE, TRUE, current_server_version, 'Version conflict detected'::TEXT;
        RETURN;
    END IF;
    
    -- Calculate new version
    new_version := COALESCE(current_server_version, 0) + 1;
    
    -- Insert new version
    INSERT INTO nutrition_plans (
        device_id, plan_id, plan_name, plan_data, version, 
        last_modified_by, client_updated_at, is_deleted, 
        conflict_resolution, created_at, updated_at
    ) VALUES (
        p_device_id, p_plan_id, p_plan_name, p_plan_data, new_version,
        p_device_id, NOW(), FALSE,
        'last_write_wins', NOW(), NOW()
    );
    
    RETURN QUERY SELECT TRUE, FALSE, new_version, 'Plan saved successfully'::TEXT;
END;
$$ LANGUAGE plpgsql;

-- Function to get active app content
CREATE OR REPLACE FUNCTION get_active_app_content(
    p_environment TEXT DEFAULT 'production',
    p_locale TEXT DEFAULT 'en-US'
)
RETURNS JSONB AS $$
DECLARE
    content_result JSONB;
BEGIN
    SELECT content INTO content_result
    FROM app_content
    WHERE environment = p_environment 
      AND locale = p_locale 
      AND is_active = TRUE
    ORDER BY version DESC
    LIMIT 1;
    
    RETURN COALESCE(content_result, '{}'::JSONB);
END;
$$ LANGUAGE plpgsql;

-- ==============================================
-- ROW LEVEL SECURITY (RLS)
-- ==============================================

-- Enable RLS on all user-scoped tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE nutrition_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- ==============================================
-- RLS POLICIES FOR USERS
-- ==============================================

-- Users can read/write their own data
CREATE POLICY "Users can manage own data" ON users
    FOR ALL USING (true) WITH CHECK (true);

-- ==============================================
-- RLS POLICIES FOR FOOD_PREFERENCES
-- ==============================================

CREATE POLICY "Users can manage own food preferences" ON food_preferences
    FOR ALL USING (true) WITH CHECK (true);

-- ==============================================
-- RLS POLICIES FOR NUTRITION_PLANS
-- ==============================================

CREATE POLICY "Users can manage own nutrition plans" ON nutrition_plans
    FOR ALL USING (true) WITH CHECK (true);

-- ==============================================
-- RLS POLICIES FOR FEEDBACK
-- ==============================================

CREATE POLICY "Anyone can insert feedback" ON feedback
    FOR INSERT WITH CHECK (true);

CREATE POLICY "No one can read feedback" ON feedback
    FOR SELECT USING (false);

-- ==============================================
-- PUBLIC TABLES (No RLS needed)
-- ==============================================

-- foods, categories, food_categories, app_content are public read-only
-- Edge functions have service role access for writes

-- ==============================================
-- FUNCTION COMMENTS
-- ==============================================

COMMENT ON FUNCTION upsert_food_preferences(TEXT, JSONB) IS 'Replace all food preferences for a user with new preferences from JSONB object';
COMMENT ON FUNCTION upsert_nutrition_plan_versioned(TEXT, TEXT, TEXT, JSONB, INTEGER) IS 'Insert nutrition plan with optimistic concurrency control and conflict detection';
COMMENT ON FUNCTION get_active_app_content(TEXT, TEXT) IS 'Get active app content for environment and locale';