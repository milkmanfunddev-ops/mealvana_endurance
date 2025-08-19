-- Users table for Mealvana Endurance
-- Identifies users by device_id and stores all app data
-- Run this in your Supabase SQL Editor

-- Add new columns to existing users table
-- This will safely add columns only if they don't already exist

-- Add device_id column if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'users' AND column_name = 'device_id'
    ) THEN
        ALTER TABLE users ADD COLUMN device_id TEXT UNIQUE;
    END IF;
END $$;

-- Add user profile columns if they don't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'gender') THEN
        ALTER TABLE users ADD COLUMN gender TEXT CHECK (gender IN ('male', 'female', 'other'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'birthday') THEN
        ALTER TABLE users ADD COLUMN birthday DATE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'height_feet') THEN
        ALTER TABLE users ADD COLUMN height_feet INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'height_inches') THEN
        ALTER TABLE users ADD COLUMN height_inches INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'weight_pounds') THEN
        ALTER TABLE users ADD COLUMN weight_pounds DECIMAL(5,2);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'runs_with_water_bottle') THEN
        ALTER TABLE users ADD COLUMN runs_with_water_bottle BOOLEAN DEFAULT false;
    END IF;
END $$;

-- Add food preferences column if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'food_preferences') THEN
        ALTER TABLE users ADD COLUMN food_preferences JSONB DEFAULT '{}';
    END IF;
END $$;

-- Add app preferences columns if they don't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'preferred_distance_unit') THEN
        ALTER TABLE users ADD COLUMN preferred_distance_unit TEXT DEFAULT 'miles' CHECK (preferred_distance_unit IN ('miles', 'kilometers'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'preferred_pace_unit') THEN
        ALTER TABLE users ADD COLUMN preferred_pace_unit TEXT DEFAULT 'min_per_mile' CHECK (preferred_pace_unit IN ('min_per_mile', 'min_per_km'));
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'gut_training_level') THEN
        ALTER TABLE users ADD COLUMN gut_training_level TEXT DEFAULT 'moderate' CHECK (gut_training_level IN ('low', 'moderate', 'high'));
    END IF;
END $$;

-- Add app usage data columns if they don't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'onboarding_completed') THEN
        ALTER TABLE users ADD COLUMN onboarding_completed BOOLEAN DEFAULT false;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'last_active_at') THEN
        ALTER TABLE users ADD COLUMN last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'app_version') THEN
        ALTER TABLE users ADD COLUMN app_version TEXT;
    END IF;
END $$;

-- Add updated_at column if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'updated_at') THEN
        ALTER TABLE users ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
    END IF;
END $$;

-- Create index on device_id for fast lookups
CREATE INDEX IF NOT EXISTS idx_users_device_id ON users (device_id);
CREATE INDEX IF NOT EXISTS idx_users_updated_at ON users (updated_at);

-- Create function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) policies
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and recreate them
DROP POLICY IF EXISTS "Users can read own data" ON users;
DROP POLICY IF EXISTS "Users can insert own data" ON users;
DROP POLICY IF EXISTS "Users can update own data" ON users;

-- Policy: Users can read their own data by device_id
CREATE POLICY "Users can read own data" ON users
    FOR SELECT USING (true); -- Allow all reads for now, can restrict later

-- Policy: Users can insert their own data
CREATE POLICY "Users can insert own data" ON users
    FOR INSERT WITH CHECK (true); -- Allow all inserts for now

-- Policy: Users can update their own data by device_id  
CREATE POLICY "Users can update own data" ON users
    FOR UPDATE USING (true); -- Allow all updates for now

-- Helper function to upsert user by device_id
CREATE OR REPLACE FUNCTION upsert_user_by_device_id(
    p_device_id TEXT,
    p_user_data JSONB DEFAULT '{}'
)
RETURNS users AS $$
DECLARE
    result_user users;
BEGIN
    -- Try to update first
    UPDATE users 
    SET 
        gender = COALESCE((p_user_data->>'gender')::TEXT, gender),
        birthday = COALESCE((p_user_data->>'birthday')::DATE, birthday),
        height_feet = COALESCE((p_user_data->>'height_feet')::INTEGER, height_feet),
        height_inches = COALESCE((p_user_data->>'height_inches')::INTEGER, height_inches),
        weight_pounds = COALESCE((p_user_data->>'weight_pounds')::DECIMAL, weight_pounds),
        runs_with_water_bottle = COALESCE((p_user_data->>'runs_with_water_bottle')::BOOLEAN, runs_with_water_bottle),
        food_preferences = COALESCE(p_user_data->'food_preferences', food_preferences),
        preferred_distance_unit = COALESCE((p_user_data->>'preferred_distance_unit')::TEXT, preferred_distance_unit),
        preferred_pace_unit = COALESCE((p_user_data->>'preferred_pace_unit')::TEXT, preferred_pace_unit),
        gut_training_level = COALESCE((p_user_data->>'gut_training_level')::TEXT, gut_training_level),
        onboarding_completed = COALESCE((p_user_data->>'onboarding_completed')::BOOLEAN, onboarding_completed),
        app_version = COALESCE((p_user_data->>'app_version')::TEXT, app_version),
        last_active_at = NOW(),
        updated_at = NOW()
    WHERE device_id = p_device_id
    RETURNING * INTO result_user;
    
    -- If no row was updated, insert a new one
    IF NOT FOUND THEN
        INSERT INTO users (
            device_id,
            gender,
            birthday,
            height_feet,
            height_inches,
            weight_pounds,
            runs_with_water_bottle,
            food_preferences,
            preferred_distance_unit,
            preferred_pace_unit,
            gut_training_level,
            onboarding_completed,
            app_version,
            last_active_at
        ) VALUES (
            p_device_id,
            (p_user_data->>'gender')::TEXT,
            (p_user_data->>'birthday')::DATE,
            (p_user_data->>'height_feet')::INTEGER,
            (p_user_data->>'height_inches')::INTEGER,
            (p_user_data->>'weight_pounds')::DECIMAL,
            COALESCE((p_user_data->>'runs_with_water_bottle')::BOOLEAN, false),
            COALESCE(p_user_data->'food_preferences', '{}'::JSONB),
            COALESCE((p_user_data->>'preferred_distance_unit')::TEXT, 'miles'),
            COALESCE((p_user_data->>'preferred_pace_unit')::TEXT, 'min_per_mile'),
            COALESCE((p_user_data->>'gut_training_level')::TEXT, 'moderate'),
            COALESCE((p_user_data->>'onboarding_completed')::BOOLEAN, false),
            (p_user_data->>'app_version')::TEXT,
            NOW()
        )
        RETURNING * INTO result_user;
    END IF;
    
    RETURN result_user;
END;
$$ LANGUAGE plpgsql;

-- Helper function to get user by device_id
CREATE OR REPLACE FUNCTION get_user_by_device_id(p_device_id TEXT)
RETURNS users AS $$
DECLARE
    result_user users;
BEGIN
    SELECT * INTO result_user
    FROM users 
    WHERE device_id = p_device_id;
    
    RETURN result_user;
END;
$$ LANGUAGE plpgsql;

-- Sample usage:
-- SELECT upsert_user_by_device_id('device123', '{"gender": "male", "weight_pounds": 150.5}');
-- SELECT * FROM get_user_by_device_id('device123');