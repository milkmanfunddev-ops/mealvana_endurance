-- Ensure categories table exists with correct structure
CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE
);

-- Insert the required categories
INSERT INTO categories (id, name) VALUES (1, 'before_run')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO categories (id, name) VALUES (2, 'during_run')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO categories (id, name) VALUES (3, 'after_run')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name;

-- Ensure food_categories junction table exists
CREATE TABLE IF NOT EXISTS food_categories (
  food_id UUID NOT NULL REFERENCES foods(id) ON DELETE CASCADE,
  category_id INTEGER NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  PRIMARY KEY (food_id, category_id)
);

CREATE INDEX IF NOT EXISTS idx_food_categories_food_id ON food_categories(food_id);
CREATE INDEX IF NOT EXISTS idx_food_categories_category_id ON food_categories(category_id);
