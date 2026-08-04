-- Dual-unit serving_size text for metric athletes.
--
-- `serving_size` is human-readable explanatory text, not a computed measurement
-- (macros come from the *_per_serving columns), so the fix is editorial rather
-- than a conversion: state both units, matching the convention `foods` already
-- uses — "1 cup = 8 fl oz (240 mL)".
--
-- Scope: 21 template_foods + 1 foods row, identical on dev and prod. Idempotent —
-- every statement is guarded on the exact old value, so re-running changes nothing.
--
-- APPLIED 2026-08-03 via the Supabase MCP, which stamps its own version per
-- project: dev = 20260804112950, prod = 20260804113044. This file is named for
-- the dev stamp, so a later `db push` against prod will re-run it as a no-op.
-- Both envs verified afterwards: 0 imperial-only rows, 24 dual-unit.
--
-- NOT covered, deliberately:
--   * catalog_variants (30 rows) — TheFeed manufacturer catalog, rewritten by
--     /refresh-feed on every import. Editing rows here would be overwritten;
--     manufacturer serving sizes are also arguably correct to keep verbatim.
--     Fix belongs in the importer if we want it at all.
--   * nutrition_products "8 OZA" (2 rows) — that is a USDA import artifact,
--     a data-quality bug rather than a units problem. Tracked separately.

begin;

-- ── template_foods ─────────────────────────────────────────────────────────
-- 1 cup (8 oz) → 1 cup (8 fl oz / 240 mL)
update public.template_foods
   set serving_size = '1 cup (8 fl oz / 240 mL)'
 where serving_size = '1 cup (8 oz)';

-- Ready-to-drink bottles
update public.template_foods
   set serving_size = '1 bottle (11 fl oz / 325 mL)'
 where serving_size = '1 bottle (11 oz)';

update public.template_foods
   set serving_size = '1 bottle (14 fl oz / 415 mL)'
 where serving_size in ('1 bottle (14 oz)', '1 bottle (14 fl oz)');

-- Mix-in-water instructions
update public.template_foods
   set serving_size = '1 scoop (in 16-20 fl oz / 475-590 mL water)'
 where serving_size = '1 scoop (in 16-20oz water)';

update public.template_foods
   set serving_size = '1 packet (in 16 fl oz / 475 mL water)'
 where serving_size = '1 packet (in 16 oz water)';

update public.template_foods
   set serving_size = '1 stick (mix in 16 fl oz / 475 mL water)'
 where serving_size = '1 stick (mix in 16 oz water)';

update public.template_foods
   set serving_size = '1 shot (2.5 fl oz / 75 mL)'
 where serving_size = '1 shot (2.5 oz)';

-- Weight ounces (28.35 g), not fluid
update public.template_foods
   set serving_size = '3 oz (85 g)'
 where serving_size = '3 oz';

update public.template_foods
   set serving_size = '1 oz (28 g)'
 where serving_size = '1 oz';

-- ── foods ──────────────────────────────────────────────────────────────────
update public.foods
   set serving_size = '1 serving-cup = 5.3 oz (150 g)'
 where serving_size = '1 serving-cup = 5.3 oz';

commit;

-- Verification — expect 0 rows.
-- select name, serving_size from public.template_foods
--  where serving_size ~* '(fl ?oz|[0-9] ?oz|lbs?)'
--    and serving_size !~* '(ml|gram|[0-9] ?g\y|kg)'
-- union all
-- select name, serving_size from public.foods
--  where serving_size ~* '(fl ?oz|[0-9] ?oz|lbs?)'
--    and serving_size !~* '(ml|gram|[0-9] ?g\y|kg)';
