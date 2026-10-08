# 58-001 · Onboarding saves allergy avoids then diet avoids each with mergeMode false, so the diet save deletes the allergy rows locally

- kind: bug
- status: triaged
- ticket: 58
- run: w6-lead
- screen: Onboarding (allergies, then diet)
- decision: 

**Steps.**
1. From code, filed by the wave lead (ticket 58's Decisions, drafter 2026-10-08): `onboarding_controller.dart` saves the allergy avoids with `mergeMode: false`, then the diet avoids with `mergeMode: false`.
2. `FoodPreferencesDao.saveFoodPreferences` with `mergeMode: false` deletes every other local row for the user before writing (`food_preferences_dao.dart`, the replace branch).

**Expected.**
Both sets of avoids survive onboarding locally and reach the server.

**Actual.**
The diet save replaces the allergy rows locally, so only the diet avoids remain in Drift after onboarding (and, since ticket 58, only those are uploaded at once). Filed by the wave lead; not reproduced on a device.

**Evidence.**
- `.scratch/testing-wave/rounds/develop-2026-10/issues/58-*.md`, Decisions: "Also seen, not in this ticket".
- Code: `lib/features/onboarding/presentation/providers/onboarding_controller.dart` (the two `saveFoodPreferences` calls), `lib/shared/database/daos/food_preferences_dao.dart` (replace branch).

**Decision quote.**
> 

**Triage.**
fix ticket 71 · Lee, 2026-10-08: both avoid sets survive onboarding.
