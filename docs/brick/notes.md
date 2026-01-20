# Brick Feature Implementation Notes

## Instructions for Agents

1. **Before starting work**: Read this entire file and the checklist below
2. **Pick a task**: Choose an uncompleted task from the checklist (mark it as `[IN PROGRESS]`)
3. **Do the work**: Implement the task following FOA patterns and existing code conventions
4. **Update checklist**: Mark your task as `[DONE]` when complete
5. **Add notes**: Document any decisions, issues, or context in the Notes section below
6. **Commit**: Commit your changes to the brick branch with a descriptive message
7. **Important**: Only ONE agent should work on each task - check for `[IN PROGRESS]` markers

---

# PHASE 1: Schema & Domain Models

## 1.1 Supabase Schema (Run manually by human after Drift is ready)
- [DONE] Create migration file `supabase/migrations/YYYYMMDDHHMMSS_add_brick_support.sql`
- [DONE] Add `brick` to `activity_type_enum`
- [DONE] Add `archived_for_brick` to `activity_status_enum`
- [DONE] Add `brick_metadata` JSONB column to activities
- [DONE] Add `brick_id` UUID column to activities
- [DONE] Add indexes for brick queries
- [DONE] Add `transition` to `category_enum`

## 1.2 Drift Schema
- [DONE] Update `activities_table.dart` - Add `brickMetadata` TEXT column
- [DONE] Update `activities_table.dart` - Add `brickId` TEXT column
- [DONE] Update `activities_table.dart` - Update CHECK constraint for activity_type (add 'brick')
- [DONE] Update `activities_table.dart` - Update CHECK constraint for status (add 'archived_for_brick')
- [ ] Update `app_database.dart` - Ensure new columns are in onCreate (v3 not released yet)

## 1.3 Domain Models
- [DONE] Update `activity_type.dart` - Add `brick` enum value with displayName, iconName, dbValue
- [DONE] Update `activity_type.dart` - Update `isMultiSport` to include brick
- [DONE] Update `activity_type.dart` - Add `isBrick` helper getter
- [DONE] Create `brick_metadata.dart` - BrickMetadata model with toJson/fromJson
- [DONE] Create `brick_metadata.dart` - BrickSegment model with toJson/fromJson
- [ ] Update `activity.dart` - Add brickMetadata and brickId fields
- [ ] Update `activity.dart` - Add isBrick getter
- [ ] Update `activity.dart` - Update toJson() for brick fields
- [ ] Update `activity.dart` - Update copyWith() for brick fields
- [ ] Update `activity.dart` - Update equality/hashCode for brick fields
- [ ] Run `flutter pub run build_runner build --delete-conflicting-outputs` for code generation

## 1.4 Repository Updates
- [ ] Update `activities_repository.dart` - Add brick fields to `uploadDirtyRecords()` JSON payload
- [ ] Update `activities_repository.dart` - Add brick fields to `_saveToDrift()` CREATE path
- [ ] Update `activities_repository.dart` - Add brick fields to `_saveToDrift()` UPDATE path
- [ ] Update `activities_repository.dart` - Add brick fields to `_mapToActivityDomain()`
- [ ] Update `activities_repository.dart` - Add brick fields to `_mapJsonToActivityDomain()`
- [ ] Update `activities_repository.dart` - Add brick fields to `_mapDomainToCompanion()`
- [ ] Update `activities_repository.dart` - Add brick fields to `_uploadActivityToSupabase()`
- [ ] Update `activities_repository.dart` - Add brick fields to `_uploadActivityToSupabaseSync()`
- [ ] Add `getArchivedActivitiesForBrick(String brickId)` method
- [ ] Add `createBrickFromActivities()` method
- [ ] Add `ungroupBrick(String brickId)` method

## 1.5 Service Updates
- [ ] Update `activities_service.dart` - Add brick parameters to `createActivity()` method
- [ ] Add `createBrickActivity()` convenience method
- [ ] Update `mapToActivityDomain()` for brick fields

## 1.6 Phase 1 Verification
- [ ] Run `flutter analyze` - No errors
- [ ] Run code generation successfully
- [ ] Verify app compiles without errors

---

# PHASE 2: Edge Function Updates

## 2.1 generate-macros Updates
- [ ] Add brick detection in main handler
- [ ] Implement `calculateBrickMacros()` function for cumulative duration-based calculation
- [ ] Implement phase breakdown calculation (before, during-swim, T1, during-bike, T2, during-run, after)
- [ ] Implement transition macro calculation (T1: 20g carbs, T2: 25g carbs)
- [ ] Add brick-specific response schema (include segment macros)
- [ ] Normalize response to match single-sport format

## 2.2 generate-nutrition-plan Updates
- [ ] Add brick activity type support
- [ ] Implement multi-phase food selection
- [ ] Add transition food category handling
- [ ] Implement sport-specific during-phase food filtering
- [ ] Update response schema for brick plans (separate foods per phase)

## 2.3 Sport Config
- [ ] Create `brick.ts` sport config in `supabase/functions/_shared/nutrition/sport-configs/`
- [ ] Define phase structure for brick workouts
- [ ] Define food category mappings per phase
- [ ] Add transition phase settings

## 2.4 Phase 2 Verification
- [ ] Edge function test: Swim/Run brick macro calculation
- [ ] Edge function test: Bike/Run brick macro calculation
- [ ] Edge function test: Swim/Bike/Run brick macro calculation
- [ ] Edge function test: Brick nutrition plan generation
- [ ] Edge function test: Transition food selection

---

# PHASE 3: Activities List UI (Create Brick)

## 3.1 Create Brick Button
- [ ] Add visibility logic (2+ different sports on same day)
- [ ] Create `CreateBrickButton` widget
- [ ] Add button to activities list header (next to "Today's Activities")
- [ ] Style with orange outline, chain link icon

## 3.2 Selection Mode
- [ ] Create `BrickSelectionController` provider
- [ ] Add selection mode state to activities list
- [ ] Implement checkbox UI on activity cards
- [ ] Implement numbered order indicators (1, 2, 3)
- [ ] Add Cancel/Confirm buttons to header
- [ ] Validate selection (2-3 activities, different sports)

## 3.3 Brick Group Display
- [ ] Create `BrickGroupCard` widget
- [ ] Implement brick header with Ungroup/View Combined buttons
- [ ] Create `BrickSegmentCard` for nested segment display
- [ ] Add X buttons for removing segments
- [ ] Add "Consecutive activities share nutrition" label
- [ ] Style according to design specs (dark purple header)

## 3.4 Brick Actions
- [ ] Implement "Create Brick" confirmation flow
- [ ] Implement soft delete of original activities (status = 'archived_for_brick')
- [ ] Implement brick activity creation with brick_metadata JSON
- [ ] Implement "Ungroup" functionality (restore originals, delete brick)
- [ ] Implement "Remove from brick" functionality
- [ ] Handle minimum 2 sports validation

## 3.5 Calendar Indicators
- [ ] Update calendar dots for brick activities (show multiple sport colors)
- [ ] Show dots in segment order

## 3.6 Phase 3 Verification
- [ ] Widget test: Create Brick button visibility
- [ ] Widget test: Selection mode UI
- [ ] Widget test: Brick group card display
- [ ] Integration test: Create brick from existing activities
- [ ] Integration test: Ungroup brick

---

# PHASE 4: New Activity Screen (Brick Tab)

## 4.1 Sport Selector Update
- [ ] Add 4th brick icon to sport selector
- [ ] Create combined silhouettes icon asset (or use chain link)
- [ ] Add `SportTab.brick` to enum
- [ ] Handle brick tab selection
- [ ] Update `NewActivityCoordinator` for brick tab

## 4.2 Brick Tab Content
- [ ] Create `BrickInputController` provider
- [ ] Create `BrickTabContent` widget
- [ ] Create sport checkbox selector (select which sports to include)
- [ ] Implement minimum 2 sports validation
- [ ] Implement dynamic segment visibility based on checkboxes

## 4.3 Segment Input Sections
- [ ] Create `BrickSegmentAccordion` expandable widget
- [ ] Create `BrickSwimmingSection` (reuse swimming inputs)
- [ ] Create `BrickCyclingSection` (reuse cycling inputs)
- [ ] Create `BrickRunningSection` (reuse running inputs)
- [ ] Implement per-segment intensity selector
- [ ] Auto-populate from Training Peaks/Final Surge data (if available)

## 4.4 Drag to Reorder
- [ ] Implement `ReorderableListView` for segments
- [ ] Add drag handles to segment cards
- [ ] Update segment order in controller state
- [ ] Persist order to brick_metadata

## 4.5 Generate Macros Integration
- [ ] Update generate macros button for brick
- [ ] Collect all segment data
- [ ] Add `generateBrickMacros()` to `MacroTargetsController`
- [ ] Add `generateBrickMacros()` to `MacroGenerationService`
- [ ] Call generate-macros edge function with brick payload
- [ ] Navigate to adjust macros screen

## 4.6 Phase 4 Verification
- [ ] Widget test: Brick tab display
- [ ] Widget test: Sport checkbox validation
- [ ] Widget test: Segment reordering
- [ ] Integration test: Generate macros for brick
- [ ] Integration test: Navigate from brick tab to adjust macros

---

# PHASE 5: Activity Details Screen (Brick View)

## 5.1 Brick Header
- [ ] Create `BrickHeader` widget with side-by-side sport icons
- [ ] Display brick type name (e.g., "SWIM/RUN BRICK")
- [ ] Show combined distance/duration summary
- [ ] Update geometric pattern for multi-sport (blend sport colors)

## 5.2 Multi-Phase Nutrition Sections
- [ ] Modify section rendering to handle dynamic phases
- [ ] Implement During-Swim section (usually empty - "No food during swim")
- [ ] Implement T1 Transition section with transition icon
- [ ] Implement During-Bike section
- [ ] Implement T2 Transition section (if 3 sports)
- [ ] Implement During-Run section
- [ ] Add phase-specific icons and labels

## 5.3 Adjust Macros Screen Updates
- [ ] Add combined totals view (top of screen)
- [ ] Implement expandable phase breakdown
- [ ] Allow per-phase macro editing
- [ ] Update UI for brick context

## 5.4 Completion Flow
- [ ] Update completion dialog for brick (mark entire brick complete)
- [ ] Update activity status
- [ ] Show completion confirmation

## 5.5 Phase 5 Verification
- [ ] Widget test: Brick header display
- [ ] Widget test: Multi-phase sections rendering
- [ ] Widget test: Transition sections
- [ ] Integration test: View brick nutrition plan
- [ ] Integration test: Complete brick workout

---

# PHASE 6: Polish & Testing

## 6.1 Animations
- [ ] Selection mode entry/exit animations (checkboxes fade in)
- [ ] Brick group creation animation (cards animate together)
- [ ] Segment reorder animations (card lifts with shadow)
- [ ] Ungroup animation (cards separate)

## 6.2 Error Handling
- [ ] Add error states for all brick operations
- [ ] Implement validation error dialogs
- [ ] Add loading states for brick creation/ungrouping
- [ ] Handle edge cases (no activities, single sport, etc.)

## 6.3 Accessibility
- [ ] Add screen reader labels for all brick UI
- [ ] Ensure touch target sizes (44x44px minimum)
- [ ] Test with VoiceOver/TalkBack
- [ ] Verify color contrast

## 6.4 Comprehensive Testing
- [ ] Unit tests for BrickMetadata domain model
- [ ] Unit tests for BrickSegment domain model
- [ ] Unit tests for brick repository methods
- [ ] Unit tests for BrickInputController
- [ ] Widget tests for all new widgets
- [ ] Integration tests for complete flows
- [ ] Edge function tests for all brick scenarios
- [ ] Manual testing on iOS and Android

## 6.5 Documentation Updates
- [ ] Update CLAUDE.md with brick feature
- [ ] Add brick section to user documentation
- [ ] Update API documentation
- [ ] Update database schema docs

## 6.6 Final Verification
- [ ] All `flutter analyze` warnings resolved
- [ ] All tests pass
- [ ] No accessibility issues
- [ ] Smooth animations
- [ ] App runs on iOS simulator
- [ ] App runs on Android emulator

---

# Implementation Notes

## Schema Design Decisions
- `brick_metadata` stores segment information as JSON (see schema-changes.md for structure)
- Original activities are soft-deleted with `status = 'archived_for_brick'` and `brick_id` pointing to parent
- Any sport combination allowed (including run/bike/run for duathlon-style)
- Maximum 3 segments per brick

## Key Files Reference
- Activities table: `lib/shared/database/tables/activities_table.dart`
- App database: `lib/shared/database/app_database.dart`
- Activity type enum: `lib/shared/domain/activity_type.dart`
- Activity domain: `lib/features/activities/domain/activity.dart`
- Activities repository: `lib/features/activities/data/activities_repository.dart`
- Activities service: `lib/features/activities/application/activities_service.dart`
- Sport selector: `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/sport_selector.dart`
- New activity coordinator: `lib/features/nutrition_plan/presentation/providers/new_activity_coordinator.dart`

## Current Schema Version
- Drift schema is at v3 (NOT YET RELEASED to public)
- Add brick columns directly to v3 schema, no version bump needed

## Nutrition Algorithm Key Points
- Use TOTAL duration to determine carbohydrate rate (cumulative calculation)
- T1 transition: 20g carbs, 150mg sodium, 200ml water
- T2 transition: 25g carbs, 100mg sodium, 150ml water
- Swim phase: 0g carbs (can't eat while swimming)
- Bike phase: Higher gastric tolerance - maximize intake
- Run phase: Reduced gastric tolerance - conservative intake

## Agent Work Log
<!-- Agents should add their work entries here -->

### 2026-01-20 - Claude (Sonnet 4.5) - Part 2
**Task**: Phase 1.3 - Create BrickMetadata domain models

**Completed**:
- Created `/lib/features/activities/domain/brick_metadata.dart`
- Implemented `BrickMetadata` class with:
  - Fields: segmentOrder, segments, originalActivityIds, createdFromExisting, totalDurationMinutes
  - toJson() and fromJson() methods for database serialization
  - copyWith(), equals, hashCode, and toString() methods
- Implemented `BrickSegment` class with:
  - Required fields: sport, order, durationMinutes, intensity
  - Swimming fields: distanceMeters, pacePer100mSeconds, poolOrOpenWater, waterTempC
  - Cycling fields: distanceMiles, speedMph, terrain, indoorOutdoor, elevationGainFt
  - Running fields: distanceMiles (shared), paceMinutesPerMile
  - Full toJson/fromJson, copyWith, equals, hashCode, toString support
- Added helper function `_listEquals` for list equality comparison
- Verified with `flutter analyze` - no errors

**Design Decisions**:
- Used plain Dart classes (not freezed) to match existing codebase patterns (see activity.dart)
- All sport-specific fields are nullable - only populate relevant fields per segment
- distanceMiles is shared between cycling and running segments
- JSON keys use snake_case (e.g., segment_order) to match database conventions

**Next Steps**:
- Update activity_type.dart to add brick enum value
- Update activity.dart to include brickMetadata and brickId fields
- Update activities_table.dart for Drift schema changes

---

### 2026-01-20 - Claude (Sonnet 4.5) - Part 1
**Task**: Phase 1.1 - Create Supabase migration for brick support

**Completed**:
- Created `/supabase/migrations/20260120000000_add_brick_support.sql`
- Added `brick` to `activity_type_enum` with idempotent DO block
- Added `archived_for_brick` to `activity_status_enum` with idempotent DO block
- Added `brick_metadata` JSONB column (nullable, default NULL)
- Added `brick_id` UUID column (nullable, FK to activities.id ON DELETE SET NULL)
- Created partial index `idx_activities_brick_id` for efficient brick_id queries
- Created partial index `idx_activities_brick_type` for efficient activity_type='brick' queries
- Ensured `transition` category enum value exists (already added in previous migration)
- Added comprehensive comments documenting the brick workflow and schema

**Notes**:
- Followed existing migration patterns from `20250114_expand_category_enum_and_cleanup.sql` and `20260118_create_app_config_table.sql`
- Used idempotent `DO $$ BEGIN ... EXCEPTION WHEN duplicate_object` blocks to safely add enum values
- Foreign key constraint uses ON DELETE SET NULL to preserve archived activities if brick is deleted
- Partial indexes improve query performance for brick-specific lookups
- Migration is ready to be run manually by human after Drift schema is updated

**Next Steps**:
- Phase 1.2: Update Drift schema (activities_table.dart and app_database.dart)
- Phase 1.3: Update domain models (activity_type.dart, brick_metadata.dart, activity.dart)

---
*Last updated: 2026-01-20*
