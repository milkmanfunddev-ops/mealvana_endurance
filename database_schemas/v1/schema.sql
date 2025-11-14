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
    cycling_ftp_watts             integer,
    prefers_cycling_power         boolean                  default false,
    swimming_css_seconds_per_100m integer,
    prefers_swimming_pace         boolean                  default false
);

comment on column public.users.cycling_ftp_watts is 'User default FTP (Functional Threshold Power) in watts';

comment on column public.users.prefers_cycling_power is 'Whether user prefers to input power vs speed for cycling';

comment on column public.users.swimming_css_seconds_per_100m is 'User default CSS (Critical Swim Speed) in seconds per 100m';

comment on column public.users.prefers_swimming_pace is 'Whether user prefers to input pace vs speed for swimming';

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

create policy "Users can insert own data" on public.users
    as permissive
    for insert
    with check true;

create policy "Users can read own data" on public.users
    as permissive
    for select
    using true;

create policy "Users can update own data" on public.users
    as permissive
    for update
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.users to anon;

grant delete, insert, references, select, trigger, truncate, update on public.users to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.users to service_role;

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

create policy "Allow authenticated insert to app_content" on public.app_content
    as permissive
    for insert
    with check (auth.role() = 'authenticated'::text);

create policy "Allow authenticated update to app_content" on public.app_content
    as permissive
    for update
    using (auth.role() = 'authenticated'::text);

create policy "Allow public read access to app_content" on public.app_content
    as permissive
    for select
    using true;

create policy "Anyone can read app_content" on public.app_content
    as permissive
    for select
    using true;

create policy "Dev: anon can modify app_content" on public.app_content
    as permissive
    for all
    to anon
    using true
with check true;

grant delete, insert, references, select, trigger, truncate, update on public.app_content to anon;

grant delete, insert, references, select, trigger, truncate, update on public.app_content to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.app_content to service_role;

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

create index idx_feedback_satisfaction_level
    on public.feedback (satisfaction_level);

create index idx_feedback_timestamp
    on public.feedback (timestamp);

create index idx_feedback_user_name
    on public.feedback (user_name);

create policy "Allow all operations on feedback" on public.feedback
    as permissive
    for all
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.feedback to anon;

grant delete, insert, references, select, trigger, truncate, update on public.feedback to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.feedback to service_role;

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
    suitable_for_activities jsonb,
    cycling_suitable        boolean                  default true,
    swimming_suitable       boolean                  default true,
    before_run_suitable     boolean                  default false,
    during_run_suitable     boolean                  default false,
    run_portable            boolean                  default false,
    requires_preparation    boolean                  default false,
    aid_station_available   boolean                  default false,
    after_run_suitable      boolean,
    instructions            text,
    nutritional_info        text,
    serving_unit            text,
    serving_unit_plural     text,
    serving_qualifier       text,
    purchase_url            text,
    affiliate_source        text,
    preference_priority     integer
);

comment on column public.foods.show_in_preferences is 'Whether this food should be shown in the onboarding food preferences screen';

comment on column public.foods.is_essential is 'No need to present to user to set preferences';

comment on column public.foods.suitable_for_activities is 'JSONB map of sport types to boolean suitability. Example: {"running": true, "cycling": true, "swimming": false}. Null means suitable for all activities (backward compatibility).';

alter table public.foods
    owner to postgres;

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

create index idx_food_categories_category_id
    on public.food_categories (category_id);

create index idx_food_categories_food
    on public.food_categories (food_id);

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

create index idx_foods_product_type_id
    on public.foods (product_type_id);

create unique index uq_foods_lower_name
    on public.foods (lower(name));

create index idx_foods_suitable_for_activities
    on public.foods using gin (suitable_for_activities);

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
    suitable_for_activities jsonb,
    needs_upload            boolean                  default false,
    local_updated_at        timestamp                default CURRENT_TIMESTAMP
);

comment on column public.user_foods.suitable_for_activities is 'JSONB map of sport types to boolean suitability. Example: {"running": true, "cycling": true, "swimming": false}. Null means suitable for all activities (backward compatibility).';

comment on column public.user_foods.needs_upload is 'Flag indicating record needs upload to Supabase (offline-first sync)';

comment on column public.user_foods.local_updated_at is 'Timestamp of last local modification (for conflict resolution)';

alter table public.user_foods
    owner to postgres;

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

create index idx_user_food_categories_category
    on public.user_food_categories (category_id);

create index idx_user_food_categories_user_food
    on public.user_food_categories (user_food_id);

grant delete, insert, references, select, trigger, truncate, update on public.user_food_categories to anon;

grant delete, insert, references, select, trigger, truncate, update on public.user_food_categories to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.user_food_categories to service_role;

create index idx_user_foods_barcode
    on public.user_foods (barcode);

create index idx_user_foods_device
    on public.user_foods (device_id);

create index idx_user_foods_device_not_deleted
    on public.user_foods (device_id)
    where (is_deleted = false);

create unique index uq_user_foods_device_clientid
    on public.user_foods (device_id, client_food_id);

create index idx_user_foods_suitable_for_activities
    on public.user_foods using gin (suitable_for_activities);

create index idx_user_foods_needs_upload
    on public.user_foods (needs_upload, device_id)
    where (needs_upload = true);

grant delete, insert, references, select, trigger, truncate, update on public.user_foods to anon;

grant delete, insert, references, select, trigger, truncate, update on public.user_foods to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.user_foods to service_role;

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

create table public.activities
(
    id                             text      not null
        primary key,
    user_id                        text      not null,
    activity_type                  text      not null
        constraint activity_type_check
            check (activity_type = ANY (ARRAY ['running'::text, 'cycling'::text, 'swimming'::text])),
    title                          text      not null,
    scheduled_date_time            timestamp not null,
    status                         text      default 'planned'::text
        constraint status_check
            check (status = ANY (ARRAY ['planned'::text, 'in_progress'::text, 'completed'::text, 'skipped'::text])),
    distance_miles                 real,
    duration_minutes               integer,
    pace_target_minutes_per_mile   real,
    intensity_level                text
        constraint intensity_check
            check ((intensity_level IS NULL) OR
                   (intensity_level = ANY (ARRAY ['easy'::text, 'moderate'::text, 'hard'::text, 'race'::text]))),
    completed_at                   timestamp,
    completion_rating              integer
        constraint rating_check
            check ((completion_rating IS NULL) OR ((completion_rating >= 1) AND (completion_rating <= 5))),
    completion_notes               text,
    actual_distance_miles          real,
    actual_duration_minutes        integer,
    notes                          text,
    created_at                     timestamp default CURRENT_TIMESTAMP,
    updated_at                     timestamp default CURRENT_TIMESTAMP,
    deleted_at                     timestamp,
    sport_type                     text      default 'running'::text
        constraint activities_sport_type_check
            check (sport_type = ANY (ARRAY ['running'::text, 'cycling'::text, 'swimming'::text])),
    cycling_power_watts            integer,
    cycling_ftp_watts              integer,
    swimming_speed_per_100m        integer,
    swimming_css_seconds_per_100m  integer,
    cycling_speed_mph              real,
    cycling_terrain                text
        constraint activities_cycling_terrain_check
            check ((cycling_terrain IS NULL) OR
                   (cycling_terrain = ANY (ARRAY ['flat'::text, 'rolling'::text, 'hilly'::text]))),
    cycling_indoor_outdoor         text
        constraint activities_cycling_indoor_outdoor_check
            check ((cycling_indoor_outdoor IS NULL) OR
                   (cycling_indoor_outdoor = ANY (ARRAY ['indoor'::text, 'outdoor'::text]))),
    cycling_elevation_gain_ft      integer,
    cycling_session_goal           text
        constraint activities_cycling_session_goal_check
            check ((cycling_session_goal IS NULL) OR
                   (cycling_session_goal = ANY (ARRAY ['endurance'::text, 'tempo'::text, 'intervals'::text]))),
    swimming_pace_per_100m_seconds integer,
    swimming_pool_or_open_water    text
        constraint activities_swimming_pool_or_open_water_check
            check ((swimming_pool_or_open_water IS NULL) OR
                   (swimming_pool_or_open_water = ANY (ARRAY ['pool'::text, 'open_water'::text]))),
    swimming_water_temp_c          real,
    intensity_target               text,
    time_before_minutes            integer,
    needs_upload                   boolean   default false,
    local_updated_at               timestamp default CURRENT_TIMESTAMP,
    constraint activities_cycling_columns_check
        check (((sport_type = 'cycling'::text) AND (cycling_power_watts IS NOT NULL)) OR
               ((sport_type <> 'cycling'::text) AND (cycling_power_watts IS NULL) AND (cycling_ftp_watts IS NULL))),
    constraint activities_swimming_columns_check
        check (((sport_type = 'swimming'::text) AND (swimming_speed_per_100m IS NOT NULL)) OR
               ((sport_type <> 'swimming'::text) AND (swimming_speed_per_100m IS NULL) AND
                (swimming_css_seconds_per_100m IS NULL)))
);

comment on table public.activities is 'All calendar entries including workouts and events';

comment on column public.activities.activity_type is 'Type of endurance sport: running, cycling, or swimming';

comment on column public.activities.status is 'Current status: planned, in_progress, completed, skipped';

comment on column public.activities.sport_type is 'Type of endurance sport: running, cycling, or swimming';

comment on column public.activities.cycling_power_watts is 'Average power output in watts for cycling activities';

comment on column public.activities.cycling_ftp_watts is 'Functional Threshold Power in watts (if known)';

comment on column public.activities.swimming_speed_per_100m is 'Average pace in seconds per 100 meters for swimming';

comment on column public.activities.swimming_css_seconds_per_100m is 'Critical Swim Speed in seconds per 100m (if known)';

comment on column public.activities.cycling_speed_mph is 'Average cycling speed in miles per hour';

comment on column public.activities.cycling_terrain is 'Terrain type: flat, rolling, or hilly';

comment on column public.activities.cycling_indoor_outdoor is 'Indoor (trainer) or outdoor cycling';

comment on column public.activities.cycling_elevation_gain_ft is 'Total elevation gain in feet';

comment on column public.activities.cycling_session_goal is 'Session type: endurance, tempo, or intervals';

comment on column public.activities.swimming_pace_per_100m_seconds is 'Swimming pace in seconds per 100 meters';

comment on column public.activities.swimming_pool_or_open_water is 'Pool or open water swimming';

comment on column public.activities.swimming_water_temp_c is 'Water temperature in Celsius';

comment on column public.activities.intensity_target is 'Intensity target (zone_1, zone_2, rpe_3, etc.) - works across all sports';

comment on column public.activities.time_before_minutes is 'Pre-activity timing window in minutes (replaces run-specific pre_run_timing)';

comment on column public.activities.needs_upload is 'Flag indicating record needs upload to Supabase (offline-first sync)';

comment on column public.activities.local_updated_at is 'Timestamp of last local modification (for conflict resolution)';

alter table public.activities
    owner to postgres;

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
    activity_id           text
        constraint fk_nutrition_plans_activity_id
            references public.activities
            on delete set null,
    needs_upload          boolean                  default false,
    local_updated_at      timestamp                default CURRENT_TIMESTAMP,
    plan_type             text                     default 'standard'::text
        constraint nutrition_plans_plan_type_check
            check (plan_type = ANY (ARRAY ['standard'::text, 'carb_loading'::text, 'recovery'::text])),
    sport_type            text                     default 'running'::text,
    unique (device_id, plan_id)
);

comment on column public.nutrition_plans.activity_id is 'Links nutrition plan to a calendar activity/event. Nullable to support standalone plans.';

comment on column public.nutrition_plans.needs_upload is 'Flag indicating record needs upload to Supabase (offline-first sync)';

comment on column public.nutrition_plans.local_updated_at is 'Timestamp of last local modification (for conflict resolution)';

comment on column public.nutrition_plans.plan_type is 'Type of nutrition plan: standard, carb_loading, or recovery';

comment on column public.nutrition_plans.sport_type is 'Sport type for the nutrition plan (currently only running, placeholder for future multi-sport)';

alter table public.nutrition_plans
    owner to postgres;

create index idx_nutrition_plans_created_at
    on public.nutrition_plans (created_at desc);

create index idx_nutrition_plans_device_id
    on public.nutrition_plans (device_id);

create index idx_nutrition_plans_device_updated
    on public.nutrition_plans (device_id asc, updated_at desc);

create index idx_nutrition_plans_plan_id
    on public.nutrition_plans (plan_id);

create index idx_nutrition_plans_updated_at
    on public.nutrition_plans (updated_at desc);

create index idx_nutrition_plans_activity_id
    on public.nutrition_plans (activity_id);

create index idx_nutrition_plans_needs_upload
    on public.nutrition_plans (needs_upload, device_id)
    where (needs_upload = true);

comment on index public.idx_nutrition_plans_needs_upload is 'Partial index for efficient sync queries (only indexes dirty records)';

create trigger update_nutrition_plans_updated_at
    before update
    on public.nutrition_plans
    for each row
execute procedure public.update_updated_at_column();

create policy "Users can delete own plans" on public.nutrition_plans
    as permissive
    for delete
    using true;

create policy "Users can insert own plans" on public.nutrition_plans
    as permissive
    for insert
    with check true;

create policy "Users can read own plans" on public.nutrition_plans
    as permissive
    for select
    using true;

create policy "Users can update own plans" on public.nutrition_plans
    as permissive
    for update
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.nutrition_plans to anon;

grant delete, insert, references, select, trigger, truncate, update on public.nutrition_plans to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.nutrition_plans to service_role;

create index idx_activities_user
    on public.activities (user_id);

create index idx_activities_scheduled
    on public.activities (scheduled_date_time);

create index idx_activities_type
    on public.activities (activity_type);

create index idx_activities_status
    on public.activities (status);

create index idx_activities_needs_upload
    on public.activities (needs_upload, user_id)
    where (needs_upload = true);

create policy activities_select_policy on public.activities
    as permissive
    for select
    using (user_id = current_setting('app.user_id'::text, true));

create policy activities_insert_policy on public.activities
    as permissive
    for insert
    with check (user_id = current_setting('app.user_id'::text, true));

create policy activities_update_policy on public.activities
    as permissive
    for update
    using (user_id = current_setting('app.user_id'::text, true));

create policy activities_delete_policy on public.activities
    as permissive
    for delete
    using (user_id = current_setting('app.user_id'::text, true));

grant delete, insert, references, select, trigger, truncate, update on public.activities to anon;

grant delete, insert, references, select, trigger, truncate, update on public.activities to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.activities to service_role;

create table public.events
(
    id                            text not null
        primary key,
    activity_id                   text
        unique
        references public.activities
            on delete cascade,
    event_type                    text not null
        constraint event_type_check
            check (event_type = ANY
                   (ARRAY ['marathon'::text, 'half_marathon'::text, '10k'::text, '5k'::text, 'ultra_50k'::text, 'ultra_50m'::text, 'ultra_100k'::text, 'ultra_100m'::text, 'custom'::text])),
    event_subtype                 text,
    event_name                    text,
    location                      text,
    registration_url              text,
    start_time                    text,
    goal_time_minutes             integer,
    goal_pace_minutes_per_mile    real,
    predicted_finish_time_minutes integer,
    has_carb_loading              boolean   default false,
    carb_loading_days             integer
        constraint carb_days_check
            check ((carb_loading_days IS NULL) OR (carb_loading_days = ANY (ARRAY [1, 2, 3, 7]))),
    carb_loading_start_date       timestamp,
    bib_number                    text,
    wave_start_time               text,
    packet_pickup_info            text,
    actual_finish_time_minutes    integer,
    final_placement               integer,
    age_group_placement           integer,
    created_at                    timestamp default CURRENT_TIMESTAMP,
    updated_at                    timestamp default CURRENT_TIMESTAMP,
    has_nutrition_plan            boolean   default false,
    user_id                       text not null,
    needs_upload                  boolean   default false,
    local_updated_at              timestamp default CURRENT_TIMESTAMP
);

comment on table public.events is 'Specialized event data for races and competitions';

comment on column public.events.activity_id is 'Optional link to an activity. Events can exist independently without activities.';

comment on column public.events.has_carb_loading is 'Whether this event has an associated carb loading plan';

comment on column public.events.has_nutrition_plan is 'Indicates whether this event has an associated nutrition plan (via activities.id -> nutrition_plans.activity_id)';

comment on column public.events.user_id is 'User ID for direct filtering (eliminates need for joins with activities)';

comment on column public.events.needs_upload is 'Flag indicating record needs upload to Supabase (offline-first sync)';

comment on column public.events.local_updated_at is 'Timestamp of last local modification (for conflict resolution)';

alter table public.events
    owner to postgres;

create index idx_events_activity
    on public.events (activity_id);

create index idx_events_type
    on public.events (event_type);

create index idx_events_carb_loading
    on public.events (has_carb_loading)
    where (has_carb_loading = true);

create index idx_events_user_id
    on public.events (user_id);

create index idx_events_needs_upload
    on public.events (needs_upload, user_id)
    where (needs_upload = true);

create policy events_select_policy on public.events
    as permissive
    for select
    using (EXISTS (SELECT 1
                   FROM activities
                   WHERE ((activities.id = events.activity_id) AND
                          (activities.user_id = current_setting('app.user_id'::text, true)))));

create policy events_insert_policy on public.events
    as permissive
    for insert
    with check (EXISTS (SELECT 1
                        FROM activities
                        WHERE ((activities.id = events.activity_id) AND
                               (activities.user_id = current_setting('app.user_id'::text, true)))));

create policy events_update_policy on public.events
    as permissive
    for update
    using (EXISTS (SELECT 1
                   FROM activities
                   WHERE ((activities.id = events.activity_id) AND
                          (activities.user_id = current_setting('app.user_id'::text, true)))));

create policy events_delete_policy on public.events
    as permissive
    for delete
    using (EXISTS (SELECT 1
                   FROM activities
                   WHERE ((activities.id = events.activity_id) AND
                          (activities.user_id = current_setting('app.user_id'::text, true)))));

create policy "Users can view their own events" on public.events
    as permissive
    for select
    using (user_id = (auth.uid())::text);

create policy "Users can insert their own events" on public.events
    as permissive
    for insert
    with check (user_id = (auth.uid())::text);

create policy "Users can update their own events" on public.events
    as permissive
    for update
    using (user_id = (auth.uid())::text);

create policy "Users can delete their own events" on public.events
    as permissive
    for delete
    using (user_id = (auth.uid())::text);

grant delete, insert, references, select, trigger, truncate, update on public.events to anon;

grant delete, insert, references, select, trigger, truncate, update on public.events to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.events to service_role;

create table public.carb_loading_plans
(
    id                      text      not null
        primary key,
    event_id                text
        references public.events
            on delete cascade,
    user_id                 text      not null,
    total_days              integer   not null
        constraint total_days_check
            check (total_days = ANY (ARRAY [1, 2, 3, 7])),
    start_date              timestamp not null,
    end_date                timestamp not null,
    daily_carb_target_grams integer   not null,
    daily_calorie_target    integer,
    generated_at            timestamp not null,
    algorithm_version       text      default 'v1.0'::text,
    adherence_score         real
        constraint adherence_check
            check ((adherence_score IS NULL) OR
                   ((adherence_score >= (0.0)::double precision) AND (adherence_score <= (1.0)::double precision))),
    completed_at            timestamp,
    needs_upload            boolean   default false,
    local_updated_at        timestamp default CURRENT_TIMESTAMP
);

comment on table public.carb_loading_plans is 'Carb loading plans linked to specific events';

comment on column public.carb_loading_plans.event_id is 'FOREIGN KEY to events.id. Nullable to support standalone carb loading plans not tied to specific events. Multiple plans can share the same event_id.';

comment on column public.carb_loading_plans.adherence_score is '0.0 to 1.0 based on logged meals';

comment on column public.carb_loading_plans.needs_upload is 'Flag indicating record needs upload to Supabase (offline-first sync)';

comment on column public.carb_loading_plans.local_updated_at is 'Timestamp of last local modification (for conflict resolution)';

alter table public.carb_loading_plans
    owner to postgres;

create index idx_carb_plans_event
    on public.carb_loading_plans (event_id);

create index idx_carb_plans_user
    on public.carb_loading_plans (user_id);

create index idx_carb_plans_dates
    on public.carb_loading_plans (start_date, end_date);

create index idx_carb_loading_plans_needs_upload
    on public.carb_loading_plans (needs_upload, user_id)
    where (needs_upload = true);

create policy carb_plans_select_policy on public.carb_loading_plans
    as permissive
    for select
    using (user_id = current_setting('app.user_id'::text, true));

create policy carb_plans_insert_policy on public.carb_loading_plans
    as permissive
    for insert
    with check (user_id = current_setting('app.user_id'::text, true));

create policy carb_plans_update_policy on public.carb_loading_plans
    as permissive
    for update
    using (user_id = current_setting('app.user_id'::text, true));

create policy carb_plans_delete_policy on public.carb_loading_plans
    as permissive
    for delete
    using (user_id = current_setting('app.user_id'::text, true));

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_plans to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_plans to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_plans to service_role;

create table public.carb_loading_days
(
    id                      text                  not null
        primary key,
    carb_loading_plan_id    text                  not null
        references public.carb_loading_plans
            on delete cascade,
    plan_date               timestamp             not null,
    day_number              integer               not null
        constraint day_number_check
            check (day_number > 0),
    carb_target_grams       integer               not null
        constraint carb_target_check
            check (carb_target_grams > 0),
    calorie_target          integer,
    meal_count              integer   default 6
        constraint meal_count_check
            check (meal_count > 0),
    breakfast_percent       real      default 0.25
        constraint breakfast_percent_check
            check ((breakfast_percent >= (0.0)::double precision) AND (breakfast_percent <= (1.0)::double precision)),
    morning_snack_percent   real      default 0.10
        constraint morning_snack_percent_check
            check ((morning_snack_percent >= (0.0)::double precision) AND
                   (morning_snack_percent <= (1.0)::double precision)),
    lunch_percent           real      default 0.25
        constraint lunch_percent_check
            check ((lunch_percent >= (0.0)::double precision) AND (lunch_percent <= (1.0)::double precision)),
    afternoon_snack_percent real      default 0.15
        constraint afternoon_snack_percent_check
            check ((afternoon_snack_percent >= (0.0)::double precision) AND
                   (afternoon_snack_percent <= (1.0)::double precision)),
    dinner_percent          real      default 0.20
        constraint dinner_percent_check
            check ((dinner_percent >= (0.0)::double precision) AND (dinner_percent <= (1.0)::double precision)),
    evening_snack_percent   real      default 0.05
        constraint evening_snack_percent_check
            check ((evening_snack_percent >= (0.0)::double precision) AND
                   (evening_snack_percent <= (1.0)::double precision)),
    logged_carbs_grams      integer   default 0
        constraint logged_carbs_check
            check (logged_carbs_grams >= 0),
    logged_calories         integer   default 0
        constraint logged_calories_check
            check (logged_calories >= 0),
    completed               boolean   default false,
    carb_protocol_g_per_kg  real      default 8.0 not null,
    needs_upload            boolean   default false,
    local_updated_at        timestamp default CURRENT_TIMESTAMP,
    unique (carb_loading_plan_id, plan_date)
);

comment on table public.carb_loading_days is 'Individual day entries within carb loading plans';

comment on column public.carb_loading_days.day_number is '1, 2, 3, etc. (last number = race day - 1)';

comment on column public.carb_loading_days.meal_count is 'Default 6: breakfast, snack, lunch, snack, dinner, evening';

comment on column public.carb_loading_days.carb_protocol_g_per_kg is 'Carbohydrate protocol in grams per kilogram of bodyweight (e.g., 8.0 for 8g/kg)';

comment on column public.carb_loading_days.needs_upload is 'Flag indicating record needs upload to Supabase (offline-first sync)';

comment on column public.carb_loading_days.local_updated_at is 'Timestamp of last local modification (for conflict resolution)';

alter table public.carb_loading_days
    owner to postgres;

create index idx_carb_days_plan
    on public.carb_loading_days (carb_loading_plan_id);

create index idx_carb_days_date
    on public.carb_loading_days (plan_date);

create index idx_carb_days_completed
    on public.carb_loading_days (completed);

create index idx_carb_loading_days_needs_upload
    on public.carb_loading_days (needs_upload)
    where (needs_upload = true);

create policy carb_days_select_policy on public.carb_loading_days
    as permissive
    for select
    using (EXISTS (SELECT 1
                   FROM carb_loading_plans
                   WHERE ((carb_loading_plans.id = carb_loading_days.carb_loading_plan_id) AND
                          (carb_loading_plans.user_id = current_setting('app.user_id'::text, true)))));

create policy carb_days_insert_policy on public.carb_loading_days
    as permissive
    for insert
    with check (EXISTS (SELECT 1
                        FROM carb_loading_plans
                        WHERE ((carb_loading_plans.id = carb_loading_days.carb_loading_plan_id) AND
                               (carb_loading_plans.user_id = current_setting('app.user_id'::text, true)))));

create policy carb_days_update_policy on public.carb_loading_days
    as permissive
    for update
    using (EXISTS (SELECT 1
                   FROM carb_loading_plans
                   WHERE ((carb_loading_plans.id = carb_loading_days.carb_loading_plan_id) AND
                          (carb_loading_plans.user_id = current_setting('app.user_id'::text, true)))));

create policy carb_days_delete_policy on public.carb_loading_days
    as permissive
    for delete
    using (EXISTS (SELECT 1
                   FROM carb_loading_plans
                   WHERE ((carb_loading_plans.id = carb_loading_days.carb_loading_plan_id) AND
                          (carb_loading_plans.user_id = current_setting('app.user_id'::text, true)))));

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_days to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_days to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_days to service_role;

create table public.activity_completions
(
    id                            text      not null
        primary key,
    activity_id                   text      not null
        unique
        references public.activities
            on delete cascade,
    completed_at                  timestamp not null,
    actual_distance_miles         real,
    actual_duration_minutes       integer,
    average_pace_minutes_per_mile real,
    completion_rating             integer
        constraint rating_check
            check ((completion_rating IS NULL) OR ((completion_rating >= 1) AND (completion_rating <= 5))),
    completion_notes              text,
    created_at                    timestamp default CURRENT_TIMESTAMP,
    user_id                       text      not null,
    needs_upload                  boolean   default false,
    local_updated_at              timestamp default CURRENT_TIMESTAMP
);

comment on table public.activity_completions is 'Completion records for activities';

comment on column public.activity_completions.activity_id is 'One-to-one link to activities table';

comment on column public.activity_completions.user_id is 'User who completed the activity (denormalized from activities table for query efficiency)';

comment on column public.activity_completions.needs_upload is 'Flag indicating record needs upload to Supabase (offline-first sync)';

comment on column public.activity_completions.local_updated_at is 'Timestamp of last local modification (for conflict resolution)';

alter table public.activity_completions
    owner to postgres;

create index idx_activity_completions_activity
    on public.activity_completions (activity_id);

create index idx_activity_completions_date
    on public.activity_completions (completed_at);

create index idx_activity_completions_user_id
    on public.activity_completions (user_id);

create index idx_activity_completions_needs_upload
    on public.activity_completions (needs_upload, user_id)
    where (needs_upload = true);

create policy activity_completions_select_policy on public.activity_completions
    as permissive
    for select
    using (EXISTS (SELECT 1
                   FROM activities
                   WHERE ((activities.id = activity_completions.activity_id) AND
                          (activities.user_id = current_setting('app.user_id'::text, true)))));

create policy activity_completions_insert_policy on public.activity_completions
    as permissive
    for insert
    with check (EXISTS (SELECT 1
                        FROM activities
                        WHERE ((activities.id = activity_completions.activity_id) AND
                               (activities.user_id = current_setting('app.user_id'::text, true)))));

create policy activity_completions_update_policy on public.activity_completions
    as permissive
    for update
    using (EXISTS (SELECT 1
                   FROM activities
                   WHERE ((activities.id = activity_completions.activity_id) AND
                          (activities.user_id = current_setting('app.user_id'::text, true)))));

create policy activity_completions_delete_policy on public.activity_completions
    as permissive
    for delete
    using (EXISTS (SELECT 1
                   FROM activities
                   WHERE ((activities.id = activity_completions.activity_id) AND
                          (activities.user_id = current_setting('app.user_id'::text, true)))));

grant delete, insert, references, select, trigger, truncate, update on public.activity_completions to anon;

grant delete, insert, references, select, trigger, truncate, update on public.activity_completions to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.activity_completions to service_role;

create table public.meal_types
(
    id           integer not null
        primary key,
    name         text    not null
        unique,
    display_name text    not null
);

comment on table public.meal_types is 'Meal categories for carb loading feature (breakfast, morning_snack, lunch, afternoon_snack, dinner, evening_snack)';

comment on column public.meal_types.id is 'Primary key (1=breakfast, 2=lunch, 3=dinner, 4=snacks [deprecated], 5=morning_snack, 6=afternoon_snack, 7=evening_snack)';

comment on column public.meal_types.name is 'Internal name (lowercase, underscore-separated)';

comment on column public.meal_types.display_name is 'Display name for UI (title case)';

alter table public.meal_types
    owner to postgres;

create policy meal_types_public_read on public.meal_types
    as permissive
    for select
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.meal_types to anon;

grant delete, insert, references, select, trigger, truncate, update on public.meal_types to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.meal_types to service_role;

create table public.carb_loading_foods
(
    id                  uuid      default gen_random_uuid() not null
        primary key,
    name                text                                not null,
    display_name        text                                not null,
    display_name_plural text,
    carbs_per_serving   real                                not null
        constraint carbs_positive
            check (carbs_per_serving > (0)::double precision),
    image_address       text,
    is_default          boolean   default true,
    created_at          timestamp default CURRENT_TIMESTAMP
);

comment on table public.carb_loading_foods is 'Global default carb loading foods (cereal, pasta, etc.) - pre-seeded';

comment on column public.carb_loading_foods.id is 'UUID primary key';

comment on column public.carb_loading_foods.name is 'Internal name (lowercase, underscore-separated)';

comment on column public.carb_loading_foods.display_name is 'Display name with serving size (e.g., "Cereal (1/2 cup dry)")';

comment on column public.carb_loading_foods.carbs_per_serving is 'Carbohydrates in grams per serving';

comment on column public.carb_loading_foods.is_default is 'True for pre-seeded foods, false for admin-added';

alter table public.carb_loading_foods
    owner to postgres;

create index idx_carb_loading_foods_name
    on public.carb_loading_foods (name);

create index idx_carb_loading_foods_default
    on public.carb_loading_foods (is_default);

create policy carb_loading_foods_public_read on public.carb_loading_foods
    as permissive
    for select
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_foods to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_foods to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_foods to service_role;

create table public.carb_loading_user_foods
(
    id                  uuid      default gen_random_uuid() not null
        primary key,
    device_id           text                                not null,
    client_food_id      text,
    name                text                                not null,
    display_name        text                                not null,
    display_name_plural text,
    carbs_per_serving   real                                not null
        constraint carbs_positive
            check (carbs_per_serving > (0)::double precision),
    image_address       text,
    barcode             text,
    source_food_id      uuid
        references public.foods,
    source_user_food_id uuid
        references public.user_foods,
    is_deleted          boolean   default false,
    created_at          timestamp default CURRENT_TIMESTAMP,
    updated_at          timestamp default CURRENT_TIMESTAMP
);

comment on table public.carb_loading_user_foods is 'User-created carb loading foods from scanning, importing, or manual entry';

comment on column public.carb_loading_user_foods.device_id is 'Device that created this food';

comment on column public.carb_loading_user_foods.barcode is 'Barcode if scanned via barcode scanner';

comment on column public.carb_loading_user_foods.source_food_id is 'FK to foods table if imported from nutrition plan';

comment on column public.carb_loading_user_foods.source_user_food_id is 'FK to user_foods if imported from user custom foods';

comment on column public.carb_loading_user_foods.is_deleted is 'Soft delete flag to preserve meal history';

alter table public.carb_loading_user_foods
    owner to postgres;

create index idx_carb_loading_user_foods_device
    on public.carb_loading_user_foods (device_id);

create index idx_carb_loading_user_foods_deleted
    on public.carb_loading_user_foods (is_deleted);

create index idx_carb_loading_user_foods_barcode
    on public.carb_loading_user_foods (barcode)
    where (barcode IS NOT NULL);

create policy carb_loading_user_foods_device_read on public.carb_loading_user_foods
    as permissive
    for select
    using (device_id = current_setting('app.device_id'::text, true));

create policy carb_loading_user_foods_device_insert on public.carb_loading_user_foods
    as permissive
    for insert
    with check (device_id = current_setting('app.device_id'::text, true));

create policy carb_loading_user_foods_device_update on public.carb_loading_user_foods
    as permissive
    for update
    using (device_id = current_setting('app.device_id'::text, true));

create policy carb_loading_user_foods_device_delete on public.carb_loading_user_foods
    as permissive
    for delete
    using (device_id = current_setting('app.device_id'::text, true));

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_foods to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_foods to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_foods to service_role;

create table public.carb_loading_food_meal_types
(
    carb_loading_food_id uuid    not null
        references public.carb_loading_foods
            on delete cascade,
    meal_type_id         integer not null
        references public.meal_types,
    primary key (carb_loading_food_id, meal_type_id)
);

comment on table public.carb_loading_food_meal_types is 'Links global carb loading foods to meal types (e.g., Cereal → Breakfast)';

alter table public.carb_loading_food_meal_types
    owner to postgres;

create index idx_carb_food_meal_types_food
    on public.carb_loading_food_meal_types (carb_loading_food_id);

create index idx_carb_food_meal_types_meal
    on public.carb_loading_food_meal_types (meal_type_id);

create policy carb_loading_food_meal_types_public_read on public.carb_loading_food_meal_types
    as permissive
    for select
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_food_meal_types to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_food_meal_types to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_food_meal_types to service_role;

create table public.carb_loading_user_food_meal_types
(
    carb_loading_user_food_id uuid    not null
        constraint carb_loading_user_food_meal_type_carb_loading_user_food_id_fkey
            references public.carb_loading_user_foods
            on delete cascade,
    meal_type_id              integer not null
        references public.meal_types,
    primary key (carb_loading_user_food_id, meal_type_id)
);

comment on table public.carb_loading_user_food_meal_types is 'Links user carb loading foods to meal types (e.g., "My Pasta" → Lunch, Dinner)';

alter table public.carb_loading_user_food_meal_types
    owner to postgres;

create index idx_carb_user_food_meal_types_food
    on public.carb_loading_user_food_meal_types (carb_loading_user_food_id);

create index idx_carb_user_food_meal_types_meal
    on public.carb_loading_user_food_meal_types (meal_type_id);

create policy carb_loading_user_food_meal_types_device_read on public.carb_loading_user_food_meal_types
    as permissive
    for select
    using (EXISTS (SELECT 1
                   FROM carb_loading_user_foods
                   WHERE ((carb_loading_user_foods.id = carb_loading_user_food_meal_types.carb_loading_user_food_id) AND
                          (carb_loading_user_foods.device_id = current_setting('app.device_id'::text, true)))));

create policy carb_loading_user_food_meal_types_device_insert on public.carb_loading_user_food_meal_types
    as permissive
    for insert
    with check (EXISTS (SELECT 1
                        FROM carb_loading_user_foods
                        WHERE ((carb_loading_user_foods.id =
                                carb_loading_user_food_meal_types.carb_loading_user_food_id) AND
                               (carb_loading_user_foods.device_id = current_setting('app.device_id'::text, true)))));

create policy carb_loading_user_food_meal_types_device_delete on public.carb_loading_user_food_meal_types
    as permissive
    for delete
    using (EXISTS (SELECT 1
                   FROM carb_loading_user_foods
                   WHERE ((carb_loading_user_foods.id = carb_loading_user_food_meal_types.carb_loading_user_food_id) AND
                          (carb_loading_user_foods.device_id = current_setting('app.device_id'::text, true)))));

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_food_meal_types to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_food_meal_types to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_user_food_meal_types to service_role;

create table public.carb_loading_day_meals
(
    id                        uuid      default gen_random_uuid() not null
        primary key,
    carb_loading_day_id       text                                not null
        references public.carb_loading_days
            on delete cascade,
    meal_type_id              integer                             not null
        references public.meal_types,
    carb_loading_food_id      uuid
        references public.carb_loading_foods,
    carb_loading_user_food_id uuid
        references public.carb_loading_user_foods,
    food_display_name         text,
    quantity                  integer   default 1
        constraint quantity_positive
            check (quantity > 0),
    carbs_consumed            real                                not null
        constraint carbs_positive
            check (carbs_consumed >= (0)::double precision),
    created_at                timestamp default CURRENT_TIMESTAMP,
    updated_at                timestamp default CURRENT_TIMESTAMP,
    constraint one_food_type
        check (((carb_loading_food_id IS NOT NULL) AND (carb_loading_user_food_id IS NULL)) OR
               ((carb_loading_food_id IS NULL) AND (carb_loading_user_food_id IS NOT NULL)))
);

comment on table public.carb_loading_day_meals is 'Actual food selections per meal per day (e.g., Day -2, Breakfast: 2x Cereal, 1x Banana)';

comment on column public.carb_loading_day_meals.quantity is 'Number of servings';

comment on column public.carb_loading_day_meals.carbs_consumed is 'Calculated: quantity * carbs_per_serving';

comment on constraint one_food_type on public.carb_loading_day_meals is 'Ensures exactly one food type is set (either default OR user food, not both)';

alter table public.carb_loading_day_meals
    owner to postgres;

create index idx_carb_day_meals_day
    on public.carb_loading_day_meals (carb_loading_day_id);

create index idx_carb_day_meals_meal_type
    on public.carb_loading_day_meals (meal_type_id);

create index idx_carb_day_meals_food
    on public.carb_loading_day_meals (carb_loading_food_id)
    where (carb_loading_food_id IS NOT NULL);

create index idx_carb_day_meals_user_food
    on public.carb_loading_day_meals (carb_loading_user_food_id)
    where (carb_loading_user_food_id IS NOT NULL);

create policy carb_loading_day_meals_device_read on public.carb_loading_day_meals
    as permissive
    for select
    using (EXISTS (SELECT 1
                   FROM (carb_loading_days d
                       JOIN carb_loading_plans p ON ((p.id = d.carb_loading_plan_id)))
                   WHERE ((d.id = carb_loading_day_meals.carb_loading_day_id) AND
                          (p.user_id = current_setting('app.device_id'::text, true)))));

create policy carb_loading_day_meals_device_insert on public.carb_loading_day_meals
    as permissive
    for insert
    with check (EXISTS (SELECT 1
                        FROM (carb_loading_days d
                            JOIN carb_loading_plans p ON ((p.id = d.carb_loading_plan_id)))
                        WHERE ((d.id = carb_loading_day_meals.carb_loading_day_id) AND
                               (p.user_id = current_setting('app.device_id'::text, true)))));

create policy carb_loading_day_meals_device_update on public.carb_loading_day_meals
    as permissive
    for update
    using (EXISTS (SELECT 1
                   FROM (carb_loading_days d
                       JOIN carb_loading_plans p ON ((p.id = d.carb_loading_plan_id)))
                   WHERE ((d.id = carb_loading_day_meals.carb_loading_day_id) AND
                          (p.user_id = current_setting('app.device_id'::text, true)))));

create policy carb_loading_day_meals_device_delete on public.carb_loading_day_meals
    as permissive
    for delete
    using (EXISTS (SELECT 1
                   FROM (carb_loading_days d
                       JOIN carb_loading_plans p ON ((p.id = d.carb_loading_plan_id)))
                   WHERE ((d.id = carb_loading_day_meals.carb_loading_day_id) AND
                          (p.user_id = current_setting('app.device_id'::text, true)))));

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_day_meals to anon;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_day_meals to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.carb_loading_day_meals to service_role;

create table public.macro_targets_table
(
    id                            text                     not null
        primary key
        constraint macro_targets_table_id_check
            check ((length(id) >= 1) AND (length(id) <= 50)),
    pre_run_carbs_g               numeric                  not null
        constraint check_pre_run_carbs_positive
            check (pre_run_carbs_g >= (0)::numeric),
    pre_run_protein_g             numeric                  not null
        constraint check_pre_run_protein_positive
            check (pre_run_protein_g >= (0)::numeric),
    pre_run_fat_cap_g             numeric                  not null
        constraint check_pre_run_fat_positive
            check (pre_run_fat_cap_g >= (0)::numeric),
    pre_run_fluids_ml             numeric                  not null
        constraint check_pre_run_fluids_positive
            check (pre_run_fluids_ml >= (0)::numeric),
    pre_run_sodium_mg             numeric                  not null
        constraint check_pre_run_sodium_positive
            check (pre_run_sodium_mg >= (0)::numeric),
    during_carb_rate_g_per_h      numeric                  not null
        constraint check_during_carb_rate_positive
            check (during_carb_rate_g_per_h >= (0)::numeric),
    during_carb_total_g           numeric                  not null
        constraint check_during_carb_total_positive
            check (during_carb_total_g >= (0)::numeric),
    during_fluid_rate_ml_per_h    numeric                  not null
        constraint check_during_fluid_rate_positive
            check (during_fluid_rate_ml_per_h >= (0)::numeric),
    during_fluid_total_ml         numeric                  not null
        constraint check_during_fluid_total_positive
            check (during_fluid_total_ml >= (0)::numeric),
    during_sodium_rate_mg_per_h   numeric                  not null
        constraint check_during_sodium_rate_positive
            check (during_sodium_rate_mg_per_h >= (0)::numeric),
    during_sodium_total_mg        numeric                  not null
        constraint check_during_sodium_total_positive
            check (during_sodium_total_mg >= (0)::numeric),
    during_mass_norm_rate_g_per_h numeric,
    post_run_carbs_g              numeric                  not null
        constraint check_post_run_carbs_positive
            check (post_run_carbs_g >= (0)::numeric),
    post_run_protein_g            numeric                  not null
        constraint check_post_run_protein_positive
            check (post_run_protein_g >= (0)::numeric),
    post_run_fluids_ml            numeric                  not null
        constraint check_post_run_fluids_positive
            check (post_run_fluids_ml >= (0)::numeric),
    post_run_sodium_mg            numeric                  not null
        constraint check_post_run_sodium_positive
            check (post_run_sodium_mg >= (0)::numeric),
    distance_mi                   numeric                  not null
        constraint check_distance_positive
            check (distance_mi > (0)::numeric),
    duration_h                    numeric                  not null
        constraint check_duration_positive
            check (duration_h > (0)::numeric),
    pace_min_per_mile             numeric                  not null
        constraint check_pace_positive
            check (pace_min_per_mile > (0)::numeric),
    calories_gross_kcal           numeric                  not null
        constraint check_calories_positive
            check (calories_gross_kcal >= (0)::numeric),
    met                           numeric                  not null
        constraint check_met_positive
            check (met > (0)::numeric),
    calculation_rule              text                     not null,
    timestamp                     timestamp                not null,
    is_user_modified              boolean default false    not null,
    modified_fields               text    default ''::text not null
);

comment on table public.macro_targets_table is 'Calculated nutrition targets for running sessions (26 columns)';

comment on column public.macro_targets_table.id is 'Unique identifier for this macro target set';

comment on column public.macro_targets_table.calculation_rule is 'Algorithm version/rule used for calculations';

comment on column public.macro_targets_table.is_user_modified is 'Whether user has manually adjusted these targets';

comment on column public.macro_targets_table.modified_fields is 'Comma-separated list of user-modified field names';

alter table public.macro_targets_table
    owner to postgres;

create index idx_macro_targets_timestamp
    on public.macro_targets_table (timestamp);

create index idx_macro_targets_distance
    on public.macro_targets_table (distance_mi);

create policy macro_targets_public_read on public.macro_targets_table
    as permissive
    for select
    using true;

create policy macro_targets_authenticated_insert on public.macro_targets_table
    as permissive
    for insert
    with check true;

create policy macro_targets_authenticated_update on public.macro_targets_table
    as permissive
    for update
    using true;

grant delete, insert, references, select, trigger, truncate, update on public.macro_targets_table to anon;

grant delete, insert, references, select, trigger, truncate, update on public.macro_targets_table to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.macro_targets_table to service_role;

create table public.workout_notes
(
    id         text      not null
        primary key,
    user_id    uuid      not null
        constraint fk_workout_notes_user
            references public.users
            on delete cascade,
    plan_id    text,
    note_text  text      not null,
    rating     integer
        constraint workout_notes_rating_check
            check ((rating IS NULL) OR ((rating >= 1) AND (rating <= 5))),
    created_at timestamp not null,
    updated_at timestamp not null
);

comment on table public.workout_notes is 'User workout journal entries with optional ratings';

comment on column public.workout_notes.user_id is 'References users.id (not device_id)';

comment on column public.workout_notes.plan_id is 'Optional reference to nutrition_plans.id';

comment on column public.workout_notes.rating is 'Optional 1-5 scale rating';

alter table public.workout_notes
    owner to postgres;

create index idx_workout_notes_user
    on public.workout_notes (user_id);

create index idx_workout_notes_plan
    on public.workout_notes (plan_id)
    where (plan_id IS NOT NULL);

create index idx_workout_notes_created
    on public.workout_notes (created_at);

create policy workout_notes_user_read on public.workout_notes
    as permissive
    for select
    using (user_id = (current_setting('app.user_id'::text, true))::uuid);

create policy workout_notes_user_insert on public.workout_notes
    as permissive
    for insert
    with check (user_id = (current_setting('app.user_id'::text, true))::uuid);

create policy workout_notes_user_update on public.workout_notes
    as permissive
    for update
    using (user_id = (current_setting('app.user_id'::text, true))::uuid);

create policy workout_notes_user_delete on public.workout_notes
    as permissive
    for delete
    using (user_id = (current_setting('app.user_id'::text, true))::uuid);

grant delete, insert, references, select, trigger, truncate, update on public.workout_notes to anon;

grant delete, insert, references, select, trigger, truncate, update on public.workout_notes to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.workout_notes to service_role;

create table public.feature_survey_responses
(
    id                text                                not null
        primary key,
    device_id         text                                not null
        constraint unique_device_vote
            unique,
    selected_features text                                not null,
    voted_at          timestamp default CURRENT_TIMESTAMP not null
);

comment on table public.feature_survey_responses is 'Stores user votes for feature requests. One vote per device.';

comment on column public.feature_survey_responses.id is 'Primary key - UUID';

comment on column public.feature_survey_responses.device_id is 'Device ID of the user who voted';

comment on column public.feature_survey_responses.selected_features is 'JSON array of selected feature IDs (exactly 3). Example: ["shopping_list", "coach_sharing", "recipes"]';

comment on column public.feature_survey_responses.voted_at is 'Timestamp of when the vote was cast';

alter table public.feature_survey_responses
    owner to postgres;

create index idx_feature_survey_responses_device_id
    on public.feature_survey_responses (device_id);

create index idx_feature_survey_responses_voted_at
    on public.feature_survey_responses (voted_at);

create policy "Anyone can insert feature survey votes" on public.feature_survey_responses
    as permissive
    for insert
    to anon, authenticated
    with check true;

create policy "Anyone can read feature survey votes" on public.feature_survey_responses
    as permissive
    for select
    to anon, authenticated
    using true;

create policy "Service role full access to feature survey votes" on public.feature_survey_responses
    as permissive
    for all
    to service_role
    using true
with check true;

grant delete, insert, references, select, trigger, truncate, update on public.feature_survey_responses to anon;

grant delete, insert, references, select, trigger, truncate, update on public.feature_survey_responses to authenticated;

grant delete, insert, references, select, trigger, truncate, update on public.feature_survey_responses to service_role;

