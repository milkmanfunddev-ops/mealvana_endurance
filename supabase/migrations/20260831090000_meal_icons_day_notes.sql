-- Meal icons + per-day Vana notes for the Plan tab (2026-08-31). Idempotent.
--
-- icon: a stable key from the shared classifier (packages/web/src/lib/vana/meal-icon.ts in the prototype):
--   bowl | oats | chicken | meat | fish | egg | salad | bread | wrap | pasta | soup | pizza | drink | fruit | nuts |
--   yogurt | potato | beans | tofu | baked | snack | sweet | utensils
-- The Flutter app can render the same key with Font Awesome (KyleFoodIcon) — no images.
alter table public.meal_library add column if not exists icon text;
alter table public.plan_meals   add column if not exists icon text;
alter table public.saved_meals  add column if not exists icon text;

-- day_notes: {"2026-08-31": "Long ride today — front-load the rice bowl at lunch.", ...}
-- Written once when a plan is confirmed / edited (Haiku, one call for the whole week), read for free on the Plan tab.
-- day_notes_stale flips true on every plan edit so the next Plan-tab load regenerates them.
alter table public.meal_plans add column if not exists day_notes jsonb not null default '{}'::jsonb;
alter table public.meal_plans add column if not exists day_notes_stale boolean not null default true;
alter table public.meal_plans add column if not exists day_notes_at timestamptz;

-- ---------------------------------------------------------------- search_meals: + icon in the result set (return type changes → drop first)
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
  p_kind           text default null          -- 'assembly' | 'recipe' | null (both)
)
returns table (
  source text, id text, name text, meal_type text, contexts text[], batch boolean, prep_minutes integer,
  kcal integer, carbs_g numeric, protein_g numeric, fat_g numeric, allergens text[], diets_ok text[],
  swaps text, why text, attribution text, ingredients text, library_meal_id text, score real,
  kind text, pattern text, frequency text, icon text
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
           m.kind, m.pattern, m.frequency, m.icon
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
           coalesce(l.kind, 'assembly') as kind, l.pattern, 'staple'::text as frequency, coalesce(s.icon, l.icon) as icon
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
