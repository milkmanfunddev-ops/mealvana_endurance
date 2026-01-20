# Brick Workout Implementation Roadmap

## Overview

This document outlines the phased implementation plan for the brick workout feature. The implementation is divided into 6 phases, designed to allow incremental testing and validation.

## Phase Summary

| Phase | Description | Dependencies | Estimated Effort |
|-------|-------------|--------------|------------------|
| 1 | Schema & Domain Models | None | 2-3 days |
| 2 | Edge Function Updates | Phase 1 | 3-4 days |
| 3 | Activities List UI (Create Brick) | Phase 1 | 3-4 days |
| 4 | New Activity Screen (Brick Tab) | Phase 1, 2 | 4-5 days |
| 5 | Activity Details Screen (Brick View) | Phase 2, 4 | 3-4 days |
| 6 | Polish & Testing | All phases | 3-4 days |

**Total Estimated Effort: 18-24 days**

---

## Phase 1: Schema & Domain Models

### Objective
Set up the data foundation for brick workouts.

### Tasks

#### 1.1 Supabase Schema Updates

- [ ] Add `brick` to `activity_type_enum`
- [ ] Add `archived_for_brick` to `activity_status_enum`
- [ ] Add `brick_metadata` JSONB column to activities table
- [ ] Add `brick_id` UUID column to activities table
- [ ] Create indexes for brick queries
- [ ] Add `transition` to `category_enum`
- [ ] Tag transition-suitable foods

**SQL Migration File:** `supabase/migrations/YYYYMMDDHHMMSS_add_brick_support.sql`

#### 1.2 Drift Schema Updates

- [ ] Update `activities_table.dart` with new columns
- [ ] Update CHECK constraint for activity_type
- [ ] Bump schema version to v3
- [ ] Create migration in `app_database.dart`
- [ ] Generate schema snapshot

**Files to Modify:**
- `lib/shared/database/tables/activities_table.dart`
- `lib/shared/database/app_database.dart`

#### 1.3 Domain Models

- [ ] Add `brick` to `ActivityType` enum
- [ ] Create `BrickMetadata` freezed model
- [ ] Create `BrickSegment` freezed model
- [ ] Update `Activity` domain model with brick fields
- [ ] Run code generation

**Files to Create/Modify:**
- `lib/shared/domain/activity_type.dart` (modify)
- `lib/features/activities/domain/brick_metadata.dart` (create)
- `lib/features/activities/domain/activity.dart` (modify)

#### 1.4 Repository Updates

- [ ] Add brick-specific queries to `ActivitiesRepository`
- [ ] Add method to archive activities for brick
- [ ] Add method to restore archived activities (ungroup)
- [ ] Add method to create brick from existing activities

**Files to Modify:**
- `lib/features/activities/data/activities_repository.dart`

### Deliverables
- Working database migration (Supabase + Drift)
- Complete domain models with JSON serialization
- Repository methods for brick CRUD operations

### Testing
- [ ] Migration test: Upgrade from v2 to v3
- [ ] Model test: BrickMetadata serialization/deserialization
- [ ] Repository test: Create/read/update/delete brick activities

---

## Phase 2: Edge Function Updates

### Objective
Update edge functions to calculate nutrition for brick workouts.

### Tasks

#### 2.1 generate-macros Updates

- [ ] Add brick detection in main handler
- [ ] Implement `calculateBrickMacros()` function
- [ ] Implement phase breakdown calculation
- [ ] Implement transition macro calculation
- [ ] Add brick-specific response schema
- [ ] Normalize response to match single-sport format

**Files to Modify:**
- `supabase/functions/generate-macros/index.ts`

#### 2.2 generate-nutrition-plan Updates

- [ ] Add brick activity type support
- [ ] Implement multi-phase food selection
- [ ] Add transition food category handling
- [ ] Implement sport-specific during-phase food filtering
- [ ] Update response schema for brick plans

**Files to Modify:**
- `supabase/functions/generate-nutrition-plan/index.ts`
- `supabase/functions/_shared/nutrition/types.ts`
- `supabase/functions/_shared/nutrition/sport-configs/index.ts`

#### 2.3 New Sport Config

- [ ] Create brick sport config
- [ ] Define phase structure for brick workouts
- [ ] Define food category mappings per phase

**Files to Create:**
- `supabase/functions/_shared/nutrition/sport-configs/brick.ts`

### Deliverables
- Updated generate-macros endpoint handling brick requests
- Updated generate-nutrition-plan endpoint with multi-phase support
- Brick sport configuration

### Testing
- [ ] Edge function test: Swim/Run brick macro calculation
- [ ] Edge function test: Bike/Run brick macro calculation
- [ ] Edge function test: Swim/Bike/Run brick macro calculation
- [ ] Edge function test: Brick nutrition plan generation
- [ ] Edge function test: Transition food selection

---

## Phase 3: Activities List UI (Create Brick)

### Objective
Implement the brick creation flow from the activities list screen.

### Tasks

#### 3.1 Create Brick Button

- [ ] Add visibility logic (2+ different sports on same day)
- [ ] Create `CreateBrickButton` widget
- [ ] Add button to activities list header
- [ ] Style according to design specs

**Files to Modify:**
- `lib/features/activities/presentation/screens/activities_list_screen.dart`

**Files to Create:**
- `lib/features/activities/presentation/widgets/create_brick_button.dart`

#### 3.2 Selection Mode

- [ ] Create `BrickSelectionController` provider
- [ ] Add selection mode state to activities list
- [ ] Implement checkbox UI on activity cards
- [ ] Implement numbered order indicators
- [ ] Add Cancel/Confirm buttons to header
- [ ] Validate selection (2+ different sports)

**Files to Create:**
- `lib/features/activities/presentation/providers/brick_selection_controller.dart`

**Files to Modify:**
- `lib/features/activities/presentation/widgets/activity_card.dart`

#### 3.3 Brick Group Display

- [ ] Create `BrickGroupCard` widget
- [ ] Implement brick header with Ungroup/View Combined buttons
- [ ] Implement nested segment cards with X buttons
- [ ] Add "Consecutive activities share nutrition" label
- [ ] Style according to design specs

**Files to Create:**
- `lib/features/activities/presentation/widgets/brick_group_card.dart`
- `lib/features/activities/presentation/widgets/brick_segment_card.dart`

#### 3.4 Brick Actions

- [ ] Implement "Create Brick" confirmation flow
- [ ] Implement soft delete of original activities
- [ ] Implement brick activity creation
- [ ] Implement "Ungroup" functionality
- [ ] Implement "Remove from brick" functionality
- [ ] Handle minimum 2 sports validation

**Files to Modify:**
- `lib/features/activities/presentation/providers/activities_controller.dart`

### Deliverables
- Create Brick button with proper visibility logic
- Full selection mode with numbered ordering
- Brick group card with nested segments
- Ungroup and remove from brick functionality

### Testing
- [ ] Widget test: Create Brick button visibility
- [ ] Widget test: Selection mode UI
- [ ] Widget test: Brick group card display
- [ ] Integration test: Create brick from existing activities
- [ ] Integration test: Ungroup brick

---

## Phase 4: New Activity Screen (Brick Tab)

### Objective
Implement the brick tab in the new activity screen for creating/editing brick workouts.

### Tasks

#### 4.1 Sport Selector Update

- [ ] Add 4th brick icon to sport selector
- [ ] Create combined silhouettes icon asset
- [ ] Handle brick tab selection
- [ ] Update `NewActivityCoordinator` for brick tab

**Files to Modify:**
- `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/sport_selector.dart`
- `lib/features/nutrition_plan/presentation/providers/new_activity_coordinator.dart`

#### 4.2 Brick Tab Content

- [ ] Create `BrickInputController` provider
- [ ] Create sport checkbox selector widget
- [ ] Implement minimum 2 sports validation
- [ ] Implement dynamic segment visibility based on checkboxes

**Files to Create:**
- `lib/features/nutrition_plan/presentation/providers/brick_input_controller.dart`
- `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_sport_checkboxes.dart`

#### 4.3 Segment Input Sections

- [ ] Create expandable segment accordion widget
- [ ] Reuse existing sport input fields in accordions
- [ ] Implement per-segment intensity selector
- [ ] Auto-populate from Training Peaks/Final Surge data

**Files to Create:**
- `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_segment_accordion.dart`
- `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_swimming_section.dart`
- `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_cycling_section.dart`
- `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_running_section.dart`

#### 4.4 Drag to Reorder

- [ ] Implement `ReorderableListView` for segments
- [ ] Add drag handles to segment cards
- [ ] Update segment order in controller state
- [ ] Persist order to brick_metadata

**Files to Modify:**
- `lib/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_sport_checkboxes.dart`

#### 4.5 Generate Macros Integration

- [ ] Update generate macros button for brick
- [ ] Collect all segment data
- [ ] Call generate-macros with brick payload
- [ ] Navigate to adjust macros screen

**Files to Modify:**
- `lib/features/nutrition_plan/presentation/providers/brick_input_controller.dart`

### Deliverables
- Complete brick tab with sport checkboxes
- Segment input sections for each sport
- Drag-to-reorder functionality
- Integration with generate-macros edge function

### Testing
- [ ] Widget test: Brick tab display
- [ ] Widget test: Sport checkbox validation
- [ ] Widget test: Segment reordering
- [ ] Integration test: Generate macros for brick
- [ ] Integration test: Navigate from brick tab to adjust macros

---

## Phase 5: Activity Details Screen (Brick View)

### Objective
Display brick nutrition plans with multi-phase breakdown.

### Tasks

#### 5.1 Brick Header

- [ ] Create side-by-side sport icons layout
- [ ] Display brick type name (e.g., "SWIM/RUN BRICK")
- [ ] Show combined distance/duration summary
- [ ] Update geometric pattern for multi-sport

**Files to Modify:**
- `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`

**Files to Create:**
- `lib/features/nutrition_plan/presentation/widgets/activity_detail/brick_header.dart`

#### 5.2 Multi-Phase Nutrition Sections

- [ ] Modify section rendering to handle dynamic phases
- [ ] Implement During-Swim section (usually empty)
- [ ] Implement T1 Transition section
- [ ] Implement During-Bike section
- [ ] Implement T2 Transition section
- [ ] Implement During-Run section
- [ ] Add phase-specific icons and labels

**Files to Modify:**
- `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`

**Files to Create:**
- `lib/features/nutrition_plan/presentation/widgets/activity_detail/transition_section.dart`

#### 5.3 Adjust Macros Screen Updates

- [ ] Add "Both Views" layout (totals + expandable phases)
- [ ] Implement expandable phase breakdown
- [ ] Allow per-phase macro editing
- [ ] Update UI for brick context

**Files to Modify:**
- `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`

#### 5.4 Completion Flow

- [ ] Update completion dialog for brick
- [ ] Mark entire brick as complete
- [ ] Update activity status

**Files to Modify:**
- `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`

### Deliverables
- Brick header with side-by-side sport icons
- Multi-phase nutrition sections with transitions
- Updated adjust macros screen with phase breakdown
- Brick completion flow

### Testing
- [ ] Widget test: Brick header display
- [ ] Widget test: Multi-phase sections rendering
- [ ] Widget test: Transition sections
- [ ] Integration test: View brick nutrition plan
- [ ] Integration test: Complete brick workout

---

## Phase 6: Polish & Testing

### Objective
Final polish, comprehensive testing, and bug fixes.

### Tasks

#### 6.1 Animations

- [ ] Selection mode entry/exit animations
- [ ] Brick group creation animation
- [ ] Segment reorder animations
- [ ] Ungroup animation

#### 6.2 Error Handling

- [ ] Add error states for all brick operations
- [ ] Implement validation error dialogs
- [ ] Add loading states
- [ ] Handle edge cases (no activities, single sport, etc.)

#### 6.3 Accessibility

- [ ] Add screen reader labels
- [ ] Ensure touch target sizes
- [ ] Test with VoiceOver/TalkBack
- [ ] Verify color contrast

#### 6.4 Comprehensive Testing

- [ ] Unit tests for all new domain models
- [ ] Unit tests for all new controllers
- [ ] Widget tests for all new widgets
- [ ] Integration tests for complete flows
- [ ] Edge function tests for all brick scenarios
- [ ] Manual testing on iOS and Android

#### 6.5 Documentation

- [ ] Update CLAUDE.md with brick feature
- [ ] Add brick section to user documentation
- [ ] Update API documentation

### Deliverables
- Polished animations
- Complete error handling
- Accessible UI
- Comprehensive test coverage
- Updated documentation

---

## Risk Mitigation

### High Risk Items

| Risk | Impact | Mitigation |
|------|--------|------------|
| Edge function complexity | High | Implement incrementally, test each phase separately |
| Schema migration issues | High | Test migration thoroughly in dev before prod |
| UI state complexity | Medium | Use clear state machine for selection mode |
| Performance with many segments | Low | Limit to 3 segments, optimize rendering |

### Rollback Plan

If issues arise after deployment:

1. **Schema Rollback**: Columns are nullable, can ignore in app
2. **Edge Function Rollback**: Deploy previous version
3. **App Rollback**: Shorebird code push to previous version
4. **Feature Flag**: Consider adding feature flag for gradual rollout

---

## Dependencies

### External Dependencies

- None (uses existing infrastructure)

### Internal Dependencies

```
Phase 1 (Schema) ─────────┬─────────── Phase 3 (Activities List UI)
                          │
                          └─────────── Phase 4 (New Activity Screen)
                                           │
Phase 2 (Edge Functions) ──────────────────┴─── Phase 5 (Activity Details)
                                                    │
                                                    └─── Phase 6 (Polish)
```

---

## Success Criteria

### Phase 1
- [ ] Can create brick activity in database
- [ ] Can archive/restore activities for brick
- [ ] Domain models serialize correctly

### Phase 2
- [ ] generate-macros returns correct brick macros
- [ ] generate-nutrition-plan returns multi-phase plan
- [ ] All edge function tests pass

### Phase 3
- [ ] Create Brick button appears at correct times
- [ ] Can select 2-3 activities and create brick
- [ ] Brick displays correctly in list
- [ ] Can ungroup and remove from brick

### Phase 4
- [ ] Brick tab appears in sport selector
- [ ] Can create brick from scratch
- [ ] Can edit brick segments
- [ ] Can reorder segments
- [ ] Generate macros works for brick

### Phase 5
- [ ] Brick header displays correctly
- [ ] All nutrition phases render
- [ ] Transition sections show
- [ ] Can complete brick workout

### Phase 6
- [ ] All tests pass
- [ ] No accessibility issues
- [ ] Smooth animations
- [ ] Documentation complete

---

## Checklist Summary

### Pre-Implementation
- [ ] Review all documentation in /docs/brick/
- [ ] Set up feature branch
- [ ] Ensure Supabase dev environment ready

### Post-Phase Checkpoints
- [ ] Phase 1 complete: Schema + domain models working
- [ ] Phase 2 complete: Edge functions updated and tested
- [ ] Phase 3 complete: Can create bricks from activities list
- [ ] Phase 4 complete: Can create bricks from scratch
- [ ] Phase 5 complete: Can view and complete brick plans
- [ ] Phase 6 complete: All tests pass, documentation updated

### Pre-Release
- [ ] All tests pass in CI
- [ ] Manual testing complete on iOS + Android
- [ ] Documentation reviewed
- [ ] Supabase production migration ready
- [ ] Shorebird release prepared
- [ ] Update `min_app_version` in `app_config` table to brick-enabled version

---

## Backward Compatibility

**Strategy: Force Forward**

This feature requires a **minimum app version** enforcement. When releasing:

1. Deploy Supabase schema migration first
2. Deploy edge function updates
3. Release new app version via App Store/Play Store
4. Update `app_config.min_app_version` to new version number

Users on older versions will see `ForceUpgradeScreen` and must update before using the app. This ensures:
- No sync issues with unknown `brick` activity type
- No Drift CHECK constraint violations
- Clean upgrade path for all users

**No backward compatibility code needed** - the existing `VersionCheckService` handles this.
