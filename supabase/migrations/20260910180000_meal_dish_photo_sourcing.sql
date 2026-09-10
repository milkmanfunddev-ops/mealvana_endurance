-- Sourcing a dish photograph, remembered between runs.
--
-- Pass 10 searches licensed stock by the meal's name and shows every candidate
-- to the judge BEFORE storing it. That makes a failed meal expensive in a way a
-- failed tile never was: several vision calls were paid for, and the only thing
-- worth keeping from them is which photographs were already refused.
--
-- Without that, a second run re-buys the same verdicts on the same pictures. The
-- ingredient bank learned this on 2026-09-09 (`ingredient_images.rejected_urls`)
-- and these are its counterparts on the meal.
--
-- Idempotent. Dev first; prod at cutover.
alter table public.meal_library
  add column if not exists image_rejected_urls text[] not null default '{}',
  add column if not exists image_attempts      integer not null default 0;

comment on column public.meal_library.image_rejected_urls is
  'Candidate dish photographs the judge has already refused for this meal. '
  'Pass 10 never shows the judge one of these again — a refusal is a verdict '
  'that was paid for, and re-buying it is the whole cost of the pass.';
comment on column public.meal_library.image_attempts is
  'How many sourcing rounds this meal has been through, so a dish no stock '
  'library holds eventually stops consuming every future run.';

-- Pass 10 selects "meals that still have a sourcing round left", and it does so
-- across four queues: the ones showing nothing AND the ones already wearing a
-- photograph of the wrong food. An `image_url is null` predicate would serve
-- only the first two, so the predicate is the thing every queue shares.
drop index if exists public.meal_library_dish_sourcing_idx;
create index if not exists meal_library_dish_sourcing_idx
  on public.meal_library (image_attempts)
  where is_active;
