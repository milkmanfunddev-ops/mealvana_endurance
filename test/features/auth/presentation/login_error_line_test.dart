/// Log In errors sit under the form (testing-wave 125-002, 125-007): one line
/// that says wrong email or password, no connection, or that it failed, and
/// stays until the next edit. Never a 2-second snackbar.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_login_screen.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../../helpers/widget_test_harness.dart';
import '../../meal_planning/presentation/helpers/test_content.dart';

/// Fails every Log In with [failure], as the real controller does: the typed
/// exception lands in its error state.
class _FailingAuthController extends PostOnboardingAuthController {
  static Object failure = const WrongCredentialsException();

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = AsyncError(failure, StackTrace.empty);
    return false;
  }
}

final _content = loadDefaultContent();
final _line = find.byKey(const ValueKey('login.error_line'));

Future<void> _pumpLogin(WidgetTester tester, Object failure) async {
  _FailingAuthController.failure = failure;
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const EmailLoginScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        mockSharedPreferences(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        contentServiceProvider.overrideWith(testContentService),
        postOnboardingAuthControllerProvider.overrideWith(
          _FailingAuthController.new,
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
  await tester.enterText(
    find.byKey(const ValueKey('login.email_field')),
    'a@b.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('login.password_field')),
    'password123',
  );
  await tester.tap(find.byKey(const ValueKey('login.log_in_button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets('a wrong password: one line under the form, no snackbar, and '
      'it stays until the next edit', (tester) async {
    await _pumpLogin(tester, const WrongCredentialsException());

    expect(_line, findsOneWidget);
    expect(
      tester.widget<Text>(_line).data,
      _content['auth.login.error_wrong_credentials'],
    );
    expect(find.byType(SnackBar), findsNothing);

    // Time alone does not take it.
    await tester.pump(const Duration(seconds: 5));
    expect(_line, findsOneWidget);

    // An edit does.
    await tester.enterText(
      find.byKey(const ValueKey('login.password_field')),
      'password1234',
    );
    await tester.pump();
    expect(_line, findsNothing);
  });

  testWidgets('no connection says so', (tester) async {
    await _pumpLogin(tester, const NoConnectionException('socket'));

    expect(
      tester.widget<Text>(_line).data,
      _content['auth.login.error_no_connection'],
    );
  });

  testWidgets('anything else is the general line', (tester) async {
    await _pumpLogin(tester, const SignInFailedException('500'));

    expect(
      tester.widget<Text>(_line).data,
      _content['auth.login.error_failed'],
    );
  });

  testWidgets('the address Verify your email offered is filled in', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const EmailLoginScreen(initialEmail: 'b@example.com'),
      overrides: [
        postOnboardingAuthControllerProvider.overrideWith(
          _FailingAuthController.new,
        ),
      ],
    );
    expect(
      tester
          .widget<TextFormField>(
            find.byKey(const ValueKey('login.email_field')),
          )
          .controller!
          .text,
      'b@example.com',
    );
  });
}
