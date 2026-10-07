/// After Log In, the Log In screen stays busy until something replaces it
/// (Finding 12-003: the form came back enabled for about a second before the
/// tabs shell, and could be tapped again).
///
/// The controller's state leaves loading as soon as the sign-in lands, but
/// the screen still has work before it navigates (the controller's own
/// trailing analytics call, then the pop or the app-gate settle). The screen
/// must not read "done" from the controller's state alone.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_login_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../../helpers/widget_test_harness.dart';

/// Signs in the way the real controller does: loading, then data once the
/// session lands, then a trailing await before it returns.
class _SlowTailAuthController extends PostOnboardingAuthController {
  static Completer<void> tail = Completer<void>();
  static bool result = true;
  static int calls = 0;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    calls++;
    state = const AsyncLoading();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    state = result
        ? const AsyncData(null)
        : AsyncError(Exception('bad password'), StackTrace.empty);
    await tail.future;
    return result;
  }
}

KylePrimaryButton _logInButton(WidgetTester tester) =>
    tester.widget(find.byKey(const ValueKey('login.log_in_button')));

Future<void> _pumpLoginOverBase(WidgetTester tester) async {
  // Made here, inside the test's fake-async zone: a completer made in setUp
  // resumes its awaiters only after the test body has finished.
  _SlowTailAuthController.tail = Completer<void>();
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.push('/login'),
            child: const Text('BASE'),
          ),
        ),
      ),
      GoRoute(path: '/login', builder: (_, __) => const EmailLoginScreen()),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mockAppExternalDeps(),
        mockSharedPreferences(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        postOnboardingAuthControllerProvider.overrideWith(
          _SlowTailAuthController.new,
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
  await tester.tap(find.text('BASE'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const ValueKey('login.email_field')),
    'a@b.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('login.password_field')),
    'password123',
  );
}

void main() {
  setUp(() {
    _SlowTailAuthController.result = true;
    _SlowTailAuthController.calls = 0;
  });

  testWidgets('Log In stays disabled from the tap until the screen is left', (
    tester,
  ) async {
    await _pumpLoginOverBase(tester);

    await tester.tap(find.byKey(const ValueKey('login.log_in_button')));
    await tester.pump();
    expect(_logInButton(tester).onPressed, isNull, reason: 'while loading');

    // The session has landed and the controller reads done, but the screen
    // has not navigated yet.
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      _logInButton(tester).onPressed,
      isNull,
      reason: 'after the controller settles, before navigation',
    );
    await tester.tap(
      find.byKey(const ValueKey('login.log_in_button')),
      warnIfMissed: false,
    );
    expect(_SlowTailAuthController.calls, 1);

    _SlowTailAuthController.tail.complete();
    // The spinner and the error snackbar animate, so pump fixed frames.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(EmailLoginScreen), findsNothing);
    expect(find.text('BASE'), findsOneWidget);
  });

  testWidgets('a failed Log In gives the button back', (tester) async {
    _SlowTailAuthController.result = false;
    await _pumpLoginOverBase(tester);

    await tester.tap(find.byKey(const ValueKey('login.log_in_button')));
    await tester.pump(const Duration(milliseconds: 50));
    _SlowTailAuthController.tail.complete();
    // The spinner and the error snackbar animate, so pump fixed frames.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(EmailLoginScreen), findsOneWidget);
    expect(_logInButton(tester).onPressed, isNotNull);
  });
}
