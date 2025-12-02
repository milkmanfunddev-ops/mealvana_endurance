# Integration Tests

Real device/simulator integration tests for Mealvana Endurance using Flutter's `integration_test` package.

## Quick Start

```bash
# Run all tests (auto-detects simulator)
./integration_test/run_tests.sh

# Run specific test
./integration_test/run_tests.sh nutrition
./integration_test/run_tests.sh event
./integration_test/run_tests.sh settings
./integration_test/run_tests.sh food
```

## Test Runner Script

The `run_tests.sh` script automatically detects your iOS simulator, so you don't need to specify `-d "iPhone 15"` each time.

```bash
# Make executable (first time only)
chmod +x integration_test/run_tests.sh

# Run all tests
./integration_test/run_tests.sh

# Run individual tests
./integration_test/run_tests.sh nutrition    # Nutrition Plan Flow
./integration_test/run_tests.sh event        # Event Management Flow
./integration_test/run_tests.sh settings     # Settings Flow
./integration_test/run_tests.sh food         # Food Management Flow
./integration_test/run_tests.sh onboarding   # Onboarding & Auth Flow
./integration_test/run_tests.sh login        # Email Login Flow
```

## Manual Flutter Commands

If you prefer using Flutter directly:

```bash
# Run all tests
flutter test integration_test/test_runner.dart -d "iphone 15 pro max"

# Run individual tests
flutter test integration_test/flows/nutrition_plan_flow_test.dart -d "iphone 15 pro max"
flutter test integration_test/flows/event_management_flow_test.dart -d "iphone 15 pro max"
flutter test integration_test/flows/settings_flow_test.dart -d "iphone 15 pro max"
flutter test integration_test/flows/food_management_flow_test.dart -d "iphone 15 pro max"

# With verbose output
flutter test integration_test/test_runner.dart -d "iphone 15 pro max" --reporter expanded
```

## Test Coverage

| Flow | Description | File | Duration |
|------|-------------|------|----------|
| **Event Management** | Create, edit, delete events | `flows/event_management_flow_test.dart` | ~3-4 min |
| **Nutrition Plan** | Create activity, generate plan, swap/delete foods | `flows/nutrition_plan_flow_test.dart` | ~3-5 min |
| **Settings** | Profile, preferences, appearance | `flows/settings_flow_test.dart` | ~2-3 min |
| **Food Management** | Food preference sliders, search | `flows/food_management_flow_test.dart` | ~2-3 min |
| **Onboarding + Auth** | New user signup through email | `flows/onboarding_auth_flow_test.dart` | ~3-5 min |
| **Email Login** | Existing user login with test@test.com | `flows/email_login_flow_test.dart` | ~2-3 min |

**Full Suite Duration:** ~15-25 minutes

## Directory Structure

```
integration_test/
├── run_tests.sh               # Shell script runner (auto-detects device)
├── test_runner.dart           # Main entry point for all tests
├── README.md                  # This file
├── helpers/
│   ├── test_config.dart       # Test configuration and credentials
│   └── test_helpers.dart      # WidgetTester extensions and utilities
└── flows/                     # User flow integration tests
    ├── event_management_flow_test.dart
    ├── nutrition_plan_flow_test.dart
    ├── settings_flow_test.dart
    ├── food_management_flow_test.dart
    ├── onboarding_auth_flow_test.dart
    └── email_login_flow_test.dart
```

## App Screen Flow

The tests follow the actual app screens:

1. **Welcome Screen** → "Get Started" / "Log In"
2. **Your Profile** → Gender, Birthday, Height, Weight
3. **Sport Preferences** → Running/Cycling/Swimming, Gut Sensitivity, "Continue"
4. **Food Preferences** → Sliders (Avoid ↔ Love), "Save Changes"
5. **Create Account** → Apple/Google/Email, "Continue without signing in"
6. **Calendar (Main)** → BY WEEK/BY MONTH, "CREATE AN EVENT", FAB
7. **New Event** → Sport Category, Race Distance, Event Name, Location, Date
8. **Event Details** → "Create Nutrition Plan", "Create Carb Loading Plan"
9. **Create New Activity Plan** → Distance, Pace, Gut Training, "Generate Plan"
10. **Adjust Your Macros** → PRE/DURING/POST table, "Create Plan"
11. **Nutrition Plan** → "BEFORE RUN" section, food items, "+ ADD FOOD"
12. **Settings** → Profile & Preferences, Appearance, Food Preferences

## Prerequisites

1. **iOS Simulator**: Tests run on iOS simulator
   ```bash
   # List available simulators
   flutter devices

   # Boot simulator if needed
   open -a Simulator
   ```

2. **Dev Environment**: Tests run against dev Supabase instance
   - Ensure `.env.dev.local` exists with proper credentials

3. **Test Account**: `test@test.com` / `test` must exist for login tests

## Test Configuration

Edit `helpers/test_config.dart` to customize:

```dart
class TestConfig {
  // Test account credentials
  static const testEmail = 'test@test.com';
  static const testPassword = 'test';

  // Timeouts
  static const Duration shortTimeout = Duration(seconds: 10);
  static const Duration mediumTimeout = Duration(seconds: 30);
  static const Duration longTimeout = Duration(minutes: 2);

  // Test data
  static const testUserProfile = TestUserProfile(...);
  static const testActivity = TestActivityData(...);
  static const testEvent = TestEventData(...);
}
```

## Test Helpers

The `test_helpers.dart` provides extensions on `WidgetTester`:

```dart
// Wait and settle
await tester.settle();
await tester.wait(Duration(seconds: 2));

// Tap by various selectors
await tester.tapByKey('my_button');
await tester.tapByText('Submit');
await tester.tapByIcon(Icons.add);

// Enter text
await tester.enterTextByHint('Email', 'test@test.com');
await tester.enterTextByKey('password_field', 'password');

// Wait for widgets
await tester.waitForWidget(find.text('Welcome'));

// Scroll until visible
await tester.scrollToFind(find.text('Settings'));

// Screenshots (for debugging)
await tester.screenshot('after_login');
```

## Test Logging

Tests use `TestLogger` for structured output:

```dart
TestLogger.logStep('Starting Login');       // Major step header
TestLogger.logSubStep('Entering email...'); // Sub-step
TestLogger.logSuccess('Login successful');  // Success message
TestLogger.logError('Login failed');        // Error message
TestLogger.logInfo('Skipping optional step'); // Info message
```

## Troubleshooting

### No Simulator Found
```bash
# List available simulators
flutter emulators

# Launch a simulator
flutter emulators --launch apple_ios_simulator

# Or open Simulator app
open -a Simulator
```

### Test Timeout
- Increase timeout in test: `timeout: const Timeout(Duration(minutes: 5))`
- Check network connectivity to dev Supabase
- Verify simulator is running properly

### Widget Not Found
- Add `await tester.pumpAndSettle()` before finding widget
- Use `await tester.waitForWidget()` for async-loaded content
- Check if widget is scrolled off-screen

### Authentication Errors
- Verify test account exists in dev Supabase
- Check `.env.dev.local` has correct credentials
- Ensure anonymous auth is enabled in Supabase

## References

- [Flutter Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [integration_test package](https://pub.dev/packages/integration_test)
