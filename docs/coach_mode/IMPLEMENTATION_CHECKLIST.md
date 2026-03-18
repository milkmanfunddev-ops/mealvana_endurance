# Coach Mode v2 - Implementation Checklist

**Created**: 2026-03-17
**Status**: Planning Phase
**Branch**: `develop`

---

## Issue Summary

| # | Issue | Priority | Complexity | Status |
|---|-------|----------|------------|--------|
| 1 | Athlete search not finding users by name | High | Low | Pending |
| 2 | Child screens render full-screen instead of windowed on web | High | Medium | Pending |
| 3 | Carb loading plan creation for athletes | Medium | Medium | Pending |
| 4 | Activity creation fails ("activity not found") | Critical | Low | Pending |
| 5 | Athlete code generation + coach pairing flow | High | High | Pending |
| 6 | Coach portal as first screen on login | Medium | Low | Pending |
| 7 | Coach reports (at least one real report) | Medium | Medium | Pending |
| 8 | Coach sets nutrition targets for athletes | High | Medium | Pending |
| 9 | Push athlete workout feedback to TrainingPeaks | Medium | High | Pending |
| 10 | Import TP comments + bi-directional sync | Medium | High | Pending |

---

## Issue 1: Athlete Search Not Finding Users

### Root Cause Analysis
- Search uses `ilike` queries on Supabase `user_profiles` table
- Multi-word search splits by space and tries first_name/last_name in both orders
- Likely cause: Name updates not synced to Supabase, or search query construction issues

### Fix Plan
- [ ] Ensure athlete search always queries Supabase directly (not local Drift)
- [ ] Add debounced real-time search with loading indicator
- [ ] Verify that settings name changes upload to Supabase `user_profiles` immediately
- [ ] Add helpful message: "No athletes found. Ask them to share their athlete code instead."

### Files to Modify
- `lib/features/coach_mode/data/coach_repository.dart` - `searchAthletesByNameOrEmail()`
- `lib/features/coach_mode/presentation/widgets/portal_sidebar.dart` - Search UI

---

## Issue 2: Child Screens Full-Screen on Web (Coach Portal)

### Root Cause
`_isCoachSession()` in `root_app_widget.dart` makes ALL screens pushed from coach portal full-width. When coach navigates to NewActivityScreen, AdjustMacrosScreen, ActivityDetailScreen etc., they render at full browser width.

### Decision: Use standard 480px width (same as regular app)

### Fix Plan
- [ ] Modify `_isCoachSession()` to only apply full-width to actual `/coach` routes
- [ ] Exclude general app routes: `/distancepacegut`, `/plan`, `/adjust-macros`, `/events/create`
- [ ] Test coach portal remains full-width, child screens are windowed (480px centered)

### Files to Modify
- `lib/shared/widgets/root_app_widget.dart` - `_isCoachSession()` logic

---

## Issue 3: Carb Loading Plan Creation for Athletes

### Current State
- Service layer already supports `forUserId` for coach access
- Coach-athlete relationship validation is implemented
- RLS policies exist for carb loading tables

### Decision: Available from both Events tab AND standalone Carb Loading tab

### Fix Plan
- [ ] Add carb loading plan creation UI in coach portal athlete detail panel
- [ ] Wire up `CarbLoadingService.createCarbLoadingPlan()` with `forUserId`
- [ ] Add protocol selection (2-day vs 3-day) dialog
- [ ] Show existing carb loading plans in Carb Loading tab
- [ ] Enable creation from Events tab (linked to event) and standalone
- [ ] Add delete/edit capabilities

### Files to Modify
- `lib/features/coach_mode/presentation/widgets/portal_athlete_detail_panel.dart`
- `lib/features/coach_mode/presentation/providers/athlete_detail_controller.dart`
- New widget: Carb loading creation dialog for coach portal

---

## Issue 4: Activity Creation Fails ("Activity Not Found") - CRITICAL

### Root Cause (CONFIRMED via logs)
1. Activity created with `userId = athlete's ID` (correct)
2. `ActivityDetailController.build()` uses `userIdProvider` = **coach's ID**
3. Query: `WHERE userId = coachId AND id = activityId` = **NO MATCH**

### Fix Plan
- [ ] Pass `forUserId` through navigation extras from adjust-macros to activity detail
- [ ] Update `ActivityDetailController.build()` to accept/use `forUserId`
- [ ] Update `ActivitiesService.getActivityById()` for coach-access queries
- [ ] Test full flow: Create → Adjust macros → View activity detail

### Files to Modify
- `lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart`
- `lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`
- `lib/features/activities/application/activities_service.dart`
- `lib/shared/core/app_router.dart`

---

## Issue 5: Athlete Code Generation + Coach Pairing Flow

### Decisions
- Time-limited code with **24-hour expiry**
- When connected: Show coach name + disconnect button + chat button
- Code-based pairing = primary connection method

### Implementation Plan

#### Athlete Side (Settings)
- [ ] Add "Coach Connection" section to settings menu
- [ ] If NOT connected: "Generate Pairing Code" button
- [ ] Generate random 6-char alphanumeric code, store in Supabase with 24h expiry
- [ ] Display code with copy + share + "Expires in X hours"
- [ ] If CONNECTED: Show coach name, disconnect button, chat button
- [ ] Disconnect archives the relationship with confirmation dialog

#### Coach Side (Portal)
- [ ] Replace name/email search with code entry as primary "Add Athlete" method
- [ ] Code entry field + "Connect" button
- [ ] Validate code, create active relationship on valid code
- [ ] Show success with athlete name
- [ ] Keep name search as secondary fallback

#### Database
- [ ] Create `athlete_pairing_codes` table (Supabase + Drift):
  - `id`, `user_id`, `code` (VARCHAR 6, UNIQUE), `created_at`, `expires_at`, `used_by_coach_id`, `used_at`
- [ ] RLS policies: user creates/reads own codes, coaches read valid codes
- [ ] Schema version bump

### Files to Modify
- `lib/features/settings/presentation/screens/settings_menu_screen.dart`
- New: `coach_connection_screen.dart`
- `lib/features/coach_mode/data/coach_repository.dart`
- `lib/features/coach_mode/presentation/widgets/portal_sidebar.dart`
- New migration: `athlete_pairing_codes` table
- `lib/shared/database/app_database.dart`

---

## Issue 6: Coach Portal as First Screen on Login

### Fix Plan
- [ ] In `TabsScreen`, detect if `kIsWeb && isCoach`
- [ ] Set initial tab index to coach tab (or auto-navigate to `/coach`)
- [ ] Ensure coaches can still navigate back to regular app tabs

### Files to Modify
- `lib/shared/widgets/tabs_screen.dart`

---

## Issue 7: Coach Reports

### Decision: Show whatever data we have

### Plan: "Weekly Athlete Summary" Report
- [ ] Per-athlete summary for last 7 days:
  - Activities completed / planned
  - Average feedback rating (1-5 stars)
  - Carb target adherence (%)
  - Upcoming events (next 14 days)
  - Unread messages
- [ ] Replace "Coming Soon" in reports panel
- [ ] Date range selection (This Week / Last Week / Custom)
- [ ] Graceful "No data yet" states

### Files to Modify
- New: `portal_reports_panel.dart`
- New: `coach_reports_controller.dart`
- `lib/features/coach_mode/presentation/screens/coach_portal_screen.dart`
- `lib/features/coach_mode/data/coach_repository.dart`

---

## Issue 8: Coach Sets Nutrition Targets for Athletes

### Decision: Coach overrides directly (no approval)

### Fix Plan
- [ ] Add "Nutrition Targets" section in athlete detail panel
- [ ] Reuse form from `nutrition_targets_screen.dart` in coach context
- [ ] Write to athlete's `nutrition_target_overrides` with coach as modifier
- [ ] Athlete's plans immediately use new targets
- [ ] Show "Set by coach" indicator in athlete's targets screen

### Files to Modify
- `lib/features/coach_mode/presentation/widgets/portal_athlete_detail_panel.dart`
- `lib/features/nutrition_plan/data/nutrition_plan_repository.dart`
- `lib/features/settings/presentation/screens/nutrition_targets_screen.dart`
- `lib/features/coach_mode/data/coach_repository.dart`

---

## Issue 9: Push Athlete Feedback to TrainingPeaks

### Fix Plan
- [ ] After post-workout feedback, check if TP connected
- [ ] Format: "Mealvana Feedback: [rating] stars - [notes] - Carbs: [up/down/same]"
- [ ] Call `POST /v2/workouts/{athleteId}/id/{workoutId}/comment`
- [ ] Handle 403 (premium required) gracefully
- [ ] Store write-back status, retry on failure

### Files to Modify
- `lib/features/integrations/data/training_peaks_api_client.dart`
- `lib/features/integrations/application/tp_writeback_service.dart`
- `lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart`

---

## Issue 10: Import TP Comments + Bi-directional Sync

### Fix Plan
- [ ] During TP sync, fetch workout comments/description
- [ ] Store comments in activity model or separate table
- [ ] Display TP coach comments in "Coach Feedback" section
- [ ] Push athlete comments back to TP
- [ ] Source indicator (Mealvana vs TrainingPeaks) per comment

### Files to Modify
- `lib/features/integrations/application/training_peaks_sync_service.dart`
- `lib/features/integrations/application/training_peaks_transformer.dart`
- `lib/features/integrations/data/training_peaks_api_client.dart`
- `lib/features/nutrition_plan/presentation/widgets/activity_detail/`

---

## Implementation Order

### Phase 1: Critical Fixes (Issues 4, 1, 2, 6)
Bugs and UX blockers preventing coach mode from being usable.
1. Issue 4 - Activity creation userId mismatch
2. Issue 1 - Athlete search reliability
3. Issue 2 - Full-screen child screens
4. Issue 6 - Coach portal as first screen

### Phase 2: Core Coach Features (Issues 5, 8, 3)
Essential coach capabilities.
5. Issue 5 - Time-limited pairing code flow
6. Issue 8 - Coach sets nutrition targets
7. Issue 3 - Carb loading plan creation

### Phase 3: Reporting & TP Integration (Issues 7, 9, 10)
Value-add features.
8. Issue 7 - Weekly athlete summary report
9. Issue 9 - Push feedback to TP
10. Issue 10 - Import TP comments (bi-directional)

---

## Database Changes Needed
- New `athlete_pairing_codes` table (Supabase + Drift)
- Possibly extend `nutrition_target_overrides` with `set_by_coach_id`
- Schema version bump for Drift changes

---

**Last Updated**: 2026-03-17
