# 39: The five remaining timestamptz writers send UTC

**Status:** retest FAILED 2026-10-08 (ticket 49, wave 5): the Settings save never uploads → 49-010; the UTC writer could not be exercised
**Labels:** fix, round:develop-2026-10, area:sync
**Branch:** `develop-next` (fix-wave worktree)
**Blocked by:** nothing.
**Next:** `/testing-wave develop-2026-10` (fix wave 4)
**Model:** opus

**What to build:** Ticket 22 (commit `6a1236ed`, 01-004) made the signup-path writes send `created_at`/`updated_at` as UTC (`.toUtc().toIso8601String()`; seam test `test/features/daily_macros/data/daily_macro_targets_upload_utc_test.dart` against `FakePostgrest`, asserting `endsWith('Z')` and `isAtSameMomentAs`). Its closing note listed nine more writers. Checked against the dev and prod dumps (`docs/dev_schema.txt`, `docs/prod_schema.txt`), only **five** write naive local time into `timestamptz` columns; the rest are wall-clock columns by design or not server writes (Decisions). Lee (2026-10-08, wave 2 question m): finish the sweep. Line numbers from code at `4e77cf43`.

1. **Coach** (`lib/features/coach_mode/data/coach_repository.dart`): `final now = DateTime.now()` feeds `coach_athlete_relationships` at `:553-556, :626-627, :684-685, :742-743` (`requested_at`/`accepted_at`/`declined_at`/`archived_at` and `updated_at`), `coaches` at `:1642-1644` (`submitted_at`, `created_at`, `updated_at`), and `users.updated_at` at `:1276, :1356`. All `timestamptz`. Use `now.toUtc()` / `DateTime.now().toUtc()`. **Leave** `:1138-1139` (activities) and `:1209-1210` (events): wall-clock columns. Pairing codes (`:1813, :2248`) and `coach_messaging_repository.dart:254-255, 335-336` are already UTC.
2. **Food preferences**: `food_preferences_repository.dart:147-148` (`uploadDirtyRecords`) and `:457-458` (`_uploadAllPreferencesForUser`); `lib/shared/services/sync/entity_sync/user_sync_handler.dart:239-240` (`uploadFoodPreferences`).
3. **Feedback**: `feedback_repository.dart:275` (`_saveToSupabase`) and `:450` (`_toSupabaseJson`).
4. **User foods**: `user_foods_repository.dart:124-126` (`created_at`, `updated_at`, `client_updated_at`, all `timestamptz`); `lib/shared/services/food_management/user_food_crud_service.dart:335-337, :352, :384-385`. **Leave** `barcode_scanner_service.dart:181-182`: a local Drift cache write.
5. **Personal templates**: `lib/features/personal_templates/domain/personal_template.dart:154-155` (`toSupabaseJson`, upserted at `personal_templates_repository.dart:345, :404`).
6. **Optional, for consistency**: `coach.dart:126-127`, `coach_athlete_relationship.dart:119-120`, `coach_message.dart:102-103` `toJson` (naive; no upload caller found). Change them only if a test covers them; otherwise leave and say so.

**Findings:** none (wave 2 question m; ticket 22's closing note).

**Decisions:**
- **Not changed, by design:** activities (`activity_mapper.dart:576-577, 685-686`, `activity_sync_handler.dart:414-415`), events (`events_repository.dart:753-754`, `event_sync_handler.dart:162-163`) and carb loading (`carb_loading_mapper.dart:105-109, 132`; `carb_loading_repository.dart:1029-1033, 1065, 1104`) write `timestamp without time zone` columns; `ActivityMapper.utcIso8601`'s doc (`:744-751`) says these must not go through it, and `activity_sync_handler_timestamptz_test.dart:67-72` + `activity_mapper_test.dart:210-261` pin them naive. A `Z` string into those columns would store the UTC wall clock and change their meaning. Moving them to `timestamptz` is a schema decision for another ticket.
- **Not a write:** `nutrition_plan_service.dart:459-460` builds a map for a local parse; no `nutrition_plans` table exists in either dump.
- No shared helper is introduced: ticket 22 inlined `.toUtc()`; do the same.

**Touches:** lib/features/coach_mode/data/coach_repository.dart, lib/features/food_preferences/data/food_preferences_repository.dart, lib/shared/services/sync/entity_sync/user_sync_handler.dart, lib/features/feedback/data/feedback_repository.dart, lib/features/user_foods/data/user_foods_repository.dart, lib/shared/services/food_management/user_food_crud_service.dart, lib/features/personal_templates/domain/personal_template.dart, test/new_sync/coach_repository_sync_test.dart, test/new_sync/food_preferences_repository_test.dart, test/new_sync/feedback_repository_sync_test.dart, test/new_sync/user_foods_repository_test.dart, test/features/personal_templates/personal_templates_repository_test.dart, test/shared/services/food_management/user_food_crud_service_utc_test.dart (new), test/shared/services/sync/entity_sync/user_sync_handler_utc_test.dart (new). 14 files. No generated files.

**Overlaps:** none in wave 4 (34 root widget; 35/36 settings; 37 integrations; 38 meal logging).

No edge-function or schema change. Nothing to deploy. Ticket 22's note about the server reading naive strings in its own zone applies to dev and prod alike; no SQL fix for existing rows (they are at most hours off and overwritten on the next write).

- [x] Seam tests (ticket 22's pattern: a Drift row read back local, uploaded through the real repository against `FakePostgrest`, assert `endsWith('Z')` and `isAtSameMomentAs`) for each of the five areas, extending the named existing files and adding the two new ones.
- [x] The two pinned-naive tests (`activity_sync_handler_timestamptz_test.dart`, `activity_mapper_test.dart`) still green: nothing wall-clock moved.
- [x] `flutter analyze` clean on touched files.
- [ ] Retest: one real read per changed PostgREST write at dev deploy time is not needed (no function changed); the lead checks one `food_preferences` row's `updated_at` offset after the next simulator run (ticket 31 or 30).

**Fix notes (wave 4, `78a5947e`).** All five areas send `.toUtc().toIso8601String()`, inline. Two more sites in the touched files had the same bug and were fixed with them: `feedback.timestamp` (`feedback_repository.dart` `_saveToSupabase` + `_toSupabaseJson`; `timestamptz` in both dumps) and the two `users.updated_at` stamps in `UserSyncHandler.syncUsers` / `uploadUserProfile`. Item 6 left alone: no upload caller and no test covers those `toJson`s. Not touched, outside this ticket's files: `UserProfile.toJson` `sweat_test_date` (`timestamptz`, still naive; lives under `lib/features/auth/`). Seam tests: coach (create/accept/decline/archive/athlete profile/nutrition targets/coach application), food preferences (repo upload + immediate upload; handler upload), feedback (dirty upload + survey save), user foods (repo upload; crud save/update/delete), personal templates (create + dirty upload). Red-checked against the unfixed lib. The fourth box is the lead's retest.

Next: /testing-wave develop-2026-10 (fix wave 4)

**Rulings at the wave-4 close (Lee, 2026-10-08).** The `sweat_test_date` naive write is follow-up ticket 53.
