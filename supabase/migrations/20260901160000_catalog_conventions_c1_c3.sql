-- Catalog conventions C1 + C3 — template_foods fluid/unit corrections.
--
-- Source of truth: qa spec/domain/catalog-conventions.md v1 (RULED Xuan,
-- 2026-09-01; mirrored at app docs/ssot/spec/domain/catalog-conventions.md),
-- executed per qa intake/2026-09-01-handback-catalog-conventions.md.
-- Scope: DEV first, then PROD at release. Catalogs verified row-identical
-- 2026-09-01 — one migration, both projects. Replayable: every statement is
-- idempotent (guarded UPDATEs by unique name).
--
-- C1 — `fluid_ml` means "fluid the item delivers AS CONSUMED". Powders,
-- tablets and single-serve mixes are dry: fluid_ml = 0. Their water arrives
-- as the separate C2 pairing water row — carrying it on the item row
-- double-counts (the P13-class 44 oz delivered-fluid overshoot).
-- Unchanged BY DESIGN: sports_drink_mix (already 0), pickle_juice_shot
-- (genuinely liquid, 70), oatmeal/oats_dry (consumed cooked, 200),
-- fruit/rice intrinsic water.
--
-- C3 — `is_indivisible` = "cannot be consumed in fractional units":
-- energy_gel and single-serve sticks/packets true; divisible-in-practice
-- items (banana halves, powder scoops) unchanged.

begin;

-- C1: zero fluid_ml on the ruled dry set.
update template_foods
set fluid_ml = 0, updated_at = now()
where name in (
  'electrolyte_tablet',
  'electrolyte_packet',
  'electrolyte_drink_mix',
  'high_sodium_electrolyte_mix',
  'carb_drink_mix',
  'high_carb_drink_mix'
)
and fluid_ml is distinct from 0;

-- C3: whole-unit-only items.
update template_foods
set is_indivisible = true, updated_at = now()
where name in (
  'energy_gel',
  'electrolyte_packet',
  'high_sodium_electrolyte_mix'
)
and is_indivisible is distinct from true;

commit;

-- Verification (run after apply; expect the C1 set at 0 and the C3 set true):
-- select name, fluid_ml, is_indivisible from template_foods
-- where name in ('electrolyte_tablet','electrolyte_packet',
--   'electrolyte_drink_mix','high_sodium_electrolyte_mix','carb_drink_mix',
--   'high_carb_drink_mix','energy_gel','sports_drink_mix',
--   'pickle_juice_shot','oats_dry')
-- order by name;
