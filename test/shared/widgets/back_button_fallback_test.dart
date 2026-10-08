// Patch #4 regression (2026-10-04): a visible back control must never do
// NOTHING. When the navigation stack has nothing beneath the current route
// (a stackless deep-link arrival — witnessed on the nudge-tap create page
// 2026-10-01 and again 2026-10-03), CustomAppBarBackButton falls back to
// go('/') instead of silently ignoring the tap.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/app_startup/application/app_startup_provider.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/privacy/analytics_consent.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region.dart';
import 'package:mealvana_endurance/shared/widgets/custom_app_bar_back_button.dart';

import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

class _MockSession extends Mock implements Session {}

/// Startup's live snapshot after an in-session login (ticket 56): the
/// athlete is signed in and onboarded.
class _LiveStartup extends AppStartup {
  @override
  Future<AppStartupData> build() async {
    final now = DateTime(2026, 10, 8);
    return AppStartupData(
      user: UserProfile(
        id: 'athlete-56',
        deviceId: 'device-56',
        authUserId: 'athlete-56',
        authProvider: 'email',
        isAnonymous: false,
        gender: Gender.female,
        birthday: DateTime(1990, 1, 1),
        heightFeet: 5,
        heightInches: 6,
        weightPounds: 140,
        runsWithWaterBottle: true,
        createdAt: now,
        updatedAt: now,
        onboardingCompleted: true,
        appVersion: '1.30.0',
      ),
      hasCompletedOnboarding: true,
    );
  }
}

class _ConsentDecided extends AnalyticsConsentNotifier {
  @override
  AnalyticsConsent build() => const AnalyticsConsent(
    status: ConsentStatus.granted,
    regime: ConsentRegime.standard,
    source: RegionSource.geo,
  );
}

GoRouter _router(String initial) => GoRouter(
  initialLocation: initial,
  routes: [
    GoRoute(
      path: '/',
      builder: (c, s) => const Scaffold(body: Text('HOME')),
    ),
    GoRoute(
      path: '/dead-end',
      builder: (c, s) => const Scaffold(
        appBar: null,
        body: Column(children: [CustomAppBarBackButton(), Text('DEAD END')]),
      ),
    ),
  ],
);

void main() {
  testWidgets('stackless arrival: back goes home instead of doing nothing', (
    tester,
  ) async {
    final router = _router('/dead-end');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('DEAD END'), findsOneWidget);

    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget, reason: 'fallback must go home');
  });

  // 49-001: Connected Apps opened by a deep link, Back took the fallback's
  // go('/'), and the launch-time snapshot sent the athlete to Welcome. With
  // the live snapshot the real root redirect answers /main.
  testWidgets('stackless arrival on the real router, signed in and onboarded: '
      'back lands on /main', (tester) async {
    final auth = MockGoTrueClient();
    when(() => auth.currentSession).thenReturn(_MockSession());
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());

    final container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: fakeSupabaseClient(auth: auth)),
        mockSharedPreferences(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        contentServiceProvider.overrideWith(testContentService),
        appStartupProvider.overrideWith(_LiveStartup.new),
        analyticsConsentProvider.overrideWith(_ConsentDecided.new),
      ],
    );
    addTearDown(container.dispose);
    final held = container.listen(appStartupProvider, (_, __) {});
    addTearDown(held.close);
    await container.read(appStartupProvider.future);

    final router = container.read(AppRouter.routerProvider);
    addTearDown(router.dispose);
    // Stackless: go replaces the stack, nothing beneath to pop.
    router.go('/help');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    expect(router.routerDelegate.currentConfiguration.uri.path, '/help');

    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/main');
    // The button's double-tap guard holds a 500 ms timer; release it inside
    // the body (#110), with /main's screen gone so its providers start none.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 500));
  });

  testWidgets('normal stack: back still pops (no behavior change)', (
    tester,
  ) async {
    final router = _router('/');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/dead-end');
    await tester.pumpAndSettle();
    expect(find.text('DEAD END'), findsOneWidget);

    await tester.tap(find.byType(CustomAppBarBackButton));
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsOneWidget, reason: 'pop must still work');
  });
}
