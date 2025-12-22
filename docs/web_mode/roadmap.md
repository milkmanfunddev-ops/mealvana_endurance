# Flutter Web Deployment - Implementation Roadmap

## Overview

**SELECTED APPROACH: Web Repositories + In-Memory Cache (Simplified)**

This roadmap outlines the **2-week implementation plan** for deploying Mealvana Endurance as a web application using the simplest possible architecture: web-specific repositories calling Supabase directly with optional in-memory caching.

**Timeline:** 2 weeks (10 developer days)
**Current Phase:** Pre-Planning
**Key Principle:** Simplest possible implementation - zero changes to controllers, services, or UI

**Philosophy:** Start with the minimal viable architecture. Add IndexedDB persistence only if users report that page refresh is disruptive.

---

## Decision Context

### Why This Simplified Approach?

After further analysis, we realized that **Option C was still too complex**. The simplest path forward is:

**Selected: Web Repositories + In-Memory Cache**
- **Zero changes** to controllers, services, or UI code
- **New files only**: Web-specific repository implementations
- **Optional caching**: In-memory only (no IndexedDB for MVP)
- **Defer complexity**: Move IndexedDB to Phase 2 if needed

| Factor | Option A (Supabase-Only) | Option B (drift_web) | **Simplified Web Repos** ✅ |
|--------|-------------------------|---------------------|------------------------|
| Performance | ⚠️ 200-500ms reads | ⚠️ 50ms reads | ✅ 200-500ms (cache: <10ms) |
| Bundle Size | ✅ +0MB | ❌ +3-4MB | ✅ +0MB |
| Complexity | ⚠️ Medium | ❌ High (2K+ sync code) | ✅ Minimal (~500 lines) |
| Offline Mode | ❌ None | ✅ Full | ❌ None (can add later) |
| Implementation | 8-12 weeks | 12-18 weeks | **2 weeks** |

### Architecture Decision

**Current Mobile Architecture:**
```
Flutter App → Drift SQLite (local) ⟷ Supabase (sync) → PostgreSQL
                ↓
        2,000+ lines of sync code
```

**New Web Architecture (Simplified):**
```
MOBILE (Unchanged):
┌──────────────┐
│ Controllers  │ (No changes)
└──────┬───────┘
       ↓
┌──────────────┐
│ Repositories │ (Drift-based)
└──────┬───────┘
       ↓
┌──────────────┐
│ Drift SQLite │ → Background sync to Supabase
└──────────────┘

WEB (New Files Only):
┌──────────────┐
│ Controllers  │ (SAME controllers - zero changes)
└──────┬───────┘
       ↓
┌──────────────┐
│ Web Repos    │ (New *_repository_web.dart files)
└──────┬───────┘
       ↓
┌──────────────┐
│ In-Memory    │ → Supabase REST API
│ Cache        │    (Direct calls)
└──────────────┘
```

**Key Insight:** Controllers work on both platforms unchanged because repositories implement the same interface. Web repositories are just new files that call Supabase directly.

---

## Phase 1: Core Cache Layer (Week 1)

### Objective
Implement basic IndexedDB caching for the three most-accessed data types: foods, content, and user profile.

### Prerequisites

```bash
# Add IndexedDB dependency
flutter pub add idb_shim

# Verify web support
flutter config --enable-web
flutter devices  # Should show "Chrome"
```

### 1.1 Create WebCacheService (Days 1-2)

**Goal:** Build foundation caching service with TTL support.

**File:** `lib/shared/services/web_cache_service.dart`

```dart
import 'package:idb_shim/idb.dart';
import 'package:idb_shim/idb_browser.dart';

class WebCacheService {
  static const String _dbName = 'mealvana_cache';
  static const int _version = 1;

  Database? _db;

  // Store names
  static const String foodsStore = 'foods';
  static const String contentStore = 'content';
  static const String userStore = 'user';
  static const String metadataStore = 'metadata';

  Future<void> initialize() async {
    final factory = getIdbFactory()!;

    _db = await factory.open(_dbName, version: _version,
      onUpgradeNeeded: (VersionChangeEvent event) {
        final db = event.database;

        // Create object stores
        db.createObjectStore(foodsStore, keyPath: 'id');
        db.createObjectStore(contentStore, keyPath: 'key');
        db.createObjectStore(userStore, keyPath: 'id');
        db.createObjectStore(metadataStore, keyPath: 'key');
      },
    );
  }

  Future<CachedData<T>?> get<T>(
    String storeName,
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final txn = _db!.transaction(storeName, idbModeReadOnly);
    final store = txn.objectStore(storeName);

    final result = await store.getObject(key);
    if (result == null) return null;

    final data = result as Map<String, dynamic>;
    final cachedAt = DateTime.parse(data['cachedAt'] as String);
    final ttlSeconds = data['ttl'] as int;

    return CachedData<T>(
      data: fromJson(data['data'] as Map<String, dynamic>),
      cachedAt: cachedAt,
      ttl: Duration(seconds: ttlSeconds),
    );
  }

  Future<void> set<T>(
    String storeName,
    String key,
    T data,
    Map<String, dynamic> Function(T) toJson,
    Duration ttl,
  ) async {
    final txn = _db!.transaction(storeName, idbModeReadWrite);
    final store = txn.objectStore(storeName);

    final cacheEntry = {
      'id': key,
      'key': key,
      'data': toJson(data),
      'cachedAt': DateTime.now().toIso8601String(),
      'ttl': ttl.inSeconds,
    };

    await store.put(cacheEntry);
    await txn.completed;
  }

  Future<void> clear(String storeName) async {
    final txn = _db!.transaction(storeName, idbModeReadWrite);
    final store = txn.objectStore(storeName);
    await store.clear();
    await txn.completed;
  }

  Future<void> clearAll() async {
    await clear(foodsStore);
    await clear(contentStore);
    await clear(userStore);
    await clear(metadataStore);
  }
}

class CachedData<T> {
  final T data;
  final DateTime cachedAt;
  final Duration ttl;

  CachedData({
    required this.data,
    required this.cachedAt,
    required this.ttl,
  });

  bool get isExpired {
    return DateTime.now().difference(cachedAt) > ttl;
  }

  bool get isStale {
    // Consider stale if 70% of TTL has elapsed
    final staleThreshold = ttl * 0.7;
    return DateTime.now().difference(cachedAt) > staleThreshold;
  }

  Duration get remainingTtl {
    final elapsed = DateTime.now().difference(cachedAt);
    return ttl - elapsed;
  }
}
```

**Provider:**

```dart
// lib/shared/providers/web_cache_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../services/web_cache_service.dart';

part 'web_cache_provider.g.dart';

@riverpod
WebCacheService webCacheService(WebCacheServiceRef ref) {
  final service = WebCacheService();
  // Initialize asynchronously
  service.initialize();
  return service;
}
```

### 1.2 Cache Foods Database (Days 2-3)

**Goal:** Cache the foods database (1000+ items, 50KB, most-read data).

**File:** `lib/features/foods/data/cached_foods_repository.dart`

```dart
import 'package:flutter/foundation.dart' show kIsWeb;
import '../domain/food.dart';
import '../../../shared/services/web_cache_service.dart';
import '../../../shared/providers/supabase_provider.dart';

class CachedFoodsRepository implements FoodsRepository {
  CachedFoodsRepository(this._supabase, this._cache);

  final SupabaseClient _supabase;
  final WebCacheService? _cache;

  static const _cacheKey = 'all_foods';
  static const _cacheTtl = Duration(days: 7);  // Foods rarely change

  @override
  Future<List<Food>> getAllFoods() async {
    if (!kIsWeb || _cache == null) {
      return await _fetchFromSupabase();
    }

    // Try cache first
    final cached = await _cache!.get<List<Food>>(
      WebCacheService.foodsStore,
      _cacheKey,
      (json) => (json['items'] as List)
          .map((item) => Food.fromJson(item as Map<String, dynamic>))
          .toList(),
    );

    if (cached != null && !cached.isExpired) {
      // Return cached data immediately
      final foods = cached.data;

      // Refresh in background if stale
      if (cached.isStale) {
        _refreshInBackground();
      }

      return foods;
    }

    // Cache miss or expired - fetch fresh data
    return await _fetchAndCache();
  }

  Future<List<Food>> _fetchFromSupabase() async {
    final response = await _supabase
        .from('foods')
        .select()
        .eq('is_deleted', false)
        .order('name');

    return (response as List)
        .map((json) => Food.fromJson(json))
        .toList();
  }

  Future<List<Food>> _fetchAndCache() async {
    final foods = await _fetchFromSupabase();

    if (kIsWeb && _cache != null) {
      await _cache!.set<List<Food>>(
        WebCacheService.foodsStore,
        _cacheKey,
        foods,
        (foodsList) => {
          'items': foodsList.map((f) => f.toJson()).toList(),
        },
        _cacheTtl,
      );
    }

    return foods;
  }

  void _refreshInBackground() {
    // Fire and forget background refresh
    _fetchAndCache().catchError((error) {
      print('Background foods refresh failed: $error');
    });
  }

  @override
  Future<void> invalidateCache() async {
    if (kIsWeb && _cache != null) {
      await _cache!.clear(WebCacheService.foodsStore);
    }
  }
}
```

### 1.3 Cache Content/UI Text (Day 3)

**Goal:** Cache app content (10KB, frequently accessed).

**File:** `lib/features/content/data/cached_content_repository.dart`

```dart
class CachedContentRepository implements ContentRepository {
  CachedContentRepository(this._supabase, this._cache);

  final SupabaseClient _supabase;
  final WebCacheService? _cache;

  static const _cacheKey = 'app_content';
  static const _cacheTtl = Duration(days: 1);  // Content updates daily

  @override
  Future<AppContent> getContent() async {
    if (!kIsWeb || _cache == null) {
      return await _fetchFromSupabase();
    }

    final cached = await _cache!.get<AppContent>(
      WebCacheService.contentStore,
      _cacheKey,
      (json) => AppContent.fromJson(json),
    );

    if (cached != null && !cached.isExpired) {
      if (cached.isStale) {
        _refreshInBackground();
      }
      return cached.data;
    }

    return await _fetchAndCache();
  }

  Future<AppContent> _fetchFromSupabase() async {
    final response = await _supabase
        .from('app_content')
        .select()
        .single();

    return AppContent.fromJson(response);
  }

  Future<AppContent> _fetchAndCache() async {
    final content = await _fetchFromSupabase();

    if (kIsWeb && _cache != null) {
      await _cache!.set<AppContent>(
        WebCacheService.contentStore,
        _cacheKey,
        content,
        (c) => c.toJson(),
        _cacheTtl,
      );
    }

    return content;
  }

  void _refreshInBackground() {
    _fetchAndCache().catchError((error) {
      print('Background content refresh failed: $error');
    });
  }
}
```

### 1.4 Cache User Profile (Day 4)

**Goal:** Cache user profile (2KB, session-scoped).

**File:** `lib/features/auth/data/cached_user_profile_repository.dart`

```dart
class CachedUserProfileRepository implements UserProfileRepository {
  CachedUserProfileRepository(this._supabase, this._cache);

  final SupabaseClient _supabase;
  final WebCacheService? _cache;

  static const _cacheTtl = Duration(days: 1);

  @override
  Future<UserProfile?> getByDeviceId(String deviceId) async {
    if (!kIsWeb || _cache == null) {
      return await _fetchFromSupabase(deviceId);
    }

    final cacheKey = 'user_$deviceId';
    final cached = await _cache!.get<UserProfile>(
      WebCacheService.userStore,
      cacheKey,
      (json) => UserProfile.fromJson(json),
    );

    if (cached != null && !cached.isExpired) {
      if (cached.isStale) {
        _refreshInBackground(deviceId);
      }
      return cached.data;
    }

    return await _fetchAndCache(deviceId);
  }

  @override
  Future<void> upsert(UserProfile profile) async {
    // Always write to Supabase immediately
    await _supabase
        .from('user_profiles')
        .upsert(profile.toJson());

    // Update cache
    if (kIsWeb && _cache != null) {
      final cacheKey = 'user_${profile.deviceId}';
      await _cache!.set<UserProfile>(
        WebCacheService.userStore,
        cacheKey,
        profile,
        (p) => p.toJson(),
        _cacheTtl,
      );
    }
  }

  Future<UserProfile?> _fetchFromSupabase(String deviceId) async {
    final response = await _supabase
        .from('user_profiles')
        .select()
        .eq('device_id', deviceId)
        .maybeSingle();

    return response != null ? UserProfile.fromJson(response) : null;
  }

  Future<UserProfile?> _fetchAndCache(String deviceId) async {
    final profile = await _fetchFromSupabase(deviceId);

    if (profile != null && kIsWeb && _cache != null) {
      final cacheKey = 'user_$deviceId';
      await _cache!.set<UserProfile>(
        WebCacheService.userStore,
        cacheKey,
        profile,
        (p) => p.toJson(),
        _cacheTtl,
      );
    }

    return profile;
  }

  void _refreshInBackground(String deviceId) {
    _fetchAndCache(deviceId).catchError((error) {
      print('Background user profile refresh failed: $error');
    });
  }
}
```

### 1.5 Testing (Day 5)

**Test Plan:**

```dart
// test/web/cache_service_test.dart
void main() {
  group('WebCacheService', () {
    late WebCacheService cache;

    setUp(() async {
      cache = WebCacheService();
      await cache.initialize();
    });

    tearDown(() async {
      await cache.clearAll();
    });

    test('caches and retrieves data', () async {
      final testData = {'id': '1', 'name': 'Banana'};

      await cache.set(
        WebCacheService.foodsStore,
        'test_food',
        testData,
        (data) => data,
        Duration(hours: 1),
      );

      final cached = await cache.get(
        WebCacheService.foodsStore,
        'test_food',
        (json) => json,
      );

      expect(cached, isNotNull);
      expect(cached!.data['name'], 'Banana');
      expect(cached.isExpired, false);
    });

    test('detects expired cache', () async {
      final testData = {'id': '2', 'name': 'Apple'};

      await cache.set(
        WebCacheService.foodsStore,
        'test_expired',
        testData,
        (data) => data,
        Duration(milliseconds: 100),
      );

      // Wait for expiration
      await Future.delayed(Duration(milliseconds: 150));

      final cached = await cache.get(
        WebCacheService.foodsStore,
        'test_expired',
        (json) => json,
      );

      expect(cached!.isExpired, true);
    });

    test('detects stale cache', () async {
      final testData = {'id': '3', 'name': 'Orange'};

      await cache.set(
        WebCacheService.foodsStore,
        'test_stale',
        testData,
        (data) => data,
        Duration(seconds: 1),
      );

      // Wait for 70% of TTL (stale threshold)
      await Future.delayed(Duration(milliseconds: 750));

      final cached = await cache.get(
        WebCacheService.foodsStore,
        'test_stale',
        (json) => json,
      );

      expect(cached!.isExpired, false);
      expect(cached.isStale, true);
    });
  });
}
```

**Success Criteria:**
- ✅ WebCacheService initializes on web
- ✅ Foods database caches and retrieves correctly
- ✅ Content caches with 1-day TTL
- ✅ User profile caches and invalidates on write
- ✅ All tests pass
- ✅ **Result: 80% of reads are instant (<10ms)**

---

## Phase 2: Smart Invalidation (Week 2)

### Objective
Implement intelligent cache invalidation with stale-while-revalidate pattern.

### 2.1 Implement Cache Metadata (Days 6-7)

**Goal:** Track cache freshness and trigger background refreshes.

**File:** `lib/shared/services/cache_metadata_service.dart`

```dart
class CacheMetadataService {
  CacheMetadataService(this._cache);
  final WebCacheService _cache;

  Future<void> recordAccess(String storeName, String key) async {
    final metadata = {
      'id': '${storeName}_$key',
      'key': '${storeName}_$key',
      'lastAccess': DateTime.now().toIso8601String(),
      'accessCount': await _incrementAccessCount(storeName, key),
    };

    await _cache.set(
      WebCacheService.metadataStore,
      '${storeName}_$key',
      metadata,
      (m) => m,
      Duration(days: 30),
    );
  }

  Future<int> _incrementAccessCount(String storeName, String key) async {
    final existing = await _cache.get(
      WebCacheService.metadataStore,
      '${storeName}_$key',
      (json) => json,
    );

    return existing != null ? (existing.data['accessCount'] as int) + 1 : 1;
  }

  Future<List<String>> getMostAccessedKeys(String storeName) async {
    // Used to prioritize which caches to keep fresh
    // Implementation omitted for brevity
    return [];
  }
}
```

### 2.2 Background Sync Service (Days 7-8)

**Goal:** Automatically refresh stale caches in the background.

**File:** `lib/shared/services/background_sync_service.dart`

```dart
class BackgroundSyncService {
  BackgroundSyncService(this._cache, this._repositories);

  final WebCacheService _cache;
  final Map<String, Future<void> Function()> _repositories;

  Timer? _syncTimer;

  void start() {
    // Check for stale caches every 5 minutes
    _syncTimer = Timer.periodic(Duration(minutes: 5), (_) {
      _syncStaleCaches();
    });
  }

  void stop() {
    _syncTimer?.cancel();
  }

  Future<void> _syncStaleCaches() async {
    // Check each store for stale entries
    await _checkAndSyncStore(
      WebCacheService.foodsStore,
      'all_foods',
      _repositories['foods']!,
    );

    await _checkAndSyncStore(
      WebCacheService.contentStore,
      'app_content',
      _repositories['content']!,
    );
  }

  Future<void> _checkAndSyncStore(
    String storeName,
    String key,
    Future<void> Function() refreshFn,
  ) async {
    final cached = await _cache.get(
      storeName,
      key,
      (json) => json,
    );

    if (cached != null && cached.isStale && !cached.isExpired) {
      print('Background refreshing $storeName:$key');
      await refreshFn();
    }
  }
}
```

### 2.3 User Action Invalidation (Day 9)

**Goal:** Invalidate caches when user performs relevant actions.

**Example: Updating Food Preferences**

```dart
class FoodPreferencesService {
  Future<void> updatePreferences(List<String> likedFoods) async {
    // Save to Supabase
    await _repository.updatePreferences(likedFoods);

    // Invalidate user cache
    await _userRepository.invalidateCache();

    // Invalidate foods cache (affects recommendations)
    await _foodsRepository.invalidateCache();
  }
}
```

### 2.4 Network Reconnect Handler (Day 10)

**Goal:** Sync when network comes back online.

**File:** `lib/shared/services/network_sync_service.dart`

```dart
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkSyncService {
  NetworkSyncService(this._backgroundSync);
  final BackgroundSyncService _backgroundSync;

  StreamSubscription<ConnectivityResult>? _subscription;

  void start() {
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen(_handleConnectivityChange);
  }

  void stop() {
    _subscription?.cancel();
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    if (result != ConnectivityResult.none) {
      print('Network reconnected - syncing caches');
      _backgroundSync._syncStaleCaches();
    }
  }
}
```

**Success Criteria:**
- ✅ Stale caches refresh in background
- ✅ User actions invalidate relevant caches
- ✅ Network reconnect triggers sync
- ✅ No blocking UI during background sync

---

## Phase 3: Optimistic Writes (Week 3)

### Objective
Implement write queue with background upload and retry logic.

### 3.1 Write Queue Implementation (Days 11-12)

**Goal:** Queue writes for background upload to Supabase.

**File:** `lib/shared/services/write_queue_service.dart`

```dart
class WriteQueueService {
  WriteQueueService(this._cache, this._supabase);

  final WebCacheService _cache;
  final SupabaseClient _supabase;

  static const _queueStore = 'write_queue';

  Future<void> enqueue(WriteOperation operation) async {
    final entry = {
      'id': operation.id,
      'key': operation.id,
      'table': operation.table,
      'action': operation.action.name,
      'data': operation.data,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
    };

    await _cache.set(
      _queueStore,
      operation.id,
      entry,
      (e) => e,
      Duration(days: 7),
    );

    // Try to process immediately
    _processQueue();
  }

  Future<void> _processQueue() async {
    // Get all pending writes
    final pending = await _getPendingWrites();

    for (final write in pending) {
      try {
        await _executeWrite(write);
        await _removeFromQueue(write['id'] as String);
      } catch (e) {
        await _incrementRetryCount(write);
        print('Write failed, will retry: $e');
      }
    }
  }

  Future<void> _executeWrite(Map<String, dynamic> write) async {
    final table = write['table'] as String;
    final action = WriteAction.values.byName(write['action'] as String);
    final data = write['data'] as Map<String, dynamic>;

    switch (action) {
      case WriteAction.insert:
        await _supabase.from(table).insert(data);
        break;
      case WriteAction.update:
        await _supabase.from(table).update(data).eq('id', data['id']);
        break;
      case WriteAction.delete:
        await _supabase.from(table).delete().eq('id', data['id']);
        break;
    }
  }

  Future<List<Map<String, dynamic>>> _getPendingWrites() async {
    // Query IndexedDB for pending writes
    // Implementation omitted for brevity
    return [];
  }

  Future<void> _removeFromQueue(String id) async {
    // Remove from IndexedDB
  }

  Future<void> _incrementRetryCount(Map<String, dynamic> write) async {
    final retryCount = (write['retryCount'] as int) + 1;

    if (retryCount > 5) {
      print('Write failed after 5 retries, giving up');
      await _removeFromQueue(write['id'] as String);
      return;
    }

    write['retryCount'] = retryCount;
    // Update in IndexedDB with exponential backoff
  }
}

enum WriteAction { insert, update, delete }

class WriteOperation {
  final String id;
  final String table;
  final WriteAction action;
  final Map<String, dynamic> data;

  WriteOperation({
    required this.id,
    required this.table,
    required this.action,
    required this.data,
  });
}
```

### 3.2 Optimistic Update Pattern (Day 13)

**Goal:** Update UI immediately, sync in background.

**Example: Saving Nutrition Plan**

```dart
class NutritionPlanService {
  Future<void> savePlan(NutritionPlan plan) async {
    // 1. Update cache immediately (optimistic)
    await _updateCacheImmediately(plan);

    // 2. Queue background write
    await _writeQueue.enqueue(WriteOperation(
      id: plan.id,
      table: 'nutrition_plans',
      action: WriteAction.insert,
      data: plan.toJson(),
    ));

    // 3. UI shows updated state instantly
  }

  Future<void> _updateCacheImmediately(NutritionPlan plan) async {
    if (kIsWeb && _cache != null) {
      // Update in-memory cache
      _inMemoryPlans[plan.id] = plan;

      // Update IndexedDB cache
      await _cache!.set(
        WebCacheService.userStore,
        'plans_${plan.deviceId}',
        _inMemoryPlans.values.toList(),
        (plans) => {'items': plans.map((p) => p.toJson()).toList()},
        Duration(days: 7),
      );
    }
  }
}
```

### 3.3 Retry Logic with Exponential Backoff (Day 14)

**Goal:** Retry failed writes with increasing delays.

```dart
class RetryService {
  static Duration getBackoffDelay(int retryCount) {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    final baseDelay = Duration(seconds: 1);
    final multiplier = math.pow(2, retryCount);
    return baseDelay * multiplier.toInt();
  }

  Future<void> retryWithBackoff(
    Future<void> Function() operation,
    int maxRetries,
  ) async {
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        await operation();
        return;  // Success
      } catch (e) {
        retryCount++;

        if (retryCount >= maxRetries) {
          rethrow;
        }

        final delay = getBackoffDelay(retryCount);
        print('Retry $retryCount after ${delay.inSeconds}s');
        await Future.delayed(delay);
      }
    }
  }
}
```

### 3.4 Conflict Resolution (Day 15)

**Goal:** Handle conflicts when offline changes conflict with server state.

```dart
class ConflictResolver {
  Future<void> resolveConflict(
    WriteOperation localWrite,
    Map<String, dynamic> serverData,
  ) async {
    // Strategy: Last-write-wins
    final localTimestamp = DateTime.parse(
      localWrite.data['updated_at'] as String,
    );
    final serverTimestamp = DateTime.parse(
      serverData['updated_at'] as String,
    );

    if (localTimestamp.isAfter(serverTimestamp)) {
      // Local is newer - upload local changes
      await _supabase
          .from(localWrite.table)
          .update(localWrite.data)
          .eq('id', localWrite.data['id']);
    } else {
      // Server is newer - discard local changes
      print('Discarding local changes (server is newer)');
      await _updateCacheWithServerData(serverData);
    }
  }

  Future<void> _updateCacheWithServerData(
    Map<String, dynamic> serverData,
  ) async {
    // Update cache with authoritative server data
  }
}
```

**Success Criteria:**
- ✅ Writes update UI instantly
- ✅ Background upload queue works
- ✅ Retry logic with exponential backoff
- ✅ Conflict resolution handles edge cases
- ✅ No data loss

---

## Week 4: Service Worker & PWA (OPTIONAL - SKIP FOR MVP)

### Decision: Not Required for MVP

Workbox and service workers are **NOT required** for the Mealvana web deployment MVP. Here's why:

**What already handles caching without service workers:**
- ✅ **Vercel Edge CDN**: Static assets cached globally across 100+ locations
- ✅ **Browser cache**: Automatic via Cache-Control headers (see vercel.json configuration)
- ✅ **IndexedDB**: Your custom data caching (foods, user data, content)

**What you lose without service workers:**
- ❌ Custom offline page (users see browser default "No internet connection")
- ❌ Background sync for failed requests
- ❌ PWA install prompts and standalone app experience

**Why this trade-off is acceptable:**
1. **Core features require internet anyway** - AI nutrition generation needs Supabase Edge Functions
2. **OAuth requires internet** - Sign in with Apple/Google needs connectivity
3. **Complexity reduction** - Skip 400+ lines of service worker code
4. **Faster implementation** - 3 weeks instead of 4 weeks
5. **Browser caching is sufficient** - Vercel + Cache-Control headers provide good performance

### Build Command (No PWA)

```bash
flutter build web --release --pwa-strategy=none --web-renderer canvaskit
```

### When to Add Workbox Later (Phase 2)

Consider adding service workers in Phase 2 if you need:

1. **True offline app shell** - Custom "You're Offline" page with branding
2. **Background sync** - Queue failed API calls for retry when online
3. **PWA installability** - "Add to Home Screen" prompt on mobile browsers
4. **Offline content** - View cached nutrition plans without internet

For MVP, skip this complexity. Use `flutter build web --pwa-strategy=none`

---

## Original Week 4 Implementation (For Future Reference)

<details>
<summary>Click to expand full Workbox/PWA implementation details</summary>

### Objective (Optional Phase 2)
Add service worker for static asset caching and PWA support.

### 4.1 Setup Workbox (Days 16-17)

**Goal:** Install and configure Workbox for service worker generation.

```bash
npm install --save-dev workbox-cli
```

**File:** `workbox-config.js`

```javascript
module.exports = {
  globDirectory: 'build/web/',
  globPatterns: [
    '**/*.{js,css,html,png,jpg,svg,woff,woff2,ttf,eot,ico,json}'
  ],
  swDest: 'build/web/sw.js',

  runtimeCaching: [
    {
      urlPattern: /^https:\/\/fonts\.googleapis\.com/,
      handler: 'StaleWhileRevalidate',
      options: {
        cacheName: 'google-fonts-stylesheets',
      }
    },
    {
      urlPattern: /^https:\/\/fonts\.gstatic\.com/,
      handler: 'CacheFirst',
      options: {
        cacheName: 'google-fonts-webfonts',
        cacheableResponse: {
          statuses: [0, 200]
        },
        expiration: {
          maxAgeSeconds: 60 * 60 * 24 * 365,  // 1 year
          maxEntries: 30
        }
      }
    },
    {
      urlPattern: /\.(?:png|jpg|jpeg|svg|gif)$/,
      handler: 'CacheFirst',
      options: {
        cacheName: 'images',
        expiration: {
          maxEntries: 60,
          maxAgeSeconds: 30 * 24 * 60 * 60  // 30 days
        }
      }
    },
    {
      urlPattern: /\/api\//,
      handler: 'NetworkFirst',
      options: {
        cacheName: 'api-cache',
        networkTimeoutSeconds: 10,
        expiration: {
          maxEntries: 50,
          maxAgeSeconds: 5 * 60  // 5 minutes
        }
      }
    }
  ]
};
```

**Build Script:** `build_web_pwa.sh`

```bash
#!/bin/bash
set -e

echo "Building Flutter web..."
flutter build web --release --web-renderer html

echo "Generating service worker..."
npx workbox generateSW workbox-config.js

echo "PWA build complete!"
```

### 4.2 Create Manifest (Day 17)

**File:** `web/manifest.json`

```json
{
  "name": "Mealvana Endurance",
  "short_name": "Mealvana",
  "description": "AI-powered nutrition planning for endurance athletes",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#4CAF50",
  "orientation": "portrait-primary",
  "icons": [
    {
      "src": "/icons/icon-72x72.png",
      "sizes": "72x72",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-96x96.png",
      "sizes": "96x96",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-128x128.png",
      "sizes": "128x128",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-144x144.png",
      "sizes": "144x144",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-152x152.png",
      "sizes": "152x152",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-192x192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-384x384.png",
      "sizes": "384x384",
      "type": "image/png",
      "purpose": "any maskable"
    },
    {
      "src": "/icons/icon-512x512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "any maskable"
    }
  ]
}
```

**Update:** `web/index.html`

```html
<head>
  <!-- ... existing head content ... -->

  <!-- PWA Manifest -->
  <link rel="manifest" href="manifest.json">

  <!-- iOS Meta Tags -->
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black">
  <meta name="apple-mobile-web-app-title" content="Mealvana">
  <link rel="apple-touch-icon" href="/icons/icon-192x192.png">

  <!-- Theme Color -->
  <meta name="theme-color" content="#4CAF50">
</head>

<body>
  <!-- ... existing body content ... -->

  <!-- Register Service Worker -->
  <script>
    if ('serviceWorker' in navigator) {
      window.addEventListener('load', () => {
        navigator.serviceWorker.register('/sw.js')
          .then(registration => {
            console.log('Service Worker registered:', registration);
          })
          .catch(error => {
            console.error('Service Worker registration failed:', error);
          });
      });
    }
  </script>
</body>
```

### 4.3 Offline Fallback Page (Day 18)

**File:** `web/offline.html`

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Offline - Mealvana</title>
  <style>
    body {
      font-family: system-ui, -apple-system, sans-serif;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }

    .offline-container {
      text-align: center;
      padding: 2rem;
    }

    h1 {
      font-size: 2.5rem;
      margin-bottom: 1rem;
    }

    p {
      font-size: 1.2rem;
      opacity: 0.9;
    }

    .icon {
      font-size: 5rem;
      margin-bottom: 1rem;
    }

    button {
      margin-top: 2rem;
      padding: 1rem 2rem;
      font-size: 1rem;
      background: white;
      color: #667eea;
      border: none;
      border-radius: 8px;
      cursor: pointer;
      font-weight: 600;
    }

    button:hover {
      transform: scale(1.05);
    }
  </style>
</head>
<body>
  <div class="offline-container">
    <div class="icon">📡</div>
    <h1>You're Offline</h1>
    <p>Mealvana works best with an internet connection.</p>
    <p>You can still view cached nutrition plans and food data.</p>
    <button onclick="window.location.reload()">Try Again</button>
  </div>
</body>
</html>
```

### 4.4 Install Prompt (Day 19)

**File:** `lib/shared/widgets/pwa_install_prompt.dart`

```dart
import 'package:flutter/material.dart';
import 'dart:html' as html;

class PWAInstallPrompt extends StatefulWidget {
  const PWAInstallPrompt({super.key});

  @override
  State<PWAInstallPrompt> createState() => _PWAInstallPromptState();
}

class _PWAInstallPromptState extends State<PWAInstallPrompt> {
  bool _showPrompt = false;
  html.Event? _deferredPrompt;

  @override
  void initState() {
    super.initState();
    _listenForInstallPrompt();
  }

  void _listenForInstallPrompt() {
    html.window.addEventListener('beforeinstallprompt', (event) {
      event.preventDefault();
      setState(() {
        _deferredPrompt = event;
        _showPrompt = true;
      });
    });
  }

  Future<void> _showInstallPrompt() async {
    if (_deferredPrompt == null) return;

    // Show the install prompt
    // Note: This requires additional JS interop in actual implementation

    setState(() {
      _showPrompt = false;
      _deferredPrompt = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_showPrompt) return const SizedBox.shrink();

    return Container(
      color: Colors.blue.shade600,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.install_mobile, color: Colors.white),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Install Mealvana for a better experience',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ),
          TextButton(
            onPressed: _showInstallPrompt,
            child: const Text(
              'Install',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => setState(() => _showPrompt = false),
          ),
        ],
      ),
    );
  }
}
```

### 4.5 Testing & Launch (Day 20)

**PWA Checklist:**

```bash
# 1. Build PWA
./build_web_pwa.sh

# 2. Serve locally
cd build/web
python3 -m http.server 8000

# 3. Test with Lighthouse
lighthouse http://localhost:8000 --view

# 4. Verify PWA criteria
# - ✅ Manifest present
# - ✅ Service worker registered
# - ✅ Icons in all sizes
# - ✅ Offline fallback works
# - ✅ Install prompt appears
# - ✅ Lighthouse PWA score > 90
```

**Success Criteria:**
- ✅ Service worker caches static assets
- ✅ Offline fallback page displays
- ✅ PWA install prompt appears
- ✅ App works offline with cached data
- ✅ Lighthouse PWA score > 90

</details>

---

## Success Metrics

### Technical Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Cached read latency | <10ms | Chrome DevTools Performance |
| Cache hit rate | >80% | Analytics events |
| Bundle size | <3MB | flutter build web --analyze-size |
| Initial load time | <3s on 3G | Lighthouse |
| Offline capability | Read-only | Manual testing |

### Business Metrics

- ✅ 100% core feature parity with mobile
- ✅ Users can generate nutrition plans on web
- ✅ Food preferences persist correctly
- ✅ Offline mode shows cached data
- ✅ No data loss during network issues

---

## Risk Mitigation

### High-Risk Items

1. **Browser Storage Quotas**
   - **Risk:** Users exceed 10-50MB IndexedDB quota
   - **Mitigation:** Implement LRU eviction, show storage usage
   - **Fallback:** Degrade to in-memory cache only

2. **Cache Invalidation Bugs**
   - **Risk:** Stale data shown to users
   - **Mitigation:** Conservative TTLs, explicit invalidation on writes
   - **Fallback:** Manual cache clear button

3. **Write Queue Failures**
   - **Risk:** Offline writes lost
   - **Mitigation:** Persistent queue in IndexedDB, retry logic
   - **Fallback:** Show "sync failed" warning to user

4. **Cross-Browser Compatibility**
   - **Risk:** IndexedDB behaves differently in Safari
   - **Mitigation:** Early Safari testing, idb_shim library
   - **Fallback:** Officially support Chrome first, expand later

---

## Timeline Summary

| Week | Phase | Key Deliverables |
|------|-------|------------------|
| Week 1 | Core Cache Layer | WebCacheService, Foods cache, Content cache, User cache |
| Week 2 | Smart Invalidation | Background sync, Stale-while-revalidate, Network reconnect |
| Week 3 | Optimistic Writes | Write queue, Retry logic, Conflict resolution |

**Total: 3 weeks (15 developer days)**

**Note:** Week 4 (Service Worker & PWA) is optional and skipped for MVP. Can be added in Phase 2 if needed.

---

## Post-Launch Monitoring

### Week 4-5: Observability

1. **Add Cache Analytics**
   ```dart
   void trackCacheHit(String storeName) {
     analytics.track('cache_hit', {'store': storeName});
   }

   void trackCacheMiss(String storeName) {
     analytics.track('cache_miss', {'store': storeName});
   }
   ```

2. **Monitor Storage Usage**
   ```dart
   Future<void> checkStorageQuota() async {
     final estimate = await html.window.navigator.storage?.estimate();
     final usagePercent = (estimate?.usage ?? 0) / (estimate?.quota ?? 1);

     if (usagePercent > 0.8) {
       analytics.track('storage_quota_warning', {'usage': usagePercent});
     }
   }
   ```

3. **Track Write Queue Health**
   ```dart
   Future<void> monitorWriteQueue() async {
     final queueLength = await _writeQueue.getPendingCount();

     if (queueLength > 10) {
       analytics.track('write_queue_backlog', {'count': queueLength});
     }
   }
   ```

---

## Next Steps

1. **Week 1 Kickoff** - Team reviews roadmap, assigns developers
2. **Day 1 Start** - Create feature branch, setup IndexedDB dependency
3. **Weekly Check-ins** - Review progress, adjust timeline as needed
4. **Week 4 Launch** - Deploy to production, monitor metrics

---

## Related Documentation

- 📋 [Main Overview](./README.md) - Comprehensive web deployment overview
- 📊 [Cache Strategy](./cache-strategy.md) - Detailed caching architecture
- 🚫 [Technical Blockers](./blockers.md) - Resolved with Option C approach
- 🏗️ [FOA Architecture](../technical/foa-architecture.md) - Current architecture patterns

---

**Document Version:** 2.0 (Option C Implementation)
**Last Updated:** 2025-12-15
**Status:** Ready for Implementation
**Maintainer:** Development Team
