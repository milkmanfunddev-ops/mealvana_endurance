-- Migration: Add specific snack meal types
-- This migration adds three new meal types to differentiate between morning, afternoon, and evening snacks
-- NON-BREAKING: Existing meal_type_id = 4 (snacks) records remain valid

-- Add three new meal types for snacks
INSERT INTO meal_types (id, name, display_name) VALUES
  (5, 'morning_snack', 'Morning Snack'),
  (6, 'afternoon_snack', 'Afternoon Snack'),
  (7, 'evening_snack', 'Evening Snack')
ON CONFLICT (id) DO NOTHING;

-- Update comments to reflect the new meal types
COMMENT ON TABLE meal_types IS 'Meal categories for carb loading feature (breakfast, morning_snack, lunch, afternoon_snack, dinner, evening_snack)';
COMMENT ON COLUMN meal_types.id IS 'Primary key (1=breakfast, 2=lunch, 3=dinner, 4=snacks [deprecated], 5=morning_snack, 6=afternoon_snack, 7=evening_snack)';
