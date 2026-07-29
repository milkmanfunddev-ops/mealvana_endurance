# Integration Sync Update - Design Decisions

## Summary

This document captures the finalized design decisions for handling workout schedule changes from Training Peaks and Final Surge.

---

## Core Design Decisions

### 1. Sync Strategy: On-Demand via `ensureSynced()`

**Decision**: Use existing `SyncableRepository` pattern - no separate background sync.

**How it works**:
1. User opens Activities screen or Activity Detail
2. Controller calls `ensureSynced('activities', userId, repository: repo)`
3. If stale (>1 hour since last sync) → sync from provider API
4. Detect changes, update local activities, flag stale nutrition plans
5. Return fresh data to UI

**Benefits**:
- Consistent with existing sync architecture
- No heavy app startup sync
- Only syncs when user actually needs the data
- Reuses existing staleness tracking infrastructure

**Staleness Threshold**: 1 hour (same as other repositories)

---

### 2. Nutrition Plan Handling: Mark as Stale + Warn

**Decision**: Keep existing nutrition plan but show warning banner when schedule changed.

**Implementation**:
- When sync detects schedule change → set `needs_nutrition_refresh = true` on activity
- Activity Detail screen shows warning banner: "Schedule changed since this plan was generated"
- Single action button: **"Regenerate Plan"**
- User decides whether to regenerate or keep existing plan

**Why this approach**:
- Preserves user customizations (food swaps, notes)
- Gives user control over when to regenerate
- Non-destructive - no data lost automatically

---

### 3. Deleted Workout Handling: Soft-Delete Locally

**Decision**: Mark activity as "removed from provider" but keep all data.

**Implementation**:
- Add `provider_deleted_at` timestamp column (or use existing `deleted_at`)
- Activity remains visible with visual indicator
- User can manually delete or convert to manual activity

**UI Treatment**:
- Show subtle badge/icon: "Removed from Training Peaks"
- Activity still appears on calendar
- User can tap to view details and decide action

---

### 4. UI Location: Activity Detail Header Only

**Decision**: Show "Last updated" timestamp and refresh button in activity detail header only.

**Implementation**:
- Location: Below activity title in hero section
- Format: "Last updated: Jan 16, 2026 at 3:42 PM"
- Refresh icon button next to timestamp
- Show loading indicator during refresh

**Not included** (to keep UI clean):
- No sync indicators on activity cards in list view
- No floating action button
- Pull-to-refresh on list is already sufficient for bulk sync

---

### 5. Single Activity Refresh: Sync Just That Activity

**Decision**: When user taps refresh button, only fetch that specific workout from provider.

**Implementation**:
- Call provider API for single workout by `provider_workout_id`
- Compare with local data
- Update if changed, show confirmation
- Fast and focused operation

**API Methods Needed**:
- Final Surge: `getWorkoutById(accessToken, workoutKey)`
- Training Peaks: `getWorkoutById(accessToken, workoutId)`

---

### 6. Proactive Alerts: None (Silent Sync)

**Decision**: No push notifications or in-app banners about sync results.

**User experience**:
1. Sync happens silently via `ensureSynced()` when needed
2. If changes detected → activities updated, nutrition plans flagged
3. User opens activity → sees "stale plan" warning banner contextually
4. User taps "Regenerate Plan" if desired

**Why this approach**:
- Less intrusive
- Contextual warnings are more actionable
- Avoids notification fatigue

---

## Implementation Scope: Full

**Included in implementation**:
- Phase 1: Timestamps + refresh button + basic change detection
- Phase 2: Full change detection with update/delete handling
- Phase 3: Smart nutrition staleness flagging + regeneration prompt

---

## Data Flow Diagram

```
User opens Activities List or Activity Detail
    ↓
ActivitiesController.build()
    ↓
syncCoordinator.ensureSynced('activities', userId, repository: activitiesRepo)
    ↓
Is stale? (>1 hour since last sync)
    ├── No → Return cached data from Drift
    └── Yes → Continue
    ↓
Check for active integrations (Final Surge / Training Peaks)
    ├── None → Standard activities sync only
    └── Has integration → Continue
    ↓
Fetch workouts from provider API
    ↓
ChangeDetectionService.detectChanges(localActivities, providerWorkouts)
    ↓
For each change type:
    ├── NEW → Insert activity with synced_from_provider
    ├── UPDATED → Update activity + flag needs_nutrition_refresh if schedule changed
    └── DELETED → Set provider_deleted_at timestamp
    ↓
Update integrations.last_sync_at
    ↓
Return activities from Drift
    ↓
UI displays activities
    ↓
User taps activity with needs_nutrition_refresh = true
    ↓
Show warning banner: "Schedule changed since plan was generated"
    ↓
User taps "Regenerate Plan" → Generate new nutrition plan
```

---

## Database Changes Required

### Activities Table Additions

```sql
-- Flag for nutrition plan staleness
needs_nutrition_refresh BOOLEAN DEFAULT FALSE,

-- When provider deleted this workout (soft delete)
provider_deleted_at TIMESTAMP,

-- Original provider schedule for change detection
provider_scheduled_at TIMESTAMP,

-- Track when we last detected a change
schedule_changed_at TIMESTAMP
```

### Integrations Table (Existing - No Changes)

Already has:
- `last_sync_at` - Used for staleness check
- `last_sync_status` - 'success', 'error', 'pending'
- `last_sync_error` - Error message

---

## Files to Create/Modify

### New Files
- `/lib/features/integrations/domain/sync_change_result.dart`
- `/lib/features/integrations/application/change_detection_service.dart`
- `/lib/features/integrations/presentation/widgets/sync_status_widget.dart`
- `/lib/features/nutrition_plan/presentation/widgets/stale_plan_warning.dart`

### Modified Files
- `/lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`
- `/lib/features/integrations/application/final_surge_sync_service.dart`
- `/lib/features/integrations/application/training_peaks_sync_service.dart`
- `/lib/features/activities/data/activities_repository.dart`
- `/lib/shared/database/tables/activities_table.dart` (if adding columns)

---

## Open Questions (Resolved)

| Question | Decision |
|----------|----------|
| What happens to nutrition plan when schedule changes? | Mark as stale + show warning |
| What happens when workout deleted in provider? | Soft-delete locally |
| Where to show refresh UI? | Activity detail header only |
| How to sync? | On-demand via ensureSynced() |
| Sync frequency? | 1 hour staleness threshold |
| Proactive notifications? | None - silent sync |
| Single activity refresh? | Fetch just that workout |
| Warning banner actions? | Single "Regenerate Plan" button |
