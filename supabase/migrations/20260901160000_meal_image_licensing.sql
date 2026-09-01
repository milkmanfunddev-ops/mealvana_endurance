-- =====================================================================
-- 20260901_160000 · licence + provenance for meal images
--
-- Meal photos are sourced from openly-licensed collections (Wikimedia Commons,
-- optionally Openverse). Those licences are only satisfied if we can actually
-- render the attribution, so the licence and creator have to travel with the URL
-- rather than being implied. Idempotent.
-- =====================================================================

alter table public.meal_library add column if not exists image_license      text;   -- 'cc0' | 'pd' | 'cc-by-4.0' | 'cc-by-sa-4.0' | …
alter table public.meal_library add column if not exists image_creator      text;   -- photographer, as the collection records them
alter table public.meal_library add column if not exists image_provider     text;   -- 'wikimedia' | 'openverse'
alter table public.meal_library add column if not exists image_match_query  text;   -- the query that found it — makes a bad match debuggable
alter table public.meal_library add column if not exists image_at           timestamptz;

comment on column public.meal_library.image_license is 'Licence identifier for image_url. Non-null means we believe the image is safe to display WITH the attribution in image_creator/image_credit.';
comment on column public.meal_library.image_provider is 'Which collection supplied it. Images from a cited recipe page (image_provider is null) are that publisher''s and carry no licence grant.';
comment on column public.meal_library.image_match_query is 'The search term that produced this image — a wrong photo is almost always a wrong query, so keep it.';

create index if not exists meal_library_image_idx on public.meal_library (image_provider) where image_url is not null;
