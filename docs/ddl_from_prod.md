create table public.app_content
(
    id          uuid                     default gen_random_uuid()  not null
        primary key,
    version     integer                  default 1                  not null,
    environment text                     default 'production'::text not null,
    locale      text                     default 'en'::text         not null,
    content     jsonb                                               not null,
    is_active   boolean                  default true               not null,
    created_at  timestamp with time zone default now(),
    updated_at  timestamp with time zone default now(),
    created_by  uuid,
    updated_by  uuid
);

alter table public.app_content
    owner to postgres;

create index idx_app_content_active
    on public.app_content (is_active);

create index idx_app_content_env_locale
    on public.app_content (environment, locale);

create index idx_app_content_version
    on public.app_content (version);

create trigger update_app_content_updated_at
    before update
    on public.app_content
    for each row
execute procedure public.update_updated_at_column();

create policy "Allow public read access to app_content" on public.app_content
    as permissive
    for select
    using true;

create policy "Allow authenticated insert to app_content" on public.app_content
    as permissive
    for insert
    with check (auth.role() = 'authenticated'::text);

create policy "Allow authenticated update to app_content" on public.app_content
    as permissive
    for update
    using (auth.role() = 'authenticated'::text);

create policy "Dev: anon can modify app_content" on public.app_content
    as permissive
    for all
    to anon
    using true
with check true;

create policy "Anyone can read app_content" on public.app_content
    as permissive
    for select
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.app_content to anon;

grant delete, insert, references, select, trigger, truncate, update on public.app_content to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.app_content to service_role;

create table public.users
(
    id                            uuid                     default gen_random_uuid() not null
        primary key,
    device_id                     text                                               not null
        unique,
    created_at                    timestamp with time zone default now(),
    updated_at                    timestamp with time zone default now(),
    gender                        text
        constraint users_gender_check
            check (gender = ANY (ARRAY ['male'::text, 'female'::text, 'other'::text])),
    birthday                      date,
    height_feet                   integer,
    height_inches                 integer,
    weight_pounds                 numeric(5, 2),
    runs_with_water_bottle        boolean                  default false,
    food_preferences              jsonb                    default '{}'::jsonb,
    preferred_distance_unit       text                     default 'miles'::text
        constraint users_preferred_distance_unit_check
            check (preferred_distance_unit = ANY (ARRAY ['miles'::text, 'kilometers'::text])),
    preferred_pace_unit           text                     default 'min_per_mile'::text
        constraint users_preferred_pace_unit_check
            check (preferred_pace_unit = ANY (ARRAY ['min_per_mile'::text, 'min_per_km'::text])),
    gut_training_level            text                     default 'moderate'::text
        constraint users_gut_training_level_check
            check (gut_training_level = ANY (ARRAY ['low'::text, 'moderate'::text, 'high'::text])),
    onboarding_completed          boolean                  default false,
    last_active_at                timestamp with time zone default now(),
    app_version                   text,
    notifications_enabled         boolean                  default false,
    default_reminder_day          integer                  default 4,
    default_reminder_hour         integer                  default 17,
    default_reminder_minute       integer                  default 0,
    default_reminder_recurring    boolean                  default false,
    preferred_sports              text[]                   default ARRAY ['running'::text],
    cycling_ftp_watts             integer,
    prefers_cycling_power         boolean                  default false,
    swimming_css_seconds_per_100m integer,
    prefers_swimming_pace         boolean                  default false
);

alter table public.users
    owner to postgres;

create index idx_users_device_id
    on public.users (device_id);

create index idx_users_updated_at
    on public.users (updated_at);

create trigger update_users_updated_at
    before update
    on public.users
    for each row
execute procedure public.update_updated_at_column();

create policy "Users can read own data" on public.users
    as permissive
    for select
    using true;

create policy "Users can insert own data" on public.users
    as permissive
    for insert
    with check true;

create policy "Users can update own data" on public.users
    as permissive
    for update
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.users to anon;

grant delete, insert, references, select, trigger, truncate, update on public.users to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.users to service_role;

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
    activity_id           text,
    user_id               text,
    unique (device_id, plan_id)
);

comment on column public.nutrition_plans.activity_id is 'Links nutrition plan to a calendar activity/event. Nullable to support standalone plans.';

alter table public.nutrition_plans
    owner to postgres;

create index idx_nutrition_plans_device_id
    on public.nutrition_plans (device_id);

create index idx_nutrition_plans_created_at
    on public.nutrition_plans (created_at desc);

create index idx_nutrition_plans_plan_id
    on public.nutrition_plans (plan_id);

create index idx_nutrition_plans_updated_at
    on public.nutrition_plans (updated_at desc);

create index idx_nutrition_plans_device_updated
    on public.nutrition_plans (device_id asc, updated_at desc);

create trigger update_nutrition_plans_updated_at
    before update
    on public.nutrition_plans
    for each row
execute procedure public.update_updated_at_column();

create policy "Users can read own plans" on public.nutrition_plans
    as permissive
    for select
    using true;

create policy "Users can insert own plans" on public.nutrition_plans
    as permissive
    for insert
    with check true;

create policy "Users can update own plans" on public.nutrition_plans
    as permissive
    for update
    using true;

create policy "Users can delete own plans" on public.nutrition_plans
    as permissive
    for delete
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.nutrition_plans to anon;

grant delete, insert, references, select, trigger, truncate, update on public.nutrition_plans to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.nutrition_plans to service_role;

create table public.categories
(
    name text    not null,
    id   integer not null
        constraint categories_pk
            primary key
);

alter table public.categories
    owner to postgres;

create policy "Anyone can read categories" on public.categories
    as permissive
    for select
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.categories to anon;

grant delete, insert, references, select, trigger, truncate, update on public.categories to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.categories to service_role;

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

alter table public.food_preferences
    owner to postgres;

create unique index idx_food_preferences_device_food
    on public.food_preferences (device_id, food_name);

create index idx_food_preferences_device_id
    on public.food_preferences (device_id);

create index idx_food_preferences_preference
    on public.food_preferences (preference);

create trigger update_food_preferences_updated_at
    before update
    on public.food_preferences
    for each row
execute procedure public.update_food_preferences_updated_at();

create policy "Allow all operations on food_preferences" on public.food_preferences
    as permissive
    for all
    using true
with check true;

grant delete, insert, references, select, trigger, truncate, update on public.food_preferences to anon;

grant delete, insert, references, select, trigger, truncate, update on public.food_preferences to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.food_preferences to service_role;

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

alter table public.edge_functions
    owner to postgres;

create policy "Anyone can read edge_functions" on public.edge_functions
    as permissive
    for select
    using true;

create policy "Dev: anon can modify edge_functions" on public.edge_functions
    as permissive
    for all
    to anon
    using true
with check true;

grant delete, insert, references, select, trigger, truncate, update on public.edge_functions to anon;

grant delete, insert, references, select, trigger, truncate, update on public.edge_functions to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.edge_functions to service_role;

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

alter table public.feedback
    owner to postgres;

create index idx_feedback_created_at
    on public.feedback (created_at);

create index idx_feedback_user_name
    on public.feedback (user_name);

create index idx_feedback_satisfaction_level
    on public.feedback (satisfaction_level);

create index idx_feedback_timestamp
    on public.feedback (timestamp);

create policy "Allow all operations on feedback" on public.feedback
    as permissive
    for all
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.feedback to anon;

grant delete, insert, references, select, trigger, truncate, update on public.feedback to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.feedback to service_role;

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

alter table public.product_types
    owner to postgres;

create table public.foods
(
    id                      uuid                     default gen_random_uuid() not null
        primary key,
    name                    text,
    image_address           text,
    created_at              timestamp with time zone default now(),
    serving_amount          numeric,
    max_servings_before     integer,
    max_servings_during     integer,
    sodium_mg               integer,
    caffeine_mg             integer,
    potassium_mg            integer,
    fat_per_serving         numeric(10, 2),
    carbs_per_serving       numeric(10, 2),
    protein_per_serving     numeric(10, 2),
    calories_per_serving    integer,
    fluid_ml_per_serving    numeric(10, 1),
    show_in_preferences     boolean                  default false,
    display_name            varchar(100),
    max_servings_after      integer,
    is_electrolyte          boolean                  default false,
    display_name_plural     varchar(100),
    to_exclude_from_solver  boolean                  default false,
    product_type_id         uuid
        references public.product_types,
    description             text,
    serving_description     text,
    serving_size            varchar(50),
    is_essential            boolean                  default false,
    is_other_food           boolean,
    cycling_suitable        boolean                  default true,
    swimming_suitable       boolean                  default true,
    suitable_for_activities jsonb
);

comment on column public.foods.show_in_preferences is 'Whether this food should be shown in the onboarding food preferences screen';

comment on column public.foods.is_essential is 'No need to present to user to set preferences';

alter table public.foods
    owner to postgres;

create unique index uq_foods_lower_name
    on public.foods (lower(name));

create index idx_foods_product_type_id
    on public.foods (product_type_id);

create policy "Anyone can read foods" on public.foods
    as permissive
    for select
    using true;

create policy "Dev: anon can modify foods" on public.foods
    as permissive
    for all
    to anon
    using true
with check true;

grant delete, insert, references, select, trigger, truncate, update on public.foods to anon;

grant delete, insert, references, select, trigger, truncate, update on public.foods to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.foods to service_role;

create table public.food_categories
(
    food_id     uuid    not null
        references public.foods
            on delete cascade,
    category_id integer not null
        references public.categories,
    primary key (food_id, category_id)
);

alter table public.food_categories
    owner to postgres;

create index idx_food_categories_food
    on public.food_categories (food_id);

create index idx_food_categories_category_id
    on public.food_categories (category_id);

create policy "Anyone can read food_categories" on public.food_categories
    as permissive
    for select
    using true;

create policy "Dev: anon can modify food_categories" on public.food_categories
    as permissive
    for all
    to anon
    using true
with check true;

grant delete, insert, references, select, trigger, truncate, update on public.food_categories to anon;

grant delete, insert, references, select, trigger, truncate, update on public.food_categories to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.food_categories to service_role;

grant delete, insert, references, select, trigger, truncate, update on public.product_types to anon;

grant delete, insert, references, select, trigger, truncate, update on public.product_types to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.product_types to service_role;

create table public.user_foods
(
    id                      uuid                     default gen_random_uuid() not null
        primary key,
    device_id               text                                               not null
        references public.users (device_id)
            on delete cascade,
    client_food_id          text,
    barcode                 text,
    name                    text                                               not null,
    display_name            text,
    display_name_plural     text,
    description             text,
    image_address           text,
    serving_amount          numeric,
    serving_unit            text,
    calories_per_serving    integer,
    carbs_per_serving       numeric(10, 2),
    protein_per_serving     numeric(10, 2),
    fat_per_serving         numeric(10, 2),
    sodium_mg               integer,
    fluid_ml_per_serving    numeric(10, 1),
    product_type_id         uuid
        references public.product_types,
    is_electrolyte          boolean                  default false,
    to_exclude_from_solver  boolean                  default false,
    is_deleted              boolean                  default false,
    created_at              timestamp with time zone default now(),
    updated_at              timestamp with time zone default now(),
    client_updated_at       timestamp with time zone,
    cycling_suitable        boolean                  default true,
    swimming_suitable       boolean                  default true,
    suitable_for_activities jsonb
);

alter table public.user_foods
    owner to postgres;

create index idx_user_foods_device
    on public.user_foods (device_id);

create index idx_user_foods_barcode
    on public.user_foods (barcode);

create unique index uq_user_foods_device_clientid
    on public.user_foods (device_id, client_food_id);

create index idx_user_foods_device_not_deleted
    on public.user_foods (device_id)
    where (is_deleted = false);

grant delete, insert, references, select, trigger, truncate, update on public.user_foods to anon;

grant delete, insert, references, select, trigger, truncate, update on public.user_foods to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.user_foods to service_role;

create table public.user_food_categories
(
    user_food_id uuid    not null
        references public.user_foods
            on delete cascade,
    category_id  integer not null
        references public.categories,
    primary key (user_food_id, category_id)
);

alter table public.user_food_categories
    owner to postgres;

create index idx_user_food_categories_user_food
    on public.user_food_categories (user_food_id);

create index idx_user_food_categories_category
    on public.user_food_categories (category_id);

grant delete, insert, references, select, trigger, truncate, update on public.user_food_categories to anon;

grant delete, insert, references, select, trigger, truncate, update on public.user_food_categories to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.user_food_categories to service_role;

create table public.user_hidden_foods
(
    device_id text not null
        constraint user_hidden_global_foods_device_id_fkey
            references public.users (device_id)
            on delete cascade,
    food_id   uuid not null
        constraint user_hidden_global_foods_food_id_fkey
            references public.foods
            on delete cascade,
    constraint user_hidden_global_foods_pkey
        primary key (device_id, food_id)
);

alter table public.user_hidden_foods
    owner to postgres;

grant delete, insert, references, select, trigger, truncate, update on public.user_hidden_foods to anon;

grant delete, insert, references, select, trigger, truncate, update on public.user_hidden_foods to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.user_hidden_foods to service_role;

create table public.macro_targets_table
(
    id               text not null
        primary key,
    device_id        text not null,
    activity_id      text,
    carbs_grams      integer,
    protein_grams    integer,
    fat_grams        integer,
    sodium_mg        integer,
    hydration_oz     integer,
    calculation_rule text,
    is_user_modified boolean                  default false,
    modified_fields  text[],
    created_at       timestamp with time zone default now(),
    updated_at       timestamp with time zone default now()
);

alter table public.macro_targets_table
    owner to postgres;

create policy "Users can access their own macro targets" on public.macro_targets_table
    as permissive
    for all
    using (device_id = ((current_setting('request.jwt.claims'::text, true))::json ->> 'device_id'::text));

grant delete, insert, references, select, trigger, truncate, update on public.macro_targets_table to anon;

grant delete, insert, references, select, trigger, truncate, update on public.macro_targets_table to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.macro_targets_table to service_role;

create table public.workout_notes
(
    id          uuid                     default gen_random_uuid() not null
        primary key,
    device_id   text                                               not null,
    user_id     text,
    plan_id     text,
    activity_id text,
    rating      integer,
    notes       text,
    created_at  timestamp with time zone default now(),
    updated_at  timestamp with time zone default now()
);

alter table public.workout_notes
    owner to postgres;

create policy "Users can access their own workout notes" on public.workout_notes
    as permissive
    for all
    using (device_id = ((current_setting('request.jwt.claims'::text, true))::json ->> 'device_id'::text));

grant delete, insert, references, select, trigger, truncate, update on public.workout_notes to anon;

grant delete, insert, references, select, trigger, truncate, update on public.workout_notes to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.workout_notes to service_role;

create table public.activities
(
    id                             text not null
        primary key,
    device_id                      text not null,
    activity_type                  text not null,
    sport_type                     text                     default 'running'::text,
    distance_miles                 numeric(5, 2),
    pace_minutes_per_mile          numeric(5, 2),
    duration_minutes               integer,
    scheduled_date                 timestamp with time zone,
    time_before_minutes            integer,
    intensity_target               text,
    status                         text                     default 'scheduled'::text,
    cycling_power_watts            integer,
    cycling_speed_mph              numeric(5, 2),
    cycling_ftp_watts              integer,
    cycling_terrain                text,
    cycling_elevation_gain_ft      integer,
    cycling_indoor_outdoor         text,
    cycling_session_goal           text,
    swimming_pace_per_100m_seconds integer,
    swimming_speed_per_100m        numeric(5, 2),
    swimming_css_seconds_per_100m  integer,
    swimming_pool_or_open_water    text,
    swimming_water_temp_c          numeric(4, 1),
    created_at                     timestamp with time zone default now(),
    updated_at                     timestamp with time zone default now()
);

alter table public.activities
    owner to postgres;

create policy "Users can access their own activities" on public.activities
    as permissive
    for all
    using (device_id = ((current_setting('request.jwt.claims'::text, true))::json ->> 'device_id'::text));

grant delete, insert, references, select, trigger, truncate, update on public.activities to anon;

grant delete, insert, references, select, trigger, truncate, update on public.activities to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.activities to service_role;

create table public.events
(
    id                 text                     not null
        primary key,
    device_id          text                     not null,
    event_name         text                     not null,
    event_date         timestamp with time zone not null,
    activity_id        text,
    has_nutrition_plan boolean                  default false,
    has_carb_loading   boolean                  default false,
    created_at         timestamp with time zone default now(),
    updated_at         timestamp with time zone default now()
);

alter table public.events
    owner to postgres;

create policy "Users can access their own events" on public.events
    as permissive
    for all
    using (device_id = ((current_setting('request.jwt.claims'::text, true))::json ->> 'device_id'::text));

grant delete, insert, references, select, trigger, truncate, update on public.events to anon;

grant delete, insert, references, select, trigger, truncate, update on public.events to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.events to service_role;

create table public.activity_completions
(
    id                      text not null
        primary key,
    device_id               text not null,
    user_id                 text,
    activity_id             text not null,
    completed_at            timestamp with time zone default now(),
    actual_duration_minutes integer,
    actual_distance_miles   numeric(5, 2),
    notes                   text,
    created_at              timestamp with time zone default now(),
    updated_at              timestamp with time zone default now()
);

alter table public.activity_completions
    owner to postgres;

create policy "Users can access their own completions" on public.activity_completions
    as permissive
    for all
    using (device_id = ((current_setting('request.jwt.claims'::text, true))::json ->> 'device_id'::text));

grant delete, insert, references, select, trigger, truncate, update on public.activity_completions to anon;

grant delete, insert, references, select, trigger, truncate, update on public.activity_completions to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.activity_completions to service_role;

create table public.carb_loading_plans
(
    id                    text                     not null
        primary key,
    device_id             text                     not null,
    event_id              text                     not null,
    start_date            timestamp with time zone not null,
    end_date              timestamp with time zone not null,
    target_carbs_g_per_kg numeric(5, 2),
    adherence_score       numeric(5, 2),
    created_at            timestamp with time zone default now(),
    updated_at            timestamp with time zone default now()
);

alter table public.carb_loading_plans
    owner to postgres;

create policy "Users can access their own carb plans" on public.carb_loading_plans
    as permissive
    for all
    using (device_id = ((current_setting('request.jwt.claims'::text, true))::json ->> 'device_id'::text));

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_plans to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_plans to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_plans to service_role;

create table public.carb_loading_days
(
    id                     text                     not null
        primary key,
    plan_id                text                     not null,
    day_number             integer                  not null,
    date                   timestamp with time zone not null,
    target_carbs_grams     integer,
    carb_protocol_g_per_kg numeric(5, 2),
    meal_count             integer                  default 0,
    created_at             timestamp with time zone default now(),
    updated_at             timestamp with time zone default now()
);

alter table public.carb_loading_days
    owner to postgres;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_days to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_days to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_days to service_role;

create table public.meal_types
(
    id           text not null
        primary key,
    name         text not null
        unique,
    display_name text not null,
    sort_order   integer default 0
);

alter table public.meal_types
    owner to postgres;

create policy "All users can read meal types" on public.meal_types
    as permissive
    for select
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.meal_types to anon;

grant delete, insert, references, select, trigger, truncate, update on public.meal_types to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.meal_types to service_role;

create table public.carb_loading_foods
(
    id                text not null
        primary key,
    name              text not null,
    display_name      text,
    carbs_per_serving numeric(6, 2),
    serving_size      text,
    serving_unit      text,
    is_default        boolean                  default true,
    created_at        timestamp with time zone default now()
);

alter table public.carb_loading_foods
    owner to postgres;

create policy "All users can read default carb foods" on public.carb_loading_foods
    as permissive
    for select
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_foods to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_foods to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_foods to service_role;

create table public.carb_loading_user_foods
(
    id                  text not null
        primary key,
    device_id           text not null,
    name                text not null,
    display_name        text,
    carbs_per_serving   numeric(6, 2),
    serving_size        text,
    serving_unit        text,
    barcode             text,
    source_food_id      text,
    source_user_food_id text,
    is_deleted          boolean                  default false,
    created_at          timestamp with time zone default now(),
    updated_at          timestamp with time zone default now()
);

alter table public.carb_loading_user_foods
    owner to postgres;

create policy "Users can access their own user foods" on public.carb_loading_user_foods
    as permissive
    for all
    using (device_id = ((current_setting('request.jwt.claims'::text, true))::json ->> 'device_id'::text));

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_foods to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_foods to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_foods to service_role;

create table public.carb_loading_food_meal_types
(
    food_id      text not null,
    meal_type_id text not null,
    primary key (food_id, meal_type_id)
);

alter table public.carb_loading_food_meal_types
    owner to postgres;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_food_meal_types to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_food_meal_types to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_food_meal_types to service_role;

create table public.carb_loading_user_food_meal_types
(
    user_food_id text not null,
    meal_type_id text not null,
    primary key (user_food_id, meal_type_id)
);

alter table public.carb_loading_user_food_meal_types
    owner to postgres;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_food_meal_types to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_food_meal_types to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_food_meal_types to service_role;

create table public.carb_loading_day_meals
(
    id             text not null
        primary key,
    day_id         text not null,
    meal_type_id   text not null,
    food_id        text,
    user_food_id   text,
    quantity       numeric(6, 2),
    carbs_consumed numeric(6, 2),
    created_at     timestamp with time zone default now(),
    updated_at     timestamp with time zone default now()
);

alter table public.carb_loading_day_meals
    owner to postgres;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_day_meals to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_day_meals to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_day_meals to service_role;

