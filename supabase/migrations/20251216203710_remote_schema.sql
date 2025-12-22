

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






CREATE EXTENSION IF NOT EXISTS "pg_trgm" WITH SCHEMA "public";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE TYPE "public"."activity_status_enum" AS ENUM (
    'planned',
    'in_progress',
    'completed',
    'skipped'
);


ALTER TYPE "public"."activity_status_enum" OWNER TO "postgres";


CREATE TYPE "public"."activity_type_enum" AS ENUM (
    'running',
    'cycling',
    'swimming',
    'triathlon',
    'duathlon',
    'multisport'
);


ALTER TYPE "public"."activity_type_enum" OWNER TO "postgres";


CREATE TYPE "public"."allergy_enum" AS ENUM (
    'dairy',
    'eggs',
    'fish',
    'gluten',
    'peanuts',
    'sesame',
    'shellfish',
    'soy',
    'tree_nuts'
);


ALTER TYPE "public"."allergy_enum" OWNER TO "postgres";


COMMENT ON TYPE "public"."allergy_enum" IS 'Common food allergens for user allergy tracking';



CREATE TYPE "public"."auth_provider_enum" AS ENUM (
    'anonymous',
    'email',
    'google',
    'apple'
);


ALTER TYPE "public"."auth_provider_enum" OWNER TO "postgres";


CREATE TYPE "public"."category_enum" AS ENUM (
    'before_run',
    'during_run',
    'after_run'
);


ALTER TYPE "public"."category_enum" OWNER TO "postgres";


CREATE TYPE "public"."cycling_goal_enum" AS ENUM (
    'endurance',
    'tempo',
    'intervals'
);


ALTER TYPE "public"."cycling_goal_enum" OWNER TO "postgres";


CREATE TYPE "public"."cycling_terrain_enum" AS ENUM (
    'flat',
    'rolling',
    'hilly'
);


ALTER TYPE "public"."cycling_terrain_enum" OWNER TO "postgres";


CREATE TYPE "public"."dietary_preference_enum" AS ENUM (
    'omnivore',
    'vegetarian',
    'pescatarian',
    'vegan',
    'mediterranean',
    'paleo',
    'keto',
    'low_carb'
);


ALTER TYPE "public"."dietary_preference_enum" OWNER TO "postgres";


COMMENT ON TYPE "public"."dietary_preference_enum" IS 'User dietary preference options for food filtering';



CREATE TYPE "public"."distance_unit_enum" AS ENUM (
    'miles',
    'kilometers'
);


ALTER TYPE "public"."distance_unit_enum" OWNER TO "postgres";


CREATE TYPE "public"."event_subtype_enum" AS ENUM (
    '5k',
    '10k',
    '15k',
    '10_mile',
    'half_marathon',
    '25k',
    '30k',
    'marathon',
    'ultra_50k',
    'ultra_50m',
    'ultra_100k',
    'ultra_100m',
    'ultra_12h',
    'ultra_24h',
    '20k',
    '40k_tt',
    '50k',
    'half_century',
    'metric_century',
    'century',
    'gran_fondo',
    '200k',
    '1k',
    '1.5k',
    '2.5k',
    'sprint',
    'olympic',
    'half_ironman',
    'ironman',
    'standard',
    'long_course',
    'aquathlon',
    'aquabike',
    'custom'
);


ALTER TYPE "public"."event_subtype_enum" OWNER TO "postgres";


CREATE TYPE "public"."gender_enum" AS ENUM (
    'male',
    'female',
    'other',
    'unknown'
);


ALTER TYPE "public"."gender_enum" OWNER TO "postgres";


CREATE TYPE "public"."gut_training_enum" AS ENUM (
    'low',
    'moderate',
    'high'
);


ALTER TYPE "public"."gut_training_enum" OWNER TO "postgres";


CREATE TYPE "public"."indoor_outdoor_enum" AS ENUM (
    'indoor',
    'outdoor'
);


ALTER TYPE "public"."indoor_outdoor_enum" OWNER TO "postgres";


CREATE TYPE "public"."intensity_enum" AS ENUM (
    'easy',
    'moderate',
    'hard',
    'race'
);


ALTER TYPE "public"."intensity_enum" OWNER TO "postgres";


CREATE TYPE "public"."pace_unit_enum" AS ENUM (
    'min_per_mile',
    'min_per_km'
);


ALTER TYPE "public"."pace_unit_enum" OWNER TO "postgres";


CREATE TYPE "public"."plan_type_enum" AS ENUM (
    'standard',
    'carb_loading',
    'recovery'
);


ALTER TYPE "public"."plan_type_enum" OWNER TO "postgres";


CREATE TYPE "public"."product_type_enum" AS ENUM (
    'bar',
    'capsule',
    'chew',
    'drink_mix',
    'electrolyte_only',
    'electrolytes_fluids',
    'gel',
    'hydration_with_carbs',
    'import',
    'protein_recovery',
    'quick_carbs',
    'real_food',
    'real_food_carbs',
    'recovery_shake',
    'solid_carb_snacks',
    'sports_drink',
    'waffle'
);


ALTER TYPE "public"."product_type_enum" OWNER TO "postgres";


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


CREATE OR REPLACE FUNCTION "public"."search_public_events_hybrid"("search_term" "text", "limit_count" integer DEFAULT 20, "event_type_filter" "text" DEFAULT NULL::"text", "state_filter" "text" DEFAULT NULL::"text", "min_similarity" double precision DEFAULT 0.2) RETURNS TABLE("id" bigint, "event_name" "text", "event_type" "text", "event_subtype" "text", "location" "text", "city" "text", "state" "text", "country" "text", "event_date" "date", "start_time" time without time zone, "registration_url" "text", "website_url" "text", "description" "text", "organizer_name" "text", "match_type" "text", "relevance_score" real)
    LANGUAGE "plpgsql" STABLE
    AS $$
DECLARE
  fts_query TEXT;
  today_date DATE := CURRENT_DATE;
BEGIN
  -- Convert search term to tsquery (handle special characters)
  fts_query := websearch_to_tsquery('english', search_term)::text;

  -- Return combined results from both full-text and fuzzy search
  RETURN QUERY
  WITH fts_matches AS (
    -- Full-text search using the existing search_vector
    SELECT
      e.id,
      e.event_name,
      e.event_type::TEXT,
      e.event_subtype::TEXT,
      e.location,
      e.city,
      e.state,
      e.country,
      e.event_date,
      e.start_time,
      e.registration_url,
      e.website_url,
      e.description,
      e.organizer_name,
      'exact'::TEXT AS match_type,
      -- Weighted ranking: event_name weighted highest
      ts_rank_cd(
        '{0.1, 0.2, 0.4, 1.0}',
        e.search_vector,
        websearch_to_tsquery('english', search_term)
      )::REAL AS relevance_score
    FROM public.public_events e
    WHERE
      e.is_active = true
      AND e.event_date >= today_date
      AND e.search_vector @@ websearch_to_tsquery('english', search_term)
      -- Apply optional filters
      AND (event_type_filter IS NULL OR e.event_type::TEXT = event_type_filter)
      AND (state_filter IS NULL OR e.state ILIKE state_filter)
  ),
  fuzzy_matches AS (
    -- Fuzzy matching using pg_trgm similarity for typo tolerance
    SELECT
      e.id,
      e.event_name,
      e.event_type::TEXT,
      e.event_subtype::TEXT,
      e.location,
      e.city,
      e.state,
      e.country,
      e.event_date,
      e.start_time,
      e.registration_url,
      e.website_url,
      e.description,
      e.organizer_name,
      'fuzzy'::TEXT AS match_type,
      -- Combined similarity score (event_name weighted 60%, city 40%)
      (
        0.6 * similarity(e.event_name, search_term) +
        0.4 * COALESCE(similarity(e.city, search_term), 0)
      )::REAL AS relevance_score
    FROM public.public_events e
    WHERE
      e.is_active = true
      AND e.event_date >= today_date
      -- Use similarity operator (%) for fuzzy matching
      AND (
        e.event_name % search_term
        OR e.city % search_term
        OR COALESCE(e.location, '') % search_term
      )
      -- Exclude events already found by FTS (FIXED: fully qualified column name)
      AND NOT EXISTS (
        SELECT 1 FROM fts_matches fm WHERE fm.id = e.id
      )
      -- Apply optional filters
      AND (event_type_filter IS NULL OR e.event_type::TEXT = event_type_filter)
      AND (state_filter IS NULL OR e.state ILIKE state_filter)
      -- Only include results above similarity threshold
      AND (
        similarity(e.event_name, search_term) >= min_similarity
        OR similarity(COALESCE(e.city, ''), search_term) >= min_similarity
        OR similarity(COALESCE(e.location, ''), search_term) >= min_similarity
      )
  ),
  combined_results AS (
    -- Combine both result sets
    SELECT * FROM fts_matches
    UNION ALL
    SELECT * FROM fuzzy_matches
  )
  -- Return sorted by relevance score (highest first), then by event date (nearest first)
  SELECT * FROM combined_results
  ORDER BY relevance_score DESC, event_date ASC
  LIMIT limit_count;
END;
$$;


ALTER FUNCTION "public"."search_public_events_hybrid"("search_term" "text", "limit_count" integer, "event_type_filter" "text", "state_filter" "text", "min_similarity" double precision) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."search_public_events_hybrid"("search_term" "text", "limit_count" integer, "event_type_filter" "text", "state_filter" "text", "min_similarity" double precision) IS 'Hybrid search function combining full-text search (exact matches) with fuzzy matching (typo tolerance).
Returns results ranked by relevance score with match_type indicator (exact/fuzzy).
Fixed: Column reference ambiguity in NOT IN clause.
Parameters:
- search_term: Query string (e.g., "Boston Marathon")
- limit_count: Max results to return (default: 20)
- event_type_filter: Optional activity type filter (e.g., "running")
- state_filter: Optional state filter (e.g., "MA")
- min_similarity: Minimum fuzzy match threshold 0-1 (default: 0.2)';



CREATE OR REPLACE FUNCTION "public"."update_auth_sessions_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."update_auth_sessions_updated_at"() OWNER TO "postgres";


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
      NEW.updated_at = now();
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

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."activities" (
    "title" "text" NOT NULL,
    "scheduled_date_time" timestamp without time zone NOT NULL,
    "status" "public"."activity_status_enum" DEFAULT 'planned'::"public"."activity_status_enum",
    "distance_miles" real,
    "duration_minutes" integer,
    "pace_target_minutes_per_mile" real,
    "intensity_level" "public"."intensity_enum",
    "completed_at" timestamp without time zone,
    "completion_rating" integer,
    "completion_notes" "text",
    "actual_distance_miles" real,
    "actual_duration_minutes" integer,
    "notes" "text",
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "deleted_at" timestamp without time zone,
    "cycling_power_watts" integer,
    "cycling_ftp_watts" integer,
    "cycling_speed_mph" real,
    "cycling_terrain" "public"."cycling_terrain_enum",
    "cycling_indoor_outdoor" "public"."indoor_outdoor_enum",
    "cycling_elevation_gain_ft" integer,
    "cycling_session_goal" "public"."cycling_goal_enum",
    "swimming_speed_per_100m" integer,
    "swimming_css_seconds_per_100m" integer,
    "swimming_pace_per_100m_seconds" integer,
    "swimming_pool_or_open_water" "text",
    "swimming_water_temp_c" real,
    "intensity_target" "text",
    "time_before_minutes" integer,
    "user_id" "uuid" NOT NULL,
    "id" bigint NOT NULL,
    "nutrition_plan_data" "jsonb",
    "completion_type" "text" DEFAULT 'manual'::"text",
    "average_pace_minutes_per_mile" double precision,
    "max_heart_rate" integer,
    "average_heart_rate" integer,
    "calories_burned" integer,
    "effort_rating" integer,
    "nutrition_rating" integer,
    "overall_satisfaction" integer,
    "voice_note_id" "text",
    "has_voice_recording" boolean DEFAULT false,
    "weather_conditions" "text",
    "temperature_fahrenheit" integer,
    "humidity_percent" integer,
    "nutrition_adherence_score" double precision,
    "performance_vs_target" double precision,
    "activity_type" "public"."activity_type_enum" NOT NULL,
    CONSTRAINT "activities_swimming_pool_or_open_water_check" CHECK ((("swimming_pool_or_open_water" IS NULL) OR ("swimming_pool_or_open_water" = ANY (ARRAY['pool'::"text", 'open_water'::"text"])))),
    CONSTRAINT "rating_check" CHECK ((("completion_rating" IS NULL) OR (("completion_rating" >= 1) AND ("completion_rating" <= 5))))
);


ALTER TABLE "public"."activities" OWNER TO "postgres";


COMMENT ON TABLE "public"."activities" IS 'All calendar entries including workouts and events';



COMMENT ON COLUMN "public"."activities"."status" IS 'Current status: planned, in_progress, completed, skipped';



COMMENT ON COLUMN "public"."activities"."cycling_power_watts" IS 'Average power output in watts for cycling activities';



COMMENT ON COLUMN "public"."activities"."cycling_ftp_watts" IS 'Functional Threshold Power in watts (if known)';



COMMENT ON COLUMN "public"."activities"."cycling_speed_mph" IS 'Average cycling speed in miles per hour';



COMMENT ON COLUMN "public"."activities"."cycling_terrain" IS 'Terrain type: flat, rolling, or hilly';



COMMENT ON COLUMN "public"."activities"."cycling_indoor_outdoor" IS 'Indoor (trainer) or outdoor cycling';



COMMENT ON COLUMN "public"."activities"."cycling_elevation_gain_ft" IS 'Total elevation gain in feet';



COMMENT ON COLUMN "public"."activities"."cycling_session_goal" IS 'Session type: endurance, tempo, or intervals';



COMMENT ON COLUMN "public"."activities"."swimming_speed_per_100m" IS 'Average pace in seconds per 100 meters for swimming';



COMMENT ON COLUMN "public"."activities"."swimming_css_seconds_per_100m" IS 'Critical Swim Speed in seconds per 100m (if known)';



COMMENT ON COLUMN "public"."activities"."swimming_pace_per_100m_seconds" IS 'Swimming pace in seconds per 100 meters';



COMMENT ON COLUMN "public"."activities"."swimming_pool_or_open_water" IS 'Pool or open water swimming';



COMMENT ON COLUMN "public"."activities"."swimming_water_temp_c" IS 'Water temperature in Celsius';



COMMENT ON COLUMN "public"."activities"."intensity_target" IS 'Intensity target (zone_1, zone_2, rpe_3, etc.) - works across all sports';



COMMENT ON COLUMN "public"."activities"."time_before_minutes" IS 'Pre-activity timing window in minutes (replaces run-specific pre_run_timing)';



COMMENT ON COLUMN "public"."activities"."nutrition_plan_data" IS 'Full JSON payload for the nutrition plan (before/during/after sections, macro targets, notes)';



COMMENT ON COLUMN "public"."activities"."activity_type" IS 'Sport category using shared activity_type enum: running, cycling, swimming, triathlon, duathlon, multisport';



CREATE SEQUENCE IF NOT EXISTS "public"."activities_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."activities_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."activities_id_seq" OWNED BY "public"."activities"."id";



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
    "carb_loading_food_id" "uuid",
    "carb_loading_user_food_id" "uuid",
    "food_display_name" "text",
    "quantity" integer DEFAULT 1,
    "carbs_consumed" real NOT NULL,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "meal_type" "text" NOT NULL,
    "carb_loading_plan_id" bigint NOT NULL,
    "carb_loading_day_id" bigint,
    CONSTRAINT "carbs_positive" CHECK (("carbs_consumed" >= (0)::double precision)),
    CONSTRAINT "one_food_type" CHECK (((("carb_loading_food_id" IS NOT NULL) AND ("carb_loading_user_food_id" IS NULL)) OR (("carb_loading_food_id" IS NULL) AND ("carb_loading_user_food_id" IS NOT NULL)))),
    CONSTRAINT "quantity_positive" CHECK (("quantity" > 0))
);


ALTER TABLE "public"."carb_loading_day_meals" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."carb_loading_days" (
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
    "carb_loading_plan_id" bigint,
    "id" bigint NOT NULL,
    "local_updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "needs_upload" boolean DEFAULT false,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "carb_target_check" CHECK (("carb_target_grams" > 0)),
    CONSTRAINT "day_number_check" CHECK (("day_number" > 0)),
    CONSTRAINT "meal_count_check" CHECK (("meal_count" > 0))
);


ALTER TABLE "public"."carb_loading_days" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."carb_loading_days_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."carb_loading_days_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."carb_loading_days_id_seq" OWNED BY "public"."carb_loading_days"."id";



CREATE TABLE IF NOT EXISTS "public"."carb_loading_foods" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "display_name" "text" NOT NULL,
    "display_name_plural" "text",
    "carbs_per_serving" real NOT NULL,
    "image_address" "text",
    "is_default" boolean DEFAULT true,
    "created_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "meal_types" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "carbs_positive" CHECK (("carbs_per_serving" > (0)::double precision))
);


ALTER TABLE "public"."carb_loading_foods" OWNER TO "postgres";


COMMENT ON TABLE "public"."carb_loading_foods" IS 'Global default carb loading foods';



CREATE TABLE IF NOT EXISTS "public"."carb_loading_plans" (
    "total_days" integer NOT NULL,
    "start_date" timestamp without time zone NOT NULL,
    "end_date" timestamp without time zone NOT NULL,
    "daily_carb_target_grams" integer NOT NULL,
    "daily_calorie_target" integer,
    "generated_at" timestamp without time zone NOT NULL,
    "algorithm_version" "text" DEFAULT 'v1.0'::"text",
    "adherence_score" real,
    "completed_at" timestamp without time zone,
    "user_id" "uuid" NOT NULL,
    "event_id" bigint,
    "id" bigint NOT NULL,
    "needs_upload" boolean DEFAULT false,
    "local_updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    CONSTRAINT "adherence_check" CHECK ((("adherence_score" IS NULL) OR (("adherence_score" >= (0.0)::double precision) AND ("adherence_score" <= (1.0)::double precision)))),
    CONSTRAINT "total_days_check" CHECK (("total_days" = ANY (ARRAY[1, 2, 3, 7])))
);


ALTER TABLE "public"."carb_loading_plans" OWNER TO "postgres";


COMMENT ON TABLE "public"."carb_loading_plans" IS 'Carb loading plans linked to specific events';



CREATE SEQUENCE IF NOT EXISTS "public"."carb_loading_plans_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."carb_loading_plans_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."carb_loading_plans_id_seq" OWNED BY "public"."carb_loading_plans"."id";



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
    "meal_types" "text"[] DEFAULT '{}'::"text"[] NOT NULL,
    "user_id" "uuid" NOT NULL,
    CONSTRAINT "carbs_positive" CHECK (("carbs_per_serving" > (0)::double precision))
);


ALTER TABLE "public"."carb_loading_user_foods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."events" (
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
    "user_id" "uuid" NOT NULL,
    "activity_id" bigint,
    "id" bigint NOT NULL,
    "event_subtype" "public"."event_subtype_enum",
    "event_type" "public"."activity_type_enum" NOT NULL,
    "event_date" "date",
    "needs_upload" boolean DEFAULT false,
    "local_updated_at" timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "carb_days_check" CHECK ((("carb_loading_days" IS NULL) OR ("carb_loading_days" = ANY (ARRAY[1, 2, 3, 7]))))
);


ALTER TABLE "public"."events" OWNER TO "postgres";


COMMENT ON TABLE "public"."events" IS 'Specialized event data for races and competitions';



COMMENT ON COLUMN "public"."events"."has_carb_loading" IS 'Whether this event has an associated carb loading plan';



COMMENT ON COLUMN "public"."events"."has_nutrition_plan" IS 'Indicates whether this event has an associated nutrition plan';



COMMENT ON COLUMN "public"."events"."event_subtype" IS 'Race distance/type: marathon, half_marathon, 10k, 5k, sprint, olympic, etc.';



COMMENT ON COLUMN "public"."events"."event_type" IS 'Sport category using shared activity_type enum: running, cycling, swimming, triathlon, duathlon, multisport';



COMMENT ON COLUMN "public"."events"."event_date" IS 'Date of the event (DATE type). Use this for calendar displays and date-based queries. start_time remains for precise race start timestamps.';



CREATE SEQUENCE IF NOT EXISTS "public"."events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."events_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."events_id_seq" OWNED BY "public"."events"."id";



CREATE TABLE IF NOT EXISTS "public"."feature_survey_responses" (
    "id" bigint NOT NULL,
    "user_id" "uuid" NOT NULL,
    "selected_features" "text" NOT NULL,
    "voted_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."feature_survey_responses" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."feature_survey_responses_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."feature_survey_responses_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."feature_survey_responses_id_seq" OWNED BY "public"."feature_survey_responses"."id";



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


CREATE TABLE IF NOT EXISTS "public"."food_preferences" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "food_name" "text" NOT NULL,
    "preference" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "preference_level" smallint DEFAULT 2 NOT NULL,
    CONSTRAINT "food_preferences_preference_check" CHECK (("preference" = ANY (ARRAY['like'::"text", 'dislike'::"text", 'willing_to_try'::"text"])))
);


ALTER TABLE "public"."food_preferences" OWNER TO "postgres";


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
    "description" "text",
    "serving_description" "text",
    "serving_size" character varying(50),
    "is_essential" boolean DEFAULT false,
    "is_other_food" boolean,
    "instructions" "text",
    "nutritional_info" "text",
    "serving_unit" "text",
    "serving_unit_plural" "text",
    "serving_qualifier" "text",
    "purchase_url" "text",
    "affiliate_source" "text",
    "preference_priority" integer,
    "categories" "public"."category_enum"[] DEFAULT '{}'::"public"."category_enum"[] NOT NULL,
    "product_type" "public"."product_type_enum",
    "activity_types" "public"."activity_type_enum"[],
    "before_run_suitable" boolean DEFAULT false,
    "during_run_suitable" boolean DEFAULT false,
    "after_run_suitable" boolean DEFAULT false,
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "allergens" "public"."allergy_enum"[] DEFAULT '{}'::"public"."allergy_enum"[],
    "excluded_diets" "public"."dietary_preference_enum"[] DEFAULT '{}'::"public"."dietary_preference_enum"[]
);


ALTER TABLE "public"."foods" OWNER TO "postgres";


COMMENT ON COLUMN "public"."foods"."show_in_preferences" IS 'Whether this food should be shown in the onboarding food preferences screen';



COMMENT ON COLUMN "public"."foods"."is_essential" IS 'No need to present to user to set preferences';



COMMENT ON COLUMN "public"."foods"."allergens" IS 'Allergens contained in this food (e.g., dairy, gluten, peanuts). Used for filtering foods based on user allergies.';



COMMENT ON COLUMN "public"."foods"."excluded_diets" IS 'Diets that should exclude this food (e.g., vegan excludes meat/dairy). Used for filtering foods based on user dietary preference.';



CREATE TABLE IF NOT EXISTS "public"."public_events" (
    "id" bigint NOT NULL,
    "event_name" "text" NOT NULL,
    "event_type" "public"."activity_type_enum" NOT NULL,
    "event_subtype" "public"."event_subtype_enum",
    "location" "text",
    "city" "text",
    "state" "text",
    "country" "text" DEFAULT 'USA'::"text",
    "event_date" "date",
    "start_time" time without time zone,
    "registration_url" "text",
    "website_url" "text",
    "description" "text",
    "organizer_name" "text",
    "is_active" boolean DEFAULT true,
    "source" "text",
    "external_id" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "search_vector" "tsvector" GENERATED ALWAYS AS ("to_tsvector"('"english"'::"regconfig", ((((((COALESCE("event_name", ''::"text") || ' '::"text") || COALESCE("location", ''::"text")) || ' '::"text") || COALESCE("city", ''::"text")) || ' '::"text") || COALESCE("state", ''::"text")))) STORED
);


ALTER TABLE "public"."public_events" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."public_events_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."public_events_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."public_events_id_seq" OWNED BY "public"."public_events"."id";



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
    "is_electrolyte" boolean DEFAULT false,
    "to_exclude_from_solver" boolean DEFAULT false,
    "is_deleted" boolean DEFAULT false,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "client_updated_at" timestamp with time zone,
    "categories" "public"."category_enum"[] DEFAULT '{}'::"public"."category_enum"[] NOT NULL,
    "user_id" "uuid" NOT NULL,
    "product_type" "public"."product_type_enum",
    "activity_types" "public"."activity_type_enum"[]
);


ALTER TABLE "public"."user_foods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."users" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "device_id" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"(),
    "gender" "public"."gender_enum",
    "birthday" "date",
    "height_feet" integer,
    "height_inches" integer,
    "weight_pounds" numeric(5,2),
    "runs_with_water_bottle" boolean DEFAULT false,
    "food_preferences" "jsonb" DEFAULT '{}'::"jsonb",
    "preferred_distance_unit" "public"."distance_unit_enum" DEFAULT 'miles'::"public"."distance_unit_enum",
    "preferred_pace_unit" "public"."pace_unit_enum" DEFAULT 'min_per_mile'::"public"."pace_unit_enum",
    "gut_training_level" "public"."gut_training_enum" DEFAULT 'moderate'::"public"."gut_training_enum",
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
    "auth_user_id" "uuid",
    "auth_provider" "public"."auth_provider_enum" DEFAULT 'anonymous'::"public"."auth_provider_enum" NOT NULL,
    "is_anonymous" boolean DEFAULT true NOT NULL,
    "auth_skipped_at" timestamp with time zone,
    "typical_bike_bottles" integer,
    "has_aero_bottle" boolean,
    "has_bento_box" boolean,
    "typical_wetsuit" boolean,
    "typical_swim_cap_type" "text",
    "gi_sensitivity" boolean,
    "dietary_preference" "public"."dietary_preference_enum",
    "allergies" "public"."allergy_enum"[] DEFAULT '{}'::"public"."allergy_enum"[],
    CONSTRAINT "check_bike_bottles" CHECK ((("typical_bike_bottles" IS NULL) OR (("typical_bike_bottles" >= 0) AND ("typical_bike_bottles" <= 6)))),
    CONSTRAINT "check_swim_cap_type" CHECK ((("typical_swim_cap_type" IS NULL) OR ("typical_swim_cap_type" = ANY (ARRAY['none'::"text", 'latex'::"text", 'silicone'::"text", 'neoprene'::"text"]))))
);


ALTER TABLE "public"."users" OWNER TO "postgres";


COMMENT ON COLUMN "public"."users"."cycling_ftp_watts" IS 'User default FTP (Functional Threshold Power) in watts';



COMMENT ON COLUMN "public"."users"."prefers_cycling_power" IS 'Whether user prefers to input power vs speed for cycling';



COMMENT ON COLUMN "public"."users"."swimming_css_seconds_per_100m" IS 'User default CSS (Critical Swim Speed) in seconds per 100m';



COMMENT ON COLUMN "public"."users"."prefers_swimming_pace" IS 'Whether user prefers to input pace vs speed for swimming';



COMMENT ON COLUMN "public"."users"."typical_bike_bottles" IS 'Number of water bottles typically carried on bike (1-4)';



COMMENT ON COLUMN "public"."users"."has_aero_bottle" IS 'Whether cyclist has aero bottle for additional hydration';



COMMENT ON COLUMN "public"."users"."has_bento_box" IS 'Whether cyclist has bento box for additional nutrition storage';



COMMENT ON COLUMN "public"."users"."typical_wetsuit" IS 'Whether swimmer typically uses wetsuit in open water';



COMMENT ON COLUMN "public"."users"."typical_swim_cap_type" IS 'Typical swim cap type: none, latex, silicone, neoprene';



COMMENT ON COLUMN "public"."users"."gi_sensitivity" IS 'Whether user has GI sensitivity issues during endurance activities';



COMMENT ON COLUMN "public"."users"."dietary_preference" IS 'User dietary preference: omnivore, vegetarian, pescatarian, vegan, mediterranean, paleo, keto, low_carb. NULL means no preference set.';



COMMENT ON COLUMN "public"."users"."allergies" IS 'Array of user allergies for food filtering. Empty array means no allergies.';



ALTER TABLE ONLY "public"."activities" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."activities_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."carb_loading_days" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."carb_loading_days_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."carb_loading_plans" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."carb_loading_plans_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."events" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."events_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."feature_survey_responses" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."feature_survey_responses_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."public_events" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."public_events_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."activities"
    ADD CONSTRAINT "activities_id_new_unique" UNIQUE ("id");



ALTER TABLE ONLY "public"."activities"
    ADD CONSTRAINT "activities_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."app_content"
    ADD CONSTRAINT "app_content_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_days"
    ADD CONSTRAINT "carb_loading_days_id_new_unique" UNIQUE ("id");



ALTER TABLE ONLY "public"."carb_loading_days"
    ADD CONSTRAINT "carb_loading_days_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_foods"
    ADD CONSTRAINT "carb_loading_foods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_plans"
    ADD CONSTRAINT "carb_loading_plans_id_new_unique" UNIQUE ("id");



ALTER TABLE ONLY "public"."carb_loading_plans"
    ADD CONSTRAINT "carb_loading_plans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."carb_loading_user_foods"
    ADD CONSTRAINT "carb_loading_user_foods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_id_new_unique" UNIQUE ("id");



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feature_survey_responses"
    ADD CONSTRAINT "feature_survey_responses_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."food_preferences"
    ADD CONSTRAINT "food_preferences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."foods"
    ADD CONSTRAINT "foods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."public_events"
    ADD CONSTRAINT "public_events_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_foods"
    ADD CONSTRAINT "user_foods_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_device_id_key" UNIQUE ("device_id");



ALTER TABLE ONLY "public"."users"
    ADD CONSTRAINT "users_pkey" PRIMARY KEY ("id");



CREATE INDEX "idx_activities_cycling_power" ON "public"."activities" USING "btree" ("cycling_power_watts") WHERE ("cycling_power_watts" IS NOT NULL);



CREATE INDEX "idx_activities_scheduled" ON "public"."activities" USING "btree" ("scheduled_date_time");



CREATE INDEX "idx_activities_status" ON "public"."activities" USING "btree" ("status");



CREATE INDEX "idx_activities_swimming_pace" ON "public"."activities" USING "btree" ("swimming_speed_per_100m") WHERE ("swimming_speed_per_100m" IS NOT NULL);



CREATE INDEX "idx_app_content_active" ON "public"."app_content" USING "btree" ("is_active");



CREATE INDEX "idx_app_content_env_locale" ON "public"."app_content" USING "btree" ("environment", "locale");



CREATE INDEX "idx_app_content_version" ON "public"."app_content" USING "btree" ("version");



CREATE INDEX "idx_carb_day_meals_day" ON "public"."carb_loading_day_meals" USING "btree" ("carb_loading_day_id");



CREATE INDEX "idx_carb_day_meals_food" ON "public"."carb_loading_day_meals" USING "btree" ("carb_loading_food_id") WHERE ("carb_loading_food_id" IS NOT NULL);



CREATE INDEX "idx_carb_day_meals_meal_type" ON "public"."carb_loading_day_meals" USING "btree" ("meal_type");



CREATE INDEX "idx_carb_day_meals_user_food" ON "public"."carb_loading_day_meals" USING "btree" ("carb_loading_user_food_id") WHERE ("carb_loading_user_food_id" IS NOT NULL);



CREATE INDEX "idx_carb_days_completed" ON "public"."carb_loading_days" USING "btree" ("completed");



CREATE INDEX "idx_carb_days_date" ON "public"."carb_loading_days" USING "btree" ("plan_date");



CREATE INDEX "idx_carb_days_plan" ON "public"."carb_loading_days" USING "btree" ("carb_loading_plan_id");



CREATE INDEX "idx_carb_loading_foods_default" ON "public"."carb_loading_foods" USING "btree" ("is_default");



CREATE INDEX "idx_carb_loading_foods_name" ON "public"."carb_loading_foods" USING "btree" ("name");



CREATE INDEX "idx_carb_loading_user_foods_barcode" ON "public"."carb_loading_user_foods" USING "btree" ("barcode") WHERE ("barcode" IS NOT NULL);



CREATE INDEX "idx_carb_loading_user_foods_deleted" ON "public"."carb_loading_user_foods" USING "btree" ("is_deleted");



CREATE INDEX "idx_carb_loading_user_foods_device" ON "public"."carb_loading_user_foods" USING "btree" ("device_id");



CREATE INDEX "idx_carb_loading_user_foods_user_id" ON "public"."carb_loading_user_foods" USING "btree" ("user_id");



CREATE INDEX "idx_carb_plans_dates" ON "public"."carb_loading_plans" USING "btree" ("start_date", "end_date");



CREATE INDEX "idx_carb_plans_event" ON "public"."carb_loading_plans" USING "btree" ("event_id") WHERE ("event_id" IS NOT NULL);



CREATE INDEX "idx_events_activity" ON "public"."events" USING "btree" ("activity_id") WHERE ("activity_id" IS NOT NULL);



CREATE INDEX "idx_events_carb_loading" ON "public"."events" USING "btree" ("has_carb_loading") WHERE ("has_carb_loading" = true);



CREATE INDEX "idx_events_event_date" ON "public"."events" USING "btree" ("event_date");



CREATE UNIQUE INDEX "idx_feature_survey_responses_user_id" ON "public"."feature_survey_responses" USING "btree" ("user_id");



CREATE INDEX "idx_feature_survey_responses_voted_at" ON "public"."feature_survey_responses" USING "btree" ("voted_at");



CREATE INDEX "idx_feedback_created_at" ON "public"."feedback" USING "btree" ("created_at");



CREATE INDEX "idx_feedback_satisfaction_level" ON "public"."feedback" USING "btree" ("satisfaction_level");



CREATE INDEX "idx_feedback_timestamp" ON "public"."feedback" USING "btree" ("timestamp");



CREATE INDEX "idx_feedback_user_name" ON "public"."feedback" USING "btree" ("user_name");



CREATE INDEX "idx_food_preferences_preference" ON "public"."food_preferences" USING "btree" ("preference");



CREATE UNIQUE INDEX "idx_food_preferences_user_food" ON "public"."food_preferences" USING "btree" ("user_id", "food_name");



CREATE INDEX "idx_foods_after_suitable" ON "public"."foods" USING "btree" ("after_run_suitable") WHERE ("after_run_suitable" = true);



CREATE INDEX "idx_foods_allergens_gin" ON "public"."foods" USING "gin" ("allergens");



CREATE INDEX "idx_foods_before_suitable" ON "public"."foods" USING "btree" ("before_run_suitable") WHERE ("before_run_suitable" = true);



CREATE INDEX "idx_foods_categories_gin" ON "public"."foods" USING "gin" ("categories");



CREATE INDEX "idx_foods_during_suitable" ON "public"."foods" USING "btree" ("during_run_suitable") WHERE ("during_run_suitable" = true);



CREATE INDEX "idx_foods_excluded_diets_gin" ON "public"."foods" USING "gin" ("excluded_diets");



CREATE INDEX "idx_foods_show_in_preferences_name" ON "public"."foods" USING "btree" ("show_in_preferences", "name");



CREATE INDEX "idx_public_events_city_trgm" ON "public"."public_events" USING "gin" ("city" "public"."gin_trgm_ops");



CREATE INDEX "idx_public_events_location_trgm" ON "public"."public_events" USING "gin" ("location" "public"."gin_trgm_ops");



CREATE INDEX "idx_public_events_name_trgm" ON "public"."public_events" USING "gin" ("event_name" "public"."gin_trgm_ops");



CREATE INDEX "idx_public_events_search" ON "public"."public_events" USING "gin" ("search_vector");



CREATE INDEX "idx_user_foods_barcode" ON "public"."user_foods" USING "btree" ("barcode");



CREATE INDEX "idx_user_foods_categories_gin" ON "public"."user_foods" USING "gin" ("categories");



CREATE INDEX "idx_user_foods_device" ON "public"."user_foods" USING "btree" ("device_id");



CREATE INDEX "idx_user_foods_device_not_deleted" ON "public"."user_foods" USING "btree" ("device_id") WHERE ("is_deleted" = false);



CREATE INDEX "idx_user_foods_user_id" ON "public"."user_foods" USING "btree" ("user_id");



CREATE INDEX "idx_users_auth_provider" ON "public"."users" USING "btree" ("auth_provider");



CREATE INDEX "idx_users_auth_user_id" ON "public"."users" USING "btree" ("auth_user_id");



CREATE INDEX "idx_users_device_id" ON "public"."users" USING "btree" ("device_id");



CREATE INDEX "idx_users_dietary_preference" ON "public"."users" USING "btree" ("dietary_preference") WHERE ("dietary_preference" IS NOT NULL);



CREATE INDEX "idx_users_updated_at" ON "public"."users" USING "btree" ("updated_at");



CREATE UNIQUE INDEX "uq_foods_lower_name" ON "public"."foods" USING "btree" ("lower"("name"));



CREATE UNIQUE INDEX "uq_user_foods_device_clientid" ON "public"."user_foods" USING "btree" ("device_id", "client_food_id");



CREATE OR REPLACE TRIGGER "update_app_content_updated_at" BEFORE UPDATE ON "public"."app_content" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_carb_loading_days_updated_at" BEFORE UPDATE ON "public"."carb_loading_days" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_carb_loading_foods_updated_at" BEFORE UPDATE ON "public"."carb_loading_foods" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_carb_loading_plans_updated_at" BEFORE UPDATE ON "public"."carb_loading_plans" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_foods_updated_at" BEFORE UPDATE ON "public"."foods" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



ALTER TABLE ONLY "public"."activities"
    ADD CONSTRAINT "activities_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_carb_loading_day_id_fkey" FOREIGN KEY ("carb_loading_day_id") REFERENCES "public"."carb_loading_days"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_carb_loading_food_id_fkey" FOREIGN KEY ("carb_loading_food_id") REFERENCES "public"."carb_loading_foods"("id");



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_carb_loading_user_food_id_fkey" FOREIGN KEY ("carb_loading_user_food_id") REFERENCES "public"."carb_loading_user_foods"("id");



ALTER TABLE ONLY "public"."carb_loading_day_meals"
    ADD CONSTRAINT "carb_loading_day_meals_plan_fk" FOREIGN KEY ("carb_loading_plan_id") REFERENCES "public"."carb_loading_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_days"
    ADD CONSTRAINT "carb_loading_days_plan_fk" FOREIGN KEY ("carb_loading_plan_id") REFERENCES "public"."carb_loading_plans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_plans"
    ADD CONSTRAINT "carb_loading_plans_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "public"."events"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_user_foods"
    ADD CONSTRAINT "carb_loading_user_foods_source_food_id_fkey" FOREIGN KEY ("source_food_id") REFERENCES "public"."foods"("id");



ALTER TABLE ONLY "public"."carb_loading_user_foods"
    ADD CONSTRAINT "carb_loading_user_foods_source_user_food_id_fkey" FOREIGN KEY ("source_user_food_id") REFERENCES "public"."user_foods"("id");



ALTER TABLE ONLY "public"."carb_loading_user_foods"
    ADD CONSTRAINT "carb_loading_user_foods_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_activity_fkey" FOREIGN KEY ("activity_id") REFERENCES "public"."activities"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."events"
    ADD CONSTRAINT "events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."feature_survey_responses"
    ADD CONSTRAINT "feature_survey_responses_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_plans"
    ADD CONSTRAINT "fk_carb_loading_plans_user" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."carb_loading_user_foods"
    ADD CONSTRAINT "fk_carb_loading_user_foods_user" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_foods"
    ADD CONSTRAINT "fk_user_foods_user" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."food_preferences"
    ADD CONSTRAINT "food_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_foods"
    ADD CONSTRAINT "user_foods_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Users can manage their own carb loading foods" ON "public"."carb_loading_user_foods" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "Users can manage their own foods" ON "public"."user_foods" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."feedback" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_in"("cstring") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_out"("public"."gtrgm") TO "service_role";

























































































































































GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_by_device_plan_id"("p_device_id" "text", "p_plan_id" "text") TO "anon";
GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_by_device_plan_id"("p_device_id" "text", "p_plan_id" "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_by_device_plan_id"("p_device_id" "text", "p_plan_id" "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_client_version" integer) TO "anon";
GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_client_version" integer) TO "authenticated";
GRANT ALL ON FUNCTION "public"."delete_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_client_version" integer) TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_query_trgm"("text", "internal", smallint, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_extract_value_trgm"("text", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_consistent"("internal", smallint, "text", integer, "internal", "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gin_trgm_triconsistent"("internal", smallint, "text", integer, "internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_compress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_consistent"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_decompress"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_distance"("internal", "text", smallint, "oid", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_options"("internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_penalty"("internal", "internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_picksplit"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_same"("public"."gtrgm", "public"."gtrgm", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "postgres";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "anon";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "authenticated";
GRANT ALL ON FUNCTION "public"."gtrgm_union"("internal", "internal") TO "service_role";



GRANT ALL ON FUNCTION "public"."search_public_events_hybrid"("search_term" "text", "limit_count" integer, "event_type_filter" "text", "state_filter" "text", "min_similarity" double precision) TO "anon";
GRANT ALL ON FUNCTION "public"."search_public_events_hybrid"("search_term" "text", "limit_count" integer, "event_type_filter" "text", "state_filter" "text", "min_similarity" double precision) TO "authenticated";
GRANT ALL ON FUNCTION "public"."search_public_events_hybrid"("search_term" "text", "limit_count" integer, "event_type_filter" "text", "state_filter" "text", "min_similarity" double precision) TO "service_role";



GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "postgres";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "anon";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_limit"(real) TO "service_role";



GRANT ALL ON FUNCTION "public"."show_limit"() TO "postgres";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "anon";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_limit"() TO "service_role";



GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "postgres";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "anon";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."show_trgm"("text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_dist"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."strict_word_similarity_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."update_auth_sessions_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_auth_sessions_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_auth_sessions_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_food_preferences_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_food_preferences_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_food_preferences_updated_at"() TO "service_role";



GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "anon";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."update_updated_at_column"() TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_food_preferences"("p_device_id" "text", "p_preferences" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_food_preferences"("p_device_id" "text", "p_preferences" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_food_preferences"("p_device_id" "text", "p_preferences" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb", "p_client_version" integer, "p_client_updated_at" timestamp with time zone) TO "anon";
GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb", "p_client_version" integer, "p_client_updated_at" timestamp with time zone) TO "authenticated";
GRANT ALL ON FUNCTION "public"."upsert_nutrition_plan_versioned"("p_device_id" "text", "p_plan_id" "text", "p_plan_data" "jsonb", "p_client_version" integer, "p_client_updated_at" timestamp with time zone) TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_commutator_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_dist_op"("text", "text") TO "service_role";



GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "postgres";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "anon";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "authenticated";
GRANT ALL ON FUNCTION "public"."word_similarity_op"("text", "text") TO "service_role";


















GRANT ALL ON TABLE "public"."activities" TO "anon";
GRANT ALL ON TABLE "public"."activities" TO "authenticated";
GRANT ALL ON TABLE "public"."activities" TO "service_role";



GRANT ALL ON SEQUENCE "public"."activities_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."activities_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."activities_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."app_content" TO "anon";
GRANT ALL ON TABLE "public"."app_content" TO "authenticated";
GRANT ALL ON TABLE "public"."app_content" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_day_meals" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_day_meals" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_day_meals" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_days" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_days" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_days" TO "service_role";



GRANT ALL ON SEQUENCE "public"."carb_loading_days_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."carb_loading_days_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."carb_loading_days_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_foods" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_foods" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_foods" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_plans" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_plans" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_plans" TO "service_role";



GRANT ALL ON SEQUENCE "public"."carb_loading_plans_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."carb_loading_plans_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."carb_loading_plans_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."carb_loading_user_foods" TO "anon";
GRANT ALL ON TABLE "public"."carb_loading_user_foods" TO "authenticated";
GRANT ALL ON TABLE "public"."carb_loading_user_foods" TO "service_role";



GRANT ALL ON TABLE "public"."events" TO "anon";
GRANT ALL ON TABLE "public"."events" TO "authenticated";
GRANT ALL ON TABLE "public"."events" TO "service_role";



GRANT ALL ON SEQUENCE "public"."events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."events_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."events_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."feature_survey_responses" TO "anon";
GRANT ALL ON TABLE "public"."feature_survey_responses" TO "authenticated";
GRANT ALL ON TABLE "public"."feature_survey_responses" TO "service_role";



GRANT ALL ON SEQUENCE "public"."feature_survey_responses_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."feature_survey_responses_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."feature_survey_responses_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."feedback" TO "anon";
GRANT ALL ON TABLE "public"."feedback" TO "authenticated";
GRANT ALL ON TABLE "public"."feedback" TO "service_role";



GRANT ALL ON TABLE "public"."food_preferences" TO "anon";
GRANT ALL ON TABLE "public"."food_preferences" TO "authenticated";
GRANT ALL ON TABLE "public"."food_preferences" TO "service_role";



GRANT ALL ON TABLE "public"."foods" TO "anon";
GRANT ALL ON TABLE "public"."foods" TO "authenticated";
GRANT ALL ON TABLE "public"."foods" TO "service_role";



GRANT ALL ON TABLE "public"."public_events" TO "anon";
GRANT ALL ON TABLE "public"."public_events" TO "authenticated";
GRANT ALL ON TABLE "public"."public_events" TO "service_role";



GRANT ALL ON SEQUENCE "public"."public_events_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."public_events_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."public_events_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."user_foods" TO "anon";
GRANT ALL ON TABLE "public"."user_foods" TO "authenticated";
GRANT ALL ON TABLE "public"."user_foods" TO "service_role";



GRANT ALL ON TABLE "public"."users" TO "anon";
GRANT ALL ON TABLE "public"."users" TO "authenticated";
GRANT ALL ON TABLE "public"."users" TO "service_role";









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






























drop extension if exists "pg_net";


