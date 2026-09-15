# 25: An admin can review any meal

**Status:** done (wave 1, 2026-09-15)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee mealplanning`

**What to build:** A signed-in admin opens any meal and sees a comment box under the thumbs: is this a good recipe, and why. Each comment lands in a review table with the meal, the admin and the date, for the team to read. Athletes never see the box. Admin is a boolean on the user record, set by hand in the database, read by the server for the insert policy and by the client to show the box; there is no admin UI to grant it.

**Decisions:** mp-144; approved as mp-303.

**Touches:** supabase/migrations/20260916120000_meal_reviews_and_admin_flag.sql, lib/features/meal_planning/presentation/screens/meal_detail_screen.dart, lib/features/meal_planning/application/meal_detail_controller.dart, lib/features/meal_planning/data/meal_review_repository.dart, test/features/meal_planning/application/meal_detail_controller_test.dart

- [x] Migration: an is_admin boolean on users (default false) and a meal_reviews table whose insert policy requires it.
- [x] The box shows only when the signed-in user is an admin; a review writes one row (controller test through the real notifier).
- [ ] The dev account used for captures is set admin by hand and the simulator shows the box; a second dev account does not.

Next: /implement-lee mealplanning
