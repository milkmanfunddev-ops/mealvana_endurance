-- A confirmed plan's list carries confirmed_at however it was built (testing-wave ticket 127, Finding 89-004).
--
-- Until now only confirm (markListConfirmed) and Rebuild shopping list (markListConfirmedIfUnset) stamped the plan's list.
-- A list remade by a plan edit (refreshShopping -> syncPlanList -> ensurePlanList) after the athlete deleted it was left
-- with confirmed_at null: the tab read "Made <date>" instead of "Confirmed <date>", it sorted by created_at, and
-- dropArchivedDraftLists lost its second guard. shopping.ts syncPlanList now stamps it on every build path; this
-- backfills the lists it missed.
--
-- A plan counts as confirmed when its status is confirmed or it was once (meal_plans.confirmed_at, backfilled by
-- 20260925150100_meal_plans_name_and_confirmed_at.sql). The list takes the plan's own confirmation time, falling back
-- to the list's creation time. Lists that already have a stamp keep it; hand-made lists (plan_id null) are untouched.
-- Requires 20260925150100 (meal_plans.confirmed_at). Idempotent: a re-run finds nothing left to stamp.
-- Count on dev before applying (read-only):
--   select count(*) from public.shopping_lists l join public.meal_plans p on p.id = l.plan_id
--    where l.confirmed_at is null and (p.status = 'confirmed' or p.confirmed_at is not null);

update public.shopping_lists l
   set confirmed_at = coalesce(p.confirmed_at, l.created_at)
  from public.meal_plans p
 where p.id = l.plan_id
   and l.confirmed_at is null
   and (p.status = 'confirmed' or p.confirmed_at is not null);
