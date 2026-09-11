-- search_meals says where a Dish photo came from, and who took it.
--
-- A rail never shows one photograph on two Meals (meal-imagery ticket 07). The
-- client can only tell two Meals wear the same photograph by where it came
-- from: a mirrored archive photo is stored once per Meal (meal-images/meals/<id>.jpg),
-- so "White bread & jam" and "White bread with jam" carry different
-- image_url values for one Wikimedia file. image_source_url is that identity.
--
-- image_creator and image_license ride along so a card credits a Dish photo
-- the way the detail screen (get_meal) already does. Sending the source page
-- alone would reword the card's credit from the stored line to a bare
-- "Photo on <platform>".
--
-- Three columns appended, nothing removed or reordered: callers read columns
-- by name. Only the return type changes, so the signature is dropped and
-- recreated (Postgres cannot alter a function's OUT columns in place).
--
-- Idempotent. Dev first; prod has no search_meals yet and takes this with the
-- meal-planning cutover.

-- One transaction: between the drop and the create there is no search_meals,
-- and every Meals tab and Vana search would fail.
begin;
drop function if exists public.search_meals(uuid, text, vector, text, text[], boolean, boolean, integer, allergy_enum[], dietary_preference_enum, text, boolean, integer);
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
  p_include_disliked boolean default false,   -- true only when the caller is browsing, not suggesting
  p_offset         integer default 0          -- browse paging; ordering is stable so pages don't overlap
)
returns table (
  source text, id text, name text, meal_type text, contexts text[], batch boolean, prep_minutes integer,
  kcal integer, carbs_g numeric, protein_g numeric, fat_g numeric, allergens text[], diets_ok text[],
  swaps text, why text, attribution text, ingredients text, library_meal_id text, score real,
  kind text, pattern text, frequency text, icon text, my_vote smallint,
  image_url text, image_mode text, image_tiles jsonb, image_credit text,
  image_source_url text, image_creator text, image_license text
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
           m.kind, m.pattern, m.frequency, m.icon, coalesce(v.vote, 0::smallint) as my_vote,
           m.image_url, coalesce(m.image_mode, 'none') as image_mode,
           coalesce(m.image_tiles, '[]'::jsonb) as image_tiles, m.image_credit,
           m.image_source_url, m.image_creator, m.image_license
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
           coalesce(s.icon, l.icon) as icon, coalesce(v.vote, 0::smallint) as my_vote,
           l.image_url, coalesce(l.image_mode, 'none') as image_mode,
           coalesce(l.image_tiles, '[]'::jsonb) as image_tiles, l.image_credit,
           l.image_source_url, l.image_creator, l.image_license
    from public.saved_meals s
    left join public.meal_library l on l.id = s.library_meal_id
    left join votes v on v.saved_meal_id = s.id
    where p_include_saved and s.user_id = p_user_id and not s.is_deleted
      and (p_meal_type is null or s.meal_types = '{}' or s.meal_types @> array[p_meal_type])
      and (p_batch is null or coalesce(s.batch, false) = p_batch or s.batch is null)
      and (p_include_disliked or coalesce(v.vote, 0) >= 0)
      -- A kind-filtered rail asked for assemblies or recipes; saved meals have to
      -- honour that too, or twelve saved meals fill both rails and the library
      -- never appears. (They used to ignore p_kind entirely.)
      and (p_kind is null or coalesce(l.kind, 'assembly') = p_kind)
  )
  select * from (select * from mine union all select * from lib) x
  -- id breaks score ties deterministically. Without it, every library row scores
  -- identically on an unqueried browse and paging returns overlapping pages.
  order by score desc, id
  limit p_limit offset greatest(coalesce(p_offset, 0), 0);
$$;
grant execute on function public.search_meals to authenticated, service_role;
commit;
