-- Foods reference table for Mealvana Endurance
-- Static data for our 12 food items
-- Run this in your Supabase SQL Editor

-- Create foods table
CREATE TABLE IF NOT EXISTS foods (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    name TEXT NOT NULL,
    category TEXT NOT NULL CHECK (category IN ('before_run', 'during_run', 'after_run')),
    icon_path TEXT,
    description TEXT,
    instructions TEXT,
    nutritional_info JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for category lookups
CREATE INDEX IF NOT EXISTS idx_foods_category ON foods (category);

-- Insert our 12 static foods
INSERT INTO foods (name, category, icon_path, description, instructions, nutritional_info) VALUES

-- Before Run Foods
('Oatmeal', 'before_run', 'assets/images/oatmeal.png', 
 'Carb up, buttercup: gentle complex carbs = smooth 2–3-hour energy. Hit ''em 30–60 min pre-run.', 
 'Eat 2-3 hours before your run',
 '{"carbs_per_serving": 30, "protein_per_serving": 5, "fat_per_serving": 3, "serving_size": "1 cup cooked"}'::jsonb),

('Banana sliced', 'before_run', 'assets/images/banana.png',
 'Quick-digesting sugars and potassium for energy.',
 'Eat 30-60 minutes before your run',
 '{"carbs_per_serving": 27, "protein_per_serving": 1, "fat_per_serving": 0, "serving_size": "1 medium banana"}'::jsonb),

('Coffee', 'before_run', 'assets/images/coffee.png',
 'Caffeine boost for performance.',
 'Drink 30-60 minutes before your run',
 '{"carbs_per_serving": 0, "protein_per_serving": 0, "fat_per_serving": 0, "caffeine_mg": 95, "serving_size": "1 cup"}'::jsonb),

('Orange juice', 'before_run', 'assets/images/orange_juice.png',
 'Quick carbohydrates and vitamin C.',
 'Drink 30-60 minutes before your run',
 '{"carbs_per_serving": 26, "protein_per_serving": 2, "fat_per_serving": 0, "serving_size": "1 cup"}'::jsonb),

-- During Run Foods
('Gels', 'during_run', 'assets/images/gels.png',
 'Fast-absorbing energy for sustained performance.',
 'Take with water every 45-60 minutes.',
 '{"carbs_per_serving": 22, "protein_per_serving": 0, "fat_per_serving": 0, "sodium_mg": 50, "serving_size": "1 gel packet"}'::jsonb),

('Sport drinks', 'during_run', 'assets/images/sports_drink.png',
 'Hydration with electrolytes and carbohydrates.',
 'Sip regularly throughout your run.',
 '{"carbs_per_serving": 14, "protein_per_serving": 0, "fat_per_serving": 0, "sodium_mg": 110, "serving_size": "8 oz"}'::jsonb),

('Dates', 'during_run', 'assets/images/dates.png',
 'Natural sugars for quick energy.',
 'Eat 1-2 dates every 45-60 minutes during long runs.',
 '{"carbs_per_serving": 18, "protein_per_serving": 0, "fat_per_serving": 0, "serving_size": "2 dates"}'::jsonb),

('Energy chews', 'during_run', 'assets/images/energy_chews.png',
 'Convenient carbohydrate source for endurance.',
 'Chew thoroughly and follow with water.',
 '{"carbs_per_serving": 16, "protein_per_serving": 0, "fat_per_serving": 0, "sodium_mg": 70, "serving_size": "4 chews"}'::jsonb),

-- After Run Foods
('Protein bar', 'after_run', 'assets/images/protein_bar.png',
 'Protein and carbs for recovery.',
 'Eat within 30 minutes of finishing your run.',
 '{"carbs_per_serving": 25, "protein_per_serving": 20, "fat_per_serving": 8, "serving_size": "1 bar"}'::jsonb),

('Coconut water', 'after_run', 'assets/images/coconut_water.png',
 'Natural electrolytes for rehydration.',
 'Drink within 30 minutes of finishing your run.',
 '{"carbs_per_serving": 9, "protein_per_serving": 2, "fat_per_serving": 0, "potassium_mg": 600, "serving_size": "8 oz"}'::jsonb),

('Chocolate milk', 'after_run', 'assets/images/chocolate_milk.png',
 'Ideal 3:1 carb to protein ratio for recovery.',
 'Drink within 30 minutes of finishing your run.',
 '{"carbs_per_serving": 26, "protein_per_serving": 8, "fat_per_serving": 8, "serving_size": "8 oz"}'::jsonb),

('Greek yogurt with berries', 'after_run', 'assets/images/greek_yogurt.png',
 'High protein with antioxidants for muscle recovery.',
 'Eat within 1 hour of finishing your run.',
 '{"carbs_per_serving": 20, "protein_per_serving": 15, "fat_per_serving": 0, "serving_size": "1 cup yogurt + 1/2 cup berries"}'::jsonb);

-- Make table read-only for reference data
ALTER TABLE foods ENABLE ROW LEVEL SECURITY;

-- Policy: Everyone can read foods (reference data)
CREATE POLICY "Anyone can read foods" ON foods
    FOR SELECT USING (true);

-- Only admins can modify foods (restrict INSERT/UPDATE/DELETE)
CREATE POLICY "Only admins can modify foods" ON foods
    FOR ALL USING (false);