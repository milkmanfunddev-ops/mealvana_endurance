# 71: Onboarding keeps both the allergy and the diet avoids

**Status:** landed-pending-merge (wave 8, 2026-10-09, 9a400599f)
**Labels:** fix, round:develop-2026-10, area:onboarding, area:food-preferences
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing in code; cut at the wave-6 close from Finding 58-001.
**Next:** `/testing-wave develop-2026-10` (fix wave after test wave 7)
**Model:** opus

**What to build:** Lee, 2026-10-08 (58-001): both avoid sets survive onboarding. `OnboardingController` saves the allergy avoids and then the diet avoids with two `AuthService.saveFoodPreferences` calls (`onboarding_controller.dart:402` and `:432` at `8dec4583`), each `mergeMode: false`; since ticket 58 that call goes through `FoodPreferencesRepository.saveFoodPreferences`, whose replace branch (`food_preferences_dao.dart`) deletes every other local row for the user first, so the diet save wipes the allergy rows and only the diet rows are uploaded.

1. Save both sets in one call (build the combined avoid list, one `saveFoodPreferences` with `mergeMode: false`), or make the second call `mergeMode: true`. Prefer one call: onboarding is the one place a replace is right (a fresh account), and one write is one upload.
2. The anonymous-to-real migration path (`user_repository.dart:713`, `auth_migration_service.dart`) copies rows; check it is unaffected and say so in the Fix notes.

**Findings:** 58-001.

**Decisions:** Lee, 2026-10-08: fix ticket.

**Touches:** lib/features/onboarding/presentation/providers/onboarding_controller.dart, lib/features/auth/application/auth_service.dart (only if the call shape changes), test/features/onboarding/onboarding_avoids_seam_test.dart (new). 2 to 3 files. No codegen unless a `@riverpod` signature changes.

**Overlaps:** 72 and 73 share no file.

No edge-function or schema change. Nothing to deploy.

- [x] Seam test through the real `OnboardingController` on in-memory Drift + `FakePostgrest`: onboard with one allergy avoid (`peanuts`-class template food) and one diet avoid; after `saveAllOnboardingData`, Drift holds both rows and the recorded `food_preferences` upsert carries both, keys snake_case (ticket 58).
- [x] #116: `grep -rl` under test/ for `saveFoodPreferences`, `OnboardingController` and run every file named.
- [x] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator: a fresh onboarding with an allergy and a diet shows both avoids in Settings → Food Likes & Dislikes and both rows on the server.

## Fix notes

**The writer is not onboarding any more.** Since the 2026-08 redesign `saveAllOnboardingData` writes no avoids: it defaults the diet to omnivore and allergies to none (`onboarding_controller.dart`, step 2). The two `saveFoodPreferences` calls live in `_updateFoodPreferencesForAllergies`, which only `saveAllergies` and `saveDietaryPreference` reach, and those are called by the Settings modes of `allergies_screen.dart` and `dietary_preference_screen.dart` (their onboarding modes save nothing). So the bug hit an existing account in Settings, and it was worse than the Finding says: each replace also deleted the athlete's own Likes & Dislikes rows, and with two allergies the second allergy's save deleted the first's.

**What changed.**
- `_updateFoodPreferencesForAllergies` builds every new avoid (each allergy, then the diet) into one map and makes **one** `AuthService.saveFoodPreferences` call with `mergeMode: true`. The ticket preferred one call with `mergeMode: false`, but a replace is wrong here: this account already has rows, and a replace would still wipe the manual likes. One call is still one local write and one upload.
- Each row keeps its own source (`allergy:peanuts`, `dietary:vegan`) through a new optional per-food `sources` map, threaded `AuthService.saveFoodPreferences` → `FoodPreferencesRepository.saveFoodPreferences` → `FoodPreferencesDao.saveFoodPreferences` (`sources?[food] ?? source`). The undo (`removeFoodPreferencesBySource`) depends on it.
- A food already avoided by another restriction (an existing row whose source starts `allergy:` or `dietary:`) is left alone, so its row and source stay. A food in two new sets takes the first (allergies in list order, then the diet). Source is one value per row, so removing that first restriction later removes the avoid even if the other still applies. That was already true before this change.
- `AuthService.saveFoodPreferences` gained `mergeMode` (default false: replace) and passes `upload: true`. Its one remaining replace caller is `FoodPreferenceResolver`, which writes defaults only when the account has no rows.
- Nothing new to save → a `Food avoids: nothing new to save` breadcrumb and no repository call.
- Same file, found while testing: `saveAllergies`/`saveDietaryPreference` cached the profile read *before* the update in `_currentUser`. The controller is kept alive, so a second diet change in one session diffed against the old value (null) and never removed the first diet's avoids. It now caches the saved value (`copyWith(dietaryPreference: …)` / `copyWith(allergies: …)`). A null diet (skip) still leaves the cached value unchanged, because `copyWith` cannot set null.

**Replace vs diff (with ticket 78).** Every path that writes these rows, after both tickets:
- Settings → Food Likes & Dislikes: **diffs** (78). It writes only the foods whose level moved, merged in place.
- Settings → Allergies / Dietary Preference (this ticket): **merges** only the new avoids, minus foods already avoided.
- `FoodPreferenceResolver` defaults: **replaces**, through `AuthService` with its default `mergeMode: false`. It runs only when the account has no rows, so nothing is lost.
- Server pulls: merge (`syncFromRemote`, the sync handler) or replace (`UserRepository.fetchAndCacheRemoteFoodPreferences`, which skips while an upload is pending).

Both are right for the same reason: a write may only drop rows nobody chose to drop. Settings screens act on an account that already has rows, so they write only what the athlete changed. A replace fits only when the set being written is already the whole set. Under 78 every user-edit save, merge or replace, marks the keys it saved as pending, and the upload sends only those rows, without `id`/`created_at`. This ticket's merge therefore uploads just the new avoids.

**Anonymous-to-real migration: unaffected.** `user_repository.dart:713` (the reset path) copies the old profile's preferences onto a new local id through `UserRepository.saveFoodPreferences` → DAO replace, with no `sources`. It never calls the avoid writer or `AuthService.saveFoodPreferences`. `auth_migration_service.dart` re-parents the server rows (`update user_id … eq fromUserId`) and never touches Drift's save path.

**#77, twice at once / after a refresh.** Two quick Settings saves (allergies, then diet, or two allergy saves) each run one merge. The repository serialises the local writes per user in call order (`_serializedWrite`), so both sets land. Each save's `getFoodPreferenceSources` read can run before the other's write lands, so both may write the same food. The second write wins, which is the same row with a different source tag. The immediate upload reruns for the second save. A refresh does not reset this controller (it is `keepAlive`); `_currentUser` now carries the saved values, so the next save diffs against them.

**Tests run.**
- `test/features/onboarding/onboarding_avoids_seam_test.dart` (new, real `OnboardingController`/`AuthService`/`OnboardingService`/`FoodRepository`/`FoodPreferencesRepository`, in-memory Drift, `FakePostgrest` with producer-shaped `template_foods`): 3/3 pass. All 3 fail against the old controller, which leaves only the diet rows and drops the athlete's `banana` like.
- #116/#76: every file under `test/` naming `saveFoodPreferences`, `OnboardingController`, `onboardingControllerProvider`, `getFoodPreferenceSources`, or faking `AuthService` (28 files): 134 pass, 0 fail.
- `test/shared/source_guard/`: 20/20 pass.
- `flutter analyze` on the five touched files: no new issue. One existing warning at `food_preferences_dao.dart:168` (`dead_null_aware_expression`, a line this ticket did not touch).

**Not changed, noted for the lead.** `removeFoodPreferencesBySource` deletes local rows only. The server keeps the removed restriction's avoids, and a later pull (merge) brings them back. It was like that before this ticket, and it needs a server delete, which is a separate ticket.

Next: /testing-wave develop-2026-10
