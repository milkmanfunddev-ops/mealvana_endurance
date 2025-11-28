-- First, let's check the actual column types
SELECT
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'user_foods'
    AND column_name IN ('user_id', 'device_id');

-- Check users table id type
SELECT
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'id';

-- If user_id is UUID type, use this policy (NO casting needed):
DROP POLICY IF EXISTS "Users can manage their own foods" ON public.user_foods;
CREATE POLICY "Users can manage their own foods" ON public.user_foods
FOR ALL USING (
  user_id = auth.uid()
);

-- If user_id is UUID type for carb_loading_user_foods:
DROP POLICY IF EXISTS "Users can manage their own carb loading foods" ON public.carb_loading_user_foods;
CREATE POLICY "Users can manage their own carb loading foods" ON public.carb_loading_user_foods
FOR ALL USING (
  user_id = auth.uid()
);

-- Add comments
COMMENT ON COLUMN public.user_foods.user_id IS 'User ID (UUID) that owns this food';
COMMENT ON COLUMN public.user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';

COMMENT ON COLUMN public.carb_loading_user_foods.user_id IS 'User ID (UUID) that owns this food';
COMMENT ON COLUMN public.carb_loading_user_foods.device_id IS 'DEPRECATED: Legacy device ID, kept for backwards compatibility';