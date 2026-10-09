# 78: Food preferences: Save writes only the foods that changed, and existing rows keep their id and created_at

**Status:** in-progress (wave 8, 2026-10-09)
**Labels:** fix, round:develop-2026-10, area:settings, area:sync
**Branch:** `develop-next` (fix-wave worktree)
**Source:** Finding 68-001; TRIAGE.md rulings of 2026-10-09.
**Blocked by:** nothing in code. Ticket 58 (landed, wave 6) built the load/save path this ticket narrows. One dev SQL at the close, run by the lead (Deploy).
**Next:** `/testing-wave develop-2026-10` (fix wave 8)
**Model:** opus

**What to build:** Lee, 2026-10-09 (68-001): Save Changes on Food Likes & Dislikes upserts only the foods whose level changed. Existing rows keep their id and created_at (update in place, never delete-and-insert). An untouched food never gets a default level written. The lead deletes the five stray rows on test@test.com at the fix-wave close. Line numbers are from code at `84615131`.

## Findings

- **68-001 · Food Preferences Save writes every on-screen food: unseen Fig Bar lands on the server as dislike 0, and every row's id and created_at are rewritten.** Run 68 (w7-20261008T2309Z), test@test.com. The server held 9 `food_preferences` rows, all created 17:23:53Z. The tester dragged Sports Drink 4 → 3, never opened "Show more food options", and saved at 23:16:20Z. The server went to 14 rows. Five were new and untouched: `carb_drink_mix`, `energy_chews_mini_pack`, `granola_bar`, `high_carb_drink_mix` at willing_to_try 2, and `fig_bar` at **dislike 0** (Fig Bar sits under the collapsed "Show more"). Every existing row got a new id and created_at. On-screen rows took 23:16:23. Rows not on the screen (`Bagel (plain)`, `Bananas`, `oatmeal_cooked`, `toast`) took 23:12:05, the time the screen pulled them. `food_preferences_saved` reported `total_foods: 10`. The Sports Drink part was right (49-010 save passed).
  Evidence: `runs/68/db-food-preferences-before.txt` (9 rows), `runs/68/db-food-preferences-after-save.txt` (14 rows, `fig_bar` dislike 0, new ids), `runs/68/drift-food-preferences-after-save.txt` (the same 14 locally), `runs/68/02-sports-drink-moved-to-3.png`. A later save at 23:48:43Z (Sports Drink back to 4) rewrote every id again: `runs/68/db-food-preferences-end.txt`.

**Why, from code.** There are three causes. Each alone breaks part of the ruling.

1. **The screen sends every food it shows.** `FoodPreferencesController._load` (`lib/features/settings/presentation/providers/food_preferences_controller.dart:150-162`) gives every loaded food a level: its row's level, or the default (2 for primary and user foods, 0 for additional ones, `:17-20`). The screen copies that whole map into `_sliderLevels` (`lib/features/settings/presentation/screens/food_preferences_screen.dart:291-293`). `_savePreferences` then saves all of it (`:331`, `Map<String, int>.from(_sliderLevels)`). `save` (`food_preferences_controller.dart:176-213`) maps every entry to a preference (`foodPreferenceForLevel(0)` is dislike, `:23-27`) and passes the whole map to `FoodPreferencesRepository.saveFoodPreferences(..., mergeMode: true, upload: true)` (`:201-207`). So the four primary foods with no row went in at the default 2, and `fig_bar`, an additional food, went in at the default 0.
2. **The local write is delete-and-insert.** `FoodPreferencesDao.saveFoodPreferences` (`lib/shared/database/daos/food_preferences_dao.dart:35-109`) inserts each entry with a fresh `_generateUuid()` id and `createdAt: DateTime.now()` under `InsertMode.insertOrReplace` (`:58-75`). The table's only key besides `id` is `UNIQUE(user_id, food_name)` (`lib/shared/database/tables/food_preferences.dart:43-47`). SQLite's OR REPLACE answers that conflict by deleting the old row and inserting the new one, so every saved food gets a new local id and created_at. The pull takes the same path: `ensureSynced` → `syncFromRemote` → `saveFoodPreferences(mergeMode: true)` (`lib/features/food_preferences/data/food_preferences_repository.dart:93-98`), and the sign-in hydrate does too (`lib/shared/services/sync/entity_sync/food_preference_sync_handler.dart:93-98`). That is why the off-screen rows took 23:12:05, the pull at Settings open.
3. **The upload sends every local row, with its id and created_at.** `_uploadAllPreferencesForUser` (`food_preferences_repository.dart:558-587`) reads every local row (`getAllFoodPreferenceEntries`, `food_preferences_dao.dart:247-254`). It sends `id` and `created_at` (`:569`, `:575`) in one upsert on `user_id,food_name` (`:583-585`). PostgREST's merge-duplicates updates every column in the payload, so each server row's id and created_at became the local ones. Both upload paths use it: the immediate one (`_runImmediateUpload`, `:531-554`) and the dirty walk (`uploadDirtyRecords`, `:127-176`). The dirty flag is one bool per user (`_isUploadPending`/`_setUploadPending`, `:457-469`), so nothing records which foods changed.

The server table gives `id` (`gen_random_uuid()`) and `created_at` (`now()`) defaults (`docs/dev_schema.txt:2067-2078`). The unique index `idx_food_preferences_user_food` on `(user_id, food_name)` is full, not partial (`:4753`), so the `onConflict` target stays valid (CLAUDE.md's 42P10 rule does not bite). No trigger sets `updated_at`.

## Fix

1. **The controller saves only what changed.** In `FoodPreferencesController`:
   - Keep the levels `_load` resolved as a private baseline (`Map<String, int> _baseline`), set where `_legacyNames` is set (`:164`) and reset in `build` (`:48-52`), as `_legacyNames` already is (Riverpod reuses the notifier across invalidate).
   - `save(levelsByKey)` (`:176`) keeps only the entries where `_baseline[key] != level` or the key is not in `_baseline`, plus every key `_load` folded from a legacy display-name row (`resolve`, `:136-148`; those rows are deleted locally at `:199-200`, so their level must be written under the key or it is lost). It calls the repository with that map only. An empty map writes nothing and makes no repository call. It records `_report.breadcrumb('Food preferences save: nothing changed', category: 'settings', data: {'count': levelsByKey.length})` (D9 does not strictly apply to a Settings save, but a no-op that looks like a save should leave a trace). State becomes the baseline with the changes applied, and the baseline moves to it.
   - `save` returns the number of changed foods (`Future<int>`). The screen adds `'changed_foods': n` to `food_preferences_saved` (`food_preferences_screen.dart:340-351`) and keeps `total_foods`, so the funnel can tell a save from a no-op.
   - The screen's own map stays as it is: it still holds every food's level for the sliders. Only the controller decides what is written.
2. **The DAO's merge write updates in place.** In `FoodPreferencesDao.saveFoodPreferences` (`food_preferences_dao.dart:58-75`), when `mergeMode` is true, insert with `onConflict: DoUpdate((old) => FoodPreferencesTableCompanion(preference: …, preferenceLevel: …, preferenceSource: Value(source), updatedAt: Value(now)), target: [foodPreferencesTable.userId, foodPreferencesTable.foodName])` instead of `mode: InsertMode.insertOrReplace`. A new food still inserts with a fresh id and `createdAt: now`; an existing `(user_id, food_name)` keeps its `id` and `created_at`. The replace branch (`mergeMode: false`, `:53-55`: delete all, then insert) is unchanged: onboarding uses it on a fresh account (ticket 71 owns it), and step 3 keeps a replace from rewriting server ids anyway. The legacy jsonb metadata write (`:78-108`) is unchanged.
3. **The upload sends only the pending foods, without `id` or `created_at`.**
   - Next to the bool flag, keep the pending food names per user in SharedPreferences: a `StringList` under a new key beside `foodPreferencesUploadPendingKey` (`food_preferences_repository.dart:593-594`), e.g. `food_preferences_upload_pending_names_<userId>`. `saveFoodPreferences` (`:198-256`) adds the saved keys to it in the same place it sets the flag (`:215-218`). A user-edit replace (onboarding, `AuthService`) adds every key it saved. The bool flag keeps its meaning (true while anything is pending), because `UserRepository`'s reconcile reads it (`lib/features/auth/data/user_repository.dart:839`).
   - `_uploadAllPreferencesForUser` becomes `_uploadPendingPreferencesForUser`: it reads the pending names and sends only the local rows whose `food_name` is in that set. **The payload drops `id` and `created_at`** (`:569`, `:575`) and keeps `user_id`, `food_name`, `preference`, `preference_level`, `preference_source` and `updated_at` (UTC, ticket 39). A new food gets the server's default id and `now()`. An existing one keeps both, because the conflict update only sets the columns sent. Local ids then differ from server ids for rows this phone created. Nothing reads a local id against the server (the only reader of `getAllFoodPreferenceEntries` is this upload, by grep).
   - **Back-compat:** a phone with the flag set but no names list (upgraded mid-pending) sends every local row once, still without `id`/`created_at`. That is today's set of rows, with the id damage removed.
   - **Clearing:** on success, both the immediate upload (`:531-538`) and the dirty walk (`:143-161`) clear the names and the flag only when no save landed since the rows were read (the existing `_saveGenerations` check and the rerun flag). Otherwise both stay, and the next pass resends. A failed upload leaves both (`:165-166`, `:539-540`).
   - `syncFromRemote`'s pending guard (`:83-89`) is unchanged. It keeps every local food while anything is pending.
4. **One-off dev cleanup of test@test.com, run by the lead at the close** (Deploy). The agent writes no SQL file and runs nothing against a database.

## Touches

- lib/features/settings/presentation/providers/food_preferences_controller.dart
- lib/features/settings/presentation/screens/food_preferences_screen.dart (the `changed_foods` analytics property only)
- lib/features/food_preferences/data/food_preferences_repository.dart
- lib/shared/database/daos/food_preferences_dao.dart
- test/features/settings/food_preferences_save_uploads_seam_test.dart
- test/new_sync/food_preferences_repository_test.dart
- test/shared/database/daos/food_preferences_dao_merge_keeps_ids_test.dart (new)
- test/new_sync/pull_keeps_dirty_rows_test.dart (only if its pending-flag fixture needs the names list)

No codegen expected: `build()` and the provider keep their signatures, and `food_preferences_controller.g.dart` does not change when a method's return type does. Run the unfiltered codegen anyway if the analyzer reports a stale part. No Drift schema change (the names live in SharedPreferences, so `schema_version_guard_test.dart` is untouched). No migration. No edge function.

**Call sites read, not changed** (other writers of these rows; each still works under the new rules): `AuthService.saveFoodPreferences` (`lib/features/auth/application/auth_service.dart:367-393`, replace, used by onboarding `onboarding_controller.dart:402, :432` and `FoodPreferenceResolver` `food_preference_resolver.dart:42`), `FoodPreferencesRepository.updateFoodPreference` (`:382-392`), `UserRepository.saveFoodPreferences`/`fetchAndCacheRemoteFoodPreferences` (`user_repository.dart:486-498`, `:923`), `FoodPreferenceSyncHandler.syncFoodPreferencesFromEdgeFunction` (`food_preference_sync_handler.dart:93`).

**Overlaps:** 71 edits `onboarding_controller.dart` (and maybe `auth_service.dart`), neither of which is in this list. Both tickets decide what is pending for the same rows (RUNBOOK #70), so each prompt states the other's rule. Under 78, a replace save marks every key it saved as pending and uploads those rows without `id`/`created_at`. Under 71, onboarding saves both avoid sets in one replace call. 71's seam assertion ("the recorded upsert carries both rows") holds under 78. The lead checks the Touches of 72, 73, 74–77 and 79–80 for these four lib files before the wave.

## Tests

- [ ] **Seam, through the real notifier** (`food_preferences_save_uploads_seam_test.dart`, `ProviderContainer`, real `FoodPreferencesController`, real `FoodPreferencesRepository` over in-memory Drift, `FakePostgrest`, real `SyncCoordinator`; `docs/test/README.md` §Seam tests). Seed the server producer-shaped: run 68's nine rows from `db-food-preferences-before.txt`, with server ids, `created_at`/`updated_at` `2026-10-08 17:23:53+00`, snake_case keys, and `Bagel (plain)`/`Bananas` included. Load with a primary list that holds the five keyed foods plus `carb_drink_mix`, `energy_chews_mini_pack`, `granola_bar` and `high_carb_drink_mix` (no rows), and an additional list holding `fig_bar`. Move `sports_drink` 4 → 3 and save. The recorded `food_preferences` upsert carries **one** row: `food_name: 'sports_drink'`, `preference_level: 3`, `preference: 'like'`, `updated_at` ending `Z`, and **no `id` key and no `created_at` key**. `on_conflict` is `user_id,food_name`. No row is sent for `fig_bar` or the four new foods. `save` returns 1.
- [ ] Same file: save with nothing moved records no upsert, records the "nothing changed" breadcrumb, and returns 0. Move a food that has no row (`granola_bar` 2 → 3): the upsert carries that one row, again without `id`/`created_at`.
- [ ] Same file: a legacy display-name row ("Energy Chews" at 3, no `energy_chews` row) is folded at load. Save with no slider moved sends `energy_chews` at 3 (the fold is a change) and deletes the local "Energy Chews" row.
- [ ] **DAO** (`food_preferences_dao_merge_keeps_ids_test.dart`, new, in-memory Drift): seed a row with id `X` and `createdAt` T₀. A merge save at a new level keeps id `X` and `createdAt` T₀, changes the level and moves `updatedAt`. A merge save of a new food inserts one row. A replace save behaves as today (deletes, then inserts).
- [ ] **Repository** (`food_preferences_repository_test.dart`): a pull (`syncFromRemote` with server rows) keeps the local ids of rows that already existed. Two saves of different foods while the first immediate upload is in flight: the rerun sends both foods and the names clear only after it. A refused upload keeps the names and the flag, and the next `uploadDirtyRecords` sends only those foods. The flag set with no names list sends every local row, without `id`/`created_at`. The ticket-39 UTC cases and ticket 58's cases stay green.
- [ ] `flutter analyze` clean on touched files.
- [ ] #116, #76: `grep -rl` under `test/` for `FoodPreferencesController`, `foodPreferencesControllerProvider`, `saveFoodPreferences`, `FoodPreferencesDao`, `foodPreferencesDao`, `uploadDirtyRecords`, `syncFromRemote`, `foodPreferencesUploadPendingKey`, `getAllFoodPreferenceEntries`, `FakePostgrest` and `FoodPreferencesScreen`, and run every file named (today that includes `user_repository_food_preferences_test.dart`, `sign_out_clears_device_test.dart`, `data_sync_service_test.dart`, `pull_keeps_dirty_rows_test.dart`).
- [ ] #117: the new breadcrumb is `_report.`, already covered by `reportCalls`. Run `test/shared/source_guard/` anyway, since the repository's catches move.
- [ ] #118: a no-op save and a failed upload are not error states. Only the missing user stays an `AsyncError` (`:180-187`).
- [ ] Async paths, written down in Fix notes: `save` twice at once (the repository serialises the writes, `_serializedWrite` `:491-509`; the names are a union; the rerun sends the latest rows); a save during an in-flight upload (its names are added, the generation moves, so nothing clears until the rerun); `load` after a refresh (the baseline resets in `build` and a stale load is dropped by the generation check, `:80`); Settings closed mid-upload (the upload belongs to the repository).
- [ ] Timeouts/retries: none added. The load's existing 10 s bound (`:38`, `:109-111`) still covers one write, the pending upload inside `ensureSynced`: an upsert of the pending foods on `user_id,food_name`, without `id`/`created_at`. Safe to repeat.

## Deploy

No function or schema change; nothing to deploy. **Lead, at the close, dev only** (`vlmtsdzpnjnavdgytcmi`, Management API `database/query`). Delete the five stray rows by user and food key, not by id: the 23:48:43Z save rewrote the ids again, so the ids in `db-food-preferences-after-save.txt` are gone (current ones are in `db-food-preferences-end.txt`).

```sql
-- 1. Read-only: one user, and exactly these five rows (expect 5; fig_bar at dislike 0, the rest at willing_to_try 2).
select count(*) from public.users where email = 'test@test.com';  -- expect 1
select id, food_name, preference, preference_level, created_at
from public.food_preferences
where user_id = (select id from public.users where email = 'test@test.com')
  and food_name in ('carb_drink_mix', 'energy_chews_mini_pack', 'granola_bar',
                    'high_carb_drink_mix', 'fig_bar')
order by food_name;

-- 2. Only if step 1 shows exactly those five rows.
delete from public.food_preferences
where user_id = (select id from public.users where email = 'test@test.com')
  and food_name in ('carb_drink_mix', 'energy_chews_mini_pack', 'granola_bar',
                    'high_carb_drink_mix', 'fig_bar')
returning food_name;

-- 3. After: 9 rows for the user, no fig_bar.
select count(*) from public.food_preferences
where user_id = (select id from public.users where email = 'test@test.com');
```

The original ids and the 17:23:53 `created_at` of the nine kept rows are already lost; this SQL does not try to restore them (the ruling asks only for the five deletes). Any simulator that saved on a wave-7 build still holds the five rows in Drift. The retest starts from a cleared app.

## Retest

On a simulator, in the retest ticket after fix wave 8, as test@test.com, starting from a cleared app and a fresh sign-in. Read `food_preferences` (named columns: `id, food_name, preference, preference_level, created_at, updated_at`) before and after each save.

- **68-001:**
  - Open Food Likes & Dislikes. Move Sports Drink one level, leave "Show more" closed, and Save Changes. The server still holds 9 rows. Only `sports_drink` changed: new level, new `updated_at` at `+00`. Its `id` and `created_at` are unchanged, and every other row's `id`, `created_at` and `updated_at` are unchanged. No `fig_bar` row and none of the four foods appear.
  - Open again and Save without moving anything: nothing on the server changes.
  - Move Granola Bar (no row) to Like: exactly one new row appears and the other rows are untouched.
  - `food_preferences_saved` shows `changed_foods` 1, 0 and 1.

## Questions for Lee

None. (The ruling covers the scope: test@test.com only. Ticket 58 never reached prod, so prod holds no rows written by this bug.)

Next: /testing-wave develop-2026-10 (fix wave 8)
