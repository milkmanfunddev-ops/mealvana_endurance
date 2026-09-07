-- Meal planning (Vana) — library, plans, memories, unified search.
-- Idempotent. Applied to DEV with `supabase db query --linked -f` on 2026-08-27 (migration history drifted).
-- Design: docs/new_mealplanning/synthesis-and-recommendations.md §7 + walkthrough.md

create extension if not exists vector;

-- ---------------------------------------------------------------- meal_library
create table if not exists public.meal_library (
  id              text primary key,                              -- 'D-048'
  name            text not null,
  meal_type       text not null check (meal_type in ('breakfast','lunch','dinner','snack')),
  contexts        text[] not null default '{}',                  -- everyday|pre-session|recovery|rest-day|race-week|carb-load|travel
  cuisine         text,
  ingredients     text not null,                                  -- as written, with portions
  ingredients_json jsonb not null default '[]'::jsonb,            -- [{name, qty}] parsed
  diets_ok        dietary_preference_enum[] not null default '{}',
  excluded_diets  dietary_preference_enum[] not null default '{}',
  allergens       allergy_enum[] not null default '{}',
  swaps           text,
  kcal            integer,
  carbs_g         numeric,
  protein_g       numeric,
  fat_g           numeric,
  prep            text,
  prep_minutes    integer,
  batch           boolean not null default false,
  servings        integer not null default 1,
  source          text,
  why             text,
  search_text     text generated always as (name || ' ' || coalesce(why,'') || ' ' || ingredients || ' ' || coalesce(cuisine,'')) stored,
  embedding       vector(1536),
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists meal_library_type_idx      on public.meal_library (meal_type) where is_active;
create index if not exists meal_library_contexts_idx  on public.meal_library using gin (contexts);
create index if not exists meal_library_allergens_idx on public.meal_library using gin (allergens);
create index if not exists meal_library_search_trgm   on public.meal_library using gin (search_text gin_trgm_ops);
create index if not exists meal_library_embedding_idx on public.meal_library using hnsw (embedding vector_cosine_ops);

alter table public.meal_library enable row level security;
drop policy if exists "meal_library read" on public.meal_library;
create policy "meal_library read" on public.meal_library for select to authenticated, anon using (is_active);

-- ---------------------------------------------------------------- saved_meals: make the user's own meals searchable alongside the library
alter table public.saved_meals add column if not exists embedding       vector(1536);
alter table public.saved_meals add column if not exists library_meal_id text references public.meal_library(id) on delete set null;
alter table public.saved_meals add column if not exists meal_types      text[] not null default '{}';
alter table public.saved_meals add column if not exists batch           boolean;
create index if not exists saved_meals_embedding_idx on public.saved_meals using hnsw (embedding vector_cosine_ops);

-- ---------------------------------------------------------------- meal_plans / plan_meals
create table if not exists public.meal_plans (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references public.users(id) on delete cascade,
  week_start     date not null,
  status         text not null default 'draft' check (status in ('draft','confirmed','archived')),
  batch_cooking  boolean not null default true,
  rules          jsonb not null default '[]'::jsonb,   -- [{day:'fri', rule:'race-eve plate', meal_id:'D-002'}]
  shopping       jsonb not null default '[]'::jsonb,   -- [{aisle, name, qty, checked, have}]
  brief          text,                                 -- Vana's week brief, one line
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  is_deleted     boolean not null default false,
  unique (user_id, week_start)
);
create table if not exists public.plan_meals (
  id               uuid primary key default gen_random_uuid(),
  plan_id          uuid not null references public.meal_plans(id) on delete cascade,
  user_id          uuid not null references public.users(id) on delete cascade,
  source           text not null check (source in ('library','saved')),
  library_meal_id  text references public.meal_library(id),
  saved_meal_id    uuid references public.saved_meals(id),
  name             text not null,
  meal_type        text not null check (meal_type in ('breakfast','lunch','dinner','snack')),
  session          text,                                -- 'cook-sun' | 'topup-wed' | 'fresh-fri' | null when batch off
  servings         integer not null default 1,
  servings_left    integer not null default 1,
  kcal             integer, carbs_g numeric, protein_g numeric, fat_g numeric,
  swaps_applied    jsonb not null default '[]'::jsonb,
  comments         jsonb not null default '[]'::jsonb,   -- [{role:'user'|'vana', text, at}]
  position         integer not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);
create index if not exists plan_meals_plan_idx on public.plan_meals (plan_id);
alter table public.meal_plans enable row level security;
alter table public.plan_meals enable row level security;
drop policy if exists "meal_plans owner" on public.meal_plans;
create policy "meal_plans owner" on public.meal_plans for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "plan_meals owner" on public.plan_meals;
create policy "plan_meals owner" on public.plan_meals for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------- meal_logs: log from the plan
alter table public.meal_logs add column if not exists plan_meal_id uuid references public.plan_meals(id) on delete set null;
alter table public.meal_logs drop constraint if exists meal_logs_source_check;
alter table public.meal_logs add constraint meal_logs_source_check
  check (source = any (array['photo','manual','describe','saved','recipe','jade_baseline','plan']));

-- ---------------------------------------------------------------- user_memories ("What Vana knows")
create table if not exists public.user_memories (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.users(id) on delete cascade,
  kind              text not null check (kind in ('preference','constraint','pattern','episode','setting')),
  key               text,                     -- for settings: 'batch_cooking', 'show_macros'
  fact              text not null,
  value             jsonb,
  confidence        numeric not null default 0.8,
  source            text not null default 'conversation',   -- conversation | inferred | settings
  embedding         vector(1536),
  created_at        timestamptz not null default now(),
  last_confirmed_at timestamptz not null default now(),
  expires_at        timestamptz,
  is_deleted        boolean not null default false
);
create index if not exists user_memories_user_idx on public.user_memories (user_id) where not is_deleted;
create unique index if not exists user_memories_setting_key on public.user_memories (user_id, key) where kind = 'setting' and not is_deleted;
create index if not exists user_memories_embedding_idx on public.user_memories using hnsw (embedding vector_cosine_ops);
alter table public.user_memories enable row level security;
drop policy if exists "user_memories owner" on public.user_memories;
create policy "user_memories owner" on public.user_memories for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ---------------------------------------------------------------- search_meals: ONE call, hard filters first, vector rank, saved + library together
drop function if exists public.search_meals(uuid,text,vector,text,text[],boolean,boolean,integer);
create or replace function public.search_meals(
  p_user_id        uuid,
  p_query          text default null,
  p_embedding      vector(1536) default null,
  p_meal_type      text default null,
  p_contexts       text[] default null,       -- any-of
  p_batch          boolean default null,
  p_include_saved  boolean default true,
  p_limit          integer default 12,
  p_exclude_allergens allergy_enum[] default null,   -- query-time ("without nuts"), on top of the user's allergies
  p_require_diet   dietary_preference_enum default null -- query-time ("vegan"), on top of the user's diet
)
returns table (
  source text, id text, name text, meal_type text, contexts text[], batch boolean, prep_minutes integer,
  kcal integer, carbs_g numeric, protein_g numeric, fat_g numeric, allergens text[], diets_ok text[],
  swaps text, why text, attribution text, ingredients text, library_meal_id text, score real
)
language sql stable security invoker as $$
  with me as (
    select coalesce(u.allergies, '{}'::allergy_enum[]) as allergies, u.dietary_preference as diet
    from public.users u where u.id = p_user_id
  ),
  lib as (
    select 'library'::text as source, m.id, m.name, m.meal_type, m.contexts, m.batch, m.prep_minutes,
           m.kcal, m.carbs_g, m.protein_g, m.fat_g,
           m.allergens::text[] as allergens, m.diets_ok::text[] as diets_ok,
           m.swaps, m.why, m.source as attribution, m.ingredients, m.id as library_meal_id,
           (case when p_embedding is not null and m.embedding is not null then 1 - (m.embedding <=> p_embedding)
                 when p_query is not null then greatest(similarity(m.name, p_query), word_similarity(p_query, m.search_text))
                 else 0.5 end)::real as score
    from public.meal_library m, me
    where m.is_active
      and (p_meal_type is null or m.meal_type = p_meal_type)
      and (p_contexts is null or m.contexts && p_contexts)
      and (p_batch is null or m.batch = p_batch)
      and not (m.allergens && me.allergies)                                   -- HARD: allergies
      and (p_exclude_allergens is null or not (m.allergens && p_exclude_allergens))
      and (me.diet is null or not (m.excluded_diets @> array[me.diet]))       -- HARD: diet
      and (p_require_diet is null or m.diets_ok @> array[p_require_diet])
  ),
  mine as (
    select 'saved'::text as source, s.id::text, s.name,
           coalesce(p_meal_type, coalesce(s.meal_types[1], 'dinner')) as meal_type,
           '{}'::text[] as contexts, coalesce(s.batch, false) as batch, null::integer as prep_minutes,
           s.calories as kcal, s.carbs_g, s.protein_g, s.fat_g,
           '{}'::text[] as allergens, '{}'::text[] as diets_ok,
           l.swaps, coalesce(l.why, 'one of your saved meals') as why, 'your saved meal' as attribution,
           (select string_agg(coalesce(i->>'name', i->>'food_name', ''), ', ') from jsonb_array_elements(s.items) i) as ingredients,
           s.library_meal_id,
           (0.15 + case when p_embedding is not null and s.embedding is not null then 1 - (s.embedding <=> p_embedding)
                        when p_query is not null then similarity(s.name, p_query)
                        else 0.5 end)::real as score                         -- saved meals rank first
    from public.saved_meals s
    left join public.meal_library l on l.id = s.library_meal_id
    where p_include_saved and s.user_id = p_user_id and not s.is_deleted
      and (p_meal_type is null or s.meal_types = '{}' or s.meal_types @> array[p_meal_type])
      and (p_batch is null or coalesce(s.batch, false) = p_batch or s.batch is null)
  )
  select * from (select * from mine union all select * from lib) x
  order by score desc
  limit p_limit;
$$;
grant execute on function public.search_meals to authenticated, service_role;

-- ---------------------------------------------------------------- match_library: nearest library meal for a free-text meal (staples matching)
create or replace function public.match_library(p_embedding vector(1536), p_meal_type text default null, p_limit integer default 3)
returns table (id text, name text, meal_type text, score real)
language sql stable as $$
  select m.id, m.name, m.meal_type, (1 - (m.embedding <=> p_embedding))::real as score
  from public.meal_library m
  where m.is_active and m.embedding is not null and (p_meal_type is null or m.meal_type = p_meal_type)
  order by m.embedding <=> p_embedding
  limit p_limit;
$$;
grant execute on function public.match_library to authenticated, service_role;

-- ---------------------------------------------------------------- recall_memories
create or replace function public.recall_memories(p_user_id uuid, p_embedding vector(1536), p_limit integer default 8)
returns table (id uuid, kind text, key text, fact text, value jsonb, confidence numeric, last_confirmed_at timestamptz, score real)
language sql stable as $$
  select m.id, m.kind, m.key, m.fact, m.value, m.confidence, m.last_confirmed_at,
         (case when m.embedding is null then 0.3 else 1 - (m.embedding <=> p_embedding) end)::real as score
  from public.user_memories m
  where m.user_id = p_user_id and not m.is_deleted and (m.expires_at is null or m.expires_at > now())
  order by score desc, m.last_confirmed_at desc
  limit p_limit;
$$;
grant execute on function public.recall_memories to authenticated, service_role;
