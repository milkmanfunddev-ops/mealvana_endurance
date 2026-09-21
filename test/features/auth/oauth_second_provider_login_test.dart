// OAuth second-provider login must never strand the athlete in a fresh
// empty account (Critical, 2026-09-17).
//
// Supabase's id-token grant has no "sign in only" mode: a LOGIN attempt with
// a never-before-seen provider identity silently MINTS a brand-new user. An
// Apple registrant who logs in with Google (private-relay email defeats
// server-side email matching) landed in an empty uid that read as total data
// loss (`a77aecc3` -> `c4ecf49f`). These tests pin the fix:
//
//  1. OAuthService.isFreshlyMintedUser — the mint detector, fed
//     PRODUCER-SHAPED GoTrue wire JSON (docs/test/README.md §Seam tests),
//     never locally constructed User objects. Unparseable boundary data
//     fails OPEN (never lock a real user out on garbage).
//  2. OAuthService.refuseFreshlyMintedLoginAccount — through the REAL
//     notifier: a fresh mint is signed back out and surfaced as
//     OAuthAccountNotFoundException; a returning user passes untouched.
//  3. PostOnboardingAuthController.signInWithGoogle/-Apple — through the
//     REAL controller: the refusal comes back as a typed error state (so the
//     screen can say which way is home), not as success.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/oauth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';

import '../../helpers/widget_test_harness.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

// ---------------------------------------------------------------------------
// Producer-shaped fixtures: GoTrue's wire JSON for a signInWithIdToken user,
// microsecond timestamps and all. A fresh mint's created_at/last_sign_in_at
// are written milliseconds apart by the SAME server request; a returning
// user's created_at is months older. Never build these from the detector's
// own inputs.
// ---------------------------------------------------------------------------

User _wireUser({
  required String createdAt,
  Object? lastSignInAt = #unset,
  String? email = 'athlete@gmail.com',
}) {
  final json = <String, dynamic>{
    'id': 'c4ecf49f-0000-4000-8000-000000000000',
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': email,
    'email_confirmed_at': createdAt,
    'app_metadata': {
      'provider': 'google',
      'providers': ['google'],
    },
    'user_metadata': {'email_verified': true},
    'created_at': createdAt,
    'is_anonymous': false,
  };
  if (lastSignInAt != #unset) {
    json['last_sign_in_at'] = lastSignInAt;
  }
  return User.fromJson(json)!;
}

/// The mint: both stamps from the same creating request.
User _freshlyMintedUser() => _wireUser(
  createdAt: '2026-08-23T14:03:11.482913Z',
  lastSignInAt: '2026-08-23T14:03:11.507224Z',
);

/// The 9-month registrant signing back in.
User _returningUser() => _wireUser(
  createdAt: '2025-11-14T09:22:41.118332Z',
  lastSignInAt: '2026-08-23T14:03:11.507224Z',
);

// ---------------------------------------------------------------------------
// Container wiring for the real OAuthService notifier
// ---------------------------------------------------------------------------

({ProviderContainer container, GoTrueClient auth, AnalyticsTracker analytics})
_oauthContainer() {
  final auth = _MockGoTrue();
  when(() => auth.signOut()).thenAnswer((_) async {});

  final client = _MockSupabase();
  when(() => client.auth).thenReturn(auth);

  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});

  final deps = AppExternalDeps(
    analytics: analytics,
    supabaseClient: client,
    sentry: MockSentryReporter(),
    logger: MockAppLogger(),
    sharedPreferences: MockSharedPreferences(),
  );

  final container = ProviderContainer(
    overrides: [
      appExternalDepsProvider.overrideWithValue(deps),
      analyticsTrackerProvider.overrideWithValue(analytics),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, auth: auth, analytics: analytics);
}

/// OAuthService double for the CONTROLLER tests: the native plugin calls
/// (GoogleSignIn / SignInWithApple) cannot run headless, so the service is
/// pinned to the outcome under test while the controller stays real.
class _NoAccountOAuthService extends OAuthService {
  @override
  Future<void> build() async {}

  @override
  Future<void> signInWithGoogle() async {
    throw const OAuthAccountNotFoundException(
      provider: 'google',
      email: 'athlete@gmail.com',
    );
  }

  @override
  Future<void> signInWithApple() async {
    throw const OAuthAccountNotFoundException(provider: 'apple');
  }
}

ProviderContainer _controllerContainer() {
  final client = _MockSupabase();
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});

  final deps = AppExternalDeps(
    analytics: analytics,
    supabaseClient: client,
    sentry: MockSentryReporter(),
    logger: MockAppLogger(),
    sharedPreferences: MockSharedPreferences(),
  );

  final container = ProviderContainer(
    overrides: [
      appExternalDepsProvider.overrideWithValue(deps),
      analyticsTrackerProvider.overrideWithValue(analytics),
      oAuthServiceProvider.overrideWith(_NoAccountOAuthService.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('OAuthService.isFreshlyMintedUser (seam: GoTrue wire JSON)', () {
    test('detects the mint: created_at == last_sign_in_at to within ms', () {
      expect(OAuthService.isFreshlyMintedUser(_freshlyMintedUser()), isTrue);
    });

    test('a returning user (created months earlier) is not a mint', () {
      expect(OAuthService.isFreshlyMintedUser(_returningUser()), isFalse);
    });

    test('a re-sign-in minutes after signup is already outside tolerance', () {
      final user = _wireUser(
        createdAt: '2026-08-23T14:03:11.482913Z',
        lastSignInAt: '2026-08-23T14:08:30.000000Z',
      );
      expect(OAuthService.isFreshlyMintedUser(user), isFalse);
    });

    test('fails OPEN on absent last_sign_in_at (gotrue nullable field)', () {
      final user = _wireUser(createdAt: '2026-08-23T14:03:11.482913Z');
      expect(OAuthService.isFreshlyMintedUser(user), isFalse);
    });

    test('fails OPEN on unparseable created_at (gotrue defaults to "")', () {
      final user = _wireUser(
        createdAt: '',
        lastSignInAt: '2026-08-23T14:03:11.507224Z',
      );
      expect(OAuthService.isFreshlyMintedUser(user), isFalse);
    });
  });

  group('OAuthService.refuseFreshlyMintedLoginAccount (real notifier)', () {
    test('signs the mint back out and throws OAuthAccountNotFound', () async {
      final wired = _oauthContainer();
      final service = wired.container.read(oAuthServiceProvider.notifier);

      await expectLater(
        service.refuseFreshlyMintedLoginAccount(
          user: _freshlyMintedUser(),
          provider: 'google',
          email: 'athlete@gmail.com',
        ),
        throwsA(
          isA<OAuthAccountNotFoundException>()
              .having((e) => e.provider, 'provider', 'google')
              .having((e) => e.email, 'email', 'athlete@gmail.com'),
        ),
      );

      // The empty account must not be left as the live session.
      verify(() => wired.auth.signOut()).called(1);
      verify(
        () => wired.analytics.track(
          'auth_oauth_no_existing_account',
          properties: any(named: 'properties'),
        ),
      ).called(1);
    });

    test('a returning user passes untouched — no sign-out, no throw', () async {
      final wired = _oauthContainer();
      final service = wired.container.read(oAuthServiceProvider.notifier);

      await service.refuseFreshlyMintedLoginAccount(
        user: _returningUser(),
        provider: 'apple',
      );

      verifyNever(() => wired.auth.signOut());
    });
  });

  group('PostOnboardingAuthController (real controller)', () {
    test('signInWithGoogle surfaces the refusal as a typed error state', () async {
      final container = _controllerContainer();
      final controller = container.read(
        postOnboardingAuthControllerProvider.notifier,
      );

      final success = await controller.signInWithGoogle();

      expect(success, isFalse);
      final state = container.read(postOnboardingAuthControllerProvider);
      expect(state.error, isA<OAuthAccountNotFoundException>());
      expect(
        (state.error as OAuthAccountNotFoundException).provider,
        'google',
      );
    });

    test('signInWithApple surfaces the refusal as a typed error state', () async {
      final container = _controllerContainer();
      final controller = container.read(
        postOnboardingAuthControllerProvider.notifier,
      );

      final success = await controller.signInWithApple();

      expect(success, isFalse);
      final state = container.read(postOnboardingAuthControllerProvider);
      expect(state.error, isA<OAuthAccountNotFoundException>());
    });
  });
}
