# Activity-Nutrition Linking Refactor Roadmap

## Overview

This document outlines the comprehensive refactor needed to properly link Activities in the calendar system with Nutrition Plans. Currently, these systems are disconnected - nutrition plans are generated but not associated with any calendar activity, causing activities to not appear in the activities list after creation.

## Problem Statement

**Current Broken Flow:**
1. User taps FAB on Activities List → Activity Creation Screen → Running Tab
2. User enters distance/pace/gut training → Presses "Generate"
3. Macros are generated → Navigate to Adjust Macros → Current Plan Screen
4. User presses "Save" → Survey → Back to Activities List
5. **🚨 NO ACTIVITY IS CREATED - List still shows "No activities scheduled"**

**Root Cause:**
- No Activity entity is created in the database during this flow
- Nutrition plans exist in isolation without any activity linkage
- Calendar controller has no activities to display

## Required Architecture Changes

### 1. Database Schema Review

**Existing Tables (Drift):**
- `activities` - Calendar activities with scheduled date/time
- `nutrition_plans` - Generated nutrition plans with macros
- `events` - Race events (special type of activity)

**Required Linkage:**
- `nutrition_plans.activity_id` - Foreign key to activities table
- Each Activity can have 0 or 1 Nutrition Plan
- Nutrition Plan MUST be linked to an Activity

**Action Items:**
- ✅ Review existing schema for activity_id column in nutrition_plans
- 🔲 Add migration if needed
- 🔲 Update NutritionPlan domain model to include activityId field

### 2. Activity Creation Flow

**New Flow:**
```
Activities List (selected date: 2024-01-15)
  ↓ FAB pressed
Activity Creation Screen (receives selectedDate)
  ↓ Running tab
Distance/Pace/Gut Entry Screen
  - Shows date/time picker (initialized with selectedDate, time defaults to 7am)
  - User enters: distance, pace, gut training, temp, humidity
  - User can change date/time
  ↓ "Generate" button pressed
CREATE ACTIVITY IN DATABASE
  - title: "Morning Run" (generated from distance)
  - scheduledDateTime: combine selected date + time
  - distanceMiles: from form
  - paceTargetMinutesPerMile: from form
  - status: planned
  - activityType: running
  - Store activity ID in provider state
  ↓
Generate Macros (pass activity ID)
  ↓
Navigate to Adjust Macros (activity ID in state)
  ↓
Navigate to Activity Detail Screen (activity ID passed)
  ↓ "Save" button
SAVE/UPDATE NUTRITION PLAN
  - Link nutrition plan to activity ID
  - Save to database
  ↓
Survey (if eligible)
  ↓
Navigate to Activities List
REFRESH CALENDAR CONTROLLER
  - Activity now appears in list for its scheduled date! ✅
```

### 3. Implementation Tasks

#### Phase 1: State Management & Data Flow (Est: 1 hour)

**Task 1.1: Update Distance Page Controller to Create Activity**
- File: `lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart`
- Add method: `createActivityAndGeneratePlan()`
- Steps:
  1. Create Activity entity in database via CalendarController
  2. Store activity ID in controller state
  3. Generate macros with activity context
  4. Return activity ID for navigation

**Task 1.2: Update DistancePageGutEntryState to Store Activity ID**
- File: `lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart`
- Add field: `String? activityId`
- Pass through navigation chain

**Task 1.3: Update Navigation to Pass Activity ID**
- File: `lib/features/nutrition_plan/presentation/screens/distance_pace_gut_entry_screen.dart`
- Update `_handleGenerateButtonPress()` to:
  1. Call controller with date/time
  2. Get activity ID from result
  3. Navigate to adjust-macros with activity ID in route params or state

#### Phase 2: Nutrition Plan Linking (Est: 45 minutes)

**Task 2.1: Update NutritionPlan Domain Model**
- File: `lib/features/nutrition_plan/domain/nutrition_plan.dart`
- Add field: `String? activityId`
- Update serialization methods

**Task 2.2: Update Nutrition Plan Repository**
- File: `lib/features/nutrition_plan/data/nutrition_plan_repository.dart`
- Update `savePlan()` to accept and store activityId
- Update all CRUD operations to handle activity linkage

**Task 2.3: Update Nutrition Plan Controller**
- File: `lib/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart`
- Add activityId to state
- Update `savePlan()` method to link to activity
- Ensure activity ID flows through from distance page

#### Phase 3: Activity Detail Screen Integration (Est: 45 minutes)

**Task 3.1: Update Current Plan Screen to Accept Activity ID**
- File: `lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart`
- Add parameter: `String? activityId`
- Load activity details if ID provided
- Show/hide "Save" button based on context:
  - NEW activity (creating for first time): Show "Save"
  - EXISTING activity (viewing from calendar): Show "Save" only if edited

**Task 3.2: Update Adjust Macros Navigation**
- File: `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`
- Pass activity ID to current_plan_screen navigation
- Update route to include activity ID parameter

**Task 3.3: Update Save Logic**
- File: `lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart`
- Update `_handleSavePlan()` to:
  1. Save nutrition plan with activity ID
  2. Update activity status if needed
  3. Navigate properly after save

#### Phase 4: Calendar Refresh & Display (Est: 30 minutes)

**Task 4.1: Ensure Calendar Controller Refreshes**
- File: `lib/features/calendar/presentation/providers/calendar_controller.dart`
- After activity creation, ensure `ref.invalidateSelf()` is called
- Verify that activities are loaded for the correct date range

**Task 4.2: Update Activities List Navigation**
- File: `lib/features/calendar/presentation/screens/activities_list_screen.dart`
- When activity card is tapped → Navigate to Activity Detail with activity ID
- Load existing nutrition plan for that activity

**Task 4.3: Handle "No Nutrition Plan" State**
- If activity exists but has no nutrition plan yet:
  - Show "Create Nutrition Plan" button
  - Navigate to distance/pace screen with activity context (edit mode)

### 4. Navigation Architecture

**Route Updates Needed:**

```dart
// Current routes (broken)
/distance-pace-gut-entry
/adjust-macros
/current-plan

// New routes with activity context
/distance-pace-gut-entry?activityId=<id>  // Edit existing activity
/adjust-macros?activityId=<id>
/activity-detail/:activityId              // View/edit activity with plan
```

**Alternative: Use State Instead of Route Params**
- Pass activity ID through provider state
- Cleaner for complex data flow
- Less URL complexity

**Recommendation: Hybrid Approach**
- Use state for creation flow (distance → adjust → save)
- Use route params when navigating from calendar to existing activity

### 5. Edge Cases & Error Handling

**Case 1: User Exits During Creation**
- Activity is created but nutrition plan is not saved
- Solution: Mark activity as "draft" status, allow completion later

**Case 2: Activity Creation Fails**
- Database error during activity insertion
- Solution: Show error, don't navigate, allow retry

**Case 3: Nutrition Plan Save Fails**
- Activity exists but plan not linked
- Solution: Show error, keep user on activity detail screen, allow retry

**Case 4: Calendar Doesn't Refresh**
- New activity not visible after creation
- Solution: Force refresh via `ref.invalidate()` after save

**Case 5: Editing Existing Activity**
- User taps activity in calendar → Makes changes → Needs to update
- Solution: Detect if activity has ID, update instead of create

### 6. Testing Strategy

**Unit Tests:**
- ✅ Activity creation with valid date/time
- ✅ Nutrition plan linking to activity
- ✅ Activity appears in correct date on calendar
- ✅ Save/update operations work correctly

**Integration Tests:**
- ✅ Full flow: Create activity → Generate plan → Save → Verify in calendar
- ✅ Edit flow: Tap activity → Modify → Save → Verify changes
- ✅ Date change: Create for one date → Changes appear on correct date

**Manual Testing Checklist:**
- [ ] Create activity from activities list FAB
- [ ] Activity uses selected date from calendar
- [ ] Can change date/time in distance page
- [ ] Generate button creates activity in database
- [ ] Activity appears in activities list immediately after save
- [ ] Activity appears on correct date
- [ ] Tapping activity shows nutrition plan details
- [ ] Can edit activity and changes persist
- [ ] Survey flow works correctly
- [ ] Navigation back to activities list works

### 7. File Changes Summary

**New Files:**
- None (all modifications to existing files)

**Modified Files:**
1. `lib/features/nutrition_plan/presentation/screens/distance_pace_gut_entry_screen.dart`
   - Add date/time state management ✅
   - Update generate button handler to create activity

2. `lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart`
   - Add `createActivityAndGeneratePlan()` method
   - Store activity ID in state

3. `lib/features/nutrition_plan/domain/nutrition_plan.dart`
   - Add `activityId` field

4. `lib/features/nutrition_plan/data/nutrition_plan_repository.dart`
   - Update save methods to link activity

5. `lib/features/nutrition_plan/presentation/providers/nutrition_plan_controller.dart`
   - Add activity ID to state
   - Update save logic

6. `lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart`
   - Accept activity ID parameter
   - Conditional save button logic
   - Update save handler

7. `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`
   - Pass activity ID to next screen

8. `lib/features/calendar/presentation/screens/activities_list_screen.dart`
   - Update navigation to pass activity ID ✅
   - Handle empty event widget ✅

9. `lib/features/calendar/presentation/screens/activity_creation_screen.dart`
   - Accept and pass selected date ✅

10. `lib/features/calendar/presentation/widgets/upcoming_event_widget.dart`
    - Show "no events" state ✅

### 8. Database Migration (If Needed)

**Check if migration is required:**
```dart
// Verify nutrition_plans table has activity_id column
// Check: lib/shared/database/tables/nutrition_plans.dart
```

**If missing, create migration:**
```dart
// Add to app_database.dart schema version
@DriftDatabase(
  tables: [...],
  schemaVersion: 2, // Increment
)

// Add migration
MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from == 1) {
      await m.addColumn(nutritionPlans, nutritionPlans.activityId);
    }
  },
)
```

### 9. Implementation Order

**Day 1: Core Linking (2-3 hours)**
1. ✅ Update UpcomingEventWidget to show "no events" state
2. ✅ Pass selected date from activities list to activity creation
3. ✅ Add date/time picker to distance pace gut entry screen
4. 🔲 Update distance controller to create activity + generate macros
5. 🔲 Update nutrition plan domain model with activityId
6. 🔲 Update nutrition plan repository to save with activity link

**Day 2: Integration & Testing (1-2 hours)**
7. 🔲 Update current_plan_screen with activity ID parameter
8. 🔲 Update save logic to link nutrition plan
9. 🔲 Ensure calendar refreshes after activity creation
10. 🔲 Test full flow end-to-end
11. 🔲 Fix any bugs found during testing

### 10. Success Criteria

✅ **Working Flow:**
- User selects date in calendar (e.g., Jan 15)
- Taps FAB → Creates activity
- Date/time picker shows Jan 15, 7:00 AM (editable)
- Enters distance/pace → Generates plan
- Activity is created in database with Jan 15 date
- Saves nutrition plan → Survey → Back to activities list
- **Activity appears in calendar on Jan 15!** ✅

✅ **Editing Flow:**
- User taps existing activity in calendar
- Activity detail screen loads with nutrition plan
- Can make changes → Save updates activity and plan
- Changes persist and appear in calendar

✅ **No Regressions:**
- Events still work correctly
- Carb loading integration unaffected
- Existing navigation patterns preserved
- All other features continue to work

## Risks & Mitigation

**Risk 1: Breaking Existing Nutrition Plan Flow**
- Mitigation: Add activity ID as optional field initially
- Support both legacy (no activity) and new (with activity) flows

**Risk 2: Database Migration Issues**
- Mitigation: Test migration on dev database first
- Have rollback plan ready

**Risk 3: Navigation Complexity**
- Mitigation: Document navigation flow clearly
- Use consistent patterns (state vs route params)

**Risk 4: Performance Impact**
- Mitigation: Ensure calendar queries are optimized
- Add indexes if needed for activity lookups

## Post-Implementation

**Documentation Updates:**
- Update /docs/features/calendar/README.md with activity-nutrition flow
- Add architecture diagram showing entity relationships
- Document navigation patterns for future developers

**Code Review Focus:**
- Verify all navigation paths work correctly
- Check error handling is robust
- Ensure state management follows Riverpod patterns
- Confirm database operations are atomic

**Future Enhancements:**
- Allow multiple nutrition plans per activity (future feature)
- Add nutrition plan templates for common activities
- Implement nutrition plan copying between activities
- Add nutrition plan versioning/history

---

**Status:** 🟡 In Progress - Phases 1-3 started
**Last Updated:** 2025-01-08
**Owner:** AI Assistant + Lee Martin
