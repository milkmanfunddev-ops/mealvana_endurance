# Data Flow Architecture

## Overview

This document describes how data flows through the Mealvana Endurance system, from user interactions through local storage to backend synchronization. Understanding these flows is essential for maintaining data consistency and system reliability.

## System Components

### Local Layer (Drift SQLite)
- **Primary Storage**: User profiles, preferences, nutrition plans
- **Cache Layer**: Foods, categories, app content
- **Queue Layer**: Pending sync operations, analytics events

### Backend Layer (Supabase PostgreSQL)
- **Master Database**: Authoritative source for shared data
- **Content Management**: Dynamic UI text and algorithm parameters  
- **Analytics Storage**: User feedback and usage metrics
- **Edge Functions**: Server-side business logic

### Sync Layer
- **Background Services**: Periodic data synchronization
- **Conflict Resolution**: Handle concurrent data modifications
- **Retry Logic**: Ensure eventual consistency

## Data Flow Patterns

### 1. User Profile Management

#### Profile Creation Flow
```mermaid
graph TD
    A[User Completes Onboarding] --> B[Save to Local Drift]
    B --> C[Mark as Pending Sync]
    C --> D[Background Sync to Supabase]
    D --> E{Sync Successful?}
    E -->|Yes| F[Mark as Synced]
    E -->|No| G[Queue for Retry]
    G --> H[Exponential Backoff]
    H --> D
```

#### Profile Update Flow
```mermaid
graph TD
    A[User Updates Profile] --> B[Immediate Save to Drift]
    B --> C[Update UI Instantly]
    C --> D[Queue Sync Operation]
    D --> E[Background Sync to Supabase]
    E --> F{Conflict Detected?}
    F -->|No| G[Mark as Synced]
    F -->|Yes| H[Apply Last-Write-Wins]
    H --> G
```

### 2. Food Database Management

#### Initial Load Flow
```mermaid
graph TD
    A[App Startup] --> B[Check Local Food Cache]
    B --> C{Cache Exists & Fresh?}
    C -->|Yes| D[Use Cached Data]
    C -->|No| E[Fetch from Supabase]
    E --> F[Save to Local Cache]
    F --> G[Update Last Sync Time]
    G --> D
```

#### Periodic Refresh Flow
```mermaid
graph TD
    A[Background Timer] --> B[Check Last Sync Time]
    B --> C{> 24 Hours Old?}
    C -->|No| D[Skip Sync]
    C -->|Yes| E[Fetch Latest from Supabase]
    E --> F[Compare Versions]
    F --> G{Updates Available?}
    G -->|No| H[Update Sync Time Only]
    G -->|Yes| I[Update Local Cache]
    I --> J[Notify Components]
    J --> H
```

### 3. Nutrition Plan Generation

#### Local Plan Creation
```mermaid
graph TD
    A[User Inputs Run Parameters] --> B[Validate Input Locally]
    B --> C[Load User Preferences]
    C --> D[Load Cached Food Data]
    D --> E[Calculate Nutrition Plan]
    E --> F[Save to Local Drift]
    F --> G[Display to User]
    G --> H[Queue for Backup Sync]
```

#### AI-Enhanced Plan Creation
```mermaid
graph TD
    A[User Requests AI Plan] --> B[Check Network Connection]
    B --> C{Online?}
    C -->|No| D[Generate Basic Plan Locally]
    C -->|Yes| E[Send Request to Edge Function]
    E --> F[AI Processing on Server]
    F --> G[Enhanced Plan Returned]
    G --> H[Save to Local Drift]
    H --> I[Display Enhanced Plan]
    I --> J[Background Sync for History]
```

### 4. Content Management System

#### Content Update Flow
```mermaid
graph TD
    A[App Requests Content] --> B[Check Local Cache]
    B --> C{Cache Valid?}
    C -->|Yes| D[Return Cached Content]
    C -->|No| E[Fetch from Supabase]
    E --> F{Fetch Successful?}
    F -->|Yes| G[Update Local Cache]
    F -->|No| H[Use Fallback Defaults]
    G --> I[Return Fresh Content]
    H --> J[Return Default Content]
```

#### Content Deployment Flow
```mermaid
graph TD
    A[Content Team Updates] --> B[Save to Supabase app_content]
    B --> C[Increment Version Number]
    C --> D[Set Active Flag]
    D --> E[Apps Check for Updates]
    E --> F[Download New Content]
    F --> G[Update Local Cache]
    G --> H[Apply New Content]
```

### 5. Analytics and Feedback

#### Feedback Collection Flow
```mermaid
graph TD
    A[User Provides Feedback] --> B[Save to Local Drift]
    B --> C[Show Confirmation to User]
    C --> D[Queue for Sync]
    D --> E{Network Available?}
    E -->|Yes| F[Sync Immediately]
    E -->|No| G[Store in Sync Queue]
    F --> H[Send to Supabase]
    G --> I[Wait for Network]
    I --> F
```

#### Analytics Event Flow
```mermaid
graph TD
    A[User Action] --> B[Generate Analytics Event]
    B --> C[Add to Local Queue]
    C --> D[Batch Events]
    D --> E{Queue Size > Threshold?}
    E -->|No| F[Wait for More Events]
    E -->|Yes| G[Send Batch to Analytics]
    F --> D
    G --> H[Clear Sent Events]
```

## Sync Coordination

### Startup Sync Sequence
```dart
// In AppStartupService
async initializeApp() {
  1. Initialize Drift database
  2. Run schema migrations if needed
  3. Load cached user profile
  4. Check and refresh content (if stale)
  5. Check and refresh food data (if stale)
  6. Initialize analytics with device context
  7. Start background sync services
}
```

### Background Sync Coordination
```dart
class SyncCoordinator {
  Timer? _syncTimer;
  
  void startPeriodicSync() {
    _syncTimer = Timer.periodic(Duration(hours: 24), (_) async {
      await syncContent();
      await syncFoodDatabase();
      await syncPendingUserData();
    });
  }
}
```

### Network State Management
```dart
class NetworkStateManager {
  void onNetworkAvailable() {
    // Immediately sync high-priority data
    syncPendingFeedback();
    syncPendingPlans();
    
    // Schedule content refresh
    scheduleLowPrioritySync();
  }
  
  void onNetworkUnavailable() {
    // Cancel pending sync operations
    cancelPendingSync();
    
    // Switch to offline mode
    enableOfflineMode();
  }
}
```

## Error Handling Patterns

### Sync Failure Recovery
```dart
class SyncErrorHandler {
  static const maxRetries = 3;
  static const baseDelay = Duration(seconds: 5);
  
  Future<void> handleSyncError(SyncOperation op, Exception error) async {
    if (op.retryCount < maxRetries) {
      // Exponential backoff
      final delay = baseDelay * pow(2, op.retryCount);
      await Future.delayed(delay);
      
      // Retry operation
      op.retryCount++;
      await retrySync(op);
    } else {
      // Max retries reached - log and continue
      logger.error('Sync failed permanently', error: error);
      await markSyncAsFailed(op);
    }
  }
}
```

### Data Consistency Checks
```dart
class DataConsistencyChecker {
  Future<void> validateDataIntegrity() async {
    // Check for orphaned records
    await removeOrphanedFoodPreferences();
    
    // Validate foreign key relationships
    await validatePlanUserReferences();
    
    // Check for data corruption
    await verifyNutritionPlanIntegrity();
  }
}
```

## Performance Optimizations

### Batch Operations
```dart
// Batch multiple operations for efficiency
await database.batch((batch) {
  for (final food in foods) {
    batch.insert(foodsTable, food);
  }
  for (final category in categories) {
    batch.insert(categoriesTable, category);
  }
});
```

### Connection Pooling
```dart
// Single database instance shared across app
class DatabaseProvider {
  static AppDatabase? _instance;
  
  static AppDatabase get instance {
    return _instance ??= AppDatabase();
  }
}
```

### Index Optimization
```sql
-- Optimize common queries
CREATE INDEX idx_nutrition_plans_user_date 
ON nutrition_plans(user_id, created_at DESC);

CREATE INDEX idx_food_preferences_user_food 
ON food_preferences(user_id, food_name);

CREATE INDEX idx_foods_category 
ON food_categories(category_id);
```

## Monitoring and Observability

### Sync Metrics
```dart
class SyncMetrics {
  static void trackSyncOperation(String operation, Duration duration, bool success) {
    analytics.track('sync_operation', {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'success': success,
    });
  }
}
```

### Data Quality Checks
```dart
class DataQualityMonitor {
  Future<void> checkDataQuality() async {
    final stats = await database.getDatabaseStats();
    
    // Alert if data seems corrupted
    if (stats.totalUsers > 0 && stats.totalPreferences == 0) {
      await reportDataInconsistency('missing_preferences');
    }
    
    // Track database growth
    analytics.track('database_stats', stats);
  }
}
```

## Testing Data Flows

### Unit Tests
```dart
test('user profile sync flow', () async {
  // Setup
  final user = createTestUser();
  await database.saveUserProfile(user);
  
  // Test sync
  await syncService.syncUserProfile(user.id);
  
  // Verify
  final syncedUser = await supabase.getUserProfile(user.id);
  expect(syncedUser, equals(user));
});
```

### Integration Tests
```dart
testWidgets('offline plan creation flow', (tester) async {
  // Setup offline environment
  mockNetworkService.setOffline();
  
  // Create plan
  await tester.enterText(find.byKey('distance'), '10');
  await tester.tap(find.text('Generate Plan'));
  await tester.pumpAndSettle();
  
  // Verify plan created locally
  final localPlans = await database.getAllNutritionPlans();
  expect(localPlans, hasLength(1));
});
```

## Data Flow Best Practices

### 1. Always Write Local First
- User actions immediately update local storage
- Background sync handles server updates
- Never block UI on network operations

### 2. Graceful Degradation
- App works fully when offline
- Network features degrade gracefully
- Clear user communication about feature availability

### 3. Eventual Consistency
- Accept that remote sync may be delayed
- Design UI to handle temporary inconsistencies
- Provide manual refresh options when needed

### 4. Data Validation
- Validate data at multiple layers
- Handle server validation errors gracefully
- Preserve user input even if sync fails

### 5. Error Recovery
- Implement robust retry mechanisms
- Provide clear error messages to users
- Maintain data integrity during failures

This data flow architecture ensures reliable, performant data management while providing an excellent user experience both online and offline.