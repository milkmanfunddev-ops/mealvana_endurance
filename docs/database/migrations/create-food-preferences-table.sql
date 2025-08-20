-- Food Preferences Table Migration
-- Create the food_preferences table to store user food preferences
-- Run this in your Supabase SQL Editor

-- Create food_preferences table
CREATE TABLE IF NOT EXISTS food_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,
    food_name TEXT NOT NULL,
    preference TEXT NOT NULL CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create unique constraint to prevent duplicate preferences for same user/food
CREATE UNIQUE INDEX IF NOT EXISTS idx_food_preferences_device_food 
ON food_preferences (device_id, food_name);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_food_preferences_device_id ON food_preferences (device_id);
CREATE INDEX IF NOT EXISTS idx_food_preferences_preference ON food_preferences (preference);

-- Create trigger function for auto-updating updated_at
CREATE OR REPLACE FUNCTION update_food_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_food_preferences_updated_at ON food_preferences;
CREATE TRIGGER update_food_preferences_updated_at
    BEFORE UPDATE ON food_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_food_preferences_updated_at();

-- Enable Row Level Security (RLS)
ALTER TABLE food_preferences ENABLE ROW LEVEL SECURITY;

-- Create RLS policies (permissive for now, can be tightened later)
CREATE POLICY "Allow all operations on food_preferences" ON food_preferences
    FOR ALL USING (true) WITH CHECK (true);

-- Helper function to upsert food preferences (replace all user preferences)
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
        -- Log error and return false
        RAISE NOTICE 'Error in upsert_food_preferences: %', SQLERRM;
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Sample data for testing (remove after testing)
-- INSERT INTO food_preferences (device_id, food_name, preference) VALUES
--     ('test_device_1', 'Oatmeal', 'like'),
--     ('test_device_1', 'Banana sliced', 'like'),
--     ('test_device_1', 'Gels', 'willing_to_try'),
--     ('test_device_1', 'Coffee', 'dislike');

-- Test the upsert function (remove after testing)
-- SELECT upsert_food_preferences('test_device_2', '{"Oatmeal": "like", "Banana sliced": "willing_to_try", "Orange juice": "dislike"}'::jsonb);

-- Query to check the table was created successfully
-- SELECT * FROM food_preferences LIMIT 5;

COMMENT ON TABLE food_preferences IS 'Stores user food preferences (like, dislike, willing_to_try) linked by device_id';
COMMENT ON COLUMN food_preferences.device_id IS 'References users.device_id - user who owns this preference';
COMMENT ON COLUMN food_preferences.food_name IS 'Name of the food item (should match foods.name)';
COMMENT ON COLUMN food_preferences.preference IS 'User preference: like, dislike, or willing_to_try';
COMMENT ON FUNCTION upsert_food_preferences(TEXT, JSONB) IS 'Replace all food preferences for a user with new preferences from JSONB object';