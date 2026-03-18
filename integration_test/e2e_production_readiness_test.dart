import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mealvana_endurance/main_prod.dart' as app;

/// E2E Production Readiness Test
///
/// Comprehensive end-to-end test covering the complete user journey:
/// 1. Welcome Screen → Get Started / Log In
/// 2. Onboarding flow (sport preferences, biometrics, etc.)
/// 3. Signup flow (create account)
/// 4. Login flow (existing account)
/// 5. Event creation
/// 6. Activity plan creation
///
/// This test runs against a REAL Supabase backend (dev or prod depending
/// on which main entry point is imported). Nothing is mocked.
///
/// Run with: patrol test --target integration_test/e2e_production_readiness_test.dart

void main() {
  // ============================================================
  // PATH 1: Full signup flow (onboarding → signup → app)
  // ============================================================
  patrolTest(
    'Complete signup flow: onboarding → signup → create event → create plan',
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    ($) async {
      // Launch the app
      await app.main();
      await $.pumpAndSettle();

      // ──────────────────────────────────────────────
      // STEP 0: Detect auth state
      // ──────────────────────────────────────────────
      // The app either shows:
      //   - Welcome Screen (/welcome) → user is logged out
      //   - Main TabsScreen (/main) → user is logged in
      // We need to be on the Welcome Screen for this path.
      // If logged in, we'll navigate to settings and sign out first.

      final isOnWelcomeScreen = $.tester
          .any(find.text('Get Started'));

      if (!isOnWelcomeScreen) {
        // User is logged in - need to sign out first
        // TODO: Navigate to Settings → Sign Out (user will provide steps)
      }

      // ──────────────────────────────────────────────
      // SCREEN 1: Welcome Screen
      // ──────────────────────────────────────────────
      // Verify welcome screen elements are visible
      expect($('Mealvana'), findsOneWidget);
      expect($('Endurance'), findsOneWidget);
      expect($('Get Started'), findsOneWidget);
      expect($('Log In'), findsOneWidget);

      // Tap "Get Started" to begin onboarding
      await $('Get Started').tap();

      // ──────────────────────────────────────────────
      // SCREEN 2: Onboarding (next screen after Get Started)
      // ──────────────────────────────────────────────
      // TODO: Will be filled in after screenshot review
    },
  );

  // ============================================================
  // PATH 2: Login flow (welcome → login → app)
  // ============================================================
  patrolTest(
    'Login flow: welcome → login → create event → create plan',
    framePolicy: LiveTestWidgetsFlutterBindingFramePolicy.fullyLive,
    ($) async {
      // Launch the app
      await app.main();
      await $.pumpAndSettle();

      // ──────────────────────────────────────────────
      // STEP 0: Detect auth state (same as Path 1)
      // ──────────────────────────────────────────────
      final isOnWelcomeScreen = $.tester
          .any(find.text('Get Started'));

      if (!isOnWelcomeScreen) {
        // User is logged in - need to sign out first
        // TODO: Navigate to Settings → Sign Out (user will provide steps)
      }

      // ──────────────────────────────────────────────
      // SCREEN 1: Welcome Screen
      // ──────────────────────────────────────────────
      expect($('Mealvana'), findsOneWidget);
      expect($('Endurance'), findsOneWidget);
      expect($('Get Started'), findsOneWidget);
      expect($('Log In'), findsOneWidget);

      // Tap "Log In" to go to auth screen
      await $('Log In').tap();

      // ──────────────────────────────────────────────
      // SCREEN 2: Login Screen
      // ──────────────────────────────────────────────
      // TODO: Will be filled in after screenshot review
    },
  );
}
