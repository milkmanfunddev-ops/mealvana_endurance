-- Fix RLS on categories table - it's read-only reference data, should be publicly readable
-- The service role needs to be able to read it

-- Disable RLS on categories (it's reference data, no user-specific rows)
ALTER TABLE categories DISABLE ROW LEVEL SECURITY;

-- Grant read access to everyone (anon, authenticated, service_role)
GRANT SELECT ON categories TO anon, authenticated, service_role;

-- Disable RLS on food_categories junction table
ALTER TABLE food_categories DISABLE ROW LEVEL SECURITY;

-- Grant read access to everyone
GRANT SELECT ON food_categories TO anon, authenticated, service_role;
