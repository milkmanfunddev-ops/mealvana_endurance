-- STEP 1: Check the actual column types in your database
-- Run this query first to see what data types you have

SELECT
    'user_foods' as table_name,
    column_name,
    data_type,
    udt_name,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'user_foods'
    AND column_name IN ('user_id', 'device_id')
UNION ALL
SELECT
    'carb_loading_user_foods' as table_name,
    column_name,
    data_type,
    udt_name,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'carb_loading_user_foods'
    AND column_name IN ('user_id', 'device_id')
UNION ALL
SELECT
    'users' as table_name,
    column_name,
    data_type,
    udt_name,
    is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
    AND table_name = 'users'
    AND column_name = 'id';

-- STEP 2: After checking types above, use the appropriate solution:

-- SOLUTION A: If user_id is TEXT type (use this if user_id shows as 'text' or 'character varying')
/*
DROP POLICY IF EXISTS "Users can manage their own foods" ON public.user_foods;
CREATE POLICY "Users can manage their own foods" ON public.user_foods
FOR ALL USING (
  user_id = auth.uid()::text
);

DROP POLICY IF EXISTS "Users can manage their own carb loading foods" ON public.carb_loading_user_foods;
CREATE POLICY "Users can manage their own carb loading foods" ON public.carb_loading_user_foods
FOR ALL USING (
  user_id = auth.uid()::text
);
*/

-- SOLUTION B: If user_id is UUID type (use this if user_id shows as 'uuid')
/*
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

-- SOLUTION C: If there's a mix or you need to handle both anonymous (text) and auth (uuid) users
/*
DROP POLICY IF EXISTS "Users can manage their own foods" ON public.user_foods;
CREATE POLICY "Users can manage their own foods" ON public.user_foods
FOR ALL USING (
  CASE
    WHEN pg_typeof(user_id) = 'uuid'::regtype THEN user_id = auth.uid()
    WHEN pg_typeof(user_id) = 'text'::regtype THEN user_id = auth.uid()::text
    ELSE false
  END
);
*/