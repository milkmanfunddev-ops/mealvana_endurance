import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Main integration test file for Mealvana Endurance app
///
/// This file serves as the entry point for all integration tests.
/// Individual test suites should be imported and organized below.
///
/// Integration tests verify complete user flows and interactions
/// between multiple features, using the real app with mocked
/// external dependencies (Supabase, Analytics, Sentry).
///
/// Test Organization:
/// - flows/: Complete user journeys (onboarding → plan generation)
/// - e2e/: End-to-end scenarios crossing multiple features
///
/// Running Tests:
/// - All integration tests: flutter test integration_test
/// - Specific test file: flutter test integration_test/flows/onboarding_flow_test.dart
///
/// Test Environment:
/// - Uses in-memory Drift database for fast, isolated tests
/// - Mocks Supabase client to avoid network dependencies
/// - Records analytics/sentry/logging calls for verification
/// - Real Flutter widgets and routing for authentic user flow

void main() {
  // Initialize integration test binding
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Mealvana Endurance Integration Tests', () {
    // Import and run test suites here as they are created
    // Example:
    // import 'flows/onboarding_flow_test.dart' as onboarding_flow;
    // onboarding_flow.main();

    test('Integration test infrastructure is set up', () {
      expect(true, true);
    });
  });
}
