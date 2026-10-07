// Ticket 141 (Findings 118-005, 119-005, 124-005): Sign Up with Email's two
// eye buttons are named "Show password" as Log In's is, and the Log In
// chooser's back arrow is a button named "Back" (it was missing from the
// accessibility tree altogether).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_signup_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/post_onboarding_auth_screen.dart';

import '../../helpers/widget_test_harness.dart';

class _FakePostOnboardingAuthController extends PostOnboardingAuthController {
  @override
  FutureOr<void> build() {}
}

void main() {
  testWidgets('Sign Up with Email: both eye buttons are named Show password, '
      'then Hide password', (tester) async {
    final handle = tester.ensureSemantics();
    await smokeScreen(
      tester,
      const EmailSignupScreen(),
      overrides: [
        postOnboardingAuthControllerProvider.overrideWith(
          _FakePostOnboardingAuthController.new,
        ),
      ],
    );

    const eyes = [
      ValueKey('signup_email.password_visibility_button'),
      ValueKey('signup_email.confirm_password_visibility_button'),
    ];
    for (final key in eyes) {
      expect(
        tester.getSemantics(find.byKey(key)),
        // An IconButton is named by its tooltip.
        isSemantics(
          tooltip: 'Show password',
          isButton: true,
          hasTapAction: true,
        ),
        reason: '$key',
      );
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(find.byKey(key)),
        isSemantics(tooltip: 'Hide password', isButton: true),
        reason: '$key after a tap',
      );
    }
    handle.dispose();
  });

  testWidgets('Log In chooser: the back arrow is a button named Back', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await smokeScreen(tester, const PostOnboardingAuthScreen(mode: 'login'));

    expect(
      tester.getSemantics(
        find.byKey(const ValueKey('login_options.back_button')),
      ),
      isSemantics(label: 'Back', isButton: true, hasTapAction: true),
    );
    handle.dispose();
  });
}
