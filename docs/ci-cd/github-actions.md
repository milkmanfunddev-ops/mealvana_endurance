# GitHub Actions Workflows

This document describes the GitHub Actions workflows used for backend deployment and testing.

## Workflows Overview

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| **Test** | `test.yml` | PR, push, daily | Run all tests |
| **Deploy Dev** | `deploy-dev.yml` | Push to `develop` | Auto-deploy to dev Supabase |
| **Deploy Prod** | `deploy-prod.yml` | Push to `main` | Production deployment (manual approval) |
| **Schema Drift Check** | `schema-drift-check.yml` | Daily 9 AM UTC | Detect database drift |
| **CodeRabbit** | `coderabbit.yml` | Pull requests | AI code review |

## Test Workflow (`test.yml`)

**Trigger:** PRs to develop/main, push to develop/main, daily at 10 AM UTC

**Jobs:**

### 1. Flutter Tests
```yaml
- Checkout code
- Setup Flutter (stable)
- Run code generation (build_runner)
- Run unit tests with coverage
- Upload coverage to Codecov
```

### 2. Edge Function Tests
```yaml
- Checkout code
- Setup Node.js 20
- Setup Deno
- Install dependencies
- Run Vitest tests (150+ tests)
```

### 3. Edge Integration Tests (Manual/Scheduled)
```yaml
- Only runs manually or on schedule
- Uses real dev Supabase instance
- Validates edge function integration
```

### 4. Test Summary
```yaml
- Aggregates results from all jobs
- Creates unified test report
```

**Required Secrets:**
- `DEV_SUPABASE_URL` - Dev environment URL
- `DEV_ANON_KEY` - Dev anonymous key
- `CODECOV_TOKEN` - Coverage reporting (optional)

## Deploy Dev Workflow (`deploy-dev.yml`)

**Trigger:** Push to `develop` branch, manual dispatch

**Steps:**

```yaml
1. Run Tests (Flutter + Edge functions)
2. Link to dev Supabase project
3. Deploy database migrations
4. Deploy Edge Functions
```

**Required Secrets:**
- `DEV_PROJECT_ID` - Supabase project ID
- `DEV_DB_PASSWORD` - Database password
- `SUPABASE_ACCESS_TOKEN` - CLI authentication

## Deploy Prod Workflow (`deploy-prod.yml`)

**Trigger:** Push to `main` branch, manual dispatch

**REQUIRES MANUAL APPROVAL** via GitHub Environments

**Steps:**

```yaml
1. Run Tests (Flutter + Edge functions)
2. Wait for manual approval
3. Link to production Supabase project
4. Safety check - review schema diff
5. Deploy database migrations
6. Deploy Edge Functions
7. Verify deployment
8. Post-deployment monitoring checklist
```

**Required Secrets:**
- `PROD_PROJECT_ID` - Production Supabase project ID
- `PROD_DB_PASSWORD` - Production database password
- `SUPABASE_ACCESS_TOKEN` - CLI authentication

**Safety Features:**
- Manual approval gate prevents accidental deployments
- Schema diff review before applying migrations
- Post-deployment verification step
- Monitoring checklist output

## Schema Drift Check (`schema-drift-check.yml`)

**Trigger:** Daily at 9 AM UTC, manual dispatch

**Purpose:** Detect when cloud database schema differs from local migrations

**Steps:**

```yaml
1. Check dev environment for drift
2. Check production environment for drift
3. If drift detected:
   - Create GitHub issue with details
   - Upload drift report as artifact
   - Provide remediation instructions
```

**Required Secrets:**
- `DEV_PROJECT_ID`, `DEV_DB_PASSWORD`
- `PROD_PROJECT_ID`, `PROD_DB_PASSWORD`
- `SUPABASE_ACCESS_TOKEN`

**Example Issue Created:**
```markdown
## Schema Drift Detected

**Environment:** production
**Date:** 2025-12-02

### Drift Details
[diff output]

### Remediation
Run: supabase db pull
Compare with: database_schemas/v1/schema.sql
```

## CodeRabbit (`coderabbit.yml`)

**Trigger:** Pull requests (opened, synchronized, reopened)

**Purpose:** AI-powered code review with FOA architecture awareness

**Configuration:** `.coderabbit.yaml`

**Custom Instructions:**
- Enforce Andrea Bizzotto's FOA patterns
- Check for UI/Controller separation
- Validate Riverpod patterns
- Review content service usage

## Setting Up GitHub Environments

### Production Environment

1. Go to Repository Settings → Environments
2. Click "New environment"
3. Name: `production`
4. Enable "Required reviewers"
5. Add team members who can approve production deploys
6. Add environment secrets:
   - `PROD_PROJECT_ID`
   - `PROD_DB_PASSWORD`

### Development Environment

1. Create environment: `development`
2. No approval required (auto-deploy)
3. Add secrets:
   - `DEV_PROJECT_ID`
   - `DEV_DB_PASSWORD`

## Required GitHub Secrets

### Repository Secrets

```
SUPABASE_ACCESS_TOKEN    # supabase login → copies token
DEV_PROJECT_ID           # From Supabase dashboard
DEV_DB_PASSWORD          # From Supabase dashboard
DEV_SUPABASE_URL         # https://xxx.supabase.co
DEV_ANON_KEY             # From Supabase dashboard
PROD_PROJECT_ID          # Production Supabase project
PROD_DB_PASSWORD         # Production database password
```

### Generating Supabase Access Token

```bash
supabase login
# Copies token to clipboard
# Paste into GitHub secret: SUPABASE_ACCESS_TOKEN
```

## Workflow Dependencies

```
┌─────────────────┐
│   test.yml      │◄─── Runs on every PR
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ deploy-dev.yml  │◄─── Auto on develop push
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ deploy-prod.yml │◄─── Manual approval on main
└─────────────────┘

┌──────────────────────┐
│ schema-drift-check   │◄─── Daily scheduled
└──────────────────────┘
```

## Monitoring & Alerts

**GitHub Actions Notifications:**
- Enable in repository Settings → Notifications
- Or use Slack integration via GitHub app

**Failed Workflow Actions:**
1. Check Actions tab for error logs
2. Review specific job that failed
3. Common issues:
   - Missing secrets
   - Database connection timeout
   - Edge function syntax errors

## Troubleshooting

### Tests Pass Locally but Fail in CI

```bash
# Ensure you're using same versions
flutter --version
node --version
deno --version
```

### Supabase Deploy Fails

```bash
# Verify CLI is authenticated
supabase projects list

# Check project linking
supabase link --project-ref $PROJECT_ID
```

### Schema Drift Alert

```bash
# Pull current remote schema
supabase db pull

# Compare with local
diff database_schemas/v1/schema.sql supabase/migrations/

# Generate migration if needed
supabase db diff --schema public
```

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Supabase CLI Reference](https://supabase.com/docs/reference/cli)
- [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments)
