-- Migration: Add Carb Loading Food Tables to v1 Schema
-- Description: Adds 6 new tables for carb loading food management
-- Tables: meal_types, carb_loading_foods, carb_loading_user_foods,
--         carb_loading_food_meal_types, carb_loading_user_food_meal_types,
--         carb_loading_day_meals
-- Date: 2025-10-08
-- Schema Version: v1 (no migration - adding to existing v1)

-- ============================================================================
-- Table 1: meal_types
-- Purpose: Meal categories for carb loading (breakfast, lunch, dinner, snacks)
-- Note: Separate from categories table which is for nutrition plan timing
-- ============================================================================

CREATE TABLE IF NOT EXISTS meal_types (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL
);

COMMENT ON TABLE meal_types IS 'Meal categories for carb loading feature (breakfast, lunch, dinner, snacks)';
COMMENT ON COLUMN meal_types.id IS 'Primary key (1=breakfast, 2=lunch, 3=dinner, 4=snacks)';
COMMENT ON COLUMN meal_types.name IS 'Internal name (lowercase, underscore-separated)';
COMMENT ON COLUMN meal_types.display_name IS 'Display name for UI (title case)';

-- Seed meal types data
INSERT INTO meal_types (id, name, display_name) VALUES
  (1, 'breakfast', 'Breakfast'),
  (2, 'lunch', 'Lunch'),
  (3, 'dinner', 'Dinner'),
  (4, 'snacks', 'Snacks')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- Table 2: carb_loading_foods
-- Purpose: Global default carb loading foods available to all users
-- ============================================================================

CREATE TABLE IF NOT EXISTS carb_loading_foods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  display_name_plural TEXT,
  carbs_per_serving REAL NOT NULL,
  image_address TEXT,
  is_default BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT carbs_positive CHECK (carbs_per_serving > 0)
);

COMMENT ON TABLE carb_loading_foods IS 'Global default carb loading foods (cereal, pasta, etc.) - pre-seeded';
COMMENT ON COLUMN carb_loading_foods.id IS 'UUID primary key';
COMMENT ON COLUMN carb_loading_foods.name IS 'Internal name (lowercase, underscore-separated)';
COMMENT ON COLUMN carb_loading_foods.display_name IS 'Display name with serving size (e.g., "Cereal (1/2 cup dry)")';
COMMENT ON COLUMN carb_loading_foods.carbs_per_serving IS 'Carbohydrates in grams per serving';
COMMENT ON COLUMN carb_loading_foods.is_default IS 'True for pre-seeded foods, false for admin-added';

CREATE INDEX IF NOT EXISTS idx_carb_loading_foods_name ON carb_loading_foods(name);
CREATE INDEX IF NOT EXISTS idx_carb_loading_foods_default ON carb_loading_foods(is_default);

-- ============================================================================
-- Table 3: carb_loading_user_foods
-- Purpose: User-created carb loading foods (scanned, imported, or manual)
-- ============================================================================

CREATE TABLE IF NOT EXISTS carb_loading_user_foods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  device_id TEXT NOT NULL,
  client_food_id TEXT,
  name TEXT NOT NULL,
  display_name TEXT NOT NULL,
  display_name_plural TEXT,
  carbs_per_serving REAL NOT NULL,
  image_address TEXT,
  barcode TEXT,
  source_food_id UUID REFERENCES foods(id),
  source_user_food_id UUID REFERENCES user_foods(id),
  is_deleted BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT carbs_positive CHECK (carbs_per_serving > 0)
);

COMMENT ON TABLE carb_loading_user_foods IS 'User-created carb loading foods from scanning, importing, or manual entry';
COMMENT ON COLUMN carb_loading_user_foods.device_id IS 'Device that created this food';
COMMENT ON COLUMN carb_loading_user_foods.barcode IS 'Barcode if scanned via barcode scanner';
COMMENT ON COLUMN carb_loading_user_foods.source_food_id IS 'FK to foods table if imported from nutrition plan';
COMMENT ON COLUMN carb_loading_user_foods.source_user_food_id IS 'FK to user_foods if imported from user custom foods';
COMMENT ON COLUMN carb_loading_user_foods.is_deleted IS 'Soft delete flag to preserve meal history';

CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_device ON carb_loading_user_foods(device_id);
CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_deleted ON carb_loading_user_foods(is_deleted);
CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_barcode ON carb_loading_user_foods(barcode) WHERE barcode IS NOT NULL;

-- ============================================================================
-- Table 4: carb_loading_food_meal_types
-- Purpose: Junction table linking global foods to meal types (many-to-many)
-- ============================================================================

CREATE TABLE IF NOT EXISTS carb_loading_food_meal_types (
  carb_loading_food_id UUID NOT NULL REFERENCES carb_loading_foods(id) ON DELETE CASCADE,
  meal_type_id INTEGER NOT NULL REFERENCES meal_types(id),
  PRIMARY KEY (carb_loading_food_id, meal_type_id)
);

COMMENT ON TABLE carb_loading_food_meal_types IS 'Links global carb loading foods to meal types (e.g., Cereal → Breakfast)';

CREATE INDEX IF NOT EXISTS idx_carb_food_meal_types_food ON carb_loading_food_meal_types(carb_loading_food_id);
CREATE INDEX IF NOT EXISTS idx_carb_food_meal_types_meal ON carb_loading_food_meal_types(meal_type_id);

-- ============================================================================
-- Table 5: carb_loading_user_food_meal_types
-- Purpose: Junction table linking user foods to meal types (many-to-many)
-- ============================================================================

CREATE TABLE IF NOT EXISTS carb_loading_user_food_meal_types (
  carb_loading_user_food_id UUID NOT NULL REFERENCES carb_loading_user_foods(id) ON DELETE CASCADE,
  meal_type_id INTEGER NOT NULL REFERENCES meal_types(id),
  PRIMARY KEY (carb_loading_user_food_id, meal_type_id)
);

COMMENT ON TABLE carb_loading_user_food_meal_types IS 'Links user carb loading foods to meal types (e.g., "My Pasta" → Lunch, Dinner)';

CREATE INDEX IF NOT EXISTS idx_carb_user_food_meal_types_food ON carb_loading_user_food_meal_types(carb_loading_user_food_id);
CREATE INDEX IF NOT EXISTS idx_carb_user_food_meal_types_meal ON carb_loading_user_food_meal_types(meal_type_id);

-- ============================================================================
-- Table 6: carb_loading_day_meals
-- Purpose: Tracks actual food selections for each meal on each carb loading day
-- ============================================================================

CREATE TABLE IF NOT EXISTS carb_loading_day_meals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  carb_loading_day_id TEXT NOT NULL REFERENCES carb_loading_days(id) ON DELETE CASCADE,
  meal_type_id INTEGER NOT NULL REFERENCES meal_types(id),
  carb_loading_food_id UUID REFERENCES carb_loading_foods(id),
  carb_loading_user_food_id UUID REFERENCES carb_loading_user_foods(id),
  food_display_name TEXT,
  quantity INTEGER DEFAULT 1,
  carbs_consumed REAL NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT quantity_positive CHECK (quantity > 0),
  CONSTRAINT carbs_positive CHECK (carbs_consumed >= 0),
  CONSTRAINT one_food_type CHECK (
    (carb_loading_food_id IS NOT NULL AND carb_loading_user_food_id IS NULL) OR
    (carb_loading_food_id IS NULL AND carb_loading_user_food_id IS NOT NULL)
  )
);

COMMENT ON TABLE carb_loading_day_meals IS 'Actual food selections per meal per day (e.g., Day -2, Breakfast: 2x Cereal, 1x Banana)';
COMMENT ON COLUMN carb_loading_day_meals.quantity IS 'Number of servings';
COMMENT ON COLUMN carb_loading_day_meals.carbs_consumed IS 'Calculated: quantity * carbs_per_serving';
COMMENT ON CONSTRAINT one_food_type ON carb_loading_day_meals IS 'Ensures exactly one food type is set (either default OR user food, not both)';

CREATE INDEX IF NOT EXISTS idx_carb_day_meals_day ON carb_loading_day_meals(carb_loading_day_id);
CREATE INDEX IF NOT EXISTS idx_carb_day_meals_meal_type ON carb_loading_day_meals(meal_type_id);
CREATE INDEX IF NOT EXISTS idx_carb_day_meals_food ON carb_loading_day_meals(carb_loading_food_id) WHERE carb_loading_food_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_carb_day_meals_user_food ON carb_loading_day_meals(carb_loading_user_food_id) WHERE carb_loading_user_food_id IS NOT NULL;

-- ============================================================================
-- Row Level Security (RLS) Policies
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE meal_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE carb_loading_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE carb_loading_user_foods ENABLE ROW LEVEL SECURITY;
ALTER TABLE carb_loading_food_meal_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE carb_loading_user_food_meal_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE carb_loading_day_meals ENABLE ROW LEVEL SECURITY;

-- meal_types: Public read access (reference data)
CREATE POLICY "meal_types_public_read" ON meal_types FOR SELECT USING (true);

-- carb_loading_foods: Public read access (global defaults)
CREATE POLICY "carb_loading_foods_public_read" ON carb_loading_foods FOR SELECT USING (true);

-- carb_loading_user_foods: Device-based access
CREATE POLICY "carb_loading_user_foods_device_read" ON carb_loading_user_foods
  FOR SELECT USING (device_id = current_setting('app.device_id', true));

CREATE POLICY "carb_loading_user_foods_device_insert" ON carb_loading_user_foods
  FOR INSERT WITH CHECK (device_id = current_setting('app.device_id', true));

CREATE POLICY "carb_loading_user_foods_device_update" ON carb_loading_user_foods
  FOR UPDATE USING (device_id = current_setting('app.device_id', true));

CREATE POLICY "carb_loading_user_foods_device_delete" ON carb_loading_user_foods
  FOR DELETE USING (device_id = current_setting('app.device_id', true));

-- carb_loading_food_meal_types: Public read access (reference data)
CREATE POLICY "carb_loading_food_meal_types_public_read" ON carb_loading_food_meal_types
  FOR SELECT USING (true);

-- carb_loading_user_food_meal_types: Device-based access via user_food
CREATE POLICY "carb_loading_user_food_meal_types_device_read" ON carb_loading_user_food_meal_types
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM carb_loading_user_foods
      WHERE id = carb_loading_user_food_id
      AND device_id = current_setting('app.device_id', true)
    )
  );

CREATE POLICY "carb_loading_user_food_meal_types_device_insert" ON carb_loading_user_food_meal_types
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM carb_loading_user_foods
      WHERE id = carb_loading_user_food_id
      AND device_id = current_setting('app.device_id', true)
    )
  );

CREATE POLICY "carb_loading_user_food_meal_types_device_delete" ON carb_loading_user_food_meal_types
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM carb_loading_user_foods
      WHERE id = carb_loading_user_food_id
      AND device_id = current_setting('app.device_id', true)
    )
  );

-- carb_loading_day_meals: Device-based access via carb_loading_days → carb_loading_plans
CREATE POLICY "carb_loading_day_meals_device_read" ON carb_loading_day_meals
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM carb_loading_days d
      JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
      WHERE d.id = carb_loading_day_id
      AND p.user_id = current_setting('app.device_id', true)
    )
  );

CREATE POLICY "carb_loading_day_meals_device_insert" ON carb_loading_day_meals
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM carb_loading_days d
      JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
      WHERE d.id = carb_loading_day_id
      AND p.user_id = current_setting('app.device_id', true)
    )
  );

CREATE POLICY "carb_loading_day_meals_device_update" ON carb_loading_day_meals
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM carb_loading_days d
      JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
      WHERE d.id = carb_loading_day_id
      AND p.user_id = current_setting('app.device_id', true)
    )
  );

CREATE POLICY "carb_loading_day_meals_device_delete" ON carb_loading_day_meals
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM carb_loading_days d
      JOIN carb_loading_plans p ON p.id = d.carb_loading_plan_id
      WHERE d.id = carb_loading_day_id
      AND p.user_id = current_setting('app.device_id', true)
    )
  );

-- ============================================================================
-- Migration Complete
-- ============================================================================

-- Verify table creation
DO $$
BEGIN
  RAISE NOTICE 'Carb loading food tables migration completed successfully';
  RAISE NOTICE 'Tables created: meal_types, carb_loading_foods, carb_loading_user_foods, carb_loading_food_meal_types, carb_loading_user_food_meal_types, carb_loading_day_meals';
  RAISE NOTICE 'Seed data inserted: 4 meal types';
  RAISE NOTICE 'Next step: Run seed data migration to populate carb_loading_foods and carb_loading_food_meal_types';
END $$;
