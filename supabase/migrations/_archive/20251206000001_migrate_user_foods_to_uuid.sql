-- Migration to update user_foods and carb_loading_user_foods to use UUID as foreign key
-- instead of device_id

-- Step 1: Drop existing foreign key constraints on user_foods
ALTER TABLE public.user_foods
DROP CONSTRAINT IF EXISTS user_foods_device_id_fkey;

-- Step 2: Drop existing foreign key constraints on carb_loading_user_foods
ALTER TABLE public.carb_loading_user_foods
DROP CONSTRAINT IF EXISTS carb_loading_user_foods_device_id_fkey;

-- Step 3: Add new foreign key constraint for user_foods.user_id -> users.id
ALTER TABLE public.user_foods
ADD CONSTRAINT user_foods_user_id_fkey
FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Step 4: Add new foreign key constraint for carb_loading_user_foods.user_id -> users.id
ALTER TABLE public.carb_loading_user_foods
ADD CONSTRAINT carb_loading_user_foods_user_id_fkey
FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;

-- Step 5: Create indexes on user_id columns for performance
CREATE INDEX IF NOT EXISTS idx_user_foods_user_id ON public.user_foods(user_id);
CREATE INDEX IF NOT EXISTS idx_carb_loading_user_foods_user_id ON public.carb_loading_user_foods(user_id);

-- Step 6: Update RLS policies to use user_id instead of device_id
-- Drop existing policies
DROP POLICY IF EXISTS "Users can manage their own foods" ON public.user_foods;
DROP POLICY IF EXISTS "Users can manage their own carb loading foods" ON public.carb_loading_user_foods;

-- Create new policies using user_id
CREATE POLICY "Users can manage their own foods" ON public.user_foods
FOR ALL USING (
  user_id = auth.uid()::text OR
  user_id IN (SELECT id::text FROM public.users WHERE id = auth.uid())
);

CREATE POLICY "Users can manage their own carb loading foods" ON public.carb_loading_user_foods
FOR ALL USING (
  user_id = auth.uid()::text OR
  user_id IN (SELECT id::text FROM public.users WHERE id = auth.uid())
);

-- Step 7: Comment updates
COMMENT ON COLUMN public.user_foods.user_id IS 'User ID (UUID) that owns this food';
COMMENT ON COLUMN public.user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';

COMMENT ON COLUMN public.carb_loading_user_foods.user_id IS 'User ID (UUID) that owns this food';
COMMENT ON COLUMN public.carb_loading_user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';