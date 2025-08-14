# Mealvana Endurance App Architecture

## Overview
This document outlines the architecture for a Flutter app that generates personalized nutrition fueling plans for endurance athletes' long run days. The app prioritizes offline-first functionality with robust sync capabilities and type-safe data handling.

## Architecture Summary
- **Targets:** iOS & Android
- **Style:** Feature-oriented architecture (FOA)
- **Source of truth:** Supabase (Postgres)
- **Offline cache:** Hive
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
          models/              # UserProfile, FoodPreferences + Hive adapters
          repositories/        # UserRepository for local storage
        domain/                # (future: business entities/use cases)
        presentation/          # (future: auth-related screens if needed)
          screens/
          widgets/
          providers/
      nutrition_plan/          # Food database & nutrition calculations
        application/           # NutritionPlanService, NutritionCalculator
        data/
          models/              # FoodItem, NutritionPlan + Hive adapters
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

### Feature-oriented Architecture
Everything lives under `features/<feature>/...` in four layers:

- **data/** – Models (DTOs), Hive TypeAdapters, repositories, local & remote data sources
- **domain/** – Business entities, use cases, repository interfaces (minimal for MVP)  
- **application/** – Services that orchestrate cross-feature logic (follows Andrea Bizzotto pattern)
- **presentation/** – Screens, widgets, Riverpod providers; pure UI layer

### Cross-Feature Communication
Features communicate through **application layer services** that use `Ref` for dependency injection:

```dart
class NutritionPlanService {
  NutritionPlanService(this.ref);
  final Ref ref;

  // Access other feature services
  AuthService get _authService => ref.read(authServiceProvider);
  
  // Coordinate across features
  Future<NutritionPlan> generatePlan(distance, pace) async {
    final user = _authService.getCurrentUser(); // Cross-feature access
    return NutritionCalculator.calculatePlan(user, distance, pace);
  }
}
```

### Current MVP Features
1. **auth** - User profiles, food preferences (Hive storage)
2. **nutrition_plan** - Food database, nutrition calculations, plan storage
3. **onboarding** - Welcome flow coordinating user creation + preferences  
4. **feedback** - Post-plan feedback collection (logging for MVP)

## Naming & Type Safety
**Storage naming:** snake_case in Supabase (tables/columns) and Hive (keys in stored maps)

**Dart fields/classes:** camelCase for properties, PascalCase for types

**Entity keys:** Each table includes:
- `id` (PK)
- `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`
- `deleted_at TIMESTAMPTZ NULL` (soft delete)

**Conflict policy:** Newest-wins based on `updated_at`

**Soft delete:** server sets `deleted_at`, client mirrors it

## Authentication & Security
**Supabase Auth** for sign-in (Email, Apple, Google). The app stores:
- `supabase_user_id` – from Supabase Auth (canonical identity)
- `app_user_id` – our own user identifier (UUID) used as FK in tables

**Row Level Security (RLS)** is enabled on all tables:
- Users can only access their own data
- JWT tokens from Supabase Auth contain user context
- RLS policies enforce data isolation

## Data Flow

### Read Path
Supabase (with RLS) → JSON (snake_case) → map to DTO (camelCase) → store in Hive (as snake_case maps) → UI reads via providers

### Write Path
**Online:**
- UI intents → Repository calls Supabase with JWT → server updates row (sets `updated_at`) → write returned JSON to Hive

**Offline:**
- UI intents → write to Hive immediately (optimistic) + enqueue in `pending_ops_<entity>` → background sync pushes later

### Sync Process (Periodic)
1. **Push:** Process `pending_ops_*` queues with retry logic
2. **Pull:** Fetch rows `WHERE updated_at > last_sync_at` (per entity), upsert in Hive
3. **Newest-wins:** Compare timestamps; apply soft deletes
4. **Triggers:** App start, login, foreground/resume, connectivity regained, every X minutes

## Database Design

### Tables
Start every user table with:
```sql
id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
user_id UUID REFERENCES auth.users(id) NOT NULL,
updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
deleted_at TIMESTAMPTZ NULL
```

### RLS Policies
```sql
-- Example policy for user-owned data
CREATE POLICY "Users can manage their own data" ON table_name
FOR ALL USING (auth.uid() = user_id);
```

## Supabase Setup

### Migrations & Local Dev
```bash
# Install CLI
brew install supabase/tap/supabase

# Initialize project
supabase init

# Run local stack
supabase start

# Create migration
supabase migration new <name>

# Apply locally
supabase db push

# Link remote (once)
supabase link --project-ref <id>

# Deploy schema
supabase db push
```

## Hive Storage
**Boxes per entity:** e.g., `meals`, `plans`, `users`, plus `pending_ops_<entity>`, and a shared `meta` box for `last_sync_at` values

**Schema versioning:** `meta['app_schema_version']` guards one-time in-app migrations

**TypeAdapters:** Store `Map<String, dynamic>` to remain flexible while maintaining type safety through DTOs

**Encryption:** Enable encrypted boxes for sensitive data

## Riverpod Architecture
State management uses Riverpod v2 with `riverpod_generator` for automatic provider generation:

- **Repository providers:** Data layer access
- **Service providers:** Application layer business logic  
- **Controller providers:** Presentation layer state management
- **Client providers:** External service integrations

*For detailed implementation patterns and code examples, see the [Technical Documentation](../technical/README.md).*

## Models & Mapping
**Domain Models:** Immutable Dart classes representing business entities
- Consistent naming: camelCase in Dart, snake_case in storage/API
- Include serialization methods for data persistence
- Business logic through extensions for immutable operations

**Type Safety:** Ensures consistent data handling across the entire stack

## Environment & Secrets
- **Environment Configuration:** Compile-time configuration using `--dart-define`
- **Secret Management:** Secure handling of API keys and sensitive configuration
- **Multi-Environment Support:** Development, staging, and production configurations

*For implementation details, see the [Technical Documentation](../technical/README.md).*

## Developer Workflow

### Daily Development
1. **Start Supabase:** Local database and Studio interface
2. **Code Generation:** Run build_runner in watch mode for Riverpod providers
3. **Development:** Standard Flutter development with hot reload
4. **Testing:** Unit tests for domain logic, widget tests for UI

### Schema Changes
1. **Create Migration:** Generate new Supabase migration file
2. **Test Locally:** Apply and verify migration in local environment
3. **Deploy:** Push schema changes to remote database after testing

*For detailed commands and workflows, see the [Technical Documentation](../technical/README.md).*

## Testing Strategy
- **Unit Tests:** Domain model business logic and data transformations
- **Integration Tests:** Repository layer with database operations
- **Widget Tests:** UI components and user interactions  
- **End-to-End Tests:** Complete user flows through the application

*For specific testing patterns and examples, see the [Technical Documentation](../technical/README.md).*

## Future Considerations

### PowerSync Migration Path
When ready to eliminate manual sync complexity:
1. **PowerSync** provides automatic offline-first sync with type safety
2. Can replace manual sync layer while keeping UI and business logic
3. Handles conflict resolution, real-time updates, and connectivity automatically
4. Migration path: PowerSync → SQLite replaces Hive, sync logic becomes automatic

### Additional Enhancements
- **Real-time subscriptions** for entities needing instant updates
- **Background isolates** for heavy sync operations
- **Advanced conflict resolution** beyond newest-wins
- **Collaborative features** for coach/athlete plan sharing

## Success Metrics
- **Offline reliability:** App functions completely offline
- **Type safety:** Zero runtime errors from naming mismatches
- **Sync efficiency:** Fast, reliable data synchronization
- **User experience:** Seamless online/offline transitions

---

This architecture provides a solid foundation for an offline-first nutrition planning app with room to scale and enhance over time.