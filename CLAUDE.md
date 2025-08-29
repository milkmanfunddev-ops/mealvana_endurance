# Mealvana Endurance - AI Assistant Context

## Project Overview

### Purpose
Mealvana Endurance is a personalized nutrition planning app for endurance athletes (runners, cyclists, triathletes). It generates science-based nutrition plans based on run distance, pace, user biometrics, and food preferences.

### Target Users
- Endurance athletes preparing for races (5K to ultra-marathons)
- Runners seeking personalized nutrition guidance
- Athletes wanting to optimize their fueling strategy

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

**Benefits**:
- Non-technical team members can update content
- A/B testing of algorithm parameters
- Instant updates without app releases

📚 **Full Documentation**: [/docs/technical/fat-backend-architecture.md](/docs/technical/fat-backend-architecture.md)

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
│   │   └── content_defaults.json  # Default content & algorithm parameters
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
The app uses an evidence-based algorithm for nutrition planning based on:
- **Energy Expenditure**: ACSM running equation for MET calculation
- **Carbohydrate Requirements**: Gut training levels (0.7-1.0 g/kg/h)
- **Hydration**: Intensity-based fluid recommendations (400-800 mL/h)
- **Electrolytes**: Duration-based sodium supplementation

**Key Files**:
- Algorithm implementation: `/lib/features/nutrition_plan/application/nutrition_calculator.dart`
- Algorithm documentation: `/docs/business_logic/nutrition_algorithms.md`
- Python reference: `/docs/business_logic/run_fueling.py`

📚 **Full Documentation**: [/docs/business_logic/nutrition_algorithms.md](/docs/business_logic/nutrition_algorithms.md)

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
Offline-first architecture using Drift (SQLite):

**Database Tables**:
- `user_profiles`: User biometric data and preferences
- `food_preferences`: Like/dislike food selections with user associations
- `nutrition_plans`: Generated nutrition plans with full history
- `app_content`: Cached backend content with version control
- `feedback`: User feedback queue with sync status

**Migration System**:
- **Schema Versioning**: Built-in versioning with automatic migration generation
- **Step-by-Step Migrations**: Type-safe migrations with schema validation
- **Migration Testing**: Auto-generated test cases for all schema changes
- **Rollback Support**: Safe rollback mechanisms for failed migrations

📚 **Full Documentation**: [/docs/database/README.md](/docs/database/README.md)

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
- **DO run `flutter analyze`** - This is fast and helps catch issues
- **Let the human handle builds** - They will run builds when ready for testing/deployment

**Local Development**:
```bash
flutter run                              # Run on connected device
flutter analyze                          # Check for issues (AI assistants should use this)
flutter test                            # Run tests
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

## External Integrations

### Supabase Backend
**Tables**:
- `app_content`: Dynamic content management
- `user_profiles`: User data sync
- `nutrition_plans`: Plan backup/sync
- `feedback`: User feedback collection

**Environment Variables**:
```dart
// lib/main.dart
url: 'https://[PROJECT_ID].supabase.co'
anonKey: '[ANON_KEY]'
```

📚 **Full Documentation**: [/docs/technical/backend-integration.md](/docs/technical/backend-integration.md)

### Analytics & Monitoring
- **Analytics**: RudderStack → Mixpanel pipeline
- **Error Tracking**: Sentry for crash reporting
- **Performance**: Custom metrics via OpenTelemetry

📚 **Full Documentation**: 
- [/docs/technical/analytics.md](/docs/technical/analytics.md)
- [/docs/technical/error-tracking.md](/docs/technical/error-tracking.md)

## Documentation Index

### Technical Documentation
- [Architecture Overview](/docs/technical/README.md) - Complete architecture guide
- [Fat Backend Architecture](/docs/technical/fat-backend-architecture.md) - Content management strategy
- [Content Management](/docs/technical/content-management.md) - CMS implementation details
- [Data Storage](/docs/database/README.md) - Drift database implementation and migrations
- [Backend Integration](/docs/technical/backend-integration.md) - Supabase setup
- [CI/CD Pipeline](/docs/technical/cicd.md) - Codemagic configuration
- [Shorebird Code Push](/docs/technical/shorebird-code-push.md) - OTA updates
- [Analytics](/docs/technical/analytics.md) - Event tracking setup
- [Error Tracking](/docs/technical/error-tracking.md) - Sentry integration
- [Subscriptions](/docs/technical/subscriptions.md) - RevenueCat setup

### Business Logic
- [Nutrition Algorithms](/docs/business_logic/nutrition_algorithms.md) - Core calculation formulas
- [Python Reference Implementation](/docs/business_logic/run_fueling.py) - Algorithm reference
- [Output Reference](/docs/business_logic/output_reference.md) - Algorithm output documentation
- [Usage Examples](/docs/business_logic/examples.md) - Algorithm usage examples

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
6. **Generate Schema Migrations**: After database schema changes using `dart run drift_dev make-migrations`
6. **Follow ContentService Integration**: All controllers must access ContentService for UI text
7. **Test on Both Platforms**: iOS and Android have different requirements

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

### Testing Approach
- Unit tests for algorithms and business logic
- Widget tests for UI components
- Integration tests for critical user flows
- Manual testing on real devices for performance

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