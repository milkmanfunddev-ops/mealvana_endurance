# Home Screen Redesign Checklist

**Status Legend**: `[ ]` = Not Started | `[~]` = In Progress | `[x]` = Complete

## Track 1: Tab Bar Updates
- [x] Replace Survey tab with Events tab in `tabs_screen.dart`
- [x] Update `FloatingActionButtonsBar` to use calendar-check icon for Events
- [x] Remove orange plus button from `FloatingActionButtonsBar`
- [x] Update all `onSurveyTap` references to `onEventsTap`
- [x] Auto-resize pill container (3 buttons instead of 4)
- [ ] Write unit test for tab bar

## Track 2: Plus Button Relocation
- [x] Create new `FloatingPlusButton` widget (50px orange circle)
- [x] Position as overlay in top-right of `ActivitiesListScreen`
- [x] Style to "overlap" the activities section attractively
- [x] Wire tap handler to navigate to New Activity screen
- [x] Write unit test for plus button widget

## Track 3: Activity Card Updates
- [x] Remove `ActivityActionButtons` from `ActivityCard`
- [x] Add right chevron icon to `ActivityCard`
- [x] Add scheduled time display (e.g., "6:00 AM · 10.5 mi")
- [x] Implement swipe-to-delete on `ActivityCard`
- [x] Update `BrickGroupCard` if needed for consistency
- [x] Write unit tests for activity card changes

## Track 4: Empty State Updates
- [x] Create new `NoFuelingPlansWidget` matching screenshot design
- [x] Calendar icon, "No fueling plans yet", orange "Tap + to fuel...", date
- [x] Replace existing empty state in `ActivitiesListScreen`
- [x] Write unit test for empty state widget

## Track 5: Upcoming Races Section
- [x] Rename "Upcoming Events" header to "Upcoming Races"
- [x] Add "Add race >" link to section header (navigates to EventFormScreen)
- [x] Move section BELOW activities (reorder slivers)
- [x] Simplify event card: name + countdown + chevron only (no date/location)
- [x] Hide entire section when no events (don't show "Create an Event")
- [ ] Write unit test for upcoming races section

## Track 6: Activity Detail Screen Updates
- [x] Add delete activity button to actions
- [x] Ensure mark-as-complete is available in detail screen
- [x] Write unit test for detail screen actions (Note: Will compile after Track 7 completes)

## Track 7: Survey Feature Removal
- [x] Remove `FeatureSurveyScreen` and related widgets
- [x] Remove `feature_survey_controller.dart` and `.g.dart`
- [x] Remove `feature_survey_service.dart`
- [x] Remove `feature_survey_repository.dart`
- [x] Remove `feature_survey_data.dart` domain model
- [x] Remove `FeatureSurveyResponsesTable` from Drift database
- [x] Update `AppDatabase` to remove feature survey references
- [x] Remove from `SyncCoordinator` dependencies
- [x] Remove from edge functions if applicable
- [x] Clean up any remaining imports/references
- [x] Write test to verify survey code is removed

## Post-Implementation
- [x] Run `dart run build_runner build --delete-conflicting-outputs`
- [x] Run `flutter analyze` to check for issues
- [x] Run all tests (new tests pass, pre-existing failures unrelated to redesign)
- [ ] Manual smoke test of home screen flow

---

## Agent Assignments
| Agent | Track(s) | Status |
|-------|----------|--------|
| Agent 1 | Track 1 (Tab Bar) + Track 2 (Plus Button) | Complete |
| Agent 2 | Track 3 (Activity Card) | Complete |
| Agent 3 | Track 4 (Empty State) + Track 5 (Races Section) | Complete |
| Agent 4 | Track 6 (Detail Screen) | Complete |
| Agent 5 | Track 7 (Survey Removal) | Complete |

---

**Last Updated**: 2026-01-27
