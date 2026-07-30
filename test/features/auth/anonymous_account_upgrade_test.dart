// Anonymous-account upgrade: the uid must survive.
//
// Anonymous data is synced to Supabase, so `public.users.id` (== auth.uid())
// is the key every user-scoped row hangs off: activities, events,
// formula_pins, integrations, food_preferences, user_foods, carb_loading_plans.
// An upgrade that mints a NEW uid orphans all of it under a dead id. These
// tests pin the two upgrade routes:
//
//  1. EmailAuthService.linkEmailAccount — updateUser() on the live anonymous
//     session (uid preserved), including the production case where the address
//     must be confirmed before the upgrade lands.
//  2. EmailSignupScreen — routes an anonymous session to the LINK path and a
//     sessionless one to signUp(), and never signs an anonymous user out.
//  3. PostOnboardingAuthScreen — an OAuth upgrade from Settings (no cached
//     onboarding data, profile already persisted) must not report failure.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/auth_migration_service.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_signup_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/post_onboarding_auth_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

import '../../helpers/fixtures/user_fixtures.dart';
import '../../helpers/widget_test_harness.dart';

const _anonUid = 'anon-uid-0000-1111';

// ---------------------------------------------------------------------------
// Doubles
// ---------------------------------------------------------------------------

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockUser extends Mock implements User {}

class _MockUserResponse extends Mock implements UserResponse {}

class _MockAuthResponse extends Mock implements AuthResponse {}

class _MockSession extends Mock implements Session {}

class _MockAuthMigrationService extends Mock implements AuthMigrationService {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

/// Records the arguments of the single call the upgrade path is allowed to
/// make into the migration layer.
class _CompletionSpy {
  String? previousUserId;
  String? newUserId;
  bool? preservedUserId;
  int calls = 0;
}

User _user({
  String id = _anonUid,
  String? email,
  String? newEmail,
  bool isAnonymous = true,
}) {
  final u = _MockUser();
  when(() => u.id).thenReturn(id);
  when(() => u.email).thenReturn(email);
  when(() => u.newEmail).thenReturn(newEmail);
  when(() => u.isAnonymous).thenReturn(isAnonymous);
  when(() => u.emailConfirmedAt).thenReturn(null);
  return u;
}

UserResponse _userResponse(User user) {
  final r = _MockUserResponse();
  when(() => r.user).thenReturn(user);
  return r;
}

/// A GoTrue client holding an anonymous session, with `updateUser` wired to
/// return [afterEmail] for the email step and [afterPassword] for the password
/// step (GoTrue requires them as two separate calls).
GoTrueClient _anonGoTrue({
  required User afterEmail,
  required User afterPassword,
}) {
  final auth = _MockGoTrue();
  final anon = _user();
  final session = _MockSession();
  var call = 0;

  when(() => auth.currentUser).thenReturn(anon);
  when(() => auth.currentSession).thenReturn(session);
  when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  when(() => auth.signOut()).thenAnswer((_) async {});
  when(() => auth.updateUser(any())).thenAnswer(
    (_) async => _userResponse(call++ == 0 ? afterEmail : afterPassword),
  );
  return auth;
}

SupabaseClient _clientWith(GoTrueClient auth) {
  final client = _MockSupabase();
  when(() => client.auth).thenReturn(auth);
  return client;
}

AppExternalDeps _deps(SupabaseClient client) {
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  return AppExternalDeps(
    analytics: analytics,
    supabaseClient: client,
    sentry: MockSentryReporter(),
    logger: MockAppLogger(),
    sharedPreferences: MockSharedPreferences(),
  );
}

/// Container wired for [EmailAuthService] with the migration layer spied on.
({ProviderContainer container, _CompletionSpy spy}) _containerFor(
  SupabaseClient client,
) {
  final spy = _CompletionSpy();
  final migration = _MockAuthMigrationService();
  when(
    () => migration.completeAuthentication(
      previousUserId: any(named: 'previousUserId'),
      wasAnonymous: any(named: 'wasAnonymous'),
      newUserId: any(named: 'newUserId'),
      authProvider: any(named: 'authProvider'),
      preservedUserId: any(named: 'preservedUserId'),
    ),
  ).thenAnswer((invocation) async {
    spy.calls++;
    spy.previousUserId = invocation.namedArguments[#previousUserId] as String?;
    spy.newUserId = invocation.namedArguments[#newUserId] as String?;
    spy.preservedUserId = invocation.namedArguments[#preservedUserId] as bool?;
    return false;
  });

  final deps = _deps(client);
  final container = ProviderContainer(
    overrides: [
      appExternalDepsProvider.overrideWithValue(deps),
      analyticsTrackerProvider.overrideWithValue(deps.analytics),
      authMigrationServiceProvider.overrideWith((ref) async => migration),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, spy: spy);
}

// ---------------------------------------------------------------------------
// Widget-test doubles
// ---------------------------------------------------------------------------

/// Records which upgrade route the signup screen chose.
class _SpyAuthController extends PostOnboardingAuthController {
  static final List<String> calls = [];

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> linkEmailAccount({
    required String email,
    required String password,
  }) async {
    calls.add('link');
    return false; // stop before navigation; the routing choice is the assertion
  }

  @override
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    calls.add('signup');
    return false;
  }

  @override
  Future<bool> linkGoogleAccount() async {
    calls.add('linkGoogle');
    return true;
  }
}

/// Post-onboarding state: no in-memory onboarding cache (it is per-run), and
/// saveAllOnboardingData must never be reached on an upgrade.
class _NoCacheOnboardingController extends OnboardingController {
  static int saveCalls = 0;

  @override
  FutureOr<void> build() {}

  @override
  Map<String, dynamic>? get cachedUserProfileData => null;

  @override
  Future<bool> saveAllOnboardingData({
    String authProvider = 'anonymous',
    bool isAnonymous = true,
  }) async {
    saveCalls++;
    return false; // what the real controller does with a null cache
  }

  @override
  Future<List<String>> uploadOnboardingDataToSupabase(String userId) async =>
      const [];
}

class _NoopSyncCoordinator extends SyncCoordinator {
  @override
  SyncState build() => SyncState.idle;

  @override
  Future<bool> sync({
    required String userId,
    SyncTrigger trigger = SyncTrigger.manual,
    bool skipInvalidation = false,
  }) async => true;
}

/// Pumps [routes] behind a real GoRouter with a generously sized surface.
///
/// Not [pumpSeeded]: that helper installs its own appExternalDeps override, and
/// Riverpod rejects two overrides of the same provider in one container — these
/// tests must supply their own Supabase client (anonymous vs signed out).
Future<void> _pumpRouted(
  WidgetTester tester, {
  required List<Override> overrides,
  required GoRouter router,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final db = AppDatabase.memory();
  addTearDown(db.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        inMemoryDatabaseOverride(db),
        mockSharedPreferences(),
        ...overrides,
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

/// A router that shows [screen] at `/auth` and a sentinel at `/main`.
GoRouter _routerFor(Widget screen) => GoRouter(
  initialLocation: '/auth',
  routes: [
    GoRoute(path: '/auth', builder: (_, __) => screen),
    GoRoute(
      path: '/main',
      builder: (_, __) => const Scaffold(body: Text('MAIN')),
    ),
  ],
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
    registerFallbackValue(OtpType.signup);
  });

  setUp(() {
    _SpyAuthController.calls.clear();
    _NoCacheOnboardingController.saveCalls = 0;
  });

  group('EmailAuthService.linkEmailAccount', () {
    test(
      'auto-confirmed upgrade preserves the uid and links in place',
      () async {
        // Dev-style: the address lands on the account immediately.
        final auth = _anonGoTrue(
          afterEmail: _user(email: 'a@b.com', isAnonymous: false),
          afterPassword: _user(email: 'a@b.com', isAnonymous: false),
        );
        final wired = _containerFor(_clientWith(auth));

        await wired.container
            .read(emailAuthServiceProvider.notifier)
            .linkEmailAccount(email: 'a@b.com', password: 'password123');

        // The uid never moved, so nothing needs migrating.
        expect(wired.spy.calls, 1);
        expect(wired.spy.previousUserId, _anonUid);
        expect(wired.spy.newUserId, _anonUid);
        expect(wired.spy.preservedUserId, isTrue);

        // Signing out would have minted a new uid on the next signUp().
        verifyNever(() => auth.signOut());
      },
    );

    test(
      'pending confirmation leaves the anonymous account intact and asks for the code',
      () async {
        // Production-style: GoTrue parks the address in `new_email` and mails a
        // code. The session is still anonymous, so the upgrade must NOT be
        // treated as done.
        final auth = _anonGoTrue(
          afterEmail: _user(newEmail: 'a@b.com'),
          afterPassword: _user(newEmail: 'a@b.com'),
        );
        final wired = _containerFor(_clientWith(auth));

        await expectLater(
          wired.container
              .read(emailAuthServiceProvider.notifier)
              .linkEmailAccount(email: 'a@b.com', password: 'password123'),
          throwsA(isA<EmailVerificationRequiredException>()),
        );

        // Nothing was flipped: the anonymous account is still fully usable.
        expect(wired.spy.calls, 0);
        verifyNever(() => auth.signOut());
      },
    );
  });

  group('EmailAuthService.verifyEmailOtp', () {
    test('emailChange code completes the link on the SAME uid', () async {
      final auth = _MockGoTrue();
      final upgraded = _user(email: 'a@b.com', isAnonymous: false);
      final anon = _user();
      final session = _MockSession();
      final response = _MockAuthResponse();
      when(() => response.session).thenReturn(session);
      when(() => response.user).thenReturn(upgraded);

      when(() => auth.currentUser).thenReturn(anon);
      when(
        () => auth.onAuthStateChange,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => response);

      final wired = _containerFor(_clientWith(auth));

      await wired.container
          .read(emailAuthServiceProvider.notifier)
          .verifyEmailOtp(
            email: 'a@b.com',
            token: '123456',
            type: OtpType.emailChange,
          );

      expect(wired.spy.calls, 1);
      expect(wired.spy.previousUserId, _anonUid);
      expect(wired.spy.newUserId, _anonUid);
      expect(wired.spy.preservedUserId, isTrue);

      // GoTrue models this as an email *change*, not a signup.
      final captured = verify(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: captureAny(named: 'type'),
        ),
      ).captured;
      expect(captured.single, OtpType.emailChange);
    });

    test('signup code does not run the link completion', () async {
      final auth = _MockGoTrue();
      final session = _MockSession();
      final newUser = _user(id: 'brand-new-uid');
      final response = _MockAuthResponse();
      when(() => response.session).thenReturn(session);
      when(() => response.user).thenReturn(newUser);

      when(() => auth.currentUser).thenReturn(null);
      when(
        () => auth.onAuthStateChange,
      ).thenAnswer((_) => const Stream.empty());
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => response);

      final wired = _containerFor(_clientWith(auth));

      await wired.container
          .read(emailAuthServiceProvider.notifier)
          .verifyEmailOtp(email: 'a@b.com', token: '123456');

      expect(wired.spy.calls, 0);
    });
  });

  group('EmailSignupScreen routing', () {
    testWidgets('an anonymous session upgrades in place (never signs out)', (
      tester,
    ) async {
      final auth = _MockGoTrue();
      // Build the doubles BEFORE opening a stub: mocktail forbids calling
      // `when` while a stub response is being constructed.
      final anon = _user();
      final session = _MockSession();
      when(() => auth.currentUser).thenReturn(anon);
      when(() => auth.currentSession).thenReturn(session);
      when(
        () => auth.onAuthStateChange,
      ).thenAnswer((_) => const Stream.empty());
      when(() => auth.signOut()).thenAnswer((_) async {});

      final client = _clientWith(auth);
      await _pumpRouted(
        tester,
        router: _routerFor(const EmailSignupScreen()),
        overrides: [
          appExternalDepsProvider.overrideWithValue(_deps(client)),
          postOnboardingAuthControllerProvider.overrideWith(
            _SpyAuthController.new,
          ),
        ],
      );

      await _fillSignupForm(tester);

      expect(_SpyAuthController.calls, ['link']);
      verifyNever(() => auth.signOut());
    });

    testWidgets('no session falls back to a fresh signUp', (tester) async {
      final auth = fakeGoTrueClient(); // signed out
      final signedOutClient = _clientWith(auth);

      await _pumpRouted(
        tester,
        router: _routerFor(const EmailSignupScreen()),
        overrides: [
          appExternalDepsProvider.overrideWithValue(_deps(signedOutClient)),
          postOnboardingAuthControllerProvider.overrideWith(
            _SpyAuthController.new,
          ),
        ],
      );

      await _fillSignupForm(tester);

      expect(_SpyAuthController.calls, ['signup']);
    });
  });

  group('PostOnboardingAuthScreen upgrade from Settings', () {
    testWidgets(
      'OAuth upgrade with no onboarding cache navigates instead of failing',
      (tester) async {
        final auth = _MockGoTrue();
        final anon = _user();
        final session = _MockSession();
        when(() => auth.currentUser).thenReturn(anon);
        when(() => auth.currentSession).thenReturn(session);
        when(
          () => auth.onAuthStateChange,
        ).thenAnswer((_) => const Stream.empty());

        final authService = _MockAuthService();
        when(
          () => authService.getCurrentUser(),
        ).thenAnswer((_) async => UserFixtures.completedUser(id: _anonUid));

        final client = _clientWith(auth);
        await _pumpRouted(
          tester,
          router: _routerFor(const PostOnboardingAuthScreen()),
          overrides: [
            appExternalDepsProvider.overrideWithValue(_deps(client)),
            authServiceProvider.overrideWithValue(authService),
            postOnboardingAuthControllerProvider.overrideWith(
              _SpyAuthController.new,
            ),
            onboardingControllerProvider.overrideWith(
              _NoCacheOnboardingController.new,
            ),
            syncCoordinatorProvider.overrideWith(_NoopSyncCoordinator.new),
          ],
        );

        final googleButton = find.byKey(
          const ValueKey('post_onboarding.google_button'),
        );
        await tester.scrollUntilVisible(googleButton, 200);
        await tester.tap(googleButton);
        await tester.pumpAndSettle();

        // The identity was already flipped by the link; there is no cached
        // onboarding data to write, so the save must be skipped entirely...
        expect(_NoCacheOnboardingController.saveCalls, 0);
        // ...and the user must not be told their preferences failed to save.
        expect(find.textContaining('Failed to save'), findsNothing);
        expect(find.text('MAIN'), findsOneWidget);
      },
    );
  });
}

/// Fills the signup form and taps Create Account.
Future<void> _fillSignupForm(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('signup_email.email_field')),
    'a@b.com',
  );
  await tester.enterText(
    find.byKey(const ValueKey('signup_email.password_field')),
    'password123',
  );
  await tester.enterText(
    find.byKey(const ValueKey('signup_email.confirm_password_field')),
    'password123',
  );
  await tester.tap(
    find.byKey(const ValueKey('signup_email.create_account_button')),
  );
  await tester.pumpAndSettle();
}
