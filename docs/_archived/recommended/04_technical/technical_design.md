# Mealvana Endurance Technical Design

## Overview
This document outlines the detailed technical design for each layer of the Mealvana Endurance nutrition planning app, focusing on specific implementation patterns, data structures, and technical approaches for each architectural layer.

## Presentation Layer Technical Design

### Controller Implementation Pattern
**Technology**: AsyncNotifier with @riverpod code generation

**Controller Structure Design**:
```dart
@riverpod
class ScreenController extends _$ScreenController {
  ServiceClass get _service => ref.read(serviceProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);

  @override
  FutureOr<StateType> build() {
    // Synchronous initialization with cached content
    return initialState;
  }
}
```

**State Management Design**:
- **State Classes**: Immutable classes with copyWith methods
- **AsyncValue Handling**: Loading, data, and error states
- **Error Recovery**: Built-in retry mechanisms via AsyncValue.guard

### Widget Design Patterns
- **ConsumerWidget**: For reactive state listening
- **Listen Pattern**: Error handling via ref.listen
- **Loading States**: Consistent spinner and skeleton states
- **Error Display**: Centralized error message handling

## Application Layer Technical Design

### Service Class Design
**Business Logic Coordination**:
- Cross-feature communication through dependency injection
- Repository coordination for data operations
- Complex business rule implementation
- External API integration handling

**Service Implementation Pattern**:
```dart
@riverpod
ServiceClass serviceClass(ServiceClassRef ref) {
  final repository = ref.watch(repositoryProvider);
  return ServiceClass(repository);
}
```

### Content Management Service Design
**Dynamic Content Handling**:
- **Content Keys**: Type-safe string constants for all UI text
- **Fallback Strategy**: Remote → Cache → Bundled defaults
- **Real-time Updates**: Background content refresh without app restart
- **Localization Support**: Multi-language content management

## Domain Layer Technical Design

### Data Model Design
**Entity Structure**:
- **Immutable Classes**: All domain models use immutable design
- **Type Safety**: Strong typing for all business entities
- **Validation Rules**: Built-in business rule validation
- **Serialization**: JSON serialization support for storage

**Core Models**:
- **UserProfile**: Biometric data with validation constraints
- **FoodPreference**: Three-level preference system (like/dislike/willing_to_try)
- **NutritionPlan**: Complex nested structure with versioning
- **FeedbackData**: User satisfaction ratings with metadata

### Business Rule Design
- **Nutrition Algorithms**: ACSM-based calculation formulas
- **Preference Logic**: Food filtering and recommendation logic
- **Validation Rules**: Input validation and constraint checking
- **Safety Limits**: Algorithm safety boundaries and warnings

## Data Layer Technical Design

### Drift Database Implementation
**Table Design Structure**:
```dart
@DriftDatabase(tables: [
  Users,
  FoodPreferences, 
  NutritionPlans,
  AppContent,
  Feedback,
])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 1;
}
```

**Key Technical Features**:
- **Foreign Key Constraints**: Referential integrity enforcement
- **Automatic Timestamps**: Created/updated timestamp management
- **Index Optimization**: Strategic indexing for query performance
- **Migration System**: Step-by-step schema evolution with testing

### Repository Implementation Design
**Type-Safe Data Access**:
- **Generated Classes**: Compile-time validated queries
- **Transaction Support**: ACID compliance for data operations
- **Batch Operations**: Efficient bulk data handling
- **Stream Support**: Reactive data updates via watchSingleOrNull

**Query Optimization Techniques**:
- **Prepared Statements**: Reusable queries for frequent operations
- **Join Queries**: Complex relationship queries with type safety
- **Pagination Support**: Efficient large dataset handling
- **Connection Pooling**: SQLite WAL mode for performance

### Synchronization Design
**Offline-First Sync Strategy**:
- **Local Priority**: All writes go to local storage first
- **Background Sync**: Periodic upload/download operations
- **Conflict Resolution**: Last-write-wins with user notification
- **Retry Logic**: Exponential backoff for failed operations

**Technical Sync Details**:
- **Change Tracking**: Timestamp-based dirty flag system
- **Batch Uploads**: Efficient network usage patterns
- **Data Integrity**: Checksum validation for sync operations
- **Rollback Support**: Transaction rollback on sync failures

## Database Schema Technical Design

### Core Table Structures
**Users Table**:
- **Device-Centric**: No email required for privacy
- **Biometric Fields**: Height, weight, gender with proper types
- **Preference Tracking**: Gut training levels and bottle preferences
- **Onboarding State**: Progress tracking and app version

**Food Preferences Table**:
- **Many-to-Many Design**: User-food relationship table
- **Preference Levels**: Enum-based preference types
- **Unique Constraints**: Device-food combination uniqueness
- **Foreign Keys**: Cascading deletes for data consistency

**Nutrition Plans Table**:
- **JSONB Storage**: Flexible plan data structure
- **Versioning**: Optimistic concurrency control
- **Soft Deletes**: Historical plan preservation
- **Conflict Resolution**: Client/server timestamp comparison

### Migration Strategy Design
**Schema Evolution**:
- **Step-by-Step Migrations**: Generated migration functions
- **Data Preservation**: Safe schema changes without data loss
- **Testing Framework**: Automated migration validation
- **Rollback Support**: Safe downgrade paths when possible

**Migration Testing**:
- **Schema Verification**: Compile-time schema validation
- **Data Integrity Tests**: Pre/post migration data validation
- **Performance Testing**: Migration timing and impact measurement

## Integration Layer Technical Design

### Supabase Integration
**Edge Functions Design**:
- **Business Logic Execution**: Server-side calculation validation
- **Authentication Handling**: JWT token validation
- **Database Operations**: Direct PostgreSQL access with RLS
- **Response Formatting**: Consistent API response structure

**Real-time Features**:
- **WebSocket Connections**: Real-time data subscriptions
- **Change Notifications**: Reactive UI updates from server changes
- **Connection Management**: Automatic reconnection handling
- **Offline Queuing**: Background sync when connection restored

### External Service Integration
**Analytics Implementation**:
- **Event Tracking**: User behavior analytics via Mixpanel
- **Performance Monitoring**: App performance metrics collection
- **Privacy Compliance**: User consent and data handling
- **Batching Strategy**: Efficient event upload patterns

**Error Monitoring Design**:
- **Crash Reporting**: Automatic crash detection and reporting
- **Performance Issues**: ANR and performance issue tracking
- **User Context**: Contextual information for debugging
- **Privacy Protection**: Sensitive data filtering

## Performance Optimization Technical Design

### Memory Management
- **Provider Disposal**: Automatic cleanup of unused providers
- **Image Caching**: Efficient image loading and caching
- **Data Pagination**: Memory-efficient large dataset handling
- **Resource Cleanup**: Proper disposal of streams and listeners

### Query Performance
- **Index Strategy**: Strategic database indexing for common queries
- **Query Optimization**: Efficient SQL query patterns
- **Caching Strategy**: Multi-level caching for frequently accessed data
- **Lazy Loading**: On-demand data loading patterns

### Network Optimization
- **Request Batching**: Combining multiple API calls
- **Compression**: Response compression for large payloads
- **Caching Headers**: HTTP caching for static content
- **Connection Reuse**: HTTP connection pooling

## Security Technical Design

### Data Protection
- **Local Encryption**: SQLCipher for sensitive local data
- **Network Security**: Certificate pinning for API calls
- **Token Management**: Secure storage of authentication tokens
- **Data Anonymization**: User data privacy protection

### Access Control
- **Row-Level Security**: Database-level data isolation
- **API Authentication**: JWT-based API access control
- **Permission Model**: Feature-based permission system
- **Audit Logging**: Security event logging and monitoring

## Testing Strategy Technical Design

### Unit Testing
- **Repository Testing**: In-memory database testing
- **Service Testing**: Mock dependency injection
- **Algorithm Testing**: Calculation validation testing
- **Error Handling**: Exception and edge case testing

### Integration Testing
- **Database Migrations**: Migration testing with real data
- **API Integration**: Server communication testing
- **Sync Operations**: Offline/online sync validation
- **User Flows**: Critical path integration testing

## Deployment Technical Design

### Build Configuration
- **Environment Management**: Development/staging/production configs
- **Feature Flags**: Runtime feature toggles
- **Configuration Injection**: Build-time configuration injection
- **Asset Optimization**: Image and asset optimization

### CI/CD Pipeline
- **Automated Testing**: Full test suite execution
- **Code Quality**: Static analysis and linting
- **Build Artifacts**: Signed app bundle generation
- **Deployment Automation**: Automated store deployment

## Missing Technical Details

The following technical design details require additional source documentation:
- **Specific UI Component Design Patterns**: missing
- **Detailed Error Code System**: missing
- **Performance Benchmarking Targets**: missing
- **Specific Security Audit Requirements**: missing
- **Detailed Backup and Recovery Procedures**: missing

---

This technical design provides implementation-ready specifications for all architectural layers while maintaining separation of concerns and system reliability.

## Source References

Based on:
- `../../technical/foa-architecture.md`
- `../../technical/drift-implementation.md`
- `../../database/README.md`
- `../../technical/README.md`