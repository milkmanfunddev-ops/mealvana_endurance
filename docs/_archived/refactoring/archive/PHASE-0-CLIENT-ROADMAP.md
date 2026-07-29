# Phase 0 Client Refactor – Roadmap Index
*Updated: 2025-11-09*

The original roadmap ballooned past 2,000 lines, so it has been split into focused documents. Start with the overview and drill into the area you are working on.

## Current Snapshot
- Phase 1 (Drift definitions) is **partially** complete: the int primary keys landed and nutrition plans now live on `activities`, but several tables still expose `device_id` and array columns are not persisted.
- Phase 2 (domain models) and Phase 3 (application layer) have not started. `NutritionPlanRepository`/`NutritionPlanController` are still wired everywhere.
- The sync stack now serializes nutrition plans via `activities`, but other deprecated tables (product types, user-hidden foods) still leak into payloads, so Supabase prod/dev cannot be updated until those calls change.

## Documents
1. [`phase0/overview.md`](phase0/overview.md) – goals, prerequisites, and a status table.
2. [`phase0/database_status.md`](phase0/database_status.md) – source-of-truth for Drift/schema tasks.
3. [`phase0/client_backlog.md`](phase0/client_backlog.md) – actionable backlog for Phases 2 and 3.
4. [`COMPLETE-MIGRATION-ROADMAP.md`](COMPLETE-MIGRATION-ROADMAP.md) – cross-phase plan (schema + nutrition simplification).

## How to Contribute
1. Read the overview to understand why the work matters.
2. If you are touching the database layer, update `database_status.md` as you land changes.
3. If you are fixing app logic, update `client_backlog.md` (add links to PRs, strike completed tasks, etc.).
4. Keep the Complete Migration Roadmap in sync so leadership can see what is left before releasing Phase 0.
