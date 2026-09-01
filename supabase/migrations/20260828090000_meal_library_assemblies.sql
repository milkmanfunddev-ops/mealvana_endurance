-- meal_library: recipes AND assemblies in one table (kind), + pattern/frequency/evidence, + pair co-occurrence
-- for anti-hallucination. Idempotent. Design: docs/new_mealplanning/assembly-library.md, README.md.
-- Loader: scripts/seed_meal_library.mjs (both docs/new_mealplanning/meal-library-400.json and assembly-library.json).
-- Apply to DEV with `supabase db query --linked -f <this file>` (migration history drifted on 2026-08-27).

-- ---------------------------------------------------------------- columns
alter table public.meal_library add column if not exists kind text not null default 'recipe';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'meal_library_kind_check') then
    alter table public.meal_library add constraint meal_library_kind_check check (kind in ('assembly','recipe'));
  end if;
end $$;
alter table public.meal_library add column if not exists pattern   text;          -- 'protein + starch + veg' (assemblies)
alter table public.meal_library add column if not exists frequency text;          -- staple | common | occasional
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'meal_library_frequency_check') then
    alter table public.meal_library add constraint meal_library_frequency_check
      check (frequency is null or frequency in ('staple','common','occasional'));
  end if;
end $$;
alter table public.meal_library add column if not exists evidence text;           -- quote showing how common it is
alter table public.meal_library add column if not exists reconstructed_from_snippet boolean not null default false;
alter table public.meal_library add column if not exists shard_id text;           -- research id ('L-a-017') for provenance

comment on column public.meal_library.kind is 'assembly = 1-6 plain components, no method ("chicken, rice & broccoli"); recipe = has a method / recipe card';
comment on column public.meal_library.ingredients_json is '[{name, qty, role?}] — role (protein|starch|veg|fruit|fat|dairy|sauce|drink|other) present on assemblies';

create index if not exists meal_library_kind_idx      on public.meal_library (kind, meal_type) where is_active;
create index if not exists meal_library_frequency_idx on public.meal_library (frequency) where is_active;

-- ---------------------------------------------------------------- search_meals: + p_kind, returns kind/pattern/frequency
drop function if exists public.search_meals(uuid,text,vector,text,text[],boolean,boolean,integer,allergy_enum[],dietary_preference_enum);
drop function if exists public.search_meals(uuid,text,vector,text,text[],boolean,boolean,integer,allergy_enum[],dietary_preference_enum,text);
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
  p_require_diet   dietary_preference_enum default null, -- query-time ("vegan"), on top of the user's diet
  p_kind           text default null          -- 'assembly' | 'recipe' | null (both)
)
returns table (
  source text, id text, name text, meal_type text, contexts text[], batch boolean, prep_minutes integer,
  kcal integer, carbs_g numeric, protein_g numeric, fat_g numeric, allergens text[], diets_ok text[],
  swaps text, why text, attribution text, ingredients text, library_meal_id text, score real,
  kind text, pattern text, frequency text
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
           ((case when p_embedding is not null and m.embedding is not null then 1 - (m.embedding <=> p_embedding)
                  when p_query is not null then greatest(similarity(m.name, p_query), word_similarity(p_query, m.search_text))
                  else 0.5 end)
            + case m.frequency when 'staple' then 0.04 when 'common' then 0.02 else 0 end)::real as score,  -- common beats clever
           m.kind, m.pattern, m.frequency
    from public.meal_library m, me
    where m.is_active
      and (p_kind is null or m.kind = p_kind)
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
                        else 0.5 end)::real as score,                        -- saved meals rank first
           coalesce(l.kind, 'assembly') as kind, l.pattern, 'staple'::text as frequency
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

-- ---------------------------------------------------------------- component pairs: "what is eaten with what"
-- Normalised component name = lower(text before the first comma / parenthesis), trimmed. Counted over active
-- library rows (both kinds). The planner may only compose a NEW combination if every component pair in it
-- co-occurs here (see library_pair_support). "oatmeal + pork tenderloin" → 0 → rejected.
create or replace function public.norm_component(p text)
returns text language sql immutable as $$
  select nullif(btrim(regexp_replace(lower(split_part(split_part(coalesce(p,''), ',', 1), '(', 1)),
                        '^(cooked|steamed|grilled|roasted|baked|boiled|fresh|plain|sliced|raw|whole|large|small|medium|tinned|canned|dried|frozen|chopped|diced|mixed|a|an)\s+', '', 'g')), '');
$$;

drop materialized view if exists public.meal_library_pairs;
create materialized view public.meal_library_pairs as
  with comps as (
    select m.id as meal_id, m.meal_type, public.norm_component(c->>'name') as comp
    from public.meal_library m, jsonb_array_elements(m.ingredients_json) c
    where m.is_active
  ), pairs as (
    select a.comp as comp_a, b.comp as comp_b, a.meal_type
    from comps a join comps b on a.meal_id = b.meal_id and a.comp < b.comp
    where a.comp is not null and b.comp is not null
  )
  select comp_a, comp_b, count(*)::integer as n_meals,
         array_agg(distinct meal_type) as meal_types
  from pairs group by comp_a, comp_b;
create unique index if not exists meal_library_pairs_pk on public.meal_library_pairs (comp_a, comp_b);
create index if not exists meal_library_pairs_a on public.meal_library_pairs (comp_a);
create index if not exists meal_library_pairs_b on public.meal_library_pairs (comp_b);
grant select on public.meal_library_pairs to authenticated, anon, service_role;

create or replace function public.refresh_meal_library_pairs()
returns void language sql security definer set search_path = public as $$
  refresh materialized view public.meal_library_pairs;
$$;
revoke all on function public.refresh_meal_library_pairs() from public;
grant execute on function public.refresh_meal_library_pairs() to service_role;

-- library_pair_support(components): for a proposed combination, the co-occurrence count of every pair.
-- min_support = 0 means at least one pair has never been seen together in the library.
create or replace function public.library_pair_support(p_components text[])
returns table (comp_a text, comp_b text, n_meals integer)
language sql stable as $$
  with c as (select distinct public.norm_component(x) as comp from unnest(p_components) x),
  pr as (select a.comp as comp_a, b.comp as comp_b from c a join c b on a.comp < b.comp where a.comp is not null and b.comp is not null)
  select pr.comp_a, pr.comp_b, coalesce(p.n_meals, 0)
  from pr left join public.meal_library_pairs p on p.comp_a = pr.comp_a and p.comp_b = pr.comp_b
  order by 3, 1, 2;
$$;
grant execute on function public.library_pair_support to authenticated, service_role;
