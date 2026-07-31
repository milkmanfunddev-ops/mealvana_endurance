# Phase 5.4-5.5 Implementation Notes

**Date**: 2026-01-18
**Agent**: claude-sonnet-4.5-20260118-p5.4-p5.5
**Tasks**: Update FoodPreferencesController + Review Pull-to-Refresh

---

## 5.4 FoodPreferencesController Update

### Implementation

Modified `/lib/features/onboarding/presentation/providers/food_preferences_controller.dart`:

1. **Added imports**:
   - `sync_coordinator.dart` - For SyncCoordinator provider
   - `user_id_provider.dart` - For getting current user ID
   - `logging_service.dart` - For error logging
   - `food_preferences_repository.dart` - For repository instance

2. **Added `_ensureFoodPreferencesSynced()` method**:
   ```dart
   Future<void> _ensureFoodPreferencesSynced() async {
     try {
       final userId = await ref.read(userIdProvider.future);
       final repository = await ref.read(foodPreferencesRepositoryProvider.future);

       await ref.read(syncCoordinatorProvider.notifier).ensureSynced(
         'food_preferences',
         userId,
         repository: repository,
       );
     } catch (e, stackTrace) {
       _logger.warning(
         'Food preferences sync failed - proceeding with cached data',
         context: 'FOOD_PREFERENCES_CONTROLLER',
         error: e,
         stackTrace: stackTrace,
       );
       // Don't rethrow - best effort sync, user sees cached data
     }
   }
   ```

3. **Updated `build()` method**:
   - Calls `_ensureFoodPreferencesSynced()` before loading data
   - Follows the new sync architecture pattern
   - Graceful error handling - logs warning but doesn't block UI

### Pattern Notes

**Why this pattern works**:
- `ensureSynced()` checks staleness first (24-hour threshold)
- If fresh, returns immediately (no-op)
- If stale, recursively syncs dependencies ('users', 'foods') FIRST
- Then uploads dirty records
- Then syncs fresh data from Supabase
- Updates timestamp

**Error handling strategy**:
- Best effort sync - don't block UI on sync failures
- Log warnings for debugging
- User sees cached data immediately
- Silent degradation (no user-facing error)

---

## 5.5 Pull-to-Refresh Review

### Current Implementation

**Location**: `/lib/features/activities/presentation/screens/activities_list_screen.dart`

**Pattern**:
```dart
RefreshIndicator(
  onRefresh: () async {
    ref.invalidate(activitiesControllerProvider);
    ref.invalidate(carbLoadingControllerProvider);
    ref.invalidate(nextUpcomingEventProvider);
  },
  child: CustomScrollView(...),
)
```

### How It Works

1. **User pulls down** on activities list screen
2. **RefreshIndicator triggers** `onRefresh` callback
3. **Invalidates providers**:
   - `activitiesControllerProvider` - Triggers full rebuild
   - `carbLoadingControllerProvider` - Triggers full rebuild
   - `nextUpcomingEventProvider` - Triggers full rebuild
4. **Controllers rebuild**:
   - `ActivitiesController.build()` → triggers background sync via `_syncInBackground()`
   - Background sync calls `SyncCoordinator.sync()` (OLD full sync)
   - On success, sync coordinator invalidates ALL providers again
5. **UI refreshes** with new data

### Two Sync Patterns in Codebase

#### OLD Pattern (still in use for pull-to-refresh)
```dart
await ref.read(syncCoordinatorProvider.notifier).sync(
  userId: userId,
  trigger: SyncTrigger.pullToRefresh,
);
```
- Syncs ALL repositories at once
- Used for OAuth sign-in and manual refresh
- Full invalidation of all providers after sync

#### NEW Pattern (Phase 5 - repository-level)
```dart
await ref.read(syncCoordinatorProvider.notifier).ensureSynced(
  'food_preferences',
  userId,
  repository: repository,
);
```
- Syncs ONE repository at a time
- Dependency resolution (recursive)
- Staleness checks (24-hour threshold)
- Used by controllers in `build()` for on-demand sync

### Decision: KEEP EXISTING PULL-TO-REFRESH BEHAVIOR

**Rationale**:

1. **Different use cases**:
   - Pull-to-refresh = explicit user request to sync EVERYTHING
   - Controller ensureSynced = automatic background sync for specific data

2. **User expectations**:
   - When user pulls down, they expect a "full refresh"
   - Syncing only the visible repository would feel incomplete

3. **No breaking changes needed**:
   - Current implementation works well
   - Users are familiar with the behavior
   - No reported issues

4. **Complementary patterns**:
   - Pull-to-refresh: Manual, full sync (user-initiated)
   - ensureSynced: Automatic, selective sync (system-initiated)

### Recommended Improvements (Future Phase)

If we want to optimize pull-to-refresh in the future:

1. **Convert to repository-level refresh**:
   ```dart
   RefreshIndicator(
     onRefresh: () async {
       final userId = await ref.read(userIdProvider.future);
       final activitiesRepo = await ref.read(activitiesRepositoryProvider.future);
       final carbRepo = await ref.read(carbLoadingRepositoryProvider.future);

       await Future.wait([
         ref.read(syncCoordinatorProvider.notifier).ensureSynced(
           'activities', userId, repository: activitiesRepo,
         ),
         ref.read(syncCoordinatorProvider.notifier).ensureSynced(
           'carb_loading_plans', userId, repository: carbRepo,
         ),
       ]);

       ref.invalidateSelf(); // Only invalidate this screen's providers
     },
   )
   ```

2. **Benefits**:
   - Faster (only syncs what's visible)
   - More granular control
   - Less network traffic
   - Uses dependency resolution

3. **When to do this**:
   - After Phase 6 (all repositories migrated)
   - After testing shows performance gains
   - After user testing confirms it feels responsive

---

## Testing Notes

### Manual Testing Checklist

- [ ] Open food preferences screen
- [ ] Verify sync happens in background (no blocking UI)
- [ ] Check logs for sync success/failure messages
- [ ] Test with network offline (should show cached data)
- [ ] Test pull-to-refresh on activities screen
- [ ] Verify full sync still works

### Unit Tests Needed

- [ ] `FoodPreferencesController.build()` calls ensureSynced
- [ ] Error handling works (sync fails, UI still loads)
- [ ] Repository is passed correctly to ensureSynced

---

## Summary

### Changes Made

1. ✅ Updated `FoodPreferencesController` to call `ensureSynced('food_preferences')`
2. ✅ Added graceful error handling
3. ✅ Documented pull-to-refresh decision

### Pull-to-Refresh Decision

**KEEP existing behavior** - full sync on pull-to-refresh is intentional and user-friendly.

### Next Steps

- Run code generation: `flutter pub run build_runner build --delete-conflicting-outputs`
- Test manually
- Move to Phase 5.1-5.3 (other controllers)

---

## Code Generation Required

After completing this phase:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This will regenerate:
- `food_preferences_controller.g.dart`
