# GitHub Actions Workflows

This document describes the GitHub Actions workflows in `.github/workflows/`.

> **GitHub Actions does NOT deploy the backend.** The Supabase deploy workflows
> (`deploy-dev.yml`, `deploy-prod.yml`) and the daily `schema-drift-check.yml` were
> **deleted in `b2f86b4f` (2026-05-22)** — they failed on the migration-history drift and
> deployed nothing. They are intentionally not being restored. Since then:
>
> - **Edge functions** ship manually via `scripts/deploy_dev.sh` / `scripts/deploy_prod.sh`
>   (or the `/deploy-edge` Claude skill). Merging to `develop`/`main` deploys nothing.
>   Runbook: [/docs/deployment/README.md](/docs/deployment/README.md).
> - **Schema** is applied by hand (DataGrip / CLI per `supabase/migrations/README.md`).
>
> Codemagic remains the build/deploy SSOT for the mobile apps.

## Workflows Overview

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| **Tests (self-hosted)** | `tests-selfhosted.yml` | Push, PR, manual | Full test suites on Lee's Mac mini M1 (saves Codemagic minutes); PR status checks |
| **Changelog on main** | `changelog-on-main.yml` | Push to `main` (code paths) | Generate user-facing changelog via Claude, publish to Sanity |
| **Refresh TheFeed catalog** | `refresh-feed.yml` | Mondays ~09:23 UTC, manual | Data-ops: import/deactivate/classify `catalog_products`/variants (prod, then dev) |
| **Sync Prod → Dev** | `sync-prod-to-dev.yml` | Mondays 15:00 UTC, manual | Mirror refresh-managed tables (catalog, public_events) prod → dev |

None of these deploy app code or edge functions — they are tests and data-ops only.

## Tests (Self-Hosted) Workflow (`tests-selfhosted.yml`)

**Trigger:** every push, every PR, manual dispatch. Runs on a self-hosted macOS runner
(Lee's Mac mini M1); results show as PR status checks.

**Notes:**
- Concurrency is one in-flight run per ref; newer pushes cancel older ones (single runner).
- Patrol integration tests run against the iOS simulator (`PATROL_DEVICE`), with an
  `EXPECTED_PATROL_TESTS` assertion so a silently dropped target fails the run.
- Codemagic's `pr-validation` remains the merge test gate; this workflow supplements it
  on owned hardware.

## Changelog on Main (`changelog-on-main.yml`)

**Trigger:** push to `main`, ignoring docs/markdown-only changes.

Generates a user-facing changelog entry from the merged commits (via Claude) and publishes
it to Sanity, which the marketing site renders.
See [/docs/deployment/changelog-automation.md](/docs/deployment/changelog-automation.md).

## Refresh TheFeed Catalog (`refresh-feed.yml`)

**Trigger:** Mondays ~09:23 UTC, or manual dispatch (target: prod / dev / both).

Deterministic data-ops job (not build/test CI): non-destructive importer, removed-product
deactivation, and classify-new SQL against `catalog_products`/`catalog_variants`.

## Sync Prod → Dev (`sync-prod-to-dev.yml`)

**Trigger:** Mondays 15:00 UTC (after the prod refreshes), or manual dispatch.

Mirrors refresh-managed tables (`catalog_products`, `public_events`) from prod to dev.

## Required GitHub Secrets

Set in Settings → Secrets and variables → Actions. The exact list is defined by the
workflow files themselves (grep `secrets.` in `.github/workflows/`); highlights:

- `DEV_SUPABASE_SERVICE_ROLE_KEY` / `PROD_SUPABASE_SERVICE_ROLE_KEY` — data-ops workflows
- Sanity + Anthropic credentials — changelog workflow

> Note: the repo moved to the `milkmanfunddev-ops` org on 2026-07-23, which wiped all
> Actions secrets — if a workflow suddenly 401s, re-check the secrets exist.

## Backend Deployment (what replaced the deleted workflows)

Manual, human-run, process of record:

```bash
# Edge functions
./scripts/deploy_dev.sh <fn> [<fn> ...]      # dev (ref pinned from .env.dev.local)
./scripts/deploy_prod.sh <fn> [<fn> ...]     # prod (interactive 'yes' confirmation)
```

Or the `/deploy-edge` Claude skill (same deploy plus schema/secret/cross-import pre-checks
and post-deploy verification). Full runbook, including the `_shared/` redeploy rule and how
to audit deployed vs repo code: [/docs/deployment/README.md](/docs/deployment/README.md).

## Monitoring & Troubleshooting

- Check the Actions tab for run logs; common failures are missing secrets (see the org-move
  note above) or the self-hosted runner being offline / low on disk.
- Mobile build failures are a Codemagic concern, not GitHub Actions — see
  [Codemagic Procedures](./codemagic-procedures.md).

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli)
