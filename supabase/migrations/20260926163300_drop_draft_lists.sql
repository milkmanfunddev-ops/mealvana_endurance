-- No shopping list for a draft (testing-wave ticket 133, Finding 110-012; Lee 2026-09-26, clarifies mp-244).
--
-- From now on the server builds a plan's list at confirm and rebuilds it after edits to a plan that is, or once was,
-- confirmed (shopping.ts syncPlanList). A draft's edits fill only the `meal_plans.shopping` mirror. This cleans the
-- lists drafts built before that rule: Previous lists showed them as "From plan" next to the confirmed plan's list.
--
-- Same predicate style as 20260925170100_drop_archived_draft_lists.sql, on live drafts instead of archived ones:
-- the plan's confirmed_at is unset (stamped by confirm_meal_plan) AND the list's own confirmed_at is unset
-- (markListConfirmed). Either stamp keeps the list. Hand-made lists (plan_id null) are never touched; shopping_items
-- cascade from shopping_lists. The draft's mirror is left as it is. Idempotent: a re-run finds nothing left.
-- Count on dev before applying (read-only):
--   select count(*) from public.shopping_lists l join public.meal_plans p on p.id = l.plan_id
--    where p.status = 'draft' and p.confirmed_at is null and l.confirmed_at is null;

delete from public.shopping_lists l
 using public.meal_plans p
 where p.id = l.plan_id
   and p.status = 'draft'
   and p.confirmed_at is null
   and l.confirmed_at is null;
