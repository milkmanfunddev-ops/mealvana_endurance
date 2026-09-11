-- =====================================================================
-- Meal planning (Vana): meal-image licensing gate. READ-ONLY.
--
-- Raises if any meal_library row still shows a picture hotlinked from a food
-- blog with no recorded licence (`image_unlicensed`). Those rows were kept on
-- dev on purpose while the library is a prototype (Lee, 2026-09-08 and
-- 2026-09-10) and must not reach production. docs/meal-images/README.md,
-- "Known issues", has the history.
--
-- Run it twice (runbook step 3 and step 5):
--   * against DEV before exporting the snapshot, because prod is seeded from
--     dev's rows and the flag travels with them;
--   * against PROD after the seed, to prove it.
--
-- It raises rather than returning a count so that it cannot be read past.
-- A pass prints a notice and returns nothing.
-- =====================================================================
do $$
declare
  n int;
begin
  if to_regclass('public.meal_library') is null then
    raise exception 'meal_library does not exist: run the gate after the push and the seed';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'meal_library'
                    and column_name = 'image_unlicensed') then
    raise exception 'meal_library.image_unlicensed is missing: 20260909170000_meal_image_verdicts.sql has not been applied';
  end if;

  if not exists (select 1 from public.meal_library) then
    raise exception 'meal_library is empty: an empty table passes nothing, run the gate after the seed';
  end if;

  execute 'select count(*) from public.meal_library where image_unlicensed' into n;
  if n > 0 then
    raise exception 'image gate: % meal_library rows show an unlicensed hotlink. Replace or retire them on dev and re-export the snapshot. List: select id, name, image_url from meal_library where image_unlicensed;', n;
  end if;
  raise notice 'image gate: 0 unlicensed pictures';
end $$;
