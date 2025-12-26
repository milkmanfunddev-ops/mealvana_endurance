# Integration Test Update Plan

**Created:** 2025-12-18
**Status:** Planning Phase
**Priority:** High - Complete UI redesign requires full test rewrite

---

## Executive Summary

The Mealvana Endurance app has undergone a **complete UI redesign** affecting both onboarding and main app flows. All integration tests require significant updates to match the new architecture.

**Key Changes:**
- ✅ New PageView-based onboarding (8 dynamic screens)
- ✅ Activities-first main app with tab navigation (3 tabs)
- ✅ Unified activity creation screen (multi-sport)
- ✅ New dietary preferences, allergies, and food selection
- ❌ Tests are 100% outdated and will fail

---

## Current App Architecture

### Complete User Flow

```
/welcome (WelcomeScreen)
  ↓ "Get Started"
/onboarding (OnboardingPageViewScreen - PageView with swipe)
  ├─ Page 1: User Profile (gender, birthday, height, weight)
  ├─ Page 2: Sports Selection (Running/Cycling/Swimming checkboxes)
  ├─ Page 3-5: [DYNAMIC] Sport Details
  │   ├─ Running Details (water bottle toggle)
  │   ├─ Cycling Details (FTP, water bottles, aero, bento box)
  │   └─ Swimming Details (CSS, wetsuit, swim cap)
  ├─ Page 6: Dietary Preference (Omnivore, Vegetarian, etc.)
  ├─ Page 7: Allergies (Dairy, Eggs, Fish, etc.)
  └─ Page 8: Food Preferences V2 (chip-based selection with search)
  ↓ Final page "Continue"
/auth/post-onboarding (PostOnboardingAuthScreen)
  ├─ Apple Sign In
  ├─ Google Sign In
  ├─ Email Sign Up
  └─ Continue without signing in
  ↓
/main (TabsScreen - 3 tabs with floating action buttons)
  ├─ Tab 0: Activities List (calendar picker + activities)
  ├─ Tab 1: Feature Survey
  └─ Tab 2: Settings

Floating Action Buttons:
  ├─ Calendar button (toggle view or navigate to Activities)
  ├─ Survey button (navigate to Survey tab)
  ├─ Menu button (navigate to Settings tab)
  └─ + button (create new activity → /distancepacegut)
```

### Key Navigation Patterns

1. **Onboarding:** PageView with swipe + Continue buttons (dynamic pages based on sport selection)
2. **Main App:** Tab-based with IndexedStack (no traditional bottom nav bar)
3. **Activity Creation:** Single unified screen for all sports (NewActivityScreen)
4. **Food Management:** Chip-based selection instead of sliders

---

## Test Files Requiring Updates

### 1. Onboarding & Auth Flow Test ⚠️ COMPLETE REWRITE
**File:** `integration_test/flows/onboarding_auth_flow_test.dart`

**Current Test Expectations (OUTDATED):**
- Welcome Screen → "Get Started"
- Your Profile → Gender, Birthday, Height, Weight
- Sport Preferences → Radio buttons, Gut Sensitivity
- Food Preferences → Sliders (Avoid ↔ Love)
- Create Account → Auth options

**New Test Requirements:**
1. Welcome Screen
   - Find "Get Started" button
   - Tap to navigate to onboarding

2. Page 1: User Profile
   - Select gender
   - Enter birthday (date picker)
   - Enter height
   - Enter weight
   - Tap "Continue"

3. Page 2: Sports Selection
   - Select Running (checkbox)
   - Optionally select Cycling/Swimming
   - Tap "Continue"

4. Pages 3-5: Sport Details (Dynamic)
   - IF Running selected:
     - Toggle "I run with a water bottle"
     - Tap "Continue"
   - IF Cycling selected:
     - Enter FTP (or 0)
     - Select water bottle count (1/2/3+)
     - Toggle "I use Aero Bottles"
     - Toggle "I use a Bento Box for food"
     - Tap "Continue"
   - IF Swimming selected:
     - Enter CSS (minutes:seconds)
     - Toggle "I typically wear a wetsuit"
     - Select swim cap type (None/Latex/Silicone/Neoprene)
     - Tap "Continue"

5. Page 6: Dietary Preference
   - Select radio button (Omnivore recommended)
   - Tap "Continue"

6. Page 7: Allergies
   - Optionally check allergies
   - Tap "Continue"

7. Page 8: Food Preferences V2
   - Search for foods (optional)
   - Tap food chips to select
   - Remove foods by tapping X on chips
   - Tap "Continue"

8. Post-Onboarding Auth
   - Tap "Continue without signing in" OR
   - Tap "Sign up with Email" → Email signup flow

**Complexity:** High - Requires PageView navigation, dynamic page handling

---

### 2. Email Login Flow Test ⚠️ MINOR UPDATES
**File:** `integration_test/flows/email_login_flow_test.dart`

**Current Test:** Logs in with test@test.com / test

**Required Updates:**
- Verify navigation after login goes to `/main` (TabsScreen)
- Verify Activities tab is shown (tab 0)
- Update any screen verification assertions

**Complexity:** Low - Mostly endpoint changes

---

### 3. Nutrition Plan Flow Test ⚠️ MAJOR UPDATES
**File:** `integration_test/flows/nutrition_plan_flow_test.dart`

**Current Test Expectations (OUTDATED):**
- Navigate to Calendar screen
- Find "CREATE AN EVENT"
- Create event
- Create nutrition plan from event

**New Test Requirements:**
1. Start at /main (Activities tab)
2. Tap "+" floating action button
3. NewActivityScreen opens (multi-sport tabs)
   - Select sport tab (Running/Cycling/Swimming)
   - Enter distance
   - Enter pace/speed/CSS
   - Select gut training level
   - Tap "Generate Plan"
4. Verify navigation to macro adjustment screen
5. Adjust macros if needed
6. Tap "Create Plan"
7. Verify nutrition plan created
8. Test food swap functionality
9. Test food deletion
10. Test adding custom food

**Complexity:** High - Complete screen flow changed

---

### 4. Food Management Flow Test ⚠️ MAJOR UPDATES
**File:** `integration_test/flows/food_management_flow_test.dart`

**Current Test Expectations (OUTDATED):**
- Food preference sliders
- OpenFoodFacts search

**New Test Requirements:**
1. Navigate to Settings tab
2. Tap "Food Preferences" (or similar)
3. Use chip-based selection interface:
   - Search for foods
   - Tap chips to select
   - Remove by tapping X
4. Save changes
5. Verify preferences persisted

**Complexity:** High - UI paradigm completely changed (sliders → chips)

---

### 5. Settings Flow Test ⚠️ MODERATE UPDATES
**File:** `integration_test/flows/settings_flow_test.dart`

**Current Test Expectations:**
- Navigate to Settings
- Update profile
- Change appearance

**New Test Requirements:**
1. Tap Menu floating button (bottom right)
2. SettingsScreen shown (tab 2)
3. Test various settings options:
   - Profile & Preferences
   - Appearance
   - Food Preferences
   - Sport Settings
   - Help & Feedback

**Complexity:** Moderate - Need to verify new settings structure

---

### 6. Event Management Flow Test ⚠️ MAJOR UPDATES
**File:** `integration_test/flows/event_management_flow_test.dart`

**Current Test Expectations (OUTDATED):**
- BY WEEK / BY MONTH calendar
- "CREATE AN EVENT" button
- Event list

**New Test Requirements:**
1. Start at Activities tab (has calendar picker)
2. Find event creation mechanism (TBD - need to verify UI)
3. Create event with:
   - Sport category
   - Race distance
   - Event name
   - Location
   - Date
4. Edit event
5. Delete event
6. Verify database consistency

**Complexity:** High - Event creation flow may have changed significantly

---

## Bug Regression Tests

### Critical Data Integrity Tests (NEW)

Based on `BUG_REGRESSION_TRACKING.md`, add these verification checks:

#### 1. Activity Count Verification
**Location:** After creating activities in nutrition_plan_flow_test.dart

```dart
// FAIL-FAST: Verify activity count matches database
test('Activity count matches database', () async {
  // Query database for activity count
  final dbCount = await database.getActivityCount(userId);

  // Count visible activities in UI
  final visibleActivities = find.byType(ActivityCard);
  final visibleCount = tester.widgetList(visibleActivities).length;

  // FAIL IMMEDIATELY if mismatch
  expect(visibleCount, equals(dbCount),
    reason: 'BUG-001: Found $dbCount activities in database but only $visibleCount visible in UI');
});
```

#### 2. Food Preferences Persistence
**Location:** After saving food preferences in food_management_flow_test.dart

```dart
// FAIL-FAST: Verify food preferences persist
test('Food preferences persist across sessions', () async {
  // Save preferences
  final savedFoods = ['banana', 'energy gel', 'water'];
  // ... save foods ...

  // Restart app simulation
  await tester.restartApp();

  // Navigate back to food preferences
  // ... navigate ...

  // Verify all foods still selected
  for (final food in savedFoods) {
    final chip = find.widgetWithText(Chip, food);
    expect(chip, findsOneWidget,
      reason: 'BUG-002: Food "$food" not found after app restart');
  }
});
```

#### 3. Event Data Integrity
**Location:** event_management_flow_test.dart

```dart
// FAIL-FAST: Verify event data matches database
test('Event data integrity check', () async {
  // Create event
  final eventData = TestEventData(
    name: 'Test Marathon',
    date: DateTime(2025, 6, 15),
    location: 'Chicago',
    distance: 42.2,
  );
  // ... create event ...

  // Query database
  final dbEvent = await database.getEventById(eventId);

  // Verify exact match
  expect(dbEvent.name, equals(eventData.name),
    reason: 'BUG-003: Event name mismatch');
  expect(dbEvent.date, equals(eventData.date),
    reason: 'BUG-003: Event date mismatch');
  expect(dbEvent.location, equals(eventData.location),
    reason: 'BUG-003: Event location mismatch');
});
```

#### 4. Carb Loading Plans
**Location:** New test file: `integration_test/flows/carb_loading_flow_test.dart`

```dart
test('Carb loading plans save correctly', () async {
  // Create carb loading plan
  final plan = await createCarbLoadingPlan(
    eventId: testEventId,
    startDate: DateTime(2025, 6, 10),
    endDate: DateTime(2025, 6, 14),
  );

  // Verify plan exists in database
  final dbPlan = await database.getCarbLoadingPlan(plan.id);
  expect(dbPlan, isNotNull,
    reason: 'BUG-004: Carb loading plan not found in database');

  // Verify all days saved
  expect(dbPlan!.days.length, equals(5),
    reason: 'BUG-004: Expected 5 days, found ${dbPlan.days.length}');

  // Verify meals for each day
  for (final day in dbPlan.days) {
    expect(day.meals, isNotEmpty,
      reason: 'BUG-004: Day ${day.date} has no meals');
  }
});
```

---

## Test Account Data Requirements

The test account (`test@test.com`) must have **known, verifiable data** to enable fail-fast assertions.

### Required Data Setup

```sql
-- User Profile
INSERT INTO users (id, email, gender, birthday, height_cm, weight_kg)
VALUES ('test-user-id', 'test@test.com', 'male', '1990-01-01', 175, 70);

-- Sports (at least Running selected)
UPDATE users SET
  running_enabled = true,
  runs_with_water_bottle = true
WHERE id = 'test-user-id';

-- Dietary Preferences
UPDATE users SET
  dietary_preference = 'omnivore',
  allergies = ARRAY[]::text[]
WHERE id = 'test-user-id';

-- Food Preferences (exactly 5 known foods for verification)
INSERT INTO food_preferences (user_id, food_id, preference_level)
VALUES
  ('test-user-id', 'banana', 5),
  ('test-user-id', 'energy-gel', 5),
  ('test-user-id', 'water', 5),
  ('test-user-id', 'oatmeal', 3),
  ('test-user-id', 'protein-bar', 4);

-- Activities (exactly 5 for count verification)
INSERT INTO activities (id, user_id, sport_type, distance_km, created_at)
VALUES
  ('activity-1', 'test-user-id', 'running', 5.0, '2025-01-01'),
  ('activity-2', 'test-user-id', 'running', 10.0, '2025-01-02'),
  ('activity-3', 'test-user-id', 'running', 21.1, '2025-01-03'),
  ('activity-4', 'test-user-id', 'cycling', 40.0, '2025-01-04'),
  ('activity-5', 'test-user-id', 'swimming', 2.0, '2025-01-05');

-- Events (exactly 3 for count verification)
INSERT INTO events (id, user_id, name, event_date, location, distance_km)
VALUES
  ('event-1', 'test-user-id', 'Test 5K', '2025-06-01', 'Chicago', 5.0),
  ('event-2', 'test-user-id', 'Test Half Marathon', '2025-07-01', 'Boston', 21.1),
  ('event-3', 'test-user-id', 'Test Marathon', '2025-08-01', 'New York', 42.2);

-- Carb Loading Plans (2 plans for verification)
INSERT INTO carb_loading_plans (id, user_id, event_id, start_date, end_date)
VALUES
  ('carb-plan-1', 'test-user-id', 'event-2', '2025-06-26', '2025-06-30'),
  ('carb-plan-2', 'test-user-id', 'event-3', '2025-07-27', '2025-07-31');
```

### Test Account Verification Script

Create `integration_test/helpers/fixtures/setup_test_account.dart`:

```dart
/// Sets up test account with known data for integration tests
/// Run before test suite to ensure consistent state
Future<void> setupTestAccount() async {
  final database = await getDatabase();
  final userId = 'test-user-id';

  // Clear existing data
  await database.deleteAllUserData(userId);

  // Set up user profile
  await database.insertUser(TestUserFixtures.testUser);

  // Set up food preferences (exactly 5)
  for (final pref in TestFoodPreferenceFixtures.testPreferences) {
    await database.insertFoodPreference(pref);
  }

  // Set up activities (exactly 5)
  for (final activity in TestActivityFixtures.testActivities) {
    await database.insertActivity(activity);
  }

  // Set up events (exactly 3)
  for (final event in TestEventFixtures.testEvents) {
    await database.insertEvent(event);
  }

  // Verify counts
  assert(await database.getActivityCount(userId) == 5, 'Expected 5 activities');
  assert(await database.getEventCount(userId) == 3, 'Expected 3 events');
  assert(await database.getFoodPreferenceCount(userId) == 5, 'Expected 5 food preferences');
}
```

---

## Codemagic Integration

### Current Workflow
**File:** `codemagic.yaml`

**Current Integration Test Workflow (lines 441-527):**
```yaml
integration-tests:
  name: Integration Tests
  scripts:
    - flutter pub get
    - dart run build_runner build
    - flutter test integration_test/flows/onboarding_auth_flow_test.dart
    - boot_ios_simulator
    - run integration tests
    - shutdown_ios_simulator
```

### Required Updates

1. **Add test account setup step:**
```yaml
- name: Set up test account
  script: |
    # Run setup script to populate test account
    flutter test integration_test/helpers/fixtures/setup_test_account.dart
```

2. **Update test execution for new structure:**
```yaml
- name: Run integration tests
  script: |
    # Run all integration tests with fail-fast
    flutter test integration_test/test_runner.dart \
      -d "$TEST_DEVICE" \
      --reporter expanded \
      --fail-fast \
      2>&1 | tee test-results/integration-tests.log
```

3. **Add fail-fast flag** to stop immediately on first failure (bug detected)

4. **Keep existing simulator management** (boot/shutdown scripts look good)

---

## Implementation Phases

### Phase 1: Foundation (1-2 days)
- [ ] Update `BUG_REGRESSION_TRACKING.md` with all discovered bugs
- [ ] Create test account setup script (`setup_test_account.dart`)
- [ ] Populate test account with known data
- [ ] Create test fixtures for all data types
- [ ] Update test_config.dart with new screen expectations

### Phase 2: Helper Updates (1 day)
- [ ] Add PageView navigation helpers
- [ ] Add chip selection helpers (for food preferences)
- [ ] Add sport-specific form helpers (FTP, CSS, water bottles)
- [ ] Add tab navigation helpers
- [ ] Add database verification helpers

### Phase 3: Onboarding Tests (2-3 days)
- [ ] Rewrite onboarding_auth_flow_test.dart for new PageView flow
- [ ] Add tests for dynamic sport details screens
- [ ] Add tests for dietary preference selection
- [ ] Add tests for allergies selection
- [ ] Add tests for food chip selection
- [ ] Add fail-fast data verification assertions

### Phase 4: Main App Tests (2-3 days)
- [ ] Update email_login_flow_test.dart for TabsScreen navigation
- [ ] Rewrite nutrition_plan_flow_test.dart for NewActivityScreen
- [ ] Rewrite food_management_flow_test.dart for chip-based UI
- [ ] Update settings_flow_test.dart for new settings structure
- [ ] Rewrite event_management_flow_test.dart for new calendar/activities UI

### Phase 5: Bug Regression Tests (1-2 days)
- [ ] Add activity count verification tests
- [ ] Add food preference persistence tests
- [ ] Add event data integrity tests
- [ ] Add carb loading plan verification tests
- [ ] Add all bug-specific regression tests

### Phase 6: Codemagic Integration (1 day)
- [ ] Update codemagic.yaml with test account setup
- [ ] Add fail-fast flag to test execution
- [ ] Test full CI/CD pipeline
- [ ] Verify tests run on PR triggers
- [ ] Document CI/CD test results reporting

---

## Success Criteria

✅ **All integration tests pass** on latest develop branch
✅ **Fail-fast assertions catch bugs** immediately (activity count, food persistence, etc.)
✅ **Test account has known data** for consistent verification
✅ **Codemagic runs tests** on every PR to develop/release branches
✅ **Tests complete in under 30 minutes** (acceptable for CI/CD)
✅ **Documentation updated** with new screen flows and test patterns

---

## Questions for User

Before starting implementation, please confirm:

1. **Should I start with Phase 1 (Foundation)?**
   - Set up test account with known data first
   - Create fixtures and helpers
   - Then tackle test rewrites

2. **Do you want to fill in bug details in `BUG_REGRESSION_TRACKING.md` first?**
   - Or should I proceed with known bugs (activity count, food preferences, events, carb loading)

3. **Priority order:**
   - Option A: Onboarding tests first (get basic flow working)
   - Option B: Main app tests first (more critical business logic)
   - Option C: Bug regression tests first (prevent known issues)

4. **Timeline expectations:**
   - Estimated 8-12 days for complete update
   - Can be faster if we parallelize or reduce scope
   - What's your target deadline?

