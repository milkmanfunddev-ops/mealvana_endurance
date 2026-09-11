-- Grids the judge refused, remembered on the meal.
--
-- Pass 10 retires a meal's picture when the judge rated it `wrong` and no
-- photograph of the dish could be found. For a dish photo that memory already
-- exists (`image_rejected_urls`). A Mosaic is different: nobody chose it, the
-- ladder did, and pass 3 recomputes every meal from scratch — so without a
-- record of the refusal, the next run of pass 3 hands the meal back the very
-- grid it was retired from.
--
-- Each entry is the grid's photographs in drawing order, joined by ' + '
-- (`pictureIdentity` in scripts/meal-images/lib/ladder.mjs). The memory is of
-- the picture, not the meal: a grid whose tile photograph has since been
-- replaced is a different picture, and the ladder offers it.
--
-- Idempotent. Dev first; prod at cutover.
alter table public.meal_library
  add column if not exists image_rejected_mosaics text[] not null default '{}';

comment on column public.meal_library.image_rejected_mosaics is
  'Mosaics (and single tiles) the judge rated wrong for this meal, as their '
  'photograph URLs in drawing order joined by '' + ''. The ladder never offers '
  'one of these to the meal again; the meal is blocked with judged_wrong instead.';
