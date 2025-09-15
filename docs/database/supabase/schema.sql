-- Mealvana Endurance Supabase Database Schema
-- Complete schema for backend PostgreSQL database
-- This is the authoritative schema provided by the user

CREATE TABLE public.app_content
(
    id          uuid                     default gen_random_uuid()  not null,
    version     integer                  default 1                  not null,
    environment text                     default 'production'::text not null,
    locale      text                     default 'en'::text         not null,
    content     jsonb                                               not null,
    is_active   boolean                  default true               not null,
    created_at  timestamp with time zone default now(),
    updated_at  timestamp with time zone default now(),
    created_by  uuid,
    updated_by  uuid,
    primary key (id)
);

alter table public.app_content owner to postgres;

create unique index app_content_pkey on public.app_content using btree (id);
create index idx_app_content_active on public.app_content using btree (is_active);
create index idx_app_content_env_locale on public.app_content using btree (environment, locale);
create index idx_app_content_version on public.app_content using btree (version);

create trigger update_app_content_updated_at
    before update on public.app_content
    for each row
execute procedure update_updated_at_column();

create policy "Allow public read access to app_content" on public.app_content
    as permissive for select using (true);

create policy "Allow authenticated insert to app_content" on public.app_content
    as permissive for insert
    with check (auth.role() = 'authenticated'::text);

create policy "Allow authenticated update to app_content" on public.app_content
    as permissive for update
    using (auth.role() = 'authenticated'::text);

create policy "Dev: anon can modify app_content" on public.app_content
    as permissive for all
    to anon
    using (true) with check (true);

create policy "Anyone can read app_content" on public.app_content
    as permissive for select using (true);

-- Users table (device-based authentication)
CREATE TABLE public.users
(
    id                         uuid                     default gen_random_uuid() not null primary key,
    device_id                  text                                               not null unique,
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

alter table public.users owner to postgres;

create index idx_users_device_id on public.users using btree (device_id);
create index idx_users_updated_at on public.users using btree (updated_at);

create trigger update_users_updated_at
    before update on public.users
    for each row
execute procedure update_updated_at_column();

create policy "Users can read own data" on public.users
    as permissive for select using (true);

create policy "Users can insert own data" on public.users
    as permissive for insert with check (true);

create policy "Users can update own data" on public.users
    as permissive for update using (true);

grant delete, insert, references, select, trigger, truncate, update on public.users to anon;
grant delete, insert, references, select, trigger, truncate, update on public.users to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.users to service_role;

-- Nutrition plans with versioning and sync support
CREATE TABLE public.nutrition_plans
(
    id                    uuid                     default gen_random_uuid() not null primary key,
    device_id             text                                               not null
        references public.users (device_id) on delete cascade,
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

alter table public.nutrition_plans owner to postgres;

create index idx_nutrition_plans_device_id on public.nutrition_plans using btree (device_id);
create index idx_nutrition_plans_created_at on public.nutrition_plans using btree (created_at desc);
create index idx_nutrition_plans_plan_id on public.nutrition_plans using btree (plan_id);
create index idx_nutrition_plans_updated_at on public.nutrition_plans using btree (updated_at desc);
create index idx_nutrition_plans_device_updated on public.nutrition_plans using btree (device_id asc, updated_at desc);

create trigger update_nutrition_plans_updated_at
    before update on public.nutrition_plans
    for each row
execute procedure update_updated_at_column();

create policy "Users can read own plans" on public.nutrition_plans
    as permissive for select using (true);

create policy "Users can insert own plans" on public.nutrition_plans
    as permissive for insert with check (true);

create policy "Users can update own plans" on public.nutrition_plans
    as permissive for update using (true);

create policy "Users can delete own plans" on public.nutrition_plans
    as permissive for delete using (true);

grant delete, insert, references, select, trigger, truncate, update on public.nutrition_plans to anon;
grant delete, insert, references, select, trigger, truncate, update on public.nutrition_plans to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.nutrition_plans to service_role;

-- Categories for food timing (before_run, during_run, after_run)
CREATE TABLE public.categories
(
    name text    not null,
    id   integer not null constraint categories_pk primary key
);

alter table public.categories owner to postgres;

create policy "Anyone can read categories" on public.categories
    as permissive for select using (true);

grant delete, insert, references, select, trigger, truncate, update on public.categories to anon;
grant delete, insert, references, select, trigger, truncate, update on public.categories to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.categories to service_role;

-- Food preferences with device-based association
CREATE TABLE public.food_preferences
(
    id         uuid                     default gen_random_uuid() not null primary key,
    device_id  text                                               not null
        references public.users (device_id) on delete cascade,
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

alter table public.food_preferences owner to postgres;

create unique index idx_food_preferences_device_food on public.food_preferences using btree (device_id, food_name);
create index idx_food_preferences_device_id on public.food_preferences using btree (device_id);
create index idx_food_preferences_preference on public.food_preferences using btree (preference);

create trigger update_food_preferences_updated_at
    before update on public.food_preferences
    for each row
execute procedure public.update_food_preferences_updated_at();

create policy "Allow all operations on food_preferences" on public.food_preferences
    as permissive for all using (true) with check (true);

grant delete, insert, references, select, trigger, truncate, update on public.food_preferences to anon;
grant delete, insert, references, select, trigger, truncate, update on public.food_preferences to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.food_preferences to service_role;

-- Edge functions for dynamic code deployment
CREATE TABLE public.edge_functions
(
    id         uuid                     default gen_random_uuid() not null primary key,
    name       text                                               not null unique,
    code       text                                               not null,
    created_at timestamp with time zone default now(),
    updated_at timestamp with time zone default now()
);

alter table public.edge_functions owner to postgres;

create policy "Anyone can read edge_functions" on public.edge_functions
    as permissive for select using (true);

create policy "Dev: anon can modify edge_functions" on public.edge_functions
    as permissive for all to anon using (true) with check (true);

grant delete, insert, references, select, trigger, truncate, update on public.edge_functions to anon;
grant delete, insert, references, select, trigger, truncate, update on public.edge_functions to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.edge_functions to service_role;

-- Brands for affiliate marketing features
CREATE TABLE public.brands
(
    id                    uuid default gen_random_uuid() not null primary key,
    name                  text                           not null unique,
    website_url           text,
    affiliate_program_url text,
    affiliate_network     text,
    default_affiliate_url text,
    notes                 text
);

alter table public.brands owner to postgres;

-- Foods database with comprehensive nutrition and affiliate data
CREATE TABLE public.foods
(
    id                    uuid                     default gen_random_uuid() not null primary key,
    name                  text,
    image_address         text,
    description           text,
    instructions          text,
    nutritional_info      jsonb                    default '{}'::jsonb,
    created_at            timestamp with time zone default now(),
    serving_amount        numeric,
    serving_unit          text,
    serving_unit_plural   text,
    serving_qualifier     text,
    before_run_suitable   boolean                  default false,
    during_run_suitable   boolean                  default false,
    run_portable          boolean                  default false,
    requires_preparation  boolean                  default false,
    aid_station_available boolean                  default false,
    max_servings_before   integer,
    max_servings_during   integer,
    serving_size          text,
    sodium_mg             integer,
    caffeine_mg           integer,
    potassium_mg          integer,
    fat_per_serving       numeric(10, 2),
    carbs_per_serving     numeric(10, 2),
    protein_per_serving   numeric(10, 2),
    calories_per_serving  integer,
    fluid_ml_per_serving  numeric(10, 1),
    brand_id              uuid references public.brands,
    product_type          text
        constraint foods_product_type_check
            check (product_type = ANY
                   (ARRAY ['gel'::text, 'chew'::text, 'drink_mix'::text, 'electrolyte_only'::text, 'sports_drink'::text, 'bar'::text, 'waffle'::text, 'capsule'::text, 'real_food'::text, 'recovery_shake'::text])),
    purchase_url          text,
    affiliate_source      text,
    show_in_preferences   boolean                  default false,
    preference_priority   integer                  default 999,
    display_name          varchar(100),
    max_servings_after    integer,
    after_run_suitable    boolean,
    is_electrolyte        boolean                  default false
);

comment on column public.foods.show_in_preferences is 'Whether this food should be shown in the onboarding food preferences screen';
comment on column public.foods.preference_priority is 'Priority order for display in preferences screen (lower numbers first)';
comment on column public.foods.display_name is 'User-friendly display name for UI (may differ from technical name)';
comment on column public.foods.max_servings_after is 'Maximum recommended servings for after-run phase';
comment on column public.foods.after_run_suitable is 'Whether this food is suitable for post-run recovery';
comment on column public.foods.is_electrolyte is 'Whether this food is primarily an electrolyte/sodium source';

alter table public.foods owner to postgres;

create unique index uq_foods_lower_name on public.foods using btree (lower(name));

create policy "Anyone can read foods" on public.foods
    as permissive for select using (true);

create policy "Dev: anon can modify foods" on public.foods
    as permissive for all to anon using (true) with check (true);

grant delete, insert, references, select, trigger, truncate, update on public.foods to anon;
grant delete, insert, references, select, trigger, truncate, update on public.foods to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.foods to service_role;

-- Many-to-many relationship between foods and categories
CREATE TABLE public.food_categories
(
    food_id     uuid    not null references public.foods on delete cascade,
    category_id integer not null references public.categories,
    primary key (food_id, category_id)
);

alter table public.food_categories owner to postgres;

create index idx_food_categories_food on public.food_categories using btree (food_id);
create index idx_food_categories_category_id on public.food_categories using btree (category_id);

create policy "Anyone can read food_categories" on public.food_categories
    as permissive for select using (true);

create policy "Dev: anon can modify food_categories" on public.food_categories
    as permissive for all to anon using (true) with check (true);

grant delete, insert, references, select, trigger, truncate, update on public.food_categories to anon;
grant delete, insert, references, select, trigger, truncate, update on public.food_categories to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.food_categories to service_role;

grant delete, insert, references, select, trigger, truncate, update on public.brands to anon;
grant delete, insert, references, select, trigger, truncate, update on public.brands to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.brands to service_role;

-- Feedback collection with comprehensive tracking
CREATE TABLE public.feedback
(
    id                   uuid                     default gen_random_uuid() not null primary key,
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

alter table public.feedback owner to postgres;

create index idx_feedback_created_at on public.feedback using btree (created_at);
create index idx_feedback_user_name on public.feedback using btree (user_name);
create index idx_feedback_satisfaction_level on public.feedback using btree (satisfaction_level);
create index idx_feedback_timestamp on public.feedback using btree (timestamp);

create policy "Allow all operations on feedback" on public.feedback
    as permissive for all using (true);

grant delete, insert, references, select, trigger, truncate, update on public.feedback to anon;
grant delete, insert, references, select, trigger, truncate, update on public.feedback to authenticated;
grant delete, insert, references, select, trigger, truncate, update on public.feedback to service_role;

-- Helper functions and triggers

-- Generic update_updated_at function for automatic timestamp updates
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Specific trigger function for food_preferences
CREATE OR REPLACE FUNCTION public.update_food_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Insert default categories
INSERT INTO public.categories (id, name) VALUES 
(1, 'before_run'),
(2, 'during_run'), 
(3, 'after_run')
ON CONFLICT (id) DO NOTHING;

-- Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_users_onboarding ON public.users(onboarding_completed);
CREATE INDEX IF NOT EXISTS idx_users_last_active ON public.users(last_active_at);
CREATE INDEX IF NOT EXISTS idx_nutrition_plans_active ON public.nutrition_plans(device_id, is_deleted) WHERE is_deleted = false;
CREATE INDEX IF NOT EXISTS idx_foods_suitability_before ON public.foods(before_run_suitable) WHERE before_run_suitable = true;
CREATE INDEX IF NOT EXISTS idx_foods_suitability_during ON public.foods(during_run_suitable) WHERE during_run_suitable = true;
CREATE INDEX IF NOT EXISTS idx_foods_suitability_after ON public.foods(after_run_suitable) WHERE after_run_suitable = true;
CREATE INDEX IF NOT EXISTS idx_foods_brand ON public.foods(brand_id) WHERE brand_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_foods_electrolyte ON public.foods(is_electrolyte) WHERE is_electrolyte = true;
CREATE INDEX IF NOT EXISTS idx_foods_preferences ON public.foods(show_in_preferences, preference_priority) WHERE show_in_preferences = true;
CREATE INDEX IF NOT EXISTS idx_app_content_latest ON public.app_content(environment, locale, version DESC) WHERE is_active = true;