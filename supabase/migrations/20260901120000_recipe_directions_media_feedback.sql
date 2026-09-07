-- =====================================================================
-- 20260901_120000 · recipe directions provenance, media, and meal feedback
--
-- Three things, all for the meal/recipe/assembly detail page + cooking mode:
--   1. meal_library gains a clickable source_url, an image_url, and provenance
--      for method_steps (where the directions came from, and whether they are
--      the publisher's words or ours).
--   2. meal_feedback: one thumbs up / thumbs down per user per meal.
--   3. search_meals honours those votes (thumbs-down never suggested again)
--      and returns the caller's own vote so the UI can render thumb state.
--
-- Idempotent — safe to re-run.
-- =====================================================================

-- ------------------------------------------------------------ 1. media + provenance
-- The single best clickable link for "see the original recipe". Parsed out of the
-- free-text `source` line by scripts/fetch_recipe_sources.mjs; `source` itself stays
-- the human attribution string and is unchanged.
alter table public.meal_library add column if not exists source_url  text;
alter table public.meal_library add column if not exists source_urls text[] not null default '{}';
comment on column public.meal_library.source_url  is 'Primary clickable original-recipe link, extracted from source. Null when the attribution carries no URL.';
comment on column public.meal_library.source_urls is 'Every URL found in source, in order of appearance.';

-- Images stay remote for now (decision 2026-09-01): we record the URL and the page
-- it came from, and a later job may copy them into Supabase Storage.
alter table public.meal_library add column if not exists image_url        text;
alter table public.meal_library add column if not exists image_source_url text;
alter table public.meal_library add column if not exists image_credit     text;
comment on column public.meal_library.image_url is 'Remote image URL (og:image or schema.org Recipe.image). Hotlinked — not yet copied into Storage.';

-- Where method_steps came from. Load-bearing for the UI: 'ai_generated' renders an
-- "AI-written steps" badge, and lets us re-do or re-license any subset later.
do $$ begin
  alter table public.meal_library add column if not exists directions_origin text;
exception when duplicate_column then null; end $$;
alter table public.meal_library drop constraint if exists meal_library_directions_origin_check;
alter table public.meal_library add constraint meal_library_directions_origin_check
  check (directions_origin is null or directions_origin in ('source','alt_source','ai_generated','assembly_simple'));
comment on column public.meal_library.directions_origin is
  'source = lifted from the cited source_url; alt_source = another page we found; ai_generated = written by us from name+ingredients (UI shows a badge); assembly_simple = trivial assemble-and-serve steps.';

alter table public.meal_library add column if not exists directions_source_url  text;
alter table public.meal_library add column if not exists directions_source_name text;
-- true when method_steps reproduce the publisher's wording (attributed), false when in our own voice.
alter table public.meal_library add column if not exists directions_verbatim boolean not null default false;
alter table public.meal_library add column if not exists directions_at timestamptz;

create index if not exists meal_library_directions_origin_idx on public.meal_library (directions_origin);

-- ------------------------------------------------------------ 2. meal_feedback
create table if not exists public.meal_feedback (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references public.users(id) on delete cascade,
  library_meal_id text references public.meal_library(id) on delete cascade,
  saved_meal_id   uuid references public.saved_meals(id) on delete cascade,
  vote            smallint not null check (vote in (-1, 1)),
  reason          text,                                    -- optional free text ("too much fibre pre-race")
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint meal_feedback_one_target check (num_nonnulls(library_meal_id, saved_meal_id) = 1)
);
-- Partial uniques: one vote per user per target. NOTE (CLAUDE.md): never PostgREST-upsert
-- on these columns (42P10) — go through set_meal_feedback() below.
create unique index if not exists meal_feedback_user_library_uniq on public.meal_feedback (user_id, library_meal_id) where library_meal_id is not null;
create unique index if not exists meal_feedback_user_saved_uniq   on public.meal_feedback (user_id, saved_meal_id)   where saved_meal_id   is not null;
create index if not exists meal_feedback_user_idx on public.meal_feedback (user_id);

alter table public.meal_feedback enable row level security;
drop policy if exists "meal_feedback owner" on public.meal_feedback;
create policy "meal_feedback owner" on public.meal_feedback for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Set / flip / clear a vote in one call. Passing the same vote again clears it (toggle off),
-- which is what tapping an already-lit thumb should do. Returns the resulting vote (0 = none).
create or replace function public.set_meal_feedback(
  p_library_meal_id text default null,
  p_saved_meal_id   uuid default null,
  p_vote            smallint default null,   -- 1 | -1 | 0 (0 = clear outright)
  p_reason          text default null
) returns smallint
language plpgsql volatile security invoker as $$
declare
  v_user uuid := auth.uid();
  v_existing smallint;
begin
  if v_user is null then raise exception 'not authenticated'; end if;
  if num_nonnulls(p_library_meal_id, p_saved_meal_id) <> 1 then
    raise exception 'pass exactly one of p_library_meal_id / p_saved_meal_id';
  end if;
  if p_vote is null or p_vote not in (-1, 0, 1) then raise exception 'p_vote must be -1, 0 or 1'; end if;

  select vote into v_existing from public.meal_feedback
   where user_id = v_user
     and library_meal_id is not distinct from p_library_meal_id
     and saved_meal_id   is not distinct from p_saved_meal_id;

  if p_vote = 0 or v_existing = p_vote then          -- clear, or toggle the lit thumb off
    delete from public.meal_feedback
     where user_id = v_user
       and library_meal_id is not distinct from p_library_meal_id
       and saved_meal_id   is not distinct from p_saved_meal_id;
    return 0;
  end if;

  if v_existing is null then
    insert into public.meal_feedback (user_id, library_meal_id, saved_meal_id, vote, reason)
    values (v_user, p_library_meal_id, p_saved_meal_id, p_vote, p_reason);
  else
    update public.meal_feedback
       set vote = p_vote, reason = coalesce(p_reason, reason), updated_at = now()
     where user_id = v_user
       and library_meal_id is not distinct from p_library_meal_id
       and saved_meal_id   is not distinct from p_saved_meal_id;
  end if;
  return p_vote;
end $$;
grant execute on function public.set_meal_feedback to authenticated;

-- ------------------------------------------------------------ 3. search_meals: vote-aware
-- Return type changes (+ my_vote) → drop the old signature first.
drop function if exists public.search_meals(uuid, text, vector, text, text[], boolean, boolean, integer, allergy_enum[], dietary_preference_enum, text);
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
  p_kind           text default null,         -- 'assembly' | 'recipe' | null (both)
  p_include_disliked boolean default false    -- true only when the caller is browsing, not suggesting
)
returns table (
  source text, id text, name text, meal_type text, contexts text[], batch boolean, prep_minutes integer,
  kcal integer, carbs_g numeric, protein_g numeric, fat_g numeric, allergens text[], diets_ok text[],
  swaps text, why text, attribution text, ingredients text, library_meal_id text, score real,
  kind text, pattern text, frequency text, icon text, my_vote smallint
)
language sql stable security invoker as $$
  with me as (
    select coalesce(u.allergies, '{}'::allergy_enum[]) as allergies, u.dietary_preference as diet
    from public.users u where u.id = p_user_id
  ),
  votes as (
    select library_meal_id, saved_meal_id, vote from public.meal_feedback where user_id = p_user_id
  ),
  lib as (
    select 'library'::text as source, m.id, m.name, m.meal_type, m.contexts, m.batch, m.prep_minutes,
           m.kcal, m.carbs_g, m.protein_g, m.fat_g,
           m.allergens::text[] as allergens, m.diets_ok::text[] as diets_ok,
           m.swaps, m.why, m.source as attribution, m.ingredients, m.id as library_meal_id,
           ((case when p_embedding is not null and m.embedding is not null then 1 - (m.embedding <=> p_embedding)
                  when p_query is not null then greatest(similarity(m.name, p_query), word_similarity(p_query, m.search_text))
                  else 0.5 end)
            + case m.frequency when 'staple' then 0.04 when 'common' then 0.02 else 0 end   -- common beats clever
            + case when v.vote = 1 then 0.10 else 0 end)::real as score,                    -- what you liked comes back
           m.kind, m.pattern, m.frequency, m.icon, coalesce(v.vote, 0::smallint) as my_vote
    from public.meal_library m
    cross join me
    left join votes v on v.library_meal_id = m.id
    where m.is_active
      and (p_kind is null or m.kind = p_kind)
      and (p_meal_type is null or m.meal_type = p_meal_type)
      and (p_contexts is null or m.contexts && p_contexts)
      and (p_batch is null or m.batch = p_batch)
      and not (m.allergens && me.allergies)                                   -- HARD: allergies
      and (p_exclude_allergens is null or not (m.allergens && p_exclude_allergens))
      and (me.diet is null or not (m.excluded_diets @> array[me.diet]))       -- HARD: diet
      and (p_require_diet is null or m.diets_ok @> array[p_require_diet])
      and (p_include_disliked or coalesce(v.vote, 0) >= 0)                    -- thumbs-down is not suggested again
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
           coalesce(l.kind, 'assembly') as kind, l.pattern, 'staple'::text as frequency,
           coalesce(s.icon, l.icon) as icon, coalesce(v.vote, 0::smallint) as my_vote
    from public.saved_meals s
    left join public.meal_library l on l.id = s.library_meal_id
    left join votes v on v.saved_meal_id = s.id
    where p_include_saved and s.user_id = p_user_id and not s.is_deleted
      and (p_meal_type is null or s.meal_types = '{}' or s.meal_types @> array[p_meal_type])
      and (p_batch is null or coalesce(s.batch, false) = p_batch or s.batch is null)
      and (p_include_disliked or coalesce(v.vote, 0) >= 0)
  )
  select * from (select * from mine union all select * from lib) x
  order by score desc
  limit p_limit;
$$;
grant execute on function public.search_meals to authenticated, service_role;
