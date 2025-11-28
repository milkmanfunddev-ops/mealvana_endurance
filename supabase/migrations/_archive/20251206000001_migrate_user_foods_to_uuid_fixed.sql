-- Continue from line 30 - Fixed RLS policies with proper type casting

-- Create new policies using user_id with proper type casting
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