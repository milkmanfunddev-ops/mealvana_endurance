-- Nutrition Plans table for Mealvana Endurance
-- Stores nutrition plans linked to users by device_id
-- Run this in your Supabase SQL Editor (after creating users table)

-- Create nutrition_plans table if it doesn't exist
CREATE TABLE IF NOT EXISTS nutrition_plans (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL,
    plan_data JSONB NOT NULL,
    distance_miles DECIMAL(5,2),
    pace_minutes_per_mile DECIMAL(5,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add new columns to existing table if they don't exist
DO $$ 
BEGIN 
    -- Add plan_id column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'nutrition_plans' AND column_name = 'plan_id'
    ) THEN
        ALTER TABLE nutrition_plans ADD COLUMN plan_id TEXT;
    END IF;
    
    -- Add plan_name column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'nutrition_plans' AND column_name = 'plan_name'
    ) THEN
        ALTER TABLE nutrition_plans ADD COLUMN plan_name TEXT;
    END IF;
    
    -- Add total_calories column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'nutrition_plans' AND column_name = 'total_calories'
    ) THEN
        ALTER TABLE nutrition_plans ADD COLUMN total_calories INTEGER;
    END IF;
    
    -- Add notes column if it doesn't exist
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'nutrition_plans' AND column_name = 'notes'
    ) THEN
        ALTER TABLE nutrition_plans ADD COLUMN notes TEXT;
    END IF;
    
    -- Add versioning columns
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'nutrition_plans' AND column_name = 'version'
    ) THEN
        ALTER TABLE nutrition_plans ADD COLUMN version INTEGER DEFAULT 1;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'nutrition_plans' AND column_name = 'last_modified_by'
    ) THEN
        ALTER TABLE nutrition_plans ADD COLUMN last_modified_by TEXT; -- device_id of the modifier
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'nutrition_plans' AND column_name = 'client_updated_at'
    ) THEN
        ALTER TABLE nutrition_plans ADD COLUMN client_updated_at TIMESTAMP WITH TIME ZONE; -- Client-side timestamp
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'nutrition_plans' AND column_name = 'is_deleted'
    ) THEN
        ALTER TABLE nutrition_plans ADD COLUMN is_deleted BOOLEAN DEFAULT FALSE;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'nutrition_plans' AND column_name = 'conflict_resolution'
    ) THEN
        ALTER TABLE nutrition_plans ADD COLUMN conflict_resolution TEXT; -- 'last_write_wins', 'manual', etc.
    END IF;
END $$;

-- Update existing rows to have plan_id if they don't have one
UPDATE nutrition_plans 
SET plan_id = 'plan-' || id::text 
WHERE plan_id IS NULL;

-- Update existing rows to have plan_name if they don't have one
UPDATE nutrition_plans 
SET plan_name = 'Nutrition Plan'
WHERE plan_name IS NULL;

-- Initialize versioning fields for existing rows
UPDATE nutrition_plans 
SET 
    version = 1,
    last_modified_by = device_id,
    client_updated_at = COALESCE(updated_at, created_at),
    is_deleted = FALSE,
    conflict_resolution = 'last_write_wins'
WHERE version IS NULL;

-- Make plan_id NOT NULL after updating existing data
ALTER TABLE nutrition_plans ALTER COLUMN plan_id SET NOT NULL;
ALTER TABLE nutrition_plans ALTER COLUMN plan_name SET NOT NULL;

-- Add unique constraint if it doesn't exist
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.table_constraints 
        WHERE table_name = 'nutrition_plans' 
        AND constraint_name = 'nutrition_plans_device_id_plan_id_key'
    ) THEN
        ALTER TABLE nutrition_plans ADD CONSTRAINT nutrition_plans_device_id_plan_id_key UNIQUE(device_id, plan_id);
    END IF;
END $$;

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_device_id ON nutrition_plans (device_id);
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_plan_id ON nutrition_plans (plan_id);
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_created_at ON nutrition_plans (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_updated_at ON nutrition_plans (updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_device_updated ON nutrition_plans (device_id, updated_at DESC);

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_nutrition_plans_updated_at ON nutrition_plans;
CREATE TRIGGER update_nutrition_plans_updated_at
    BEFORE UPDATE ON nutrition_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) policies
ALTER TABLE nutrition_plans ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and recreate them
DROP POLICY IF EXISTS "Users can read own plans" ON nutrition_plans;
DROP POLICY IF EXISTS "Users can insert own plans" ON nutrition_plans;
DROP POLICY IF EXISTS "Users can update own plans" ON nutrition_plans;
DROP POLICY IF EXISTS "Users can delete own plans" ON nutrition_plans;

-- Policy: Users can read their own plans
CREATE POLICY "Users can read own plans" ON nutrition_plans
    FOR SELECT USING (true); -- Allow all reads for now

-- Policy: Users can insert their own plans
CREATE POLICY "Users can insert own plans" ON nutrition_plans
    FOR INSERT WITH CHECK (true); -- Allow all inserts for now

-- Policy: Users can update their own plans
CREATE POLICY "Users can update own plans" ON nutrition_plans
    FOR UPDATE USING (true); -- Allow all updates for now

-- Policy: Users can delete their own plans
CREATE POLICY "Users can delete own plans" ON nutrition_plans
    FOR DELETE USING (true); -- Allow all deletes for now

-- Helper function to upsert nutrition plan with versioning and conflict resolution
CREATE OR REPLACE FUNCTION upsert_nutrition_plan_versioned(
    p_device_id TEXT,
    p_plan_id TEXT,
    p_plan_data JSONB,
    p_client_version INTEGER DEFAULT NULL,
    p_client_updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS JSONB AS $$
DECLARE
    result_plan nutrition_plans;
    current_version INTEGER;
    conflict_detected BOOLEAN := FALSE;
    operation_type TEXT;
    user_exists BOOLEAN := FALSE;
BEGIN
    -- First, ensure the user exists - create a minimal user record if not
    SELECT EXISTS(SELECT 1 FROM users WHERE device_id = p_device_id) INTO user_exists;
    
    IF NOT user_exists THEN
        -- Create a minimal user record for the device_id
        INSERT INTO users (
            device_id,
            gender,
            birthday,
            height_feet,
            height_inches,
            weight_pounds,
            runs_with_water_bottle,
            gut_training_level,
            onboarding_completed,
            app_version
        ) VALUES (
            p_device_id,
            'other',                    -- Default gender
            '1990-01-01',              -- Default birthday
            5,                         -- Default height feet
            8,                         -- Default height inches  
            150.0,                     -- Default weight
            false,                     -- Default water bottle preference
            'moderate',                -- Default gut training
            false,                     -- Not onboarded (minimal record)
            '1.0.0'                    -- App version
        )
        ON CONFLICT (device_id) DO NOTHING; -- Skip if user was created by another process
    END IF;

    -- Check if plan exists and get current version
    SELECT version INTO current_version
    FROM nutrition_plans 
    WHERE device_id = p_device_id AND plan_id = p_plan_id AND is_deleted = FALSE;
    
    -- Detect conflicts
    IF current_version IS NOT NULL AND p_client_version IS NOT NULL THEN
        IF p_client_version < current_version THEN
            conflict_detected := TRUE;
        END IF;
    END IF;
    
    -- Handle conflict detection
    IF conflict_detected THEN
        -- Return conflict information instead of updating
        SELECT * INTO result_plan
        FROM nutrition_plans 
        WHERE device_id = p_device_id AND plan_id = p_plan_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'conflict', true,
            'current_version', current_version,
            'client_version', p_client_version,
            'server_plan', row_to_json(result_plan),
            'message', 'Version conflict detected. Server has newer version.'
        );
    END IF;
    
    -- Determine operation type
    operation_type := CASE WHEN current_version IS NULL THEN 'insert' ELSE 'update' END;
    
    -- Perform upsert with version increment
    INSERT INTO nutrition_plans (
        device_id,
        plan_id,
        plan_name,
        plan_data,
        total_calories,
        notes,
        distance_miles,
        pace_minutes_per_mile,
        version,
        last_modified_by,
        client_updated_at,
        is_deleted,
        conflict_resolution
    ) VALUES (
        p_device_id,
        p_plan_id,
        COALESCE((p_plan_data->>'plan_name')::TEXT, 'Nutrition Plan'),
        p_plan_data->'plan_data',
        (p_plan_data->>'total_calories')::INTEGER,
        (p_plan_data->>'notes')::TEXT,
        (p_plan_data->>'distance_miles')::DECIMAL,
        (p_plan_data->>'pace_minutes_per_mile')::DECIMAL,
        1, -- Initial version
        p_device_id,
        p_client_updated_at,
        FALSE,
        'last_write_wins'
    )
    ON CONFLICT (device_id, plan_id) 
    DO UPDATE SET
        plan_name = COALESCE((p_plan_data->>'plan_name')::TEXT, nutrition_plans.plan_name),
        plan_data = p_plan_data->'plan_data',
        total_calories = (p_plan_data->>'total_calories')::INTEGER,
        notes = (p_plan_data->>'notes')::TEXT,
        distance_miles = (p_plan_data->>'distance_miles')::DECIMAL,
        pace_minutes_per_mile = (p_plan_data->>'pace_minutes_per_mile')::DECIMAL,
        version = nutrition_plans.version + 1, -- Increment version
        last_modified_by = p_device_id,
        client_updated_at = p_client_updated_at,
        updated_at = NOW(),
        is_deleted = FALSE
    RETURNING * INTO result_plan;
    
    -- Return success response
    RETURN jsonb_build_object(
        'success', true,
        'conflict', false,
        'operation', operation_type,
        'plan', row_to_json(result_plan),
        'new_version', result_plan.version
    );
END;
$$ LANGUAGE plpgsql;

-- Legacy function for backward compatibility
CREATE OR REPLACE FUNCTION upsert_nutrition_plan(
    p_device_id TEXT,
    p_plan_id TEXT,
    p_plan_data JSONB
)
RETURNS nutrition_plans AS $$
DECLARE
    result JSONB;
    result_plan nutrition_plans;
BEGIN
    -- Call versioned function with default parameters
    result := upsert_nutrition_plan_versioned(p_device_id, p_plan_id, p_plan_data);
    
    -- Extract plan from result
    IF (result->>'success')::BOOLEAN THEN
        SELECT * INTO result_plan FROM jsonb_populate_record(null::nutrition_plans, result->'plan');
    ELSE
        -- In case of conflict, return current server version
        SELECT * INTO result_plan FROM jsonb_populate_record(null::nutrition_plans, result->'server_plan');
    END IF;
    
    RETURN result_plan;
END;
$$ LANGUAGE plpgsql;

-- Helper function to get nutrition plans by device_id (exclude deleted)
CREATE OR REPLACE FUNCTION get_nutrition_plans_by_device_id(p_device_id TEXT)
RETURNS SETOF nutrition_plans AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM nutrition_plans 
    WHERE device_id = p_device_id AND is_deleted = FALSE
    ORDER BY updated_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Helper function to get latest nutrition plan by device_id (exclude deleted)
CREATE OR REPLACE FUNCTION get_latest_nutrition_plan_by_device_id(p_device_id TEXT)
RETURNS nutrition_plans AS $$
DECLARE
    result_plan nutrition_plans;
BEGIN
    SELECT * INTO result_plan
    FROM nutrition_plans 
    WHERE device_id = p_device_id AND is_deleted = FALSE
    ORDER BY updated_at DESC
    LIMIT 1;
    
    RETURN result_plan;
END;
$$ LANGUAGE plpgsql;

-- Helper function to soft delete nutrition plan with versioning
CREATE OR REPLACE FUNCTION delete_nutrition_plan_versioned(
    p_device_id TEXT,
    p_plan_id TEXT,
    p_client_version INTEGER DEFAULT NULL
)
RETURNS JSONB AS $$
DECLARE
    result_plan nutrition_plans;
    current_version INTEGER;
    conflict_detected BOOLEAN := FALSE;
BEGIN
    -- Check if plan exists and get current version
    SELECT version INTO current_version
    FROM nutrition_plans 
    WHERE device_id = p_device_id AND plan_id = p_plan_id AND is_deleted = FALSE;
    
    -- Check if plan exists
    IF current_version IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'conflict', false,
            'message', 'Plan not found or already deleted.'
        );
    END IF;
    
    -- Detect conflicts
    IF p_client_version IS NOT NULL AND p_client_version < current_version THEN
        conflict_detected := TRUE;
    END IF;
    
    -- Handle conflict
    IF conflict_detected THEN
        SELECT * INTO result_plan
        FROM nutrition_plans 
        WHERE device_id = p_device_id AND plan_id = p_plan_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'conflict', true,
            'current_version', current_version,
            'client_version', p_client_version,
            'server_plan', row_to_json(result_plan),
            'message', 'Version conflict detected. Server has newer version.'
        );
    END IF;
    
    -- Perform soft delete with version increment
    UPDATE nutrition_plans 
    SET 
        is_deleted = TRUE,
        version = version + 1,
        last_modified_by = p_device_id,
        client_updated_at = NOW(),
        updated_at = NOW()
    WHERE device_id = p_device_id AND plan_id = p_plan_id
    RETURNING * INTO result_plan;
    
    RETURN jsonb_build_object(
        'success', true,
        'conflict', false,
        'operation', 'delete',
        'plan', row_to_json(result_plan),
        'new_version', result_plan.version
    );
END;
$$ LANGUAGE plpgsql;

-- Legacy function for backward compatibility
CREATE OR REPLACE FUNCTION delete_nutrition_plan_by_device_plan_id(
    p_device_id TEXT,
    p_plan_id TEXT
)
RETURNS BOOLEAN AS $$
DECLARE
    result JSONB;
BEGIN
    result := delete_nutrition_plan_versioned(p_device_id, p_plan_id);
    RETURN (result->>'success')::BOOLEAN;
END;
$$ LANGUAGE plpgsql;

-- Sample usage:
-- SELECT upsert_nutrition_plan('device123', 'plan456', '{"plan_name": "Marathon Plan", "total_calories": 2500, "notes": "Long run nutrition"}');
-- SELECT * FROM get_nutrition_plans_by_device_id('device123');
-- SELECT * FROM get_latest_nutrition_plan_by_device_id('device123');
-- SELECT delete_nutrition_plan_by_device_plan_id('device123', 'plan456');