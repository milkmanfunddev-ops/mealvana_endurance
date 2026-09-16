-- A Meal shows a Dish photo or nothing (ADR 0003, mp-145 re-ruled 2026-09-15).
--
-- The current photo becomes its own three fields on meal_library, separate from
-- everything the image pipeline wrote. The pipeline's columns (image_url,
-- image_mode, image_tiles, the Verdicts, the Tile bank) are NOT touched and NOT
-- dropped: the pipeline is frozen, not deleted, so Mosaics can come back later
-- without re-sourcing. After this migration the app reads photo_* only.
--
--   photo_url         the image's address — our storage or the web. Null = the
--                     Meal shows no picture at all (no placeholder, no icon).
--   photo_credit      one credit line, shown under the photo on the recipe
--                     screen and read out by screen readers. Null = no line.
--   photo_credit_url  where that line goes when tapped. Null = not tappable.
--
-- Switchover: a Meal keeps its picture only if that picture is a Dish photo the
-- Judge passed (image_mode = 'dish' and image_verdict = 'ok') — 170 Meals on dev
-- on 2026-09-15. A `weak` photo, a Mosaic and a single ingredient Tile all
-- become nothing. No History rows are created: History starts empty, so a
-- rejected pipeline picture can never be restored with a tap.
--
-- Idempotent (guarded backfill: only rows that have no photo yet are filled, so
-- a re-run never overwrites a photo a Tester has since added). Dev first; prod
-- takes it with the meal-planning cutover.

begin;

-- ------------------------------------------------------------ 1. the columns
alter table public.meal_library
  add column if not exists photo_url        text,
  add column if not exists photo_credit     text,
  add column if not exists photo_credit_url text;

comment on column public.meal_library.photo_url is
  'The Dish photo this Meal shows right now: an https address, in our storage or '
  'on the web. Null means the Meal shows no picture at all (ADR 0003). Written by '
  'the photo edge function and by the switchover backfill — never by the frozen '
  'image pipeline, which keeps writing image_url.';
comment on column public.meal_library.photo_credit is
  'One credit line for photo_url, or null when the photo needs none (our own '
  'photographs). Shown under the photo on the recipe screen; on a card it is the '
  'screen-reader label only.';
comment on column public.meal_library.photo_credit_url is
  'The page photo_credit opens when tapped — the photograph''s own page, not the '
  'photographer''s profile. Null when there is nowhere to go.';

-- ------------------------------------------- 2. the credit line, composed once
-- The app used to build a dish photo's credit at render time from the structured
-- licensing fields ("Photo by X on Wikimedia Commons (CC BY-SA 4.0)"). A Dish
-- photo now carries one stored line instead, so this composes it the same way,
-- once, at switchover. Immutable so the backfill below can be re-run cheaply.
create or replace function public.meal_photo_credit_line(
  p_creator    text,
  p_license    text,
  p_source_url text,
  p_fallback   text,
  p_provider   text default null
) returns text
language sql immutable as $$
  with parts as (
    select
      nullif(btrim(coalesce(p_creator, '')), '') as who,
      -- The platform the credit names: the provider that sourced the
      -- photograph, else the host it lives on. Openverse is a search engine
      -- over other sites, so its photographs are credited to the site the
      -- source page names, and only fall back to "Openverse" when it doesn't.
      coalesce(
        case lower(coalesce(p_provider, ''))
          when 'unsplash'  then 'Unsplash'
          when 'pexels'    then 'Pexels'
          when 'wikimedia' then 'Wikimedia Commons'
          else null
        end,
        case lower(regexp_replace(coalesce(substring(p_source_url from '^https?://([^/?#]+)'), ''), '^www\.', ''))
          when 'commons.wikimedia.org' then 'Wikimedia Commons'
          when 'upload.wikimedia.org'  then 'Wikimedia Commons'
          when 'unsplash.com'          then 'Unsplash'
          when 'images.unsplash.com'   then 'Unsplash'
          when 'pexels.com'            then 'Pexels'
          when 'images.pexels.com'     then 'Pexels'
          when 'flickr.com'            then 'Flickr'
          when ''                      then null
          else lower(regexp_replace(substring(p_source_url from '^https?://([^/?#]+)'), '^www\.', ''))
        end,
        case when lower(coalesce(p_provider, '')) = 'openverse' then 'Openverse' else null end
      ) as platform,
      -- One spelling per licence, whichever way the pipeline stored it
      -- (`cc-by-sa-4.0`, `CC BY-SA 4.0`, `cc0-or-pd`). Terms join with hyphens
      -- and the version follows a space — `CC BY-SA 4.0`, as the app writes it.
      -- The stock licences are already named by their platform, so they are not
      -- repeated.
      case
        when p_license is null or btrim(p_license) = '' then null
        when lower(btrim(p_license)) in ('unsplash', 'pexels') then null
        when lower(btrim(p_license)) ~ '^(pd|pdm|public domain|cc0[ -]or[ -]pd)$' then 'public domain'
        when lower(btrim(p_license)) ~ '^cc0([ -]1\.0)?$' then 'CC0'
        when lower(btrim(p_license)) ~ '^cc[ -]+by([ -]+(sa|nc|nd))*([ -]+[0-9]+(\.[0-9]+)?)?$' then
          trim(
            regexp_replace(
              upper(regexp_replace(btrim(p_license), '[ -]+', ' ', 'g')),
              ' (SA|NC|ND)', '-\1', 'g'
            )
          )
        else btrim(p_license)
      end as licence
  )
  select coalesce(
    case
      when who is null and platform is null and licence is null then null
      when who is null and platform is null then 'Photo (' || licence || ')'
      else
        (case
           when who is null then 'Photo on ' || platform
           when platform is null then 'Photo by ' || who
           else 'Photo by ' || who || ' on ' || platform
         end)
        || (case when licence is null then '' else ' (' || licence || ')' end)
    end,
    nullif(btrim(coalesce(p_fallback, '')), '')
  )
  from parts;
$$;

comment on function public.meal_photo_credit_line is
  'The one credit line a Dish photo shows, composed from the structured '
  'licensing fields the way the app used to compose it at render time, falling '
  'back to the stored image_credit. Used by the ADR 0003 switchover.';

-- ------------------------------------------------------- 3. the switchover
-- Only `dish` + `ok`. `weak` photos, Mosaics and single Tiles show nothing.
-- Guarded on photo_url is null, so re-running never overwrites a Tester's photo.
update public.meal_library m
   set photo_url        = m.image_url,
       photo_credit     = public.meal_photo_credit_line(
                            m.image_creator, m.image_license, m.image_source_url,
                            m.image_credit, m.image_provider),
       photo_credit_url = nullif(btrim(coalesce(m.image_source_url, '')), '')
 where m.is_active
   and m.photo_url is null
   and m.image_mode = 'dish'
   and m.image_verdict = 'ok'
   and nullif(btrim(coalesce(m.image_url, '')), '') is not null;

-- The Meals tab reads photo_url on every browse; a partial index keeps the
-- "has a picture" half of the library cheap to find for verification queries.
create index if not exists meal_library_photo_idx
  on public.meal_library (id) where photo_url is not null;

commit;

-- ------------------------------------------------------------ 4. verify (read-only)
-- Run after applying. The two counts must be equal, and dev on 2026-09-15 says 170.
--
--   select
--     (select count(*) from public.meal_library
--       where is_active and photo_url is not null)                      as with_photo,
--     (select count(*) from public.meal_library
--       where is_active and image_mode = 'dish' and image_verdict = 'ok'
--         and nullif(btrim(coalesce(image_url, '')), '') is not null)    as dish_ok;
