-- A saved meal made from a log (Describe / photo) carries one dish-level item
-- (`items = [{name: <the meal>, portion: "1 serving", …macros}]`) and no
-- ingredients, so the shopping list showed "Egg & veggie scramble — 4 serving"
-- under Protein and Kroger could match nothing (playtest 2026-09-16, §5).
--
-- `ingredients_json` holds the per-ONE-serving ingredient list the server
-- extracts once for such a meal, in the same shape as
-- `meal_library.ingredients_json`: `[{name, qty}]`. NULL means "not extracted";
-- the grocery builder falls back to `items`. A "Save to mine" copy keeps real
-- ingredient rows in `items` and never needs this column.
--
-- Idempotent.
alter table public.saved_meals add column if not exists ingredients_json jsonb;
comment on column public.saved_meals.ingredients_json is
  'Per-one-serving ingredients [{name, qty}] extracted once for a dish-level saved meal; NULL = not extracted, grocery falls back to items.';
