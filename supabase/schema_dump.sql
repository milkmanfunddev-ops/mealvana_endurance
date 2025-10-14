

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


CREATE SCHEMA IF NOT EXISTS "public";


ALTER SCHEMA "public" OWNER TO "pg_database_owner";


COMMENT ON SCHEMA "public" IS 'standard public schema';



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
    "conflict_resolution" "text"
);


ALTER TABLE "public"."nutrition_plans" OWNER TO "postgres";


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
    CONSTRAINT "users_gender_check" CHECK (("gender" = ANY (ARRAY['male'::"text", 'female'::"text", 'other'::"text"]))),
    CONSTRAINT "users_gut_training_level_check" CHECK (("gut_training_level" = ANY (ARRAY['low'::"text", 'moderate'::"text", 'high'::"text"]))),
    CONSTRAINT "users_preferred_distance_unit_check" CHECK (("preferred_distance_unit" = ANY (ARRAY['miles'::"text", 'kilometers'::"text"]))),
    CONSTRAINT "users_preferred_pace_unit_check" CHECK (("preferred_pace_unit" = ANY (ARRAY['min_per_mile'::"text", 'min_per_km'::"text"])))
);


ALTER TABLE "public"."users" OWNER TO "postgres";


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
    "is_other_food" boolean
);


ALTER TABLE "public"."foods" OWNER TO "postgres";


COMMENT ON COLUMN "public"."foods"."show_in_preferences" IS 'Whether this food should be shown in the onboarding food preferences screen';



COMMENT ON COLUMN "public"."foods"."is_essential" IS 'No need to present to user to set preferences';



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
    "client_updated_at" timestamp with time zone
);


ALTER TABLE "public"."user_foods" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_hidden_foods" (
    "device_id" "text" NOT NULL,
    "food_id" "uuid" NOT NULL
);


ALTER TABLE "public"."user_hidden_foods" OWNER TO "postgres";


ALTER TABLE ONLY "public"."app_content"
    ADD CONSTRAINT "app_content_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pk" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."edge_functions"
    ADD CONSTRAINT "edge_functions_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."edge_functions"
    ADD CONSTRAINT "edge_functions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."feedback"
    ADD CONSTRAINT "feedback_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."food_categories"
    ADD CONSTRAINT "food_categories_pkey" PRIMARY KEY ("food_id", "category_id");



ALTER TABLE ONLY "public"."food_preferences"
    ADD CONSTRAINT "food_preferences_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."foods"
    ADD CONSTRAINT "foods_pkey" PRIMARY KEY ("id");



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



CREATE INDEX "idx_app_content_active" ON "public"."app_content" USING "btree" ("is_active");



CREATE INDEX "idx_app_content_env_locale" ON "public"."app_content" USING "btree" ("environment", "locale");



CREATE INDEX "idx_app_content_version" ON "public"."app_content" USING "btree" ("version");



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



CREATE INDEX "idx_users_device_id" ON "public"."users" USING "btree" ("device_id");



CREATE INDEX "idx_users_updated_at" ON "public"."users" USING "btree" ("updated_at");



CREATE UNIQUE INDEX "uq_foods_lower_name" ON "public"."foods" USING "btree" ("lower"("name"));



CREATE UNIQUE INDEX "uq_user_foods_device_clientid" ON "public"."user_foods" USING "btree" ("device_id", "client_food_id");



CREATE OR REPLACE TRIGGER "update_app_content_updated_at" BEFORE UPDATE ON "public"."app_content" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_food_preferences_updated_at" BEFORE UPDATE ON "public"."food_preferences" FOR EACH ROW EXECUTE FUNCTION "public"."update_food_preferences_updated_at"();



CREATE OR REPLACE TRIGGER "update_nutrition_plans_updated_at" BEFORE UPDATE ON "public"."nutrition_plans" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



CREATE OR REPLACE TRIGGER "update_users_updated_at" BEFORE UPDATE ON "public"."users" FOR EACH ROW EXECUTE FUNCTION "public"."update_updated_at_column"();



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



ALTER TABLE "public"."app_content" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."feedback" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."food_preferences" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."foods" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."nutrition_plans" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."users" ENABLE ROW LEVEL SECURITY;


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



GRANT ALL ON TABLE "public"."app_content" TO "anon";
GRANT ALL ON TABLE "public"."app_content" TO "authenticated";
GRANT ALL ON TABLE "public"."app_content" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."current_content" TO "anon";
GRANT ALL ON TABLE "public"."current_content" TO "authenticated";
GRANT ALL ON TABLE "public"."current_content" TO "service_role";



GRANT ALL ON TABLE "public"."edge_functions" TO "anon";
GRANT ALL ON TABLE "public"."edge_functions" TO "authenticated";
GRANT ALL ON TABLE "public"."edge_functions" TO "service_role";



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






RESET ALL;
