-- Simple RLS Policy Fix
-- This assumes user_id is TEXT type containing UUID strings

-- Drop existing policies
DROP POLICY IF EXISTS "Users can manage their own foods" ON public.user_foods;
DROP POLICY IF EXISTS "Users can manage their own carb loading foods" ON public.carb_loading_user_foods;

-- Create policies with explicit casting from UUID to TEXT
CREATE POLICY "Users can manage their own foods" ON public.user_foods
FOR ALL USING (
  user_id = (auth.uid())::text
);

CREATE POLICY "Users can manage their own carb loading foods" ON public.carb_loading_user_foods
FOR ALL USING (
  user_id = (auth.uid())::text
);

-- Add comments
COMMENT ON COLUMN public.user_foods.user_id IS 'User ID (TEXT containing UUID) that owns this food';
COMMENT ON COLUMN public.user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';

COMMENT ON COLUMN public.carb_loading_user_foods.user_id IS 'User ID (TEXT containing UUID) that owns this food';
COMMENT ON COLUMN public.carb_loading_user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';