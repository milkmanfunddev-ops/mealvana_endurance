-- Food Preferences table for Mealvana Endurance
-- Stores user food preferences linked by device_id
-- Run this in your Supabase SQL Editor (after creating users and foods tables)

-- Create food_preferences table
CREATE TABLE IF NOT EXISTS food_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL REFERENCES users(device_id) ON DELETE CASCADE,
    food_name TEXT NOT NULL,
    preference TEXT NOT NULL CHECK (preference IN ('like', 'dislike', 'willing_to_try')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create unique constraint to prevent duplicate preferences for same user/food
CREATE UNIQUE INDEX IF NOT EXISTS idx_food_preferences_device_food 
ON food_preferences (device_id, food_name);

-- Create indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_food_preferences_device_id ON food_preferences (device_id);
CREATE INDEX IF NOT EXISTS idx_food_preferences_preference ON food_preferences (preference);

-- Create trigger to automatically update updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS update_food_preferences_updated_at ON food_preferences;
CREATE TRIGGER update_food_preferences_updated_at
    BEFORE UPDATE ON food_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Row Level Security (RLS) policies
ALTER TABLE food_preferences ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist and recreate them
DROP POLICY IF EXISTS "Users can read own food preferences" ON food_preferences;
DROP POLICY IF EXISTS "Users can insert own food preferences" ON food_preferences;
DROP POLICY IF EXISTS "Users can update own food preferences" ON food_preferences;
DROP POLICY IF EXISTS "Users can delete own food preferences" ON food_preferences;

-- Policy: Users can read their own food preferences
CREATE POLICY "Users can read own food preferences" ON food_preferences
    FOR SELECT USING (true); -- Allow all reads for now (Edge Functions need access)

-- Policy: Users can insert their own food preferences
CREATE POLICY "Users can insert own food preferences" ON food_preferences
    FOR INSERT WITH CHECK (true); -- Allow all inserts for now

-- Policy: Users can update their own food preferences
CREATE POLICY "Users can update own food preferences" ON food_preferences
    FOR UPDATE USING (true); -- Allow all updates for now

-- Policy: Users can delete their own food preferences
CREATE POLICY "Users can delete own food preferences" ON food_preferences
    FOR DELETE USING (true); -- Allow all deletes for now

-- Helper function to upsert food preferences
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
END;
$$ LANGUAGE plpgsql;

-- Sample usage:
-- SELECT upsert_food_preferences('device123', '{"Oatmeal": "like", "Banana sliced": "dislike", "Gels": "willing_to_try"}'::jsonb);
-- SELECT * FROM food_preferences WHERE device_id = 'device123';