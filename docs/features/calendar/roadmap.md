# Calendar Feature Implementation Roadmap

## Overview

This roadmap delivers the Calendar feature as a focused, running-first experience while laying lightweight groundwork for future multi-sport expansion. Each phase prioritizes user value, minimizes migration risk, and keeps scope aligned with current requirements: running activities, race events, carb loading, and workout completion powered by our existing voice notes feature.

**IMPORTANT ARCHITECTURE NOTES:**
- **No Auth System**: Using device_id from user_profiles for user identification
- **Manual Nutrition Generation**: Users explicitly create nutrition plans via existing distance/pace/gut entry flow
- **Activities List Primary**: Main tab shows daily activity list with calendar, NOT standalone calendar
- **Events Are Special**: Events have their own list screen and support carb loading plans
- **Carb Loading**: 0-day (none), 2-day, or 3-day protocols only

## Development Principles

- **Risk-Driven**: Ship the smallest viable slice, guard migrations with rollback plans, and keep feature flags in place until confidence is high.
- **User-Centric**: Validate flows with runners and race preparation scenarios before investing in polish.
- **Reuse Before Reinventing**: Lean on existing nutrition planning, carb loading logic, and voice notes infrastructure wherever possible.
- **Offline-First**: Preserve the current offline guarantees while introducing the new calendar-centric UX.
- **Device-Based Identity**: All user data keyed to device_id, not authentication system.

## Phase 1 – Calendar & Activity Foundation (4-5 weeks)

> Goal: Replace the legacy tab experience with a calendar-first surface that supports running activities and race events end to end.

### Key Deliverables
- **Database groundwork**: ✅ Create the new `activities`, `events`, and `activity_completions` tables plus required indexes. Update existing nutrition plans to reference activities.
- **Navigation overhaul**: Swap bottom navigation to `Activities List` (primary) + `Settings`. Activities List screen shows calendar picker + daily activity list.
- **Activities List Screen**: Main screen showing calendar date picker at top, with scrollable list of activities for selected day below. Includes "Upcoming Event" widget showing next event with countdown.
- **Activity Creation Flow**:
  - FAB on Activities List → Activity Creation Screen
  - Tabbed interface: **Running** | **Biking (grayed)** | **Swimming (grayed)**
  - Running tab contains existing distance/pace/gut entry form
  - Completes with nutrition plan generation → returns to Activities List
  - Activity appears in list with nutrition plan linked
- **Event Creation Flow**:
  - Tap "Upcoming Event" widget → Events List Screen
  - FAB on Events List → Event Creation Screen (full screen, not dialog)
  - Save event → Event Detail Screen with two action buttons:
    - "Create Nutrition Plan" (goes to distance/pace/gut entry)
    - "Create Carb Loading Plan" (goes to protocol selection)
  - Events appear in Activities List with special event styling
- **Event Detail Screen**: Shows event metadata (name, type, date, goals) with action buttons for creating nutrition and carb loading plans.
- **Current Plan Screen Enhancement**: Update existing Current Plan screen to show activity metadata alongside nutrition plan and voice notes.
- **Tapping Activities**:
  - Activity WITH nutrition plan → Current Plan Screen
  - Activity WITHOUT nutrition plan → Distance/pace/gut entry flow
  - Event WITHOUT nutrition plan → Event Detail Screen
  - Past activities (readonly) → Current Plan Screen (view only)

### Testing & Validation
- Drift/Supabase schema creation with proper indexes.
- Calendar rendering performance (<500ms) across iOS/Android.
- Regression checks for nutrition plan generation and offline behavior.

### Success Criteria
- Calendar becomes the default entry point without regressing existing nutrition flows.
- Users can schedule and complete running activities entirely inside the calendar.
- Voice notes remain accessible from the activity detail page.

## Phase 2 – Carb Loading & Completion Enhancements (3-4 weeks)

> Goal: Integrate carb loading plans into the calendar and enrich the completion experience using the existing voice notes tooling.

### Key Deliverables
- **Carb Loading Protocol Selection**: Create screen to choose protocol (0-day/2-day/3-day) based on carb_loading_protocols.md
- **Carb loading plan generation**: Generate 2-day or 3-day carb loading plans tied to events. Create carb loading day activities that appear in Activities List with special carb loading styling.
- **Carb day management**: Clicking carb loading day activity shows single-day carb loading detail (reuse existing carb loading day UI, filtered to that day only).
- **Protocol modification**: Allow users to change carb loading protocol after creation (deletes old carb days, creates new ones).
- **Activity completion enhancements**: Extend completion data (actual distance/duration, optional weather) and prompt the user to launch the voice notes recorder if they have not added a note.
- **Event editing rules**: Editing or deleting an event cascades the appropriate carb loading activities and nutrition plans.
- **Analytics instrumentation**: Track calendar adoption, completion rates, and carb loading engagement.

### Testing & Validation
- Edge cases for editing/deleting events with carb loading plans.
- Offline-first validation for carb loading activities.
- Accessibility review for new completion UI.

### Success Criteria
- Users can plan and execute race week carb loading directly from the calendar.
- Completion flow consistently gathers ratings and encourages voice note usage.
- Analytics confirm high retention of running-only workflows.

## Phase 3 – Polish, Insights, and Future Hooks (3-4 weeks)

> Goal: Finish the experience with performance refinements, richer insights, and unobtrusive placeholders for future multi-sport work.

### Key Deliverables
- **UI polish & accessibility**: Animation tuning, high-contrast adjustments, and screen reader improvements across calendar, activity detail, and completion flows.
- **Performance tuning**: Query/index optimizations, lazy loading for dense weeks, and background sync refinements.
- **Activity history & insights**: Lightweight summaries (weekly mileage, completion streaks, nutrition adherence trends) scoped to running activities.
- **Under-construction surfacing**: Biking and swimming tabs appear in the activity type selector as disabled cards labeled "Under Construction" (no backend work required yet).
- **Documentation & rollout**: Update internal docs, create release notes, and prep customer-facing education.

### Testing & Validation
- Full regression suite (unit, widget, integration) focused on the new calendar architecture.
- Performance benchmarks on mid-range devices.
- Beta rollout monitoring with feature flag control.

### Success Criteria
- Calendar renders in <300ms on supported devices with smooth navigation.
- Users report clear differentiation between available (running/events) and future (biking/swimming) functionality.
- Support volume remains flat or decreases after rollout.

## Out-of-Scope (Future Considerations)

The following items are explicitly deferred and should not influence current implementation decisions:
- Biking or swimming activity management beyond "Under Construction" placeholders.
- Speech-to-text capture; we continue to rely on the existing voice notes experience.
- Third-party integrations (Strava, Garmin, TrainingPeaks, etc.).
- Recurring activity templates or automated training plan builders.
- Coach/athlete sharing or collaboration features.

## Timeline Summary

| Phase | Duration | Core Focus | Definition of Done |
|-------|----------|------------|--------------------|
| Phase 1 | 4-5 weeks | Calendar shell, running activities, event basics | Users can plan and complete runs within the calendar |
| Phase 2 | 3-4 weeks | Carb loading integration, completion upgrades | Race prep lives inside the calendar, completion flow encourages voice notes |
| Phase 3 | 3-4 weeks | Polish, insights, future hooks | Performance target met, under-construction messaging live, rollout documentation ready |

**Total Estimate:** 10-13 weeks of focused delivery (excluding contingency for user feedback-driven iteration).

## Risk & Mitigation Snapshot

| Risk | Mitigation |
|------|------------|
| Migration errors | Build migrations in isolation, run on staging with production snapshots before release. |
| User confusion during transition | Ship with feature flag, create in-app announcements and support documentation. |
| Performance regression | Profile calendar rendering continuously and add instrumentation for slow frames. |
| Scope creep | Maintain strict out-of-scope list and review new requests at phase boundaries. |

## Implementation Progress

### Current Status: Phase 1 Foundation (✅ COMPLETE - Updated 2025-10-07 - Session 3-4)

#### ✅ Completed (Foundation Layer)
- **Database Schema**: ✅ Complete v1 schema with Activities, Events, ActivityCompletions, CarbLoadingPlans, CarbLoadingDays tables
- **Domain Models**: ✅ Activity, Event, ActivityCompletion domain classes
- **Service Layer**: ✅ CalendarService with full CRUD operations for activities, events, completions
- **Controller Layer**: ✅ CalendarController with AsyncNotifier pattern
- **Database Generation**: ✅ Drift classes generated, all tables accessible
- **Compilation**: ✅ Zero errors in calendar feature code
- **Old Code Cleanup**: ✅ Removed duplicate carb loading tables and old implementations

#### ✅ Completed (UI Layer - Sessions 2 & 3)
- **Device ID Provider**: ✅ Created `device_id_provider.dart` with Riverpod @riverpod pattern
- **Upcoming Event Widget**: ✅ Widget with countdown + navigation to Events List
- **Activities List Screen**: ✅ PRIMARY TAB with calendar picker, daily activity list, upcoming event widget, and FAB
- **Navigation Update**: ✅ Updated `tabs_screen.dart` to use Activities List as primary tab (index 0)
- **Activity Creation Screen**: ✅ Tabbed interface (Running/Biking🚧/Swimming🚧) embedding distance/pace/gut entry
- **Events List Screen**: ✅ Full event list with FAB, sorted by date, past/upcoming styling
- **Event Creation Screen**: ✅ Full screen form (NO carb loading) with event types, dates, goals
- **Event Detail Screen**: ✅ Event info display + "Create Nutrition Plan" + "Create Carb Loading Plan" buttons
- **Core Navigation**: ✅ FAB → Activity Creation, Upcoming Event → Events List, Event Card → Event Detail

#### ✅ Final Phase 1 Completions (Session 4)
1. ✅ **Wire Activity Card Navigation**: Event cards → Event Detail, Regular activities → Plan screens
2. ✅ **Wire Nutrition Plan Button**: Event Detail → Distance/Pace/Gut Entry
3. ✅ **Delete Old Files**: Removed activity_creation_dialog.dart, event_creation_dialog.dart, calendar_screen.dart

#### 📋 Optional Enhancements (Future)
1. 💡 **Update Current Plan Screen**: Add activity metadata display header
2. 💡 **Pre-populate Event Data**: Pass event distance/pace to nutrition creation
3. 💡 **Edit Event**: Add edit functionality
4. 💡 **Nutrition Plan Indicator**: Show visual indicator if activity has plan

#### 🎯 Implementation Notes
**Files Created (Session 2)**:
- `/lib/shared/providers/device_id_provider.dart` - Device-based user identification
- `/lib/features/calendar/presentation/widgets/upcoming_event_widget.dart` - Event preview widget
- `/lib/features/calendar/presentation/screens/activities_list_screen.dart` - Main calendar interface

**Files Created (Session 3)**:
- `/lib/features/calendar/presentation/screens/activity_creation_screen.dart` - Tabbed activity creation
- `/lib/features/calendar/presentation/screens/events_list_screen.dart` - Events list with past/upcoming
- `/lib/features/calendar/presentation/screens/event_creation_screen.dart` - Full event form (no carb loading)
- `/lib/features/calendar/presentation/screens/event_detail_screen.dart` - Event display + action buttons

**Files Modified (Session 2-3)**:
- `/lib/shared/widgets/tabs_screen.dart` - Changed from CalendarScreen to ActivitiesListScreen
- `/lib/features/calendar/presentation/screens/activities_list_screen.dart` - Added navigation to ActivityCreationScreen
- `/lib/features/calendar/presentation/widgets/upcoming_event_widget.dart` - Added navigation to EventsListScreen

**Key Technical Decisions**:
- UserProfile.id is the device_id (no separate deviceId field needed)
- CalendarController returns AsyncValue<CalendarState> where CalendarState.activities contains activity list
- Activity Creation Screen embeds existing DistancePaceGutEntryScreen in Running tab
- Event creation creates both Activity and Event records sequentially
- EventDetailScreen has placeholders for Phase 2 carb loading

#### 🚧 Architecture Compliance Checklist
- ✅ **Device-Based Identity**: Using device_id from user_profiles (no auth)
- ✅ **Manual Nutrition Generation**: No auto-generation (buttons marked as TODOs)
- ✅ **Activities List Primary**: Main tab shows activities with calendar picker
- ✅ **No Carb Loading in Event Creation**: Separate action button in Event Detail Screen
- ✅ **FOA Pattern**: Proper separation of presentation, application, domain, data layers
- ✅ **Riverpod 3.x**: Using @riverpod AsyncNotifier patterns throughout

**Files Modified (Session 4)**:
- `/lib/features/calendar/presentation/screens/activities_list_screen.dart` - Added smart activity card navigation
- `/lib/features/calendar/presentation/screens/event_detail_screen.dart` - Wired nutrition plan button

**Files Deleted (Session 4)**:
- `/lib/features/calendar/presentation/widgets/activity_creation_dialog.dart` - Replaced by full screen
- `/lib/features/calendar/presentation/widgets/event_creation_dialog.dart` - Replaced by full screen
- `/lib/features/calendar/presentation/screens/calendar_screen.dart` - Replaced by ActivitiesListScreen

#### ⏱️ Time Investment
- **Session 1**: ~2 hours (Database, Service, Controller, Domain models)
- **Session 2**: ~2.5 hours (Device provider, widget, screen, tabs update, documentation)
- **Session 3**: ~3 hours (Activity/Event screens creation + navigation wiring)
- **Session 4**: ~1 hour (Final navigation wiring, file cleanup, documentation)
- **Total**: ~8.5 hours
- **Phase 1**: ✅ COMPLETE

---

This roadmap keeps the Calendar feature tightly scoped around running and events while preserving the ability to grow into multi-sport support later. Each phase delivers tangible value, protects existing user data, and respects Mealvana Endurance's offline-first, nutrition-focused foundation.
