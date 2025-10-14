# Calendar Feature - Architecture Clarification Session

**Date**: 2025-10-07
**Participants**: Lee (Product Owner), Claude (AI Assistant)
**Purpose**: Clarify calendar feature architecture and correct initial implementation approach

## Context

The calendar feature was initially implemented with incorrect assumptions about:
- Authentication/user identity
- Automatic nutrition plan generation
- Navigation structure (calendar-first vs activities-first)
- Event creation workflow
- Carb loading protocols

This document captures the complete conversation that led to the corrected architecture documented in ARCHITECTURE.md and roadmap.md.

## Initial State (Before Clarification)

### What Was Built Initially:
- ✅ Database tables: Activities, Events, ActivityCompletions, CarbLoadingPlans, CarbLoadingDays
- ✅ CalendarService with full CRUD operations
- ✅ CalendarController with AsyncNotifier pattern
- ✅ CalendarScreen with week view
- ❌ ActivityCreationDialog (incorrect - should be full screen with tabs)
- ❌ EventCreationDialog (incorrect - had carb loading section that shouldn't exist)
- ❌ Assumed auto-generation of nutrition plans
- ❌ Assumed auth-based user identification

### Critical Misunderstandings:
1. Thought we were using authentication system → Actually using device_id
2. Thought nutrition plans auto-generate when creating activities → Manual creation only
3. Thought calendar was primary screen → Activities List is primary
4. Thought event creation had carb loading config → Carb loading is separate action
5. Thought carb loading had 1/2/3/7-day options → Only 0/2/3-day

## Clarification Questions & Answers

### Session 1: Basic Architecture Questions

**Q1: Activity Creation Workflow**
- **Question**: When creating a regular activity, do they go straight to distance/pace/gut entry screen or fill out a dialog first?
- **Answer**: They go to `activity_creation_screen.dart` with tabs (Running | Biking🚧 | Swimming🚧). Running tab contains the distance/pace/gut entry form. No separate dialog needed for regular activities.

**Q2: Event Creation Workflow**
- **Question**: Is event creation via FAB on main screen?
- **Answer**: NO. User taps "Upcoming Event" widget → navigates to Events Screen → FAB there opens Event Creation. After creation → Event Detail Screen with two buttons: "Create Nutrition Plan" and "Create Carb Loading Plan"

**Q3: Nutrition Plan Generation**
- **Question**: Should plans auto-generate when activities are created?
- **Answer**: NO. Users manually create nutrition plans by pressing buttons. Preserve existing sequence (distance/pace/gut → food preferences → plan generation).

**Q4: Carb Loading Plan**
- **Question**: What happens when user clicks "Create Carb Loading Plan"?
- **Answer**: They select protocol (0/2/3-day based on carb_loading_protocols.md and sample_screen.png). Carb loading days appear as separate activities in calendar.

**Q5: Calendar Display**
- **Question**: When should activities show in calendar?
- **Answer**: Immediately when created, before nutrition plan exists. If activity lacks nutrition plan, tapping it directs user to create one.

**Q6: Device ID Usage**
- **Question**: How to implement device ID for user identification?
- **Answer**: Get device_id from UserProfile table. Create deviceIdProvider that reads from getCurrentUserProfile().

**Q7: Existing Flow Integration**
- **Question**: Should calendar reuse existing distance/pace/gut entry flow?
- **Answer**: Yes, preserve exact sequence. Distance/pace/gut → food preferences → nutrition generation.

### Session 2: Detailed Screen Architecture

**Q1: Activity Creation Screen Title**
- **Answer**: "New Activity" is fine

**Q2: Events Widget Location & Display**
- **Answer**: Widget shows next event with countdown. Lives on Activities List screen (the main tab).

**Q3: Nutrition Plan & Carb Loading Buttons**
- **Clarification**: Only EVENTS have "Create Carb Loading Plan" button. Regular activities only have nutrition plan creation.
- **Important**: User CAN create carb loading plan BEFORE nutrition plan
- **Critical Fix**: Remove carb loading section from Event Creation Dialog entirely
- **Activity Without Plan**: Direct users to start distance/pace/gut entry flow

**Q4: Carb Loading Protocols**
- **Correction**: Don't reference old docs. Use carb_loading_protocols.md and sample_screen.png
- **Protocols**: 2-day or 3-day (plus 0-day meaning no carb loading)
- **Display**: Carb loading days appear as activities alongside other activities
- **Day Detail**: Clicking carb loading activity shows single-day detail (like existing carb loading screen but just that day)
- **Protocol Changes**: Deleting/altering requires handling existing carb loading activities

**Q5: Navigation After Plan Creation**
- **Answer**: Return to Activities List (NOT Current Plan Screen)
- **Requirement**: Activities List screen must be the main tab in tabs page

**Q6: Activity Detail Screens**
- **Major Clarification**: There is NO separate activity detail screen
- **Instead**: Update Current Plan Screen to incorporate:
  - Activity info
  - Voice notes
  - Nutrition plan
  - Whatever else is needed

**Q7: Retroactive Plan Creation**
- **Answer**: NO, users cannot create plans for past activities

**Q8: Device ID Implementation**
- **Answer**: Easiest way to get deviceIdProvider from user profile

### Session 3: Final Architecture Confirmation

**Q1: Activities List Screen Display**
- **Answer**: Shows calendar for each day, filtered by currently selected day (not by week)

**Q2: Event Creation Dialog vs Screen**
- **Answer**: Full screen, not dialog

**Q3: Actual Carb Loading Protocols**
- **Answer**: 2-day or 3-day protocol (or 0-day = not carb loading)
- **Source**: carb_loading_protocols.md (not generic docs)

**Q4: Phase Split**
- **Answer**: Developer's choice based on complexity

**Q5: Device ID Provider**
- **Answer**: Read from first UserProfile in database is fine

## Final Corrected Architecture

### Navigation Structure
```
TabsScreen
├── Activities List (PRIMARY TAB)
│   ├── Calendar date picker
│   ├── "Upcoming Event" widget (conditional)
│   └── Daily activity list (for selected date)
└── Settings
```

### Creating Regular Activity Flow
```
Activities List
  → [FAB]
  → Activity Creation Screen (tabs: Running | Biking🚧 | Swimming🚧)
  → Running tab has Distance/Pace/Gut Entry form
  → Generate nutrition plan
  → Return to Activities List
```

### Creating Event Flow
```
Activities List
  → [Tap "Upcoming Event" widget]
  → Events List Screen
  → [FAB]
  → Event Creation Screen (full screen, NO carb loading section)
  → Save
  → Event Detail Screen
      ├── "Create Nutrition Plan" button
      └── "Create Carb Loading Plan" button
```

### Viewing Activities
- **Activity WITH nutrition plan** → Current Plan Screen (enhanced with activity metadata)
- **Activity WITHOUT nutrition plan** → Start distance/pace/gut entry flow
- **Event WITHOUT nutrition plan** → Event Detail Screen (action buttons)
- **Past activity** → Current Plan Screen (read-only, no plan creation)
- **Carb loading day** → Carb Loading Day Detail Screen (single day view)

### Screens to Create
1. ✅ `activities_list_screen.dart` - Main tab (calendar picker + daily list + upcoming event widget)
2. ✅ `activity_creation_screen.dart` - Tabbed interface with distance/pace/gut entry
3. ✅ `events_list_screen.dart` - List of all events
4. ✅ `event_creation_screen.dart` - Full screen form (NOT dialog)
5. ✅ `event_detail_screen.dart` - Event info + action buttons
6. ✅ `upcoming_event_widget.dart` - Shows next event with countdown
7. ✅ Update `current_plan_screen.dart` - Add activity metadata display
8. ✅ Add `device_id_provider.dart` - Get device_id from user profile

### Screens to Remove
- ❌ `activity_creation_dialog.dart` - Replaced by full screen with tabs
- ❌ `event_creation_dialog.dart` - Replaced by full screen without carb loading
- ❌ `calendar_screen.dart` - Replaced by activities_list_screen.dart

### Carb Loading (Phase 2)
- **Protocols**: 0-day (none), 2-day, 3-day only
- **Selection Screen**: Based on carb_loading_protocols.md and sample_screen.png
- **Activities**: Carb days appear as separate activities in calendar
- **Detail View**: Shows single day (reuse existing UI, filtered to that day)
- **Protocol Changes**: Delete old carb activities, create new ones

## Key Architecture Principles

### 1. Device-Based Identity
```dart
// NO authentication system
// Use device_id from user_profiles table
@riverpod
Future<String> deviceId(DeviceIdRef ref) async {
  final database = ref.watch(appDatabaseProvider);
  final userProfile = await database.getCurrentUserProfile();
  return userProfile.deviceId;
}
```

### 2. Manual Nutrition Generation
- **Rule**: Creating activity does NOT auto-generate nutrition plan
- **User Action**: Must explicitly press "Create Nutrition Plan" button or complete distance/pace/gut flow
- **Reason**: Give users control over when they create plans

### 3. Activities List Primary
- **Main Tab**: Activities List (NOT standalone calendar)
- **Structure**: Calendar picker at top + daily activity list below
- **FAB**: Creates new activity (not on calendar screen)

### 4. Events Are Special
- **Separate List**: Events have their own list screen
- **Access**: Via "Upcoming Event" widget on Activities List
- **Features**: Support carb loading plans (regular activities don't)

### 5. One Plan Per Activity
- **Rule**: Each activity can have maximum one nutrition plan
- **Enforcement**: Button disabled if plan exists, shows "View Plan" instead

## Implementation Checklist

### Completed ✅
- Database schema (all tables)
- CalendarService (CRUD operations)
- CalendarController (AsyncNotifier pattern)
- Drift code generation
- Old code cleanup (duplicate carb loading tables removed)
- Zero compilation errors in main app

### To Remove ❌
- activity_creation_dialog.dart
- event_creation_dialog.dart
- calendar_screen.dart (if standalone)
- Carb loading section from any event creation UI

### To Create 🆕
- activities_list_screen.dart
- activity_creation_screen.dart (tabbed)
- events_list_screen.dart
- event_creation_screen.dart (full screen)
- event_detail_screen.dart
- upcoming_event_widget.dart
- device_id_provider.dart
- carb_loading_protocol_selection_screen.dart (Phase 2)

### To Modify 🔧
- current_plan_screen.dart (add activity metadata)
- tabs_screen.dart (use Activities List as primary)
- Distance/pace/gut entry screen (return to Activities List)

## Critical Corrections Made

### ❌ WRONG Initial Assumptions:
1. Auto-generate nutrition plans when creating activities
2. Use authentication for user identity
3. Calendar is primary screen with FAB
4. Event creation includes carb loading configuration
5. Activity creation is a simple dialog
6. Carb loading has 1/2/3/7-day protocols

### ✅ CORRECT Architecture:
1. Manual nutrition plan creation via button press
2. Device ID from user_profiles for identity
3. Activities List is primary with calendar picker
4. Event creation does NOT include carb loading (separate action)
5. Activity creation is full screen with tabs
6. Carb loading has 0/2/3-day protocols only

## Data Flow Examples

### Creating Activity with Nutrition Plan
```
1. User taps FAB on Activities List
2. Activity Creation Screen opens (Running tab selected)
3. User fills distance/pace/gut entry form
4. Taps "Generate Plan"
5. Nutrition plan generated via existing flow
6. Activity + nutrition plan saved to database
7. Return to Activities List
8. Activity appears with ✅ "Has Plan" indicator
```

### Creating Event with Carb Loading
```
1. User taps "Upcoming Event" widget
2. Events List Screen opens
3. User taps FAB on Events List
4. Event Creation Screen opens (full screen)
5. User fills event details (NO carb loading section)
6. Taps "Save Event"
7. Event Detail Screen opens
8. User taps "Create Carb Loading Plan"
9. Protocol Selection Screen opens
10. User selects "3-Day Protocol"
11. System generates:
    - CarbLoadingPlan record
    - 3 CarbLoadingDay activities (Day -3, -2, -1)
12. Return to Activities List
13. Event + 3 carb loading activities appear in calendar
```

### Viewing Activity Without Plan
```
1. User sees activity in Activities List (⚠️ "No Plan" indicator)
2. User taps activity
3. System checks: activity.hasPlan == false
4. System navigates to distance/pace/gut entry screen
5. Screen pre-populated with activity distance
6. User completes form
7. Nutrition plan generated
8. Return to Activities List
9. Activity now shows ✅ "Has Plan" indicator
```

## References

### Source Documents
- [roadmap.md](./roadmap.md) - Updated with corrected architecture
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Comprehensive technical specification
- [carb_loading_protocols.md](./carb_loading_protocols.md) - Carb loading protocol details
- sample_screen.png - UI reference for protocol selection

### Related Code
- `/lib/features/calendar/` - Calendar feature implementation
- `/lib/features/nutrition_plan/presentation/screens/distance_pace_gut_entry_screen.dart` - Existing nutrition entry
- `/lib/shared/database/app_database.dart` - Database schema
- `/lib/shared/database/tables/activities_table.dart` - Activities table definition

## Future AI Assistant Notes

### When Working on Calendar Feature:
1. **ALWAYS check this document first** before making assumptions
2. **Device ID, not auth** - User identification via device_id from user_profiles
3. **Manual nutrition generation** - Never auto-generate, always explicit user action
4. **Activities List is primary** - Not standalone calendar
5. **Events are special** - Separate flow, support carb loading
6. **No dialogs** - Use full screens for creation flows
7. **Carb loading: 0/2/3-day only** - Not 1/7-day

### Critical "Gotchas":
- ❌ Don't create activity_detail_screen.dart - Use current_plan_screen.dart instead
- ❌ Don't add carb loading to event creation - It's a separate action
- ❌ Don't auto-generate nutrition plans - User must initiate
- ❌ Don't put FAB on calendar - Put on Activities List
- ❌ Don't use auth service - Use device_id provider

### Testing Checklist:
- [ ] Activity created without nutrition plan appears in list
- [ ] Tapping activity without plan starts nutrition creation flow
- [ ] Event created without plans shows both action buttons
- [ ] Carb loading creates separate day activities
- [ ] Device ID correctly identifies user across all operations
- [ ] Past activities cannot create new plans

## Conversation Meta-Notes

### Communication Clarity
The conversation required multiple rounds of clarification because:
1. Initial requirements weren't fully documented
2. Some aspects contradicted typical app patterns (no auth, manual generation)
3. Terminology overlap ("calendar" screen vs "activities list" screen)
4. Implementation had started with incorrect assumptions

### Effective Patterns Used
- ✅ Asked follow-up questions before implementing
- ✅ Confirmed understanding with detailed examples
- ✅ Requested to see specific documentation (carb_loading_protocols.md)
- ✅ Created visual flow diagrams in text format
- ✅ Listed all screens to create/modify/remove

### Documentation Outcome
This conversation resulted in:
1. Updated roadmap.md with corrected architecture
2. New ARCHITECTURE.md with comprehensive specs
3. This CONVERSATION_SUMMARY.md for future reference
4. Clear implementation checklist
5. Removal of incorrect dialog implementations

## Conclusion

The calendar feature architecture is now clearly defined and documented. The key insight was that this is an **activities-first** app with **manual nutrition generation** and **device-based identity**, not a calendar-first app with auto-generation and authentication.

Future work should reference ARCHITECTURE.md as the source of truth, and this document for understanding WHY certain decisions were made.

---

**Last Updated**: 2025-10-07
**Status**: Architecture finalized, ready for implementation
**Next Step**: Create Activities List Screen as primary tab
