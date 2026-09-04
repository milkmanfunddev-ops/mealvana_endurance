# 06 — Sync, schema versions, environments (Phase 5)

## Status — **dev side done 2026-09-02; the prod apply is prepared but NOT run**
| Item | State |
|---|---|
| Sync registration (§1.1–1.4) | **done** in Phase 4b (`c494a817`) — graph, `_repositoryFor`, the `_syncableRepositoryKeys` roster, and the pre-logout `Future.wait` with every `UploadResult` checked. |
| `user_entitlements` in the sync graph (§1.1/1.2) | **deliberately not done.** `UserEntitlementsRepository` is not a `SyncableRepository`: the row is written only by the RevenueCat webhook under `service_role`, RLS is owner-select, and the Drift table is a read-only cache. It has no `needs_upload` column and no upload path, so registering it would put a key in the dirty-upload roster that can never resolve. The repository's own doc comment says this. |
| On-demand `ensureSynced` (§1.3) | **done** — `MealPlanController` and `VanaSettingsController` each kick `ensureSynced` on build (`meal_plans` / `user_memories`); the Plan tab's `RefreshIndicator` calls `refresh()`. Nothing syncs from startup. |
| Cascade check (§1.5) | **verified on dev 2026-09-02**: 6 cascading FKs across `meal_plans`, `user_memories`, `user_entitlements`, `meal_feedback`. |
| Drift version | shipped as **v20**, not 19 (05 §2). Dev `app_config.current_schema_version` / `latest_schema_version` **bumped 18 → 20 on 2026-09-02**; the floor stays 4, so 1.23.x dev builds on Drift 18 sit inside the compatibility window and do **not** resync. |
| Prod DDL + seed | **prepared, not run** — `supabase/migrations/cutover/meal_planning/` (README + `01_pre_check.sql` + `90_verify.sql` + `95_app_config_schema_20.sql`), derived from a live read of both projects on 2026-09-02. Prod `app_config` is Xuan's call. |
| CI env flags (§"Environments / CI") | **already in `codemagic.yaml`** from Phase 3: dev builds force `PRO_GATE_ENABLED=false`; prod builds hard-fail unless the prod secret states it as exactly `true`/`false`. `.env.example` carries `PRO_GATE_ENABLED` and `PRO_PURCHASE_ENABLED`. |

### What the live read changed about the plan below
- **prod has no `pgvector`.** §1's pre-check assumed it did. The first migration
  (`20260827090000`) runs `create extension if not exists vector`, so the apply must go through
  `supabase db push` (owner role), not the SQL editor. `pg_trgm` **is** installed.
- **The enums match** (`dietary_preference_enum` 8 labels, `allergy_enum` 9) — §1's other pre-check passes.
- **Prod's ledger head is `20260811160003`**, so the push also carries the two 2026-08-14 macro-dashboard
  migrations. `plan_recalc_log` already exists on prod but is absent from the ledger (applied by hand), and
  `activities` has `deleted_at` but not `planned_time`/`actual_time`. Both files are idempotent; both are
  needed by 1.24 regardless of meal planning. This was not in the plan — say so on the cut card.
- **`plan_days` is not a table.** `20260827130000` adds `meal_plans.days jsonb` plus a partial
  unique index that `20260831150000` later replaces with `meal_plans_confirmed_week` (one
  confirmed plan per athlete-week; drafts are per-conversation). The verification SQL checks the
  column and the surviving index, not a table.
- **The seed re-embeds.** `meal-library.snapshot.json` carries every column except `embedding` and
  `search_text`, so prod pays ≈1,922 embedding calls (~$0.05); `90_verify.sql` asserts
  `library_embedded = library_rows` because a half-embedded library still answers `search_meals`, badly.

## Sync registration (both, or it silently no-ops)
1. `lib/shared/services/sync/sync_dependency_graph.dart`: add `'meal_plans': ['users', 'saved_meals',
   'meal_logs']`, `'user_memories': ['users']`, `'user_entitlements': ['users']`.
2. `lib/shared/services/sync/sync_coordinator.dart` `_repositoryFor`: `case 'meal_plans'`, `case
   'user_memories'`, `case 'user_entitlements'` → the providers.
3. On-demand: `ensureSynced('meal_plans', userId, repository: repo)` when the Food tab first shows and
   on pull-to-refresh; never from startup.
4. `settings_controller.signOut()`: add `mealPlanRepo`, `userMemoryRepo` to the pre-logout
   `Future.wait` upload list; check every `UploadResult`.
5. `delete-user` relies on `ON DELETE CASCADE` — all new tables FK `users(id) on delete cascade` ✅
   (`meal_feedback`, `plan_meals`, `meal_plans`, `user_memories`, `vana_*`, `user_entitlements`).

## Schema versions
- Drift 18 → **19** (05 §2). `app_config`: dev `current_schema_version=19`, then prod after the prod
  DDL is in. `min_supported_schema_version` stays (11 on prod). No force-update for this release —
  additive only.

## Prod DDL + data (cutover-style runbook, `supabase/migrations/cutover/meal_planning/`)
Prod (`wvmvsodrvbkxfydabqed`) has none of the meal-planning objects and still has real `jade_*` tables.
1. Pre-check: `pgvector` + `pg_trgm` enabled on prod; `dietary_preference_enum` / `allergy_enum` values
   match dev (`meal_library.diets_ok/allergens` use them).
2. Apply migrations **in order**: `20260827090000` → `20260827120000` (renames `jade_*` → `vana_*`,
   creates compat views — the 1.23.x app keeps working through the views) → `20260827130000` →
   `20260828090000` → `20260831090000` → `20260831150000` → `20260901090000` → `20260901120000` →
   `20260901160000` → the Phase 2 RPC migration → the Phase 3 `user_entitlements` migration. Use
   `supabase db push` (idempotent files) or `db query --linked` per file; record in `apply_all.sql`.
3. Seed `meal_library` on prod: `cd mealplanning-prototype/packages/web && node scripts/seed_meal_library.mjs
   --env <prod env file>` (≈1,922 embedding calls via AI Gateway, ~$0.05) → `refresh_meal_library_pairs()`.
   Then the directions/images are already in the JSON? — **no**: `method_steps`, `directions_*`,
   `image_*` were written to dev by the apply scripts from `data/direction-results` + `source-scrape.json`
   + `meal-images.json`. Either re-run `apply_agent_directions`, `apply_source_scrape`, `find_meal_images`
   against prod, or (simpler, recommended) add `scripts/export_meal_library.mjs` that dumps dev's
   `meal_library` to `data/meal-library.snapshot.json` and let the seed script load the snapshot. Do this
   in Phase 1 so prod seeding is one command.
4. Deploy `vana-chat`, `vana-action`, `vana-day-notes`, updated `revenuecat-webhook`, `jade-chat`
   alias to prod (`/deploy-edge`). Secrets: `PRO_GATE_ENABLED`, `VANA_*_MODEL` (optional).
5. Verify: RPC smoke (`search_meals` for the QA user excludes allergens), `vana_calls` writes,
   `jade_conversations` view still serves the shipped app.
6. Regenerate `docs/dev_schema.txt` / `docs/prod_schema.txt` from the live catalogs (DataGrip workflow
   per memory) and commit `[skip ci]`.

## Environments / CI
- `codemagic.yaml`: dev builds force `PRO_GATE_ENABLED=false`; prod builds require it present.
- `.env.example` + `secrets/` docs updated; nothing new client-side beyond the flag.
- `sim-dev-login.sh` unchanged; add the QA user to `internal_users` on dev for the fn gate.
