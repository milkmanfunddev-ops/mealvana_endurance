# Next Steps After Wave 2 Completion
**Updated:** 2025-11-17

## Wave 2 Status: ✅ COMPLETE

### What We Just Finished

Successfully migrated from global `NutritionPlanController` to activity-scoped nutrition plan management:

- **Deleted:** NutritionPlanController (724 lines)
- **Added:** Food CRUD methods to ActivityDetailController
- **Updated:** All UI screens to use single controller
- **Fixed:** DataSyncService to sync nutrition_plan_data
- **Result:** 420 → 100 analyzer errors (**76% reduction**)

📄 **Full Details:** [Session Summary](session-2025-11-17-controller-migration.md)

---

## Immediate Next Steps (Priority Order)

### 1. Edge Function Compatibility Testing (High Priority)

**Why:** Ensure nutrition_plan_data syncs correctly between client and Supabase.

**Tasks:**
```bash
# Test save-calendar-activity edge function
curl -X POST https://[PROJECT].supabase.co/functions/v1/save-calendar-activity \
  -H "Authorization: Bearer [ANON_KEY]" \
  -d '{
    "device_id": "test-user",
    "activity": {
      "id": 1,
      "nutritionPlanData": "{\"sections\":[...]}",
      ...
    },
    "operation": "update"
  }'

# Test sync-all-data edge function
curl -X POST https://[PROJECT].supabase.co/functions/v1/sync-all-data \
  -H "Authorization: Bearer [ANON_KEY]" \
  -d '{"device_id": "test-user"}'
# Verify response includes nutrition_plan_data in activities
```

**Expected Behavior:**
- `save-calendar-activity` accepts nutritionPlanData JSON string
- `sync-all-data` returns nutrition_plan_data for activities
- Round-trip preserves JSON structure

**Files to Check:**
- `supabase/functions/save-calendar-activity/index.ts`
- `supabase/functions/sync-all-data/index.ts`

---

### 2. Wave 0 Completion (Medium Priority)

**Remaining Work:** Convert remaining String IDs to int IDs

**Files to Update:**
1. `lib/features/activities/domain/activity_completion.dart`
   - Change `activityId` from String to int
   - Update all references

2. `lib/features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart`
   - Update carb loading day/plan IDs to int

3. `lib/shared/core/app_router.dart`
   - Update router extras to pass int IDs

**Expected Impact:** ~45% of remaining 100 errors (~45 errors fixed)

---

### 3. Wave 1 Completion (Low Priority)

**Remaining Work:** Remove deprecated table/payload references

**Tasks:**
1. Search for and remove any lingering references:
```bash
grep -r "macro_targets_table" lib/
grep -r "workout_notes_table" lib/
grep -r "mealTypes" lib/
grep -r "product_types" lib/
grep -r "device_id" lib/shared/services/sync/
```

2. Update edge functions to reject deprecated keys
3. Document final API contract in `docs/api_documentation.txt`

**Expected Impact:** ~15% of remaining errors (~15 errors fixed)

---

## Future Enhancements (Post-Wave 3)

### Performance Optimizations
- [ ] Add database indexes for nutrition plan queries
- [ ] Implement lazy loading for large nutrition plans
- [ ] Cache parsed plans in memory
- [ ] Profile JSON parsing performance

### Feature Improvements
- [ ] Implement macro target recalculation in food operations
- [ ] Add optimistic updates with rollback for better UX
- [ ] Implement conflict resolution for concurrent edits
- [ ] Add plan versioning for undo/redo functionality
- [ ] Create migration tool for legacy nutrition_plans table data

### Architecture Patterns to Apply
The activity-owned nutrition pattern can be applied to:
- Event notes (embed in events.notes JSON)
- Activity reminders (embed in activities.reminder_config JSON)
- User preferences (embed in users.preferences JSON)
- Feature flags (embed in users.feature_flags JSON)

---

## Success Metrics

### Current Status
- **Analyzer Errors:** 100 (down from 420, 76% reduction)
- **Nutrition-Related Errors:** 0 ✅
- **Controller-Related Errors:** 0 ✅
- **Code Reduction:** -324 lines net

### Target for Production
- **Analyzer Errors:** <50 (50% more reduction needed)
- **Wave 0 Complete:** All IDs are int
- **Wave 1 Complete:** No deprecated table references
- **Wave 3 Complete:** Edge functions tested and verified

---

## Quick Reference Commands

```bash
# Check analyzer status
flutter analyze 2>&1 | tail -5

# Check for nutrition-related errors
flutter analyze 2>&1 | grep -i "nutrition"

# Check for deprecated table references
grep -r "macro_targets_table\|workout_notes_table\|nutrition_plans_table" lib/

# Check for String ID issues
grep -r "activityId.*String\|planId.*String" lib/

# View git status
git status --short

# View recent changes to key files
git diff HEAD -- lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart
git diff HEAD -- lib/shared/services/sync/data_sync_service.dart
```

---

## Documentation Index

- **This File:** Next steps roadmap
- [PHASE-3-ROADMAP.md](PHASE-3-ROADMAP.md) - Overall phase status
- [session-2025-11-17-controller-migration.md](session-2025-11-17-controller-migration.md) - Wave 2 details
- [session-2025-11-16-nutrition-data-integration.md](session-2025-11-16-nutrition-data-integration.md) - Domain model integration
- [COMPLETE-MIGRATION-ROADMAP.md](COMPLETE-MIGRATION-ROADMAP.md) - High-level migration status

---

**Last Updated:** 2025-11-17
**Next Session Focus:** Edge function compatibility testing
