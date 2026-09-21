// The welcome screen starts no session (mp-459 / mp-417).
//
// Before the paywall, "Get Started" signed out whatever session existed and
// opened a fresh anonymous one so the onboarding answers had a uid to land
// on. The account is now required: answers wait on the phone and are written
// once the athlete signs up, so the welcome screen touches auth not at all.
// This test drives the real screen with a spy GoTrue and pins that neither
// `signOut` nor `signInAnonymously` is ever called on the way into
// onboarding.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/onboarding/presentation/screens/welcome_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  late MockGoTrueClient goTrue;
  late GoRouter router;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    goTrue = fakeGoTrueClient() as MockGoTrueClient;
    // Unstubbed on purpose beyond the signed-out defaults: a call to either
    // would be the regression, and `verifyNever` below is the assertion.
    when(() => goTrue.signOut()).thenAnswer((_) async {});
    router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('ONBOARDING')),
        ),
        GoRoute(
          path: '/privacy-consent',
          builder: (_, __) => const Scaffold(body: Text('CONSENT')),
        ),
      ],
    );
  });

  testWidgets('Get Started opens onboarding without starting a session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(supabaseClient: fakeSupabaseClient(auth: goTrue)),
          mockSharedPreferences(),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('welcome.get_started_button')));
    await tester.pumpAndSettle();

    // Onboarding (or, in a strict region, the consent step that leads to it)
    // is reached. Read the rendered screen, not `currentConfiguration.uri`:
    // Get Started pushes, and go_router reports the base location for a
    // pushed route.
    final reached =
        find.text('ONBOARDING').evaluate().isNotEmpty ||
        find.text('CONSENT').evaluate().isNotEmpty;
    expect(reached, isTrue, reason: 'Get Started must open onboarding');

    // ...and auth was never touched: no session is torn down, none is started.
    verifyNever(() => goTrue.signOut());
    verifyNever(() => goTrue.signInAnonymously());
  });
}
