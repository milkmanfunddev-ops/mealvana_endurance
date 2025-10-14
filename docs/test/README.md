# Mealvana Endurance Testing Handbook

This guide explains how we structure, write, and run tests across the Mealvana Endurance codebase. It reflects the decoupling strategy, Riverpod 3 upgrade, Supabase edge-function priorities, and the roadmap outlined in `docs/test/roadmap.md`.

---

## 1. Philosophy & Priorities

We pursue risk-based, high-impact coverage:

1. **Edge functions** – ensure Supabase functions (plan generation, etc.) stay correct; cloud dev project is the primary target, with local parity via Supabase CLI.
2. **Drift schema migrations** – guarantee v1 → v2 (and future) migrations preserve data.
3. **Nutrition safety & macro accuracy** – controllers/services must enforce food suitability, macro tolerances, hydration requirements.
4. **Authentication & onboarding** – device ID, profile flows, and startup logic.
5. **Content delivery** – CMS data should gracefully fall back to defaults when offline.
6. **Critical UI flows** – widget tests only for screens that tie directly to the above.

Every test must be fast, deterministic, and emit a structured console log (we’ll reassess once coverage stabilizes).

---

## 2. Directory Layout

```
test/
  features/
    <feature>/
      presentation/   # Controllers + widget tests
      application/    # Services/AsyncNotifiers
      domain/         # Pure models/value objects
      data/           # Repositories/DAOs
  integration/
    drift/            # Schema migration tests
    edge/             # Supabase edge integration tests (tagged)
    flows/            # Cross-feature journeys (startup, onboarding → plan)
  helpers/
    fakes/            # Reusable test doubles (FakeSupabaseClient, RecordingAuthService, etc.)
    fixtures/         # JSON/Map fixtures for plans, profiles, schema data
    utils/            # Console logging helpers, provider utilities
  local_edge_functions/
    functions/        # Node/Vitest mirror of Supabase edge functions
    tests/            # Vitest suites + fixtures for edge logic
```

Create directories on demand. Keep helpers DRY so new suites only wire overrides and assertions.

---

## 3. Prerequisites & Environment Setup

### 3.1 Supabase CLI & Docker

Edge tests (especially local parity) require Docker + Supabase CLI:

1. Install Docker Desktop and ensure the daemon is running.
2. Install Supabase CLI: `npm install -g supabase`, `brew install supabase/tap/supabase`, or similar.
3. In repo root:
   ```bash
   supabase init
   supabase link --project-ref wvmvsodrvbkxfydabqed
   supabase functions pull
   ```
4. For local stack: `supabase start` (Docker spins up Postgres/auth/edge runtime).
5. Serve individual functions locally: `supabase functions serve run-plan` (or other function name).

> **Note:** `.supabase/` and `.env` files must stay out of version control.

### 3.2 Dev Cloud Credentials

Create `.env.test_supabase` in repo root (ignored by git) with:

```
SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
SUPABASE_ANON_KEY=<anon key from Supabase dashboard>
```

Load it when running tests: `flutter test --dart-define-from-file=.env.test_supabase`.

### 3.3 Drift Schema Snapshots

We maintain historical schemas under `drift_schemas/` (e.g., `drift_schemas/v1/schema.sql`). Use these snapshots to seed migration tests.

---

## 4. Test Utilities & Conventions

### 4.1 Riverpod 3 Testing

- Use `ProviderContainer.test()` for scoped containers (auto-disposed).
- Override dependencies via `container.overrideWith`, `overrideWithBuild`, `Future/StreamProvider.overrideWithValue`.
- In widget tests, call `tester.container()` to access the scope.
- Assert AsyncNotifier transitions (`AsyncLoading → AsyncData/Error`).
- Reference `docs/test/riverpod_3_testing.md` for detailed patterns.

### 4.2 Console Logging Utilities ✅ Phase 2 Complete

All tests must log inputs/results using `test/helpers/utils/console_logging.dart`. This provides colored, structured console output that makes debugging easy.

**Basic Example:**
```dart
test('Marathon nutrition plan generation', () {
  logTestHeading('Edge Function – Marathon Plan Generation');

  logTestInput({
    'distance_miles': 26.2,
    'pace_min_per_mile': 7.5,
    'gut_training': 'high',
  });

  final plan = await service.generatePlan(...);

  logTestResult('carbs_total_g', plan.totalCarbsG, expectedRange: '360-480');
  logAssertion('No dairy during run', passed: !hasDairy);
  logTestPass();
});
```

**Available Functions:**
- `logTestHeading(String)` - Test title with colored divider
- `logTestSetup(Map)` - Configuration details
- `logTestInput(Map)` - Input parameters
- `logTestResult(label, actual, {expected, expectedRange, unit})` - Single result
- `logTestResults(Map<String, ResultData>)` - Multiple results at once
- `logAssertion(String, {passed, reason})` - Validation checks
- `logTestPass([message])` / `logTestFail(reason)` - Final status
- `logSection(String)`, `logApiCall(...)`, `logDatabaseOp(...)`, `logAnalyticsEvent(...)`

### 4.3 Test Fixtures ✅ Phase 2 Complete

Canonical test data in `test/helpers/fixtures/` for consistency across all tests.

#### Users Table (`users.dart`)
```dart
import 'package:mealvana_endurance/test/helpers/fixtures/users.dart';

// Map-based user data for edge function testing
final beginner = UserFixtures.beginner; // 30yo, 140lbs, low gut training
final advanced = UserFixtures.advanced; // 35yo, 155lbs, high gut training

// Helper functions
final weightKg = UserHelpers.getWeightKg(beginner); // Convert lbs to kg
final age = UserHelpers.getAge(beginner); // Calculate age
```

Available: `beginner`, `intermediate`, `advanced`, `heavyAthlete`, `lightAthlete`, `ultraRunner`, `newUser`
Note: Map-based format for edge function testing. Full Drift entities in Phase 4.

#### Nutrition Plan Requests (`nutrition_plan_requests.dart`)
```dart
import 'package:mealvana_endurance/test/helpers/fixtures/nutrition_plan_requests.dart';

final marathonReq = NutritionPlanRequestFixtures.marathon;
final hotWeatherReq = NutritionPlanRequestFixtures.hotWeatherMarathon;
final expectedTargets = ExpectedMacroTargets.marathon; // {'carbs_total_g': '360-480', ...}
```

Available: `fiveK`, `tenK`, `halfMarathon`, `marathon`, `ultraMarathon`, `hotWeatherMarathon`, `coldWeatherMarathon`, `beginnerMarathon`, `shortPreRunWindow`, `heavyAthleteMarathon`, `fastPaceMarathon`

#### Food Preferences (`food_preferences.dart`)
```dart
import 'package:mealvana_endurance/test/helpers/fixtures/food_preferences.dart';

final standardPrefs = FoodPreferenceFixtures.standard;
final pickyEater = FoodPreferenceFixtures.picky;
final shouldInclude = ExpectedFoodSelections.standardPreRun; // ['Oatmeal', 'Banana', ...]
```

Available: `standard`, `picky`, `adventurous`, `wholeFood`, `gelOnly`, `dairyFree`, `glutenFree`, `vegan`, `empty`

#### Drift Migration Data (`drift_v1_seed.dart`)
```dart
import 'package:mealvana_endurance/test/helpers/fixtures/drift_v1_seed.dart';

final seedData = DriftV1SeedData.all; // Complete v1 database state
final isValid = DriftV2ExpectedData.validateUserProfilesMigrated(profiles);
```

### 4.4 Reusable Fakes ✅ Phase 2 Complete

Test doubles in `test/helpers/fakes/` for dependency injection:

```dart
// Analytics
final analytics = RecordingAnalyticsTracker();
// Check: analytics.events, analytics.lastIdentifiedUser

// Error reporting
final sentry = RecordingSentryReporter();
// Check: sentry.capturedExceptions, sentry.breadcrumbs

// Logging
final logger = RecordingAppLogger();
// Check: logger.records

// Supabase
final supabase = FakeSupabaseClient(); // From Phase 1
```

**Using in Tests:**
```dart
test('Plan generation tracks analytics', () {
  final analytics = RecordingAnalyticsTracker();
  final container = ProviderContainer.test(
    overrides: [analyticsTrackerProvider.overrideWithValue(analytics)],
  );

  await container.read(nutritionPlanServiceProvider).generatePlan(...);

  expect(analytics.events.first.name, 'plan_generated');
});
```

### 4.5 Tagging

- Tag Supabase edge integration tests with `@Tags(['edge'])` so they run only when requested.
- Optionally add `@Tags(['slow'])` for other heavy suites.

---

## 5. Running Tests

### 5.1 Fast Suites

- Run all standard tests: `flutter test` (auto-skips tagged `edge`).
- Per feature: `flutter test test/features/nutrition_plan/...`.
- Service/Notifier tests should complete quickly (<100 ms each).

### 5.2 Edge Function Suites

- Vitest (Node harness):
  ```bash
  cd test/local_edge_functions
  npm install
  npm test  # or npx vitest run
  ```
- Dart integration (dev cloud):
  ```bash
  flutter test --tags edge --dart-define-from-file=.env.test_supabase
  ```
- Optional local parity:
  ```bash
  supabase start
  flutter test --tags edge --dart-define SUPABASE_URL=http://localhost:54321 ...
  ```

### 5.3 Migration Tests

- After reconstructing v1 schema, run: `flutter test test/integration/drift/`.
- These tests spin up in-memory databases, apply migrations, and assert data integrity/performance.

---

## 6. Test Creation Workflow

1. **Identify scope** – feature/layer, risk category, dependencies.
2. **Set up container** – use `ProviderContainer.test()` with overrides; choose fakes/fixtures.
3. **Implement test** – follow naming conventions (`<Class> should <behavior>`), include console logs.
4. **Run targeted command** – execute smallest suite possible.
5. **Document** – update roadmap/README when you add new patterns or require new tooling.

Our default expectation: each new feature/bugfix comes with tests in the relevant layer. Use the `.claude/agents/test-engineer.md` instructions when delegating to the testing agent.

---

## 7. Edge Function Testing Strategy (Three-Tier Approach)

We implement a comprehensive three-tier testing strategy for edge functions, balancing speed, realism, and coverage:

### **Tier 1: Local Unit Tests (Vitest)**
- **Purpose**: Fast, deterministic testing of pure function logic
- **Location**: `test/local_edge_functions/tests/`
- **Dependencies**: JSON fixtures, no database
- **Execution**: `cd test/local_edge_functions && npm test`
- **Use for**: Formula validation, algorithm logic, edge cases

### **Tier 2: Local Integration Tests (Dart + Local Supabase)**
- **Purpose**: Realistic testing with isolated database
- **Location**: `test/integration/edge/local/`
- **Dependencies**: Local Supabase via Docker
- **Execution**: `supabase start && flutter test test/integration/edge/local/`
- **Use for**: Database interactions, full request/response cycles

### **Tier 3: Dev Cloud E2E Tests (Dart + Dev Supabase)**
- **Purpose**: Production validation with real network conditions
- **Location**: `test/integration/edge/cloud/`
- **Dependencies**: Dev Supabase project credentials
- **Execution**: `flutter test --tags edge,cloud --dart-define-from-file=.env.test_supabase`
- **Use for**: Cross-function integration, performance benchmarks

### **Test Data Management**
- **JSON Fixtures**: `test/helpers/fixtures/` for portable test data
- **Local Seed Data**: `supabase/seed.sql` with test products and users
- **Golden Dataset**: Known correct calculations for formula validation
- **LP Solver Logs**: Expected logs for AI fallback detection

### **Priority Order for Implementation**
1. **generate-macros**: Deterministic formulas, easiest to validate
2. **generate-ai-nutrition-plan**: Complex logic, critical path
3. **barcode-lookup**: Database-dependent, requires seed data
4. **save-food-preferences**: Simple CRUD operation

### **Validation Tolerances**
- **Exact Match**: MET values, calorie calculations (formulas)
- **±10g**: Carbohydrate targets
- **±5g**: Protein targets
- **±50mg**: Sodium targets
- **±100ml**: Fluid targets

---

## 8. CI Recommendations

We currently lack automation. The roadmap (Phase 6) adds a GitHub Actions workflow:

- Run `flutter test` (excluding tagged suites) on every pull request.
- Run edge tests on a schedule or via manual dispatch with `.env.test_supabase` secrets.
- Cache Flutter/Dart artifacts for speed.
- Surface test logs (console output) as build artifacts for debugging.

---

## 9. Reference Documents

- [`docs/test/roadmap.md`](./roadmap.md) – master plan for decoupling/testing milestones.
- [`docs/test/riverpod_3_testing.md`](./riverpod_3_testing.md) – detailed Riverpod testing patterns.
- [`.claude/agents/test-engineer.md`](../../.claude/agents/test-engineer.md) – agent instructions.
- Supabase CLI docs: <https://supabase.com/docs/guides/cli>.
- Docker Desktop: <https://docs.docker.com/desktop/>.

---

## 10. Maintenance Checklist

- Keep fixtures/fakes updated as features evolve.
- Snapshot new Drift schemas under `drift_schemas/` whenever migrations ship.
- Review console logging policy once test stability improves.
- Update this README when patterns shift (e.g., new providers, new edge functions, CI changes).

---

With this structure in place, the team and the `test-engineer` agent can confidently expand coverage while keeping the codebase fast, testable, and aligned with Mealvana’s risk-focused goals.
