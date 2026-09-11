# 02: Home location on the device

**Status:** done
**Blocked by:** None
**Next:** `/mattpocock-skills:implement 03`. Nothing more here — the device carries home location,
and a screen that edits it is not in this spec.

**What to build:** The three home fields carried by the local profile and its sync, so the app can
show and edit where the athlete lives rather than only Vana being able to set it.

**The server half is done and verified live (2026-09-10).** `home_city`, `home_lat`, `home_lon` and
`home_timezone` exist on dev; "I live in Birmingham, Alabama" wrote the city and
`America/Chicago`, and the next weather question answered for Birmingham rather than for a race
venue. Weather and Kroger both key off home when it is set.

**Why this was split out and why it needs care.** `UserProfile` is the model whose partial parsers
once silently reset onboarding answers — the "my onboarding answers vanished after I signed in" bug.
Three new fields mean touching the constructor, `fromSupabaseRow`, `copyWith`, the Drift table, a
schema step and every write path. Missing one of those is exactly how that bug happened.

- [x] The four columns on the Drift `users` table, a `from < 21` step, schema version 20 → 21
- [x] `UserProfile` carries them through the constructor, `fromSupabaseRow`, `fromJson`, `toJson`,
      `copyWith` and the DAO's save / update / row-to-domain mapping
- [x] A test proves a round trip through every parser leaves all four intact — the regression that bit before
- [x] They sync like the rest of the profile, both directions
- [ ] Setting home in conversation shows up on the device without a reinstall — needs a device pass

**Notes (2026-09-10).** Four columns, not three: `home_city`, `home_lat`, `home_lon`,
`home_timezone` (the spec's "coordinates" is two of them). All nullable — an athlete who has never
said where they live has no home, and weather and shopping fall back to the race venue exactly as
before.

`test/db_flows/registration_flow_test.dart` pins every hop: the remote-row parser, `fromJson`,
`copyWith` (including that an unrelated edit does not drop them), the DAO's save and update, and
`saveRemoteUserProfile` — the path by which a home Vana wrote server-side reaches the device.
`test/migrations/home_location_v21_migration_test.dart` pins the schema step and its replay.

Chasing "every write path" turned up one that would have dropped them:
`SettingsController.saveNutritionTargetOverrides` rebuilt `UserProfile` field by field to express
"clear the overrides", which `copyWith`'s `??` cannot say. That hand-rolled list already silently
reset body fat, lifestyle, training phase, the sweat test and the Garmin timestamps, and home
location would have joined them. `copyWith` now owns the clear
(`clearNutritionTargetOverrides: true`) and the screen uses it, so nothing can fall off that list
again.

No profile screen: the spec asks for home as a Fact, not for a settings surface. Bumping local
schema to 21 while dev `app_config` still says 20 is harmless — `_compareVersions` only forces a
resync when local is BEHIND — but `current_schema_version` must go to 21 when the build carrying
this ships.

No profile screen: the spec asks for home as a Fact, not for a settings surface.

**What review turned up.** The Standards axis wanted the controller write path tested through the
real notifier (`docs/test` rule), so `test/features/settings/nutrition_overrides_clear_test.dart`
now drives `saveNutritionTargetOverrides` on the real controller and asserts that clearing the
overrides leaves body fat, lifestyle, training phase, the sweat test and home untouched — the
exact fields the old reconstruction wiped. The stale copy of that reconstruction in
`user_repository_settings_test.dart` was deleted with it.

The Spec axis found one more path that would have dropped home:
`AuthMigrationService._upsertOAuthUserFromAnonymousProfile` hand-rolls its own `users` upsert map
rather than using `toJson()`, so an athlete who told Vana where they live before signing up would
have arrived at their new account without it. The four fields are added there. That map still
omits a dozen other columns (unit_system, sweat_rate, allergies, the macro fields) — pre-existing,
and worth its own ticket, but not this one's to fix at the auth boundary without a device pass.

**Ship gates.**
- `20260909190000_users_home_location.sql` is applied to DEV only. `toJson()` now always sends the
  four columns, so a build that reaches PROD before that DDL gets PGRST204 on every `users` upsert.
  It rides the meal-planning cutover push (`supabase/migrations/cutover/meal_planning/`), which has
  not been run.
- That cutover's `95_app_config_schema_20.sql` targets 20. The client is v21 now. Under-setting is
  safe (a client ahead of latest is simply OK) but the target should read 21 when it is run.

**Full history:** `../archive/issues-2026-09-10/07-home-location-fact.md` and `15-home-location-on-the-device.md`
