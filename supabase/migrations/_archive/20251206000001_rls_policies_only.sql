-- RLS Policies with proper type casting for UUID/text comparison
-- Run this after completing lines 1-29 of the original migration

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can manage their own foods" ON public.user_foods;
DROP POLICY IF EXISTS "Users can manage their own carb loading foods" ON public.carb_loading_user_foods;

-- Create new policies for user_foods
-- Note: user_id column is TEXT containing UUID strings
-- auth.uid() returns UUID type, so we cast it to text
CREATE POLICY "Users can manage their own foods" ON public.user_foods
FOR ALL USING (
  user_id = auth.uid()::text
);

-- Create new policies for carb_loading_user_foods
CREATE POLICY "Users can manage their own carb loading foods" ON public.carb_loading_user_foods
FOR ALL USING (
  user_id = auth.uid()::text
);

-- Add comments to document the columns
COMMENT ON COLUMN public.user_foods.user_id IS 'User ID (UUID as text) that owns this food';
COMMENT ON COLUMN public.user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';

COMMENT ON COLUMN public.carb_loading_user_foods.user_id IS 'User ID (UUID as text) that owns this food';
COMMENT ON COLUMN public.carb_loading_user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';