-- Mealvana Endurance Database Views
-- Simplified views for common queries

-- ============================================
-- USER_NUTRITION_OVERVIEW VIEW
-- ============================================
-- Comprehensive view of user data with preferences and latest plan
CREATE OR REPLACE VIEW public.user_nutrition_overview AS
SELECT 
    u.id,
    u.device_id,
    u.gender,
    u.birthday,
    EXTRACT(YEAR FROM age(CURRENT_DATE, u.birthday)) AS age,
    u.height_feet,
    u.height_inches,
    (u.height_feet * 12 + u.height_inches) AS total_height_inches,
    u.weight_pounds,
    ROUND(u.weight_pounds * 0.453592, 2) AS weight_kg,
    u.runs_with_water_bottle,
    u.gut_training_level,
    u.preferred_distance_unit,
    u.preferred_pace_unit,
    u.onboarding_completed,
    u.app_version,
    u.created_at,
    u.updated_at,
    u.last_active_at,
    -- Count of food preferences
    (SELECT COUNT(*) FROM food_preferences fp WHERE fp.device_id = u.device_id) AS preference_count,
    -- Latest nutrition plan
    (SELECT np.plan_id 
     FROM nutrition_plans np 
     WHERE np.device_id = u.device_id 
     ORDER BY np.created_at DESC 
     LIMIT 1) AS latest_plan_id
FROM users u;

-- Grant permissions
GRANT SELECT ON public.user_nutrition_overview TO anon;
GRANT SELECT ON public.user_nutrition_overview TO authenticated;
GRANT SELECT ON public.user_nutrition_overview TO service_role;

-- ============================================
-- FOOD_WITH_PREFERENCES VIEW
-- ============================================
-- Foods joined with user preferences for personalized recommendations
CREATE OR REPLACE VIEW public.food_with_preferences AS
SELECT 
    f.id AS food_id,
    f.name AS food_name,
    f.icon_path,
    f.description,
    f.instructions,
    f.serving_amount,
    f.serving_unit,
    f.serving_size,
    f.calories_per_serving,
    f.carbs_per_serving,
    f.protein_per_serving,
    f.fat_per_serving,
    f.sodium_mg,
    f.fluid_ml_per_serving,
    f.before_run_suitable,
    f.during_run_suitable,
    f.run_portable,
    f.aid_station_available,
    fp.device_id,
    fp.preference,
    fp.updated_at AS preference_updated_at,
    -- Phase categories
    CASE WHEN fc1.food_id IS NOT NULL THEN true ELSE false END AS is_before_run,
    CASE WHEN fc2.food_id IS NOT NULL THEN true ELSE false END AS is_during_run,
    CASE WHEN fc3.food_id IS NOT NULL THEN true ELSE false END AS is_after_run
FROM foods f
LEFT JOIN food_preferences fp ON f.name = fp.food_name
LEFT JOIN food_categories fc1 ON f.id = fc1.food_id AND fc1.category_id = 1  -- before_run
LEFT JOIN food_categories fc2 ON f.id = fc2.food_id AND fc2.category_id = 2  -- during_run
LEFT JOIN food_categories fc3 ON f.id = fc3.food_id AND fc3.category_id = 3; -- after_run

-- Grant permissions
GRANT SELECT ON public.food_with_preferences TO anon;
GRANT SELECT ON public.food_with_preferences TO authenticated;
GRANT SELECT ON public.food_with_preferences TO service_role;

-- ============================================
-- FOOD_PHASE_SUITABILITY VIEW
-- ============================================
-- Simplified view showing which foods are suitable for each phase
CREATE OR REPLACE VIEW public.food_phase_suitability AS
SELECT 
    f.id,
    f.name,
    f.carbs_per_serving,
    f.protein_per_serving,
    f.sodium_mg,
    f.fluid_ml_per_serving,
    f.serving_amount,
    f.serving_unit,
    -- Phase flags
    f.before_run_suitable OR 
        EXISTS(SELECT 1 FROM food_categories fc WHERE fc.food_id = f.id AND fc.category_id = 1) AS suitable_before,
    f.during_run_suitable OR 
        EXISTS(SELECT 1 FROM food_categories fc WHERE fc.food_id = f.id AND fc.category_id = 2) AS suitable_during,
    EXISTS(SELECT 1 FROM food_categories fc WHERE fc.food_id = f.id AND fc.category_id = 3) AS suitable_after,
    -- Special flags
    f.run_portable,
    f.aid_station_available,
    f.requires_preparation
FROM foods f;

-- Grant permissions
GRANT SELECT ON public.food_phase_suitability TO anon;
GRANT SELECT ON public.food_phase_suitability TO authenticated;
GRANT SELECT ON public.food_phase_suitability TO service_role;

-- ============================================
-- USER_PREFERRED_FOODS VIEW
-- ============================================
-- Quick access to user's liked and willing-to-try foods
CREATE OR REPLACE VIEW public.user_preferred_foods AS
SELECT 
    fp.device_id,
    f.id AS food_id,
    f.name AS food_name,
    fp.preference,
    f.before_run_suitable,
    f.during_run_suitable,
    f.carbs_per_serving,
    f.protein_per_serving,
    f.sodium_mg,
    f.serving_amount,
    f.serving_unit
FROM food_preferences fp
JOIN foods f ON f.name = fp.food_name
WHERE fp.preference IN ('like', 'willing_to_try')
ORDER BY 
    fp.device_id,
    CASE fp.preference 
        WHEN 'like' THEN 1 
        WHEN 'willing_to_try' THEN 2 
    END,
    f.name;

-- Grant permissions
GRANT SELECT ON public.user_preferred_foods TO anon;
GRANT SELECT ON public.user_preferred_foods TO authenticated;
GRANT SELECT ON public.user_preferred_foods TO service_role;

-- ============================================
-- NUTRITION_PLAN_SUMMARY VIEW
-- ============================================
-- Simplified view of nutrition plans with parsed metadata
CREATE OR REPLACE VIEW public.nutrition_plan_summary AS
SELECT 
    np.id,
    np.device_id,
    np.plan_id,
    np.plan_name,
    np.distance_miles,
    np.pace_minutes_per_mile,
    np.total_calories,
    np.created_at,
    np.updated_at,
    np.version,
    -- Extract key metrics from plan_data JSON
    (np.plan_data->>'macroTargets')::jsonb->'carbs' AS total_carbs,
    (np.plan_data->>'macroTargets')::jsonb->'protein' AS total_protein,
    (np.plan_data->>'macroTargets')::jsonb->'fat' AS total_fat,
    (np.plan_data->>'macroTargets')::jsonb->'sodium' AS total_sodium,
    (np.plan_data->>'macroTargets')::jsonb->'fluids' AS total_fluids,
    -- Count items in each phase
    jsonb_array_length(COALESCE((np.plan_data->'sections'->0->'foodItems')::jsonb, '[]'::jsonb)) AS before_run_items,
    jsonb_array_length(COALESCE((np.plan_data->'sections'->1->'foodItems')::jsonb, '[]'::jsonb)) AS during_run_items,
    jsonb_array_length(COALESCE((np.plan_data->'sections'->2->'foodItems')::jsonb, '[]'::jsonb)) AS after_run_items,
    -- User info
    u.gender,
    u.weight_pounds,
    u.gut_training_level
FROM nutrition_plans np
JOIN users u ON u.device_id = np.device_id
WHERE np.is_deleted = false;

-- Grant permissions
GRANT SELECT ON public.nutrition_plan_summary TO anon;
GRANT SELECT ON public.nutrition_plan_summary TO authenticated;
GRANT SELECT ON public.nutrition_plan_summary TO service_role;

-- ============================================
-- FOOD_PREFERENCE_STATS VIEW
-- ============================================
-- Aggregate statistics on food preferences
CREATE OR REPLACE VIEW public.food_preference_stats AS
SELECT 
    f.id AS food_id,
    f.name AS food_name,
    COUNT(CASE WHEN fp.preference = 'like' THEN 1 END) AS like_count,
    COUNT(CASE WHEN fp.preference = 'dislike' THEN 1 END) AS dislike_count,
    COUNT(CASE WHEN fp.preference = 'willing_to_try' THEN 1 END) AS willing_count,
    COUNT(fp.id) AS total_preferences,
    ROUND(
        COUNT(CASE WHEN fp.preference = 'like' THEN 1 END)::numeric / 
        NULLIF(COUNT(fp.id), 0) * 100, 
        2
    ) AS like_percentage
FROM foods f
LEFT JOIN food_preferences fp ON f.name = fp.food_name
GROUP BY f.id, f.name
ORDER BY like_percentage DESC NULLS LAST, f.name;

-- Grant permissions
GRANT SELECT ON public.food_preference_stats TO anon;
GRANT SELECT ON public.food_preference_stats TO authenticated;
GRANT SELECT ON public.food_preference_stats TO service_role;

-- ============================================
-- ACTIVE_USERS VIEW
-- ============================================
-- Users who have been active in the last 30 days
CREATE OR REPLACE VIEW public.active_users AS
SELECT 
    u.*,
    np.plan_count,
    np.latest_plan_date
FROM users u
LEFT JOIN (
    SELECT 
        device_id,
        COUNT(*) AS plan_count,
        MAX(created_at) AS latest_plan_date
    FROM nutrition_plans
    WHERE is_deleted = false
    GROUP BY device_id
) np ON u.device_id = np.device_id
WHERE u.last_active_at > CURRENT_DATE - INTERVAL '30 days'
   OR np.latest_plan_date > CURRENT_DATE - INTERVAL '30 days';

-- Grant permissions
GRANT SELECT ON public.active_users TO authenticated;
GRANT SELECT ON public.active_users TO service_role;

-- ============================================
-- LLM_FOOD_SELECTION VIEW
-- ============================================
-- Optimized view specifically for LLM edge function food selection
CREATE OR REPLACE VIEW public.llm_food_selection AS
SELECT 
    f.id,
    f.name,
    f.carbs_per_serving,
    f.protein_per_serving,
    f.fat_per_serving,
    f.sodium_mg,
    f.fluid_ml_per_serving,
    f.serving_amount,
    f.serving_unit,
    f.before_run_suitable,
    f.during_run_suitable,
    f.run_portable,
    f.aid_station_available,
    -- Phase suitability flags
    CASE WHEN f.before_run_suitable OR EXISTS(
        SELECT 1 FROM food_categories fc WHERE fc.food_id = f.id AND fc.category_id = 1
    ) THEN true ELSE false END AS suitable_before,
    
    CASE WHEN f.during_run_suitable OR EXISTS(
        SELECT 1 FROM food_categories fc WHERE fc.food_id = f.id AND fc.category_id = 2
    ) THEN true ELSE false END AS suitable_during,
    
    CASE WHEN EXISTS(
        SELECT 1 FROM food_categories fc WHERE fc.food_id = f.id AND fc.category_id = 3
    ) THEN true ELSE false END AS suitable_after
FROM foods f
ORDER BY f.name;

-- Grant permissions
GRANT SELECT ON public.llm_food_selection TO anon;
GRANT SELECT ON public.llm_food_selection TO authenticated;
GRANT SELECT ON public.llm_food_selection TO service_role;

-- ============================================
-- USER_FOOD_PREFERENCES_CATEGORIZED VIEW
-- ============================================
-- User preferences categorized by type for easy filtering
CREATE OR REPLACE VIEW public.user_food_preferences_categorized AS
SELECT 
    fp.device_id,
    -- Liked foods as arrays
    COALESCE(array_agg(fp.food_name) FILTER (WHERE fp.preference = 'like'), ARRAY[]::text[]) AS liked_foods,
    -- Willing to try foods as arrays  
    COALESCE(array_agg(fp.food_name) FILTER (WHERE fp.preference = 'willing_to_try'), ARRAY[]::text[]) AS willing_to_try_foods,
    -- Disliked foods as arrays
    COALESCE(array_agg(fp.food_name) FILTER (WHERE fp.preference = 'dislike'), ARRAY[]::text[]) AS disliked_foods
FROM food_preferences fp
GROUP BY fp.device_id;

-- Grant permissions
GRANT SELECT ON public.user_food_preferences_categorized TO anon;
GRANT SELECT ON public.user_food_preferences_categorized TO authenticated;
GRANT SELECT ON public.user_food_preferences_categorized TO service_role;

-- ============================================
-- USEFUL QUERIES USING THESE VIEWS
-- ============================================

-- Example 1: Get user's preferred foods for each phase
/*
SELECT * FROM user_preferred_foods
WHERE device_id = 'user-device-id'
  AND before_run_suitable = true;
*/

-- Example 2: Get food recommendations for a user
/*
SELECT * FROM food_with_preferences
WHERE device_id = 'user-device-id'
  AND preference IN ('like', 'willing_to_try')
  AND is_during_run = true
ORDER BY preference, carbs_per_serving DESC;
*/

-- Example 3: Get user overview with latest plan
/*
SELECT * FROM user_nutrition_overview
WHERE device_id = 'user-device-id';
*/

-- Example 4: Get most popular foods
/*
SELECT * FROM food_preference_stats
WHERE total_preferences >= 10
ORDER BY like_percentage DESC
LIMIT 20;
*/

-- Example 5: Get recent nutrition plans with details
/*
SELECT * FROM nutrition_plan_summary
WHERE device_id = 'user-device-id'
ORDER BY created_at DESC
LIMIT 5;
*/