-- The composed credit line says what the app used to say.
--
-- 20260916140000 composed each kept Dish photo's credit from the structured
-- licensing fields. Two things were wrong against the builder it was copying
-- (`KyleMealImageTile.credit`, `lib/shared/widgets/kyle_design/data/meal_image_mosaic.dart`):
--
--   1. Licence terms lost their hyphens. The app writes `CC BY-SA 4.0`; the
--      first version collapsed every separator to a space and wrote
--      `CC BY SA 4.0`. 99 of the 170 kept photos on dev were miscredited — a
--      licence's required wording, so worth correcting rather than living with.
--   2. The platform was read from the source URL's host only. The app named it
--      from `image_provider` first and fell back to the host, which matters for
--      a row that has a provider and no source page. Openverse is a search
--      engine over other sites, so its photographs stay credited to the host
--      they live on — the app's rule, kept here.
--
-- Also: a photograph with nobody and nowhere to name but a licence to state now
-- reads `Photo (CC0)` as the app's builder did, instead of NULL-propagating into
-- the stored `image_credit` fallback.
--
-- Idempotent, and it re-composes: unlike the switchover, this UPDATE deliberately
-- rewrites credits that are already there, but only for rows still showing the
-- photograph the switchover gave them (photo_url = image_url, dish + ok). A photo
-- a Tester has since added or replaced is never touched.
--
-- Dev first; prod takes it with the meal-planning cutover.

begin;

-- The first version took four arguments. Adding `p_provider` with a default
-- creates a second overload rather than replacing it, and every call then fails
-- as ambiguous (42725), so the old signature goes first. 20260916140000 now
-- carries the corrected definition too, which makes this file a no-op on a
-- database built from the migrations in order (prod, at cutover).
drop function if exists public.meal_photo_credit_line(text, text, text, text);

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
      -- The platform the credit names: the provider that sourced it, else the
      -- host the photograph lives on. Openverse searches other sites, so its
      -- photographs are credited to the site rather than to Openverse whenever
      -- the source page says which site that is.
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
      -- (`cc-by-sa-4.0`, `CC BY-SA 4.0`, `cc0-or-pd`). The stock licences are
      -- already named by their platform, so they are not repeated.
      case
        when p_license is null or btrim(p_license) = '' then null
        when lower(btrim(p_license)) in ('unsplash', 'pexels') then null
        when lower(btrim(p_license)) ~ '^(pd|pdm|public domain|cc0[ -]or[ -]pd)$' then 'public domain'
        when lower(btrim(p_license)) ~ '^cc0([ -]1\.0)?$' then 'CC0'
        when lower(btrim(p_license)) ~ '^cc[ -]+by([ -]+(sa|nc|nd))*([ -]+[0-9]+(\.[0-9]+)?)?$' then
          -- Terms join with hyphens (CC BY-SA), the version follows a space
          -- (CC BY-SA 4.0) — exactly as the app's builder writes it.
          trim(
            regexp_replace(
              regexp_replace(upper(regexp_replace(btrim(p_license), '[ -]+', ' ', 'g')),
                             '^CC BY((?: (?:SA|NC|ND))*)', 'CC BY\1'),
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
  'licensing fields the way the app composed it at render time, falling back to '
  'the stored image_credit. Used by the ADR 0003 switchover.';

-- Re-compose the credits the switchover wrote, for rows still showing the
-- photograph it gave them. A Tester's photo (photo_url <> image_url) is left alone.
update public.meal_library m
   set photo_credit = public.meal_photo_credit_line(
                        m.image_creator, m.image_license, m.image_source_url,
                        m.image_credit, m.image_provider)
 where m.is_active
   and m.photo_url is not null
   and m.photo_url = m.image_url
   and m.image_mode = 'dish'
   and m.image_verdict = 'ok'
   and m.photo_credit is distinct from public.meal_photo_credit_line(
                        m.image_creator, m.image_license, m.image_source_url,
                        m.image_credit, m.image_provider);

commit;

-- Verify (read-only): no kept photo should carry a space-separated CC term.
--
--   select count(*) from public.meal_library
--    where is_active and photo_credit like '%CC BY %' and photo_credit not like '%CC BY-%';
