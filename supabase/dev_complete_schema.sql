


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."delete_nutrition_plan_by_device_plan_id"("p_device_id" "text", "p_plan_id" "text") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result JSONB;
BEGIN
    result := delete_nutrition_plan_versioned(p_device_id, p_plan_id);
    RETURN (result->>'success')::BOOLEAN;
END;
$$;


ALTER FUNCTION "public"."delete_nutrition_plan_by_device_plan_id"("p_device_id" "text", "p_plan_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_client_version" integer DEFAULT NULL::integer) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."delete_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_client_version" integer) OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."nutrition_plans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_id" "text" NOT NULL,
    "plan_data" "jsonb" NOT NULL,
    "distance_miles" numeric(5,2),
    "pace_minutes_per_mile" numeric(5,2),
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "plan_id" "text" NOT NULL,
    "plan_name" "text" NOT NULL,
    "total_calories" integer,
    "notes" "text",
    "version" integer DEFAULT 1,
    "last_modified_by" "text",
    "client_updated_at" timestamp with time zone,
    "is_deleted" boolean DEFAULT false,
    "conflict_resolution" "text",
    "activity_id" "text"
);


ALTER TABLE "public"."nutrition_plans" OWNER TO "postgres";


COMMENT ON COLUMN "public"."nutrition_plans"."activity_id" IS 'Links nutrition plan to a calendar activity/event. Nullable to support standalone plans.';



CREATE OR REPLACE FUNCTION "public"."get_latest_nutrition_plan"("p_device_id" "text") RETURNS "public"."nutrition_plans"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."get_latest_nutrition_plan"("p_device_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_latest_nutrition_plan_by_device_id"("p_device_id" "text") RETURNS "public"."nutrition_plans"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."get_latest_nutrition_plan_by_device_id"("p_device_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_nutrition_plans_by_device_id"("p_device_id" "text") RETURNS SETOF "public"."nutrition_plans"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM nutrition_plans 
    WHERE device_id = p_device_id AND is_deleted = FALSE
    ORDER BY updated_at DESC;
END;
$$;


ALTER FUNCTION "public"."get_nutrition_plans_by_device_id"("p_device_id" "text") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_id" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "gender" "text",
    "birthday" "date",
    "height_feet" integer,
    "height_inches" integer,
    "weight_pounds" numeric(5,2),
    "runs_with_water_bottle" boolean DEFAULT false,
    "food_preferences" "jsonb" DEFAULT '{}'::"jsonb",
    "preferred_distance_unit" "text" DEFAULT 'miles'::"text",
    "preferred_pace_unit" "text" DEFAULT 'min_per_mile'::"text",
    "gut_training_level" "text" DEFAULT 'moderate'::"text",
    "onboarding_completed" boolean DEFAULT false,
    "last_active_at" timestamp with time zone DEFAULT "now"(),
    "app_version" "text",
    "notifications_enabled" boolean DEFAULT false,
    "default_reminder_day" integer DEFAULT 4,
    "default_reminder_hour" integer DEFAULT 17,
    "default_reminder_minute" integer DEFAULT 0,
    "default_reminder_recurring" boolean DEFAULT false,
    "cycling_ftp_watts" integer,
    "prefers_cycling_power" boolean DEFAULT false,
    "swimming_css_seconds_per_100m" integer,
    "prefers_swimming_pace" boolean DEFAULT false,
    CONSTRAINT "users_gender_check" CHECK (("gender" = ANY (ARRAY['male'::"text", 'female'::"text", 'other'::"text"]))),
    CONSTRAINT "users_gut_training_level_check" CHECK (("gut_training_level" = ANY (ARRAY['low'::"text", 'moderate'::"text", 'high'::"text"]))),
    CONSTRAINT "users_preferred_distance_unit_check" CHECK (("preferred_distance_unit" = ANY (ARRAY['miles'::"text", 'kilometers'::"text"]))),
    CONSTRAINT "users_preferred_pace_unit_check" CHECK (("preferred_pace_unit" = ANY (ARRAY['min_per_mile'::"text", 'min_per_km'::"text"])))
);


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON COLUMN "public"."users"."cycling_ftp_watts" IS 'User default FTP (Functional Threshold Power) in watts';



COMMENT ON COLUMN "public"."users"."prefers_cycling_power" IS 'Whether user prefers to input power vs speed for cycling';



COMMENT ON COLUMN "public"."users"."swimming_css_seconds_per_100m" IS 'User default CSS (Critical Swim Speed) in seconds per 100m';



COMMENT ON COLUMN "public"."users"."prefers_swimming_pace" IS 'Whether user prefers to input pace vs speed for swimming';



CREATE OR REPLACE FUNCTION "public"."get_user_by_device_id"("p_device_id" "text") RETURNS "public"."users"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    result_user users;
BEGIN
    SELECT * INTO result_user
    FROM users 
    WHERE device_id = p_device_id;
    
    RETURN result_user;
END;
$$;


ALTER FUNCTION "public"."get_user_by_device_id"("p_device_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_food_preferences_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_food_preferences_updated_at"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_updated_at_column"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_updated_at_column"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_food_preferences"("p_device_id" "text", "p_preferences" "jsonb") RETURNS boolean
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."upsert_food_preferences"("p_device_id" "text", "p_preferences" "jsonb") OWNER TO "postgres";


COMMENT ON FUNCTION "public"."upsert_food_preferences"("p_device_id" "text", "p_preferences" "jsonb") IS 'Replace all food preferences for a user with new preferences from JSONB object';



CREATE OR REPLACE FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb") RETURNS "public"."nutrition_plans"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_data" "jsonb", "p_distance_miles" numeric DEFAULT NULL::numeric, "p_pace_minutes_per_mile" numeric DEFAULT NULL::numeric) RETURNS "public"."nutrition_plans"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_data" "jsonb", "p_distance_miles" numeric, "p_pace_minutes_per_mile" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb", "p_client_version" integer DEFAULT NULL::integer, "p_client_updated_at" timestamp with time zone DEFAULT "now"()) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."upsert_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb", "p_client_version" integer, "p_client_updated_at" timestamp with time zone) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_user_by_device_id"("p_device_id" "text", "p_user_data" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "public"."users"
    LANGUAGE "plpgsql"
    AS $$
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
$$;


ALTER FUNCTION "public"."upsert_user_by_device_id"("p_device_id" "text", "p_user_data" "jsonb") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."activities" (
    "id" "text" NOT NULL,
    "user_id" "text" NOT NULL,
    "activity_type" "text" NOT NULL,
    "title" "text" NOT NULL,
    "scheduled_date_time" timestamp without time zone NOT NULL,
    "status" "text" DEFAULT 'planned'::"text",
    "distance_miles" real,
    "duration_minutes" integer,
    "pace_target_minutes_per_mile" real,
    "intensity_level" "text",
    "completed_at" timestamp without time zone,
    "completion_rating" integer,
    "completion_notes" "text",
    "actual_distance_miles" real,
    "actual_duration_minutes" integer,
    "notes" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" timestamp without time zone,
    "sport_type" "text" DEFAULT 'running'::"text",
    "cycling_power_watts" integer,
    "cycling_ftp_watts" integer,
    "swimming_speed_per_100m" integer,
    "swimming_css_seconds_per_100m" integer,
    "cycling_speed_mph" real,
    "cycling_terrain" "text",
    "cycling_indoor_outdoor" "text",
    "cycling_elevation_gain_ft" integer,
    "cycling_session_goal" "text",
    "swimming_pace_per_100m_seconds" integer,
    "swimming_pool_or_open_water" "text",
    "swimming_water_temp_c" real,
    "intensity_target" "text",
    "time_before_minutes" integer,
    CONSTRAINT "activities_cycling_columns_check" CHECK (((("sport_type" = 'cycling'::"text") AND ("cycling_power_watts" IS NOT NULL)) OR (("sport_type" <> 'cycling'::"text") AND ("cycling_power_watts" IS NULL) AND ("cycling_ftp_watts" IS NULL)))),
    CONSTRAINT "activities_cycling_indoor_outdoor_check" CHECK ((("cycling_indoor_outdoor" IS NULL) OR ("cycling_indoor_outdoor" = ANY (ARRAY['indoor'::"text", 'outdoor'::"text"])))),
    CONSTRAINT "activities_cycling_session_goal_check" CHECK ((("cycling_session_goal" IS NULL) OR ("cycling_session_goal" = ANY (ARRAY['endurance'::"text", 'tempo'::"text", 'intervals'::"text"])))),
    CONSTRAINT "activities_cycling_terrain_check" CHECK ((("cycling_terrain" IS NULL) OR ("cycling_terrain" = ANY (ARRAY['flat'::"text", 'rolling'::"text", 'hilly'::"text"])))),
    CONSTRAINT "activities_sport_type_check" CHECK (("sport_type" = ANY (ARRAY['running'::"text", 'cycling'::"text", 'swimming'::"text"]))),
    CONSTRAINT "activities_swimming_columns_check" CHECK (((("sport_type" = 'swimming'::"text") AND ("swimming_speed_per_100m" IS NOT NULL)) OR (("sport_type" <> 'swimming'::"text") AND ("swimming_speed_per_100m" IS NULL) AND ("swimming_css_seconds_per_100m" IS NULL)))),
    CONSTRAINT "activities_swimming_pool_or_open_water_check" CHECK ((("swimming_pool_or_open_water" IS NULL) OR ("swimming_pool_or_open_water" = ANY (ARRAY['pool'::"text", 'open_water'::"text"])))),
    CONSTRAINT "activity_type_check" CHECK (("activity_type" = ANY (ARRAY['running'::"text", 'cycling'::"text", 'swimming'::"text"]))),
    CONSTRAINT "intensity_check" CHECK ((("intensity_level" IS NULL) OR ("intensity_level" = ANY (ARRAY['easy'::"text", 'moderate'::"text", 'hard'::"text", 'race'::"text"])))),
    CONSTRAINT "rating_check" CHECK ((("completion_rating" IS NULL) OR (("completion_rating" >= 1) AND ("completion_rating" <= 5)))),
    CONSTRAINT "status_check" CHECK (("status" = ANY (ARRAY['planned'::"text", 'in_progress'::"text", 'completed'::"text", 'skipped'::"text"])))
);


ALTER TABLE "public"."activities" OWNER TO "postgres";


COMMENT ON TABLE "public"."activities" IS 'All calendar entries including workouts and events';



COMMENT ON COLUMN "public"."activities"."activity_type" IS 'Type of endurance sport: running, cycling, or swimming';



COMMENT ON COLUMN "public"."activities"."status" IS 'Current status: planned, in_progress, completed, skipped';



COMMENT ON COLUMN "public"."activities"."sport_type" IS 'Type of endurance sport: running, cycling, or swimming';



COMMENT ON COLUMN "public"."activities"."cycling_power_watts" IS 'Average power output in watts for cycling activities';



COMMENT ON COLUMN "public"."activities"."cycling_ftp_watts" IS 'Functional Threshold Power in watts (if known)';



COMMENT ON COLUMN "public"."activities"."swimming_speed_per_100m" IS 'Average pace in seconds per 100 meters for swimming';



COMMENT ON COLUMN "public"."activities"."swimming_css_seconds_per_100m" IS 'Critical Swim Speed in seconds per 100m (if known)';



COMMENT ON COLUMN "public"."activities"."cycling_speed_mph" IS 'Average cycling speed in miles per hour';



COMMENT ON COLUMN "public"."activities"."cycling_terrain" IS 'Terrain type: flat, rolling, or hilly';



COMMENT ON COLUMN "public"."activities"."cycling_indoor_outdoor" IS 'Indoor (trainer) or outdoor cycling';



COMMENT ON COLUMN "public"."activities"."cycling_elevation_gain_ft" IS 'Total elevation gain in feet';



COMMENT ON COLUMN "public"."activities"."cycling_session_goal" IS 'Session type: endurance, tempo, or intervals';



COMMENT ON COLUMN "public"."activities"."swimming_pace_per_100m_seconds" IS 'Swimming pace in seconds per 100 meters';



COMMENT ON COLUMN "public"."activities"."swimming_pool_or_open_water" IS 'Pool or open water swimming';



COMMENT ON COLUMN "public"."activities"."swimming_water_temp_c" IS 'Water temperature in Celsius';



COMMENT ON COLUMN "public"."activities"."intensity_target" IS 'Intensity target (zone_1, zone_2, rpe_3, etc.) - works across all sports';



COMMENT ON COLUMN "public"."activities"."time_before_minutes" IS 'Pre-activity timing window in minutes (replaces run-specific pre_run_timing)';



CREATE TABLE IF NOT EXISTS "public"."activity_completions" (
    "id" "text" NOT NULL,
    "activity_id" "text" NOT NULL,
    "completed_at" timestamp without time zone NOT NULL,
    "actual_distance_miles" real,
    "actual_duration_minutes" integer,
    "average_pace_minutes_per_mile" real,
    "completion_rating" integer,
    "completion_notes" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "user_id" "text" NOT NULL,
    CONSTRAINT "rating_check" CHECK ((("completion_rating" IS NULL) OR (("completion_rating" >= 1) AND ("completion_rating" <= 5))))
);


ALTER TABLE "public"."activity_completions" OWNER TO "postgres";


COMMENT ON TABLE "public"."activity_completions" IS 'Completion records for activities';



COMMENT ON COLUMN "public"."activity_completions"."activity_id" IS 'One-to-one link to activities table';



COMMENT ON COLUMN "public"."activity_completions"."user_id" IS 'User who completed the activity (denormalized from activities table for query efficiency)';



CREATE TABLE IF NOT EXISTS "public"."app_content" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "version" integer DEFAULT 1 NOT NULL,
    "environment" "text" DEFAULT 'production'::"text" NOT NULL,
    "locale" "text" DEFAULT 'en'::"text" NOT NULL,
    "content" "jsonb" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "created_by" "uuid",
    "updated_by" "uuid"
);


ALTER TABLE "public"."app_content" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."carb_loading_day_meals" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "carb_loading_day_id" "text" NOT NULL,
    "meal_type_id" integer NOT NULL,
    "carb_loading_food_id" "uuid",
    "carb_loading_user_food_id" "uuid",
    "food_display_name" "text",
    "quantity" integer DEFAULT 1,
    "carbs_consumed" real NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "carbs_positive" CHECK (("carbs_consumed" >= (0)::double precision)),
    CONSTRAINT "one_food_type" CHECK (((("carb_loading_food_id" IS NOT NULL) AND ("carb_loading_user_food_id" IS NULL)) OR (("carb_loading_food_id" IS NULL) AND ("carb_loading_user_food_id" IS NOT NULL)))),
    CONSTRAINT "quantity_positive" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."carb_loading_day_meals" OWNER TO "postgres";


COMMENT ON TABLE "public"."carb_loading_day_meals" IS 'Actual food selections per meal per day (e.g., Day -2, Breakfast: 2x Cereal, 1x Banana)';



COMMENT ON COLUMN "public"."carb_loading_day_meals"."quantity" IS 'Number of servings';



COMMENT ON COLUMN "public"."carb_loading_day_meals"."carbs_consumed" IS 'Calculated: quantity * carbs_per_serving';



COMMENT ON CONSTRAINT "one_food_type" ON "public"."carb_loading_day_meals" IS 'Ensures exactly one food type is set (either default OR user food, not both)';



CREATE TABLE IF NOT EXISTS "public"."carb_loading_days" (
    "id" "text" NOT NULL,
    "carb_loading_plan_id" "text" NOT NULL,
    "plan_date" timestamp without time zone NOT NULL,
    "day_number" integer NOT NULL,
    "carb_target_grams" integer NOT NULL,
    "calorie_target" integer,
    "meal_count" integer DEFAULT 6,
    "breakfast_percent" real DEFAULT 0.25,
    "morning_snack_percent" real DEFAULT 0.10,
    "lunch_percent" real DEFAULT 0.25,
    "afternoon_snack_percent" real DEFAULT 0.15,
    "dinner_percent" real DEFAULT 0.20,
    "evening_snack_percent" real DEFAULT 0.05,
    "logged_carbs_grams" integer DEFAULT 0,
    "logged_calories" integer DEFAULT 0,
    "completed" boolean DEFAULT false,
    "carb_protocol_g_per_kg" real DEFAULT 8.0 NOT NULL,
    CONSTRAINT "afternoon_snack_percent_check" CHECK ((("afternoon_snack_percent" >= (0.0)::double precision) AND ("afternoon_snack_percent" <= (1.0)::double precision))),
    CONSTRAINT "breakfast_percent_check" CHECK ((("breakfast_percent" >= (0.0)::double precision) AND ("breakfast_percent" <= (1.0)::double precision))),
    CONSTRAINT "carb_target_check" CHECK (("carb_target_grams" > 0)),
    CONSTRAINT "day_number_check" CHECK (("day_number" > 0)),
    CONSTRAINT "dinner_percent_check" CHECK ((("dinner_percent" >= (0.0)::double precision) AND ("dinner_percent" <= (1.0)::double precision))),
    CONSTRAINT "evening_snack_percent_check" CHECK ((("evening_snack_percent" >= (0.0)::double precision) AND ("evening_snack_percent" <= (1.0)::double precision))),
    CONSTRAINT "logged_calories_check" CHECK (("logged_calories" >= 0)),
    CONSTRAINT "logged_carbs_check" CHECK (("logged_carbs_grams" >= 0)),
    CONSTRAINT "lunch_percent_check" CHECK ((("lunch_percent" >= (0.0)::double precision) AND ("lunch_percent" <= (1.0)::double precision))),
    CONSTRAINT "meal_count_check" CHECK (("meal_count" > 0)),
    CONSTRAINT "morning_snack_percent_check" CHECK ((("morning_snack_percent" >= (0.0)::double precision) AND ("morning_snack_percent" <= (1.0)::double precision)))
);


ALTER TABLE "public"."carb_loading_days" OWNER TO "postgres";


COMMENT ON TABLE "public"."carb_loading_days" IS 'Individual day entries within carb loading plans';



COMMENT ON COLUMN "public"."carb_loading_days"."day_number" IS '1, 2, 3, etc. (last number = race day - 1)';



COMMENT ON COLUMN "public"."carb_loading_days"."meal_count" IS 'Default 6: breakfast, snack, lunch, snack, dinner, evening';



COMMENT ON COLUMN "public"."carb_loading_days"."carb_protocol_g_per_kg" IS 'Carbohydrate protocol in grams per kilogram of bodyweight (e.g., 8.0 for 8g/kg)';



CREATE TABLE IF NOT EXISTS "public"."carb_loading_food_meal_types" (
    "carb_loading_food_id" "uuid" NOT NULL,
    "meal_type_id" integer NOT NULL
);


ALTER TABLE "public"."carb_loading_food_meal_types" OWNER TO "postgres";


COMMENT ON TABLE "public"."carb_loading_food_meal_types" IS 'Links global carb loading foods to meal types (e.g., Cereal → Breakfast)';



CREATE TABLE IF NOT EXISTS "public"."carb_loading_foods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "display_name_plural" "text",
    "carbs_per_serving" real NOT NULL,
    "image_address" "text",
    "is_default" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "carbs_positive" CHECK (("carbs_per_serving" > (0)::double precision))
);


ALTER TABLE "public"."carb_loading_foods" OWNER TO "postgres";


COMMENT ON TABLE "public"."carb_loading_foods" IS 'Global default carb loading foods (cereal, pasta, etc.) - pre-seeded';



COMMENT ON COLUMN "public"."carb_loading_foods"."id" IS 'UUID primary key';



COMMENT ON COLUMN "public"."carb_loading_foods"."name" IS 'Internal name (lowercase, underscore-separated)';



COMMENT ON COLUMN "public"."carb_loading_foods"."display_name" IS 'Display name with serving size (e.g., "Cereal (1/2 cup dry)")';



COMMENT ON COLUMN "public"."carb_loading_foods"."carbs_per_serving" IS 'Carbohydrates in grams per serving';



COMMENT ON COLUMN "public"."carb_loading_foods"."is_default" IS 'True for pre-seeded foods, false for admin-added';



CREATE TABLE IF NOT EXISTS "public"."carb_loading_plans" (
    "id" "text" NOT NULL,
    "event_id" "text",
    "user_id" "text" NOT NULL,
    "total_days" integer NOT NULL,
    "start_date" timestamp without time zone NOT NULL,
    "end_date" timestamp without time zone NOT NULL,
    "daily_carb_target_grams" integer NOT NULL,
    "daily_calorie_target" integer,
    "generated_at" timestamp without time zone NOT NULL,
    "algorithm_version" "text" DEFAULT 'v1.0'::"text",
    "adherence_score" real,
    "completed_at" timestamp without time zone,
    CONSTRAINT "adherence_check" CHECK ((("adherence_score" IS NULL) OR (("adherence_score" >= (0.0)::double precision) AND ("adherence_score" <= (1.0)::double precision)))),
    CONSTRAINT "total_days_check" CHECK (("total_days" = ANY (ARRAY[1, 2, 3, 7])))
);


ALTER TABLE "public"."carb_loading_plans" OWNER TO "postgres";


COMMENT ON TABLE "public"."carb_loading_plans" IS 'Carb loading plans linked to specific events';



COMMENT ON COLUMN "public"."carb_loading_plans"."event_id" IS 'FOREIGN KEY to events.id. Nullable to support standalone carb loading plans not tied to specific events. Multiple plans can share the same event_id.';



COMMENT ON COLUMN "public"."carb_loading_plans"."adherence_score" IS '0.0 to 1.0 based on logged meals';



CREATE TABLE IF NOT EXISTS "public"."carb_loading_user_food_meal_types" (
    "carb_loading_user_food_id" "uuid" NOT NULL,
    "meal_type_id" integer NOT NULL
);


ALTER TABLE "public"."carb_loading_user_food_meal_types" OWNER TO "postgres";


COMMENT ON TABLE "public"."carb_loading_user_food_meal_types" IS 'Links user carb loading foods to meal types (e.g., "My Pasta" → Lunch, Dinner)';



CREATE TABLE IF NOT EXISTS "public"."carb_loading_user_foods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_id" "text" NOT NULL,
    "client_food_id" "text",
    "name" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "display_name_plural" "text",
    "carbs_per_serving" real NOT NULL,
    "image_address" "text",
    "barcode" "text",
    "source_food_id" "uuid",
    "source_user_food_id" "uuid",
    "is_deleted" boolean DEFAULT false,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "carbs_positive" CHECK (("carbs_per_serving" > (0)::double precision))
);


ALTER TABLE "public"."carb_loading_user_foods" OWNER TO "postgres";


COMMENT ON TABLE "public"."carb_loading_user_foods" IS 'User-created carb loading foods from scanning, importing, or manual entry';



COMMENT ON COLUMN "public"."carb_loading_user_foods"."device_id" IS 'Device that created this food';



COMMENT ON COLUMN "public"."carb_loading_user_foods"."barcode" IS 'Barcode if scanned via barcode scanner';



COMMENT ON COLUMN "public"."carb_loading_user_foods"."source_food_id" IS 'FK to foods table if imported from nutrition plan';



COMMENT ON COLUMN "public"."carb_loading_user_foods"."source_user_food_id" IS 'FK to user_foods if imported from user custom foods';



COMMENT ON COLUMN "public"."carb_loading_user_foods"."is_deleted" IS 'Soft delete flag to preserve meal history';



CREATE TABLE IF NOT EXISTS "public"."categories" (
    "name" "text" NOT NULL,
    "id" integer NOT NULL
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."current_content" AS
 SELECT "id",
    "version",
    "environment",
    "locale",
    "content",
    "created_at",
    "updated_at"
   FROM "public"."app_content"
  WHERE ("is_active" = true)
  ORDER BY "version" DESC, "updated_at" DESC;


ALTER VIEW "public"."current_content" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."edge_functions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "code" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."edge_functions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."events" (
    "id" "text" NOT NULL,
    "activity_id" "text" NOT NULL,
    "event_type" "text" NOT NULL,
    "event_subtype" "text",
    "event_name" "text",
    "location" "text",
    "registration_url" "text",
    "start_time" "text",
    "goal_time_minutes" integer,
    "goal_pace_minutes_per_mile" real,
    "predicted_finish_time_minutes" integer,
    "has_carb_loading" boolean DEFAULT false,
    "carb_loading_days" integer,
    "carb_loading_start_date" timestamp without time zone,
    "bib_number" "text",
    "wave_start_time" "text",
    "packet_pickup_info" "text",
    "actual_finish_time_minutes" integer,
    "final_placement" integer,
    "age_group_placement" integer,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "has_nutrition_plan" boolean DEFAULT false,
    CONSTRAINT "carb_days_check" CHECK ((("carb_loading_days" IS NULL) OR ("carb_loading_days" = ANY (ARRAY[1, 2, 3, 7])))),
    CONSTRAINT "event_type_check" CHECK (("event_type" = ANY (ARRAY['marathon'::"text", 'half_marathon'::"text", '10k'::"text", '5k'::"text", 'ultra_50k'::"text", 'ultra_50m'::"text", 'ultra_100k'::"text", 'ultra_100m'::"text", 'custom'::"text"])))
);


ALTER TABLE "public"."events" OWNER TO "postgres";


COMMENT ON TABLE "public"."events" IS 'Specialized event data for races and competitions';



COMMENT ON COLUMN "public"."events"."activity_id" IS 'One-to-one link to activities table';



COMMENT ON COLUMN "public"."events"."has_carb_loading" IS 'Whether this event has an associated carb loading plan';



COMMENT ON COLUMN "public"."events"."has_nutrition_plan" IS 'Indicates whether this event has an associated nutrition plan (via activities.id -> nutrition_plans.activity_id)';



CREATE TABLE IF NOT EXISTS "public"."feedback" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "satisfaction_level" integer,
    "satisfaction_emoji" "text",
    "satisfaction_label" "text",
    "confidence_level" integer,
    "confidence_label" "text",
    "reuse_intent" "text",
    "reminder_requested" boolean DEFAULT false,
    "missed_reasons" "text",
    "missed_other" "text",
    "reminder_day_of_week" integer,
    "reminder_hour" integer DEFAULT 17,
    "reminder_minute" integer DEFAULT 0,
    "reminder_recurring" boolean DEFAULT false,
    "plan_name" "text",
    "user_name" "text",
    "timestamp" timestamp with time zone,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."feedback" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."food_categories" (
    "food_id" "uuid" NOT NULL,
    "category_id" integer NOT NULL
);


ALTER TABLE "public"."food_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."food_preferences" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_id" "text" NOT NULL,
    "food_name" "text" NOT NULL,
    "preference" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "food_preferences_preference_check" CHECK (("preference" = ANY (ARRAY['like'::"text", 'dislike'::"text", 'willing_to_try'::"text"])))
);


ALTER TABLE "public"."food_preferences" OWNER TO "postgres";


COMMENT ON TABLE "public"."food_preferences" IS 'Stores user food preferences (like, dislike, willing_to_try) linked by device_id';



COMMENT ON COLUMN "public"."food_preferences"."device_id" IS 'References users.device_id - user who owns this preference';



COMMENT ON COLUMN "public"."food_preferences"."food_name" IS 'Name of the food item (should match foods.name)';



COMMENT ON COLUMN "public"."food_preferences"."preference" IS 'User preference: like, dislike, or willing_to_try';



CREATE TABLE IF NOT EXISTS "public"."foods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text",
    "image_address" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "serving_amount" numeric,
    "max_servings_before" integer,
    "max_servings_during" integer,
    "sodium_mg" integer,
    "caffeine_mg" integer,
    "potassium_mg" integer,
    "fat_per_serving" numeric(10,2),
    "carbs_per_serving" numeric(10,2),
    "protein_per_serving" numeric(10,2),
    "calories_per_serving" integer,
    "fluid_ml_per_serving" numeric(10,1),
    "show_in_preferences" boolean DEFAULT false,
    "display_name" character varying(100),
    "max_servings_after" integer,
    "is_electrolyte" boolean DEFAULT false,
    "display_name_plural" character varying(100),
    "to_exclude_from_solver" boolean DEFAULT false,
    "product_type_id" "uuid",
    "description" "text",
    "serving_description" "text",
    "serving_size" character varying(50),
    "is_essential" boolean DEFAULT false,
    "is_other_food" boolean,
    "suitable_for_activities" "jsonb"
);


ALTER TABLE "public"."foods" OWNER TO "postgres";


COMMENT ON COLUMN "public"."foods"."show_in_preferences" IS 'Whether this food should be shown in the onboarding food preferences screen';



COMMENT ON COLUMN "public"."foods"."is_essential" IS 'No need to present to user to set preferences';



COMMENT ON COLUMN "public"."foods"."suitable_for_activities" IS 'JSONB map of sport types to boolean suitability. Example: {"running": true, "cycling": true, "swimming": false}. Null means suitable for all activities (backward compatibility).';



CREATE TABLE IF NOT EXISTS "public"."macro_targets_table" (
    "id" "text" NOT NULL,
    "pre_run_carbs_g" numeric NOT NULL,
    "pre_run_protein_g" numeric NOT NULL,
    "pre_run_fat_cap_g" numeric NOT NULL,
    "pre_run_fluids_ml" numeric NOT NULL,
    "pre_run_sodium_mg" numeric NOT NULL,
    "during_carb_rate_g_per_h" numeric NOT NULL,
    "during_carb_total_g" numeric NOT NULL,
    "during_fluid_rate_ml_per_h" numeric NOT NULL,
    "during_fluid_total_ml" numeric NOT NULL,
    "during_sodium_rate_mg_per_h" numeric NOT NULL,
    "during_sodium_total_mg" numeric NOT NULL,
    "during_mass_norm_rate_g_per_h" numeric,
    "post_run_carbs_g" numeric NOT NULL,
    "post_run_protein_g" numeric NOT NULL,
    "post_run_fluids_ml" numeric NOT NULL,
    "post_run_sodium_mg" numeric NOT NULL,
    "distance_mi" numeric NOT NULL,
    "duration_h" numeric NOT NULL,
    "pace_min_per_mile" numeric NOT NULL,
    "calories_gross_kcal" numeric NOT NULL,
    "met" numeric NOT NULL,
    "calculation_rule" "text" NOT NULL,
    "timestamp" timestamp without time zone NOT NULL,
    "is_user_modified" boolean DEFAULT false NOT NULL,
    "modified_fields" "text" DEFAULT ''::"text" NOT NULL,
    CONSTRAINT "check_calories_positive" CHECK (("calories_gross_kcal" >= (0)::numeric)),
    CONSTRAINT "check_distance_positive" CHECK (("distance_mi" > (0)::numeric)),
    CONSTRAINT "check_duration_positive" CHECK (("duration_h" > (0)::numeric)),
    CONSTRAINT "check_during_carb_rate_positive" CHECK (("during_carb_rate_g_per_h" >= (0)::numeric)),
    CONSTRAINT "check_during_carb_total_positive" CHECK (("during_carb_total_g" >= (0)::numeric)),
    CONSTRAINT "check_during_fluid_rate_positive" CHECK (("during_fluid_rate_ml_per_h" >= (0)::numeric)),
    CONSTRAINT "check_during_fluid_total_positive" CHECK (("during_fluid_total_ml" >= (0)::numeric)),
    CONSTRAINT "check_during_sodium_rate_positive" CHECK (("during_sodium_rate_mg_per_h" >= (0)::numeric)),
    CONSTRAINT "check_during_sodium_total_positive" CHECK (("during_sodium_total_mg" >= (0)::numeric)),
    CONSTRAINT "check_met_positive" CHECK (("met" > (0)::numeric)),
    CONSTRAINT "check_pace_positive" CHECK (("pace_min_per_mile" > (0)::numeric)),
    CONSTRAINT "check_post_run_carbs_positive" CHECK (("post_run_carbs_g" >= (0)::numeric)),
    CONSTRAINT "check_post_run_fluids_positive" CHECK (("post_run_fluids_ml" >= (0)::numeric)),
    CONSTRAINT "check_post_run_protein_positive" CHECK (("post_run_protein_g" >= (0)::numeric)),
    CONSTRAINT "check_post_run_sodium_positive" CHECK (("post_run_sodium_mg" >= (0)::numeric)),
    CONSTRAINT "check_pre_run_carbs_positive" CHECK (("pre_run_carbs_g" >= (0)::numeric)),
    CONSTRAINT "check_pre_run_fat_positive" CHECK (("pre_run_fat_cap_g" >= (0)::numeric)),
    CONSTRAINT "check_pre_run_fluids_positive" CHECK (("pre_run_fluids_ml" >= (0)::numeric)),
    CONSTRAINT "check_pre_run_protein_positive" CHECK (("pre_run_protein_g" >= (0)::numeric)),
    CONSTRAINT "check_pre_run_sodium_positive" CHECK (("pre_run_sodium_mg" >= (0)::numeric)),
    CONSTRAINT "macro_targets_table_id_check" CHECK ((("length"("id") >= 1) AND ("length"("id") <= 50)))
);


ALTER TABLE "public"."macro_targets_table" OWNER TO "postgres";


COMMENT ON TABLE "public"."macro_targets_table" IS 'Calculated nutrition targets for running sessions (26 columns)';



COMMENT ON COLUMN "public"."macro_targets_table"."id" IS 'Unique identifier for this macro target set';



COMMENT ON COLUMN "public"."macro_targets_table"."calculation_rule" IS 'Algorithm version/rule used for calculations';



COMMENT ON COLUMN "public"."macro_targets_table"."is_user_modified" IS 'Whether user has manually adjusted these targets';



COMMENT ON COLUMN "public"."macro_targets_table"."modified_fields" IS 'Comma-separated list of user-modified field names';



CREATE TABLE IF NOT EXISTS "public"."meal_types" (
    "id" integer NOT NULL,
    "name" "text" NOT NULL,
    "display_name" "text" NOT NULL
);


ALTER TABLE "public"."meal_types" OWNER TO "postgres";


COMMENT ON TABLE "public"."meal_types" IS 'Meal categories for carb loading feature (breakfast, morning_snack, lunch, afternoon_snack, dinner, evening_snack)';



COMMENT ON COLUMN "public"."meal_types"."id" IS 'Primary key (1=breakfast, 2=lunch, 3=dinner, 4=snacks [deprecated], 5=morning_snack, 6=afternoon_snack, 7=evening_snack)';



COMMENT ON COLUMN "public"."meal_types"."name" IS 'Internal name (lowercase, underscore-separated)';



COMMENT ON COLUMN "public"."meal_types"."display_name" IS 'Display name for UI (title case)';



CREATE TABLE IF NOT EXISTS "public"."product_types" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "name_plural" "text" NOT NULL,
    "sort_order" integer,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."product_types" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_food_categories" (
    "user_food_id" "uuid" NOT NULL,
    "category_id" integer NOT NULL
);


ALTER TABLE "public"."user_food_categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_foods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_id" "text" NOT NULL,
    "client_food_id" "text",
    "barcode" "text",
    "name" "text" NOT NULL,
    "display_name" "text",
    "display_name_plural" "text",
    "description" "text",
    "image_address" "text",
    "serving_amount" numeric,
    "serving_unit" "text",
    "calories_per_serving" integer,
    "carbs_per_serving" numeric(10,2),
    "protein_per_serving" numeric(10,2),
    "fat_per_serving" numeric(10,2),
    "sodium_mg" integer,
    "fluid_ml_per_serving" numeric(10,1),
    "product_type_id" "uuid",
    "is_electrolyte" boolean DEFAULT false,
    "to_exclude_from_solver" boolean DEFAULT false,
    "is_deleted" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "client_updated_at" timestamp with time zone,
    "suitable_for_activities" "jsonb"
);


ALTER TABLE "public"."user_foods" OWNER TO "postgres";


COMMENT ON COLUMN "public"."user_foods"."suitable_for_activities" IS 'JSONB map of sport types to boolean suitability. Example: {"running": true, "cycling": true, "swimming": false}. Null means suitable for all activities (backward compatibility).';



CREATE TABLE IF NOT EXISTS "public"."user_hidden_foods" (
    "device_id" "text" NOT NULL,
    "food_id" "uuid" NOT NULL
);


ALTER TABLE "public"."user_hidden_foods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."workout_notes" (
    "id" "text" NOT NULL,
    "user_id" "uuid" NOT NULL,
    "plan_id" "text",
    "note_text" "text" NOT NULL,
    "rating" integer,
    "created_at" timestamp without time zone NOT NULL,
    "updated_at" timestamp without time zone NOT NULL,
    CONSTRAINT "workout_notes_rating_check" CHECK ((("rating" IS NULL) OR (("rating" >= 1) AND ("rating" <= 5))))
);


ALTER TABLE "public"."workout_notes" OWNER TO "postgres";


COMMENT ON TABLE "public"."workout_notes" IS 'User workout journal entries with optional ratings';



COMMENT ON COLUMN "public"."workout_notes"."user_id" IS 'References users.id (not device_id)';



COMMENT ON COLUMN "public"."workout_notes"."plan_id" IS 'Optional reference to nutrition_plans.id';



COMMENT ON COLUMN "public"."workout_notes"."rating" IS 'Optional 1-5 scale rating';



ALTER TABLE ONLY "public"."activities"
    ADD CONSTRAINT "activities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."activity_completions"
    ADD CONSTRAINT "activity_completions_activity_id_key" UNIQUE ("activity_id");



ALTER TABLE ONLY "public"."activity_completions"
    ADD CONSTRAINT "activity_completions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_content"
    ADD CONSTRAINT "app_content_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_days"
    ADD CONSTRAINT "carb_loading_days_carb_loading_plan_id_plan_date_key" UNIQUE ("carb_loading_plan_id", "plan_date");



ALTER TABLE ONLY "public"."carb_loading_days"
    ADD CONSTRAINT "carb_loading_days_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_food_meal_types"
    ADD CONSTRAINT "carb_loading_food_meal_types_pkey" PRIMARY KEY ("carb_loading_food_id", "meal_type_id");



ALTER TABLE ONLY "public"."carb_loading_foods"
    ADD CONSTRAINT "carb_loading_foods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_plans"
    ADD CONSTRAINT "carb_loading_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_user_food_meal_types"
    ADD CONSTRAINT "carb_loading_user_food_meal_types_pkey" PRIMARY KEY ("carb_loading_user_food_id", "meal_type_id");



ALTER TABLE ONLY "public"."carb_loading_user_foods"
    ADD CONSTRAINT "carb_loading_user_foods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pk" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."edge_functions"
    ADD CONSTRAINT "edge_functions_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."edge_functions"
    ADD CONSTRAINT "edge_functions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_activity_id_key" UNIQUE ("activity_id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."food_categories"
    ADD CONSTRAINT "food_categories_pkey" PRIMARY KEY ("food_id", "category_id");



ALTER TABLE ONLY "public"."food_preferences"
    ADD CONSTRAINT "food_preferences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."foods"
    ADD CONSTRAINT "foods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."macro_targets_table"
    ADD CONSTRAINT "macro_targets_table_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."meal_types"
    ADD CONSTRAINT "meal_types_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."meal_types"
    ADD CONSTRAINT "meal_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."nutrition_plans"
    ADD CONSTRAINT "nutrition_plans_device_id_plan_id_key" UNIQUE ("device_id", "plan_id");



ALTER TABLE ONLY "public"."nutrition_plans"
    ADD CONSTRAINT "nutrition_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."product_types"
    ADD CONSTRAINT "product_types_code_key" UNIQUE ("code");



ALTER TABLE ONLY "public"."product_types"
    ADD CONSTRAINT "product_types_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_food_categories"
    ADD CONSTRAINT "user_food_categories_pkey" PRIMARY KEY ("user_food_id", "category_id");



ALTER TABLE ONLY "public"."user_foods"
    ADD CONSTRAINT "user_foods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_hidden_foods"
    ADD CONSTRAINT "user_hidden_global_foods_pkey" PRIMARY KEY ("device_id", "food_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_device_id_key" UNIQUE ("device_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."workout_notes"
    ADD CONSTRAINT "workout_notes_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_activities_scheduled" ON "public"."activities" USING "btree" ("scheduled_date_time");



CREATE INDEX "idx_activities_status" ON "public"."activities" USING "btree" ("status");



CREATE INDEX "idx_activities_type" ON "public"."activities" USING "btree" ("activity_type");



CREATE INDEX "idx_activities_user" ON "public"."activities" USING "btree" ("user_id");



CREATE INDEX "idx_activity_completions_activity" ON "public"."activity_completions" USING "btree" ("activity_id");



CREATE INDEX "idx_activity_completions_date" ON "public"."activity_completions" USING "btree" ("completed_at");



CREATE INDEX "idx_activity_completions_user_id" ON "public"."activity_completions" USING "btree" ("user_id");



CREATE INDEX "idx_app_content_active" ON "public"."app_content" USING "btree" ("is_active");



CREATE INDEX "idx_app_content_env_locale" ON "public"."app_content" USING "btree" ("environment", "locale");



CREATE INDEX "idx_app_content_version" ON "public"."app_content" USING "btree" ("version");



CREATE INDEX "idx_carb_day_meals_day" ON "public"."carb_loading_day_meals" USING "btree" ("carb_loading_day_id");



CREATE INDEX "idx_carb_day_meals_food" ON "public"."carb_loading_day_meals" USING "btree" ("carb_loading_food_id") WHERE ("carb_loading_food_id" IS NOT NULL);



CREATE INDEX "idx_carb_day_meals_meal_type" ON "public"."carb_loading_day_meals" USING "btree" ("meal_type_id");



CREATE INDEX "idx_carb_day_meals_user_food" ON "public"."carb_loading_day_meals" USING "btree" ("carb_loading_user_food_id") WHERE ("carb_loading_user_food_id" IS NOT NULL);



CREATE INDEX "idx_carb_days_completed" ON "public"."carb_loading_days" USING "btree" ("completed");



CREATE INDEX "idx_carb_days_date" ON "public"."carb_loading_days" USING "btree" ("plan_date");



CREATE INDEX "idx_carb_days_plan" ON "public"."carb_loading_days" USING "btree" ("carb_loading_plan_id");



CREATE INDEX "idx_carb_food_meal_types_food" ON "public"."carb_loading_food_meal_types" USING "btree" ("carb_loading_food_id");



CREATE INDEX "idx_carb_food_meal_types_meal" ON "public"."carb_loading_food_meal_types" USING "btree" ("meal_type_id");



CREATE INDEX "idx_carb_loading_foods_default" ON "public"."carb_loading_foods" USING "btree" ("is_default");



CREATE INDEX "idx_carb_loading_foods_name" ON "public"."carb_loading_foods" USING "btree" ("name");



CREATE INDEX "idx_carb_loading_user_foods_barcode" ON "public"."carb_loading_user_foods" USING "btree" ("barcode") WHERE ("barcode" IS NOT NULL);



CREATE INDEX "idx_carb_loading_user_foods_deleted" ON "public"."carb_loading_user_foods" USING "btree" ("is_deleted");



CREATE INDEX "idx_carb_loading_user_foods_device" ON "public"."carb_loading_user_foods" USING "btree" ("device_id");



CREATE INDEX "idx_carb_plans_dates" ON "public"."carb_loading_plans" USING "btree" ("start_date", "end_date");



CREATE INDEX "idx_carb_plans_event" ON "public"."carb_loading_plans" USING "btree" ("event_id");



CREATE INDEX "idx_carb_plans_user" ON "public"."carb_loading_plans" USING "btree" ("user_id");



CREATE INDEX "idx_carb_user_food_meal_types_food" ON "public"."carb_loading_user_food_meal_types" USING "btree" ("carb_loading_user_food_id");



CREATE INDEX "idx_carb_user_food_meal_types_meal" ON "public"."carb_loading_user_food_meal_types" USING "btree" ("meal_type_id");



CREATE INDEX "idx_events_activity" ON "public"."events" USING "btree" ("activity_id");



CREATE INDEX "idx_events_carb_loading" ON "public"."events" USING "btree" ("has_carb_loading") WHERE ("has_carb_loading" = true);



CREATE INDEX "idx_events_type" ON "public"."events" USING "btree" ("event_type");



CREATE INDEX "idx_feedback_created_at" ON "public"."feedback" USING "btree" ("created_at");



CREATE INDEX "idx_feedback_satisfaction_level" ON "public"."feedback" USING "btree" ("satisfaction_level");



CREATE INDEX "idx_feedback_timestamp" ON "public"."feedback" USING "btree" ("timestamp");



CREATE INDEX "idx_feedback_user_name" ON "public"."feedback" USING "btree" ("user_name");



CREATE INDEX "idx_food_categories_category_id" ON "public"."food_categories" USING "btree" ("category_id");



CREATE INDEX "idx_food_categories_food" ON "public"."food_categories" USING "btree" ("food_id");



CREATE UNIQUE INDEX "idx_food_preferences_device_food" ON "public"."food_preferences" USING "btree" ("device_id", "food_name");



CREATE INDEX "idx_food_preferences_device_id" ON "public"."food_preferences" USING "btree" ("device_id");



CREATE INDEX "idx_food_preferences_preference" ON "public"."food_preferences" USING "btree" ("preference");



CREATE INDEX "idx_foods_product_type_id" ON "public"."foods" USING "btree" ("product_type_id");



CREATE INDEX "idx_foods_suitable_for_activities" ON "public"."foods" USING "gin" ("suitable_for_activities");



CREATE INDEX "idx_macro_targets_distance" ON "public"."macro_targets_table" USING "btree" ("distance_mi");



CREATE INDEX "idx_macro_targets_timestamp" ON "public"."macro_targets_table" USING "btree" ("timestamp");



CREATE INDEX "idx_nutrition_plans_activity_id" ON "public"."nutrition_plans" USING "btree" ("activity_id");



CREATE INDEX "idx_nutrition_plans_created_at" ON "public"."nutrition_plans" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_nutrition_plans_device_id" ON "public"."nutrition_plans" USING "btree" ("device_id");



CREATE INDEX "idx_nutrition_plans_device_updated" ON "public"."nutrition_plans" USING "btree" ("device_id", "updated_at" DESC);



CREATE INDEX "idx_nutrition_plans_plan_id" ON "public"."nutrition_plans" USING "btree" ("plan_id");



CREATE INDEX "idx_nutrition_plans_updated_at" ON "public"."nutrition_plans" USING "btree" ("updated_at" DESC);



CREATE INDEX "idx_user_food_categories_category" ON "public"."user_food_categories" USING "btree" ("category_id");



CREATE INDEX "idx_user_food_categories_user_food" ON "public"."user_food_categories" USING "btree" ("user_food_id");



CREATE INDEX "idx_user_foods_barcode" ON "public"."user_foods" USING "btree" ("barcode");



CREATE INDEX "idx_user_foods_device" ON "public"."user_foods" USING "btree" ("device_id");



CREATE INDEX "idx_user_foods_device_not_deleted" ON "public"."user_foods" USING "btree" ("device_id") WHERE ("is_deleted" = false);



CREATE INDEX "idx_user_foods_suitable_for_activities" ON "public"."user_foods" USING "gin" ("suitable_for_activities");



CREATE INDEX "idx_users_device_id" ON "public"."users" USING "btree" ("device_id");



CREATE INDEX "idx_users_updated_at" ON "public"."users" USING "btree" ("updated_at");



CREATE INDEX "idx_workout_notes_created" ON "public"."workout_notes" USING "btree" ("created_at");



CREATE INDEX "idx_workout_notes_plan" ON "public"."workout_notes" USING "btree" ("plan_id") WHERE ("plan_id" IS NOT NULL);



CREATE INDEX "idx_workout_notes_user" ON "public"."workout_notes" USING "btree" ("user_id");



CREATE UNIQUE INDEX "uq_foods_lower_name" ON "public"."foods" USING "btree" ("lower"("name"));



CREATE UNIQUE INDEX "uq_user_foods_device_clientid" ON "public"."user_foods" USING "btree" ("device_id", "client_food_id");



CREATE OR REPLACE TRIGGER "update_app_content_updated_at" BEFORE UPDATE ON "public"."app_content" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_food_preferences_updated_at" BEFORE UPDATE ON "public"."food_preferences" FOR EACH ROW EXECUTE FUNCTION "public"."update_food_preferences_updated_at"();



CREATE OR REPLACE TRIGGER "update_nutrition_plans_updated_at" BEFORE UPDATE ON "public"."nutrition_plans" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."activity_completions"
    ADD CONSTRAINT "activity_completions_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "public"."activities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_carb_loading_day_id_fkey" FOREIGN KEY ("carb_loading_day_id") REFERENCES "public"."carb_loading_days"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_carb_loading_food_id_fkey" FOREIGN KEY ("carb_loading_food_id") REFERENCES "public"."carb_loading_foods"("id");



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_carb_loading_user_food_id_fkey" FOREIGN KEY ("carb_loading_user_food_id") REFERENCES "public"."carb_loading_user_foods"("id");



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_meal_type_id_fkey" FOREIGN KEY ("meal_type_id") REFERENCES "public"."meal_types"("id");



ALTER TABLE ONLY "public"."carb_loading_days"
    ADD CONSTRAINT "carb_loading_days_carb_loading_plan_id_fkey" FOREIGN KEY ("carb_loading_plan_id") REFERENCES "public"."carb_loading_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_food_meal_types"
    ADD CONSTRAINT "carb_loading_food_meal_types_carb_loading_food_id_fkey" FOREIGN KEY ("carb_loading_food_id") REFERENCES "public"."carb_loading_foods"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_food_meal_types"
    ADD CONSTRAINT "carb_loading_food_meal_types_meal_type_id_fkey" FOREIGN KEY ("meal_type_id") REFERENCES "public"."meal_types"("id");



ALTER TABLE ONLY "public"."carb_loading_plans"
    ADD CONSTRAINT "carb_loading_plans_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_user_food_meal_types"
    ADD CONSTRAINT "carb_loading_user_food_meal_type_carb_loading_user_food_id_fkey" FOREIGN KEY ("carb_loading_user_food_id") REFERENCES "public"."carb_loading_user_foods"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_user_food_meal_types"
    ADD CONSTRAINT "carb_loading_user_food_meal_types_meal_type_id_fkey" FOREIGN KEY ("meal_type_id") REFERENCES "public"."meal_types"("id");



ALTER TABLE ONLY "public"."carb_loading_user_foods"
    ADD CONSTRAINT "carb_loading_user_foods_source_food_id_fkey" FOREIGN KEY ("source_food_id") REFERENCES "public"."foods"("id");



ALTER TABLE ONLY "public"."carb_loading_user_foods"
    ADD CONSTRAINT "carb_loading_user_foods_source_user_food_id_fkey" FOREIGN KEY ("source_user_food_id") REFERENCES "public"."user_foods"("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_activity_id_fkey" FOREIGN KEY ("activity_id") REFERENCES "public"."activities"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."nutrition_plans"
    ADD CONSTRAINT "fk_nutrition_plans_activity_id" FOREIGN KEY ("activity_id") REFERENCES "public"."activities"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."workout_notes"
    ADD CONSTRAINT "fk_workout_notes_user" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."food_categories"
    ADD CONSTRAINT "food_categories_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id");



ALTER TABLE ONLY "public"."food_categories"
    ADD CONSTRAINT "food_categories_food_id_fkey" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."food_preferences"
    ADD CONSTRAINT "food_preferences_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."users"("device_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."foods"
    ADD CONSTRAINT "foods_product_type_id_fkey" FOREIGN KEY ("product_type_id") REFERENCES "public"."product_types"("id");



ALTER TABLE ONLY "public"."nutrition_plans"
    ADD CONSTRAINT "nutrition_plans_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."users"("device_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_food_categories"
    ADD CONSTRAINT "user_food_categories_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "public"."categories"("id");



ALTER TABLE ONLY "public"."user_food_categories"
    ADD CONSTRAINT "user_food_categories_user_food_id_fkey" FOREIGN KEY ("user_food_id") REFERENCES "public"."user_foods"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_foods"
    ADD CONSTRAINT "user_foods_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."users"("device_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_foods"
    ADD CONSTRAINT "user_foods_product_type_id_fkey" FOREIGN KEY ("product_type_id") REFERENCES "public"."product_types"("id");



ALTER TABLE ONLY "public"."user_hidden_foods"
    ADD CONSTRAINT "user_hidden_global_foods_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."users"("device_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_hidden_foods"
    ADD CONSTRAINT "user_hidden_global_foods_food_id_fkey" FOREIGN KEY ("food_id") REFERENCES "public"."foods"("id") ON DELETE CASCADE;



CREATE POLICY "Allow all operations on feedback" ON "public"."feedback" USING (true);



CREATE POLICY "Allow all operations on food_preferences" ON "public"."food_preferences" USING (true) WITH CHECK (true);



CREATE POLICY "Allow authenticated insert to app_content" ON "public"."app_content" FOR INSERT WITH CHECK (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow authenticated update to app_content" ON "public"."app_content" FOR UPDATE USING (("auth"."role"() = 'authenticated'::"text"));



CREATE POLICY "Allow public read access to app_content" ON "public"."app_content" FOR SELECT USING (true);



CREATE POLICY "Anyone can read app_content" ON "public"."app_content" FOR SELECT USING (true);



CREATE POLICY "Anyone can read categories" ON "public"."categories" FOR SELECT USING (true);



CREATE POLICY "Anyone can read edge_functions" ON "public"."edge_functions" FOR SELECT USING (true);



CREATE POLICY "Anyone can read food_categories" ON "public"."food_categories" FOR SELECT USING (true);



CREATE POLICY "Anyone can read foods" ON "public"."foods" FOR SELECT USING (true);



CREATE POLICY "Dev: anon can modify app_content" ON "public"."app_content" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Dev: anon can modify edge_functions" ON "public"."edge_functions" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Dev: anon can modify food_categories" ON "public"."food_categories" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Dev: anon can modify foods" ON "public"."foods" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Users can delete own plans" ON "public"."nutrition_plans" FOR DELETE USING (true);



CREATE POLICY "Users can insert own data" ON "public"."users" FOR INSERT WITH CHECK (true);



CREATE POLICY "Users can insert own plans" ON "public"."nutrition_plans" FOR INSERT WITH CHECK (true);



CREATE POLICY "Users can read own data" ON "public"."users" FOR SELECT USING (true);



CREATE POLICY "Users can read own plans" ON "public"."nutrition_plans" FOR SELECT USING (true);



CREATE POLICY "Users can update own data" ON "public"."users" FOR UPDATE USING (true);



CREATE POLICY "Users can update own plans" ON "public"."nutrition_plans" FOR UPDATE USING (true);



ALTER TABLE "public"."activities" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "activities_delete_policy" ON "public"."activities" FOR DELETE USING (("user_id" = "current_setting"('app.user_id'::"text", true)));



CREATE POLICY "activities_insert_policy" ON "public"."activities" FOR INSERT WITH CHECK (("user_id" = "current_setting"('app.user_id'::"text", true)));



CREATE POLICY "activities_select_policy" ON "public"."activities" FOR SELECT USING (("user_id" = "current_setting"('app.user_id'::"text", true)));



CREATE POLICY "activities_update_policy" ON "public"."activities" FOR UPDATE USING (("user_id" = "current_setting"('app.user_id'::"text", true)));



ALTER TABLE "public"."activity_completions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "activity_completions_delete_policy" ON "public"."activity_completions" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."activities"
  WHERE (("activities"."id" = "activity_completions"."activity_id") AND ("activities"."user_id" = "current_setting"('app.user_id'::"text", true))))));



CREATE POLICY "activity_completions_insert_policy" ON "public"."activity_completions" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."activities"
  WHERE (("activities"."id" = "activity_completions"."activity_id") AND ("activities"."user_id" = "current_setting"('app.user_id'::"text", true))))));



CREATE POLICY "activity_completions_select_policy" ON "public"."activity_completions" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."activities"
  WHERE (("activities"."id" = "activity_completions"."activity_id") AND ("activities"."user_id" = "current_setting"('app.user_id'::"text", true))))));



CREATE POLICY "activity_completions_update_policy" ON "public"."activity_completions" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."activities"
  WHERE (("activities"."id" = "activity_completions"."activity_id") AND ("activities"."user_id" = "current_setting"('app.user_id'::"text", true))))));



ALTER TABLE "public"."app_content" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "carb_days_delete_policy" ON "public"."carb_loading_days" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."carb_loading_plans"
  WHERE (("carb_loading_plans"."id" = "carb_loading_days"."carb_loading_plan_id") AND ("carb_loading_plans"."user_id" = "current_setting"('app.user_id'::"text", true))))));



CREATE POLICY "carb_days_insert_policy" ON "public"."carb_loading_days" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."carb_loading_plans"
  WHERE (("carb_loading_plans"."id" = "carb_loading_days"."carb_loading_plan_id") AND ("carb_loading_plans"."user_id" = "current_setting"('app.user_id'::"text", true))))));



CREATE POLICY "carb_days_select_policy" ON "public"."carb_loading_days" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."carb_loading_plans"
  WHERE (("carb_loading_plans"."id" = "carb_loading_days"."carb_loading_plan_id") AND ("carb_loading_plans"."user_id" = "current_setting"('app.user_id'::"text", true))))));



CREATE POLICY "carb_days_update_policy" ON "public"."carb_loading_days" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."carb_loading_plans"
  WHERE (("carb_loading_plans"."id" = "carb_loading_days"."carb_loading_plan_id") AND ("carb_loading_plans"."user_id" = "current_setting"('app.user_id'::"text", true))))));



ALTER TABLE "public"."carb_loading_day_meals" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "carb_loading_day_meals_device_delete" ON "public"."carb_loading_day_meals" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM ("public"."carb_loading_days" "d"
     JOIN "public"."carb_loading_plans" "p" ON (("p"."id" = "d"."carb_loading_plan_id")))
  WHERE (("d"."id" = "carb_loading_day_meals"."carb_loading_day_id") AND ("p"."user_id" = "current_setting"('app.device_id'::"text", true))))));



CREATE POLICY "carb_loading_day_meals_device_insert" ON "public"."carb_loading_day_meals" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM ("public"."carb_loading_days" "d"
     JOIN "public"."carb_loading_plans" "p" ON (("p"."id" = "d"."carb_loading_plan_id")))
  WHERE (("d"."id" = "carb_loading_day_meals"."carb_loading_day_id") AND ("p"."user_id" = "current_setting"('app.device_id'::"text", true))))));



CREATE POLICY "carb_loading_day_meals_device_read" ON "public"."carb_loading_day_meals" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM ("public"."carb_loading_days" "d"
     JOIN "public"."carb_loading_plans" "p" ON (("p"."id" = "d"."carb_loading_plan_id")))
  WHERE (("d"."id" = "carb_loading_day_meals"."carb_loading_day_id") AND ("p"."user_id" = "current_setting"('app.device_id'::"text", true))))));



CREATE POLICY "carb_loading_day_meals_device_update" ON "public"."carb_loading_day_meals" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM ("public"."carb_loading_days" "d"
     JOIN "public"."carb_loading_plans" "p" ON (("p"."id" = "d"."carb_loading_plan_id")))
  WHERE (("d"."id" = "carb_loading_day_meals"."carb_loading_day_id") AND ("p"."user_id" = "current_setting"('app.device_id'::"text", true))))));



ALTER TABLE "public"."carb_loading_days" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."carb_loading_food_meal_types" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "carb_loading_food_meal_types_public_read" ON "public"."carb_loading_food_meal_types" FOR SELECT USING (true);



ALTER TABLE "public"."carb_loading_foods" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "carb_loading_foods_public_read" ON "public"."carb_loading_foods" FOR SELECT USING (true);



ALTER TABLE "public"."carb_loading_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."carb_loading_user_food_meal_types" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "carb_loading_user_food_meal_types_device_delete" ON "public"."carb_loading_user_food_meal_types" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."carb_loading_user_foods"
  WHERE (("carb_loading_user_foods"."id" = "carb_loading_user_food_meal_types"."carb_loading_user_food_id") AND ("carb_loading_user_foods"."device_id" = "current_setting"('app.device_id'::"text", true))))));



CREATE POLICY "carb_loading_user_food_meal_types_device_insert" ON "public"."carb_loading_user_food_meal_types" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."carb_loading_user_foods"
  WHERE (("carb_loading_user_foods"."id" = "carb_loading_user_food_meal_types"."carb_loading_user_food_id") AND ("carb_loading_user_foods"."device_id" = "current_setting"('app.device_id'::"text", true))))));



CREATE POLICY "carb_loading_user_food_meal_types_device_read" ON "public"."carb_loading_user_food_meal_types" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."carb_loading_user_foods"
  WHERE (("carb_loading_user_foods"."id" = "carb_loading_user_food_meal_types"."carb_loading_user_food_id") AND ("carb_loading_user_foods"."device_id" = "current_setting"('app.device_id'::"text", true))))));



ALTER TABLE "public"."carb_loading_user_foods" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "carb_loading_user_foods_device_delete" ON "public"."carb_loading_user_foods" FOR DELETE USING (("device_id" = "current_setting"('app.device_id'::"text", true)));



CREATE POLICY "carb_loading_user_foods_device_insert" ON "public"."carb_loading_user_foods" FOR INSERT WITH CHECK (("device_id" = "current_setting"('app.device_id'::"text", true)));



CREATE POLICY "carb_loading_user_foods_device_read" ON "public"."carb_loading_user_foods" FOR SELECT USING (("device_id" = "current_setting"('app.device_id'::"text", true)));



CREATE POLICY "carb_loading_user_foods_device_update" ON "public"."carb_loading_user_foods" FOR UPDATE USING (("device_id" = "current_setting"('app.device_id'::"text", true)));



CREATE POLICY "carb_plans_delete_policy" ON "public"."carb_loading_plans" FOR DELETE USING (("user_id" = "current_setting"('app.user_id'::"text", true)));



CREATE POLICY "carb_plans_insert_policy" ON "public"."carb_loading_plans" FOR INSERT WITH CHECK (("user_id" = "current_setting"('app.user_id'::"text", true)));



CREATE POLICY "carb_plans_select_policy" ON "public"."carb_loading_plans" FOR SELECT USING (("user_id" = "current_setting"('app.user_id'::"text", true)));



CREATE POLICY "carb_plans_update_policy" ON "public"."carb_loading_plans" FOR UPDATE USING (("user_id" = "current_setting"('app.user_id'::"text", true)));



ALTER TABLE "public"."events" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "events_delete_policy" ON "public"."events" FOR DELETE USING ((EXISTS ( SELECT 1
   FROM "public"."activities"
  WHERE (("activities"."id" = "events"."activity_id") AND ("activities"."user_id" = "current_setting"('app.user_id'::"text", true))))));



CREATE POLICY "events_insert_policy" ON "public"."events" FOR INSERT WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."activities"
  WHERE (("activities"."id" = "events"."activity_id") AND ("activities"."user_id" = "current_setting"('app.user_id'::"text", true))))));



CREATE POLICY "events_select_policy" ON "public"."events" FOR SELECT USING ((EXISTS ( SELECT 1
   FROM "public"."activities"
  WHERE (("activities"."id" = "events"."activity_id") AND ("activities"."user_id" = "current_setting"('app.user_id'::"text", true))))));



CREATE POLICY "events_update_policy" ON "public"."events" FOR UPDATE USING ((EXISTS ( SELECT 1
   FROM "public"."activities"
  WHERE (("activities"."id" = "events"."activity_id") AND ("activities"."user_id" = "current_setting"('app.user_id'::"text", true))))));



ALTER TABLE "public"."feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."food_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."foods" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "macro_targets_authenticated_insert" ON "public"."macro_targets_table" FOR INSERT WITH CHECK (true);



CREATE POLICY "macro_targets_authenticated_update" ON "public"."macro_targets_table" FOR UPDATE USING (true);



CREATE POLICY "macro_targets_public_read" ON "public"."macro_targets_table" FOR SELECT USING (true);



ALTER TABLE "public"."macro_targets_table" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."meal_types" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "meal_types_public_read" ON "public"."meal_types" FOR SELECT USING (true);



ALTER TABLE "public"."nutrition_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."workout_notes" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "workout_notes_user_delete" ON "public"."workout_notes" FOR DELETE USING (("user_id" = ("current_setting"('app.user_id'::"text", true))::"uuid"));



CREATE POLICY "workout_notes_user_insert" ON "public"."workout_notes" FOR INSERT WITH CHECK (("user_id" = ("current_setting"('app.user_id'::"text", true))::"uuid"));



CREATE POLICY "workout_notes_user_read" ON "public"."workout_notes" FOR SELECT USING (("user_id" = ("current_setting"('app.user_id'::"text", true))::"uuid"));



CREATE POLICY "workout_notes_user_update" ON "public"."workout_notes" FOR UPDATE USING (("user_id" = ("current_setting"('app.user_id'::"text", true))::"uuid"));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_by_device_plan_id"("p_device_id" "text", "p_plan_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_by_device_plan_id"("p_device_id" "text", "p_plan_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_by_device_plan_id"("p_device_id" "text", "p_plan_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_client_version" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_client_version" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_client_version" integer) TO "service_role";



GRANT ALL ON TABLE "public"."nutrition_plans" TO "anon";
GRANT ALL ON TABLE "public"."nutrition_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."nutrition_plans" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_latest_nutrition_plan"("p_device_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_latest_nutrition_plan"("p_device_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_latest_nutrition_plan"("p_device_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_latest_nutrition_plan_by_device_id"("p_device_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_latest_nutrition_plan_by_device_id"("p_device_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_latest_nutrition_plan_by_device_id"("p_device_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."get_nutrition_plans_by_device_id"("p_device_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_nutrition_plans_by_device_id"("p_device_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_nutrition_plans_by_device_id"("p_device_id" "text") TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";



GRANT ALL ON FUNCTION "public"."get_user_by_device_id"("p_device_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."get_user_by_device_id"("p_device_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_user_by_device_id"("p_device_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_food_preferences_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_food_preferences_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_food_preferences_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_food_preferences"("p_device_id" "text", "p_preferences" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_food_preferences"("p_device_id" "text", "p_preferences" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_food_preferences"("p_device_id" "text", "p_preferences" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_data" "jsonb", "p_distance_miles" numeric, "p_pace_minutes_per_mile" numeric) TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_data" "jsonb", "p_distance_miles" numeric, "p_pace_minutes_per_mile" numeric) TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan"("p_device_id" "text", "p_plan_data" "jsonb", "p_distance_miles" numeric, "p_pace_minutes_per_mile" numeric) TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb", "p_client_version" integer, "p_client_updated_at" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb", "p_client_version" integer, "p_client_updated_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb", "p_client_version" integer, "p_client_updated_at" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_user_by_device_id"("p_device_id" "text", "p_user_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_user_by_device_id"("p_device_id" "text", "p_user_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_user_by_device_id"("p_device_id" "text", "p_user_data" "jsonb") TO "service_role";


















GRANT ALL ON TABLE "public"."activities" TO "anon";
GRANT ALL ON TABLE "public"."activities" TO "authenticated";
GRANT ALL ON TABLE "public"."activities" TO "service_role";



GRANT ALL ON TABLE "public"."activity_completions" TO "anon";
GRANT ALL ON TABLE "public"."activity_completions" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_completions" TO "service_role";



GRANT ALL ON TABLE "public"."app_content" TO "anon";
GRANT ALL ON TABLE "public"."app_content" TO "authenticated";
GRANT ALL ON TABLE "public"."app_content" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_day_meals" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_day_meals" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_day_meals" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_days" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_days" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_days" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_food_meal_types" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_food_meal_types" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_food_meal_types" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_foods" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_foods" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_foods" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_plans" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_plans" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_user_food_meal_types" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_user_food_meal_types" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_user_food_meal_types" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_user_foods" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_user_foods" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_user_foods" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."current_content" TO "anon";
GRANT ALL ON TABLE "public"."current_content" TO "authenticated";
GRANT ALL ON TABLE "public"."current_content" TO "service_role";



GRANT ALL ON TABLE "public"."edge_functions" TO "anon";
GRANT ALL ON TABLE "public"."edge_functions" TO "authenticated";
GRANT ALL ON TABLE "public"."edge_functions" TO "service_role";



GRANT ALL ON TABLE "public"."events" TO "anon";
GRANT ALL ON TABLE "public"."events" TO "authenticated";
GRANT ALL ON TABLE "public"."events" TO "service_role";



GRANT ALL ON TABLE "public"."feedback" TO "anon";
GRANT ALL ON TABLE "public"."feedback" TO "authenticated";
GRANT ALL ON TABLE "public"."feedback" TO "service_role";



GRANT ALL ON TABLE "public"."food_categories" TO "anon";
GRANT ALL ON TABLE "public"."food_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."food_categories" TO "service_role";



GRANT ALL ON TABLE "public"."food_preferences" TO "anon";
GRANT ALL ON TABLE "public"."food_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."food_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."foods" TO "anon";
GRANT ALL ON TABLE "public"."foods" TO "authenticated";
GRANT ALL ON TABLE "public"."foods" TO "service_role";



GRANT ALL ON TABLE "public"."macro_targets_table" TO "anon";
GRANT ALL ON TABLE "public"."macro_targets_table" TO "authenticated";
GRANT ALL ON TABLE "public"."macro_targets_table" TO "service_role";



GRANT ALL ON TABLE "public"."meal_types" TO "anon";
GRANT ALL ON TABLE "public"."meal_types" TO "authenticated";
GRANT ALL ON TABLE "public"."meal_types" TO "service_role";



GRANT ALL ON TABLE "public"."product_types" TO "anon";
GRANT ALL ON TABLE "public"."product_types" TO "authenticated";
GRANT ALL ON TABLE "public"."product_types" TO "service_role";



GRANT ALL ON TABLE "public"."user_food_categories" TO "anon";
GRANT ALL ON TABLE "public"."user_food_categories" TO "authenticated";
GRANT ALL ON TABLE "public"."user_food_categories" TO "service_role";



GRANT ALL ON TABLE "public"."user_foods" TO "anon";
GRANT ALL ON TABLE "public"."user_foods" TO "authenticated";
GRANT ALL ON TABLE "public"."user_foods" TO "service_role";



GRANT ALL ON TABLE "public"."user_hidden_foods" TO "anon";
GRANT ALL ON TABLE "public"."user_hidden_foods" TO "authenticated";
GRANT ALL ON TABLE "public"."user_hidden_foods" TO "service_role";



GRANT ALL ON TABLE "public"."workout_notes" TO "anon";
GRANT ALL ON TABLE "public"."workout_notes" TO "authenticated";
GRANT ALL ON TABLE "public"."workout_notes" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































