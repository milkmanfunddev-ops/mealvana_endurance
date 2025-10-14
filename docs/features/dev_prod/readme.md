# Dev/Prod Environment Setup Guide

## Overview

Complete guide for setting up development and production environments for Mealvana Endurance with unified database schemas, automated deployments, and comprehensive testing.

## Current State

- **Supabase**: 2 projects (Dev: vlmtsdzpnjnavdgytcmi, Prod: wvmvsodrvbkxfydabqed)
- **Drift**: Local v1 schema with 26 tables (living v1 approach)
- **Schema**: 100% parity between Drift SQLite and Supabase PostgreSQL (26 tables)
- **GitHub Actions**: Configured for dev + prod workflows
- **Testing**: 160+ tests (150+ edge function, 11+ Flutter/Dart)
- **Users**: Zero active users - no migration concerns

## Architecture

### Two-Environment Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                      Development Workflow                        │
└─────────────────────────────────────────────────────────────────┘

Local Dev                         Cloud Dev                 Production
┌─────────────┐                  ┌─────────────┐          ┌─────────────┐
│             │                  │             │          │             │
│  Flutter    │  push to         │  Supabase   │  merge   │  Supabase   │
│  + Drift    │ ──────────────> │  Dev        │ ──────> │  Production │
│  + Local    │  develop         │  Project    │  main    │  Project    │
│  Supabase   │  branch          │             │  branch  │             │
│             │  (auto-deploy)   │             │  (manual │             │
│             │                  │             │  approval)│             │
└─────────────┘                  └─────────────┘          └─────────────┘
     │                                 │                        │
     v                                 v                        v
26 tables                         26 tables                26 tables
Schema v1                         Schema v1                Schema v1
Testing local                     CI/CD testing            Production
```

### Deployment Flow

```
Developer                    GitHub Actions               Supabase
────────                    ──────────────               ────────

Local changes
     │
     │ git push origin develop
     │
     v
[develop branch] ────────> [Deploy to Dev] ────────> [Dev Project]
                            • Run tests (160+)
                            • Deploy migrations
                            • Deploy edge functions
                            • No approval needed

     │
     │ git merge main
     │
     v
[main branch] ──────────> [Deploy to Prod] ────────> [Prod Project]
                           • Run tests (160+)
                           • ⚠️ Requires approval
                           • Deploy migrations
                           • Deploy edge functions
                           • Health checks
```

### Unified Schema Approach (V1: 26 Tables)

**Key Principle**: 100% schema parity between Drift SQLite and Supabase PostgreSQL from v1

**Schema Philosophy**: Living v1 that grows with new features until breaking changes require v2

All 26 tables exist in both databases with identical structure:

#### Core Tables (5)
1. **users** - User data and preferences (device authentication)
2. **nutrition_plans** - Generated nutrition plans
3. **food_preferences_table** - User food likes/dislikes
4. **feedback** - Plan ratings and survey responses
5. **macro_targets_table** - Nutrition target calculations (26 columns)

#### Food System Tables (8)
6. **foods_table** - Global food database
7. **product_types_table** - Food categories (gel, bar, drink mix)
8. **categories_table** - Timing categories (before_run, during_run, after_run)
9. **food_categories_table** - Food-to-category mappings
10. **user_foods_table** - User-created/scanned foods
11. **user_food_categories_table** - User food timing mappings
12. **user_hidden_foods_table** - Hidden foods per user
13. **edge_functions_table** - Edge function code storage

#### Content Management (2)
14. **app_content_table** - Dynamic UI text and algorithm parameters
15. **workout_notes** - User workout journal

#### Calendar Feature Tables (5)
16. **activities** - Scheduled runs and events
17. **events** - Race event details (marathon, half, 10K, etc.)
18. **activity_completions** - Post-workout data and ratings
19. **carb_loading_plans** - Multi-day carb loading plans for races
20. **carb_loading_days** - Daily carb targets and meal breakdowns

#### Carb Loading Food System (6)
21. **meal_types** - Meal categories (breakfast, lunch, dinner, snacks)
22. **carb_loading_foods** - Global default carb loading foods
23. **carb_loading_user_foods** - User-created carb loading foods
24. **carb_loading_food_meal_types** - Links default foods to meal types
25. **carb_loading_user_food_meal_types** - Links user foods to meal types
26. **carb_loading_day_meals** - Actual food selections per meal per day

**Removed from v1** (documented as dropped):
- `brands` table - Removed Oct 2025, not implemented

### Environment Configuration

#### File Structure
```
mealvana_endurance/
├── .env.dev.template         # Development config (committed to git)
├── .env.prod.template        # Production config (committed to git)
├── .env.dev.local           # Development secrets (gitignored)
├── .env.prod.local          # Production secrets (gitignored)
└── .env                     # Active environment (gitignored)
```

#### .gitignore Configuration
```gitignore
# Environment files with secrets
.env
.env.*.local

# Database schemas (generated)
database_schemas/
drift_schemas/
```

#### AppConfig Integration

```dart
class AppConfig {
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String mixpanelProjectToken;
  final String sentryEnvironment;
  final bool devModeEnabled;
  final String appEnvironment; // 'dev' or 'prod'

  factory AppConfig.fromEnv() {
    final appEnv = dotenv.get('APP_ENV', fallback: 'dev');
    final devMode = dotenv.get('DEV_MODE_ENABLED', fallback: 'true') == 'true';

    return AppConfig(
      supabaseUrl: dotenv.get('SUPABASE_URL'),
      supabaseAnonKey: dotenv.get('SUPABASE_ANON_KEY'),
      mixpanelProjectToken: dotenv.get('MIXPANEL_PROJECT_TOKEN'),
      sentryEnvironment: dotenv.get('SENTRY_ENVIRONMENT'),
      appEnvironment: appEnv,
      devModeEnabled: devMode,
    );
  }

  // Helper methods
  bool get isProduction => appEnvironment == 'prod';
  bool get isDevelopment => appEnvironment == 'dev';
}
```

## Quick Start

### 1. Create Supabase Projects

Follow [roadmap_lee.md Phase 1](./roadmap_lee.md#phase-1-supabase-projects-setup) for detailed steps.

**Summary**:
- Rename existing project to "Mealvana Endurance - Production"
- Create "Mealvana Endurance - Dev" project
- Collect credentials for each (URL, anon key, service role key)

### 2. Setup Drift Schema (16 Tables)

```bash
# Remove unused tables from app_database.dart
# - BrandsTable
# - CarbLoadingTable

# Regenerate code
dart run build_runner build --delete-conflicting-outputs

# Generate v1 schema snapshot
mkdir -p database_schemas/v1
dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/
```

See [roadmap.md Phase 1.1](./roadmap.md#11-drift-schema-cleanup) for detailed steps.

### 3. Deploy Unified Schema to Supabase

```bash
# Create migration
supabase migration new init_v1_unified_schema

# Add DDL for all 26 tables
# See roadmap.md Phase 1.3 for complete SQL

# Test locally
supabase start
supabase db reset

# Deploy to all environments
supabase link --project-ref <dev-ref>
supabase db push

supabase link --project-ref <prod-ref>
supabase db push
```

See [roadmap.md Phase 1.3](./roadmap.md#13-unified-v1-schema-migration) for complete DDL.

### 4. Create Environment Configs

```bash
# Create templates
cp .env.dev.template .env.dev.local
cp .env.prod.template .env.prod.local

# Fill in actual credentials
# Edit .env.dev.local with dev Supabase URL, keys, etc.
# Edit .env.prod.local with prod credentials
```

See [roadmap_lee.md Phase 2](./roadmap_lee.md#phase-2-create-local-environment-files) for template examples.

### 5. Test Builds

```bash
# Development
flutter run --dart-define-from-file=.env.dev.local

# Production
flutter build ipa --dart-define-from-file=.env.prod.local
```

## Development Workflow

### Daily Development

```bash
# Use dev environment
./scripts/use-env.sh dev
flutter run --dart-define-from-file=.env.dev.local

# Create schema changes
supabase migration new add_feature_x
# Edit migration file
supabase db reset  # Test locally

# Commit and push
git add supabase/migrations/
git commit -m "Add feature X"
git push origin develop  # Auto-deploys to dev via GitHub Actions
```

### Deploying to Production

```bash
# Merge to main (requires manual approval)
git checkout main
git merge develop
git push origin main  # Waits for manual approval, then deploys to prod
```

### Running Tests

#### All Tests
```bash
# Flutter/Dart tests (11+ tests)
flutter test

# Edge function tests (150+ tests)
cd test/local_edge_functions
npm install
npm test
```

#### CI/CD Testing
All tests run automatically on pull requests and commits:
- **Flutter tests**: Unit and widget tests
- **Edge function tests**: Vitest for pure function logic
- **Integration tests**: Real Supabase connectivity (manual/scheduled)

See [/docs/test/README.md](/docs/test/README.md) for complete testing documentation.

## Sync Strategies

| Table | Sync Direction | Strategy |
|-------|----------------|----------|
| user_profiles | Bidirectional | Real-time |
| nutrition_plans | Client → Cloud | Backup |
| food_preferences | Bidirectional | On change |
| feedback | Client → Cloud | Append-only |
| macro_targets | Client → Cloud | Backup |
| workout_notes | Bidirectional | Real-time |
| carb_loading_simple_plans | Bidirectional | Real-time |
| foods | Cloud → Client | Daily cache |
| product_types | Cloud → Client | On app start |
| user_foods | Bidirectional | Real-time |

**Key Principles**:
- **Offline-first**: Always write to Drift first
- **Background sync**: Sync to Supabase in background
- **Conflict resolution**: Last-write-wins (timestamp-based)

## Testing & CI/CD

### Current Test Coverage

**Edge Function Tests** (150+ tests via Vitest):
- `generate-ai-nutrition-plan`: Comprehensive coverage with business logic, integration, and E2E tests
- `generate-macros`: Formula validation (pending full implementation)
- `barcode-lookup`: Database integration tests
- `save-food-preferences`: CRUD operations

**Flutter/Dart Tests** (11+ tests and growing):
- Nutrition plan domain models (8 tests)
- Repository tests (in progress)
- Controller tests (in progress)
- Service tests (in progress)

### Three-Tier Testing Strategy

1. **Tier 1: Local Unit Tests (Vitest)**
   - Fast, deterministic testing of pure function logic
   - No database dependencies
   - Execution: `cd test/local_edge_functions && npm test`

2. **Tier 2: Local Integration Tests (Dart + Local Supabase)**
   - Realistic testing with isolated database
   - Local Supabase via Docker
   - Execution: `supabase start && flutter test test/integration/edge/local/`

3. **Tier 3: Dev Cloud E2E Tests (Dart + Dev Supabase)**
   - Production validation with real network conditions
   - Dev Supabase project credentials
   - Execution: `flutter test --tags edge,cloud --dart-define-from-file=.env.test_supabase`

### GitHub Actions Testing Workflow

Tests run automatically on every PR and commit:

```yaml
jobs:
  flutter-tests:       # 11+ Flutter/Dart tests
  edge-function-tests: # 150+ Vitest edge function tests
  edge-integration:    # Integration tests (manual/scheduled)
```

See workflow: `.github/workflows/test.yml`

### Test Execution Strategy

- **On every PR**: Fast suites (Flutter + edge unit tests)
- **On schedule/manual**: Integration tests against dev Supabase
- **Code coverage**: Uploaded to Codecov automatically

### Reference Documentation
- [Testing Handbook](/docs/test/README.md) - Complete testing guide
- [Testing Roadmap](/docs/test/roadmap.md) - Implementation phases and progress
- [Riverpod Testing](/docs/test/riverpod_3_testing.md) - Controller testing patterns

## Troubleshooting

### Schema Drift Detected

```bash
# Check differences
supabase db diff

# Create fix migration
supabase migration new fix_schema_drift
supabase db diff > supabase/migrations/<timestamp>_fix_schema_drift.sql

# Apply
supabase db push
```

### Environment Variables Not Loading

```bash
# Verify file exists
ls -la .env*

# Check values
cat .env.dev.local

# Rebuild
flutter clean
flutter pub get
flutter run --dart-define-from-file=.env.dev.local
```

### Tests Failing

```bash
# Run specific test file
flutter test test/path/to/test_file.dart

# Run with verbose output
flutter test --reporter expanded

# Check edge function tests
cd test/local_edge_functions
npm test -- --reporter=verbose
```

## Security

### Credential Hierarchy

**Never commit**:
- `.env` (active environment)
- `.env.*.local` (contains actual secrets)
- Database passwords
- API keys

**Safe to commit**:
- `.env.*.template` (no actual secrets)
- Migration files (DDL only, no data)

### RLS Policies

All user-specific tables enforce Row Level Security based on `device_id`:

```sql
CREATE POLICY "Users can read own profile"
  ON user_profiles FOR SELECT
  USING (device_id = current_setting('app.device_id', true));
```

## Implementation Roadmap

See [roadmap.md](./roadmap.md) for the complete 5-phase implementation plan:

1. **Phase 1**: Clean V1 Schema Baseline (1-2 days)
2. **Phase 2**: GitHub Actions Testing (1-2 days)
3. **Phase 3**: Testing Infrastructure (2-3 days)
4. **Phase 4**: Documentation Updates (1-2 days)
5. **Phase 5**: Production Cutover (1 day)

**Total Timeline**: 2-3 weeks

## Key Differences from Three-Environment Setup

This documentation describes a **two-environment strategy** (dev + prod):

- **No staging environment**: Simplified workflow reduces complexity
- **Direct path**: Local → Dev (auto) → Prod (manual approval)
- **Faster iteration**: Fewer environments to maintain
- **Clear separation**: Dev for testing, Prod for users

If you need staging in the future, see the git history for three-environment patterns.

---

**Last Updated**: 2025-10-06
**Schema Version**: v1 (26 tables)
**Environments**: Dev + Production (2 total)
**Test Coverage**: 160+ tests (150+ edge, 11+ Flutter)
**Status**: Ready for implementation
