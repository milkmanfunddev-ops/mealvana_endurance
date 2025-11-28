-- Complete fix for UUID/TEXT type mismatch
-- This handles the case where user_id is TEXT but users.id is UUID

-- Step 1: Check current column types (for debugging)
SELECT 'Current column types:';
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
    AND ((table_name = 'user_foods' AND column_name IN ('user_id', 'device_id'))
    OR (table_name = 'users' AND column_name = 'id'));

-- Step 2: Since user_id is TEXT and users.id is UUID, we have two options:

-- OPTION 1: Keep user_id as TEXT (simpler, no data migration needed)
-- Skip the foreign key constraint (it won't work with type mismatch)
-- Just create the RLS policies with proper casting

-- Drop existing policies
DROP POLICY IF EXISTS "Users can manage their own foods" ON public.user_foods;
DROP POLICY IF EXISTS "Users can manage their own carb loading foods" ON public.carb_loading_user_foods;

-- Create policies with proper casting (UUID to TEXT)
CREATE POLICY "Users can manage their own foods" ON public.user_foods
FOR ALL USING (
  user_id = auth.uid()::text
);

CREATE POLICY "Users can manage their own carb loading foods" ON public.carb_loading_user_foods
FOR ALL USING (
  user_id = auth.uid()::text
);

-- OPTION 2: Convert user_id to UUID type (more complex but cleaner)
-- Uncomment below if you want to convert the column types

/*
-- Backup the data first (just in case)
CREATE TABLE user_foods_backup AS SELECT * FROM user_foods;
CREATE TABLE carb_loading_user_foods_backup AS SELECT * FROM carb_loading_user_foods;

-- Drop foreign key constraints if they exist
ALTER TABLE public.user_foods DROP CONSTRAINT IF EXISTS user_foods_user_id_fkey;
ALTER TABLE public.carb_loading_user_foods DROP CONSTRAINT IF EXISTS carb_loading_user_foods_user_id_fkey;

-- Convert user_id from TEXT to UUID
ALTER TABLE public.user_foods
  ALTER COLUMN user_id TYPE uuid USING user_id::uuid;

ALTER TABLE public.carb_loading_user_foods
  ALTER COLUMN user_id TYPE uuid USING user_id::uuid;

-- Now add foreign key constraints (UUID to UUID will work)
ALTER TABLE public.user_foods
  ADD CONSTRAINT user_foods_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

ALTER TABLE public.carb_loading_user_foods
  ADD CONSTRAINT carb_loading_user_foods_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Create policies without casting (UUID to UUID)
DROP POLICY IF EXISTS "Users can manage their own foods" ON public.user_foods;
CREATE POLICY "Users can manage their own foods" ON public.user_foods
FOR ALL USING (
  user_id = auth.uid()
);

DROP POLICY IF EXISTS "Users can manage their own carb loading foods" ON public.carb_loading_user_foods;
CREATE POLICY "Users can manage their own carb loading foods" ON public.carb_loading_user_foods
FOR ALL USING (
  user_id = auth.uid()
);
*/

-- Step 3: Add indexes for performance (works with either TEXT or UUID)
CREATE INDEX IF NOT EXISTS idx_user_foods_user_id ON public.user_foods(user_id);
CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_user_id ON public.carb_loading_user_foods(user_id);

-- Step 4: Add comments
COMMENT ON COLUMN public.user_foods.user_id IS 'User ID (stored as TEXT, contains UUID) that owns this food';
COMMENT ON COLUMN public.user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';

COMMENT ON COLUMN public.carb_loading_user_foods.user_id IS 'User ID (stored as TEXT, contains UUID) that owns this food';
COMMENT ON COLUMN public.carb_loading_user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';