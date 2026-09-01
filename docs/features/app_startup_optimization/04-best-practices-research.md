# Best Practices Research

> **Last Updated**: December 2024
> **Sources**: Industry research, Andrea Bizzotto patterns, Flutter documentation

## Table of Contents

1. [Mobile App Startup Best Practices](#mobile-app-startup-best-practices)
2. [Data Synchronization Strategies](#data-synchronization-strategies)
3. [Offline-First Architecture](#offline-first-architecture)
4. [Andrea Bizzotto Patterns](#andrea-bizzotto-patterns)
5. [Flutter-Specific Best Practices](#flutter-specific-best-practices)
6. [Caching & Data Retention](#caching--data-retention)
7. [Background Processing](#background-processing)

---

## Mobile App Startup Best Practices

### Launch Types and Performance Targets

| Launch Type | Description | Target Time | Acceptable |
|-------------|-------------|-------------|------------|
| **Cold Start** | Fresh start (after reboot, install, process kill) | < 2 seconds | < 5 seconds |
| **Warm Start** | Process exists but UI destroyed | < 2 seconds | < 2 seconds |
| **Hot Start** | App already in memory, just foregrounded | < 1.5 seconds | < 1.5 seconds |

**Key Insight**: Cold start time directly impacts retention. Apps taking >3 seconds to start see significant retention drops.

### Core Optimization Principles

#### 1. Do Less at Startup

| Practice | Description |
|----------|-------------|
| Minimize main() work | Only non-recoverable initialization |
| Move non-essential off main thread | Analytics, crash handlers, third-party SDKs |
| Use lazy initialization | Only create objects when first needed |

#### 2. Perception Management

| Technique | User Experience |
|-----------|-----------------|
| Skeleton UIs | Show placeholders immediately |
| Cached content first | Display last known data while refreshing |
| Progressive loading | Critical content first, details later |

#### 3. Non-Blocking Network

| Pattern | Implementation |
|---------|----------------|
| Background sync | Don't block UI on network |
| Fire-and-forget | `unawaited()` for non-critical sync |
| Fallback content | Local defaults when offline |

### Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Over-initialization in `main()` | Can't recover from errors | Move to providers |
| Blocking network calls before UI | Slow start, poor offline | Background sync |
| Circular dependencies | Initialization deadlocks | Proper dependency graph |
| Missing observability | Can't diagnose issues | Add structured logging |

---

## Data Synchronization Strategies

### The Offline-First Paradigm

**2024-2025 Consensus**: Offline-first is no longer optional.

| Statistic | Implication |
|-----------|-------------|
| 77% of users expect offline functionality | Must work without network |
| Offline-first apps have 30% higher retention | Business case is clear |
| 1/3 of global population has unreliable internet | Can't assume connectivity |

### Sync Patterns

#### 1. Pull-Based Synchronization

```
App Request → Server Response → Local Update
```

| Characteristic | Value |
|----------------|-------|
| Initiator | Client |
| Best for | Brief offline periods |
| Common trigger | Navigation, app open |

#### 2. Push-Based Synchronization

```
Server Change → Push Notification → Client Fetch → Local Update
```

| Characteristic | Value |
|----------------|-------|
| Initiator | Server |
| Best for | Real-time updates |
| Requires | WebSocket or polling |

#### 3. Database Synchronization

```
Local Change → Queue → Upload → Server
Server Change → WebSocket → Download → Merge
```

| Characteristic | Value |
|----------------|-------|
| Direction | Bidirectional |
| Complexity | High |
| Best for | Collaborative apps |

### When to Sync

| Trigger | Use Case | Implementation |
|---------|----------|----------------|
| App Start | Ensure fresh data | Quick check (<500ms timeout) |
| Background | Large transfers | WorkManager with network constraint |
| Manual | User control | Pull-to-refresh, "Sync Now" button |
| After change | Immediate backup | Fire-and-forget upload |
| App Resume | Catch up after background | If paused > 5 minutes |

### Conflict Resolution Strategies

#### Last-Write-Wins (LWW)

```dart
if (serverTimestamp > localTimestamp) {
  useServerVersion();
} else {
  useLocalVersion();
}
```

| Pros | Cons |
|------|------|
| Simple to implement | Can lose data |
| Deterministic | No merge capability |
| Low overhead | Clock skew issues |

#### Version Vectors

```dart
if (localVersion != serverVersion && hasLocalChanges) {
  // CONFLICT
  showConflictResolutionUI();
}
```

| Pros | Cons |
|------|------|
| Detects conflicts | More complex |
| Enables user choice | Requires UI |
| Preserves data | Storage overhead |

#### CRDTs (Conflict-Free Replicated Data Types)

| Pros | Cons |
|------|------|
| No conflicts by design | Very complex |
| Eventual consistency | Limited data types |
| No coordination needed | Memory overhead |

### Recommended for Mealvana

**Strategy**: Last-Write-Wins with Dirty Flag Protection + Version Column for Conflict Detection

```dart
// Upload: Optimistic locking
await supabase.from('activities')
  .update({...data, version: localVersion + 1})
  .eq('id', id)
  .eq('version', localVersion);  // Fails if version changed

// Download: Dirty flag protection
if (localRecord.needsUpload) {
  skip(); // Never overwrite dirty records
}
```

---

## Offline-First Architecture

### Core Principle

**The local database is the single source of truth (SSOT), not the server.**

```
Traditional:     Server SSOT → Local Cache → UI
Offline-First:   Local DB SSOT → UI
                          ↕
                   Sync Engine → Server
```

### Schema Design for Sync

```sql
CREATE TABLE items (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT,

  -- Sync tracking columns
  is_synced INTEGER DEFAULT 0,       -- Dirty flag
  is_deleted INTEGER DEFAULT 0,       -- Soft delete
  last_modified INTEGER NOT NULL,     -- Timestamp
  version INTEGER DEFAULT 1,          -- Optimistic locking

  -- Retry tracking
  upload_retry_count INTEGER DEFAULT 0,
  last_upload_attempt INTEGER,
  upload_error_message TEXT
);
```

### Dirty Flag Pattern Flow

```
1. User Action → Dispatch
         ↓
2. Write to SQLite → Set is_synced = 0
         ↓
3. Query dirty: SELECT * WHERE is_synced = 0
         ↓
4. Push to server (background)
         ↓
5. On success: UPDATE is_synced = 1
   On failure: INCREMENT upload_retry_count
```

### Queue-Based Upload Strategy

```sql
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,        -- 'activity', 'event', etc.
  entity_id TEXT NOT NULL,
  operation TEXT NOT NULL,          -- 'insert', 'update', 'delete'
  payload TEXT NOT NULL,            -- JSON data
  retry_count INTEGER DEFAULT 0,
  created_at INTEGER NOT NULL,
  last_attempt_at INTEGER,
  error_message TEXT
);
```

### Benefits of Offline-First

| Benefit | Description |
|---------|-------------|
| Works everywhere | No network required for core features |
| Fast UI | No network latency for local operations |
| Resilient | Survives network issues gracefully |
| Battery efficient | Batch sync vs constant polling |

---

## Andrea Bizzotto Patterns

### App Initialization Pattern

#### The Three-Stage Evolution

**Stage 1: Basic (NOT RECOMMENDED)**
```dart
void main() async {
  try {
    await someAsyncCodeThatMayThrow();
    runApp(const MaterialApp(home: MainApp()));
  } catch (e) {
    runApp(const MaterialApp(home: AppStartupErrorWidget(e)));
  }
}
```
**Problem**: No retry capability

**Stage 2: StatefulWidget (BETTER)**
```dart
class AppStartupWidget extends StatefulWidget {
  // Manages loading, error, success states with retry
}
```

**Stage 3: Riverpod Eager Init (RECOMMENDED)**
```dart
@Riverpod(keepAlive: true)
Future<void> appStartup(AppStartupRef ref) async {
  ref.onDispose(() {
    ref.invalidate(sharedPreferencesProvider);
  });
  await ref.watch(sharedPreferencesProvider.future);
  await ref.watch(databaseProvider.future);
}
```

### What Goes Where

#### In `main()` (Non-Recoverable)

| Dependency | Reason |
|------------|--------|
| WidgetsFlutterBinding | Required for Flutter |
| Firebase/Supabase | App can't function without backend |
| Sentry | Must catch startup errors |

#### In `appStartupProvider` (Recoverable)

| Dependency | Reason |
|------------|--------|
| Database | Can retry initialization |
| SharedPreferences | Can retry |
| User session | Network-dependent |
| Content sync | Optional, can fail |

### Four-Layer Architecture (FOA)

```
┌─────────────────────────┐
│   Presentation Layer    │  ← Widgets & Controllers (AsyncNotifier)
├─────────────────────────┤
│   Application Layer     │  ← Services (cross-feature logic)
├─────────────────────────┤
│    Domain Layer         │  ← Models (immutable data classes)
├─────────────────────────┤
│     Data Layer          │  ← Repositories & Data Sources
└─────────────────────────┘
```

### Controller Pattern (Mandatory)

```dart
@riverpod
class ScreenController extends _$ScreenController {
  @override
  FutureOr<ScreenState> build() {
    return ScreenState(title: 'Initial State');
  }

  Future<void> performAction() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      // Business logic
      return updatedState;
    });
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
```

### Key Rules

| Rule | Reason |
|------|--------|
| Use `@riverpod` annotation | Code generation, type safety |
| Extend `AsyncNotifier<T>` | Modern pattern, error handling |
| Use `AsyncValue.guard()` | Consistent error handling |
| Access services via `ref.read()` | Proper DI |
| Never use `StateNotifier` | Deprecated |

---

## Flutter-Specific Best Practices

### App Lifecycle Management

```dart
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // Trigger sync when app returns to foreground
        ref.read(syncServiceProvider).syncNow();
        break;
      case AppLifecycleState.paused:
        // Save pending state, upload dirty records
        ref.read(syncServiceProvider).uploadPending();
        break;
      default:
        break;
    }
  }
}
```

### AppLifecycleState States

| State | Description | Action |
|-------|-------------|--------|
| `resumed` | App visible, responding to input | Sync if stale |
| `inactive` | Transitioning (iOS) | Prepare for pause |
| `paused` | Not visible, in background | Save state, upload |
| `detached` | In memory but not rendering | Cleanup |

### Recommended Package Stack

| Category | Package | Purpose |
|----------|---------|---------|
| State Management | `riverpod` 2.x+ | Provider-based state |
| Local Database | `drift` | Type-safe SQLite |
| Background Tasks | `workmanager` | Periodic background sync |
| Network Monitoring | `connectivity_plus` | Online/offline detection |
| File Access | `path_provider` | Local file paths |
| Serialization | `json_serializable` | JSON encoding |

---

## Caching & Data Retention

### Cache Layers

| Layer | Speed | Persistence | Use Case |
|-------|-------|-------------|----------|
| L1 (Memory) | Fastest | Session only | Active screen data |
| L2 (Disk) | Fast | Survives restart | Historical data |
| L3 (Network) | Slow | Server | Source of truth |

### Cache Invalidation Strategies

#### Time-to-Live (TTL)

```dart
final cacheExpiry = Duration(hours: 24);
if (DateTime.now().isAfter(cachedAt.add(cacheExpiry))) {
  await refreshFromServer();
}
```

#### Version-Based

```dart
if (serverVersion > cachedVersion) {
  await refreshFromServer();
}
```

#### Event-Driven

```dart
// On specific user actions
onUserAction: () => clearCache();

// On push notification
onPushReceived: () => refreshData();
```

### Eviction Policies

| Policy | Description | Best For |
|--------|-------------|----------|
| LRU | Evict least recently used | General purpose |
| FIFO | Evict oldest first | Simple cases |
| Size-Based | Cap at specific size | Storage constraints |

### Data Migration Best Practices

| Practice | Implementation |
|----------|----------------|
| Use Drift migrations | Built-in version management |
| Test on production copies | Before deploying |
| Provide fallbacks | For failed migrations |
| Never delete data | Migrate or archive |

---

## Background Processing

### WorkManager Integration (Flutter)

```dart
// Initialize in main()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Workmanager().initialize(callbackDispatcher);
  runApp(MyApp());
}

// Top-level callback
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Can't use Riverpod here - create services directly
    final database = AppDatabase();
    final syncService = SyncService(database);
    await syncService.syncPendingChanges();
    return true;
  });
}

// Register periodic sync
Workmanager().registerPeriodicTask(
  'sync-task',
  'syncData',
  frequency: Duration(hours: 1),
  constraints: Constraints(
    networkType: NetworkType.connected,
    requiresBatteryNotLow: true,
  ),
);
```

### Platform Considerations

| Platform | Background Capability | Notes |
|----------|----------------------|-------|
| Android | WorkManager works well | Network constraints supported |
| iOS | Very limited | Background App Refresh only |

### Important Limitations

| Limitation | Workaround |
|------------|------------|
| Can't access Riverpod in background | Create services directly |
| iOS limits execution time | Keep tasks short (<30s) |
| Battery impact varies | Use network constraints |
| May be killed by OS | Design for resumable tasks |

---

## Summary: Key Takeaways for Mealvana

### Immediate Priorities

1. **Fix critical bugs** (two-step save race condition)
2. **Add connectivity monitoring** (detect offline state)
3. **Add lifecycle observer** (sync on resume)

### Short-Term Improvements

4. **Add retry queue** (exponential backoff)
5. **Add sync status UI** (user visibility)
6. **Add WorkManager** (background sync)

### Medium-Term Goals

7. **Add Realtime subscriptions** (multi-device)
8. **Add conflict detection** (version column)
9. **Add incremental sync** (bandwidth reduction)

### Architecture Principles to Follow

| Principle | Implementation |
|-----------|----------------|
| Offline-first | Local DB is SSOT |
| Upload-first | Push changes before downloading |
| Non-blocking | Never block UI on network |
| Graceful degradation | App works even if sync fails |
| User visibility | Show sync status |
| Retry with backoff | Auto-recover from failures |
