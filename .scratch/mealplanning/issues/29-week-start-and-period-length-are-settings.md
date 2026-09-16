# 29: Week start and period length are settings

**Status:** done (wave 4, 2026-09-16)
**Blocked by:** 15 (touches supabase/functions/_shared/vana/opener.ts), 22 (touches lib/features/meal_planning/presentation/widgets/review_sheet.dart).
**Next:** `/implement-lee mealplanning`

**What to build:** An athlete sets their week to start on Monday and their period to ten days; the Plan tab, coverage, the review sheet and the check-in opener all follow, and cook days derive from the settings rather than fixed offsets. Sunday and seven days stay the defaults. The two settings are keyed Vana settings like batch cooking, editable in Vana settings.

**Decisions:** mp-269; approved as mp-307.

**Touches:** lib/features/meal_planning/domain/vana_setting.dart, lib/features/meal_planning/presentation/screens/vana_settings_screen.dart, lib/features/meal_planning/application/vana_settings_controller.dart, lib/features/meal_planning/domain/plan_coverage.dart, lib/features/meal_planning/presentation/widgets/review_sheet.dart, lib/features/meal_planning/presentation/widgets/week_card.dart, supabase/functions/_shared/vana/env.ts, supabase/functions/_shared/vana/opener.ts, supabase/functions/_shared/vana/plan-math.ts, test/features/meal_planning/application/vana_settings_controller_test.dart

- [x] Two keyed settings, week start and period days, with defaults Sunday and 7, editable in Vana settings (controller test).
- [x] weekStartFor and the cook-day offsets read the settings; a Monday start moves cook, top-up and fresh days accordingly (server seam).
- [x] Coverage, the review sheet and the week card read the period length (widget tests).
- [x] Simulator: change the start day and see the Plan tab's week move.

Next: /implement-lee mealplanning
