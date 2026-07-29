# Home Screen Redesign - Agent Notes

**READ THIS FIRST** - This document contains shared context for all agents working on the homescreen redesign.

## Project Overview

We are redesigning the home screen (`ActivitiesListScreen`) with the following major changes:

1. **Replace Survey tab with Events tab** - The Feature Survey feature is being completely removed
2. **Move plus button to top-right overlay** - 50px orange circle overlapping the activities section
3. **Simplify activity cards** - Remove checkmark/X buttons, add chevron, add swipe-to-delete
4. **Update empty state** - New "No fueling plans yet" design
5. **Rename and reorder Upcoming Events section** - Now "Upcoming Races", moved below activities

## Key Files

### Tab Bar & Navigation
- `lib/shared/widgets/tabs_screen.dart` - Main tab controller
- `lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart` - Bottom nav bar

### Activities Screen
- `lib/features/activities/presentation/screens/activities_list_screen.dart` - Main home screen
- `lib/features/activities/presentation/widgets/activity_card.dart` - Activity list item
- `lib/features/activities/presentation/widgets/activity_action_buttons.dart` - Checkmark/X buttons (TO BE REMOVED)

### Events
- `lib/features/events/presentation/widgets/upcoming_event_card_kyle.dart` - Event card widget
- `lib/features/events/presentation/screens/events_list_screen.dart` - Full events list

### Survey (TO BE REMOVED)
- `lib/features/feature_survey/` - Entire directory to be removed
- `lib/shared/database/tables/feature_survey_responses_table.dart` - Drift table to remove

## Design Specifications

### Plus Button (New)
- Size: 50px diameter orange circle
- Background: `AppColors.orange`
- Icon: Plus icon, cream/white color
- Position: Absolute overlay, top-right of activities section
- Should "stylishly overlap" the content

### Activity Card (Updated)
- Remove: `ActivityActionButtons` (checkmark and X)
- Add: Right chevron (`Icons.chevron_right`)
- Add: Scheduled time display before distance (e.g., "6:00 AM · 10.5 mi · 8:30/mi")
- Add: Swipe-to-delete gesture (use `Dismissible` widget)
- Keep: Selection mode UI for brick creation unchanged

### Empty State (New Widget)
- Calendar icon (gray, 64px)
- "No fueling plans yet" - title text
- "Tap + to fuel your next workout" - orange subtitle
- Selected date - gray subtitle

### Upcoming Races Section
- Header: "Upcoming Races" with "Add race >" link on right
- Position: BELOW activities list
- Event card: Name + "X days away" + chevron only
- Hide entirely when no events

### Events Tab Icon
- Use `FontAwesomeIcons.calendarCheck` or similar calendar-with-star icon

## Important Patterns to Follow

1. **FOA Architecture** - Keep UI logic in screens, business logic in controllers
2. **Use MealvanaSnackbar** - Never use raw Flutter SnackBar
3. **Theme-aware colors** - Use `isDark` check with `AppColors`
4. **Font families** - Titles: 'Compadre', Body: 'Apercu'
5. **Code generation** - Run `dart run build_runner build` after controller changes

## Agent Communication

When you complete a task:
1. Update the CHECKLIST.md file (mark items as `[x]`)
2. Add a note here about what you changed and any decisions made
3. Write a small unit test in the appropriate test file

---

## Agent Log

### Agent 1 Notes


### Agent 2 Notes

**Completed**: 2026-01-27

**Track 3: Activity Card Updates (COMPLETE)**

Changes made to `lib/features/activities/presentation/widgets/activity_card.dart`:

1. **Removed ActivityActionButtons widget**:
   - Removed import for `activity_action_buttons.dart`
   - Removed the checkmark and X buttons from the card
   - Removed the `_handleComplete` method (no longer needed)

2. **Added right chevron icon**:
   - Added `Icons.chevron_right` on the right side when NOT in selection mode
   - Styled with theme-aware color (cream/blackberry) at 0.5 opacity, 20px size
   - Chevron is hidden when in selection mode (shows numbered circles instead)

3. **Added scheduled time display**:
   - Added `intl` package import for `DateFormat`
   - Updated `_formatActivityDetails()` to include scheduled time as first item
   - Format: "6:00 AM · 10.5 mi · 8:30/mi" (time first, then distance/pace)
   - Uses `DateFormat('h:mm a')` for consistent time formatting

4. **Implemented swipe-to-delete**:
   - Wrapped card in `Dismissible` widget (only when NOT in selection mode)
   - Swipe direction: `endToStart` (swipe left to delete)
   - Red background with trash icon appears during swipe
   - Shows confirmation dialog before deletion
   - Updated `_handleDelete` to return `Future<bool>` for confirmDismiss callback
   - Shows success/error snackbars after deletion attempt

5. **BrickGroupCard not updated**:
   - Checked `brick_group_card.dart` - it doesn't use `ActivityActionButtons`
   - It has its own custom header with Ungroup/Delete buttons (part of brick workflow)
   - No changes needed for consistency

**Testing**:
- Created comprehensive test file at `test/features/activities/presentation/widgets/activity_card_test.dart`
- Tests cover: title display, scheduled time display, distance/pace, chevron visibility, selection mode, dismissible behavior, activity type icons, cycling activities
- Note: Tests currently fail due to FeatureSurveyResponsesTable errors (Track 7 cleanup needed)

**File to deprecate/delete**:
- `lib/features/activities/presentation/widgets/activity_action_buttons.dart` (no longer used anywhere)

**Code generation needed**:
- No Riverpod or Drift changes, so no build_runner needed for this track

**Architecture Compliance**:
- FOA pattern maintained: UI logic in screen, business logic in controller
- Proper error handling with try-catch blocks
- Theme-aware colors throughout
- Used existing controllers and providers (no new business logic in UI)


### Agent 3 Notes

**Completed**: 2026-01-27

**Track 4: Empty State Updates (COMPLETE)**
- Created `lib/features/activities/presentation/widgets/no_fueling_plans_widget.dart`
  - Calendar icon (gray, 64px) using `Icons.calendar_today`
  - "No fueling plans yet" title with Compadre font
  - "Tap + to fuel your next workout" subtitle in AppColors.orange with Apercu font
  - Selected date displayed with full format (e.g., "Monday, January 27, 2026") using Apercu font
  - Theme-aware gray colors for light/dark mode
- Updated `_buildEmptyState` method in `ActivitiesListScreen` to use new widget
- Created comprehensive unit test at `test/features/activities/presentation/widgets/no_fueling_plans_widget_test.dart`
  - Tests icon display, text content, colors, fonts, date formatting, and layout

**Track 5: Upcoming Races Section (COMPLETE)**
- Removed "Upcoming Events" section from top of screen
- Added "Upcoming Races" section at BOTTOM (after activities list)
- Created `_buildUpcomingRacesHeader` method with:
  - "Upcoming Races" title on left
  - "Add race >" link on right (orange, tappable, navigates to EventFormScreen)
  - Invalidates `nextUpcomingEventProvider` after creating new event
- Modified section to hide entirely when no events exist (no "Create an Event" card)
- Simplified `upcoming_event_card_kyle.dart`:
  - Removed date/month display on right side
  - Kept event name + countdown text
  - Added right chevron icon matching theme colors
- Added import for `EventFormScreen` to support navigation

**Design Decisions:**
- Used `Icons.calendar_today` for empty state (simple, recognizable calendar icon)
- Applied `AppColors.orange` for call-to-action text (follows Kyle design system)
- Used Compadre for titles and Apercu for body text (consistent with app typography)
- Implemented conditional rendering for Upcoming Races (only shows when event exists)
- Made "Add race >" link interactive with proper navigation and state refresh

**Testing:**
- Created 8 unit tests for `NoFuelingPlansWidget` covering:
  - Icon display and size
  - Text content accuracy
  - Color usage (AppColors.orange)
  - Font families (Compadre/Apercu)
  - Date formatting with multiple test cases
  - Layout centering
- Upcoming Races section test still needed (marked as pending in checklist)

**Architecture Compliance:**
- FOA pattern maintained: UI logic in screens/widgets, navigation handled properly
- Used existing providers and controllers (no new business logic in UI)
- Theme-aware colors with isDark checks throughout
- Proper imports and organization


### Agent 4 Notes

**Completed**: 2026-01-27

**Changes Made**:
1. Added delete button to AppBar actions in `activity_detail_screen.dart`
   - Icon: `FontAwesomeIcons.trash` in dragonfruit color
   - Only shown for existing activities (not new ones, not in coach view)
   - Positioned in the AppBar actions area

2. Implemented delete confirmation dialog
   - Shows "Delete Activity" title with warning message
   - Cancel and Delete buttons (Delete in dragonfruit color)
   - Prevents accidental deletion

3. Implemented delete activity handler
   - Calls `activitiesController.deleteActivity()` for soft delete
   - Tracks analytics event for deletion
   - Shows success snackbar using `MealvanaSnackbar.showSuccess`
   - Navigates back to home screen (`/main`) after deletion
   - Error handling with proper logging and error snackbar

4. Mark-as-complete functionality verification
   - Already present in the screen via the "Complete" button (line 897-898)
   - Button shows "Completing..." during operation
   - Triggers `_completeWorkout()` method which shows completion dialog
   - Supports both single-sport and brick workout completion

**Architecture Compliance**:
- UI logic kept in screen (dialog display, navigation)
- Business logic handled by `activitiesController.deleteActivity()`
- Proper error handling with AsyncValue.guard pattern
- Analytics tracking for user actions
- MealvanaSnackbar used for all user feedback

**Testing**:
5. Created unit test at `test/features/nutrition_plan/presentation/screens/activity_detail_screen_test.dart`
   - Tests delete button visibility (shown for existing activities)
   - Tests delete button hidden for new activities
   - Tests delete button hidden in coach view
   - Tests complete button visibility for non-completed activities
   - Tests completed state displays correctly with checkmark icon
   - Note: Test will compile after Track 7 (Survey Removal) completes and code generation runs


### Agent 5 Notes

**Completed**: Survey Feature Removal (Track 7) - 2026-01-27

**Files Deleted**:
- Entire directory: `lib/features/feature_survey/` (including all screens, widgets, controllers, services, repositories, and domain models)
- Table definition: `lib/shared/database/tables/feature_survey_responses_table.dart`

**Files Modified**:
1. `lib/shared/database/app_database.dart`:
   - Removed import of `feature_survey_responses_table.dart`
   - Removed `FeatureSurveyResponsesTable` from the tables list in `@DriftDatabase` annotation
   - NOTE: Schema version was NOT changed - this will be handled separately in migration

2. `lib/shared/services/sync/data_sync_service.dart`:
   - Removed `dirtyFeatureSurvey` collection logic
   - Removed `feature_survey_responses` from dirty records check
   - Removed `feature_survey_responses` from dirty records payload
   - Removed `feature_survey_responses` case from `_clearNeedsUploadFlag()`
   - Removed `_featureSurveyToJson()` helper method

3. `lib/shared/services/sync/duplicate_cleanup_service.dart`:
   - Removed `feature_survey_responses` table cleanup call

4. `lib/shared/database/daos/diagnostic_dao.dart`:
   - Removed import of `feature_survey_responses_table.dart`
   - Removed feature survey responses merge logic in `mergeUserProfiles()`

5. `lib/features/auth/data/user_repository.dart`:
   - Removed feature survey migration comments in `migrateUserDataFromLocalToOAuth()`
   - Removed feature survey deletion logic in `clearAnonymousUserLocalData()`

6. `lib/shared/services/analytics/analytics_events.dart`:
   - Removed `trackFeatureSurveyCompleted()` method
   - Removed `trackFeatureVoted()` method

7. `supabase/functions/upload-all-data/index.ts`:
   - Removed `feature_survey_responses` from `UploadRequest` interface
   - Removed entire `feature_survey_responses` upload section

**Generated Files** (will be regenerated by build_runner):
- `lib/shared/database/app_database.g.dart` - still contains old references
- `lib/shared/database/schema_versions.dart` - still contains old schema definitions

**Action Required**:
- Run `dart run build_runner build --delete-conflicting-outputs` to regenerate Drift database files
- NOTE: SyncCoordinator does NOT have feature_survey in its dependency graph, so no changes needed there

**Test Created**:
- Simple verification test to ensure feature_survey imports no longer exist (see test file below)

**Edge Functions**:
- Updated `supabase/functions/upload-all-data/index.ts` to remove feature_survey handling
- No other edge functions reference feature_survey (checked sync-all-data and generate-* functions)

**Architecture Compliance**:
- All deletions followed the instruction to NOT modify files being handled by Agent 1 (tabs_screen.dart, floating_action_buttons_bar.dart)
- Cleaned up all imports and references systematically
- Maintained FOA pattern (no business logic in UI layers that were removed)
- Edge function changes maintain API compatibility (just removes unused feature_survey support)


---

**Last Updated**: 2026-01-27

**Completed**: 2026-01-27

**Track 1: Tab Bar Updates (COMPLETE)**
- Replaced `FeatureSurveyScreen` import with `EventsListScreen` in `tabs_screen.dart`
- Updated the screens list to use `EventsListScreen` instead of `FeatureSurveyScreen`
- Renamed all `onSurveyTap` callbacks to `onEventsTap` throughout the navigation flow
- Updated `FloatingActionButtonsBar` widget:
  - Changed icon from `FontAwesomeIcons.clipboardList` to `FontAwesomeIcons.calendarCheck` for Events
  - Removed the separate orange plus button (was outside the pill container)
  - Restructured the widget to have the pill container be the only child
  - The pill now auto-resizes based on the number of visible buttons (3-4 buttons depending on coach tab visibility)
- Updated all documentation comments to reflect the new Events tab naming

**Track 2: Plus Button Relocation (COMPLETE)**
- Created new `FloatingPlusButton` widget at `/lib/features/activities/presentation/widgets/floating_plus_button.dart`
  - 50px diameter orange circle
  - Plus icon in cream/white color
  - Shadow for depth and visual hierarchy
  - Uses `AppColors.orange` for background and `AppColors.cream` for icon
- Integrated `FloatingPlusButton` into `ActivitiesListScreen`:
  - Wrapped the Scaffold body in a Stack to allow overlay positioning
  - Positioned button in top-right corner with proper padding (accounts for status bar)
  - Wired tap handler to navigate to `/distancepacegut` with selectedDate
- Created comprehensive unit test at `/test/features/activities/presentation/widgets/floating_plus_button_test.dart`
  - Tests rendering of circular button with plus icon
  - Tests onPressed callback invocation
  - Tests correct colors (orange background, cream icon)
  - Tests size constraints (50x50)
  - Tests shadow existence

**Design Decisions:**
1. Used `Stack` for the plus button overlay rather than `floatingActionButton` property to achieve the exact top-right positioning requirement
2. The button is positioned to "stylishly overlap" the activities section as specified
3. The pill container in the bottom nav bar now automatically adjusts width based on visible buttons
4. Maintained theme-aware dark mode support for all components

**Files Modified:**
- `/lib/shared/widgets/tabs_screen.dart` - Survey → Events tab migration
- `/lib/shared/widgets/kyle_design/navigation/floating_action_buttons_bar.dart` - Icon update and plus button removal
- `/lib/features/activities/presentation/screens/activities_list_screen.dart` - Added FloatingPlusButton overlay

**Files Created:**
- `/lib/features/activities/presentation/widgets/floating_plus_button.dart` - New widget
- `/test/features/activities/presentation/widgets/floating_plus_button_test.dart` - Unit tests

**Architecture Compliance:**
- FOA pattern maintained: UI logic in screens/widgets, navigation handled properly
- Used existing providers and state management patterns
- Theme-aware colors with isDark checks throughout
- Proper imports and organization
- MealvanaSnackbar ready for any future feedback needs

**Next Steps:**
- No build_runner needed for this agent (no Riverpod/Drift changes)
- Human should test the UI to ensure the plus button position looks good on different screen sizes
- Track 7 (Survey Feature Removal) still needs to be completed by Agent 5 to fully remove the old survey code

