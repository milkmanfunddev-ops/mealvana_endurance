-- A draft's shopping list goes with its draft (testing-wave ticket 101, Lee 2026-09-25; follow-on to Finding 19-002).
--
-- From now on the server deletes a draft's list when the draft is archived (another plan's confirm, new_plan,
-- use_plan_again; shopping.ts dropArchivedDraftLists). This cleans the lists archived drafts left behind before that.
-- Previous lists keeps only confirmed plans' lists (including one a later plan replaced) and hand-made lists.
--
-- "Never confirmed" = the plan's confirmed_at is unset (stamped by confirm_meal_plan, backfilled by
-- 20260925150100_meal_plans_name_and_confirmed_at.sql) AND the list's own confirmed_at is unset (markListConfirmed has
-- stamped every confirmed plan's list since the table was made on 2026-09-16). Either stamp keeps the list, so a plan
-- confirmed before the plan-column backfill still keeps its list.
--
-- Hand-made lists (plan_id null) are never touched. shopping_items cascade from shopping_lists.
-- Requires 20260925150100 (meal_plans.confirmed_at). Idempotent: a re-run finds nothing left to delete.
-- Count on dev before applying (read-only):
--   select count(*) from public.shopping_lists l join public.meal_plans p on p.id = l.plan_id
--    where p.status = 'archived' and p.confirmed_at is null and l.confirmed_at is null;

delete from public.shopping_lists l
 using public.meal_plans p
 where p.id = l.plan_id
   and p.status = 'archived'
   and p.confirmed_at is null
   and l.confirmed_at is null;
