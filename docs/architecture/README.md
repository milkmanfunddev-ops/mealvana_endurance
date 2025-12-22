# Mealvana Endurance App Architecture

## Overview
This document outlines the current architecture for the Mealvana Endurance Flutter app that generates personalized nutrition fueling plans for endurance athletes. The app prioritizes offline-first functionality with robust sync capabilities and type-safe data handling.

## Current Architecture Summary (2025)
- **Targets:** iOS & Android
- **Style:** Feature-oriented architecture (FOA) - Andrea Bizzotto patterns
- **Source of truth:** Supabase PostgreSQL (dual database architecture)
- **Local storage:** Drift SQLite v2 (27 tables with proper migrations and idempotent checks)
- **Authentication:** Device-based (no traditional user accounts)
- **State management:** Riverpod v2 with `@riverpod` AsyncNotifier pattern
- **Navigation:** GoRouter with Andrea Bizzotto initialization pattern
- **Content Management:** Backend-controlled UI text and algorithm parameters
- **Analytics:** RudderStack → Mixpanel pipeline
- **Error Tracking:** Sentry
- **Code Push:** Shorebird for OTA updates
- **CI/CD:** Codemagic

## Key Requirements
- **Critical offline functionality** - App must work without internet
- **Type safety across stack** - Consistent naming between database, API, models, and cache
- **Device-based authentication** - No user accounts, identified by device ID
- **Dynamic content management** - Backend-controlled UI text and algorithm parameters
- **Complex data relationships** - User → preferences → plans → feedback

## Current Feature Structure
```
lib/features/
├── app_startup/          # Andrea Bizzotto initialization pattern
├── auth/                 # Device-based authentication & user profiles
├── content/              # Dynamic content management system
├── feedback/             # User feedback with survey system
├── notes/                # User notes functionality
├── nutrition_plan/       # Core nutrition calculations & plan generation
├── onboarding/           # User onboarding flow
├── recipes/              # Recipe management
└── settings/             # App settings and preferences

lib/shared/
├── core/                 # App router, theme, initialization
├── database/             # Drift SQLite v2 implementation
├── services/             # Shared services (analytics, logging, etc.)
├── theme/                # Material Design 3 theming system
└── widgets/              # Shared UI components
```

## Feature-Oriented Architecture (FOA)

Following Andrea Bizzotto's patterns, each feature is organized in four layers:

- **presentation/** – Screens, widgets, AsyncNotifier controllers with `@riverpod`
- **application/** – Services that orchestrate cross-feature logic
- **domain/** – Business entities, models, and use cases
- **data/** – Repositories, DTOs, and data sources

### Controller Pattern (Mandatory)
All controllers must follow the AsyncNotifier pattern with ContentService integration:

```dart
@riverpod
class ScreenController extends _$ScreenController {
  ContentService get _contentService => ref.read(contentServiceProvider);
  ServiceClass get _service => ref.read(serviceProvider);

  @override
  FutureOr<ScreenState> build() {
    // Load content from ContentService
    final title = _contentService.getValue(ContentKeys.screenTitle, 
        defaultValue: 'Default Title');
    return ScreenState(title: title);
  }

  Future<void> performAction() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Business logic here
      return updatedState;
    });
  }
}
```

## Database Architecture

**See [Database Documentation](../database/README.md) for comprehensive details**

### Dual Database Architecture
- **Local (Drift SQLite v2)**: 27 tables for offline-first functionality
- **Cloud (Supabase PostgreSQL)**: Mirrors local schema for backup and sync
- **Migration Strategy**: Proper Drift migrations with schema version bumps and idempotent checks
- **Rollback**: Simple - delete local DB and resync from Supabase if migration fails

### Schema Version 2 (Current)
- **Status**: Active with proper migrations
- **Migration Approach**: Idempotent with column existence checks
- **Key Changes from v1**: Consolidated preference_level, dietary_preference, and allergies columns
- **Schema Location**: `/database_schemas/v2/` (v1 preserved in `/database_schemas/v1/`)

### Current Tables (27 Total)
Core tables including:
- `user_profiles` - User biometric data and preferences
- `food_preferences` - Like/dislike food selections with user associations
- `foods` - Cached food database with nutritional information
- `app_content` - Dynamic content management
- `categories` - Food timing categories (before_run, during_run, after_run)
- `food_categories` - Many-to-many food-category relationships
- `feedback` - User feedback queue with sync status
- Plus 20 additional feature tables (activities, events, carb loading, weather, etc.)

## Authentication Strategy

**Device-Based Authentication**: No traditional user accounts
- Users identified by device ID (iOS: identifierForVendor, Android: Android ID)
- Anonymous analytics tracking until user creates profile
- Local data stored per device, synced to Supabase using device ID as user identifier

## App Initialization Pattern

Following Andrea Bizzotto's robust initialization pattern:

1. `main()` → Non-recoverable initialization (Supabase, Sentry)
2. `RootAppWidget` → MaterialApp.router with builder
3. `MaterialApp.builder` → Wraps router child with `AppStartupWidget`
4. `AppStartupWidget` → Manages startup process and navigation
5. `AppStartupService` → Initializes recoverable dependencies

**Navigation Logic**: AppStartupWidget determines initial route based on user state
- No user → Welcome screen
- Incomplete onboarding → Food preferences screen
- Complete user → Main tabs screen

## Content Management System

**Fat Backend Architecture**: Business logic and content controlled server-side

- All UI text is editable via Supabase `app_content` table
- Algorithm parameters are configurable without code changes
- JSON-based content with fallback to local defaults
- Enables A/B testing and instant updates without app releases

## Data Flow

### Read Path
Supabase → JSON (snake_case) → Drift (type-safe) → UI providers

### Write Path
**Online:**
- UI intents → Repository → Supabase → Local Drift cache update

**Offline:**
- UI intents → Drift immediately (optimistic) → Sync to Supabase later

### Sync Strategy
- **24-hour refresh cycles** for reference data (foods, content)
- **Device-based sync** using device ID as user identifier
- **Conflict resolution** using timestamps (newest-wins)
- **Automatic triggers** on app start, connectivity changes

## State Management

Riverpod v2 with `riverpod_generator` for automatic provider generation:

- **Repository providers:** Data layer access
- **Service providers:** Application layer business logic  
- **Controller providers:** AsyncNotifier with ContentService integration
- **Client providers:** External service integrations (Supabase, analytics)

**Mandatory Patterns:**
- Use `@riverpod` annotation for all providers
- AsyncNotifier controllers must integrate ContentService
- Use `AsyncValue.guard()` for consistent error handling
- Access services via `ref.read()` for proper dependency injection

## Developer Workflow

### Daily Development
1. **Database**: Drift handles local storage automatically
2. **Code Generation**: `dart run build_runner build` for Riverpod providers
3. **Development**: Standard Flutter with hot reload
4. **Content**: Update via Supabase dashboard for dynamic content

### Schema Changes
1. **Modify Drift table definitions** in `lib/shared/database/tables/`
2. **Update schema version** in `AppDatabase` class
3. **Implement migration** in `_migrateV<X>ToV<Y>()` method
4. **Run code generation** to update generated files

## Current Implementation Status

### ✅ Implemented Features
- Device-based authentication
- Drift SQLite v2 with 10 tables
- Dual database sync architecture
- Andrea Bizzotto initialization pattern
- Content management system
- AsyncNotifier controllers with ContentService
- User onboarding flow
- Nutrition plan generation
- Feedback system with surveys
- Settings and preferences management

### 🔄 In Development
- Enhanced food preferences system
- Recipe management expansion
- Advanced analytics integration

## Documentation References

- **[Database Architecture](../database/README.md)** - Complete dual database implementation
- **[Technical Implementation](../technical/README.md)** - Detailed development patterns
- **[FOA Architecture](../technical/foa-architecture.md)** - Mandatory controller patterns
- **[Business Logic](../business_logic/README.md)** - Nutrition algorithm documentation

## Future Considerations

### Architectural Improvements
- **Enhanced offline sync** with conflict resolution strategies
- **Real-time features** using Supabase realtime subscriptions
- **Advanced caching** for improved performance
- **Collaborative features** for coach/athlete plan sharing

### Migration Paths
- **PowerSync integration** for automatic offline-first sync
- **Advanced analytics** with custom event tracking
- **Multi-platform expansion** maintaining shared business logic

---

This architecture provides a solid foundation for an offline-first nutrition planning app with device-based authentication, dynamic content management, and robust data synchronization capabilities.