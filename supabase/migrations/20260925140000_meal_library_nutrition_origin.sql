-- meal_library nutrition provenance (Finding 29-001).
--
-- 31 library rows shipped with null kcal/carbs/protein/fat. Their numbers are filled by
-- 20260925141000_meal_library_fill_31_nutrition.sql, and these two columns record where a
-- filled number came from, in the same style as directions_origin / directions_source_url.
--
-- Idempotent: safe to re-run on dev and on prod at the meal-planning cutover.
-- Additive only. Nothing reads these columns yet; the app and edge functions ignore them.

alter table public.meal_library add column if not exists nutrition_origin text;
alter table public.meal_library drop constraint if exists meal_library_nutrition_origin_check;
alter table public.meal_library add constraint meal_library_nutrition_origin_check
  check (nutrition_origin is null or nutrition_origin in ('sourced','ai_estimated'));
comment on column public.meal_library.nutrition_origin is
  'Where kcal/carbs_g/protein_g/fat_g came from. null = the original library data (research "Approx" figures); sourced = stated for this dish on nutrition_source_url; ai_estimated = computed by us from the row''s own ingredients and quantities with USDA FoodData Central values (UI may show a badge).';

alter table public.meal_library add column if not exists nutrition_source_url text;
comment on column public.meal_library.nutrition_source_url is
  'The page that states this dish''s kcal and macros when nutrition_origin = ''sourced''; null otherwise.';
