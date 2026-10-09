/// Log In's empty Password field showed Sign Up's rule, "At least 8
/// characters" (testing-wave 67-004, develop-2026-10 ticket 82). Log In reads
/// its own key, `auth.login.password_hint`; Sign Up keeps the rule.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_login_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_signup_screen.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../../helpers/widget_test_harness.dart';
import '../../../helpers/test_content.dart';

class _IdleAuthController extends PostOnboardingAuthController {
  @override
  FutureOr<void> build() {}
}

final _content = loadDefaultContent();

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/screen',
    routes: [GoRoute(path: '/screen', builder: (_, __) => screen)],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        mockSharedPreferences(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        contentServiceProvider.overrideWith(testContentService),
        postOnboardingAuthControllerProvider.overrideWith(
          _IdleAuthController.new,
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp.router(routerConfig: router),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String? _hint(WidgetTester tester, String fieldKey) => tester
    .widget<TextField>(
      find.descendant(
        of: find.byKey(ValueKey(fieldKey)),
        matching: find.byType(TextField),
      ),
    )
    .decoration
    ?.hintText;

void main() {
  testWidgets('Log In: the empty Password field says "Enter your password"', (
    tester,
  ) async {
    expect(_content[ContentKeys.loginPasswordHint], 'Enter your password');

    await _pump(tester, const EmailLoginScreen());

    expect(_hint(tester, 'login.password_field'), 'Enter your password');
  });

  testWidgets('Sign Up still states the rule: "At least 8 characters"', (
    tester,
  ) async {
    await _pump(tester, const EmailSignupScreen());

    expect(
      _hint(tester, 'signup_email.password_field'),
      _content['auth.email_signup.password_hint'],
    );
    expect(
      _hint(tester, 'signup_email.password_field'),
      'At least 8 characters',
    );
  });
}
