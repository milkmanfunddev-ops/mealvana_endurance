# Calendar Data Sync Implementation Status

## Executive Summary

**Current Status**: Phase 2 Complete + Edge Functions Deployed ✅
**Next Steps**: Integrate edge functions into repositories → Phase 3 (Calendar Sync Service)

---

## ✅ Phase 1: Repository Layer (COMPLETE)

### Created 4 FOA-Compliant Repositories:

1. **ActivitiesRepository** ✅
   - Location: `lib/features/calendar/data/activities_repository.dart`
   - Provider: `activitiesRepositoryProvider`
   - Operations: create, update, delete (soft), getAll, getById, getForDateRange
   - Status: Ready for edge function integration

2. **EventsRepository** ✅
   - Location: `lib/features/calendar/data/events_repository.dart`
   - Provider: `eventsRepositoryProvider`
   - Operations: create, update, delete (hard), getAll, getById, getForActivity
   - Status: Ready for edge function integration

3. **CarbLoadingRepository** ✅
   - Location: `lib/features/calendar/data/carb_loading_repository.dart`
   - Provider: `carbLoadingRepositoryProvider`
   - Operations: createPlan+Days, updateDay, deletePlan, getPlans, getDays
   - Status: Ready for edge function integration

4. **ActivityCompletionsRepository** ✅
   - Location: `lib/features/calendar/data/activity_completions_repository.dart`
   - Provider: `activityCompletionsRepositoryProvider`
   - Operations: recordCompletion, updateCompletion, getCompletions
   - Status: Ready for edge function integration

### Quality Metrics:
- Code Generation: ✅ All `.g.dart` files generated
- Compilation Errors: 0 ❌
- Flutter Analyze: ✅ Repository code clean

---

## ✅ Phase 2: Edge Functions (COMPLETE + DEPLOYED)

### Edge Functions Created & Deployed to Dev:

1. **save-calendar-activity** ✅ DEPLOYED
   - URL: `https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/save-calendar-activity`
   - Operations: create, update, delete (soft)
   - Size: 75.17kB
   - Features: Device validation, multi-sport support, timestamp management

2. **save-calendar-event** ✅ DEPLOYED
   - URL: `https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/save-calendar-event`
   - Operations: create, update, delete (hard)
   - Size: 75.19kB
   - Features: Activity ownership validation, carb loading metadata

3. **save-carb-loading-plan** ✅ DEPLOYED
   - URL: `https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/save-carb-loading-plan`
   - Operations: create plan+days, update day, delete plan (cascade)
   - Size: 76.75kB
   - Features: Auto-generates 2-day/3-day protocols, carb calculations

4. **save-activity-completion** ✅ DEPLOYED
   - URL: `https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/save-activity-completion`
   - Operations: create, update
   - Size: 75.18kB
   - Features: Auto-updates activity status, performance tracking

### Deployment Info:
- **Environment**: Dev (vlmtsdzpnjnavdgytcmi)
- **Dashboard**: https://supabase.com/dashboard/project/vlmtsdzpnjnavdgytcmi/functions
- **Total Edge Functions**: 4
- **Total Code**: ~825 lines TypeScript

---

## ✅ Phase 2.5: JSON Serialization (COMPLETE)

### toJson Methods Added:

1. **Activity.toJson()** ✅
   - Location: `lib/features/calendar/domain/activity.dart` (line 92-124)
   - Serializes: All fields including sport-specific (cycling, swimming)
   - Format: Matches edge function expected payload

2. **Event.toJson()** ✅
   - Location: `lib/features/calendar/domain/event.dart` (line 82-108)
   - Serializes: Event metadata, goals, carb loading config, results
   - Format: Matches edge function expected payload

3. **ActivityCompletion.toJson()** ✅
   - Location: `lib/features/calendar/domain/activity_completion.dart` (line 72-97)
   - Serializes: Performance data, ratings, notes, conditions
   - Format: Matches edge function expected payload

---

## ⏳ Phase 2.6: Repository Integration (PENDING)

### What Needs to Be Done:

For each repository (`activities`, `events`, `carb_loading`, `activity_completions`):

1. **Uncomment Edge Function Calls**
   - Replace temporary local-only writes with edge function invocations
   - Example in `activities_repository.dart` (lines 45-56):
     ```dart
     // Current: Temporary local-only
     await _cacheActivityLocally(activity);

     // Target: Call edge function
     final response = await _supabase.functions.invoke(
       'save-calendar-activity',
       body: {
         'device_id': deviceId,
         'activity': activity.toJson(),  // ✅ Now available!
         'operation': 'create',
       },
     );
     ```

2. **Add Error Handling**
   - Handle edge function-specific errors
   - Fallback to local-only on network failure (optional Phase 4 enhancement)
   - Log edge function response times

3. **Update Cache Logic**
   - Cache returned data from edge function
   - Ensure timestamps from Supabase are preserved

### Files to Update:
- `lib/features/calendar/data/activities_repository.dart` (3 methods: create, update, delete)
- `lib/features/calendar/data/events_repository.dart` (3 methods: create, update, delete)
- `lib/features/calendar/data/carb_loading_repository.dart` (3 methods: createPlan, updateDay, deletePlan)
- `lib/features/calendar/data/activity_completions_repository.dart` (2 methods: record, update)

---

## ⏳ Phase 3: Calendar Sync Service (PENDING)

### What Needs to Be Created:

#### 1. CalendarSyncService (`lib/features/calendar/application/calendar_sync_service.dart`)

**Purpose**: Download calendar data from Supabase on app startup

**Key Methods**:
```dart
Future<void> syncCalendarTables(String deviceId) async {
  // Get user_id from device_id
  // Sync in dependency order:
  await _syncActivities(userId);
  await _syncEvents(userId);
  await _syncCarbLoadingPlans(userId);
  await _syncCarbLoadingDays(userId);
  await _syncActivityCompletions(userId);
}
```

**Features**:
- Timestamp-based conflict resolution (Supabase wins if newer)
- Batch operations for performance
- Non-blocking (app continues if sync fails)
- Comprehensive logging
- Respects soft deletes (excludes `deleted_at` records)

#### 2. Integration into AppStartupService

**File**: `lib/features/app_startup/application/app_startup_service.dart`

**Add Method** (after line 181):
```dart
Future<void> syncCalendarData() async {
  try {
    _logger.info('Syncing calendar data from Supabase');

    final calendarSyncService = ref.read(calendarSyncServiceProvider);
    final deviceId = await getOrCreateDeviceId();

    await calendarSyncService.syncCalendarTables(deviceId);

    _logger.info('Calendar data sync completed');
  } catch (e, stackTrace) {
    _logger.error('Calendar data sync error', error: e, stackTrace: stackTrace);
    // Don't throw - app should continue even if sync fails
  }
}
```

#### 3. Update AppStartupProvider

**File**: `lib/features/app_startup/application/app_startup_provider.dart`

**Update build() method** (add after line 48):
```dart
// 6. Sync calendar data from Supabase (NEW)
await startupService.syncCalendarData();
```

---

## Architecture Decisions

### Source of Truth
**Supabase is authoritative** - On startup, local data is overwritten with Supabase data if newer.

### Sync Strategy
**Hybrid Approach**:
- **Upload Flow**: User Action → Repository → Edge Function → Supabase → Cache to Drift
- **Download Flow**: App Startup → CalendarSyncService → Supabase → Batch update Drift

### Conflict Resolution
**Last-write-wins (timestamp-based)**:
- Edge function sets `updated_at` on every write
- Sync service compares timestamps
- Supabase wins if `updated_at` is newer than local

### Offline-First Guarantees
**Local-first writes**:
1. Edge function writes to Supabase (authoritative)
2. Cache response locally
3. If edge function fails: User sees error (Phase 4: queue for retry)

**Graceful degradation**:
- Sync failures on startup don't block app launch
- User continues working with local data
- Retry sync on next startup

---

## Testing Checklist (Before Production)

### Edge Functions:
- [ ] Test `save-calendar-activity` create (running)
- [ ] Test `save-calendar-activity` create (cycling)
- [ ] Test `save-calendar-activity` create (swimming)
- [ ] Test `save-calendar-activity` update
- [ ] Test `save-calendar-activity` delete (soft)
- [ ] Test `save-calendar-event` create/update/delete
- [ ] Test `save-carb-loading-plan` 2-day protocol
- [ ] Test `save-carb-loading-plan` 3-day protocol
- [ ] Test `save-carb-loading-plan` cascade delete
- [ ] Test `save-activity-completion` create/update
- [ ] Verify device_id validation works
- [ ] Verify activity ownership validation works

### Sync Service:
- [ ] Test sync with empty local database
- [ ] Test sync with existing local data
- [ ] Test conflict resolution (Supabase newer)
- [ ] Test conflict resolution (local newer)
- [ ] Test sync failure handling (no network)
- [ ] Test sync with large datasets (100+ activities)
- [ ] Verify soft-deleted activities are excluded
- [ ] Verify timestamps are preserved

### Performance:
- [ ] Sync time < 2 seconds for 100 activities
- [ ] Edge function response < 500ms per operation
- [ ] App startup overhead < 1 second
- [ ] Monitor edge function logs in Supabase dashboard

---

## Next Immediate Steps

### Option A: Continue with Integration (Recommended)
1. Integrate edge function calls into repositories (Phase 2.6)
2. Test edge functions locally with real data
3. Create CalendarSyncService (Phase 3)
4. Integrate sync into app startup

### Option B: Test Edge Functions First
1. Write test cases for each edge function
2. Verify all operations work correctly
3. Then proceed with repository integration

### Option C: Create Sync Service in Parallel
1. Build CalendarSyncService now (independent of repository integration)
2. Test download sync immediately
3. Integrate upload sync later when repositories are updated

---

## Files Modified/Created

### Phase 1:
- ✅ `lib/features/calendar/data/activities_repository.dart` (NEW)
- ✅ `lib/features/calendar/data/events_repository.dart` (NEW)
- ✅ `lib/features/calendar/data/carb_loading_repository.dart` (NEW)
- ✅ `lib/features/calendar/data/activity_completions_repository.dart` (NEW)
- ✅ `lib/features/calendar/application/calendar_service.dart` (UPDATED - migration notes)

### Phase 2:
- ✅ `supabase/functions/save-calendar-activity/index.ts` (NEW)
- ✅ `supabase/functions/save-calendar-event/index.ts` (NEW)
- ✅ `supabase/functions/save-carb-loading-plan/index.ts` (NEW)
- ✅ `supabase/functions/save-activity-completion/index.ts` (NEW)

### Phase 2.5:
- ✅ `lib/features/calendar/domain/activity.dart` (UPDATED - added toJson)
- ✅ `lib/features/calendar/domain/event.dart` (UPDATED - added toJson)
- ✅ `lib/features/calendar/domain/activity_completion.dart` (UPDATED - added toJson)

### Phase 3 (Pending):
- ⏳ `lib/features/calendar/application/calendar_sync_service.dart` (TO CREATE)
- ⏳ `lib/features/app_startup/application/app_startup_service.dart` (TO UPDATE)
- ⏳ `lib/features/app_startup/application/app_startup_provider.dart` (TO UPDATE)

---

## Documentation:
- ✅ `/docs/roadmap.md` - Original implementation plan
- ✅ `/docs/roadmap-phase-2-summary.md` - Phase 2 completion summary
- ✅ `/docs/calendar-sync-implementation-status.md` - This document

---

**Last Updated**: 2025-10-28
**Status**: Edge functions deployed to dev, ready for integration
**Author**: Claude Code
