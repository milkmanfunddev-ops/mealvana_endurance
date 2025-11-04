# Edge Functions Cleanup Strategy

## Overview

After implementing the unified `sync` edge function, we can safely remove redundant READ-only functions that are now handled by the sync endpoint. This document outlines which functions to keep and which to remove.

---

## Edge Functions Inventory

### ✅ Functions to KEEP (18 total)

#### Read Operations - Fallbacks (2 functions)
Kept as fallbacks for data recovery scenarios:

| Function | Purpose | Why Keep |
|----------|---------|----------|
| `get-foods` | Fetch nutrition plan foods | Fallback for manual refresh & data recovery |
| `get-carb-loading-foods` | Fetch carb loading foods + meal types | Fallback for manual refresh & data recovery |

#### Write Operations (7 functions)
User-initiated actions that modify data in Supabase:

| Function | Purpose | Why Keep |
|----------|---------|----------|
| `save-calendar-activity` | Create/update/delete activities | User writes data |
| `save-calendar-event` | Create/update/delete events | User writes data |
| `save-user-food` | Add custom foods | User writes data |
| `save-food-preferences` | Update liked/disliked foods | User writes data |
| `save-carb-loading-plan` | Create carb loading plans | User writes data |
| `save-activity-completion` | Log activity completion data | User writes data |
| `delete-user-food` | Remove custom foods | User writes data |

#### Business Logic (4 functions)
Computation-heavy operations that can't be done client-side:

| Function | Purpose | Why Keep |
|----------|---------|----------|
| `generate-nutrition-plan` | AI-powered nutrition plan generation | Complex LLM + linear programming |
| `generate-macros` | Calculate macro targets | Server-side calculations |
| `create-nutrition-plan` | Create and validate nutrition plans | Business logic validation |
| `create-user` | User registration and device validation | Server-side user management |

#### External APIs (4 functions)
Third-party service integrations:

| Function | Purpose | Why Keep |
|----------|---------|----------|
| `barcode-lookup` | Product barcode scanning (primary) | External API integration |
| `lookup-product` | Product barcode scanning (fallback) | External API integration |
| `get-weather-forecast` | Weather data for activities | External API integration |
| `send-nutrition-plan-email` | Share plans via email | External service integration |

#### Unused/Legacy (1 function - investigate)
| Function | Purpose | Status |
|----------|---------|--------|
| `carb-loading` | Unknown - needs investigation | Review and potentially remove |

---

### ✅ Functions to KEEP as Fallbacks (2 additional)

These READ-only functions are primarily replaced by unified `sync` during startup, but must be kept as fallbacks for data recovery scenarios:

| Function | Purpose | When Used |
|----------|---------|-----------|
| `get-foods` | Fetch nutrition plan foods | **Fallback**: Manual refresh, data recovery, troubleshooting |
| `get-carb-loading-foods` | Fetch carb loading foods + meal types | **Fallback**: Manual refresh, data recovery, troubleshooting |

**Usage Pattern**:
- **Primary (99%)**: App startup uses unified `sync` endpoint
- **Fallback (1%)**: Direct calls when food data needs recovery

**Scenarios for Fallback Functions**:
1. User reports missing foods in UI
2. Database corruption detected
3. Manual "Refresh Food Data" button in settings (future feature)
4. Developer troubleshooting tools
5. Partial sync failure (only foods affected)

**Why Keep Them**:
- Data recovery: If food data becomes corrupted or missing
- Backwards compatibility: Older app versions may still call them
- Granular control: Ability to refresh specific data types
- Debugging: Developers can test individual data sources
- Resilience: Multiple paths to restore critical data

---

## Unified Sync Architecture

### Before (7 network calls)
```
Client App Startup
├─ get-foods()                          [200ms]
├─ get-carb-loading-foods()             [200ms]
├─ Supabase.from('activities').select() [200ms]
├─ Supabase.from('events').select()     [200ms]
├─ Supabase.from('carb_loading_plans')  [200ms]
├─ Supabase.from('carb_loading_days')   [200ms]
└─ Supabase.from('activity_completions')[200ms]

Total: ~1.4-1.5s
```

### After (1 network call)
```
Client App Startup
└─ sync()  [300-500ms]
    ├─ Returns: foods (21 items)
    ├─ Returns: carb_loading.foods (27 items)
    ├─ Returns: carb_loading.meal_types (7 items)
    └─ Returns: user_data (activities, events, plans, days, completions)

Total: ~0.3-0.5s
```

**Performance Improvement**: 70% faster (1.5s → 0.5s)

---

## Response Size Analysis

### Current Approach (7 responses)
```
get-foods:              ~15KB (21 foods with full metadata)
get-carb-loading-foods: ~12KB (27 foods + 7 meal types)
activities:             ~5KB  (varies by user)
events:                 ~3KB  (varies by user)
carb_loading_plans:     ~2KB  (varies by user)
carb_loading_days:      ~4KB  (varies by user)
activity_completions:   ~6KB  (varies by user)

Total: ~47KB + HTTP overhead (7 requests × ~500 bytes = 3.5KB)
Total with overhead: ~50.5KB
```

### Unified Approach (1 response)
```
sync() single response: ~47KB + HTTP overhead (1 request × 500 bytes)

Total with overhead: ~47.5KB
```

**Bandwidth Saved**: ~3KB per startup (6% reduction)
**Latency Saved**: ~1 second (70% reduction)

---

## Migration Checklist

### Phase 1: Deploy Unified Sync
- [ ] Create `supabase/functions/sync/index.ts`
- [ ] Deploy sync function to dev environment
- [ ] Test with empty database
- [ ] Test with existing user data
- [ ] Deploy to production

### Phase 2: Update Client
- [ ] Create `UnifiedSyncService`
- [ ] Update `AppStartupService` to use unified sync
- [ ] Remove old sync method calls
- [ ] Test cold start
- [ ] Test warm start
- [ ] Deploy client update

### Phase 3: Monitor & Validate
- [ ] Monitor error rates for sync function
- [ ] Check analytics: old function invocations should drop to zero
- [ ] Verify no production errors related to sync
- [ ] Wait 1-2 weeks to ensure stability

### Phase 4: Document Fallback Usage
- [ ] Add comments to `get-foods` explaining fallback usage
- [ ] Add comments to `get-carb-loading-foods` explaining fallback usage
- [ ] Document when to use fallback functions
- [ ] Keep functions deployed (no removal)

### Phase 5: Implement Manual Refresh (Future Enhancement)
- [ ] Add "Refresh Food Data" button in settings
- [ ] Call `get-foods` when user triggers manual refresh
- [ ] Add error handling and user feedback
- [ ] Track usage analytics for fallback calls

---

## Rollback Strategy

If issues arise after deploying unified sync:

### Immediate Rollback (< 5 minutes)
```dart
// In app_startup_provider.dart, revert to:
await _appStartupService.checkAndRefreshFoodData();
await _appStartupService.syncCalendarData();
// Instead of:
await _appStartupService.syncAllData();
```

### Full Rollback (if needed)
1. Client code: Revert PR that introduced `UnifiedSyncService`
2. Old services still exist (marked deprecated but functional)
3. Old edge functions remain deployed (no need to redeploy)
4. Hot restart app or push emergency update

**Critical**: Don't delete old edge functions until client is updated and stable for 2+ weeks.

---

## Testing Strategy

### Unit Tests
- [ ] Test sync with no user (anonymous)
- [ ] Test sync with user_id
- [ ] Test sync with network error
- [ ] Test sync with partial data
- [ ] Test sync with empty tables

### Integration Tests
- [ ] Test cold start (empty local DB)
- [ ] Test warm start (cached data)
- [ ] Test sync failure graceful handling
- [ ] Test offline mode (use cached data)

### Performance Tests
- [ ] Measure sync time on slow network (3G)
- [ ] Measure sync time on fast network (WiFi)
- [ ] Compare before/after startup times
- [ ] Verify 70% improvement target

---

## Success Criteria

- [x] Unified sync function created and tested
- [ ] Client updated to use unified sync for startup
- [ ] Startup time reduced by 60%+ (target: 70%)
- [ ] No increase in error rates
- [ ] Old GET functions calls drop to <1% (only fallback usage)
- [ ] Fallback functions documented and kept for recovery
- [ ] Manual refresh functionality implemented (optional)
- [ ] Documentation updated with fallback strategy

---

## Future Optimizations

Once unified sync is stable, consider these enhancements:

### 1. Incremental Sync
Add `last_synced_at` parameter to only return changed records:
```typescript
// Request
{ user_id: "...", last_synced_at: "2025-10-28T12:00:00Z" }

// Response (only changed data)
{
  foods: [], // empty if no changes
  carb_loading: { foods: [], meal_types: [] },
  user_data: {
    activities: [/* only new/updated since last_synced_at */],
    events: [/* only new/updated */],
    ...
  }
}
```

**Benefits**:
- Reduce response size by 80-90% on subsequent syncs
- Faster sync after first launch

### 2. Compression
Enable gzip compression on sync response:
```typescript
headers: {
  'Content-Encoding': 'gzip',
  ...corsHeaders
}
```

**Benefits**:
- Reduce bandwidth by ~60%
- Faster on slow networks

### 3. Sync on Demand
Add manual refresh button in UI:
- User pulls to refresh
- Calls sync function
- Updates local database
- Shows toast notification

### 4. Background Sync
Periodic background sync (when app is in background):
- Every 24 hours
- Only if on WiFi
- Only if battery > 20%
- Use WorkManager (Android) / Background Tasks (iOS)

---

## Notes

- **No authentication required**: The unified sync works for both anonymous and authenticated users
- **Full sync only**: Incremental sync can be added later if needed
- **Error handling**: Sync failures are logged but don't block app startup
- **Offline-first**: App continues with cached data if sync fails
- **Atomic operations**: All data synced in single transaction (all or nothing)
