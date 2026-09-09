-- The image fallback ladder becomes auditable.
--
-- Until now a meal's image was assigned and never judged: pass 5 checked a Tile
-- against its ingredient ("is this a cherry?"), and nothing ever asked whether
-- the composed Mosaic honestly represents the Meal. Cherry ice cream can pass
-- every tile check and still be wrong, because the cherries are churned in.
--
-- Two facts get recorded per meal:
--
--   separability  Do the named components stay individually recognisable in the
--                 finished Meal? Only a `separable` Meal may wear a Mosaic — a
--                 `transformed` one needs a Dish photo or nothing. This cuts
--                 ACROSS Recipe/Assembly: a smoothie is an Assembly and is
--                 transformed; a grain bowl may be a Recipe and is separable.
--
--   image_verdict Does the image the Meal is actually showing represent it?
--                 Judged on the composed artefact, not on the tiles.
--
-- Idempotent. Dev first; prod at cutover.

-- ------------------------------------------------------------ 1. meal_library
alter table public.meal_library
  add column if not exists separability        text,
  add column if not exists separability_reason text,
  add column if not exists separability_at     timestamptz,
  add column if not exists image_verdict       text,
  add column if not exists image_verdict_reason text,
  add column if not exists image_verdict_at    timestamptz,
  -- The end of the ladder: nothing honest can be shown for this Meal. A flag
  -- to look at later, not a UI state (Lee, 2026-09-09) — the app still draws
  -- the icon, as it does for every `none`.
  add column if not exists image_blocked       boolean not null default false;

comment on column public.meal_library.separability is
  'separable = the named components stay individually recognisable in the finished '
  'meal, so a Mosaic tells the truth; transformed = they do not (a smoothie, ice '
  'cream, a stew), so a Mosaic would lie. See CONTEXT.md.';
comment on column public.meal_library.image_verdict is
  'ok | weak | wrong — judged against the image the meal actually shows, '
  'composed as the app composes it.';
comment on column public.meal_library.image_blocked is
  'The ladder found nothing honest to show. Reported, not rendered.';

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'meal_library_separability_check') then
    alter table public.meal_library add constraint meal_library_separability_check
      check (separability is null or separability in ('separable', 'transformed'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'meal_library_image_verdict_check') then
    alter table public.meal_library add constraint meal_library_image_verdict_check
      check (image_verdict is null or image_verdict in ('ok', 'weak', 'wrong'));
  end if;
end $$;

-- The passes select "everything not yet judged", which is a scan without this.
create index if not exists meal_library_unjudged_idx
  on public.meal_library (image_verdict) where is_active and image_verdict is null;
create index if not exists meal_library_unclassified_idx
  on public.meal_library (separability) where is_active and separability is null;

-- ------------------------------------------------------------ 2. ingredient_images
-- Pass 2 walks its ranking only until a candidate downloads; a vision rejection
-- afterwards never sent it back for the next one. So 192 slugs — bread, quinoa,
-- black beans, rice, chicken, 1,942 meal references between them — are stuck on
-- a photo of the wrong food and contribute nothing, because pass 3 reads only
-- status='ok'. Remembering what was already rejected lets pass 2 retry without
-- re-picking the same bad image.
alter table public.ingredient_images
  add column if not exists rejected_urls text[] not null default '{}',
  add column if not exists attempts      integer not null default 0;

comment on column public.ingredient_images.rejected_urls is
  'Origin URLs already tried and rejected for this slug; pass 2 skips them.';
comment on column public.ingredient_images.attempts is
  'How many fetch rounds this slug has been through, so a hopeless slug stops.';
