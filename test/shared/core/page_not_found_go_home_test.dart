// Page Not Found's Go Home goes through the root redirect, so home is wherever
// startup says it is (round develop-2026-10, ticket 46: Finding 32-002).
//
// It used to go to `/welcome`, a public route the redirect lets through, so a
// signed-in, onboarded athlete was dropped on Welcome. Runs through the real
// `AppRouter.routerProvider`; only the state the redirect reads is overridden.

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

import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

class _MockSession extends Mock implements Session {}

/// Startup finished, shaped like a real launch of an onboarded athlete.
class _FinishedStartup extends AppStartup {
  _FinishedStartup(this.data);
  final AppStartupData data;

  @override
  Future<AppStartupData> build() async => data;
}

/// A decision already on record: the consent screen is not owed.
class _ConsentDecided extends AnalyticsConsentNotifier {
  @override
  AnalyticsConsent build() => const AnalyticsConsent(
    status: ConsentStatus.granted,
    regime: ConsentRegime.standard,
    source: RegionSource.geo,
  );
}

UserProfile _athlete() {
  final now = DateTime(2026, 10, 8);
  return UserProfile(
    id: 'athlete-1',
    deviceId: 'device-1',
    authUserId: 'athlete-1',
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
  );
}

void main() {
  /// Pumps the real router on `/pro` (no such route) with startup data and
  /// a live Supabase session, so the non-root session check passes.
  Future<GoRouter> pumpOnUnknownRoute(
    WidgetTester tester, {
    required bool isLoggedOut,
  }) async {
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
        appStartupProvider.overrideWith(
          () => _FinishedStartup(
            AppStartupData(
              user: _athlete(),
              hasCompletedOnboarding: true,
              isLoggedOut: isLoggedOut,
            ),
          ),
        ),
        analyticsConsentProvider.overrideWith(_ConsentDecided.new),
      ],
    );
    addTearDown(container.dispose);
    // Hold startup the way the app's startup widget does, so the auto-dispose
    // provider keeps its data for the redirect. Startup has finished before
    // anything is tapped, as on device.
    final startup = container.listen(appStartupProvider, (_, __) {});
    addTearDown(startup.close);
    await container.read(appStartupProvider.future);

    final router = container.read(AppRouter.routerProvider);
    addTearDown(router.dispose);
    // Before the first frame, so the first route parsed is the unknown one.
    router.go('/pro');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  String path(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  testWidgets('a signed-in, onboarded athlete: Go Home lands on /main', (
    tester,
  ) async {
    final router = await pumpOnUnknownRoute(tester, isLoggedOut: false);

    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Go Home'));
    // One frame: the redirect has run by then. /main's tabs are not under
    // test here.
    await tester.pump();

    expect(path(router), '/main');
  });

  testWidgets('a logged-out athlete: Go Home lands on /welcome', (
    tester,
  ) async {
    final router = await pumpOnUnknownRoute(tester, isLoggedOut: true);

    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Go Home'));
    await tester.pump();

    expect(path(router), '/welcome');
  });
}
