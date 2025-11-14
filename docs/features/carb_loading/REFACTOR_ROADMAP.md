# Carb Loading Food Retrieval & UI Refactor Roadmap

**Status:** 🟡 In Progress
**Priority:** P0 - Critical User-Facing Issue
**Owner:** AI Assistant + Lee Martin
**Created:** 2025-11-13
**Target Completion:** 2025-11-14

---

## Executive Summary

### What We're Doing
Refactoring the carb loading feature to:
1. **Remove edge function dependency** for food retrieval - Use direct Supabase queries instead
2. **Update UI to Kyle's design system** - Match the new visual design shown in mockups

### Why This Matters
**Current Problems:**
- ✅ Foods ARE being synced (27 foods confirmed in logs)
- ❌ Foods NOT appearing in UI (filtering issue + edge function complexity)
- ❌ UI doesn't match Kyle's new design system
- ❌ Inconsistent with rest of codebase (events, activities, feedback all use direct queries)

**Expected Benefits:**
- ✅ Foods will display correctly in selection screens
- ✅ Faster data retrieval (no edge function roundtrip)
- ✅ More reliable (fewer failure points)
- ✅ Consistent architecture across entire app
- ✅ Professional UI matching design system
- ✅ Easier to debug and maintain


### Risks and Mitigation
| Risk | Impact | Mitigation |
|------|--------|------------|
| RLS policies not configured | Food retrieval fails | Verify policies exist before deploying |
| meal_type_ids column format mismatch | Foods filtered incorrectly | Test array parsing thoroughly |
| UI regression on other screens | User experience degraded | Only modify carb loading screens |
| Breaking changes in production | Users can't access carb loading | Deploy to dev first, thorough testing |

---

## Current State Analysis

### How Food Sync Currently Works

**Architecture Flow:**
```
App Startup
  ↓
sync-all-data Edge Function
  ↓
Returns: { carb_loading_foods: [...] }
  ↓
CarbLoadingFoodSyncService.syncFromDownloadedData()
  ↓
Converts meal_type_ids → PostgreSQL array format {1,2,3}
  ↓
Saves to local Drift database
  ↓
✅ SUCCESS: 27 foods synced (confirmed in logs)
```

**The Problem:**
```dart
// File: carb_loading_food_repository.dart:26
Future<List<domain.CarbLoadingFood>> getFoodsByMealType(int mealTypeId) async {
  final allFoods = await query.get();

  return allFoods
    .where((food) {
      if (food.mealTypes == null) return false;  // ❌ PROBLEM: Returns empty if null
      final mealTypes = _parseMealTypesArray(food.mealTypes);
      return mealTypes.contains(mealTypeId);
    })
    .map((food) => _convertToFoodDomain(food))
    .toList();
}
```

**Root Cause:**
- Either `meal_type_ids` is not in the downloaded data
- Or the array format isn't being parsed correctly
- Or the edge function isn't returning the field


### Current UI State vs. Kyle's Design

**Current Screen** (`carb_loading_day_detail_page.dart`):
- Old theme colors (AppTheme.baseCream)
- Gradient header cards
- Old button styles
- Inconsistent spacing

**Kyle's Design** (`/docs/kyle/carb_loading_status.png`):
- Clean white background
- Top progress card: "0g / 610g" with "Edit Target" button
- Meal section cards with:
  - Meal name on left (e.g., "Lunch")
  - Progress badge on right (e.g., "0/153g")
  - Pink/rose + button for adding foods
- Proper spacing using AppSpacing constants
- Colors from AppColors palette

---

## Technical Approach

### Architecture Change

**Before (Current - Bad):**
```
App → get-carb-loading-foods Edge Function → Supabase → Edge Function → App
```
- Extra latency (~200-500ms)
- Extra failure point (edge function can fail)
- Harder to debug
- Inconsistent with rest of codebase

**After (Target - Good):**
```
App → Supabase directly (with RLS) → App
```
- Faster (~50-100ms)
- More reliable
- Easier to debug
- Consistent with feedback_repository, events_repository patterns

### Reference Implementations

**1. feedback_repository.dart** - Direct Supabase Insert
```dart
await _supabase.from('feedback').insert(feedbackData).select();
```

**2. events_repository.dart** - Direct Supabase Upsert (just refactored!)
```dart
await _supabase.from('events').upsert({...});
```

**3. carb_loading_repository.dart** - Direct Supabase Upsert (just refactored!)
```dart
await _supabase.from('carb_loading_plans').upsert({...});
await _supabase.from('carb_loading_days').upsert({...});
```

---

## Phase 1: Fix Food Retrieval (Remove Edge Functions)

### Files to Modify

#### 1. `lib/features/carb_loading/application/carb_loading_food_sync_service.dart`

**Current (Lines 30-43) - REMOVE:**
```dart
final response = await _supabase.functions.invoke(
  'get-carb-loading-foods',
  body: {'meal_type_id': null},
);
```

**Change To - DIRECT QUERY:**
```dart
// Direct Supabase query - no edge function needed!
final response = await _supabase
  .from('carb_loading_foods')
  .select('id, name, display_name, display_name_plural, carbs_per_serving, '
          'image_address, is_default, meal_type_ids, created_at')
  .order('display_name');

final List<dynamic> foodsData = (response as List<dynamic>);
```

