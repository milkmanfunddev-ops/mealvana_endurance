// Driver entry point for `flutter drive`-based WEB e2e tests.
//
// This is intentionally separate from the Patrol mobile suite under
// integration_test/ (which is wired to patrol_cli via `test_directory:
// integration_test` in pubspec.yaml). Flutter web renders to a <canvas>, so
// DOM tools (Playwright/Selenium) cannot see widgets — `flutter drive` +
// integration_test is the supported way to drive the real app in a real
// browser, because the test runs against the widget tree.
//
// Run via scripts/run_web_e2e.sh (which starts chromedriver first).
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
