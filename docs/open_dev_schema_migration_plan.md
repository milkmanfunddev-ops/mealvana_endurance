
# Open-Dev Schema Refactor — Migration Plan (Mealvana / Supabase)

---

## Conversation Summary (Decisions & Rationale)

**Date:** Nov 7, 2025 (America/Chicago)  
**Context:** Pre‑launch, DEV‑only posture. Prioritize simplicity and momentum over security hardening.

### Identity & Ownership
- Keep `users.id (uuid)` as the **one true user identifier**.
- Add `user_id uuid not null` to all user‑scoped tables and backfill from `users.device_id` where necessary.
- Keep `users.device_id text unique` as metadata only (no future FKs).

### Primary Keys & IDs
- Convert legacy **text PKs** to **auto‑increment `bigserial`** (e.g., `activities`, `events`, `carb_loading_plans`, `carb_loading_days`, `workout_notes`, `feature_survey_responses`).
- Keep existing `uuid` PKs where already used.

### Events & Activities
- `events.activity_id` remains **nullable**; enforce **≤1 event per activity** with a unique index on non‑nulls.

### Access Model (DEV)
- **Remove RLS entirely** and **drop all policies**.
- Use **permissive grants** for `anon`, `authenticated`, and `service_role` to unblock iteration.
- Security will be re‑introduced later (auth + RLS with `auth.uid()`).

### Data Modeling Simplification
- Replace join tables with **enum arrays**:
  - `foods.categories category_enum[]` and `user_foods.categories category_enum[]` with values: `before_run | during_run | after_run`.
  - `foods.activity_types sport_enum[]` and `user_foods.activity_types sport_enum[]` with values: `running | cycling | swimming`.
- **Drop** suitability JSON/booleans (`suitable_for_activities`, `*_suitable`, `run_portable`, `requires_preparation`, `aid_station_available`).
- **Keep** on `foods`: `is_other_food`, `to_exclude_from_solver`, `is_essential`, `show_in_preferences`.
- Mirror the same structure and pruning on `user_foods`.
- Add GIN indexes on new array columns for fast `@>` queries.

### Tables to Drop Now
- `activity_completions`, `edge_functions`, `food_categories`, `user_hidden_foods`, `user_food_categories`, `carb_loading_user_food_meal_types`, `carb_loading_food_meal_types`, `categories`, `meal_types`.

### Timestamps & Triggers
- Standardize all time columns to **`timestamp`** (no time zone). Treat stored data as UTC during conversion.
- **Remove** `update_updated_at`‑style triggers for now.

### Offline‑First Behavior
- **Phone wins** (client last write wins). Keep `needs_upload`, `local_updated_at`, and optionally `client_updated_at` on all user‑mutable tables.

### Open Questions (non‑blocking)
- Drop `preference_priority` on `foods` now? (Default is: keep unless requested.)
- Keep `is_electrolyte` on `user_foods` or mirror `foods` exactly? (Default: mirror `foods` unless requested.)

---

## High-level decisions (confirmed)

- **Identity:** `users.id UUID` remains the canonical user identifier. Every user-scoped table gets `user_id UUID NOT NULL` FK to `users(id)` and stops using `device_id` for ownership (you may keep `users.device_id TEXT UNIQUE` as metadata).
- **PK style:** Convert specific `TEXT` PKs to **`BIGSERIAL`** (auto-increment). Keep existing `UUID` PKs elsewhere.
- **RLS:** **Disabled everywhere**; all RLS policies dropped.
- **Grants:** **Permissive** grants to `anon`, `authenticated`, and `service_role` so things “just work.”
- **Enums:** Use enums for finite sets (gender, units, sports, statuses, etc.).
- **Arrays over joins:** Replace `categories` and `suitability` join/flags with **enum arrays** on `foods` & `user_foods`.
- **Drops:** Remove tables you listed that we no longer need.
- **Timestamps:** Standardize to **`timestamp`** (no time zone) across the schema.
- **Triggers:** Remove `update_updated_at` (and similar) triggers for now.
- **Offline-first:** Phone “wins” in conflicts (client last write wins). Keep `needs_upload`, `local_updated_at`, optional `client_updated_at` consistently on user-mutable tables.

---

## Ordered migration outline

Run these in order (idempotent-safe with `IF EXISTS/IF NOT EXISTS` where possible). Use transactions per step where appropriate.

### 0) Prep: Extensions (if needed)
```sql
-- Needed for UUID defaults if not already enabled
create extension if not exists "pgcrypto";
```

### 1) Create enums

Adjust as needed; these reflect your current finite sets.

```sql
-- Users
do $$ begin
  create type gender_enum as enum ('male','female','other','unknown');
exception when duplicate_object then null; end $$;

-- Units
do $$ begin
  create type distance_unit_enum as enum ('miles','kilometers');
exception when duplicate_object then null; end $$;
do $$ begin
  create type pace_unit_enum as enum ('min_per_mile','min_per_km');
exception when duplicate_object then null; end $$;

-- Gut training
do $$ begin
  create type gut_training_enum as enum ('low','moderate','high');
exception when duplicate_object then null; end $$;

-- Sports / activities
do $$ begin
  create type sport_enum as enum ('running','cycling','swimming');
exception when duplicate_object then null; end $$;
do $$ begin
  create type activity_status_enum as enum ('planned','in_progress','completed','skipped');
exception when duplicate_object then null; end $$;
do $$ begin
  create type intensity_enum as enum ('easy','moderate','hard','race');
exception when duplicate_object then null; end $$;
do $$ begin
  create type cycling_terrain_enum as enum ('flat','rolling','hilly');
exception when duplicate_object then null; end $$;
do $$ begin
  create type indoor_outdoor_enum as enum ('indoor','outdoor');
exception when duplicate_object then null; end $$;
do $$ begin
  create type cycling_goal_enum as enum ('endurance','tempo','intervals');
exception when duplicate_object then null; end $$;

-- Plan type
do $$ begin
  create type plan_type_enum as enum ('standard','carb_loading','recovery');
exception when duplicate_object then null; end $$;

-- Food categories (UI tags) and meal types
do $$ begin
  create type category_enum as enum ('before_run','during_run','after_run');
exception when duplicate_object then null; end $$;
do $$ begin
  create type meal_type_enum as enum ('breakfast','morning_snack','lunch','afternoon_snack','dinner','evening_snack','snacks');
exception when duplicate_object then null; end $$;
```

### 2) Users: keep UUID identity, convert option columns to enums

```sql
-- Ensure users.id is UUID PK (it already is); keep device_id as unique metadata
alter table public.users
  alter column id set data type uuid using id::uuid;

alter table public.users
  alter column gender type gender_enum using (gender::gender_enum),
  alter column preferred_distance_unit type distance_unit_enum using (preferred_distance_unit::distance_unit_enum),
  alter column preferred_pace_unit type pace_unit_enum using (preferred_pace_unit::pace_unit_enum),
  alter column gut_training_level type gut_training_enum using (gut_training_level::gut_training_enum);
```

### 3) Add `user_id uuid not null` to user-scoped tables and backfill

> **Pattern:** add `user_id`, backfill from either `device_id` (via `users.device_id`) or from a legacy `user_id text`, then make it `NOT NULL` and add FK.

#### 3.1 Activities (convert PK to BIGSERIAL; user link to UUID)
```sql
-- Add new user_id
alter table public.activities add column if not exists user_id uuid;

-- Backfill: activities.user_id (TEXT) may refer to users.id or users.device_id
update public.activities a
set user_id = a.user_id::uuid
where a.user_id ~ '^[0-9a-fA-F-]{36}$' and a.user_id is not null; -- looks like UUID

update public.activities a
set user_id = u.id
from public.users u
where a.user_id is not null
  and (a.user_id !~ '^[0-9a-fA-F-]{36}$') -- not a UUID
  and a.user_id = u.device_id;

alter table public.activities
  alter column user_id set not null,
  add constraint activities_user_fk foreign key (user_id) references public.users(id) on delete cascade;

-- Convert PK to BIGSERIAL
alter table public.activities add column if not exists id_new bigserial;
update public.activities set id_new = nextval(pg_get_serial_sequence('public.activities','id_new')) where id_new is null;
alter table public.activities drop constraint if exists activities_pkey;
alter table public.activities add constraint activities_pkey primary key (id_new);
alter table public.activities drop column if exists id;
alter table public.activities rename column id_new to id;

create index if not exists idx_activities_user on public.activities(user_id);
create index if not exists idx_activities_scheduled on public.activities(scheduled_date_time);
```

#### 3.2 Nutrition plans (user-owned; keep `activity_id` link later)
```sql
alter table public.nutrition_plans add column if not exists user_id uuid;

update public.nutrition_plans np
set user_id = u.id
from public.users u
where np.device_id = u.device_id and (np.user_id is distinct from u.id);

alter table public.nutrition_plans
  alter column user_id set not null,
  add constraint fk_np_user foreign key (user_id) references public.users(id) on delete cascade;

create index if not exists idx_np_user on public.nutrition_plans(user_id);
```

#### 3.3 User foods
```sql
alter table public.user_foods add column if not exists user_id uuid;

update public.user_foods uf
set user_id = u.id
from public.users u
where uf.device_id = u.device_id and (uf.user_id is distinct from u.id);

alter table public.user_foods
  alter column user_id set not null,
  add constraint fk_user_foods_user foreign key (user_id) references public.users(id) on delete cascade;

create index if not exists idx_user_foods_user on public.user_foods(user_id);
```

#### 3.4 Carb-loading user foods
```sql
alter table public.carb_loading_user_foods add column if not exists user_id uuid;

update public.carb_loading_user_foods cf
set user_id = u.id
from public.users u
where cf.device_id = u.device_id and (cf.user_id is distinct from u.id);

alter table public.carb_loading_user_foods
  alter column user_id set not null,
  add constraint fk_cl_user_foods_user foreign key (user_id) references public.users(id) on delete cascade;

create index if not exists idx_cl_user_foods_user on public.carb_loading_user_foods(user_id);
```

#### 3.5 Carb-loading plans & days (will also change their PK to BIGSERIAL later)
```sql
alter table public.carb_loading_plans add column if not exists user_id uuid;
update public.carb_loading_plans p
set user_id = u.id
from public.users u
where p.user_id = u.device_id or p.user_id = u.id::text; -- covers legacy text storage
alter table public.carb_loading_plans alter column user_id set not null;
create index if not exists idx_cl_plans_user on public.carb_loading_plans(user_id);
```

#### 3.6 Workout notes
```sql
alter table public.workout_notes add column if not exists user_id_uuid uuid;

update public.workout_notes wn set user_id_uuid = wn.user_id
where wn.user_id is not null and (wn.user_id_uuid is distinct from wn.user_id);

alter table public.workout_notes drop constraint if exists fk_workout_notes_user;
alter table public.workout_notes drop column if exists user_id;
alter table public.workout_notes rename column user_id_uuid to user_id;
alter table public.workout_notes add constraint fk_workout_notes_user foreign key (user_id) references public.users(id) on delete cascade;

create index if not exists idx_workout_notes_user on public.workout_notes(user_id);
```

#### 3.7 Feature survey responses
```sql
alter table public.feature_survey_responses add column if not exists user_id uuid;
update public.feature_survey_responses fs
set user_id = u.id
from public.users u
where fs.device_id = u.device_id and (fs.user_id is distinct from u.id);
```

> Repeat the “add `user_id` → backfill from device_id → set NOT NULL → add FK + index” pattern for any other user-scoped tables you see in your schema.

---

### 4) Replace join tables & suitability flags with enum arrays

#### 4.1 Foods

Add arrays:
```sql
alter table public.foods
  add column if not exists categories category_enum[] default '{}',
  add column if not exists activity_types sport_enum[] default '{}';

create index if not exists idx_foods_categories_gin on public.foods using gin (categories);
create index if not exists idx_foods_activity_types_gin on public.foods using gin (activity_types);
```

Drop obsolete flags/JSONB:
```sql
alter table public.foods
  drop column if exists suitable_for_activities,
  drop column if exists cycling_suitable,
  drop column if exists swimming_suitable,
  drop column if exists before_run_suitable,
  drop column if exists during_run_suitable,
  drop column if exists after_run_suitable,
  drop column if exists run_portable,
  drop column if exists requires_preparation,
  drop column if exists aid_station_available;
-- Keep: is_other_food, to_exclude_from_solver, is_essential, show_in_preferences
```

#### 4.2 User foods (mirror)

```sql
alter table public.user_foods
  add column if not exists categories category_enum[] default '{}',
  add column if not exists activity_types sport_enum[] default '{}';

create index if not exists idx_user_foods_categories_gin on public.user_foods using gin (categories);
create index if not exists idx_user_foods_activity_types_gin on public.user_foods using gin (activity_types);
```

#### 4.3 Drop join tables & lookup tables

```sql
drop table if exists public.food_categories cascade;
drop table if exists public.user_food_categories cascade;
drop table if exists public.categories cascade;

drop table if exists public.carb_loading_user_food_meal_types cascade;
drop table if exists public.carb_loading_food_meal_types cascade;
drop table if exists public.meal_types cascade;
```

---

### 5) Events & activity links

- Keep `events.activity_id` **nullable**.
- Enforce at most one event per activity:

```sql
-- Convert events PK to BIGSERIAL
alter table public.events add column if not exists id_new bigserial;
update public.events set id_new = nextval(pg_get_serial_sequence('public.events','id_new')) where id_new is null;
alter table public.events drop constraint if exists events_pkey;
alter table public.events add constraint events_pkey primary key (id_new);
alter table public.events drop column if exists id;
alter table public.events rename column id_new to id;

-- Unique index on non-null activity links
drop index if exists uq_events_activity_id;
create unique index if not exists uq_events_activity_nonnull on public.events(activity_id) where activity_id is not null;
```

> Ensure any FKs pointing to `events.id` are updated to BIGINT (see Section 6).

---

### 6) Convert other TEXT PKs to BIGSERIAL & fix dependent FKs

Do these **in dependency order**. Example set below; adjust for your schema.

#### 6.1 Activities — already converted in 3.1

#### 6.2 Carb-loading plans & days
```sql
-- Plans
alter table public.carb_loading_plans add column if not exists id_new bigserial;
update public.carb_loading_plans set id_new = nextval(pg_get_serial_sequence('public.carb_loading_plans','id_new')) where id_new is null;
alter table public.carb_loading_plans drop constraint if exists carb_loading_plans_pkey;
alter table public.carb_loading_plans add constraint carb_loading_plans_pkey primary key (id_new);

-- Update FKs from carb_loading_days to new id
alter table public.carb_loading_days drop constraint if exists cl_days_plan_fk;
alter table public.carb_loading_days add column if not exists carb_loading_plan_id_new bigint;
update public.carb_loading_days d
set carb_loading_plan_id_new = p.id_new
from public.carb_loading_plans p
where d.carb_loading_plan_id = p.id; -- old text

alter table public.carb_loading_days drop column if exists carb_loading_plan_id;
alter table public.carb_loading_days rename column carb_loading_plan_id_new to carb_loading_plan_id;
alter table public.carb_loading_days add constraint cl_days_plan_fk foreign key (carb_loading_plan_id) references public.carb_loading_plans(id);

-- Swap columns on plans
alter table public.carb_loading_plans drop column if exists id;
alter table public.carb_loading_plans rename column id_new to id;

-- Days PK
alter table public.carb_loading_days add column if not exists id_new bigserial;
update public.carb_loading_days set id_new = nextval(pg_get_serial_sequence('public.carb_loading_days','id_new')) where id_new is null;
alter table public.carb_loading_days drop constraint if exists carb_loading_days_pkey;
alter table public.carb_loading_days add constraint carb_loading_days_pkey primary key (id_new);
alter table public.carb_loading_days drop column if exists id;
alter table public.carb_loading_days rename column id_new to id;
```

#### 6.3 Carb-loading day meals (optional: keep UUID or convert too)

If you prefer uniform BIGSERIAL here too, repeat the add/swap pattern.

#### 6.4 Workout notes
```sql
alter table public.workout_notes add column if not exists id_new bigserial;
update public.workout_notes set id_new = nextval(pg_get_serial_sequence('public.workout_notes','id_new')) where id_new is null;
alter table public.workout_notes drop constraint if exists workout_notes_pkey;
alter table public.workout_notes add constraint workout_notes_pkey primary key (id_new);
alter table public.workout_notes drop column if exists id;
alter table public.workout_notes rename column id_new to id;
```

#### 6.5 Feature survey responses
```sql
alter table public.feature_survey_responses add column if not exists id_new bigserial;
update public.feature_survey_responses set id_new = nextval(pg_get_serial_sequence('public.feature_survey_responses','id_new')) where id_new is null;
alter table public.feature_survey_responses drop constraint if exists feature_survey_responses_pkey;
alter table public.feature_survey_responses add constraint feature_survey_responses_pkey primary key (id_new);
alter table public.feature_survey_responses drop column if exists id;
alter table public.feature_survey_responses rename column id_new to id;
```

> **Adjust any other TEXT PK tables similarly**. Rebuild dependent FKs by adding new bigint columns, backfilling, then swapping.

---

### 7) Drop deprecated tables

```sql
drop table if exists public.activity_completions cascade;
drop table if exists public.edge_functions cascade;
drop table if exists public.user_hidden_foods cascade;
-- food_categories, user_food_categories, carb_loading_user_food_meal_types, carb_loading_food_meal_types, categories, meal_types already handled in Section 4.3
```

If you identify other unused tables, add them here.

---

### 8) Convert all time columns to `timestamp`

> 📝 Converting from `timestamptz` to `timestamp` **drops time zone**. Use a consistent convention (e.g., store UTC as naive `timestamp`) and convert app-side when displaying.

Pattern per table/column (repeat as needed):
```sql
alter table public.activities
  alter column created_at type timestamp using (created_at at time zone 'UTC'),
  alter column updated_at type timestamp using (updated_at at time zone 'UTC'),
  alter column scheduled_date_time type timestamp using (scheduled_date_time at time zone 'UTC');
```

Apply the same to every `timestamptz` column across your tables (`created_at`, `updated_at`, `client_updated_at`, `local_updated_at`, etc.).

---

### 9) Remove triggers & RLS

```sql
-- Drop common updated_at triggers (repeat per table if present)
drop trigger if exists update_users_updated_at on public.users;
drop trigger if exists update_app_content_updated_at on public.app_content;
-- ... add any other update_* triggers you have

-- Disable and drop RLS & policies everywhere
alter table public.users disable row level security;
alter table public.app_content disable row level security;
alter table public.foods disable row level security;
alter table public.user_foods disable row level security;
alter table public.food_preferences disable row level security;
alter table public.activities disable row level security;
alter table public.events disable row level security;
alter table public.nutrition_plans disable row level security;
alter table public.carb_loading_plans disable row level security;
alter table public.carb_loading_days disable row level security;
alter table public.carb_loading_day_meals disable row level security;
alter table public.workout_notes disable row level security;
alter table public.carb_loading_foods disable row level security;
alter table public.feature_survey_responses disable row level security;

-- Example policy drops (repeat as needed; safe if policy doesn't exist)
drop policy if exists "Users can read own data" on public.users;
drop policy if exists "Users can insert own data" on public.users;
drop policy if exists "Users can update own data" on public.users;
-- Add DROP POLICY lines for other tables that previously had policies
```

> Tip: You can script policy drops by querying `pg_policies` to generate `DROP POLICY` commands automatically.

---

### 10) Permissive grants (DEV only)

```sql
-- Tables
grant select, insert, update, delete, truncate, references, trigger on all tables in schema public to anon;
grant select, insert, update, delete, truncate, references, trigger on all tables in schema public to authenticated;
grant select, insert, update, delete, truncate, references, trigger on all tables in schema public to service_role;

-- Sequences (needed for BIGSERIAL nextval)
grant usage, select, update on all sequences in schema public to anon;
grant usage, select, update on all sequences in schema public to authenticated;
grant usage, select, update on all sequences in schema public to service_role;
```

> In Supabase, `service_role` always has full access via the secret key, but keeping consistent grants helps local tooling.

---

## Post-migration housekeeping

- ✅ Re-run your codegen/types (if you use Supabase client/typegen).
- ✅ Verify FK integrity for any tables that referenced IDs you changed (especially `events.activity_id`, `carb_loading_days -> carb_loading_plans`).
- ✅ Update client code:
  - Use `user_id UUID` for all user-owned reads/writes.
  - Use `id BIGINT` for the tables converted to auto-increment PKs.
  - Fill `categories` and `activity_types` arrays appropriately in create/update forms.
- ✅ Ensure sync flows set/clear `needs_upload` and update `local_updated_at` consistently. With “phone wins,” let client send a `client_updated_at` you compare server-side only if/when you later add conflict checks.

---

## Rollback notes (if needed)

- Keep old ID columns in a branch until you’re confident.
- You can re-enable RLS later and restore hardened policies using `auth.uid()` once you add authentication.
- If you want to keep time zones later, reverse the `timestamp` conversions with `type timestamptz using (col at time zone 'UTC')` appropriately.

---

## Questions left open (non‑blocking)

- Do you want to **drop `preference_priority`** on `foods` now?
- Should `is_electrolyte` remain on `user_foods`? (Mirror exact set you keep on `foods` or trim for now.)

---

**End of migration plan.**
