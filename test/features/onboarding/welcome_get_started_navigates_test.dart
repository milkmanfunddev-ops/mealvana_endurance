/// The tap that the unit tests never exercised.
///
/// `OnboardingSessionController` is an auto-dispose `@riverpod` notifier, and
/// `_getStarted` reaches it with a bare `ref.read(...notifier)` — nothing
/// watches it. With no listener the provider is disposed while the async call
/// is still in flight, and the notifier's own `state =` assignment then throws
/// out of `ensureOnboardingSession()` — before the navigation line below it
/// ever runs. The button silently does nothing.
///
/// `onboarding_session_controller_test.dart` could not catch this: it holds
/// the provider alive through a `ProviderContainer` for the whole call, which
/// is exactly the condition the screen does not provide. Reported from device
/// 2026-09-21: Welcome renders, "I already have an account" (synchronous)
/// works, "Build My Plan" (async) does nothing, across app restarts.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  testWidgets('tapping Build My Plan navigates into onboarding', (tester) async {
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (_, __) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/onboarding',
          builder: (_, __) =>
              const Scaffold(body: Text('ONBOARDING REACHED')),
        ),
        GoRoute(
          path: '/privacy-consent',
          builder: (_, __) => const Scaffold(body: Text('CONSENT REACHED')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Build My Plan'), findsOneWidget);

    await tester.tap(find.text('Build My Plan'));
    await tester.pumpAndSettle();

    // Either destination is acceptable — the regional consent gate decides.
    // What must never happen is staying on Welcome with the tap swallowed.
    final reached = find.text('ONBOARDING REACHED').evaluate().isNotEmpty ||
        find.text('CONSENT REACHED').evaluate().isNotEmpty;
    expect(
      reached,
      isTrue,
      reason: 'Build My Plan did not navigate — the tap was swallowed',
    );
  });
}
