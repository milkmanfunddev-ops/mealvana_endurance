# 12: A lapsed account cannot write

**Status:** ready-for-agent
**Blocked by:** 03, 04, 08 (touches lib/features/auth/application), 09 (touches lib/features/auth/application), 11.
**Next:** `/implement-lee paywall`
**Model:** fable

**What to build:** Every write controller checks the write-access provider before writing; for a lapsed account the edit opens the paywall and nothing is written or queued for sync.

**Decisions:** mp-457, mp-280; approved as mp-491.

**Touches:** lib/features/activities/application, lib/features/ai_credits/application, lib/features/app_startup/application, lib/features/auth/application, lib/features/barcode_scanning/application, lib/features/calendar/application, lib/features/carb_loading/application, lib/features/coach_mode/application, lib/features/content/application, lib/features/daily_macros/application, lib/features/education/application, lib/features/events/application, lib/features/formula_kit/application, lib/features/fuel_timeline/application, lib/features/home_shell/application, lib/features/integrations/application, lib/features/kroger/application, lib/features/macro_dashboard/application, lib/features/meal_logging/application, lib/features/meal_planning/application, lib/features/nutrition_plan/application, lib/features/onboarding/application, lib/features/personal_templates/application, lib/features/race_checklist/application, lib/features/recipes/application, lib/features/sharing/application, lib/features/weather/application, test/features/ai_credits/application, test/features/auth/application, test/features/coach_mode/application, test/features/integrations/application, test/features/macro_dashboard/application, test/features/meal_planning/application, test/features/nutrition_plan/application

- [ ] Each write controller refuses while lapsed (one seam test per controller write path, through the real notifier).
- [ ] Nothing is written locally or queued while lapsed.
- [ ] An active account writes as before (the full suite stays green).

Next: /implement-lee paywall
