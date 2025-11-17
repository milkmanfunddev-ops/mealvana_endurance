# Mealvana Endurance - AI Assistant Context

## Project Overview

### Purpose
Mealvana Endurance is a personalized nutrition planning app for endurance athletes (runners, cyclists, triathletes). It generates science-based nutrition plans based on run distance, pace, user biometrics, and food preferences.

### Target Users
- Endurance athletes preparing for races (5K to Ironmans and ultra-marathons) and seeking nutrition guidance

### Key Features
- **Personalized Nutrition Plans**: Algorithm-based plans considering distance, pace, body weight, and gut training
- **Food Preference Integration**: Respects user's liked/disliked foods
- **Science-Based Calculations**: Uses ACSM formulas and evidence-based nutrition research
- **Offline-First Architecture**: Works without internet using Drift SQLite database
- **Content Management System**: Backend-editable UI text and algorithm parameters

### Tech Stack
- **Framework**: Flutter 3.8+ with Dart
- **State Management**: Riverpod 2.x with code generation
- **Local Storage**: Drift (SQLite with type-safe migrations and code generation)
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
- Analytics tracking (except UI events like button taps)
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
│   │   ├── auth/           # Authentication & user management
│   │   ├── content/        # Content management system
│   │   ├── feedback/       # User feedback collection
│   │   ├── nutrition_plan/ # Core nutrition calculations
│   │   └── onboarding/     # User onboarding flow
│   ├── shared/             # Shared utilities and widgets
│   ├── theme/              # App theming and styles
│   └── main.dart           # App entry point
├── assets/
│   ├── config/             # Configuration files
│   │   └── content_defaults.json  # Default content & algorithm 
│   ├── images/             # App images and icons
│   └── fonts/              # Custom fonts
├── docs/
│   ├── technical/          # Technical documentation
│   ├── business_logic/     # Algorithm documentation
│   └── roadmap.md          # Project roadmap
└── test/                   # Test files
```

## Core Systems

### Nutrition Algorithm
The app uses a sophisticated **nutrition planning system**

- **Linear Programming**: Multi-objective optimization for food selection
- **Advanced Personalization**: Context-aware recommendations and preference learning
- **Constraint Solving**: Simultaneous optimization of carbs, protein, fat, sodium, hydration
- **ACSM Calculations**: Energy expenditure using ACSM running equation for MET calculation
- **Evidence-Based Guidelines**: Carbohydrate requirements based on gut training levels
- **Performance Optimized**: Sub-second response times with deterministic calculations
- **Safety Focused**: Duration-based sodium supplementation and intensity-based hydration

**Key Files**:
- Service orchestration: `/lib/features/nutrition_plan/application/nutrition_plan_service.dart`
- AI integration: `/lib/features/nutrition_plan/application/llm_nutrition_plan_service.dart`
- Primary Edge Function: `/supabase/functions/generate-ai-nutrition-plan/index.ts`
- Fallback Edge Function: `/supabase/functions/run-plan/index.ts`

📚 **Full Business Logic Documentation**: [/docs/business_logic/README.md](/docs/business_logic/README.md)

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
- Automatic synchronization with Supabase
- Multi-sport support (running, cycling, swimming) in development environment

**Cloud Storage (Supabase PostgreSQL)**:
- **Development**: Full multi-sport schema with 27 tables (cycling/swimming columns in users, activities, foods)
- **Production**: Partial multi-sport schema with 27 tables (missing cycling/swimming columns in users and activities tables)
- Content management system for dynamic UI text and algorithm parameters
- Edge functions for AI-powered nutrition plan generation
- Row Level Security based on device_id and user_id

**Schema Management**:
- **Current Version**: v1 (clean baseline, no migrations)
- **Schema Location**: `/database_schemas/v1/`
- **Snapshot Command**: `dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/`
- **Future Migrations**: Will use Drift's built-in migration system when moving to v2

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

## Development Practices

### Code Generation
The project uses build_runner for:
- Riverpod providers (`@riverpod` annotation)
- Drift database classes (`@DriftDatabase` annotation)
- Schema migration code generation
- JSON serialization (when needed)

**Commands**:
```bash
# Watch mode for development
flutter pub run build_runner watch --delete-conflicting-outputs

# One-time generation
flutter pub run build_runner build --delete-conflicting-outputs
```

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
/task-checker                            # Run quality checks (CodeRabbit + analyze + tests)
flutter test                            # Run tests manually if needed
```

**Release Builds (HUMAN ONLY)**:
```bash
flutter build ios --release             # iOS build (5-10+ minutes)
flutter build appbundle --release       # Android build (5-10+ minutes)
```

**Code Push (Shorebird)**:
```bash
shorebird release ios                   # Create iOS release
shorebird patch ios                     # Push iOS update
```

📚 **Full Documentation**: [/docs/technical/shorebird-code-push.md](/docs/technical/shorebird-code-push.md)

### Analytics & Monitoring
- **Analytics**: RudderStack → Mixpanel pipeline
- **Error Tracking**: Sentry for crash reporting
- **Performance**: Custom metrics via OpenTelemetry

📚 **Full Documentation**: 
- [/docs/technical/analytics.md](/docs/technical/analytics.md)
- [/docs/technical/error-tracking.md](/docs/technical/error-tracking.md)

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
- [Drift Migration Guide](/docs/technical/drift-migration-guide.md) - Database migration management for future versions
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

### Project Management
- [Roadmap](/docs/roadmap.md) - Current status and future plans
- [Features List](/docs/features.md) - Complete feature documentation

## Important Notes for AI Assistants

### When Making Changes
1. **Follow Andrea Bizzotto FOA Pattern**: Keep features self-contained with proper layer separation
2. **Use AsyncNotifier Controllers**: NEVER use StateNotifier - must use @riverpod AsyncNotifier
3. **Use Content Service**: Never hardcode UI text or algorithm parameters
4. **Maintain Offline-First**: Always write to local storage first
5. **Run Code Generation**: After adding `@riverpod` or `@DriftDatabase` annotations
6. **Generate Schema Snapshots**: After database changes: `dart run drift_dev schema dump lib/shared/database/app_database.dart database_schemas/v1/`
7. **Follow ContentService Integration**: All controllers must access ContentService for UI text
8. **Test on Both Platforms**: iOS and Android have different requirements
9. **Environment Deployments**: Use GitHub Actions workflows for automated dev/staging deployment

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
