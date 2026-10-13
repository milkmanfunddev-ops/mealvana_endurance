# App map

What the app has, one page per `lib/features/` folder, written as a manual of this checkout (rules in
`ops/docs/doc-homes.md`). Each page: **What athletes can do here** · **What the data means** · **What already exists
to reuse** · **Links** (qa rulings, open intake, related pages). Big folders have a door page plus one page per
screen. Pages are indexed here by the nine athlete-job domains; a folder can serve more than one.

| # | Domain | Pages |
|---|---|---|
| 1 | Fuel a workout | [activities](activities.md) · [nutrition_plan](nutrition_plan.md) → [form](nutrition_plan/new-activity-form.md), [adjust macros](nutrition_plan/adjust-macros.md), [plan screen](nutrition_plan/activity-detail.md), [fuel log](nutrition_plan/fuel-log.md) · [formula_kit](formula_kit.md) · [weather](weather.md) · [personal_templates](personal_templates.md) · [sharing](sharing.md) |
| 2 | Your day (home) | [macro_dashboard](macro_dashboard.md) (the Timeline) · [home_shell](home_shell.md) · [calendar](calendar.md) · [fuel_timeline](fuel_timeline.md) · [daily_macros](daily_macros.md) |
| 3 | Race week | [events](events.md) · [carb_loading](carb_loading.md) · [race_checklist](race_checklist.md) |
| 4 | Log what you ate | [meal_logging](meal_logging.md) · [barcode_scanning](barcode_scanning.md) · [recipes](recipes.md) · [user_foods](user_foods.md) |
| 5 | Plan meals and shop | not on this branch (the meal-planning feature lives on `mealplanning`) |
| 6 | Connect your training | [integrations](integrations.md) · synced-workout behaviour on [activities](activities.md) |
| 7 | Coach | [coach_mode](coach_mode.md) |
| 8 | Learn and ask Vana | [education](education.md) · Vana is not on this branch |
| 9 | Account and app | [settings](settings.md) · [onboarding](onboarding.md) · [auth](auth.md) · [app_startup](app_startup.md) · [privacy](privacy.md) · [feedback](feedback.md) · [ai_credits](ai_credits.md) · [food_preferences](food_preferences.md) · [content](content.md) |
| – | Not athlete-facing | [nutrition](nutrition.md) · [notes](notes.md) · [_archived](_archived.md) |

Column meanings for every table are meant to live once in `docs/schema/<table>.md` (not generated yet); until then
each page's "What the data means" carries them. Usability hypotheses gathered while walking the pages:
`ops/docs/map-walk-pain-points.md`.
