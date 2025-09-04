# Mealvana Endurance App Architecture

## Overview
This document outlines the architecture for a Flutter app that generates personalized nutrition fueling plans for endurance athletes' long run days. The app prioritizes offline-first functionality with robust sync capabilities and type-safe data handling.

## Architecture Summary
- **Targets:** iOS & Android
- **Style:** Feature-oriented architecture (FOA) - Andrea Bizzotto's pattern
- **Source of truth:** Supabase (Postgres)
- **Local storage:** Drift (SQLite) with type-safe migrations
- **Auth:** Supabase Auth (Email, Apple, Google)
- **State mgmt:** Riverpod v2 (riverpod_generator / @riverpod)
- **Sync:** Periodic push/pull + newest-wins + soft deletes
- **Storage:** Supabase Storage (media)
- **Analytics & crashes:** Mixpanel + Sentry
- **Payments:** RevenueCat
- **CI/CD:** Codemagic
- **Migrations:** Supabase CLI (SQL in git)
- **RLS:** Enabled for security

## Key Requirements
- **Critical offline functionality** - App must work without internet
- **Type safety across stack** - Consistent naming between database, API, models, and cache
- **Future sharing capabilities** - Users will share nutrition plans with coaches/others
- **Complex data relationships** - User → preferences → plans → feedback

## Repository Structure
```
app/
  lib/
    features/
      auth/                    # User authentication & preferences
        application/           # AuthService for cross-feature coordination
        data/
          models/              # UserProfile, FoodPreferences + adapters
          repositories/        # UserRepository for local storage
        domain/                # (future: business entities/use cases)
        presentation/          # (future: auth-related screens if needed)
          screens/
          widgets/
          providers/
      nutrition_plan/          # Food database & nutrition calculations
        application/           # NutritionPlanService, NutritionCalculator
        data/
          models/              # FoodItem, NutritionPlan + adapters
          repositories/        # NutritionPlanRepository
          food_database.dart   # Static 12-item food database
        domain/                # (future: nutrition domain logic)
        presentation/          # Plan input/results screens
          screens/
          widgets/
          providers/
      onboarding/              # User onboarding flow
        application/           # OnboardingService for flow coordination
        data/                  # (minimal - uses auth feature data)
        domain/                # (future: onboarding business rules)
        presentation/          # Welcome, profile, food preference screens
          screens/
          widgets/
          providers/
      feedback/                # Post-plan user feedback
        application/           # FeedbackService (MVP: logging only)
        data/                  # (future: feedback storage)
        domain/                # (future: feedback analysis)
        presentation/          # Plan & app feedback screens
          screens/
          widgets/
          providers/
    shared/
      core/                    # App router, theme, initialization
      theme/                   # Material Design 3 theming system
      utils/                   # Small helpers, extensions
  supabase/                    # (future: when adding backend)
    migrations/
    config.toml
  ios/, android/, tool/, etc.
```

## Feature-oriented Architecture

### Four-Layer Architecture Pattern
The application employs Andrea Bizzotto's Feature-Oriented Architecture with clear separation across four distinct layers:

**Layer Responsibilities:**
- **Presentation Layer**: UI components and user interaction handling
- **Application Layer**: Cross-feature business logic coordination  
- **Domain Layer**: Business entities and core domain concepts
- **Data Layer**: Data access abstraction and persistence management

**Design Principle**: Dependencies flow inward only, ensuring testability and maintainability.

Everything lives under `features/<feature>/...` in four layers:

- **data/** – Models (DTOs), adapters, repositories, local & remote data sources
- **domain/** – Business entities, use cases, repository interfaces (minimal for MVP)  
- **application/** – Services that orchestrate cross-feature logic
- **presentation/** – Screens, widgets, providers; pure UI layer

### State Management Architecture
**Technology Choice**: Riverpod v2 with automatic code generation
- **Provider Pattern**: Automatic generation reduces boilerplate and improves type safety
- **Controller Pattern**: AsyncNotifier subclasses for consistent async state handling
- **Service Pattern**: Cross-feature coordination through dependency injection

## Cross-Feature Communication
Features communicate through **application layer services** that coordinate across feature boundaries while maintaining separation of concerns.

## Current MVP Features
1. **auth** - User profiles, food preferences storage
2. **nutrition_plan** - Food database, nutrition calculations, plan storage
3. **onboarding** - Welcome flow coordinating user creation and preferences  
4. **feedback** - Post-plan feedback collection

## Data Flow Architecture

### Read Path
Remote source (with security) → JSON format → data transformation → local cache → UI access via state management

### Write Path
**Online:** UI operations → Repository coordination → Remote service updates → Local cache synchronization

**Offline:** UI operations → Immediate local storage → Background synchronization queue → Remote sync when connected

### Sync Architecture
1. **Push:** Process pending operations with retry logic
2. **Pull:** Fetch incremental updates based on timestamps
3. **Conflict Resolution:** Newest-wins strategy with soft delete support
4. **Triggers:** App lifecycle events and connectivity changes

## Authentication & Security Architecture
**Identity Management:** External authentication service integration
- Primary identity from authentication provider
- Internal user identifier for data relationships
- Row-level security enforcement
- Data isolation between users

## Data Persistence Architecture

### Local Storage Strategy
**Technology Choice**: Drift (SQLite) with type-safe schema management
- **Type Safety**: Compile-time query validation prevents runtime errors
- **Schema Versioning**: Built-in migration system for data structure evolution
- **Offline Capability**: Complete offline functionality without network dependency

### Remote Storage Strategy  
**Technology Choice**: Supabase with PostgreSQL backend
- **Synchronization Design**: Periodic push/pull with conflict resolution
- **Security Model**: Row-level security for data isolation
- **Content Management**: Dynamic content updates without app releases

**Local Storage:** Structured data persistence with type safety
- Entity-based organization
- Schema versioning and migration support
- Encryption for sensitive data
- Offline-first data access

**Remote Storage:** Centralized data synchronization
- User data backup and sync
- Media asset storage
- Configuration and content management

## Content Management Architecture

### Fat Backend Strategy
**Design Decision**: Business logic and content controlled server-side
- **Dynamic Content**: All UI text editable via backend without code changes
- **Algorithm Parameters**: Nutrition calculation constants configurable remotely
- **Offline Resilience**: Local fallbacks ensure functionality without connectivity

### Content Architecture
- **Hierarchical Structure**: Nested JSON organization for logical content grouping
- **Version Control**: Content versioning for rollback and change tracking
- **Fallback Strategy**: Multi-tier fallback (remote → cache → bundled defaults)

## Performance Architecture

### Offline-First Architecture
**Design Philosophy**: App must function completely without network connectivity
- **Local Priority**: All operations work locally first, sync secondarily
- **Sync Strategy**: Background synchronization with conflict resolution
- **User Experience**: No loading states for cached data

### Resource Optimization
- **Memory Management**: Automatic provider disposal for efficient memory usage
- **Query Optimization**: Compiled queries for frequent database operations
- **Bundle Optimization**: Asset optimization and lazy loading strategies

## Error Handling Architecture

### Fault Tolerance Strategy
- **Graceful Degradation**: App continues functioning despite component failures
- **Error Recovery**: Automatic retry mechanisms for transient failures
- **User Communication**: Clear error messaging without technical details

### Data Integrity Architecture
- **Validation Strategy**: Multi-layer data validation (UI, service, repository)
- **Consistency Model**: Eventual consistency with conflict resolution
- **Backup Strategy**: Local and remote data backup for data loss prevention

## Integration Architecture

### External Service Integration
**Technology Choices:**
- **Analytics**: Mixpanel for user behavior tracking
- **Error Monitoring**: Sentry for crash reporting and performance monitoring
- **Payments**: RevenueCat for subscription management
- **Code Updates**: Shorebird for over-the-air updates

### API Architecture Strategy
- **Edge Functions**: Server-side business logic execution
- **RESTful Design**: Standard HTTP methods for data operations
- **Type Safety**: Consistent data models across client and server

## Future Architecture Considerations

### Scalability Enhancements
- **Real-time subscriptions** for entities requiring instant updates
- **Background processing** for heavy operations
- **Advanced conflict resolution** strategies
- **Collaborative features** architecture

### Migration Path
When ready to reduce synchronization complexity, consider automatic sync solutions that can replace manual sync layer while preserving UI and business logic layers.

## Success Metrics
- **Offline reliability:** App functions completely offline
- **Type safety:** Zero runtime errors from data inconsistencies
- **Sync efficiency:** Fast, reliable data synchronization
- **User experience:** Seamless online/offline transitions

---

This architecture provides a solid foundation for an offline-first nutrition planning app with clear separation of concerns and room for future enhancement.

## Source Reference

Based on: `../../architecture/README.md`