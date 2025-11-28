-- Complete the migration WITHOUT foreign key constraints
-- (Since user_id is TEXT and users.id is UUID, we can't create FK constraints)

-- Drop existing RLS policies
DROP POLICY IF EXISTS "Users can manage their own foods" ON public.user_foods;
DROP POLICY IF EXISTS "Users can manage their own carb loading foods" ON public.carb_loading_user_foods;

-- Create RLS policies with proper type casting (UUID to TEXT)
CREATE POLICY "Users can manage their own foods" ON public.user_foods
FOR ALL USING (
  user_id = auth.uid()::text
);

CREATE POLICY "Users can manage their own carb loading foods" ON public.carb_loading_user_foods
FOR ALL USING (
  user_id = auth.uid()::text
);

-- Add comments to document the columns
COMMENT ON COLUMN public.user_foods.user_id IS 'User ID (TEXT containing UUID string) that owns this food';
COMMENT ON COLUMN public.user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';

COMMENT ON COLUMN public.carb_loading_user_foods.user_id IS 'User ID (TEXT containing UUID string) that owns this food';
COMMENT ON COLUMN public.carb_loading_user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';

-- Note: We're NOT adding foreign key constraints because of the type mismatch
-- The application layer will handle the referential integrity