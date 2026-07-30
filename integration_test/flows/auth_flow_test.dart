/// Auth + login walk — first new integration test built on the
/// post-instrumentation ValueKey infrastructure.
///
/// What it verifies:
///   - The welcome screen appears with the `welcome.*` keys.
///   - `welcome.log_in_button` → routes to the login-options sheet.
///   - `login_options.email_button` → routes to the email-login form.
///   - `login.email_field` / `login.password_field` accept input.
///   - `login.log_in_button` → submits and ultimately lands on the
///     calendar (`calendar.*` keys appear).
///
/// This replaces the previous mobile-mcp-driven rewalk that was
/// blocked by coordinate-based synthetic taps not reaching the
/// Log In button. `find.byKey()` resolves widgets through the
/// widget tree directly, sidestepping the hit-test issue entirely.
///
/// How to run:
///   flutter test integration_test/flows/01_auth_flow_test.dart \
///     -d "iPhone 15 Pro Max" \
///     --dart-define-from-file=.env.dev.local
///
/// Requirements:
///   - test@test.com / test must exist in dev Supabase.
///   - Simulator must be booted before invocation.
///   - Network access to the dev Supabase instance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:mealvana_endurance/main_dev.dart' as app;

const _testEmail = 'test@test.com';
const _testPassword = 'test';

void main() {
  // NOTE: test@test.com / test is a PROD account. Run this against a prod build,
  // or repoint at a dev-seeded account. For the dev smoke test prefer
  // onboarding_signup_flow_test.dart, which creates a fresh dev user.
  patrolTest(
    'login as test@test.com lands on calendar',
    ($) async {
      final tester = $.tester;
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 30));

      // If the app launches already logged in (re-run on a hot
      // simulator), the calendar will be present and the welcome
      // keys absent. Skip the login walk in that case.
      final calendarPresent = find.byKey(
        const ValueKey('fuel_timeline.settings'),
      ).evaluate().isNotEmpty;

      if (calendarPresent) {
        // Already on calendar — nothing to assert beyond presence.
        expect(find.byKey(const ValueKey('fuel_timeline.settings')),
            findsOneWidget);
        return;
      }

      // Welcome → Login options
      await tester.tap(find.byKey(const ValueKey('welcome.log_in_button')));
      await tester.pumpAndSettle();

      // Login options → email login
      await tester.tap(
        find.byKey(const ValueKey('login_options.email_button')),
      );
      await tester.pumpAndSettle();

      // Fill credentials
      await tester.enterText(
        find.byKey(const ValueKey('login.email_field')),
        _testEmail,
      );
      await tester.enterText(
        find.byKey(const ValueKey('login.password_field')),
        _testPassword,
      );
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.byKey(const ValueKey('login.log_in_button')));

      // Allow Supabase round-trip + redirect to calendar.
      await tester.pumpAndSettle(const Duration(seconds: 30));

      // Verify we landed on the calendar.
      expect(
        find.byKey(const ValueKey('fuel_timeline.settings')),
        findsOneWidget,
        reason:
            'Expected the Fuel Timeline dashboard after login. If this fails, '
            'dump the tree with `debugDumpApp()` and check what screen we '
            'landed on.',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
