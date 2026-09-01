# Complete Migration Roadmap – Schema + Nutrition Simplification
*Updated: 2025-11-16*

This document now plays a supporting role to the living status in [`ROADMAPS.md`](ROADMAPS.md). It explains *why* each phase exists, what “done” means, and how the open items map to the architecture. For the up-to-date burndown snapshot (currently **552 analyzer errors**), use the roadmap hub.

## Executive Summary
- **Problem:** Supabase + Drift migrations embedded nutrition and macro data on activities, but parts of the Flutter app—and a few edge functions—still behave like the legacy tables exist (string IDs, device-centric ownership, detached controllers).
- **Target State:** Activities are the single source of truth for plans/macros/notes, repositories only speak in int/UUID IDs, and batch sync transmits a minimal, well-documented payload.
- **Reality (Nov 2025):** Schema/storage work is complete, calendar sync has been retired, and the remaining effort is clustered around Activity-owned nutrition flows, sync contracts, and tests. See `ROADMAPS.md` for the day-to-day checklist.

## Status Snapshot
| Phase | Scope | Status | Notes |
| --- | --- | --- | --- |
| Phase 0 – Schema simplification (Supabase + Drift) | Drop join tables, move to UUID/int ids, add array columns | ✅ Complete | Supabase follow-ups dropped `nutrition_plans`; Drift mirrors the schema. Historical details live under `docs/refactoring/phase0`. |
| Phase 1 – Embed & simplify nutrition | Delete NutritionPlan repo/controller, store macros on activities | ⚠️ Partial | Migrations [`20251109000000`](../../supabase/migrations/20251109000000_embed_nutrition_plan_on_activities.sql) + [`20251111000003`](../../supabase/migrations/20251111000003_embed_macros_and_notes_on_activities.sql) embedded plan/macro/note data. Flutter still routes through legacy controllers; see Roadmap B (Activity-Owned Nutrition). |
| Phase 2 – Batch sync architecture | Single sync-all edge function + dirty uploads | ⚠️ Partial | `DataSyncService` no longer references `nutrition_plans`, but payloads still include deprecated keys + device IDs. Align with Roadmap B (Sync & Edge Contracts). |
| Phase 3 – Client refactor | UI, services, and tests updated for new schema | 🚧 In progress | Analyzer currently reports 552 errors (IDs, deleted tables, orphaned providers). See `PHASE-3-ROADMAP.md` for bucket detail. |

## Reality Check (Codebase Audit)
- `NutritionPlanRepository` and `NutritionPlanController` still drive the UI even though activities now own the plan JSON, so state is duplicated and hard to reconcile.
- `DataSyncService` no longer uploads `nutrition_plans`, but the rest of the batch-sync architecture is untouched.
- Food preference call sites still pass `deviceId`; repositories/UI have not switched to UUID inputs.
- Domain models (`Activity`, `Event`, carb loading models) still use `String` ids, blocking the int migration.

## Outstanding Work by Phase

### Phase 0 – Schema Alignment
✅ Done in code and Supabase (see `docs/refactoring/phase0/database_status.md`). Remaining work now lives in Phases 2/3.

### Phase 1 – Nutrition Simplification
1. ✅ Embed nutrition plans + macro targets + workout notes directly on `activities` (Supabase migrations `20251109000000` + `20251111000003`).
2. ⚠️ Remove `NutritionPlanController`/`NutritionPlanRepository` and teach the UI to load/write nutrition JSON through `ActivitiesRepository`.
3. ⚠️ Convert macro adjustment + feedback flows to edit the activity payload only (no detached cache tables).

### Phase 2 – Batch Sync
1. Update `DataSyncService` to download/upload only supported tables (activities, foods, carb loading data) and to send UUID `userId` values instead of `device_id`.
2. Tighten the edge-function contracts and document them in `docs/api_documentation.txt`.
3. Add automated tests that fail whenever a deprecated table sneaks into the payload.

### Phase 3 – Client Refactor & Analyzer Burndown
See `docs/refactoring/PHASE-3-ROADMAP.md` for the active burndown plan. High-level buckets:
1. **ID Alignment:** Finish migrating domain models/repositories/controllers to `int` IDs (removes ~60% of analyzer errors).
2. **Deleted Tables:** Rip out remaining references to `macro_targets_table`, `workout_notes`, `product_types`, `meal_types`, etc. Any helper that called Drift tables must now read the activity JSON.
3. **Nutrition Controller Removal:** Replace `NutritionPlanController` state with per-activity data; delete globals.
4. **Tests & Sync:** Update fixtures/tests to new schemas, ensure `DataSyncService` no longer uploads removed tables, and backfill missing contract docs.

## Risks & Mitigations
- **Schema Drift:** Continue using the new `docs/refactoring/phase0/database_status.md` checklist and require PR reviewers to update it.
- **Hidden Dependencies:** Search for `nutrition_plans`, `product_types`, and `device_id` references before removing tables.
- **Release Timing:** Prod migrations must wait until the client ships with the new schema handling; capture the rollout checklist in `docs/database/phase0_release_plan.md` (to be created).

## References
- [Phase 0 Overview](phase0/overview.md)
- [Phase 0 Database Status](phase0/database_status.md)
- [Phase 0 Client Backlog](phase0/client_backlog.md)
- [Phase 3 Roadmap (Analyzer Burndown)](PHASE-3-ROADMAP.md)
- Supabase SQL: `docs/database/migrations/phase0_schema_refresh.sql`, `docs/database/migrations/phase0_followups.sql`
