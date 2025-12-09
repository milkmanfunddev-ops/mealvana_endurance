# Implementation Roadmap

> **Last Updated**: December 2024
> **Total Estimated Effort**: 5 weeks
> **Prerequisites**: None (can start immediately)

## Table of Contents

1. [Overview](#overview)
2. [Phase 1: Critical Bug Fixes](#phase-1-critical-bug-fixes)
3. [Phase 2: Core Reliability](#phase-2-core-reliability)
4. [Phase 3: User Visibility](#phase-3-user-visibility)
5. [Phase 4: Background Sync](#phase-4-background-sync)
6. [Phase 5: Multi-Device Support](#phase-5-multi-device-support)
7. [Phase 6: Performance Optimization](#phase-6-performance-optimization)
8. [Testing Strategy](#testing-strategy)
9. [Rollback Plans](#rollback-plans)
10. [Success Metrics](#success-metrics)

---

## Overview

### Timeline

```
Week 1: Phase 1 (Critical Fixes) + Phase 2 Start
Week 2: Phase 2 (Core Reliability)
Week 3: Phase 3 (User Visibility) + Phase 4 Start
Week 4: Phase 4 (Background Sync) + Phase 5 Start
Week 5: Phase 5 (Multi-Device) + Testing
```

### Visual Roadmap

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           IMPLEMENTATION ROADMAP                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  WEEK 1          WEEK 2          WEEK 3          WEEK 4          WEEK 5    │
│  ─────────────────────────────────────────────────────────────────────────  │
│                                                                             │
│  ┌──────────┐                                                               │
│  │ PHASE 1  │ Critical Bug Fixes (1 day)                                   │
│  │ P0       │ • User Foods race condition                                  │
│  │          │ • Feedback race condition                                    │
│  │          │ • Nullable needsUpload fix                                   │
│  └────┬─────┘                                                               │
│       │                                                                     │
│       ▼                                                                     │
│  ┌────────────────────────┐                                                │
│  │       PHASE 2          │ Core Reliability (1.5 weeks)                   │
│  │       P1               │ • Connectivity monitoring                      │
│  │                        │ • Sync on app resume                           │
│  │                        │ • Retry queue + backoff                        │
│  └────────────┬───────────┘                                                │
│               │                                                             │
│               ▼                                                             │
│          ┌────────────────────────┐                                        │
│          │       PHASE 3          │ User Visibility (1 week)               │
│          │       P1               │ • Sync status provider                 │
│          │                        │ • Sync status widget                   │
│          │                        │ • Manual sync triggers                 │
│          └────────────┬───────────┘                                        │
│                       │                                                     │
│                       ▼                                                     │
│                  ┌────────────────────────┐                                │
│                  │       PHASE 4          │ Background Sync (3 days)       │
│                  │       P2               │ • WorkManager setup            │
│                  │                        │ • Background upload task       │
│                  │                        │ • Platform testing             │
│                  └────────────┬───────────┘                                │
│                               │                                             │
│                               ▼                                             │
│                          ┌────────────────────────┐                        │
│                          │       PHASE 5          │ Multi-Device (1 week)  │
│                          │       P2               │ • Supabase Realtime    │
│                          │                        │ • Version column       │
│                          │                        │ • Conflict detection   │
│                          └────────────┬───────────┘                        │
│                                       │                                     │
│                                       ▼                                     │
│                                  ┌─────────────┐                           │
│                                  │   TESTING   │                           │
│                                  │   & QA      │                           │
│                                  └─────────────┘                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Critical Bug Fixes

### Duration: 1 day
### Priority: P0 (CRITICAL)

### Task 1.1: Fix User Foods Race Condition

**File**: `lib/shared/database/app_database.dart`
**Lines**: 894-928

**Before**:
```dart
Future<void> saveUserFood(UserFood food) async {
  final companion = UserFoodsTableCompanion.insert(
    id: food.id,
    userId: food.userId,
    // ... fields WITHOUT needsUpload
  );

  await into(userFoodsTable).insert(companion, mode: InsertMode.insertOrReplace);

  // VULNERABLE: Separate operation
  await customStatement(
    'UPDATE user_foods SET needs_upload = 1, local_updated_at = ? WHERE id = ?',
    [DateTime.now().millisecondsSinceEpoch, food.id],
  );
}
```

**After**:
```dart
Future<void> saveUserFood(UserFood food) async {
  final companion = UserFoodsTableCompanion.insert(
    id: food.id,
    userId: food.userId,
    name: food.name,
    brandName: Value(food.brandName),
    servingSize: food.servingSize,
    servingUnit: food.servingUnit,
    calories: Value(food.calories),
    carbohydrates: Value(food.carbohydrates),
    protein: Value(food.protein),
    fat: Value(food.fat),
    sodium: Value(food.sodium),
    fiber: Value(food.fiber),
    sugar: Value(food.sugar),
    barcode: Value(food.barcode),
    source: Value(food.source),
    imageUrl: Value(food.imageUrl),
    isDeleted: Value(food.isDeleted),
    // ✅ ATOMIC: Set in same operation
    needsUpload: const Value(true),
    localUpdatedAt: Value(DateTime.now()),
    createdAt: Value(food.createdAt ?? DateTime.now()),
    updatedAt: Value(DateTime.now()),
  );

  await into(userFoodsTable).insert(
    companion,
    mode: InsertMode.insertOrReplace,
  );
  // No separate UPDATE needed
}
```

**Also fix**: `updateUserFood()` and `deleteUserFood()` (same pattern)

### Task 1.2: Fix Feedback Race Condition

**File**: `lib/shared/database/app_database.dart`
**Lines**: 766-793

**Apply same fix pattern as Task 1.1**

### Task 1.3: Standardize Nullable needsUpload

**Step 1**: Update `lib/shared/database/tables/activities_table.dart`

```dart
// Line 44 - BEFORE
BoolColumn get needsUpload => boolean().nullable().named('needs_upload')();

// Line 44 - AFTER
BoolColumn get needsUpload =>
    boolean().withDefault(const Constant(false)).named('needs_upload')();
```

**Step 2**: Update `lib/shared/database/tables/events_table.dart` (same change)

**Step 3**: Run code generation
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 4**: Add migration for existing null values

In `lib/shared/database/app_database.dart`, add to `beforeOpen`:
```dart
@override
MigrationStrategy get migration => MigrationStrategy(
  beforeOpen: (details) async {
    // ... existing code

    // Fix null needsUpload values
    await customStatement(
      'UPDATE activities SET needs_upload = 0 WHERE needs_upload IS NULL'
    );
    await customStatement(
      'UPDATE events SET needs_upload = 0 WHERE needs_upload IS NULL'
    );
  },
);
```

### Task 1.4: Verification

**Test Cases**:
- [ ] Create user food → force kill app → reopen → verify `needs_upload = 1`
- [ ] Submit feedback → force kill app → reopen → verify `needs_upload = 1`
- [ ] Create activity → verify `needs_upload = 0` (not null)
- [ ] Query `WHERE needs_upload = true` returns newly created records

---

## Phase 2: Core Reliability

### Duration: 1.5 weeks
### Priority: P1

### Task 2.1: Add Connectivity Monitoring

**Step 1**: Add dependency
```yaml
# pubspec.yaml
dependencies:
  connectivity_plus: ^6.0.0
```

**Step 2**: Create service

Create `lib/shared/services/connectivity/connectivity_service.dart`:
```dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'connectivity_service.g.dart';

@riverpod
Stream<List<ConnectivityResult>> connectivityStream(ConnectivityStreamRef ref) {
  return Connectivity().onConnectivityChanged;
}

@riverpod
Future<bool> isOnline(IsOnlineRef ref) async {
  final results = await Connectivity().checkConnectivity();
  return !results.contains(ConnectivityResult.none);
}

@riverpod
class ConnectivityNotifier extends _$ConnectivityNotifier {
  @override
  bool build() {
    // Listen to connectivity changes
    ref.listen(connectivityStreamProvider, (prev, next) {
      next.whenData((results) {
        state = !results.contains(ConnectivityResult.none);
      });
    });

    // Initial check
    _checkInitial();
    return true; // Assume online initially
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    state = !results.contains(ConnectivityResult.none);
  }
}
```

**Step 3**: Run code generation
```bash
dart run build_runner build --delete-conflicting-outputs
```

**Step 4**: Update DataSyncService to check connectivity

```dart
// In data_sync_service.dart
Future<bool> syncAllData(String userId) async {
  // Check connectivity first
  final isOnline = await ref.read(isOnlineProvider.future);
  if (!isOnline) {
    _logger.info('Offline - skipping sync', context: 'DATA_SYNC');
    return false;
  }

  // ... rest of sync logic
}
```

### Task 2.2: Add App Lifecycle Observer

Create `lib/shared/widgets/app_lifecycle_observer.dart`:
```dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/sync/data_sync_service.dart';
import '../../features/auth/application/user_id_provider.dart';

class AppLifecycleObserver extends ConsumerStatefulWidget {
  final Widget child;

  const AppLifecycleObserver({required this.child, super.key});

  @override
  ConsumerState<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;
  static const _syncThreshold = Duration(minutes: 5);
  static const _uploadDebounce = Duration(seconds: 2);
  Timer? _uploadTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _uploadTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _handlePause();
        break;
      case AppLifecycleState.resumed:
        _handleResume();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _handlePause() {
    _pausedAt = DateTime.now();

    // Debounced upload of dirty records
    _uploadTimer?.cancel();
    _uploadTimer = Timer(_uploadDebounce, () {
      _uploadPendingChanges();
    });
  }

  void _handleResume() {
    _uploadTimer?.cancel();

    if (_shouldSync()) {
      _syncData();
    }
  }

  bool _shouldSync() {
    if (_pausedAt == null) return false;
    return DateTime.now().difference(_pausedAt!) > _syncThreshold;
  }

  Future<void> _uploadPendingChanges() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;

    try {
      final syncService = ref.read(dataSyncServiceProvider);
      await syncService.uploadDirtyRecordsOnly(userId);
    } catch (e) {
      // Log but don't crash
      debugPrint('Failed to upload on pause: $e');
    }
  }

  Future<void> _syncData() async {
    final userId = ref.read(userIdProvider);
    if (userId == null) return;

    try {
      final syncService = ref.read(dataSyncServiceProvider);
      await syncService.syncAllData(userId);
    } catch (e) {
      // Log but don't crash
      debugPrint('Failed to sync on resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
```

**Update DataSyncService** to add `uploadDirtyRecordsOnly`:
```dart
Future<void> uploadDirtyRecordsOnly(String userId) async {
  final isOnline = await ref.read(isOnlineProvider.future);
  if (!isOnline) return;

  await _uploadDirtyRecords(userId);
}
```

**Integrate into root_app_widget.dart**:
```dart
MaterialApp.router(
  // ...
  builder: (context, child) {
    return AppLifecycleObserver(
      child: AppStartupWidget(
        onLoaded: (_) => child!,
      ),
    );
  },
)
```

### Task 2.3: Add Retry Queue

**Step 1**: Add columns to tables

Update `lib/shared/database/tables/activities_table.dart`:
```dart
// Add after needsUpload
IntColumn get uploadRetryCount =>
    integer().withDefault(const Constant(0)).named('upload_retry_count')();
DateTimeColumn get lastUploadAttempt =>
    dateTime().nullable().named('last_upload_attempt')();
TextColumn get uploadErrorMessage =>
    text().nullable().named('upload_error_message')();
```

**Repeat for**: events_table.dart, carb_loading_plans_table.dart, carb_loading_days_table.dart

**Step 2**: Run code generation and create migration

**Step 3**: Create retry service (see `06-recommendations.md` for full implementation)

**Step 4**: Integrate into sync flow

---

## Phase 3: User Visibility

### Duration: 1 week
### Priority: P1

### Task 3.1: Sync Status Provider

Create `lib/shared/services/sync/sync_status_provider.dart`

(Full implementation in `06-recommendations.md`)

### Task 3.2: Sync Status Widget

Create `lib/shared/widgets/sync_status_widget.dart`

(Full implementation in `06-recommendations.md`)

### Task 3.3: Manual Sync Triggers

**Pull-to-refresh**: Add `RefreshIndicator` to activities list

**Settings button**: Add "Sync Now" to settings screen

---

## Phase 4: Background Sync

### Duration: 3 days
### Priority: P2

### Task 4.1: WorkManager Setup

(Full implementation in `06-recommendations.md`)

### Task 4.2: Platform Testing

- [ ] Test on Android (various API levels)
- [ ] Test on iOS (Background App Refresh)
- [ ] Verify battery impact acceptable
- [ ] Verify network constraints respected

---

## Phase 5: Multi-Device Support

### Duration: 1 week
### Priority: P2

### Task 5.1: Add Version Column

**Supabase migration**:
```sql
ALTER TABLE activities ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE events ADD COLUMN version INTEGER DEFAULT 1;
ALTER TABLE carb_loading_plans ADD COLUMN version INTEGER DEFAULT 1;
```

**Drift tables**: Add matching column

### Task 5.2: Supabase Realtime

(Full implementation in `05-multi-device-analysis.md`)

### Task 5.3: Conflict Detection

Implement optimistic locking on upload

---

## Phase 6: Performance Optimization

### Duration: Optional (after Phase 5)
### Priority: P3

### Task 6.1: Incremental Sync per Table

Track last sync timestamp per table, not globally

### Task 6.2: Error Categorization

Differentiate retryable vs permanent errors

### Task 6.3: Sync Analytics

Track sync duration, success rate, bandwidth

---

## Testing Strategy

### Unit Tests

```dart
// test/shared/services/sync/data_sync_service_test.dart
void main() {
  group('DataSyncService', () {
    test('uploads dirty records before downloading', () async {
      // ...
    });

    test('skips sync when offline', () async {
      // ...
    });

    test('retries failed uploads with backoff', () async {
      // ...
    });

    test('does not overwrite dirty local records', () async {
      // ...
    });
  });
}
```

### Integration Tests

```dart
// test/integration/sync_flow_test.dart
void main() {
  group('Sync Flow', () {
    testWidgets('creates record offline, syncs when online', (tester) async {
      // 1. Go offline
      // 2. Create activity
      // 3. Verify needsUpload = true
      // 4. Go online
      // 5. Trigger sync
      // 6. Verify needsUpload = false
      // 7. Verify record on server
    });

    testWidgets('handles concurrent edits gracefully', (tester) async {
      // 1. Create activity on server
      // 2. Edit locally (don't sync)
      // 3. Edit on server (different change)
      // 4. Sync
      // 5. Verify conflict detected OR local preserved
    });
  });
}
```

### Manual Test Checklist

- [ ] Create activity offline → go online → verify synced
- [ ] Force kill app during sync → reopen → verify no data loss
- [ ] Edit on Device A → check Device B sees changes (Phase 5)
- [ ] Background app for 1 hour → reopen → verify fresh data
- [ ] Submit feedback → verify in Supabase
- [ ] Scan barcode → create food → verify in Supabase

---

## Rollback Plans

### Phase 1 Rollback

**If bug fixes cause issues**:
1. Revert commits
2. Re-run code generation
3. Deploy previous version

**Risk**: Low - fixes are additive

### Phase 2 Rollback

**If connectivity monitoring causes issues**:
1. Remove connectivity checks from sync
2. Remove lifecycle observer from widget tree

**Risk**: Low - features are isolated

### Phase 3 Rollback

**If sync status UI causes issues**:
1. Remove widget from settings
2. Remove provider

**Risk**: Very low - UI only

### Phase 4 Rollback

**If WorkManager causes issues**:
1. Unregister periodic task
2. Remove WorkManager initialization
3. App still works with foreground sync only

**Risk**: Medium - platform-specific behavior

### Phase 5 Rollback

**If Realtime causes issues**:
1. Unsubscribe from channel
2. Remove RealtimeSyncService
3. App falls back to pull-based sync

**Risk**: Medium - complex feature

---

## Success Metrics

### Phase 1 (Bug Fixes)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Data loss incidents | 0 | User reports |
| Records with null needsUpload | 0 | Database query |

### Phase 2 (Reliability)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Successful sync rate | >95% | Analytics |
| Failed uploads recovered | >90% | Retry success rate |
| Sync after resume | <5s | Timing logs |

### Phase 3 (Visibility)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Users aware of pending uploads | 100% | UI shows indicator |
| Manual sync completion | <10s | Timing logs |

### Phase 4 (Background)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Background sync execution | >80% | WorkManager logs |
| Battery impact | <1%/hour | Device stats |

### Phase 5 (Multi-Device)

| Metric | Target | Measurement |
|--------|--------|-------------|
| Cross-device sync latency | <5s | Timing logs |
| Conflict detection rate | 100% | Test scenarios |
| Data loss from conflicts | 0 | User reports |

---

## Checklist Summary

### Before Starting
- [ ] Review all documentation in `/docs/app_startup/`
- [ ] Understand current sync architecture
- [ ] Set up test environment

### Phase 1
- [ ] Fix user foods race condition
- [ ] Fix feedback race condition
- [ ] Standardize nullable needsUpload
- [ ] Run verification tests

### Phase 2
- [ ] Add connectivity_plus package
- [ ] Create connectivity service
- [ ] Add app lifecycle observer
- [ ] Add retry queue columns
- [ ] Create retry service
- [ ] Test offline/online transitions

### Phase 3
- [ ] Create sync status provider
- [ ] Create sync status widget
- [ ] Add to settings screen
- [ ] Add pull-to-refresh
- [ ] Add manual sync button

### Phase 4
- [ ] Add workmanager package
- [ ] Initialize WorkManager
- [ ] Create callback dispatcher
- [ ] Register periodic task
- [ ] Test on both platforms

### Phase 5
- [ ] Add version columns (Supabase + Drift)
- [ ] Set up Realtime subscriptions
- [ ] Implement conflict detection
- [ ] Create conflict UI (optional)
- [ ] Test multi-device scenarios

### Final
- [ ] Run full test suite
- [ ] Update documentation
- [ ] Deploy to staging
- [ ] Monitor metrics
- [ ] Deploy to production
