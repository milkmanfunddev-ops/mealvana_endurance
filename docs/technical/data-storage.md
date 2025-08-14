# Data Storage Implementation - Mealvana Endurance

## Overview

Hive-based local storage implementation for the Mealvana Endurance nutrition planning app, providing offline-first data persistence with fast access to user profiles, food preferences, nutrition plans, and feedback data. The storage layer supports the app's offline-first architecture while maintaining sync capabilities with Supabase.

## Storage Architecture

### Box Organization

The app organizes data into specific Hive boxes aligned with core features:

**User Data Boxes**: Store user profiles and authentication state locally for immediate access during app startup. Profile data includes biometrics, running habits, and onboarding completion status.

**Preference Boxes**: Cache food preferences set during onboarding to enable instant nutrition plan generation without network requests. Preferences include like/dislike/open-to-try selections for pre-run, during-run, and after-run foods.

**Plan Storage Boxes**: Store generated nutrition plans with complete macro calculations and food recommendations. Plans include distance, pace, duration, and detailed fueling schedules for offline access.

**Sync Management Boxes**: Track pending operations and sync status for each entity type. These boxes queue local changes when offline and coordinate synchronization when connectivity returns.

```dart
// lib/shared/data/hive_service.dart
class HiveService {
  static const String userProfilesBox = 'user_profiles';
  static const String foodPreferencesBox = 'food_preferences';
  static const String nutritionPlansBox = 'nutrition_plans';
  static const String feedbackBox = 'feedback';
  static const String pendingOpsPrefix = 'pending_ops_';
  static const String metaBox = 'meta';
  
  static Future<void> initialize() async {
    await Hive.initFlutter();
    
    // Open all required boxes
    await Hive.openBox<Map<String, dynamic>>(userProfilesBox);
    await Hive.openBox<Map<String, dynamic>>(foodPreferencesBox);
    await Hive.openBox<Map<String, dynamic>>(nutritionPlansBox);
    await Hive.openBox<Map<String, dynamic>>(feedbackBox);
    await Hive.openBox<Map<String, dynamic>>(metaBox);
    
    // Open sync tracking boxes
    await Hive.openBox<Map<String, dynamic>>('${pendingOpsPrefix}user_profiles');
    await Hive.openBox<Map<String, dynamic>>('${pendingOpsPrefix}food_preferences');
    await Hive.openBox<Map<String, dynamic>>('${pendingOpsPrefix}nutrition_plans');
    await Hive.openBox<Map<String, dynamic>>('${pendingOpsPrefix}feedback');
  }
}
```

### Data Modeling for Nutrition App

The storage layer maintains data models specific to endurance nutrition planning:

**User Profile Storage**: Stores complete user profiles with nested data structures for biometrics, running preferences, and onboarding progress. Data remains accessible offline for personalized plan generation.

**Food Preferences Cache**: Maintains fast lookup tables for food preferences organized by category (pre-run, during-run, after-run). Enables instant filtering during plan generation without API calls.

**Nutrition Plans Archive**: Stores complete plan history with detailed macro breakdowns and food recommendations. Each plan includes distance, duration, weather conditions, and user satisfaction feedback for pattern analysis.

## Offline-First Implementation

### Local-First Operations

All user interactions write to local storage immediately for responsive UI, with background synchronization handling remote updates:

**Profile Creation**: New user profiles save to local storage instantly and queue for backend sync. Users can immediately proceed to food preferences without waiting for network confirmation.

**Plan Generation**: Generated nutrition plans store locally first, enabling immediate viewing and sharing while background sync uploads to Supabase for cross-device access.

**Feedback Collection**: User feedback on plans and app experience saves locally and syncs when connectivity allows. No feedback is lost due to network issues.

### Sync Strategy Implementation

The storage layer implements bidirectional sync with conflict resolution:

**Push Operations**: Local changes queue in pending operations boxes and batch upload to Supabase when online. Failed operations retry with exponential backoff.

**Pull Operations**: Periodic sync fetches remote changes using timestamp-based incremental updates. Remote changes update local cache with newest-wins conflict resolution.

**Conflict Resolution**: When both local and remote data exist, the system uses `updated_at` timestamps to determine the most recent version, preserving user intent while maintaining data consistency.

```dart
// lib/shared/data/local_storage_repository.dart
abstract class LocalStorageRepository<T> {
  String get boxName;
  
  Future<T?> getById(String id) async {
    final box = Hive.box<Map<String, dynamic>>(boxName);
    final data = box.get(id);
    if (data != null) {
      return fromJson(data);
    }
    return null;
  }
  
  Future<List<T>> getAll() async {
    final box = Hive.box<Map<String, dynamic>>(boxName);
    return box.values.map((data) => fromJson(data)).toList();
  }
  
  Future<void> save(T entity) async {
    final box = Hive.box<Map<String, dynamic>>(boxName);
    final data = toJson(entity);
    data['updated_at'] = DateTime.now().toIso8601String();
    
    await box.put(getId(entity), data);
    await _queueForSync(entity, 'upsert');
  }
  
  Future<void> delete(String id) async {
    final box = Hive.box<Map<String, dynamic>>(boxName);
    final existing = box.get(id);
    
    if (existing != null) {
      existing['deleted_at'] = DateTime.now().toIso8601String();
      await box.put(id, existing);
      await _queueForSync(fromJson(existing), 'delete');
    }
  }
  
  T fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson(T entity);
  String getId(T entity);
}
```

## Performance Optimization

### Query Optimization

Storage operations are optimized for the nutrition app's specific access patterns:

**Profile Lookups**: User profiles cache with immediate access patterns for app startup and plan generation. Single-key lookups provide microsecond response times.

**Preference Filtering**: Food preferences organize by category for fast filtering during plan generation. Pre-computed preference maps eliminate iteration overhead.

**Plan History**: Recent nutrition plans cache in memory with lazy loading for older plans. Most users access only recent plans, so this pattern optimizes common operations.

### Memory Management

The storage layer manages memory efficiently for sustained app performance:

**Selective Loading**: Only active user data loads into memory, with historical data remaining on disk until accessed. This approach maintains fast startup while conserving memory.

**Cache Lifecycle**: Automatic cache eviction removes unused data based on access patterns and memory pressure. Critical user data (current profile, recent preferences) remains in memory.

**Batch Operations**: Multiple database operations batch together to reduce I/O overhead, particularly important when syncing large datasets or importing food preferences.

## Data Security Implementation

### Local Data Protection

User data protection follows security best practices for health-related applications:

**Encryption at Rest**: Sensitive user data uses AES encryption in Hive encrypted boxes. Profile data, health metrics, and personal preferences remain encrypted on device storage.

**Access Control**: Application-level access controls ensure users only access their own data. Multi-user support isolates data completely between different user accounts.

**Secure Deletion**: Data deletion operations overwrite storage locations and clear memory references to prevent data recovery attacks.

```dart
// lib/shared/data/secure_storage_service.dart
class SecureStorageService {
  static late HiveCipher _cipher;
  
  static Future<void> initialize() async {
    // Generate or retrieve encryption key
    const secureStorage = FlutterSecureStorage();
    String? encryptionKey = await secureStorage.read(key: 'hive_encryption_key');
    
    if (encryptionKey == null) {
      final key = Hive.generateSecureKey();
      encryptionKey = base64.encode(key);
      await secureStorage.write(key: 'hive_encryption_key', value: encryptionKey);
    }
    
    final key = base64.decode(encryptionKey);
    _cipher = HiveAesCipher(key);
  }
  
  static Future<Box<T>> openSecureBox<T>(String name) async {
    return await Hive.openBox<T>(name, encryptionCipher: _cipher);
  }
}
```

### Privacy Compliance

Data handling ensures compliance with privacy regulations:

**Data Minimization**: Only essential data stores locally, with optional analytics and usage data requiring explicit user consent.

**Consent Management**: User consent preferences store locally and sync with backend to ensure consistent privacy settings across devices.

**Data Export**: Users can export all local data in JSON format for portability or deletion compliance with privacy regulations.

## Maintenance and Monitoring

### Database Health Monitoring

Automated monitoring ensures storage layer reliability:

**Performance Metrics**: Track operation latency, cache hit rates, and storage utilization to identify optimization opportunities.

**Error Tracking**: Log and report storage errors, sync failures, and data corruption issues to prevent user data loss.

**Storage Analytics**: Monitor storage growth patterns and implement cleanup strategies for optimal performance.

### Maintenance Operations

Regular maintenance ensures continued performance:

**Data Cleanup**: Remove expired cache data, old nutrition plans beyond retention periods, and orphaned sync operations.

**Compaction Scheduling**: Run database compaction during app idle periods to maintain optimal performance without user impact.

**Migration Support**: Version-aware data migration handles schema changes during app updates while preserving user data integrity.

This storage implementation provides the foundation for offline-first nutrition planning while maintaining data security, performance, and synchronization capabilities essential for the Mealvana Endurance app.