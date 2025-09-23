-- MEALVANA ENDURANCE SUPABASE SCHEMA (Updated 2025-09-19)
-- This file contains the complete updated Supabase schema including product_types table

-- Users table
create table public.users
(
    id                         uuid                     default gen_random_uuid() not null
        primary key,
    device_id                  text                                               not null
        unique,
    created_at                 timestamp with time zone default now(),
    updated_at                 timestamp with time zone default now(),
    gender                     text
        constraint users_gender_check
            check (gender = ANY (ARRAY ['male'::text, 'female'::text, 'other'::text])),
    birthday                   date,
    height_feet                integer,
    height_inches              integer,
    weight_pounds              numeric(5, 2),
    runs_with_water_bottle     boolean                  default false,
    food_preferences           jsonb                    default '{}'::jsonb,
    preferred_distance_unit    text                     default 'miles'::text
        constraint users_preferred_distance_unit_check
            check (preferred_distance_unit = ANY (ARRAY ['miles'::text, 'kilometers'::text])),
    preferred_pace_unit        text                     default 'min_per_mile'::text
        constraint users_preferred_pace_unit_check
            check (preferred_pace_unit = ANY (ARRAY ['min_per_mile'::text, 'min_per_km'::text])),
    gut_training_level         text                     default 'moderate'::text
        constraint users_gut_training_level_check
            check (gut_training_level = ANY (ARRAY ['low'::text, 'moderate'::text, 'high'::text])),
    onboarding_completed       boolean                  default false,
    last_active_at             timestamp with time zone default now(),
    app_version                text,
    notifications_enabled      boolean                  default false,
    default_reminder_day       integer                  default 4,
    default_reminder_hour      integer                  default 17,
    default_reminder_minute    integer                  default 0,
    default_reminder_recurring boolean                  default false
);

-- Categories table
create table public.categories
(
    name text    not null,
    id   integer not null
        constraint categories_pk
            primary key
);

-- Brands table
create table public.brands
(
    id                    uuid default gen_random_uuid() not null
        primary key,
    name                  text                           not null
        unique,
    website_url           text,
    affiliate_program_url text,
    affiliate_network     text,
    default_affiliate_url text,
    notes                 text
);

-- Product Types table (NEW)
create table public.product_types
(
    id          uuid                     default gen_random_uuid() not null
        primary key,
    code        text                                               not null
        unique,
    name        text                                               not null,
    name_plural text                                               not null,
    sort_order  integer,
    created_at  timestamp with time zone default now()
);

-- Foods table (UPDATED with product_type_id reference)
create table public.foods
(
    id                     uuid                     default gen_random_uuid() not null
        primary key,
    name                   text,
    image_address          text,
    created_at             timestamp with time zone default now(),
    serving_amount         numeric,
    max_servings_before    integer,
    max_servings_during    integer,
    max_servings_after     integer,
    sodium_mg              integer,
    caffeine_mg            integer,
    potassium_mg           integer,
    fat_per_serving        numeric(10, 2),
    carbs_per_serving      numeric(10, 2),
    protein_per_serving    numeric(10, 2),
    calories_per_serving   integer,
    fluid_ml_per_serving   numeric(10, 1),
    brand_id               uuid
        references public.brands,
    show_in_preferences    boolean                  default false,
    display_name           varchar(100),
    display_name_plural    varchar(100),
    is_electrolyte         boolean                  default false,
    to_exclude_from_solver boolean                  default false,
    product_type_id        uuid
        references public.product_types
);

comment on column public.foods.show_in_preferences is 'Whether this food should be shown in the onboarding food preferences screen';
comment on column public.foods.display_name is 'Simplified display name for quantity formatting (e.g. "gel", "banana")';
comment on column public.foods.display_name_plural is 'Plural form of display name (e.g. "gels", "bananas")';
comment on column public.foods.product_type_id is 'References product_types table for standardized categorization';

-- Food Categories junction table
create table public.food_categories
(
    food_id     uuid    not null
        references public.foods
            on delete cascade,
    category_id integer not null
        references public.categories,
    primary key (food_id, category_id)
);

-- Food Preferences table
create table public.food_preferences
(
    id         uuid                     default gen_random_uuid() not null
        primary key,
    device_id  text                                               not null
        references public.users (device_id)
            on delete cascade,
    food_name  text                                               not null,
    preference text                                               not null
        constraint food_preferences_preference_check
            check (preference = ANY (ARRAY ['like'::text, 'dislike'::text, 'willing_to_try'::text])),
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone default now()
);

comment on table public.food_preferences is 'Stores user food preferences (like, dislike, willing_to_try) linked by device_id';
comment on column public.food_preferences.device_id is 'References users.device_id - user who owns this preference';
comment on column public.food_preferences.food_name is 'Name of the food item (should match foods.name)';
comment on column public.food_preferences.preference is 'User preference: like, dislike, or willing_to_try';

-- Nutrition Plans table
create table public.nutrition_plans
(
    id                    uuid                     default gen_random_uuid() not null
        primary key,
    device_id             text                                               not null
        references public.users (device_id)
            on delete cascade,
    plan_data             jsonb                                              not null,
    distance_miles        numeric(5, 2),
    pace_minutes_per_mile numeric(5, 2),
    created_at            timestamp with time zone default now(),
    updated_at            timestamp with time zone default now(),
    plan_id               text                                               not null,
    plan_name             text                                               not null,
    total_calories        integer,
    notes                 text,
    version               integer                  default 1,
    last_modified_by      text,
    client_updated_at     timestamp with time zone,
    is_deleted            boolean                  default false,
    conflict_resolution   text,
    unique (device_id, plan_id)
);

-- Feedback table
create table public.feedback
(
    id                   uuid                     default gen_random_uuid() not null
        primary key,
    satisfaction_level   integer,
    satisfaction_emoji   text,
    satisfaction_label   text,
    confidence_level     integer,
    confidence_label     text,
    reuse_intent         text,
    reminder_requested   boolean                  default false,
    missed_reasons       text,
    missed_other         text,
    reminder_day_of_week integer,
    reminder_hour        integer                  default 17,
    reminder_minute      integer                  default 0,
    reminder_recurring   boolean                  default false,
    plan_name            text,
    user_name            text,
    timestamp            timestamp with time zone,
    created_at           timestamp with time zone default now()
);

-- Edge Functions table
create table public.edge_functions
(
    id         uuid                     default gen_random_uuid() not null
        primary key,
    name       text                                               not null
        unique,
    code       text                                               not null,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone default now()
);

-- INDEXES
create index idx_users_device_id on public.users (device_id);
create index idx_users_updated_at on public.users (updated_at);
create unique index uq_foods_lower_name on public.foods (lower(name));
create index idx_foods_product_type_id on public.foods (product_type_id);
create index idx_food_categories_food on public.food_categories (food_id);
create index idx_food_categories_category_id on public.food_categories (category_id);
create unique index idx_food_preferences_device_food on public.food_preferences (device_id, food_name);
create index idx_food_preferences_device_id on public.food_preferences (device_id);
create index idx_food_preferences_preference on public.food_preferences (preference);
create index idx_nutrition_plans_device_id on public.nutrition_plans (device_id);
create index idx_nutrition_plans_created_at on public.nutrition_plans (created_at desc);
create index idx_nutrition_plans_plan_id on public.nutrition_plans (plan_id);
create index idx_nutrition_plans_updated_at on public.nutrition_plans (updated_at desc);
create index idx_nutrition_plans_device_updated on public.nutrition_plans (device_id asc, updated_at desc);
create index idx_feedback_created_at on public.feedback (created_at);
create index idx_feedback_user_name on public.feedback (user_name);
create index idx_feedback_satisfaction_level on public.feedback (satisfaction_level);
create index idx_feedback_timestamp on public.feedback (timestamp);

-- SAMPLE PRODUCT TYPES DATA
INSERT INTO public.product_types (id, code, name, name_plural, sort_order) VALUES
('8a847f4f-8c26-41ef-a1e2-132b404be95e', 'gel', 'Gel', 'Gels', 10),
('fc915f1b-d541-45fa-ae5c-695ee41073db', 'chew', 'Chew', 'Chews', 20),
('d3908cb2-a21d-4ef1-8d33-c999d29eefcc', 'drink_mix', 'Drink mix', 'Drink mixes', 30),
('09930546-1942-485e-9728-bced1cf933a2', 'electrolyte_only', 'Electrolyte-only', 'Electrolyte-only', 40),
('b27bc986-1402-4e20-b022-a65b5ffbd4d2', 'sports_drink', 'Sports drink', 'Sports drinks', 50),
('6102eea1-2dfe-44cf-8863-b258c27262ef', 'bar', 'Bar', 'Bars', 60),
('666408c5-6d5b-4fc6-bda3-d6428e8362b9', 'waffle', 'Waffle', 'Waffles', 70),
('52a0ff7c-a0f5-4e26-b409-2a7ce3298f4d', 'capsule', 'Capsule', 'Capsules', 80),
('76c16c67-1746-47d7-adea-e5fc9dcd1f4d', 'real_food', 'Real food', 'Real foods', 90),
('cbcfd036-127c-43fb-88d5-34a9d9ba5db4', 'recovery_shake', 'Recovery shake', 'Recovery shakes', 100);

-- SCHEMA CHANGES SUMMARY:
-- 1. ADDED: product_types table with standardized product categorization
-- 2. CHANGED: foods.product_type (text) -> foods.product_type_id (uuid reference)
-- 3. RETAINED: foods.display_name and foods.display_name_plural for simplified quantity formatting
-- 4. RETAINED: All other existing schema structure