# Offline-First Architecture

## Overview

Mealvana Endurance implements an offline-first architecture where the local Drift database serves as the primary data store, with Supabase providing backend sync and additional functionality. This ensures the app remains fully functional without an internet connection.

## Core Principles

### 1. Local-First Design
- **Primary Storage**: All user data is stored locally in Drift SQLite database
- **Immediate Response**: All user interactions work instantly without network calls
- **Background Sync**: Data synchronizes with Supabase when online
- **Graceful Degradation**: Missing network features degrade gracefully

### 2. Data Ownership
- **User Data**: Stored locally first, synced to cloud as backup
- **App Content**: Cached locally with periodic refresh from server
- **Food Database**: Cached locally with 24-hour refresh cycle
- **Analytics**: Queued locally, transmitted when online

## Architecture Components

### Local Storage (Drift)
```
UserProfiles     → User biometric data and preferences
FoodPreferences  → Like/dislike/willing-to-try preferences  
NutritionPlans   → Generated nutrition plans with full history
MacroTargets     → Custom macro adjustments
Feedback         → User satisfaction data (queued for sync)
Foods           → Complete food database (cached from Supabase)
Categories      → Food timing categories (before/during/after)
FoodCategories  → Many-to-many food-category relationships
Brands          → Brand information for affiliate features
AppContent      → Dynamic UI text and algorithm parameters
```

### Remote Storage (Supabase)
```
users           → Device-based user profiles (sync from local)
nutrition_plans → Plan backup and cross-device sync
feedback        → Analytics and improvement data
app_content     → Content management system
foods          → Master food database with images/affiliate links
brands         → Brand partnerships and affiliate programs
edge_functions → Dynamic server-side code deployment
```

## Data Flow Patterns

### 1. Write-Through Cache
```
User Action → Local Drift Write → Background Supabase Sync
```
- User changes are immediately saved locally
- Background service syncs to Supabase when online
- No waiting for network requests

### 2. Read-Through Cache
```
App Request → Check Local → Fetch Remote if Stale → Update Local
```
- App always reads from local database first
- Stale data (>24h) triggers background refresh
- Fresh data served from cache

### 3. Event-Driven Sync
```
Network Available → Trigger Sync Service → Upload Pending Changes
```
- Network connectivity changes trigger sync attempts
- Failed syncs are retried with exponential backoff
- Conflict resolution uses "last write wins" strategy

## Offline Capabilities

### ✅ Fully Offline Features
- **Profile Management**: Create/update user profiles and preferences
- **Nutrition Planning**: Generate plans using cached food data
- **Plan History**: View all previously generated plans
- **Food Selection**: Browse and select from cached food database
- **Macro Adjustments**: Customize nutrition targets
- **Feedback Collection**: Submit plan ratings (queued for sync)

### ⚠️ Requires Network Features  
- **Food Database Updates**: New foods and updated nutrition info
- **Content Updates**: Latest UI text and algorithm parameters
- **AI-Enhanced Planning**: Advanced nutrition plan generation
- **Cross-Device Sync**: Access data from multiple devices
- **Analytics**: Usage tracking and performance metrics

### 🔄 Hybrid Features
- **Plan Generation**: Basic plans work offline, AI features require network
- **Food Images**: Cached images display offline, new images require network
- **Content**: Cached text works offline, latest updates require network

## Sync Strategies

### Content Sync (24-Hour Cycle)
```dart
class ContentSyncService {
  static const Duration SYNC_INTERVAL = Duration(hours: 24);
  
  Future<void> syncIfNeeded() async {
    final lastSync = await getLastContentSync();
    if (DateTime.now().difference(lastSync) > SYNC_INTERVAL) {
      await syncAppContent();
    }
  }
}
```

### Food Database Sync (24-Hour Cycle)
```dart
class FoodSyncService {
  static const Duration SYNC_INTERVAL = Duration(hours: 24);
  
  Future<void> syncIfNeeded() async {
    final lastSync = await getLastFoodSync();
    if (DateTime.now().difference(lastSync) > SYNC_INTERVAL) {
      await syncFoodDatabase();
    }
  }
}
```

### User Data Sync (Real-time)
```dart
class UserDataSyncService {
  Future<void> syncPendingChanges() async {
    final pendingPlans = await getPendingNutritionPlans();
    final pendingFeedback = await getPendingFeedback();
    
    await Future.wait([
      syncNutritionPlans(pendingPlans),
      syncFeedback(pendingFeedback),
    ]);
  }
}
```

## Conflict Resolution

### Last Write Wins
- Simple strategy for user preference data
- Conflicts are rare due to single-device usage pattern
- Server timestamp determines winner in edge cases

### Versioned Plans
- Nutrition plans include version numbers
- Multiple versions can coexist
- User can choose which version to keep

### Append-Only Logs
- Feedback data is append-only
- No conflicts possible
- All feedback preserved for analytics

## Performance Optimizations

### Database Indexing
```sql
-- User lookups
CREATE INDEX idx_user_profiles_device_id ON user_profiles(id);

-- Food searches
CREATE INDEX idx_foods_category ON food_categories(category_id);
CREATE INDEX idx_foods_name ON foods(name);

-- Plan history
CREATE INDEX idx_nutrition_plans_created ON nutrition_plans(created_at DESC);
```

### Lazy Loading
- Food images loaded on demand
- Plan details loaded when accessed
- Background sync doesn't block UI

### Connection Pooling
```dart
// Single database connection shared across app
final database = AppDatabase();

// Connection pooling handled by Drift automatically
await database.transaction(() async {
  // Multiple operations in single transaction
});
```

## Error Handling

### Network Failures
```dart
try {
  await syncToSupabase();
} catch (e) {
  // Queue for retry
  await queueForRetry(operation);
  
  // Continue with cached data
  return getCachedData();
}
```

### Database Corruption
```dart
// Automatic recovery from backup
if (await isDatabaseCorrupt()) {
  await restoreFromBackup();
  await resyncFromServer();
}
```

### Sync Conflicts
```dart
// Resolve conflicts with user input when needed
if (conflict.requiresUserDecision) {
  final userChoice = await showConflictDialog();
  await resolveConflict(conflict, userChoice);
}
```

## Testing Offline Mode

### Manual Testing
1. **Airplane Mode**: Enable airplane mode and verify all core features work
2. **Slow Network**: Throttle network to test sync behavior
3. **Network Interruption**: Disconnect during sync operations

### Automated Testing
```dart
testWidgets('app works in offline mode', (tester) async {
  // Mock network as unavailable
  mockNetwork.setOffline();
  
  // Verify core features work
  await tester.pumpWidget(app);
  expect(find.text('Create Plan'), findsOneWidget);
  
  // Tap create plan button
  await tester.tap(find.text('Create Plan'));
  await tester.pumpAndSettle();
  
  // Verify plan generated without network
  expect(find.textContaining('Before Run'), findsOneWidget);
});
```

## Best Practices

### 1. Graceful Degradation
- Always provide local fallbacks
- Show appropriate messaging for network features
- Don't block UI on network requests

### 2. Background Operations
- Sync operations run in background
- User is never blocked waiting for sync
- Progress indicators for long operations

### 3. Data Validation
- Validate data locally before syncing
- Handle server validation errors gracefully
- Preserve user data even if sync fails

### 4. Storage Management
- Regular cleanup of old cached data
- Efficient image caching with size limits
- Database vacuum operations for performance

## Future Enhancements

### Smart Sync
- Sync only changed data, not entire datasets
- Delta sync for food database updates
- Intelligent retry strategies

### Cross-Device Sync
- Real-time sync between user devices
- Conflict resolution for simultaneous edits
- Push notifications for data changes

### Advanced Caching
- Predictive caching based on user patterns
- Intelligent cache eviction policies
- Background pre-loading of likely-needed data

The offline-first architecture ensures Mealvana Endurance provides a fast, reliable experience regardless of network conditions, while still enabling enhanced features when connectivity is available.