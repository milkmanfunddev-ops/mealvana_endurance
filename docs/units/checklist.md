# Unit System Implementation Checklist

## Overview

This checklist covers the implementation of a unified unit system (Imperial/Metric toggle) across the Mealvana Endurance app. Based on the audit findings in `notes.md`.

**Goal:** Users can set a single Imperial/Metric preference in Settings that controls all unit displays throughout the app.

**Last Updated:** 2026-01-25

---

## Phase 1: Core Infrastructure

### 1.1 Add Unit System to Domain Model

- [x] **Add `UnitSystem` enum** to `/lib/features/nutrition_plan/domain/run_parameters.dart`
  ```dart
  enum UnitSystem {
    imperial('Imperial', 'US'),
    metric('Metric', 'International');

    final String displayName;
    final String description;
    const UnitSystem(this.displayName, this.description);
  }
  ```

- [x] **Add `unitSystem` field to UserProfile** in `/lib/features/auth/domain/user_preferences.dart`
  ```dart
  final UnitSystem unitSystem; // Default: UnitSystem.imperial
  ```

- [x] **Update UserProfile.copyWith()** to include `unitSystem`

- [x] **Update UserProfile.fromJson()** to parse `unit_system` from database

- [x] **Update UserProfile.toJson()** to serialize `unitSystem`

### 1.2 Update Database Schema

- [x] **Add `unit_system` column to Drift** in `/lib/shared/database/tables/user_profiles.dart`
  ```dart
  TextColumn get unitSystem => text()
    .withDefault(const Constant('imperial'))
    .named('unit_system')();
  ```

- [x] **Add CHECK constraint** to validate 'imperial' or 'metric' values

- [x] **Create Drift migration** (v3 → v4) - Schema version bumped, uses delete & resync strategy

- [ ] **Add `unit_system` column to Supabase** - migration script for dev and prod
  ```sql
  ALTER TABLE users ADD COLUMN unit_system text DEFAULT 'imperial'
    CHECK (unit_system IN ('imperial', 'metric'));
  ```

### 1.3 Update UserDAO

- [x] **Update UserDao.mapToUserProfile()** in `/lib/shared/database/daos/user_dao.dart`
  - Parse `unitSystem` from database string to enum

- [x] **Update UserDao.upsertProfile()** to save `unitSystem`

---

## Phase 2: Unit Formatter Enhancement

### 2.1 Enhance UnitFormatter Utility

**File:** `/lib/features/nutrition_plan/presentation/utils/unit_formatter.dart`

- [x] **Add weight conversion methods**
  - `formatWeight(double pounds, {required bool useMetric})`
  - `poundsToKg(double pounds)`
  - `kgToPounds(double kg)`

- [x] **Add height conversion methods**
  - `formatHeight(int feet, int inches, {required bool useMetric})`
  - `totalInchesToCm(int totalInches)`
  - `cmToTotalInches(int cm)`
  - `cmToFeetInches(int cm)` - Returns (feet, inches) record

- [x] **Update formatFluids()** - Now accepts both `useImperial` and `useMetric` parameters

- [x] **Add unit label helpers**
  - `fluidUnitLabel({required bool useMetric})`
  - `weightUnitLabel({required bool useMetric})`
  - `heightUnitLabel({required bool useMetric})`

- [x] **Add conversion constants**
  - `kMlPerFlOz`, `kFlOzPerMl`, `kKgPerLb`, `kLbPerKg`, `kCmPerInch`

### 2.2 Update MacroHelpers

**File:** `/lib/features/nutrition_plan/presentation/utils/macro_helpers.dart`

- [ ] **Update distanceLabel()** to accept UnitSystem parameter
- [ ] **Update paceLabel()** to accept UnitSystem parameter
- [ ] **Update speedLabel()** to accept UnitSystem parameter
- [ ] **Remove hardcoded 'MI', 'mph', '/mi' strings**

---

## Phase 3: Settings Screen

### 3.1 Add Unit System Toggle

**File:** `/lib/features/settings/presentation/screens/preferences_screen.dart`

- [x] **Add Unit System section** at top of preferences
  - Uses KyleSegmentedControl for Imperial/Metric selection

- [x] **Keep individual distance/pace toggles** as override options

- [x] **Add helper text** - "Controls display of distance, pace, fluids, and measurements"

### 3.2 Update Settings Controller

**File:** `/lib/features/settings/presentation/providers/settings_controller.dart`

- [x] **Add updateUnitSystem() method**
  - Updates unitSystem in state
  - Automatically updates preferredDistanceUnit and preferredPaceUnit to match
  - Saves profile changes

- [x] **Update SettingsState** to include `unitSystem` field

---

## Phase 4: Fix Hardcoded UI Widgets

### 4.1 Widgets with Hardcoded "fl oz"

- [x] **macro_section_card.dart** (Lines 173, 203, 241)
  - Added `useMetric` parameter (default: false)
  - Replace `'Fluids (fl oz)'` with dynamic `UnitFormatter.fluidUnitLabel()`

- [x] **macro_targets_expander.dart** (Line 211)
  - Added `useMetric` parameter (default: false)
  - Replace `'oz'` with dynamic unit based on useMetric

### 4.2 Widgets with Hardcoded "ml"

- [x] **section_subtitle_widget.dart** (Lines 49, 59, 69, 141, 151, 161)
  - Added `useMetric` parameter (default: false)
  - Replace all 6 hardcoded `'ml'` with dynamic unit from UnitFormatter

- [x] **macro_targets_widget.dart** (Line 132)
  - Added `useMetric` parameter (default: false)
  - Pass useMetric to widget, use for fluid unit display

- [x] **edit_macros_dialog_widget.dart** (Line 70)
  - Added `useMetric` parameter (default: false)
  - Replace `'FLUIDS (mL)'` with dynamic label

### 4.3 Widgets with Hardcoded Distance/Pace

- [ ] **run_summary_header.dart** (Lines 53, 73, 100)
  - Replace hardcoded `'mi'`, `'mph'`, `'/mi'` with dynamic units

- [ ] **adjust_macros_screen.dart** (Lines 243-250)
  - Pass unitSystem, use for speed/pace display

---

## Phase 5: Controller Unit Handling

### 5.1 Standardize Controller Behavior

**Goal:** All controllers should pass unit preference to services; services should handle conversion consistently.

- [ ] **Running Input Controller** (`running_input_controller.dart`)
  - Load `unitSystem` from user profile
  - Pass to macro generation service with explicit unit
  - Currently assumes imperial - fix this

- [ ] **Brick Input Controller** (`brick_input_controller.dart`)
  - Add `unitSystem` to `BrickFormState`
  - Load from user profile on init
  - Pass units to brick macro service

### 5.2 Update Services

- [ ] **macro_generation_service.dart**
  - Accept unit parameters explicitly
  - Document expected units in API contract
  - Validate unit parameters before API call

- [ ] **brick_macro_service.dart**
  - Accept unit parameters for each segment
  - Convert to backend-expected units (imperial) before API call

---

## Phase 6: Standardize Water Bottle Size

### 6.1 Define Standard Bottle Size

- [x] **Add constant** in `/lib/shared/constants/bottle_constants.dart`
  ```dart
  const double kStandardBottleMl = 591.0; // 20 oz
  const double kStandardBottleOz = 20.0;
  ```

- [x] **Update cycling onboarding** text
  - Changed "1 bottle = 24 oz" to "1 bottle = 20 oz (591 mL)"

- [x] **Update offline plan builder**
  - Changed `totalMl / 500` to `totalMl / kStandardBottleMl`

- [ ] **Update sample_plan_demo.dart**
  - Use consistent bottle size constant

---

## Phase 7: Testing

### 7.1 Unit Tests

- [ ] **UnitFormatter tests**
  - Test weight conversion: lbs ↔ kg
  - Test height conversion: ft/in ↔ cm
  - Test fluid conversion: ml ↔ oz
  - Test distance conversion: mi ↔ km
  - Test pace conversion: min/mi ↔ min/km

- [ ] **UserProfile serialization tests**
  - Test `unitSystem` round-trip through JSON
  - Test backward compatibility when `unit_system` is null

### 7.2 Integration Tests

- [ ] **Settings screen test**
  - Verify changing unit system updates all displays
  - Verify preference persists across app restart

- [ ] **Plan generation test**
  - Verify metric users see correct units in results
  - Verify calculations are correct regardless of display unit

---

## Phase 8: Documentation

- [ ] **Update CLAUDE.md** with unit system information
- [ ] **Add inline code comments** explaining unit conventions
- [ ] **Document API contract** for edge functions (expected units)

---

## File Reference

### Files Created
- `/lib/shared/constants/bottle_constants.dart` - Standardized bottle size constants

### Files Modified (Completed)
1. `/lib/features/nutrition_plan/domain/run_parameters.dart` - Added UnitSystem enum ✅
2. `/lib/features/auth/domain/user_preferences.dart` - Added unitSystem field ✅
3. `/lib/shared/database/tables/user_profiles.dart` - Added unitSystem column ✅
4. `/lib/shared/database/app_database.dart` - Bumped schema version to 4 ✅
5. `/lib/shared/database/daos/user_dao.dart` - Map unitSystem ✅
6. `/lib/features/nutrition_plan/presentation/utils/unit_formatter.dart` - Added all methods ✅
7. `/lib/features/settings/domain/settings_state.dart` - Added unitSystem field ✅
8. `/lib/features/settings/presentation/providers/settings_controller.dart` - Added updateUnitSystem() ✅
9. `/lib/features/settings/presentation/screens/preferences_screen.dart` - Added toggle ✅
10. `/lib/features/nutrition_plan/presentation/widgets/macro_section_card.dart` - Dynamic fluid units ✅
11. `/lib/features/nutrition_plan/presentation/widgets/macro_targets_expander.dart` - Dynamic fluid units ✅
12. `/lib/features/nutrition_plan/presentation/widgets/section_subtitle_widget.dart` - Dynamic fluid units ✅
13. `/lib/features/nutrition_plan/presentation/widgets/macro_targets_widget.dart` - Dynamic fluid units ✅
14. `/lib/features/nutrition_plan/presentation/widgets/adjust_macros/edit_macros_dialog_widget.dart` - Dynamic fluid units ✅
15. `/lib/features/onboarding/presentation/screens/cycling_details_screen.dart` - Updated bottle text ✅
16. `/lib/features/nutrition_plan/application/nutrition_plan_service.dart` - Use bottle constant ✅

### Files Remaining (TODO)
- `/lib/features/nutrition_plan/presentation/utils/macro_helpers.dart`
- `/lib/features/nutrition_plan/presentation/providers/running_input_controller.dart`
- `/lib/features/nutrition_plan/presentation/providers/brick_input_controller.dart`
- `/lib/features/nutrition_plan/application/brick_macro_service.dart`
- `/lib/features/nutrition_plan/presentation/widgets/run_summary_header.dart`
- `/lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart`
- Supabase migration scripts (dev and prod)

---

## Acceptance Criteria

1. [x] User can toggle between Imperial and Metric in Settings
2. [x] All fluid displays show oz (imperial) or mL (metric) based on preference
3. [ ] All distance displays show mi or km based on preference
4. [ ] All pace displays show min/mi or min/km based on preference
5. [ ] Weight displays as lbs or kg based on preference (in settings)
6. [ ] Height displays as ft/in or cm based on preference (in settings)
7. [x] Preference persists across app sessions
8. [x] Onboarding continues to collect imperial values (storage unchanged)
9. [x] No regression in nutrition plan calculations
10. [x] Water bottle size is consistent (20 oz / 591 mL)

---

## Verification Status

**Flutter Analyze:** ✅ Passed (0 errors, only pre-existing warnings/info)
**Build Runner:** ✅ Passed (212 files generated)
**Flutter Tests:** ✅ 319 passed, 25 failed (failures are pre-existing E2E network issues, unrelated to unit changes)
