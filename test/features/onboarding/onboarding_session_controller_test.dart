import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_session_controller.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

class MockUser extends Mock implements User {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

/// Regression tests for the Critical bug "new anonymous UID minted per open
/// and sign-out" (2026-09-17): establishing the onboarding session must
/// REUSE any existing Supabase session — anonymous or authenticated — and
/// mint a fresh anonymous uid only when no session exists at all. Runs
/// through the real OnboardingSessionController notifier.
void main() {
  late MockSupabaseClient supabase;
  late MockGoTrueClient auth;
  late MockSharedPreferences prefs;

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: MockAnalyticsTracker(),
            supabaseClient: supabase,
            sentry: MockSentryReporter(),
            logger: MockAppLogger(),
            sharedPreferences: prefs,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  MockUser makeUser({required String id, required bool isAnonymous}) {
    final user = MockUser();
    when(() => user.id).thenReturn(id);
    when(() => user.isAnonymous).thenReturn(isAnonymous);
    return user;
  }

  setUp(() {
    supabase = MockSupabaseClient();
    auth = MockGoTrueClient();
    prefs = MockSharedPreferences();
    when(() => supabase.auth).thenReturn(auth);
    when(() => prefs.remove(any())).thenAnswer((_) async => true);
  });

  test(
    'second app open reuses the same anonymous UID — no sign-out, no mint',
    () async {
      // The device's persisted anonymous session, as supabase_flutter
      // restores it on every launch.
      final persistedAnonUser = makeUser(id: 'anon-uid-1', isAnonymous: true);
      when(() => auth.currentUser).thenReturn(persistedAnonUser);

      // First open: a fresh ProviderScope, as app launch creates one.
      final firstOpen = makeContainer();
      final firstSession = await firstOpen
          .read(onboardingSessionControllerProvider.notifier)
          .ensureOnboardingSession();

      // Second open: another fresh ProviderScope over the same persisted
      // auth state.
      final secondOpen = makeContainer();
      final secondSession = await secondOpen
          .read(onboardingSessionControllerProvider.notifier)
          .ensureOnboardingSession();

      expect(firstSession!.userId, 'anon-uid-1');
      expect(secondSession!.userId, 'anon-uid-1');
      expect(secondSession.userId, firstSession.userId);
      expect(firstSession.outcome, OnboardingSessionOutcome.reusedAnonymous);
      expect(secondSession.outcome, OnboardingSessionOutcome.reusedAnonymous);

      // The forking pair from the original bug must never run when a
      // session exists.
      verifyNever(() => auth.signOut());
      verifyNever(() => auth.signInAnonymously());
    },
  );

  test(
    'a signed-in (non-anonymous) session is kept — the just-logged-in user '
    'is never signed out onto a throwaway uid',
    () async {
      final registeredUser = makeUser(id: 'real-uid-9', isAnonymous: false);
      when(() => auth.currentUser).thenReturn(registeredUser);

      final container = makeContainer();
      final session = await container
          .read(onboardingSessionControllerProvider.notifier)
          .ensureOnboardingSession();

      expect(session!.userId, 'real-uid-9');
      expect(session.outcome, OnboardingSessionOutcome.keptAuthenticated);
      verifyNever(() => auth.signOut());
      verifyNever(() => auth.signInAnonymously());
    },
  );

  test('with no session at all, mints exactly one anonymous session', () async {
    when(() => auth.currentUser).thenReturn(null);
    final mintedUser = makeUser(id: 'anon-uid-new', isAnonymous: true);
    when(
      () => auth.signInAnonymously(),
    ).thenAnswer((_) async => AuthResponse(user: mintedUser));

    final container = makeContainer();
    final session = await container
        .read(onboardingSessionControllerProvider.notifier)
        .ensureOnboardingSession();

    expect(session!.userId, 'anon-uid-new');
    expect(session.outcome, OnboardingSessionOutcome.mintedAnonymous);
    verify(() => auth.signInAnonymously()).called(1);
    verifyNever(() => auth.signOut());
    // Stale temp id from a previous (now orphaned) attempt is cleared.
    verify(() => prefs.remove('onboarding_temp_user_id')).called(1);
  });

  test('mint failure lands in state.error and returns null — onboarding '
      'proceeds (router anti-loop contract)', () async {
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => auth.signInAnonymously(),
    ).thenThrow(const AuthException('network down'));

    final container = makeContainer();
    final notifier = container.read(
      onboardingSessionControllerProvider.notifier,
    );
    final session = await notifier.ensureOnboardingSession();

    expect(session, isNull);
    expect(container.read(onboardingSessionControllerProvider).hasError, true);
  });
}
