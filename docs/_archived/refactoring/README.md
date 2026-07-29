# Refactoring Documentation Hub
*Updated: 2025-11-16*

This directory tracks the long-running schema, sync, and client cleanup that bridges the Supabase Phase 0 migrations with the Flutter refactor. Use this README as the entry point and rely on the linked documents for tactical detail.

## How the Folder Is Organized
- **[ROADMAPS.md](ROADMAPS.md)** – Source of truth for what has shipped and what is still in flight. Start here for daily planning.
- **Topic Briefs** – Deep dives that explain why a change happened (`CALENDAR-SYNC-RETIREMENT.md`, `EVENT_TYPE_ARCHITECTURE.md`, `PRODUCTION-SCHEMA-FIX.md`, `activity-owned-nutrition-plan-roadmap.md`).
- **Phase Logs** – Historical snapshots that remain relevant for archaeology (`phase0/overview.md`, `phase0/database_status.md`, etc.).
- **Archive** – Older write-ups that are kept only for historical reference now live under [`archive/`](archive/). Browse there if you need the original Phase 0 client log or completion report.

## How to Use the Docs
1. **Check the snapshot** in `ROADMAPS.md` before you start; the table calls out current analyzer errors, blockers, and owners.
2. **Open the linked brief** for the area you are touching so you understand the context and guardrails.
3. **Update ROADMAPS.md** (and any relevant brief) before submitting a PR. Keep the completed/remaining sections in sync.

## Quick Links
- Phase 0 history: [`phase0/overview.md`](phase0/overview.md), [`phase0/database_status.md`](phase0/database_status.md)
- Nutrition ownership plan: [`activity-owned-nutrition-plan-roadmap.md`](activity-owned-nutrition-plan-roadmap.md)
- Calendar sync removal: [`CALENDAR-SYNC-RETIREMENT.md`](CALENDAR-SYNC-RETIREMENT.md)
- Event type unification: [`EVENT_TYPE_ARCHITECTURE.md`](EVENT_TYPE_ARCHITECTURE.md)
