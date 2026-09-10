-- Why a Meal shows nothing, kept per row.
--
-- The ladder already decides this — `resolveMealImage` returns one of
-- `transformed`, `no_bank_tile`, `multi_part_single_tile` — and pass 3 has been
-- counting the three into a summary and discarding which meal was which. So
-- "how many meals are blocked?" was answerable and "which ones can sourcing a
-- photograph actually help?" was not, and those are different questions: a
-- transformed meal needs a dish photo, a meal with no tile in the bank needs
-- the bank to grow, and neither is helped by the other's work.
--
-- Idempotent. Dev first; prod at cutover.
alter table public.meal_library
  add column if not exists image_blocked_reason text;

comment on column public.meal_library.image_blocked_reason is
  'Why the ladder found nothing honest to show: transformed | no_bank_tile | '
  'multi_part_single_tile. Written by pass 3 alongside image_blocked; null when '
  'the meal is not blocked. Values are the keys of BLOCKED_REASONS in '
  'scripts/meal-images/lib/ladder.mjs.';

-- Deliberately not a check constraint: the reasons are a pipeline vocabulary
-- that ticket 01 already expects to split (`no_bank_tile` currently covers both
-- "no tile exists" and "every candidate was a seasoning"), and a constraint
-- would make adding a reason a migration rather than an edit to the rules.
