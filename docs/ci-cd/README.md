# CI/CD Documentation

This directory contains comprehensive documentation for Mealvana Endurance's continuous integration and deployment pipelines.

## Architecture Overview

Mealvana Endurance uses a **dual CI/CD strategy**:

| Platform | Purpose | Triggers |
|----------|---------|----------|
| **Codemagic** | Mobile app builds, integration tests, App Store/Play Store deployment | Push/PR to branches |
| **GitHub Actions** | Test suites (self-hosted runner), changelog publishing, data-ops (catalog refresh, prod→dev sync) | Push/PR, scheduled |

> **Backend deployment is NOT in CI.** The Supabase deploy workflows (`deploy-dev.yml`,
> `deploy-prod.yml`, `schema-drift-check.yml`) were deleted in `b2f86b4f` (2026-05-22) and are
> not coming back. Edge functions ship manually via `scripts/deploy_dev.sh` /
> `scripts/deploy_prod.sh` (or the `/deploy-edge` Claude skill); schema is applied by hand.
> See [/docs/deployment/README.md](/docs/deployment/README.md).

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Git Repository                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────────────┐              ┌─────────────────────┐       │
│  │    Pull Request     │              │    Push to Branch   │       │
│  └──────────┬──────────┘              └──────────┬──────────┘       │
│             │                                    │                   │
│             ▼                                    ▼                   │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                    CODEMAGIC                                 │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │  • PR Validation (analyze, format, unit tests)              │    │
│  │  • Integration Tests (iOS simulator)                        │    │
│  │  • iOS Build → TestFlight                                   │    │
│  │  • Android Build → Play Store                               │    │
│  │  • Shorebird OTA Updates                                    │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                   GITHUB ACTIONS                             │    │
│  ├─────────────────────────────────────────────────────────────┤    │
│  │  • Test suites on self-hosted runner (PR status checks)     │    │
│  │  • Changelog generation on main (→ Sanity)                  │    │
│  │  • TheFeed catalog refresh (scheduled data-ops)             │    │
│  │  • Prod → Dev table sync (scheduled data-ops)               │    │
│  │  (NO Supabase deploys — those are manual, see below)        │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Navigation

| Document | Description |
|----------|-------------|
| **[Codemagic Procedures](./codemagic-procedures.md)** | **Day-to-day ops: which branch ships where, when to bump versions, API commands, troubleshooting** |
| [Codemagic Setup](./codemagic-setup.md) | First-time setup reference (some sections predate the 2026-04 rewrite — see Procedures for current) |
| [GitHub Actions](./github-actions.md) | Backend CI/CD workflows |
| [Secrets & Environments](./secrets-and-environments.md) | Complete secrets reference |
| [Shorebird Integration](./shorebird-integration.md) | OTA code push setup |
| [Troubleshooting](./troubleshooting.md) | Common issues and fixes |

## Branch Strategy

```
main (production)
  │
  ├── release/v1.x (release candidates)
  │     │
  │     └── feature/* (new features)
  │
  └── develop (integration)
        │
        └── feature/* (new features)
```

**Deployment Rules:**
- `develop` → Codemagic dev-iOS build (TestFlight). Supabase is NOT auto-deployed —
  edge-function changes ship only via a manual `scripts/deploy_dev.sh` run.
- `release/*` → Codemagic prod iOS/Android builds
- `main` → changelog workflow; prod Supabase deploys are manual (`scripts/deploy_prod.sh`)

## Key Files

| File | Purpose |
|------|---------|
| `/codemagic.yaml` | Codemagic workflow definitions |
| `/.github/workflows/tests-selfhosted.yml` | Test suites on self-hosted runner |
| `/.github/workflows/changelog-on-main.yml` | Changelog generation on main |
| `/.github/workflows/refresh-feed.yml` | TheFeed catalog refresh (data-ops) |
| `/.github/workflows/sync-prod-to-dev.yml` | Prod → dev table sync (data-ops) |
| `/scripts/deploy_dev.sh`, `/scripts/deploy_prod.sh` | Manual edge-function deploys (process of record) |
| `/shorebird.yaml` | Shorebird OTA configuration |

## Current Status

### Codemagic Configuration Issue (Action Required)

There is currently a **configuration conflict** between:
- **Workflow Editor**: Configured for Shorebird Release builds
- **codemagic.yaml**: Standard Flutter builds without Shorebird commands

See [Troubleshooting](./troubleshooting.md#configuration-conflict) for resolution steps.

## Environment Variable Groups

### Required in Codemagic

| Group | Variables | Used By |
|-------|-----------|---------|
| `supabase_dev` | `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Integration tests |
| `supabase_prod` | `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Production builds |
| `shorebird_credentials` | `SHOREBIRD_TOKEN` | OTA updates |
| `app_store_credentials` | App Store Connect API | iOS builds |
| `google_play_credentials` | `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` | Android builds |

### Required in GitHub Actions

The authoritative list is whatever the workflow files reference (`grep secrets.
.github/workflows/`). Highlights:

| Secret | Purpose |
|--------|---------|
| `DEV_SUPABASE_SERVICE_ROLE_KEY` | Data-ops workflows (catalog refresh, prod→dev sync) |
| `PROD_SUPABASE_SERVICE_ROLE_KEY` | Data-ops workflows |
| Sanity / Anthropic credentials | Changelog workflow |

(The old deploy-workflow secrets — `DEV_PROJECT_ID`, `*_DB_PASSWORD`,
`SUPABASE_ACCESS_TOKEN` — are no longer used by CI; manual deploys authenticate with
`~/.supabase/pat` locally.)

## Testing Strategy

**160+ automated tests** run on every deployment:
- **11+ Flutter unit tests** - Core business logic
- **150+ Edge function tests** - Backend validation
- **Integration tests** - End-to-end flows on iOS simulator

See [/docs/test/README.md](/docs/test/README.md) for complete testing documentation.
