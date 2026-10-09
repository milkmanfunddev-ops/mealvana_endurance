# 71: Onboarding keeps both the allergy and the diet avoids

**Status:** in-progress (wave 8, 2026-10-09)
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

- [ ] Seam test through the real `OnboardingController` on in-memory Drift + `FakePostgrest`: onboard with one allergy avoid (`peanuts`-class template food) and one diet avoid; after `saveAllOnboardingData`, Drift holds both rows and the recorded `food_preferences` upsert carries both, keys snake_case (ticket 58).
- [ ] #116: `grep -rl` under test/ for `saveFoodPreferences`, `OnboardingController` and run every file named.
- [ ] `flutter analyze` clean on touched files.
- [ ] Retest on a simulator: a fresh onboarding with an allergy and a diet shows both avoids in Settings → Food Likes & Dislikes and both rows on the server.

Next: /testing-wave develop-2026-10
