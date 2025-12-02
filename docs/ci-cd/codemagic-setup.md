# Codemagic CI/CD Setup

This document explains how to set up and use Codemagic for continuous integration and deployment of Mealvana Endurance.

## Overview

The `codemagic.yaml` configuration includes the following workflows:

| Workflow | Purpose | Trigger | Duration |
|----------|---------|---------|----------|
| **integration-tests** | Full integration test suite on iOS simulator | PR to develop/feature/release | ~30-45 min |
| **integration-test-quick** | Single integration test for fast feedback | Manual | ~15-20 min |
| **pr-validation** | Unit tests, analyze, format check | Every PR | ~5-10 min |
| **ios-shorebird-release** | iOS build with Shorebird → TestFlight | Push to main/release | ~30-45 min |
| **ios-shorebird-patch** | iOS OTA update (no App Store) | Manual | ~15-20 min |
| **android-shorebird-release** | Android build with Shorebird → Play Store | Push to main/release | ~30-45 min |
| **android-shorebird-patch** | Android OTA update (no Play Store) | Manual | ~15-20 min |
| **ios-build-legacy** | Standard iOS build (no Shorebird) | Manual | ~30-45 min |
| **android-build-legacy** | Standard Android build (no Shorebird) | Manual | ~30-45 min |

## Shorebird Integration

Shorebird enables over-the-air (OTA) code updates without App Store review.

**When to use Release vs Patch:**

| Scenario | Workflow | Goes to Store? |
|----------|----------|----------------|
| New version (1.0 → 1.1) | `*-shorebird-release` | Yes |
| Bug fix (same version) | `*-shorebird-patch` | No |
| UI text changes | `*-shorebird-patch` | No |
| Algorithm tweaks | `*-shorebird-patch` | No |
| Native code changes | `*-shorebird-release` | Yes |
| New permissions | `*-shorebird-release` | Yes |

See [Shorebird Integration Guide](./shorebird-integration.md) for detailed setup.

## Setup Instructions

### 1. Connect Repository to Codemagic

1. Go to [codemagic.io](https://codemagic.io) and sign in
2. Click "Add application"
3. Select your Git provider and authorize access
4. Select the `mealvana_endurance` repository
5. Choose "Flutter App" as the project type
6. Select "codemagic.yaml" configuration

### 2. Configure Environment Variable Groups

In Codemagic dashboard → Team Settings → Global Variables and Secrets, create these groups:

#### `supabase_dev` Group
```
SUPABASE_URL=https://your-dev-project.supabase.co
SUPABASE_ANON_KEY=your-dev-anon-key
```

#### `supabase_prod` Group
```
SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
SUPABASE_ANON_KEY=eyJhbGci... (JWT token)
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci... (JWT token)
```

#### `shorebird_credentials` Group (REQUIRED for Shorebird builds)
```
SHOREBIRD_TOKEN=<token from shorebird login:ci>
```

**How to generate:**
```bash
shorebird login:ci
# Copy the output token
```

#### `app_store_credentials` Group (for iOS builds)

This is configured via Codemagic integrations, not environment variables:

1. Go to Team Settings → Integrations → Developer Portal
2. Add App Store Connect API key
3. Name it: **Mealvana** (must match `codemagic.yaml`)
4. Required role: **App Manager** (not Developer)

#### `google_play_credentials` Group (for Android builds)
```
GCLOUD_SERVICE_ACCOUNT_CREDENTIALS={"type": "service_account", ...}
```

### 3. Configure Code Signing (iOS)

1. Go to your app settings in Codemagic
2. Navigate to "Code signing identities"
3. Upload your:
   - Distribution certificate (.p12)
   - Provisioning profile (.mobileprovision)
4. Or use automatic code signing with App Store Connect API

### 4. Configure Slack Notifications (Optional)

1. Create a Slack webhook URL
2. Add to Codemagic: Settings → Integrations → Slack
3. The workflows will post to `#builds` channel

## Running Workflows

### Automatic Triggers

- **PR Validation**: Runs automatically on every pull request
- **Integration Tests**: Runs on PRs to `develop`, `feature/*`, `release/*`
- **iOS/Android Builds**: Runs on push to `main` or `release/*`

### Manual Triggers

1. Go to your app in Codemagic dashboard
2. Click "Start new build"
3. Select the workflow:
   - `integration-tests` - Full test suite
   - `integration-test-quick` - Single test (configurable)
   - `ios-build` - iOS release build
   - `android-build` - Android release build
4. Optionally set environment variables:
   - `TEST_FLOW=nutrition_plan_flow_test.dart` for quick test

## Integration Test Configuration

### Running All Tests

The `integration-tests` workflow runs all test flows:

```yaml
flutter test integration_test/test_runner.dart -d "$TEST_DEVICE"
```

### Running a Single Test

Use the `integration-test-quick` workflow with `TEST_FLOW` variable:

```bash
# Available test flows:
TEST_FLOW=event_management_flow_test.dart
TEST_FLOW=nutrition_plan_flow_test.dart
TEST_FLOW=settings_flow_test.dart
TEST_FLOW=food_management_flow_test.dart
TEST_FLOW=onboarding_auth_flow_test.dart
TEST_FLOW=email_login_flow_test.dart
```

### Test Reports

Test results are captured in machine-readable format and displayed in the Codemagic UI:

- Unit tests: `test-results/unit-tests.json`
- Integration tests: `test-results/integration-tests.json`
- Logs: `test-results/*.log`

## Workflow Details

### Integration Tests Workflow

```yaml
integration-tests:
  scripts:
    1. Get Flutter dependencies (flutter pub get)
    2. Run code generation (build_runner)
    3. Run unit tests
    4. Boot iOS Simulator (iPhone 15 Pro)
    5. Run integration tests
    6. Shutdown simulator
```

The iOS simulator is created dynamically using `simctl`:

```bash
# Find latest iOS runtime
RUNTIME=$(xcrun simctl list runtimes | grep iOS | tail -1)

# Create iPhone 15 Pro simulator
TEST_DEVICE=$(xcrun simctl create "Test iPhone" "iPhone 15 Pro" "$RUNTIME")

# Boot and run tests
xcrun simctl boot "$TEST_DEVICE"
flutter test integration_test/test_runner.dart -d "$TEST_DEVICE"
```

### PR Validation Workflow

Fast feedback on every PR:

1. `flutter analyze` - Static analysis
2. `dart format --set-exit-if-changed` - Code formatting
3. `flutter test` - Unit tests

Fails fast if any check fails.

## Troubleshooting

### Simulator Boot Fails

If the iOS simulator fails to boot:

```yaml
# Add more wait time
xcrun simctl boot "$TEST_DEVICE"
sleep 30  # Increase from 10
```

### Tests Timeout

Increase the max build duration:

```yaml
max_build_duration: 90  # minutes
```

Or increase individual test timeouts in the test files:

```dart
timeout: const Timeout(Duration(minutes: 10)),
```

### Code Signing Issues

1. Verify certificates are not expired
2. Check provisioning profile matches bundle ID
3. Use automatic signing with App Store Connect API

### Environment Variables Not Found

1. Verify the group name matches exactly
2. Check the variable is marked as "Secure" for secrets
3. Ensure the workflow has the group in its `environment.groups`

## Cost Optimization

- Use `mac_mini_m2` for faster builds
- Enable `cancel_previous_builds: true` to stop outdated PR builds
- Use `integration-test-quick` for fast feedback during development
- Full `integration-tests` only on PR merge or release branches

## References

- [Codemagic Documentation](https://docs.codemagic.io/)
- [Running Tests on Codemagic](https://docs.codemagic.io/yaml-testing/testing/)
- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Andrea Bizzotto's Codemagic Guide](https://codewithandrea.com/articles/integration-tests-codemagic/)
