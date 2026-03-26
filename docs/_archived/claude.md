# Mealvana Endurance - AI Assistant Context

## Purposes
This file is a quick routing guide for AI assistants working in `mealvana_endurance`.
Keep this file short. Detailed rules and implementation docs live under `/docs`.

## How To Use This File
1. Read the non-negotiable rules below.
2. Find your task type in the Docs Map section.
3. Open the linked `/docs` file for more details before coding.

## Project Overview

### Purpose
Mealvana Endurance is a personalized nutrition planning app for endurance athletes (runners, cyclists, swimmers, and triathletes). It generates science-based nutrition plans based on run distance, pace, user biometrics, and food preferences.

### Key Features
- **Personalized Nutrition Plans**: Algorithm-based plans considering distance, pace, body weight, and gut training
- **Brick Workout Support**: Multi-sport training sessions (swim/bike/run combinations) with unified nutrition planning and transition phase support
- **Food Preference Integration**: Respects user's liked/disliked foods
- **Science-Based Calculations**: Uses ACSM formulas and evidence-based nutrition research
- **Offline-First Architecture**: Works without internet using Drift SQLite database
- **Content Management System**: Backend-editable UI text and algorithm parameters

### Tech Stack
- **Framework**: Flutter 3.8+ with Dart
- **State Management**: Riverpod 2.x with code generation
- **Local Storage**: Drift (SQLite with type-safe queries and code generation)
- **Backend**: Supabase (PostgreSQL + Auth + Realtime)
- **Architecture**: Feature-Oriented Architecture (FOA) based on Andrea Bizzotto's patterns
- **Code Push**: Shorebird for OTA updates

## Architecture

### Feature-Oriented Architecture (FOA)
The project follows Andrea Bizzotto's four-layer architecture pattern. Each feature is self-contained with its own layers:

```
lib/features/{feature_name}/
├── presentation/   # UI widgets and controllers
├── application/    # Service classes and business logic
├── domain/        # Data models and entities
└── data/          # Repositories and data sources
```

**Key Principles:**
- **Separation of Concerns**: Each layer has specific responsibilities
- **Dependency Direction**: Only inward dependencies (presentation → application → domain ← data)
- **Testability**: Business logic isolated from UI and data sources
- **Scalability**: Features can be developed independently
- **MODULARITY**: Keep ALL widgets and dart files small and modular, breaking down larger files when needed into smaller widgets.

**🚨 CRITICAL FOA COMPLIANCE RULES:**

**UI/Controller Separation (MANDATORY)**:
- **UI Screens**: ONLY UI logic - state management, navigation, form validation, animations
- **Controllers**: ALL business logic - API calls, data processing, calculations, analytics
- **NEVER**: Put business logic in UI screens (no underscore methods like `_generateMacros()`)
- **NEVER**: Put UI logic in controllers (no navigation, no UI state like loading spinners)

**Forbidden in UI Screens**:
- API calls to Supabase edge functions
- Complex data transformations 
- Business calculations
- Underscore methods that contain business logic
- More than one widget or code that could be rationally broken down into smaller widgets.

**Required in Controllers**:
- All calls to external services (Supabase, analytics)
- Data validation and parsing
- Error handling and logging
- State mutations through repositories

📚 **Full Documentation**: [/docs/technical/README.md](/docs/technical/README.md)
📖 **UI/Controller Architecture**: [/docs/technical/foa-architecture.md](/docs/technical/foa-architecture.md)

### App Initialization Pattern (Andrea Bizzotto)

**CRITICAL**: The app follows Andrea Bizzotto's robust initialization pattern. **DO NOT** modify the initialization flow without understanding this pattern.

**Proper Flow:**
1. `main()` → Only non-recoverable initialization (Supabase, Firebase)
2. `RootAppWidget` → MaterialApp.router with builder
3. `MaterialApp.builder` → Wraps router child with `AppStartupWidget`
4. `AppStartupWidget` → Manages `appStartupProvider` and navigation
5. `appStartupProvider` → Initializes recoverable dependencies (Drift database, user session, analytics)

**Key Rules:**
- **Drift database initialization**: Must be in `appStartupProvider`, NOT in `main()`
- **User session detection**: Handled in app startup service 
- **Navigation logic**: AppStartupWidget determines initial route based on user state
- **Error handling**: AppStartupWidget shows retry for recoverable errors
- **Deep links**: Supported via MaterialApp.router + builder pattern

**Code Locations:**
- Main entry: `lib/main.dart`
- Root widget: `lib/shared/widgets/root_app_widget.dart`
- Startup widget: `lib/features/app_startup/presentation/widgets/app_startup_widget.dart`
- Startup service: `lib/shared/services/app_startup_service.dart`

📖 **Andrea's Documentation**: [/docs/technical/andrea/andrea_initialization.txt](/docs/technical/andrea/andrea_initialization.txt)

### Fat Backend Architecture
The app implements a "fat backend" strategy where business logic and content are controlled server-side:

**Content Management**:
- All UI text is editable via Supabase
- Algorithm parameters are configurable without code changes
- JSON-based content with fallback to local defaults

📚 **Full Documentation**: [/docs/technical/fat-backend-architecture.md](/docs/technical/fat-backend-architecture.md)

## Agents Available
- **task-checker**: Run comprehensive quality checks (CodeRabbit + Flutter analyze + tests). Use after completing significant work and before committing.
- **docs-manager**: Please use for creating, managing or updating our documentation.
- **code-researcher**: Please use for searching through the codebase for information.
- **web-research-specialist**: Use this for doing research on the web or using context7.
- **git-commit-helper**: Please commit often using this agent whenever you finish a major task.

## Project Structure

```
mealvana_endurance/
├── lib/
│   ├── features/           # Feature modules (FOA pattern)
│   │   ├── activities/     # Activity management and brick workouts
│   │   ├── auth/           # Authentication & user management
│   │   ├── content/        # Content management system
│   │   ├── feedback/       # User feedback collection
│   │   ├── nutrition_plan/ # Core nutrition calculations
│   │   └── onboarding/     # User onboarding flow
│   ├── shared/             # Shared utilities and widgets
│   │   ├── domain/         # Shared domain models (ActivityType, BrickMetadata)
│   │   └── database/       # Drift SQLite database and tables
│   ├── theme/              # App theming and styles
│   └── main.dart           # App entry point
├── assets/
│   ├── config/             # Configuration files
│   │   └── content_defaults.json  # Default content & algorithm
│   ├── images/             # App images and icons
│   └── fonts/              # Custom fonts
├── docs/
│   ├── brick/              # Brick workout feature documentation
│   ├── technical/          # Technical documentation
│   ├── business_logic/     # Algorithm documentation
│   └── database/           # Database schema and sync documentation
├── supabase/
│   ├── functions/          # Edge functions for nutrition calculations
│   └── migrations/         # Database migrations
└── test/                   # Test files
```

## Core Systems

### Nutrition Algorithm
The app uses a sophisticated **nutrition planning system**

**Key Files**:
- Service orchestration: `/lib/features/nutrition_plan/application/nutrition_plan_service.dart`
- AI integration: `/lib/features/nutrition_plan/application/llm_nutrition_plan_service.dart`
- Brick macro service: `/lib/features/nutrition_plan/application/brick_macro_service.dart`
- Primary Edge Function: `/supabase/functions/generate-ai-nutrition-plan/index.ts`
- Macro Generation: `/supabase/functions/generate-macros/index.ts`
- Brick Sport Config: `/supabase/functions/_shared/nutrition/sport-configs/brick.ts`

📚 **Full Business Logic Documentation**: [/docs/business_logic/README.md](/docs/business_logic/README.md)
📚 **Brick Workout Documentation**: [/docs/brick/README.md](/docs/brick/README.md)

### Content Management System
Dynamic content system with backend control:

**Structure**:
```json
{
  "ui_text": { ... },        // All user-facing strings
  "algorithm": {             // Configurable parameters
    "energy": { ... },       // ACSM constants
    "pre_run": { ... },      // Pre-run nutrition rules
    "during_run": { ... },   // During-run parameters
    "safety": { ... }        // Safety limits
  }
}
```

**Key Files**:
- Content service: `/lib/features/content/application/content_service.dart`
- Default content: `/assets/config/content_defaults.json`
- Repository: `/lib/features/content/data/content_repository.dart`

📚 **Full Documentation**: [/docs/technical/content-management.md](/docs/technical/content-management.md)

### Data Storage
Unified dual database architecture with local-first design and cloud synchronization:

**Schema v1 (Living Baseline)**:
- please look at /database_schemas/v1

**Local Storage (Drift SQLite)**:
- Offline-first architecture with full schema v1 (27 tables)
- Type-safe queries and compile-time validation
- On-demand synchronization with Supabase (no "sync all at startup")
- Multi-sport support (running, cycling, swimming, brick workouts) in development environment
- Brick metadata stored as JSON in activities table with `brick_metadata` and `brick_id` columns
- Dirty record tracking via `needs_upload` boolean column
- Staleness tracking via SharedPreferences timestamps

**Cloud Storage (Supabase PostgreSQL)**:
- **Development**: Full multi-sport schema with 27 tables (cycling/swimming columns in users, activities, foods)
- **Production**: Partial multi-sport schema with 27 tables (missing cycling/swimming columns in users and activities tables)
- Brick workout support with `brick_metadata` JSONB column and `brick_id` foreign key in activities table
- Activity type enum includes 'brick' value, status enum includes 'archived_for_brick' for soft-deleted originals
- Content management system for dynamic UI text and algorithm parameters
- Edge functions for AI-powered nutrition plan generation and brick macro calculations
- Row Level Security based on device_id and user_id
- `app_config` table for version control (min_app_version, current_schema_version)

**Schema Management (Server-Side Versioning)**:
- **Current Version**: v3 (controlled via `current_schema_version` in Supabase `app_config` table)
- **Migration Strategy**: Delete-and-resync (no step-by-step Drift migrations)
- **How It Works**: When `app_config.current_schema_version` differs from local `AppDatabase.schemaVersion`:
  1. App uploads dirty records to preserve user data
  2. Local database is deleted
  3. Fresh database is created with new schema
  4. Data is resynced from Supabase
- **Version Control**: Bump both `AppDatabase.schemaVersion` in code AND `current_schema_version` in Supabase
- **Force Updates**: Set `min_app_version` in `app_config` to require app store updates for breaking changes

**Development Environments**:
- **Dev**: Automated deployment on `develop` branch push (tests run first)
- **Production**: Manual approval required for `main` branch (tests run first)
- **Automation**: GitHub Actions for CI/CD, testing, and daily drift detection
- **Testing**: 160+ tests (150+ edge function, 11+ Flutter) run on every deployment

📚 **Full Documentation**:
- [Database Overview](/docs/database/README.md) - Complete unified architecture
- [Drift Database](/docs/database/drift/README.md) - Local SQLite with v1 schema (26 tables)
- [V1 Schema Files](/database_schemas/v1/) - Complete DDL and Drift snapshot
- [Supabase Tables](/docs/database/supabase/README.md) - Cloud backend with 100% parity
- [Dev/Prod Setup](/docs/features/dev_prod/README.md) - Environment configuration guide
- [Implementation Roadmap](/docs/features/dev_prod/roadmap.md) - Step-by-step deployment plan

### Data Synchronization Architecture

**CRITICAL**: The app uses a repository-level, on-demand sync pattern with automatic dependency resolution. This replaces the previous "sync all at startup" approach.

**Key Concepts:**
- **Staleness Threshold**: Each repository tracks its last sync time in SharedPreferences; data is considered stale after 1 hour
- **Lazy Sync**: Data is only synced when needed (when controller calls `ensureSynced()`)
- **Dependency Resolution**: Dependencies are automatically synced first using a dependency graph
- **Dirty Record Protection**: Local changes are uploaded first, with JSON backup on failure
- **Schema Migration**: Delete and resync strategy (no complex step-by-step migrations)
- **Direct Supabase Queries**: Repositories query Supabase directly (no edge functions needed for sync)
- **Integration Change Detection**: External provider sync (Final Surge, Training Peaks) includes change detection for schedule updates, with automatic nutrition plan staleness flagging when significant changes occur (see `/docs/update_integration/` for details)

**SyncableRepository Mixin:**
```dart
mixin SyncableRepository {
  /// Repository identifier for staleness tracking
  /// Used as key in SharedPreferences: '{repositoryKey}_last_sync'
  String get repositoryKey;

  /// Dependencies that must be synced first
  /// Example: activities → ['users']
  List<String> get dependencies => [];

  /// Check if data is stale (>1 hour since last sync)
  Future<bool> isStale();

  /// Sync this repository's data from Supabase
  Future<SyncResult> syncFromRemote(String userId);

  /// Upload dirty records for this repository
  Future<UploadResult> uploadDirtyRecords(String userId);

  /// Get/set last sync timestamp in SharedPreferences
  Future<DateTime?> getLastSyncTime();
  Future<void> setLastSyncTime(DateTime time);
}
```

**Controller Pattern with ensureSynced:**
```dart
@riverpod
class ActivitiesController extends _$ActivitiesController {
  SyncCoordinator get _syncCoordinator => ref.read(syncCoordinatorProvider.notifier);

  @override
  Future<List<Activity>> build() async {
    final userId = await ref.read(userIdProvider.future);

    // Ensure activities (and dependencies) are synced
    // Only syncs if stale (>1h since last sync)
    await _syncCoordinator.ensureSynced(
      'activities',
      userId,
      repository: ref.read(activitiesRepositoryProvider),
    );

    // Return data from local Drift database
    return ref.read(activitiesRepositoryProvider).getActivities(userId);
  }
}
```

**How ensureSynced Works:**
```
Controller calls: ensureSynced('activities', userId, repository: repo)
    ↓
1. Check: Is 'activities' currently syncing?
   └── Yes → Return immediately (prevent infinite loops)
    ↓
2. Check: Is 'activities' stale (>1h since last sync in SharedPreferences)?
   ├── No  → Return immediately (data is fresh)
   └── Yes → Continue to step 3
    ↓
3. Mark 'activities' as syncing (_syncingNow set)
    ↓
4. Look up dependencies from graph: activities → ['users']
    ↓
5. Recursively sync dependencies FIRST: ensureSynced('users', userId, ...)
    ↓
6. Upload dirty records for 'activities' (with 3 retries)
   ├── Success → Clear dirty flags
   └── All retries failed → Backup to JSON (continue with sync)
    ↓
7. Sync fresh data from Supabase (direct PostgreSQL query)
    ↓
8. Save to local Drift database
    ↓
9. Update '{repositoryKey}_last_sync' in SharedPreferences
    ↓
10. Remove 'activities' from _syncingNow set
```

**Dependency Graph:**
```
Level 0 (No Dependencies):
├── users
├── foods
└── carb_loading_foods

Level 1 (Depend on users):
├── activities → ['users']
├── events → ['users']
├── user_foods → ['users']
├── coaches → ['users']
└── feedback → ['users']

Level 2 (Depend on Level 1):
├── food_preferences → ['users', 'foods']
├── coach_athlete_relationships → ['coaches', 'users']
└── carb_loading_plans → ['users', 'events']

Level 3 (Depend on Level 2):
├── carb_loading_days → ['carb_loading_plans']
└── coach_messages → ['coach_athlete_relationships']

Level 4 (Depend on Level 3):
└── carb_loading_day_meals → ['carb_loading_days', 'carb_loading_foods']
```

**Dirty Record Backup Flow:**
```
Repository needs to sync → Check for dirty records (needs_upload = true)
    ↓
Try upload to Supabase (3 retries with exponential backoff)
    ↓
├── Success → Clear dirty flags → Proceed with sync
└── All retries failed
    ↓
    Create DirtyRecordBackup object with:
    - backup_created_at (ISO8601 timestamp)
    - app_version (from PackageInfo)
    - schema_version (from AppDatabase.schemaVersion)
    - user_id
    - dirty_records (Map<String, List<Map<String, dynamic>>>)
    - upload_errors (List<UploadError>)
    ↓
    Save to JSON file in App Support directory
    ↓
    Log warning to Sentry
    ↓
    Proceed with sync (data is safely backed up)
```

**Backup File Location:**
```
iOS: ~/Library/Application Support/{bundle_id}/dirty_records_backup.json
Android: /data/data/{package_name}/files/dirty_records_backup.json
```

**Backup File Structure:**
```json
{
  "backup_created_at": "2026-01-18T10:30:00Z",
  "app_version": "1.12.1",
  "schema_version": 3,
  "user_id": "user-uuid-123",
  "dirty_records": {
    "activities": [
      { "id": "activity-uuid", "name": "Morning Run", ... }
    ],
    "events": []
  },
  "upload_errors": [
    {
      "repository": "activities",
      "error": "Network timeout after 3 retries",
      "timestamp": "2026-01-18T10:30:00Z"
    }
  ]
}
```

**Recovery Flow (App Startup):**
```
App Startup → DirtyRecordBackupService.hasBackup()
    ↓
├── No backup file → Normal startup
└── Backup file exists
    ↓
    Show DirtyRecordRecoveryDialog to user
    ↓
    User chooses:
    ├── "Upload" → Attempt upload → Delete backup on success
    └── "Discard" → Delete backup file immediately
```

**Version Check and Force Upgrade:**
The app queries `app_config` table in Supabase on startup:

| Column | Purpose | Action if Mismatch |
|--------|---------|-------------------|
| `min_app_version` | Minimum app version allowed (e.g., "1.12.0") | Show ForceUpgradeScreen with App Store/Play Store link |
| `current_schema_version` | Expected Drift schema version (e.g., 3) | Trigger delete & resync flow |

**Schema Migration Strategy:**
```
App Startup → VersionCheckService.checkVersion()
    ↓
Query app_config table (timeout: 5 seconds)
    ↓
├── Network failure → Use cached result (expires after 24h)
└── Success → Compare versions
    ↓
Compare app version:
├── App version >= min_app_version → Continue
└── App version < min_app_version → Show ForceUpgradeScreen (blocks app)
    ↓
Compare schema version:
├── Local schemaVersion == current_schema_version → Normal startup
└── Local schemaVersion != current_schema_version
    ↓
    Show loading indicator
    ↓
    Collect ALL dirty records from ALL repositories
    ↓
    Try upload dirty records (3 retries)
    ├── Success → Clear dirty flags
    └── Failure → Save to dirty_records_backup.json
    ↓
    Delete local Drift database file
    ↓
    Reinitialize AppDatabase (new schema)
    ↓
    Full resync from Supabase (all repositories)
    ↓
    Update cached schema version in SharedPreferences
    ↓
    Continue to app
```

**Key Services:**
- **SyncCoordinator**: Central orchestrator with dependency graph (`lib/shared/services/sync/sync_coordinator.dart`)
- **VersionCheckService**: App/schema version validation (`lib/shared/services/version_check_service.dart`)
- **DirtyRecordBackupService**: JSON backup/recovery (`lib/shared/services/dirty_record_backup_service.dart`)

📚 **Complete Sync Documentation**: [/docs/technical/sync-architecture.md](/docs/technical/sync-architecture.md)

## Development Practices

### Code Generation
The project uses build_runner for:
- Riverpod providers (`@riverpod` annotation)
- Drift database classes (`@DriftDatabase` annotation)
- JSON serialization (when needed)

**Commands**:
```bash
# Watch mode for development
flutter pub run build_runner watch --delete-conflicting-outputs

# One-time generation
flutter pub run build_runner build --delete-conflicting-outputs
```

### UI Feedback Components (Snackbars)

**🎯 CRITICAL: Always use `MealvanaSnackbar` for user feedback messages.**

The project has a centralized snackbar system at `lib/shared/widgets/kyle_design/feedback/mealvana_snackbar.dart`. **Never use basic Flutter `SnackBar` directly.**

**Usage:**
```dart
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';

// Success messages (teal background with checkmark)
MealvanaSnackbar.showSuccess(context, 'Operation completed successfully!');

// Error messages (pink background with error icon)
MealvanaSnackbar.showError(context, 'Something went wrong');

// Warning messages (orange background with warning icon)
MealvanaSnackbar.showWarning(context, 'Please check your input');

// Info messages (cream background with info icon)
MealvanaSnackbar.showInfo(context, 'Here is some information');

// Loading (cream background with spinner - stays until dismissed)
final controller = MealvanaSnackbar.showLoading(context, 'Saving...');
// ... do work ...
controller.close();
```

**Why MealvanaSnackbar:**
- Consistent branding (proper colors, icons, typography)
- Floating behavior with proper margins
- Automatic icon display per type
- Proper duration handling
- Clears previous snackbars automatically

### State Management with Riverpod (Andrea Bizzotto FOA Patterns)

**🎯 CRITICAL: All controllers MUST follow Andrea Bizzotto's AsyncNotifier patterns**

**Controller Patterns (FOA Compliant)**:
- **Controllers**: `AsyncNotifier<T>` with `@riverpod` annotation and code generation
- **Services**: `Provider<T>` for business logic classes
- **Repositories**: `Provider<T>` for data access classes

**Required Controller Structure**:
```dart
import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'controller_name.g.dart';

@riverpod
class ScreenController extends _$ScreenController {
  // Access services via ref.read()
  ServiceClass get _service => ref.read(serviceProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);

  @override
  FutureOr<StateType> build() {
    // Initialize synchronously with cached content when possible
    // Return initial state directly
    return initialState;
  }

  // Use AsyncValue.guard for error handling
  Future<void> performAction() async {
    state = const AsyncLoading();
    
    state = await AsyncValue.guard(() async {
      // Business logic here
      return updatedState;
    });
  }
  
  // Use ref.invalidateSelf() for refresh
  Future<void> refresh() async {
    await _service.refreshData();
    ref.invalidateSelf();
  }
}
```

**🚨 MANDATORY Requirements:**
1. **Use `@riverpod` annotation** - Never create manual providers
2. **Extend `AsyncNotifier<T>`** - Never use old `StateNotifier`
3. **Use `AsyncValue.guard()`** - For consistent error handling
4. **Access ContentService** - All text must come from content management system
5. **Include `part` directive** - For code generation
6. **Run `dart run build_runner build`** - After creating/modifying controllers

📚 **Full Documentation**: [/docs/technical/foa-architecture.md](/docs/technical/foa-architecture.md)

### Build & Deployment

**🚨 IMPORTANT FOR AI ASSISTANTS:**
- **NEVER run `flutter build` commands** - These take 5-10+ minutes and should only be run by the human developer
- **DO use `/task-checker` agent** - Runs comprehensive quality checks (CodeRabbit + Flutter analyze + tests)
- **Let the human handle builds** - They will run builds when ready for testing/deployment

**Local Development**:
```bash
flutter run                              # Run on connected device
flutter run -d chrome                    # Run web version in Chrome
/task-checker                            # Run quality checks (CodeRabbit + analyze + tests)
flutter test                            # Run tests manually if needed
```

**Release Builds (HUMAN ONLY)**:
```bash
# Mobile builds
flutter build ios --release             # iOS build (5-10+ minutes)
flutter build appbundle --release       # Android build (5-10+ minutes)

# Web build (2025 recommended)
flutter build web --release --wasm --pwa-strategy=none  # Web build with Skwasm renderer
```

**Why `--wasm` for web builds?**
- The `--web-renderer` flag is deprecated in Flutter 3.24+
- `--wasm` enables the new Skwasm renderer (faster, smaller at 1.1MB vs 1.5MB)
- Automatically falls back to CanvasKit on unsupported browsers

**Code Push (Shorebird)**:
```bash
shorebird release ios                   # Create iOS release
shorebird patch ios                     # Push iOS update
```

**Edge Function Deployment (Supabase CLI)**:

Deploy individual edge functions using `supabase functions deploy`. The `_shared/` folder is automatically bundled with each function.

```bash
# Project refs
# Dev:  vlmtsdzpnjnavdgytcmi
# Prod: wvmvsodrvbkxfydabqed

# Deploy a single function to dev
supabase functions deploy <function-name> --project-ref vlmtsdzpnjnavdgytcmi --no-verify-jwt

# Deploy a single function to prod
supabase functions deploy <function-name> --project-ref wvmvsodrvbkxfydabqed --no-verify-jwt

# Examples:
supabase functions deploy lookup-product --project-ref vlmtsdzpnjnavdgytcmi --no-verify-jwt
supabase functions deploy generate-nutrition-plan-v3 --project-ref wvmvsodrvbkxfydabqed --no-verify-jwt

# List deployed functions
supabase functions list --project-ref vlmtsdzpnjnavdgytcmi
```

**Important**: When modifying files in `supabase/functions/_shared/`, you must redeploy ALL functions that import from the changed shared files. Key shared dependency chains:
- `_shared/nutrition/constants.ts` & `types.ts` → `generate-nutrition-plan-v2`, `generate-nutrition-plan-v3`
- `_shared/nutrition/template-food-queries.ts` → `generate-nutrition-plan-v2`, `generate-nutrition-plan-v3`
- `_shared/nutrition/food-queries.ts` → `generate-nutrition-plan` (v1)

**Web Deployment Prerequisites:**
Before implementing web repositories, complete these setup steps:
1. Add `sqlite3_web: ^0.1.0` and `drift_web: ^2.20.0` to pubspec.yaml
2. Download `sqlite3.wasm` to `web/` directory:
   ```bash
   curl -L -o web/sqlite3.wasm https://github.com/simolus3/sqlite3.dart/releases/download/0.1.0/sqlite3.wasm
   ```
3. Update `AppDatabase._openConnection()` with `kIsWeb` check for WebDatabase
4. Remove `.env` files from web assets (security risk - web bundles are public)
5. Configure Vercel environment variables for secrets
6. Create `vercel.json` with proper WASM headers

📚 **Complete Web Setup**: [/docs/web_mode/SETUP.md](/docs/web_mode/SETUP.md)

📚 **Full Documentation**: [/docs/technical/shorebird-code-push.md](/docs/technical/shorebird-code-push.md)

### Analytics & Monitoring
- **Analytics**: RudderStack → Mixpanel pipeline
- **Error Tracking**: Sentry for crash reporting
- **Performance**: Custom metrics via OpenTelemetry

📚 **Full Documentation**: [/docs/technical/sentry-integration.md](/docs/technical/sentry-integration.md)

## Documentation Index

### Architecture Documentation
- [App Architecture](/docs/architecture/README.md) - Complete current architecture overview
- [Technical Implementation](/docs/technical/README.md) - Detailed development patterns
- [Database Architecture](/docs/database/README.md) - Dual database implementation and migrations

### Technical Documentation
- [Technical Overview](/docs/technical/README.md) - Complete technical architecture guide with current Drift SQLite v1 schema
- [Fat Backend Architecture](/docs/technical/fat-backend-architecture.md) - Content management strategy with Drift SQLite caching
- [Content Management System](/docs/technical/content-management.md) - Dynamic content management with Drift SQLite storage
- [Drift Database Implementation](/docs/technical/drift-implementation.md) - Type-safe SQLite database with v1 schema
- [Sync Architecture](/docs/technical/sync-architecture.md) - Delete-and-resync migration strategy
- [Logging Service](/docs/technical/logging-service.md) - Structured logging implementation
- [Sentry Integration](/docs/technical/sentry-integration.md) - Error tracking and performance monitoring
- [Shorebird Code Push](/docs/technical/shorebird-code-push.md) - Over-the-air updates

### Business Logic & AI Architecture
- [Business Logic Overview](/docs/business_logic/README.md) - Complete AI-first system architecture
- [AI Nutrition Planning](/docs/business_logic/ai-nutrition-planning.md) - LLM integration and linear programming optimization
- [Current Edge Functions](/docs/business_logic/edge-functions-current.md) - Active Edge Functions deployment guide  
- [Nutrition Algorithms](/docs/business_logic/nutrition_algorithms.md) - Evidence-based calculation formulas and AI system details
- [Food Preferences System](/docs/business_logic/food-preferences-system-overview.md) - Three-tier preference model and database design

### Andrea Bizzotto's Architecture Guides
- [Architecture Overview](/docs/technical/andrea/andrea_architecture.txt)
- [Presentation Layer](/docs/technical/andrea/andrea_presentation_layer.txt)
- [Application Layer](/docs/technical/andrea/andrea_application_layer.txt)
- [Domain Layer](/docs/technical/andrea/andrea_domain_layer.txt)
- [Data Layer](/docs/technical/andrea/andrea_data_layer.txt)
- [Riverpod Patterns](/docs/technical/andrea/andrea_riverpod_autogenerate_new.txt)
- [Data Mutations](/docs/technical/andrea/andrea_data_mutations.txt)

### Web Deployment Documentation

**DECISION (2025-12-16 - FINAL)**: Using **drift_web** to leverage existing Drift database on web with minimal changes.

**Implementation Approach:**
- **Mobile**: 100% unchanged (existing Drift + SQLite)
- **Web**: Same Drift code using `drift_web` + IndexedDB (transparent)
- **Code Changes**: 1 file, ~10 lines (add `kIsWeb` check to database initialization)
- **Controllers/Services**: Zero changes (work on both platforms)
- **Repositories**: Zero changes (same queries work everywhere)
- **Timeline**: **1 week (5 days testing)** to production-ready web app

**Why drift_web:**
1. **Simplest**: 1 code change (10 lines) vs 2000+ lines for web repositories
2. **Fastest**: 1 week vs 2+ weeks
3. **Zero duplication**: Same database code works on mobile + web
4. **Zero risk**: All existing controllers, services, repositories unchanged
5. **Full offline**: IndexedDB storage included from day 1

**The Math:**
- Web repositories: 14 repositories × ~150 lines = 2,100+ lines to maintain forever
- drift_web: 1 conditional statement

**Setup:**
```bash
flutter create . --platforms=web
flutter pub add drift_web
```

Update `AppDatabase._openConnection()` with `kIsWeb` check (see /docs/web_mode/SETUP.md)

**Note:** drift_web uses sql.js (JavaScript SQLite) built-in. No additional dependencies or WASM downloads needed.

**Build command:**
```bash
flutter build web --release --wasm --pwa-strategy=none
```

**Key distinction:** The `--wasm` flag is for Flutter's Skwasm renderer (faster UI), NOT for SQLite. drift_web uses sql.js by default.

**Timeline:** 30 minutes setup + 5 days testing = 1 week total

**Documentation:**
- [Web Deployment Overview](/docs/web_mode/README.md) - Complete architecture using drift_web approach
- [Web Setup Guide](/docs/web_mode/SETUP.md) - Step-by-step drift_web setup (30 minutes)
- [Web Implementation Roadmap](/docs/web_mode/roadmap-simplified.md) - 1-week deployment plan
- [Web Caching Strategy](/docs/web_mode/cache-strategy.md) - How drift_web uses IndexedDB

### Feature Documentation
- [Onboarding Revamp](/docs/features/onboarding-revamp/README.md) - Multi-sport onboarding redesign (Phase 3 - In Progress)
- [Onboarding Technical Guide](/docs/features/onboarding-revamp/technical-guide.md) - Implementation patterns and code examples
- [Phase 4 Checklist](/docs/features/onboarding-revamp/phase-4-checklist.md) - Wiring & integration tasks

### Project Management
- [Server-Side Versioning Plan](/docs/database/server-side-versioning-plan.md) - Schema migration strategy

## Important Notes for AI Assistants

### When Making Changes
1. **Follow Andrea Bizzotto FOA Pattern**: Keep features self-contained with proper layer separation
2. **Use AsyncNotifier Controllers**: NEVER use StateNotifier - must use @riverpod AsyncNotifier
3. **Use Content Service**: Never hardcode UI text or algorithm parameters
4. **Maintain Offline-First**: Always write to local storage first with `needs_upload = true` flag
5. **Run Code Generation**: After adding `@riverpod` or `@DriftDatabase` annotations
6. **Schema Changes**: Update `AppDatabase.schemaVersion` in code AND `current_schema_version` in Supabase `app_config` table (users will auto-resync)
7. **Follow ContentService Integration**: All controllers must access ContentService for UI text
8. **Implement SyncableRepository**: New repositories must implement the mixin with proper dependencies
9. **Update Dependency Graph**: Add new repository key to SyncCoordinator._dependencies map
10. **Test on Both Platforms**: iOS and Android have different requirements
11. **Environment Deployments**: Use GitHub Actions workflows for automated dev/staging deployment

### Key Design Decisions
- **No Static Methods**: Use dependency injection via Riverpod
- **Async by Default**: Most operations should be async
- **Error Handling**: Use `AsyncValue.guard` for consistent error handling
- **Content Fallbacks**: Always provide local defaults for offline mode

### Common Tasks
- **Adding New Content**: Update `/assets/config/content_defaults.json`
- **Changing Algorithm**: Modify parameters in content JSON, not code
- **Adding Features**: Create new folder under `/lib/features/`
- **Updating Dependencies**: Run `flutter pub upgrade` carefully

### Testing Strategy
Mealvana Endurance implements a **focused, speed-optimized testing approach** designed for aggressive development timelines with minimal maintenance overhead.

**Philosophy**:
- **Integration tests over unit tests** - Focus on critical business logic paths
- **Fast execution** - No slow widget pumping, uses Andrea Bizzotto's AsyncNotifier patterns
- **Real dependencies** - In-memory databases and live API calls for authentic validation
- **Risk-based coverage** - Test the 5% of functionality that causes 95% of user pain

**Critical Test Categories**:
1. **Schema Migration Tests** - Prevent app crashes during future database updates
2. **Food Suitability Validation** - Ensure user safety (no oatmeal during runs)
3. **Macro Target Validation** - Core value proposition accuracy within ±10g tolerance
4. **Device Authentication Flow** - Privacy compliance and data integrity
5. **Edge Function Integration** - AI nutrition generation and error handling
6. **Content Management System** - Backend-controlled UI text and algorithm parameters

📚 **Complete Testing Documentation**: [/docs/test/README.md](/docs/test/README.md)

## Contact & Resources

### External Resources
- [Flutter Documentation](https://docs.flutter.dev)
- [Riverpod Documentation](https://riverpod.dev)
- [Andrea Bizzotto's Blog](https://codewithandrea.com)
- [Supabase Documentation](https://supabase.com/docs)

### Project Specific
- Repository: `mealvana_endurance`
- Platform: iOS 12.0+ / Android API 21+
- Flutter Version: 3.8.0+

---

*This document serves as the primary context file for AI assistants working on the Mealvana Endurance project. It should be updated whenever significant architectural decisions or changes are made.*
