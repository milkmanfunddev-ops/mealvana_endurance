# 102: Switching accounts keeps unsynced work and shows nobody else's rows

**Status:** in-progress (wave 27, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** fable

**What to build:** Lee's ruling at wave 25 triage (2026-09-25, in the terminal): Drift exists so offline work is never lost, so the local wipe that ticket 33 added deletes only rows the server already has. Read `runs/86/triage-sync-analysis.md` first; it maps the tables, the upload paths and the unscoped reads with line numbers.
1. **Scope the reads that ignore the user.** `CalendarService.getAllEvents(userId)` ignores `userId` (`calendar_service.dart:151`, used by `calendar_controller.dart`); `UserDao.getLocalUserProfile()` returns any account's latest profile (`user_dao.dart:56`, used by `app_startup_service.dart` for analytics identity); `coach_repository.dart:1510` matches a pairing code against every local profile. Each reads the signed-in account only. `IntegrationsRepository.getAllIntegrations()` has no caller: delete it.
2. **Upload everything before sign-out.** `_uploadDirtyBeforeLogout` (`settings_controller.dart`) also uploads user_foods, integrations, formula_pins, onboarding_surveys, personal_formulas and personal_templates. Add personal_formulas and personal_templates to the sync coordinator's list too if they belong there (`sync_coordinator.dart:334-349`).
3. **Wipe only what the server has.** `AppDatabase.clearUserData(userId)` keeps a row with `needs_upload = 1`, and every parent that row needs to re-upload (the meal plan of a dirty plan meal, the carb-loading plan of a dirty day, the `users` row while any of the account's dirty rows stay). It keeps the two local-only tables (race_checklist_items, carb_loading_user_foods: no server copy, so deleting them loses them). food_preferences has no flag and re-uploads whole: delete it only when the pre-logout upload succeeded. Everything else of the account goes, as today.
4. **Say so offline.** When the pre-logout upload fails, sign-out still completes, and the athlete sees one line (`MealvanaSnackbar`, content system) that their unsynced changes stay on this phone and sync the next time they sign in.
5. **Sweep on sign-in (86-001).** Signing in runs the same rule for every other `user_id` on the phone: their server-held rows are deleted, their unsynced rows stay for their own next sign-in. This clears rows left before ticket 33.
6. **Unchanged:** account deletion still deletes everything of that account. Another account's dirty rows are never uploaded under this session (every upload query already filters on the signed-in user; keep it so).

**Findings:** 86-001, 86-007 (read both, and `runs/86/triage-sync-analysis.md`). Retest ticket 107 closes them; this ticket does not.

**Decisions:** Lee's ruling above (2026-09-25, in the terminal). No page writes.

**Touches:** lib/shared/database/app_database.dart, lib/features/settings/presentation/providers/settings_controller.dart, lib/shared/services/sync/sync_coordinator.dart, lib/features/calendar/application/calendar_service.dart, lib/features/calendar/ (calendar_controller callers), lib/shared/database/daos/user_dao.dart, lib/features/app_startup/application/app_startup_service.dart, lib/features/coach_mode/data/coach_repository.dart, lib/features/integrations/ (integrations_repository.dart), lib/shared/services/auth/auth_listener_service.dart or the sign-in path that runs the sweep, lib/features/content/domain/content_keys.dart, assets/config/content_defaults.json

- [ ] Seam test through the real sign-out path, upload failing: the account's clean rows are gone; its dirty rows, their parents and the two local-only tables stay; the offline line is shown.
- [ ] Seam test: sign-out with the upload succeeding uploads rows of all six added repositories before the wipe.
- [ ] Seam test through the real sign-in path: another account's clean rows are deleted, its dirty rows stay; when that account signs in again its dirty rows upload.
- [ ] One test per fixed read: with a second account's rows in the database, it returns only the signed-in account's.
- [ ] `flutter analyze` clean on touched files, the touched tests green.

Next: /implement-lee testing-wave
