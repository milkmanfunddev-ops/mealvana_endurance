# 96: One shopping list per plan, deletable with a warning and rebuildable from the plan

**Status:** done (wave 25, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** Lee's ruling on 19-002 (2026-09-25): "they can delete it with a clear, concise warning but they can rebuild a shopping list at any point perhaps from the mealplan page. each mealplan should have at most 1 shopping list though so edits and things like that shouldn't keep making duplicate shopping lists."
1. Deleting the confirmed plan's own list shows its own short warning (content system) saying that this is the plan's list and it can be rebuilt from the plan. A hand-made list keeps today's dialog.
2. The Plan page offers "Rebuild shopping list". It builds the plan's list from its meals (the same server path confirm uses, mp-244) and lands on Food > Shopping.
3. A plan has at most one list. Confirm, every plan edit and Rebuild update the plan's existing list in place (or create it when none exists), and never add a second. A unique constraint on the plan id for plan lists enforces this. Check dev for existing duplicates before adding it and report them; do not delete data.

**Findings:** 19-002. 19-009 (list rebuilt after an edit) is retested in ticket 89 against today's build. Retest ticket 100 closes 19-002.

**Decisions:** mp-244 (the server builds the list at confirm and after every edit), mp-669 (open on the page, answered by Lee's ruling above). No page writes.

**Touches:** supabase/functions/_shared/vana/ (grocery build and `delete_shopping_list` in contracts.ts), lib/features/meal_planning/presentation/screens/shopping_tab.dart, plan_tab.dart, their controllers, assets/config/content_defaults.json, a migration `20260925169600_one_list_per_plan.sql` if the constraint is added.

- [x] Deno test: two edits and a rebuild of one plan leave exactly one list for that plan, with rows equal to its meals' ingredients.
- [x] Deno test: rebuilding after a delete creates one list, and the plan's `shopping` mirror is filled again.
- [x] Seam test through the real notifier for Rebuild (controller write path).
- [x] Widget test: the plan list's delete dialog shows the plan warning; a hand-made list's does not.
- [x] `flutter analyze` clean, deno tests for touched functions. SQL and deploy: wave lead.

Next: /implement-lee testing-wave
