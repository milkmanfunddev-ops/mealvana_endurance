set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.delete_nutrition_plan_by_device_plan_id(p_device_id text, p_plan_id text)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    result JSONB;
BEGIN
    result := delete_nutrition_plan_versioned(p_device_id, p_plan_id);
    RETURN (result->>'success')::BOOLEAN;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.delete_nutrition_plan_versioned(p_device_id text, p_plan_id text, p_client_version integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    result_plan nutrition_plans;
    current_version INTEGER;
    conflict_detected BOOLEAN := FALSE;
BEGIN
    -- Check if plan exists and get current version
    SELECT version INTO current_version
    FROM nutrition_plans 
    WHERE device_id = p_device_id AND plan_id = p_plan_id AND is_deleted = FALSE;
    
    -- Check if plan exists
    IF current_version IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'conflict', false,
            'message', 'Plan not found or already deleted.'
        );
    END IF;
    
    -- Detect conflicts
    IF p_client_version IS NOT NULL AND p_client_version < current_version THEN
        conflict_detected := TRUE;
    END IF;
    
    -- Handle conflict
    IF conflict_detected THEN
        SELECT * INTO result_plan
        FROM nutrition_plans 
        WHERE device_id = p_device_id AND plan_id = p_plan_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'conflict', true,
            'current_version', current_version,
            'client_version', p_client_version,
            'server_plan', row_to_json(result_plan),
            'message', 'Version conflict detected. Server has newer version.'
        );
    END IF;
    
    -- Perform soft delete with version increment
    UPDATE nutrition_plans 
    SET 
        is_deleted = TRUE,
        version = version + 1,
        last_modified_by = p_device_id,
        client_updated_at = NOW(),
        updated_at = NOW()
    WHERE device_id = p_device_id AND plan_id = p_plan_id
    RETURNING * INTO result_plan;
    
    RETURN jsonb_build_object(
        'success', true,
        'conflict', false,
        'operation', 'delete',
        'plan', row_to_json(result_plan),
        'new_version', result_plan.version
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_latest_nutrition_plan(p_device_id text)
 RETURNS nutrition_plans
 LANGUAGE plpgsql
AS $function$
DECLARE
    result_plan nutrition_plans;
BEGIN
    SELECT * INTO result_plan
    FROM nutrition_plans 
    WHERE device_id = p_device_id
    ORDER BY created_at DESC
    LIMIT 1;
    
    RETURN result_plan;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_latest_nutrition_plan_by_device_id(p_device_id text)
 RETURNS nutrition_plans
 LANGUAGE plpgsql
AS $function$
DECLARE
    result_plan nutrition_plans;
BEGIN
    SELECT * INTO result_plan
    FROM nutrition_plans 
    WHERE device_id = p_device_id AND is_deleted = FALSE
    ORDER BY updated_at DESC
    LIMIT 1;
    
    RETURN result_plan;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_nutrition_plans_by_device_id(p_device_id text)
 RETURNS SETOF nutrition_plans
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT * FROM nutrition_plans 
    WHERE device_id = p_device_id AND is_deleted = FALSE
    ORDER BY updated_at DESC;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.get_user_by_device_id(p_device_id text)
 RETURNS users
 LANGUAGE plpgsql
AS $function$
DECLARE
    result_user users;
BEGIN
    SELECT * INTO result_user
    FROM users 
    WHERE device_id = p_device_id;
    
    RETURN result_user;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_food_preferences_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_food_preferences(p_device_id text, p_preferences jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    preference_record RECORD;
BEGIN
    -- Delete existing preferences for this user
    DELETE FROM food_preferences WHERE device_id = p_device_id;

    -- Insert new preferences
    FOR preference_record IN
        SELECT
            key as food_name,
            value as preference
        FROM jsonb_each_text(p_preferences)
    LOOP
        INSERT INTO food_preferences (device_id, food_name, preference)
        VALUES (p_device_id, preference_record.food_name, preference_record.preference);
    END LOOP;

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        -- Log error and return false
        RAISE NOTICE 'Error in upsert_food_preferences: %', SQLERRM;
        RETURN FALSE;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_nutrition_plan(p_device_id text, p_plan_data jsonb, p_distance_miles numeric DEFAULT NULL::numeric, p_pace_minutes_per_mile numeric DEFAULT NULL::numeric)
 RETURNS nutrition_plans
 LANGUAGE plpgsql
AS $function$
DECLARE
    result_plan nutrition_plans;
BEGIN
    -- Delete existing plan for this device
    DELETE FROM nutrition_plans WHERE device_id = p_device_id;
    
    -- Insert new plan
    INSERT INTO nutrition_plans (
        device_id,
        plan_data,
        distance_miles,
        pace_minutes_per_mile
    ) VALUES (
        p_device_id,
        p_plan_data,
        p_distance_miles,
        p_pace_minutes_per_mile
    )
    RETURNING * INTO result_plan;
    
    RETURN result_plan;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_nutrition_plan(p_device_id text, p_plan_id text, p_plan_data jsonb)
 RETURNS nutrition_plans
 LANGUAGE plpgsql
AS $function$
DECLARE
    result JSONB;
    result_plan nutrition_plans;
BEGIN
    -- Call versioned function with default parameters
    result := upsert_nutrition_plan_versioned(p_device_id, p_plan_id, p_plan_data);
    
    -- Extract plan from result
    IF (result->>'success')::BOOLEAN THEN
        SELECT * INTO result_plan FROM jsonb_populate_record(null::nutrition_plans, result->'plan');
    ELSE
        -- In case of conflict, return current server version
        SELECT * INTO result_plan FROM jsonb_populate_record(null::nutrition_plans, result->'server_plan');
    END IF;
    
    RETURN result_plan;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_nutrition_plan_versioned(p_device_id text, p_plan_id text, p_plan_data jsonb, p_client_version integer DEFAULT NULL::integer, p_client_updated_at timestamp with time zone DEFAULT now())
 RETURNS jsonb
 LANGUAGE plpgsql
AS $function$
DECLARE
    result_plan nutrition_plans;
    current_version INTEGER;
    conflict_detected BOOLEAN := FALSE;
    operation_type TEXT;
BEGIN
    -- Check if plan exists and get current version
    SELECT version INTO current_version
    FROM nutrition_plans 
    WHERE device_id = p_device_id AND plan_id = p_plan_id AND is_deleted = FALSE;
    
    -- Detect conflicts
    IF current_version IS NOT NULL AND p_client_version IS NOT NULL THEN
        IF p_client_version < current_version THEN
            conflict_detected := TRUE;
        END IF;
    END IF;
    
    -- Handle conflict detection
    IF conflict_detected THEN
        -- Return conflict information instead of updating
        SELECT * INTO result_plan
        FROM nutrition_plans 
        WHERE device_id = p_device_id AND plan_id = p_plan_id;
        
        RETURN jsonb_build_object(
            'success', false,
            'conflict', true,
            'current_version', current_version,
            'client_version', p_client_version,
            'server_plan', row_to_json(result_plan),
            'message', 'Version conflict detected. Server has newer version.'
        );
    END IF;
    
    -- Determine operation type
    operation_type := CASE WHEN current_version IS NULL THEN 'insert' ELSE 'update' END;
    
    -- Perform upsert with version increment
    INSERT INTO nutrition_plans (
        device_id,
        plan_id,
        plan_name,
        plan_data,
        total_calories,
        notes,
        distance_miles,
        pace_minutes_per_mile,
        version,
        last_modified_by,
        client_updated_at,
        is_deleted,
        conflict_resolution
    ) VALUES (
        p_device_id,
        p_plan_id,
        COALESCE((p_plan_data->>'plan_name')::TEXT, 'Nutrition Plan'),
        p_plan_data->'plan_data',
        (p_plan_data->>'total_calories')::INTEGER,
        (p_plan_data->>'notes')::TEXT,
        (p_plan_data->>'distance_miles')::DECIMAL,
        (p_plan_data->>'pace_minutes_per_mile')::DECIMAL,
        1, -- Initial version
        p_device_id,
        p_client_updated_at,
        FALSE,
        'last_write_wins'
    )
    ON CONFLICT (device_id, plan_id) 
    DO UPDATE SET
        plan_name = COALESCE((p_plan_data->>'plan_name')::TEXT, nutrition_plans.plan_name),
        plan_data = p_plan_data->'plan_data',
        total_calories = (p_plan_data->>'total_calories')::INTEGER,
        notes = (p_plan_data->>'notes')::TEXT,
        distance_miles = (p_plan_data->>'distance_miles')::DECIMAL,
        pace_minutes_per_mile = (p_plan_data->>'pace_minutes_per_mile')::DECIMAL,
        version = nutrition_plans.version + 1, -- Increment version
        last_modified_by = p_device_id,
        client_updated_at = p_client_updated_at,
        updated_at = NOW(),
        is_deleted = FALSE
    RETURNING * INTO result_plan;
    
    -- Return success response
    RETURN jsonb_build_object(
        'success', true,
        'conflict', false,
        'operation', operation_type,
        'plan', row_to_json(result_plan),
        'new_version', result_plan.version
    );
END;
$function$
;

CREATE OR REPLACE FUNCTION public.upsert_user_by_device_id(p_device_id text, p_user_data jsonb DEFAULT '{}'::jsonb)
 RETURNS users
 LANGUAGE plpgsql
AS $function$
DECLARE
    result_user users;
BEGIN
    -- Try to update first
    UPDATE users 
    SET 
        gender = COALESCE((p_user_data->>'gender')::TEXT, gender),
        birthday = COALESCE((p_user_data->>'birthday')::DATE, birthday),
        height_feet = COALESCE((p_user_data->>'height_feet')::INTEGER, height_feet),
        height_inches = COALESCE((p_user_data->>'height_inches')::INTEGER, height_inches),
        weight_pounds = COALESCE((p_user_data->>'weight_pounds')::DECIMAL, weight_pounds),
        runs_with_water_bottle = COALESCE((p_user_data->>'runs_with_water_bottle')::BOOLEAN, runs_with_water_bottle),
        food_preferences = COALESCE(p_user_data->'food_preferences', food_preferences),
        preferred_distance_unit = COALESCE((p_user_data->>'preferred_distance_unit')::TEXT, preferred_distance_unit),
        preferred_pace_unit = COALESCE((p_user_data->>'preferred_pace_unit')::TEXT, preferred_pace_unit),
        gut_training_level = COALESCE((p_user_data->>'gut_training_level')::TEXT, gut_training_level),
        onboarding_completed = COALESCE((p_user_data->>'onboarding_completed')::BOOLEAN, onboarding_completed),
        app_version = COALESCE((p_user_data->>'app_version')::TEXT, app_version),
        last_active_at = NOW(),
        updated_at = NOW()
    WHERE device_id = p_device_id
    RETURNING * INTO result_user;
    
    -- If no row was updated, insert a new one
    IF NOT FOUND THEN
        INSERT INTO users (
            device_id,
            gender,
            birthday,
            height_feet,
            height_inches,
            weight_pounds,
            runs_with_water_bottle,
            food_preferences,
            preferred_distance_unit,
            preferred_pace_unit,
            gut_training_level,
            onboarding_completed,
            app_version,
            last_active_at
        ) VALUES (
            p_device_id,
            (p_user_data->>'gender')::TEXT,
            (p_user_data->>'birthday')::DATE,
            (p_user_data->>'height_feet')::INTEGER,
            (p_user_data->>'height_inches')::INTEGER,
            (p_user_data->>'weight_pounds')::DECIMAL,
            COALESCE((p_user_data->>'runs_with_water_bottle')::BOOLEAN, false),
            COALESCE(p_user_data->'food_preferences', '{}'::JSONB),
            COALESCE((p_user_data->>'preferred_distance_unit')::TEXT, 'miles'),
            COALESCE((p_user_data->>'preferred_pace_unit')::TEXT, 'min_per_mile'),
            COALESCE((p_user_data->>'gut_training_level')::TEXT, 'moderate'),
            COALESCE((p_user_data->>'onboarding_completed')::BOOLEAN, false),
            (p_user_data->>'app_version')::TEXT,
            NOW()
        )
        RETURNING * INTO result_user;
    END IF;
    
    RETURN result_user;
END;
$function$
;



