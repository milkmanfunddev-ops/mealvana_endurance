# New Sync Architecture

This folder contains all documentation for the sync architecture refactor.

## Documents

| Document | Purpose |
|----------|---------|
| [roadmap.md](./roadmap.md) | Complete technical roadmap with architecture design |
| [checklist.md](./checklist.md) | Implementation checklist with task assignments |
| [notes.md](./notes.md) | Working notes, decisions, and discoveries |

## Quick Links

- **Current Phase**: Phase 1 - Foundation
- **Branch**: `new_sync`
- **Tests Location**: `/test/new_sync/`

## Agent Workflow

Each code executor agent should:
1. Read this README to understand the project
2. Check `checklist.md` for the next unclaimed task
3. Claim the task by adding their agent ID
4. Implement the task
5. Write tests in `/test/new_sync/`
6. Update `checklist.md` to mark complete
7. Update `notes.md` with any findings
8. Commit changes with descriptive message
9. Move to next task

## Key Files

```
lib/shared/
├── data/
│   └── syncable_repository.dart       # Base class for all syncable repos
├── services/
│   ├── version_check_service.dart     # Version checking at startup
│   ├── dirty_record_backup_service.dart  # Backup/recovery
│   └── sync/
│       └── sync_coordinator.dart      # Dependency resolution
└── models/
    ├── sync_result.dart               # Sync operation results
    └── version_check_result.dart      # Version check results
```
