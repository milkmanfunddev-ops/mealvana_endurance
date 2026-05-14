# Database Audit Report

**Date:** 2026-05-14
**Scope:** Supabase dev schema (35 tables, 3,288-line dump) cross-referenced with Flutter `lib/` and `supabase/functions/`
**Goal:** Eliminate unused tables/columns, consolidate duplicates, fix structural defects, and tighten security

---

## TL;DR — The Top 12 Actions

| # | Action | Type | Risk | Effort |
|---|---|---|---|---|
| 1 | **Verify RLS on token-bearing tables** (`integrations`, `garmin_user_mappings`, `coach_messages`, `users`, pairing codes). Dump grants full DML to `anon` on these. If RLS isn't enforced this is a critical leak. | Security | **CRITICAL** | S |
| 2 | **Drop `feature_survey_responses`** — zero references in Flutter or edge functions; appears in Drift schema history only. | Dead table | Low | XS |
| 3 | **Drop `catalog_sync_runs`** — zero references in Flutter, no read in edge functions; pure audit log nobody queries. Verify with ops first. | Dead table | Low | XS |
| 4 | **Delete legacy edge functions**: `generate-macros`, `generate-macros-v3`, `generate-nutrition-plan` (v1), `generate-nutrition-plan-v2`, `sync-final-surge`. No live Dart callers. | Dead code | Low | XS |
| 5 | **Delete dead Dart**: `lib/features/nutrition_plan/application/llm_nutrition_plan_service.dart` and `bulk_nutrition_plan_service.dart` (+ `.g.dart`). Only consumed by each other; zero external callers. They are the sole reason `generate-nutrition-plan` (v1) appeared "in use." Fix mislabeled "V2" log strings in `nutrition_plan_service.dart:325-394` (function actually calls v3). | Dead code | Low | XS |
| 6 | **Unify `foods` ↔ `template_foods`** — migration `20260220000007_unify_food_tables.sql` explicitly calls `foods` legacy/kept for v1 compat. Migrate readers to `template_foods` then drop `foods`. | Duplicate table | High | L |
| 7 | **Consolidate `templates` ↔ `pre_workout_templates`** — same purpose, different storage. `pre_workout_templates` is the newer normalized model (matches `during_workout_templates`). Migrate Flutter reads, drop `templates`. | Duplicate table | High | M |
| 8 | **Merge `coach_pairing_codes` + `athlete_pairing_codes`** into one `pairing_codes` table with `requested_by` discriminator. | Duplicate table | Low | S |
| 9 | **Remove OAuth tokens from `garmin_user_mappings`** — duplicate of `integrations` tokens. Make mappings table identity-only. | Security + dedup | Med | S |
| 10 | **Fix `activity_status_enum`** — drop `'archivedForBrick'` (camelCase); keep snake_case `'archived_for_brick'`. Currently both values are live. | Schema bug | Low | S |
| 11 | **Fix duplicate FK declarations** on `user_foods.user_id` and `carb_loading_user_foods.user_id` (both declared twice in dump). Resolve `references ???` on `personal_templates.user_id` and `athlete_pairing_codes.*`. | DDL bug | Low | XS |
| 12 | **Normalize `users` sport defaults** into a `user_sport_defaults` child table — removes ~10 columns from the 60-column `users` row, also kills the overlapping unit-system prefs. | Refactor | Med | M |

---

## Section 1 — Table-by-Table Status

Each table is tagged: **KEEP** (actively used), **MERGE** (consolidate with another), **DROP** (no live consumers), **NORMALIZE** (split out columns), or **INVESTIGATE** (data shows it but usage unclear).

### Core domain (KEEP, but with column-level cleanup)

| Table | Status | Notes |
|---|---|---|
| `users` | NORMALIZE | 60 columns. Sport defaults, three overlapping unit prefs, JSONB `food_preferences` (table also exists), partial `_updated_at` shadow columns only on weight/body_fat. Split sport defaults into `user_sport_defaults`. |
| `activities` | KEEP | Hottest table; 55 cols incl. 3 JSONB (`nutrition_plan_data`, `fuel_log_data`, `brick_metadata`). `status` is nullable — should be NOT NULL. Snapshots (`cycling_ftp_watts`, `swimming_css_seconds_per_100m`) duplicate `users`/`integrations` — keep but document intent. |
| `events` | KEEP (review) | `event_name`, `location`, `registration_url` duplicate columns on `public_events` and `activities.title`. Some columns nullable that shouldn't be. `start_time` is `text` here but `time` in `public_events` — type drift. |
| `public_events` | KEEP | FTS + trigram, generated `search_vector`. Only accessed by `search-public-events` RPC. |
| `integrations` | KEEP | Sole canonical OAuth token store after #9. |
| `garmin_user_mappings` | NORMALIZE | After removing `access_token` / `refresh_token`, becomes an 8-col identity map. |
| `garmin_health_data` | KEEP | Server-authoritative; written only by `garmin-push`/`garmin-ping`, read by `calculate-daily-macros`. |
| `coach_athlete_relationships` | KEEP | Already uses `requested_by` discriminator — the model for #8. |
| `coach_messages` | KEEP (review cascades) | THREE FKs to `users` with `ON DELETE CASCADE` — deleting either user obliterates the conversation. Change at least `sender_user_id` to `SET NULL` for archival. Also missing index on `sender_user_id`. |
| `coaches` | KEEP | |
| `food_preferences` | KEEP | Conflicts with `users.food_preferences` JSONB — drop the JSONB column. |
| `user_foods` | KEEP | Fix duplicate FK declaration; `device_id` explicitly DEPRECATED per migration comments. |
| `template_foods` | KEEP | Canonical food catalog with USDA + LP-solver columns. Target for #6. |
| `daily_macro_targets` | KEEP | `algorithm_version` defaults to `'v4'` — rows may still be v1/v2/v3; consider purging old rows. |
| `personal_templates` | KEEP | Unresolved FK target in dump (`references ???`) — verify migration. |
| `education_content` | KEEP | Read-only from Flutter. |
| `app_content` | KEEP | Drift cache table exists but unused at runtime; Flutter reads via Supabase + SharedPreferences. Could remove the Drift table. |
| `app_config` | KEEP | Version-check only. |
| `feedback` | KEEP (review) | No `user_id` FK — links via free-text `user_name`. Column literally named `timestamp` is nullable while `created_at` exists. Rename, add FK. |
| `catalog_products`, `catalog_variants`, `catalog_items` (mv) | KEEP | Read-only via `lookup-product`/`search-catalog` edge functions. |
| `athlete_pairing_codes`, `coach_pairing_codes` | MERGE | See #8. |

### Duplicate / merge candidates

| Table | Pair | Recommendation |
|---|---|---|
| `foods` | ↔ `template_foods` | Migration `20260220000007` says: *"The `foods` table remains untouched for backwards compatibility with v1 edge functions and old app versions."* Plan a migration window to retire v1 edge functions and old app versions, then drop. View `v_food_sport_phase_settings` already labels `foods.max_servings_*` as `legacy_max_*`. |
| `templates` | ↔ `pre_workout_templates` | Both store pre-workout templates with overlapping columns. `pre_workout_templates` uses normalized `component_food_names TEXT[]` + `component_ratios JSONB` (same pattern as `during_workout_templates`). `templates` uses denormalized `foods JSONB`. Flutter currently reads `templates` (server-authoritative); edge function v3/v4 read `pre_workout_templates`. Pick `pre_workout_templates`. |
| `coach_pairing_codes` | ↔ `athlete_pairing_codes` | Mirror tables. Single `pairing_codes` with `requested_by` discriminator. |
| `carb_loading_user_foods` | ↔ `user_foods` | `carb_loading_user_foods` has `source_food_id` / `source_user_food_id` FKs back to the other food tables — it's a denormalized copy. Consider tagging in `user_foods` instead. |
| `food_sport_phases` | (no pair) | Used only by the `v_food_sport_phase_settings` view; never queried directly by Flutter or edge functions. **INVESTIGATE** whether the view itself is consumed. |
| `during_workout_templates` | (no pair, but barely used) | Only referenced in `_shared/nutrition/template-food-queries.ts`. **INVESTIGATE** whether it's reached at runtime. |

### Dead / unused tables (DROP candidates)

Confirmed via cross-reference of Flutter usage + edge function code:

| Table | Why dead | Confidence |
|---|---|---|
| `feature_survey_responses` | Zero references in `lib/` or `supabase/functions/`. Appears only in old Drift schema_versions history. Column `device_id` is misleadingly named — it's `users(id)`. | High |
| `catalog_sync_runs` | Audit log written by a sync job not present in active edge functions. No reads from Flutter or edge functions. | Medium (verify with ops; deployed jobs may write to it) |

**Suspect but verify** before dropping:

| Table | Reason to verify |
|---|---|
| `during_workout_templates` | Referenced only in a shared utility file. If `generate-nutrition-plan-v3` is archived (item #5), this becomes unreferenced. |
| `food_sport_phases` | Referenced only via the view `v_food_sport_phase_settings`. Confirm view callers. |
| `carb_loading_*` (5 tables) | The `_archive/20251030000010_sync_prod_to_dev_complete.sql` migration drops the entire carb-loading subsystem, but the migration is archived/never-applied. The tables still exist in the dump and Flutter still writes to them. **Verify roadmap intent** — if carb loading is being retired, these are huge wins to drop. |

---

## Section 2 — Cross-Cutting Issues

### 2.1 Security: RLS posture is unclear from this dump

Every one of the 35 tables grants `delete, insert, references, select, trigger, truncate, update` to `anon` in the dump. This includes:

- `integrations` — holds `access_token` and `refresh_token`
- `garmin_user_mappings` — holds `access_token` and `refresh_token`
- `users` — full PII
- `coach_messages` — private messaging
- `coach_pairing_codes`, `athlete_pairing_codes` — auth secrets

This is normal Supabase grant scaffolding *if RLS policies are enabled and restrictive*. The dump does not render RLS policies. **Action: confirm via `pg_policies` query that RLS is enabled and policies are in place on every PII/token-bearing table**, and that none of them have `USING (true)` blanket policies.

Edge functions almost universally instantiate Supabase with `SUPABASE_SERVICE_ROLE_KEY` — which legitimately bypasses RLS. The risk surface is `upload-all-data`, which upserts records based on caller-supplied `user_id` without re-validating against JWT subject. Add a check that `record.user_id == jwt.sub` before writing.

### 2.2 Schema-vs-reality drift

- **`nutrition_plans` table** is referenced by SQL functions `upsert_nutrition_plan_versioned` and `delete_nutrition_plan_versioned`, but the table is not in this schema dump. Migration `_archive/20251109000000_embed_nutrition_plan_on_activities.sql` embedded plan data into `activities.nutrition_plan_data` JSONB. The orphan functions still exist and will throw at runtime if called. **Action: drop the functions or rewrite their bodies.**
- **`auth_sessions` table** is referenced by `update_auth_sessions_updated_at()` trigger function — also not in the dump. Same issue.
- **`catalog_items`** is a materialized view (created `20260324100000`) but several edge functions treat it as a table. Reads work; writes would fail. Confirm migrations apply cleanly in every environment.

### 2.3 Enum sanity

- `activity_status_enum` has BOTH `'archivedForBrick'` (camelCase) and `'archived_for_brick'` (snake_case). Failed rename. Migrate rows, drop one value.
- `category_enum` comment claims it includes `during_bike`, `during_swim` — actual values are `('before_run','during_run','after_run','transition')`. Either the comment is stale or migration `_pending/20250114_expand_category_enum_and_cleanup.sql` was supposed to add them and didn't. Verify pending migrations.

### 2.4 DDL defects in the dump

- `user_foods.user_id` — `references users on delete cascade` appears TWICE.
- `carb_loading_user_foods.user_id` — same duplicate.
- `personal_templates.user_id`, `athlete_pairing_codes.user_id`, `athlete_pairing_codes.used_by_coach_id` — show `references ??? ()` (unresolved by the dumper). Either schema is inconsistent or dump tool failed. Re-render and verify.
- `coach_pairing_codes` FKs to `users` lack explicit `ON DELETE` behavior — default is NO ACTION, meaning deleting a user with outstanding codes will fail.

### 2.5 Index hygiene

Missing:
- `coach_messages.sender_user_id`
- `coach_pairing_codes.used_by_athlete_id`
- `athlete_pairing_codes.used_by_coach_id`
- `users.email` (declared but no index despite use for prefill per comment)
- `personal_templates.updated_at` (listing queries)

Redundant:
- `activities`: `uq_activities_provider_workout` AND `idx_activities_provider_sync` cover similar columns
- `templates` has 5 single-column indexes — likely some are never queried independently

### 2.6 JSONB sprawl on hot tables

`activities` carries three large JSONB blobs: `nutrition_plan_data`, `fuel_log_data`, `brick_metadata`. This was a deliberate denormalization (migrations `20251109` and `20251111`) to reduce JOIN cost. The trade-off is that fuel-log analytics, completion stats, and brick segment queries cannot be expressed in SQL. Future direction: at least split `fuel_log_data` into `fuel_log_items(activity_id, food_id, planned_qty, actual_qty)` so completion analytics become possible.

### 2.7 Duplicate-tracking on `garmin_user_mappings`

OAuth `access_token` / `refresh_token` live in both `integrations` (where `provider='garmin'`) and `garmin_user_mappings`. Per project memory, the Garmin User ID and JWT `garmin_guid` are different values — mapping table earns its keep for identity. But token duplication is a footgun: token refresh in one place will silently drift from the other. **Pick `integrations` as source of truth; strip tokens from `garmin_user_mappings`.**

---

## Section 3 — Edge Function Cleanup

### Active, keep
`create-user`, `delete-user`, `upsert-user-profile`, `calculate-daily-macros`, `garmin-push`, `garmin-ping`, `garmin-deregistration`, `garmin-user-mapping`, `garmin-oauth-callback`, `generate-macros-v4`, **`generate-nutrition-plan-v3`** (this is the live LLM plan generator — called by `nutrition_plan_service.dart:348` → `macro_targets_controller.dart:1881`), `get-foods`, `get-weather-forecast`, `lookup-product`, `search-catalog`, `save-user-food`, `search-public-events`, `send-nutrition-plan-email`, `sync-all-data`, `upload-all-data`.

### Drop now (no live Dart callers)
- `generate-macros` (v1)
- `generate-macros-v3`
- `generate-nutrition-plan` (v1) — only invoked by dead Dart (`llm_nutrition_plan_service.dart`)
- `generate-nutrition-plan-v2`
- `sync-final-surge` (placeholder; also dangerous — writes 3rd-party token into `auth.users.user_metadata` via service role)

### Dead Dart to delete alongside
- `lib/features/nutrition_plan/application/llm_nutrition_plan_service.dart`
- `lib/features/nutrition_plan/application/bulk_nutrition_plan_service.dart` (+ `.g.dart`)

`BulkNutritionPlanService` has zero callers outside its own file. `LLMNutritionPlanService` is only consumed by `BulkNutritionPlanService`. Together they were the only reason the legacy `generate-nutrition-plan` edge function appeared to have a caller.

### Mislabeled logs to fix
`nutrition_plan_service.dart:325-394` calls `generate-nutrition-plan-v3` but its log strings say "V2-REQUEST", "V2 timed out", "V2 edge function returned success=false". Rename to V3 to stop misleading debug output.

---

## Section 4 — Migration Hygiene Findings

- **`_pending/20250114_expand_category_enum_and_cleanup.sql`** appears to be a typo (should be 2026-01-14). Phase 2 of column cleanup was deferred. Status unclear — verify whether values were ever added to `category_enum`.
- **`_archive/20251030000010_sync_prod_to_dev_complete.sql`** drops 13 tables including the carb-loading subsystem. Archived; unclear if applied. If carb loading is alive (Flutter writes it), this migration was rolled back or never applied. **Document the intent.**
- **`20251206000001_*` family — 8 attempts** in a single day to convert `user_foods.id` to UUID. State of `user_foods` PK + RLS is suspect. Confirm with `\d+ user_foods` against live DB.
- **`20260506120000_create_integrations_table.sql`** consolidates three previously-archived integration migrations. Verify no dead columns remain from partial applications of the archived ones.

---

## Section 5 — Recommended Execution Order

**Phase 0 — verify (1 day):**
- Run `pg_policies` audit on all 35 tables; confirm RLS enforced
- Run `pg_indexes` audit; confirm missing/redundant indexes
- Test whether `nutrition_plans`/`auth_sessions` functions are reachable
- Confirm `feature_survey_responses` and `catalog_sync_runs` have zero recent activity

**Phase 1 — safe wins (1 week):**
- Drop legacy edge functions (#4)
- Drop `feature_survey_responses`, `catalog_sync_runs` if verified dead (#2, #3)
- Drop orphan SQL functions (`upsert_nutrition_plan_versioned`, `delete_nutrition_plan_versioned`, `update_auth_sessions_updated_at`)
- Fix `activity_status_enum` (#10)
- Fix duplicate FK declarations + unresolved `references ???` (#11)
- Add missing indexes; remove redundant ones (§2.5)
- Make `activities.status` NOT NULL after backfill

**Phase 2 — security tightening (1 week):**
- Remove tokens from `garmin_user_mappings` (#9)
- Strengthen `upload-all-data` JWT-vs-payload check
- Review `coach_messages` cascade behavior

**Phase 3 — duplicate table consolidation (2–4 weeks):**
- Decide `generate-nutrition-plan-v3` (#5)
- Merge `coach_pairing_codes` + `athlete_pairing_codes` (#8)
- Consolidate `templates` → `pre_workout_templates` (#7)
- Unify `foods` → `template_foods` (#6) — biggest lift, requires retiring v1 edge functions and gating old app versions
- Drop `users.food_preferences` JSONB after migration check

**Phase 4 — normalization (deferred):**
- Split `users` sport defaults into `user_sport_defaults` (#12)
- Extract `fuel_log_items` from `activities.fuel_log_data` (analytics-driven; do when you need it)
- Decide carb-loading roadmap — keep & invest, or retire 5 tables

---

## Appendix A — Table-Reference Cross-Reference

| Table | Flutter | Edge Fn | Dropped/Empty? |
|---|---|---|---|
| activities | ✓ | ✓ | — |
| app_config | ✓ | — | — |
| app_content | ✓ | — | — |
| athlete_pairing_codes | ✓ | — | — |
| carb_loading_day_meals | ✓ (sync) | ✓ (upload) | — |
| carb_loading_days | ✓ | ✓ | — |
| carb_loading_foods | ✓ | ✓ (sync) | — |
| carb_loading_plans | ✓ | ✓ | — |
| carb_loading_user_foods | ✓ (sync) | — | merge w/ user_foods? |
| catalog_products | — | ✓ | server-only |
| catalog_sync_runs | — | — | **DROP** |
| catalog_variants | — | ✓ | server-only |
| coach_athlete_relationships | ✓ | ✓ | — |
| coach_messages | ✓ | — | — |
| coach_pairing_codes | ✓ | — | merge w/ athlete_pairing_codes |
| coaches | ✓ | ✓ | — |
| daily_macro_targets | ✓ | — | — |
| during_workout_templates | — | ✓ (shared util) | verify reachable |
| education_content | ✓ | — | — |
| events | ✓ | ✓ | — |
| feature_survey_responses | — | — | **DROP** |
| feedback | ✓ | ✓ (upload) | — |
| food_preferences | ✓ | ✓ | — |
| food_sport_phases | — | — (via view) | verify view consumers |
| foods | ✓ (read) | ✓ | legacy → merge into template_foods |
| garmin_health_data | ✓ (read) | ✓ | — |
| garmin_user_mappings | ✓ | ✓ | strip tokens |
| integrations | ✓ | ✓ | — |
| personal_templates | ✓ | — | fix FK |
| pre_workout_templates | — | ✓ | merge w/ templates |
| public_events | — | ✓ (RPC) | — |
| template_foods | ✓ | ✓ | canonical food table |
| templates | ✓ (read) | ✓ (v2 only) | merge into pre_workout_templates |
| user_foods | ✓ | ✓ | fix duplicate FK |
| users | ✓ | ✓ | normalize sport defaults |

---

## Appendix B — Source Agent Findings

Detailed per-area write-ups available on request — this report consolidates four parallel agent analyses:
1. Schema structure (full table-by-table inventory, anomalies, enums)
2. Flutter usage (table references, Drift mapping, sync participation)
3. Edge function usage (v1/v2/v3/v4 mapping, service-role audit)
4. Migration history (145 migrations, dropped tables, churn analysis)
