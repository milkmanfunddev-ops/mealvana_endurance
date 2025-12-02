# Test Infrastructure for App Startup

## Created Files

### Test Helpers

#### 1. Console Logging Utilities (`test/helpers/utils/console_logging.dart`)
Provides structured, colored console output for test debugging:
- `logTestHeading()` - Test title with divider
- `logTestSetup()` - Configuration details
- `logTestInput()` - Input parameters
- `logTestResult()` / `logTestResults()` - Single or multiple results
- `logAssertion()` - Validation checks with pass/fail status
- `logTestPass()` / `logTestFail()` - Final test status
- `logSection()`, `logApiCall()`, `logDatabaseOp()`, `logAnalyticsEvent()` - Contextual logging

#### 2. Recording Analytics Tracker (`test/helpers/fakes/recording_analytics_tracker.dart`)
Test double for AnalyticsTracker that captures all calls:
- Implements `AnalyticsTracker` interface
- Records all events, identifications, timed events
- Provides query methods: `hasEvent()`, `findEvents()`, `lastEvent`
- Tracks initialization state and flush count

#### 3. Recording Sentry Reporter (`test/helpers/fakes/recording_sentry_reporter.dart`)
Test double for SentryReporter that captures all calls:
- Implements `SentryReporter` interface
- Records exceptions, breadcrumbs, user contexts, messages
- Provides query methods: `hasBreadcrumb()`, `findBreadcrumbs()`, `lastException`
- Tracks user context operations

#### 4. Recording App Logger (`test/helpers/fakes/recording_app_logger.dart`)
Test double for AppLogger that captures all calls:
- Implements `AppLogger` interface
- Records all log levels: debug, info, warning, error, fatal
- Records specialized logs: api, database, navigation, user actions, nutrition plans, analytics
- Provides query methods: `findBy Level()`, `findByContext()`, `hasErrors`, `errorMessages`

#### 5. User Fixtures (`test/helpers/fixtures/user_fixtures.dart`)
Consistent test data for user profiles:
- `UserFixtures.freshUser()` - No onboarding completed
- `UserFixtures.completedUser()` - Onboarding complete
- `UserFixtures.beginner()` - Low gut training
- `UserFixtures.advanced()` - High gut training
- `UserFixtures.heavyAthlete()` / `lightAthlete()` - Different weights
- `UserFixtures.ultraRunner()` - Experienced endurance athlete
- `UserFixtures.oauthUser()` - OAuth authenticated user
- `UserHelpers` - Helper functions (weight conversion, age calc, etc.)

### Integration Tests

#### App Startup Tests (`test/integration/flows/app_startup_test.dart`)
Comprehensive tests for Andrea Bizzotto's initialization pattern:

**Test Coverage:**
1. ✓ Initializes all services in parallel (analytics, database, auth, Sentry)
2. ✓ Returns no user for fresh install
3. ✓ Returns existing user with completed onboarding
4. ✓ Returns existing user with incomplete onboarding
5. ✓ Detects activity needing feedback (past run without rating/notes)
6. ✓ Tracks startup completion in Sentry breadcrumbs
7. ✓ Handles startup errors gracefully (logs and re-throws)
8. ✓ Navigation data for fresh install → `/welcome`
9. ✓ Navigation data for completed onboarding → `/main`

**Test Patterns:**
- Uses `ProviderContainer` for fast provider-only tests (no widget pumping)
- Creates in-memory Drift database with `AppDatabase.memory()`
- Overrides providers with recording mocks
- Seeds database with test fixtures
- Verifies analytics events, Sentry breadcrumbs, log records
- Tests AppStartupData structure for navigation decisions

## Known Issues & Remaining Work

### 1. Supabase Auth Mocking Challenge

**Problem:** The AppStartupService depends on SupabaseClient for authentication, which is complex to mock:
- `initializeSupabaseAuth()` calls `_supabase.auth.signInAnonymously()`
- `_supabase.auth.currentSession` check
- Auth state listeners for OAuth callbacks

**Current State:** Tests skip Supabase-dependent operations:
```dart
// Note: We cannot easily mock SupabaseClient without significant refactoring
// For now, tests that require Supabase will skip or use a fake implementation
```

**Options to Fix:**
1. **Create FakeSupabaseClient** (Recommended):
   - Implement fake `GoTrueClient` with in-memory session storage
   - Return fake sessions/users for test scenarios
   - File: `test/helpers/fakes/fake_supabase_client.dart`
   - Complex but most realistic

2. **Extract Auth Logic to Service Layer**:
   - Move Supabase auth calls to injectable `AuthService`
   - Create `RecordingAuthService` test double
   - Refactor `AppStartupService` to depend on `AuthService`
   - Cleaner but requires production code changes

3. **Use Mockito/Mocktail**:
   - Generate mocks for `SupabaseClient` and `GoTrueClient`
   - Setup stub responses for each test
   - May be fragile due to complex Supabase SDK internals

### 2. Provider Override Type Errors

**Problem:** Recording mock classes can't be directly assigned to provider override values due to type constraints.

**Current Errors:**
```
The argument type 'RecordingAnalyticsTracker' can't be assigned to the parameter type 'AnalyticsTracker'.
```

**Root Cause:** The recording classes implement the interfaces but Dart's type system sees them as incompatible due to how the providers are defined.

**Fix Options:**
1. **Explicit Casting** (Quick Fix):
   ```dart
   analyticsTrackerProvider.overrideWithValue(analytics as AnalyticsTracker)
   ```

2. **Provider Override With Build** (Better):
   ```dart
   analyticsTrackerProvider.overrideWith((ref) => analytics)
   ```

3. **Verify Interface Implementation** (Best):
   - Ensure recording classes properly implement ALL abstract members
   - May need to add missing methods or fix signatures

### 3. Drift Companion Object Usage

**Problem:** Two compile errors with `Value` usage in activities table insert:
```dart
createdAt: Value(DateTime.now()),  // ERROR: Value<DateTime> ≠ DateTime
updatedAt: Value(DateTime.now()),  // ERROR: Value<DateTime> ≠ DateTime
```

**Fix:** ActivitiesTableCompanion expects DateTime directly for these fields:
```dart
createdAt: DateTime.now(),  // Correct
updatedAt: DateTime.now(),  // Correct
```

## Next Steps

### Immediate (Fix Compilation Errors):
1. Remove `Value()` wrapper from `createdAt` and `updatedAt` in activity inserts
2. Add explicit casts or use `overrideWith` for recording mock providers
3. Run tests to verify they pass

### Short-term (Complete App Startup Tests):
1. Create `FakeSupabaseClient` test double
2. Override `supabaseClientProvider` in test container
3. Remove "Note" comments about Supabase skipping
4. Verify auth-related assertions work

### Medium-term (Expand Test Coverage):
1. Create tests for `AppStartupService` methods individually
2. Add widget tests for `AppStartupWidget` (loading/error/success states)
3. Create tests for GoRouter redirect logic with various startup states
4. Test background data sync behavior

### Long-term (Infrastructure Improvements):
1. Add test for app startup with network failure scenarios
2. Test migration from anonymous to OAuth user during startup
3. Performance tests for startup time (<2s target)
4. Integration test with real local Supabase instance

## Running Tests

```bash
# Run all integration tests
flutter test test/integration/

# Run specific app startup tests
flutter test test/integration/flows/app_startup_test.dart

# Run with verbose output
flutter test test/integration/flows/app_startup_test.dart --verbose

# Run specific test by name
flutter test test/integration/flows/app_startup_test.dart --plain-name "initializes all services"
```

## Test Philosophy

Following the project's risk-based testing approach:
- **Fast** - Tests use in-memory database, no widget pumping
- **Deterministic** - Fully controlled test data, no external dependencies
- **Structured Logging** - Every test emits clear console output for debugging
- **FOA Compliant** - Tests follow feature-oriented architecture layers
- **Riverpod 3 Patterns** - Uses `ProviderContainer.test()` and `AsyncValue.guard()`

## References

- [Main Testing Handbook](/docs/test/README.md)
- [Riverpod 3 Testing Guide](/docs/test/riverpod_3_testing.md)
- [Andrea Bizzotto's Initialization Pattern](/docs/technical/andrea/andrea_initialization.txt)
- [App Startup Documentation](/docs/technical/app-startup.md)
