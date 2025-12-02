# CI/CD Documentation

This directory contains comprehensive documentation for Mealvana Endurance's continuous integration and deployment pipelines.

## Architecture Overview

Mealvana Endurance uses a **dual CI/CD strategy**:

| Platform | Purpose | Triggers |
|----------|---------|----------|
| **Codemagic** | Mobile app builds, integration tests, App Store/Play Store deployment | Push/PR to branches |
| **GitHub Actions** | Backend deployment (Supabase), schema monitoring, code reviews | Push/PR, scheduled |

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
│  │  • Flutter + Edge Function Tests                            │    │
│  │  • Supabase Dev Deployment (auto on develop)                │    │
│  │  • Supabase Prod Deployment (manual approval)               │    │
│  │  • Daily Schema Drift Detection                             │    │
│  │  • CodeRabbit AI Code Reviews                               │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Navigation

| Document | Description |
|----------|-------------|
| [Codemagic Setup](./codemagic-setup.md) | Mobile CI/CD configuration |
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
- `develop` → Auto-deploy to dev Supabase
- `release/*` → Trigger iOS/Android builds
- `main` → Production deployment (manual approval required)

## Key Files

| File | Purpose |
|------|---------|
| `/codemagic.yaml` | Codemagic workflow definitions |
| `/.github/workflows/test.yml` | Test automation |
| `/.github/workflows/deploy-dev.yml` | Dev environment deployment |
| `/.github/workflows/deploy-prod.yml` | Production deployment |
| `/.github/workflows/schema-drift-check.yml` | Daily schema monitoring |
| `/.github/workflows/coderabbit.yml` | AI code review |
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

| Secret | Purpose |
|--------|---------|
| `DEV_PROJECT_ID` | Dev Supabase project |
| `DEV_DB_PASSWORD` | Dev database access |
| `PROD_PROJECT_ID` | Production Supabase project |
| `PROD_DB_PASSWORD` | Production database access |
| `SUPABASE_ACCESS_TOKEN` | Supabase CLI authentication |

## Testing Strategy

**160+ automated tests** run on every deployment:
- **11+ Flutter unit tests** - Core business logic
- **150+ Edge function tests** - Backend validation
- **Integration tests** - End-to-end flows on iOS simulator

See [/docs/test/README.md](/docs/test/README.md) for complete testing documentation.
