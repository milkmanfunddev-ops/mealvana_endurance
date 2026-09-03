-- Catalog-conventions v1.1 — the solvent-dependency rule
-- (food-recommendation@v1 §6(e), RATIFIED Xuan 2026-09-03; supersedes C2's
-- flat 250 ml pairing constant with per-product label dilutions).
--
-- Adds template_foods.solvent_min_ml (+ optional solvent_max_ml): the minimum
-- plain-water solvent per serving a concentrated product's label calls for.
-- NULL = undeclared -> consumers fall back to the 250 ml pairing default
-- (DEFAULT_PAIRING_VOLUME_ML) — never to 0, which would silently remove the
-- pairing. Session-total constraint: plain water across the session >= the
-- sum of solvent minima of scheduled concentrated products; that water counts
-- toward the hydration total (no double demand). Gels chase ~150 ml (ruled in
-- the same section), carried as their solvent_min_ml so the rule stays
-- data-driven.
--
-- Backfill values are LABEL-DERIVED from each row's own serving_size text,
-- taking the minimum end of a stated range (verified against the live dev
-- catalog 2026-09-03; dev and prod catalogs are row-identical):
--   high_carb_drink_mix          '1 packet (90g carbs in 20-24 oz water)' -> 600
--   carb_drink_mix               '1 packet (60g carbs in 16-20 oz water)' -> 475
--   electrolyte_drink_mix        '1 scoop (in 16-20 fl oz / 475-590 mL)'  -> 475
--   electrolyte_packet           '1 packet (in 16 fl oz / 475 mL water)'  -> 475
--   high_sodium_electrolyte_mix  '1 stick (mix in 16 fl oz / 475 mL)'     -> 475
--   energy_gel                   gel chase (~150 ml, ruled)               -> 150
-- Deliberately left NULL (no label volume stated -> 250 ml fallback):
--   electrolyte_tablet ('1 tablet (in water)'), sports_drink_mix
--   ('1 serving (in water)').
--
-- Also adds pre_workout_templates.single_food_sufficient (food-recommendation
-- §6(a): a meal-tier feeding has >= 2 components unless flagged
-- single-food-sufficient). No template is flagged at introduction; flagging a
-- row is a catalog-curation act.
--
-- Idempotent; additive-only (safe on dev and prod at any time, playbook §3).
-- Apply to DEV first, PROD at release. Drift mirror: schemaVersion 19
-- (min_servings_during / is_indivisible / solvent_min_ml on the client copy).

alter table public.template_foods
  add column if not exists solvent_min_ml numeric(6,1),
  add column if not exists solvent_max_ml numeric(6,1);

comment on column public.template_foods.solvent_min_ml is
  'Catalog-conventions v1.1 (food-recommendation §6(e)): label-derived minimum plain-water solvent per serving for concentrated products. NULL = undeclared -> 250 ml pairing fallback, never 0.';
comment on column public.template_foods.solvent_max_ml is
  'Optional label maximum solvent per serving. NULL = no stated maximum.';

update public.template_foods set solvent_min_ml = 600, solvent_max_ml = 710
  where name = 'high_carb_drink_mix' and solvent_min_ml is distinct from 600;
update public.template_foods set solvent_min_ml = 475, solvent_max_ml = 590
  where name = 'carb_drink_mix' and solvent_min_ml is distinct from 475;
update public.template_foods set solvent_min_ml = 475, solvent_max_ml = 590
  where name = 'electrolyte_drink_mix' and solvent_min_ml is distinct from 475;
update public.template_foods set solvent_min_ml = 475
  where name = 'electrolyte_packet' and solvent_min_ml is distinct from 475;
update public.template_foods set solvent_min_ml = 475
  where name = 'high_sodium_electrolyte_mix' and solvent_min_ml is distinct from 475;
update public.template_foods set solvent_min_ml = 150
  where name = 'energy_gel' and solvent_min_ml is distinct from 150;

alter table public.pre_workout_templates
  add column if not exists single_food_sufficient boolean not null default false;

comment on column public.pre_workout_templates.single_food_sufficient is
  'food-recommendation §6(a): a meal-tier feeding has >= 2 components unless this flag licenses the single food. Default false; setting it is a curation act.';
