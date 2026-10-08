// `/welcome` resolves like `/` for anyone signed in (round develop-2026-10,
// ticket 56: Findings 49-001, 50-005; Lee's ruling 2026-10-08: an onboarded
// anonymous guest skips Welcome too).
//
// Runs through the real `AppRouter.routerProvider`; only the state the
// redirect reads is overridden (harness from page_not_found_go_home_test).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

class _FinishedStartup extends AppStartup {
  _FinishedStartup(this.data);
  final AppStartupData data;

  @override
  Future<AppStartupData> build() async => data;
}

class _ConsentDecided extends AnalyticsConsentNotifier {
  @override
  AnalyticsConsent build() => const AnalyticsConsent(
    status: ConsentStatus.granted,
    regime: ConsentRegime.standard,
    source: RegionSource.geo,
  );
}

UserProfile _profile({required bool anonymous, required bool onboarded}) {
  final now = DateTime(2026, 10, 8);
  return UserProfile(
    id: 'athlete-56',
    deviceId: 'device-56',
    authUserId: 'athlete-56',
    authProvider: anonymous ? 'anonymous' : 'email',
    isAnonymous: anonymous,
    gender: Gender.female,
    birthday: DateTime(1990, 1, 1),
    heightFeet: 5,
    heightInches: 6,
    weightPounds: 140,
    runsWithWaterBottle: true,
    createdAt: now,
    updatedAt: now,
    onboardingCompleted: onboarded,
    appVersion: '1.30.0',
  );
}

AppStartupData _snapshot({
  UserProfile? user,
  bool resyncRequired = false,
  bool isLoggedOut = false,
}) => AppStartupData(
  user: user,
  hasCompletedOnboarding: user?.onboardingCompleted ?? false,
  resyncRequired: resyncRequired,
  isLoggedOut: isLoggedOut,
);

void main() {
  /// Pumps the real router straight onto `/welcome`, as a typed or linked
  /// `…:///welcome` arrives (50-005), and returns the path it settled on.
  Future<String> landOnWelcome(
    WidgetTester tester, {
    required bool hasSession,
    required AppStartupData startup,
  }) async {
    final auth = MockGoTrueClient();
    when(
      () => auth.currentSession,
    ).thenReturn(hasSession ? _MockSession() : null);
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());

    final container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: fakeSupabaseClient(auth: auth)),
        mockSharedPreferences(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        contentServiceProvider.overrideWith(testContentService),
        appStartupProvider.overrideWith(() => _FinishedStartup(startup)),
        analyticsConsentProvider.overrideWith(_ConsentDecided.new),
      ],
    );
    addTearDown(container.dispose);
    final held = container.listen(appStartupProvider, (_, __) {});
    addTearDown(held.close);
    await container.read(appStartupProvider.future);

    final router = container.read(AppRouter.routerProvider);
    addTearDown(router.dispose);
    router.go('/welcome');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    // One frame: the redirect has run by then. The landing screens' own
    // providers are not under test here.
    return router.routerDelegate.currentConfiguration.uri.path;
  }

  testWidgets('a signed-in, onboarded athlete: /welcome lands on /main', (
    tester,
  ) async {
    final path = await landOnWelcome(
      tester,
      hasSession: true,
      startup: _snapshot(user: _profile(anonymous: false, onboarded: true)),
    );
    expect(path, '/main');
  });

  testWidgets('no session: Welcome renders (sign-out, delete account)', (
    tester,
  ) async {
    final path = await landOnWelcome(
      tester,
      hasSession: false,
      startup: _snapshot(
        user: _profile(anonymous: false, onboarded: true),
        isLoggedOut: true,
      ),
    );
    expect(path, '/welcome');
  });

  testWidgets('an onboarded anonymous guest: /welcome lands on /main '
      "(Lee's ruling)", (tester) async {
    final path = await landOnWelcome(
      tester,
      hasSession: true,
      startup: _snapshot(user: _profile(anonymous: true, onboarded: true)),
    );
    expect(path, '/main');
  });

  testWidgets('an anonymous guest with no profile yet (Build My Plan, then '
      "Sports Selection's back): Welcome renders", (tester) async {
    final path = await landOnWelcome(
      tester,
      hasSession: true,
      startup: _snapshot(),
    );
    expect(path, '/welcome');
  });

  testWidgets('an anonymous guest who has not finished onboarding: Welcome '
      'renders', (tester) async {
    final path = await landOnWelcome(
      tester,
      hasSession: true,
      startup: _snapshot(user: _profile(anonymous: true, onboarded: false)),
    );
    expect(path, '/welcome');
  });

  testWidgets('a signed-in account that is not onboarded: Welcome renders', (
    tester,
  ) async {
    final path = await landOnWelcome(
      tester,
      hasSession: true,
      startup: _snapshot(user: _profile(anonymous: false, onboarded: false)),
    );
    expect(path, '/welcome');
  });

  testWidgets('a signed-in account with a failed resync: Welcome renders, '
      'no loop back to /main', (tester) async {
    final path = await landOnWelcome(
      tester,
      hasSession: true,
      startup: _snapshot(
        user: _profile(anonymous: false, onboarded: true),
        resyncRequired: true,
      ),
    );
    expect(path, '/welcome');
  });

  group('AppRouter.welcomeRedirect', () {
    String? redirect({
      required bool hasSession,
      required AsyncValue<AppStartupData> startup,
      bool pendingSignupOpen = false,
    }) => AppRouter.welcomeRedirect(
      hasSession: hasSession,
      startup: startup,
      pendingSignupOpen: () => pendingSignupOpen,
      needsConsentPrompt: () => false,
    );

    final onboarded = _snapshot(
      user: _profile(anonymous: false, onboarded: true),
    );

    test('startup still loading or failed: Welcome renders', () {
      expect(
        redirect(
          hasSession: true,
          startup: const AsyncLoading<AppStartupData>(),
        ),
        isNull,
      );
      expect(
        redirect(
          hasSession: true,
          startup: AsyncError<AppStartupData>('boom', StackTrace.empty),
        ),
        isNull,
      );
    });

    test('a signed-in, onboarded account resolves to /main', () {
      expect(redirect(hasSession: true, startup: AsyncData(onboarded)), '/main');
      expect(redirect(hasSession: false, startup: AsyncData(onboarded)), isNull);
    });
  });
}
