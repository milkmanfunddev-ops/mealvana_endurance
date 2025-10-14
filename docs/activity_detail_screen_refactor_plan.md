# Activity Detail Screen Refactor - Comprehensive Plan

## Overview
This document outlines the complete architectural refactor to transform the Current Plan Screen into a unified Activity Detail Screen that handles both activity creation and viewing/editing nutrition plans.

---

## Research Summary

### Current Architecture

**Flow:**
1. User enters distance/pace/gut → `DistancePaceGutEntryScreen`
2. System generates macro targets → `AdjustMacrosScreen`
3. User creates nutrition plan → `CurrentPlanScreen`

**Key Files:**
- `lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart` - Shows nutrition plan after creation
- `lib/features/calendar/presentation/screens/activities_list_screen.dart` - Lists activities with swipe-to-delete
- `lib/features/calendar/presentation/providers/calendar_controller.dart` - Manages activities
- `lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart` - Handles macro generation and activity creation

**Domain Models:**
- `Activity` - Has scheduledDateTime, title, type, distance, pace, intensity, notes, isEvent, isCompleted
- `NutritionPlan` - Has activityId (links to Activity), planRating, journalNotes, runDateTime
- `ActivityCompletion` - Has effortRating (1-5), nutritionRating (1-5), overallSatisfaction (1-5), textNotes, voiceNoteId, hasVoiceRecording, weatherConditions, etc.

**Existing Infrastructure:**
- Date/time picker already implemented in current_plan_screen.dart
- Workout notes table in database (planId, rating, noteText)
- ActivityCompletion with comprehensive feedback fields
- CalendarController.completeActivity() method already exists

---

## Problem Statement

**Current Issues:**
1. Activity is created immediately during macro generation (too early)
2. No way to edit activity details after creation
3. Screen name "Current Plan Screen" doesn't reflect its purpose
4. No integrated workflow for completing activities and logging feedback
5. No clear distinction between "create mode" and "view/edit mode"

**User Requirements:**
1. Show date/time on "Schedule your run" section with 7am default
2. Add "Save" button for new activities - don't create until pressed
3. Delay activity creation until user presses Save
4. Rename to "Activity Detail Screen"
5. Make nutrition plan editable with Save button
6. Add workout journal/notes section
7. Always show "Complete Workout" button
8. After completion: show rating UI (1-5) and workout note entry
9. Navigate to tabs screen after saving new activity

---

## Solution Architecture

### 1. Screen Modes

**Create Mode:**
- Triggered when: User goes through distance/pace/gut → adjust-macros flow
- State: Activity does NOT exist yet
- UI:
  - Date/time picker (default to next Saturday 7am)
  - Generated macro targets (read-only)
  - Save button at bottom
  - NO Complete Workout button (activity doesn't exist)
- Actions:
  - Save: Creates activity + nutrition plan, navigates to tabs screen
  - Back: Discards changes, returns to previous screen

**View/Edit Mode:**
- Triggered when: User taps existing activity from calendar
- State: Activity exists, may or may not have nutrition plan
- UI:
  - Date/time picker (editable)
  - Nutrition plan (editable with Save button)
  - Complete Workout button (always visible)
  - Workout journal section (if completed)
- Actions:
  - Save: Updates activity + nutrition plan
  - Complete Workout: Shows rating UI → saves ActivityCompletion
  - Back: Returns to calendar

---

## Implementation Plan

### Phase 1: Refactor Activity Creation Flow

**Step 1.1: Update DistancePageGutEntryController**
- Remove `CalendarController.createActivity()` call from `createNutritionPlan()`
- Store macro targets and activity data in state instead
- Pass data to Activity Detail Screen via navigation extras

**Files to modify:**
- `lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart`

**Changes:**
```dart
// BEFORE
final activityId = await calendarController.createActivity(...);

// AFTER
// Store activity data in state, don't create yet
state = AsyncData(state.value!.copyWith(
  pendingActivityData: ActivityCreationData(
    title: activityTitle,
    scheduledDateTime: scheduledDateTime,
    distanceMiles: distance,
    paceMinutes: paceMinutes,
  ),
));
```

**Step 1.2: Update AdjustMacrosScreen Navigation**
- Pass activity data and macro targets via GoRouter extra parameter
- Navigate to `/activity-detail` with mode='create'

**Files to modify:**
- `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`

**Changes:**
```dart
context.push('/activity-detail', extra: {
  'mode': 'create',
  'activityData': pendingActivityData,
  'macroTargets': macroTargets,
});
```

---

### Phase 2: Rename and Refactor Current Plan Screen

**Step 2.1: Rename Files**
- Rename `current_plan_screen.dart` → `activity_detail_screen.dart`
- Update all import statements across codebase

**Files to rename:**
- `lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart` → `activity_detail_screen.dart`

**Files to update imports:**
- `lib/shared/core/app_router.dart`
- Any other files importing current_plan_screen.dart

**Step 2.2: Update App Router**
- Change route from `/current-plan` → `/activity-detail`
- Add support for passing mode + data via extra parameter

**Files to modify:**
- `lib/shared/core/app_router.dart`

**Changes:**
```dart
GoRoute(
  path: '/activity-detail',
  builder: (context, state) {
    final extra = state.extra as Map<String, dynamic>?;
    return ActivityDetailScreen(
      mode: extra?['mode'] ?? 'view',
      activityId: extra?['activityId'],
      activityData: extra?['activityData'],
      macroTargets: extra?['macroTargets'],
    );
  },
),
```

---

### Phase 3: Create Activity Detail Controller

**Step 3.1: Create New Controller**
- Create `activity_detail_controller.dart` following FOA AsyncNotifier pattern
- Handle both create and edit modes
- Manage activity creation, updates, completion

**New file:**
- `lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart`

**Controller State:**
```dart
class ActivityDetailState {
  final String mode; // 'create' or 'view'
  final Activity? activity;
  final NutritionPlan? nutritionPlan;
  final ActivityCompletion? completion;
  final MacroTargets? macroTargets;
  final DateTime scheduledDateTime;
  final bool isSaving;
  final bool isCompleting;
  final String? error;
}
```

**Key Methods:**
```dart
Future<void> saveActivity() async {
  // Create mode: Create activity + nutrition plan
  // View mode: Update activity + nutrition plan
}

Future<void> completeActivity({
  required int effortRating,
  required int nutritionRating,
  required int overallSatisfaction,
  String? textNotes,
}) async {
  // Call CalendarController.completeActivity()
  // Update state with completion data
}

Future<void> updateScheduledDateTime(DateTime newDateTime) async {
  // Update scheduled date/time
}
```

**Step 3.2: Implement Business Logic**
- Activity creation (only in create mode)
- Activity updates (both modes)
- Nutrition plan creation/updates
- Activity completion with ratings
- Date/time updates

---

### Phase 4: Rebuild Activity Detail Screen UI

**Step 4.1: Screen Structure**
- Header with date/time picker
- Nutrition plan section (editable)
- Action buttons (mode-dependent)
- Workout journal section (if completed)

**Files to modify:**
- `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart` (renamed from current_plan_screen.dart)

**UI Sections:**

1. **Header Section:**
   - Activity title
   - Date/time picker with edit button
   - Default: Next Saturday at 7:00 AM (create mode)

2. **Nutrition Plan Section:**
   - Before/During/After run food items
   - Macro targets display
   - Edit button (view mode only)
   - Generated automatically in create mode

3. **Action Buttons (Create Mode):**
   - Save button (primary action)
   - Cancel/Back button

4. **Action Buttons (View Mode):**
   - Save Changes button (if edited)
   - Complete Workout button (always visible)

5. **Workout Journal Section (View Mode, If Completed):**
   - Completion date/time
   - Ratings display (effort, nutrition, overall)
   - Text notes
   - Voice note indicator

**Step 4.2: Implement Complete Workout Flow**
- Show bottom sheet with rating UI
- 3 sliders: Effort (1-5), Nutrition (1-5), Overall (1-5)
- Text area for workout notes
- Save button to create ActivityCompletion

**New Widget:**
```dart
class CompleteWorkoutBottomSheet extends ConsumerStatefulWidget {
  // Rating sliders (1-5)
  // Text notes field
  // Save button
}
```

---

### Phase 5: Navigation Updates

**Step 5.1: Update Navigation After Save**
- Create mode: Navigate to `/main` (tabs screen) after successful save
- View mode: Stay on screen or go back

**Files to modify:**
- `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`

**Changes:**
```dart
// Create mode - after save
if (mode == 'create') {
  context.go('/main'); // Navigate to tabs screen
} else {
  context.pop(); // Return to calendar
}
```

**Step 5.2: Update Calendar Screen Navigation**
- When user taps activity: Navigate to `/activity-detail` with mode='view'

**Files to modify:**
- `lib/features/calendar/presentation/screens/activities_list_screen.dart`

**Changes:**
```dart
onTap: () {
  context.push('/activity-detail', extra: {
    'mode': 'view',
    'activityId': activity.id,
  });
}
```

---

### Phase 6: Date/Time Picker Integration

**Step 6.1: Implement Date/Time Picker**
- Reuse existing `_showDateTimePicker()` from current_plan_screen.dart
- Default to next Saturday at 7:00 AM in create mode
- Allow editing in both modes

**Logic:**
```dart
DateTime getDefaultDateTime() {
  final now = DateTime.now();
  // Find next Saturday
  final daysUntilSaturday = (DateTime.saturday - now.weekday) % 7;
  final nextSaturday = now.add(Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
  // Set time to 7:00 AM
  return DateTime(nextSaturday.year, nextSaturday.month, nextSaturday.day, 7, 0);
}
```

---

### Phase 7: Testing & Validation

**Step 7.1: Manual Testing Checklist**
- [ ] Create new activity flow: distance/pace/gut → adjust-macros → activity-detail (create mode)
- [ ] Date/time defaults to next Saturday 7am
- [ ] Save button creates activity and nutrition plan
- [ ] Navigation goes to tabs screen after save
- [ ] Calendar shows new activity
- [ ] Tap activity opens activity-detail (view mode)
- [ ] Edit nutrition plan and save
- [ ] Complete workout button shows rating UI
- [ ] Submit completion saves ActivityCompletion record
- [ ] Workout journal section shows completion data

**Step 7.2: Fix Dismissible Bug**
- Remove `async` from `onDismissed` callback in activities_list_screen.dart
- Error: "A dismissed Dismissible widget is still part of the tree"

**Files to modify:**
- `lib/features/calendar/presentation/screens/activities_list_screen.dart`

**Changes:**
```dart
// BEFORE
onDismissed: (direction) async {
  await ref.read(calendarControllerProvider.notifier).deleteActivity(activity.id);
  // ...
}

// AFTER
onDismissed: (direction) {
  ref.read(calendarControllerProvider.notifier).deleteActivity(activity.id);
  // ...
}
```

---

## Data Flow Diagrams

### Create Mode Flow
```
DistancePaceGutEntryScreen
  ↓ (user enters data)
AdjustMacrosScreen
  ↓ (user reviews macros)
  ↓ (tap "Create Plan")
ActivityDetailScreen (mode='create')
  - Date/time picker (default: next Sat 7am)
  - Generated nutrition plan (preview)
  - Save button
  ↓ (user taps Save)
ActivityDetailController.saveActivity()
  - Creates Activity in database
  - Creates NutritionPlan linked to Activity
  - Links ActivityCompletion (empty, for future completion)
  ↓
Navigate to /main (tabs screen)
```

### View/Edit Mode Flow
```
ActivitiesListScreen
  ↓ (user taps activity)
ActivityDetailScreen (mode='view', activityId=xxx)
  - Loads Activity from database
  - Loads NutritionPlan (if exists)
  - Loads ActivityCompletion (if exists)
  - Shows date/time picker
  - Shows nutrition plan
  - Shows "Complete Workout" button
  - Shows workout journal (if completed)
  ↓ (user edits and taps Save)
ActivityDetailController.saveActivity()
  - Updates Activity
  - Updates NutritionPlan
  ↓
Stay on screen or go back

  ↓ (user taps "Complete Workout")
CompleteWorkoutBottomSheet
  - 3 rating sliders (1-5)
  - Text notes field
  ↓ (user submits)
ActivityDetailController.completeActivity()
  - Creates ActivityCompletion record
  - Updates UI to show completion data
```

---

## File Structure Changes

### New Files
- `lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart`
- `lib/features/nutrition_plan/presentation/providers/activity_detail_controller.g.dart` (generated)
- `lib/features/nutrition_plan/presentation/widgets/complete_workout_bottom_sheet.dart`

### Renamed Files
- `lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart` → `activity_detail_screen.dart`

### Modified Files
- `lib/features/nutrition_plan/presentation/providers/distance_page_gut_entry_controller.dart`
- `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`
- `lib/features/calendar/presentation/providers/calendar_controller.dart` (already modified)
- `lib/features/calendar/presentation/screens/activities_list_screen.dart` (already modified + bug fix)
- `lib/shared/core/app_router.dart`

---

## Database Schema Considerations

### Existing Tables
- `activities` - Already has all required fields
- `nutrition_plans` - Already has activityId foreign key
- `activity_completions` - Already has all required fields (effortRating, nutritionRating, overallSatisfaction, textNotes, etc.)
- `workout_notes` - May be redundant with ActivityCompletion.textNotes

**No schema changes required!** All necessary fields already exist.

---

## Risk Assessment

### Low Risk
- Date/time picker (already implemented)
- Activity creation (already working)
- Navigation changes (straightforward)

### Medium Risk
- State management complexity (create vs view mode)
- Data passing between screens via GoRouter extra
- Ensuring proper cleanup of state between modes

### High Risk
- Race conditions during save operations
- Ensuring nutrition plan links correctly to activity
- ActivityCompletion integration with existing workout_notes table

### Mitigation Strategies
1. Use AsyncValue.guard() for all async operations
2. Add extensive logging during save operations
3. Test both create and view modes thoroughly
4. Add error handling for missing data scenarios

---

## Success Criteria

1. ✅ User can create activity with date/time selection
2. ✅ Activity is NOT created until Save button pressed
3. ✅ Date/time defaults to next Saturday 7am
4. ✅ Screen renamed to "Activity Detail Screen"
5. ✅ Save button navigates to tabs screen (create mode)
6. ✅ User can edit existing activities
7. ✅ Complete Workout button always visible (view mode)
8. ✅ Rating UI (1-5 scale) appears after completion
9. ✅ Workout notes saved with completion
10. ✅ No Dismissible widget errors

---

## Timeline Estimate

- **Phase 1** (Activity creation refactor): 2 hours
- **Phase 2** (Rename files/routes): 1 hour
- **Phase 3** (Controller creation): 3 hours
- **Phase 4** (UI rebuild): 4 hours
- **Phase 5** (Navigation updates): 1 hour
- **Phase 6** (Date/time picker): 1 hour
- **Phase 7** (Testing): 2 hours

**Total: ~14 hours**

---

## Next Steps

1. Review this plan with user for approval
2. Begin Phase 1 implementation
3. Run `dart run build_runner build` after each controller change
4. Test incrementally after each phase
5. Fix Dismissible bug in activities_list_screen.dart

---

**Document Status:** Complete - Ready for Implementation
**Last Updated:** 2025-01-XX
**Author:** Claude Code Assistant
