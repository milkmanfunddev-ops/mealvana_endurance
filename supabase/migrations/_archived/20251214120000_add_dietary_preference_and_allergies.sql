-- Migration: Add dietary preference and allergies support for onboarding revamp
-- Date: 2024-12-14
-- Description: Adds dietary_preference_enum, allergy_enum, and related columns to users and foods tables

-- ============================================================================
-- STEP 1: Create enum types
-- ============================================================================

-- Create dietary_preference_enum type (single-select for users)
CREATE TYPE dietary_preference_enum AS ENUM (
  'omnivore',
  'vegetarian',
  'pescatarian',
  'vegan',
  'mediterranean',
  'paleo',
  'keto',
  'low_carb'
);

COMMENT ON TYPE dietary_preference_enum IS 'User dietary preference options for food filtering';

-- Create allergy_enum type (used in arrays for multi-select)
CREATE TYPE allergy_enum AS ENUM (
  'dairy',
  'eggs',
  'fish',
  'gluten',
  'peanuts',
  'sesame',
  'shellfish',
  'soy',
  'tree_nuts'
);

COMMENT ON TYPE allergy_enum IS 'Common food allergens for user allergy tracking';

-- ============================================================================
-- STEP 2: Add columns to users table
-- ============================================================================

-- Add dietary_preference column (single value, nullable for existing users)
ALTER TABLE users
ADD COLUMN dietary_preference dietary_preference_enum;

COMMENT ON COLUMN users.dietary_preference IS 'User dietary preference: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb. NULL means no preference set.';

-- Add allergies column (array of allergens, empty array by default)
ALTER TABLE users
ADD COLUMN allergies allergy_enum[] DEFAULT '{}';

COMMENT ON COLUMN users.allergies IS 'Array of user allergies for food filtering. Empty array means no allergies.';

-- ============================================================================
-- STEP 3: Add columns to foods table
-- ============================================================================

-- Add allergens column (array of allergens contained in this food)
ALTER TABLE foods
ADD COLUMN allergens allergy_enum[] DEFAULT '{}';

COMMENT ON COLUMN foods.allergens IS 'Allergens contained in this food (e.g., dairy, gluten, peanuts). Used for filtering foods based on user allergies.';

-- Add excluded_diets column (array of diets that should exclude this food)
ALTER TABLE foods
ADD COLUMN excluded_diets dietary_preference_enum[] DEFAULT '{}';

COMMENT ON COLUMN foods.excluded_diets IS 'Diets that should exclude this food (e.g., vegan excludes meat/dairy). Used for filtering foods based on user dietary preference.';

-- ============================================================================
-- STEP 4: Create indexes for efficient filtering
-- ============================================================================

-- Index for filtering foods by allergens (GIN index for array containment queries)
CREATE INDEX idx_foods_allergens_gin ON foods USING gin (allergens);

-- Index for filtering foods by excluded diets (GIN index for array containment queries)
CREATE INDEX idx_foods_excluded_diets_gin ON foods USING gin (excluded_diets);

-- Index for filtering users by dietary preference
CREATE INDEX idx_users_dietary_preference ON users (dietary_preference) WHERE dietary_preference IS NOT NULL;

-- ============================================================================
-- STEP 5: Grant permissions
-- ============================================================================

-- Grant permissions on new columns (inherited from table grants, but explicit for clarity)
-- No additional grants needed as users and foods tables already have appropriate permissions

-- ============================================================================
-- Migration complete
-- ============================================================================
