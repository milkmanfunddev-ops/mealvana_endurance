# Archived CLAUDE Section Mapping

This maps sections from `/docs/_archived/claude.md` to current docs and marks status as `migrated` or `deprecated`.

## Section-Level Mapping

| Archived Section | Current Location | Status |
|---|---|---|
| Purposes | `CLAUDE.md` (Purpose) | migrated |
| How To Use This File | `CLAUDE.md` (usage + docs map) | migrated |
| Project Overview / Purpose / Key Features / Tech Stack | `CLAUDE.md` (Project Snapshot) + `/docs/architecture/README.md` | migrated |
| Architecture | `/docs/architecture/README.md` | migrated |
| Feature-Oriented Architecture (FOA) | `/docs/technical/foa-architecture.md` + `CLAUDE.md` rules | migrated |
| App Initialization Pattern (Andrea Bizzotto) | `/docs/technical/andrea/andrea_initialization.txt` + `CLAUDE.md` explicit init section | migrated |
| Fat Backend Architecture | `/docs/technical/content-management.md` | migrated |
| Agents Available | `CLAUDE.md` (Available Agents) | migrated |
| Project Structure | `CLAUDE.md` (Project Structure high level) + `/docs/architecture/README.md` | migrated |
| Core Systems / Nutrition Algorithm | `/docs/business_logic/README.md` | migrated |
| Core Systems / Content Management System | `/docs/technical/content-management.md` | migrated |
| Data Storage | `/docs/database/README.md` | migrated |
| Data Synchronization Architecture | `/docs/technical/sync-architecture.md` | migrated |
| Development Practices / Code Generation | `/docs/technical/README.md` + `CLAUDE.md` rules | migrated |
| Development Practices / UI Feedback Components | `CLAUDE.md` non-negotiable + UI docs under `/lib/shared/widgets/kyle_design/feedback/` | migrated |
| Development Practices / Riverpod Patterns | `/docs/technical/foa-architecture.md` | migrated |
| Build & Deployment | `/docs/deployment/README.md` | migrated |
| Analytics & Monitoring | `/docs/technical/sentry-integration.md` | migrated |
| Documentation Index | Replaced by `CLAUDE.md` Docs Map + per-domain README files | migrated |
| Web Deployment Documentation | `/docs/web_mode/README.md` + `/docs/deployment/README.md` | migrated |
| Feature Documentation | Per-feature docs in `/docs/features/` and domain docs | migrated |
| Project Management | Domain-specific docs in `/docs/database/`, `/docs/features/`, `/docs/roadmap/` | migrated |
| Important Notes for AI Assistants | `CLAUDE.md` non-negotiable rules | migrated |
| Key Design Decisions | Distributed into `CLAUDE.md` and `/docs/technical/README.md` | migrated |
| Common Tasks | Distributed into per-domain README runbooks | migrated |
| Testing Strategy | `/docs/test/README.md` | migrated |
| Contact & Resources | Deprecated as central assistant context section | deprecated |
| External Resources | Deprecated in centralized CLAUDE; use specific docs when needed | deprecated |
| Project Specific (metadata footer) | Deprecated; replaced by repo-truth docs and code references | deprecated |

## Notes
- Mapping is intentionally section-level (not paragraph-level).
- Any legacy references to removed/renamed edge functions are treated as historical unless present in current app invocation paths.
