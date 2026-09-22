// An install left anonymous from before the paywall signs up onto its old
// user (mp-455 §4, mp-417 §1; paywall ticket 09).
//
// Two seams:
//  1. The link keeps the data. Through the real EmailAuthService notifier,
//     the real AuthMigrationService and the real UserRepository over an
//     in-memory Drift seeded with the profile the old install holds, the
//     uid survives and the profile keeps the athlete's answers. The case
//     pinned is the one that lost them: the server has no row for the old
//     user (a pre-2026-07-29 local-only install) or the phone is offline, so
//     the remote fetch comes back empty. The link used to write a default
//     "not onboarded" profile over the athlete's own.
//  2. The account screen claims the grace month after the link, and only
//     after a link: the real GraceClaimService over a stubbed functions
//     client answering as `grace-claim` does.

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
import 'package:mealvana_endurance/features/auth/application/grace_claim_service.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/post_onboarding_auth_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

import '../../helpers/fixtures/user_fixtures.dart';
import '../../helpers/widget_test_harness.dart';

const _oldUid = '5f3c2a10-7d4e-4b8a-9c1f-0a2b3c4d5e6f';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

class _MockUser extends Mock implements User {}

class _MockUserResponse extends Mock implements UserResponse {}

class _MockSession extends Mock implements Session {}

class _MockAuthService extends Mock implements AuthService {}

class _MockSubscriptions extends Mock implements SubscriptionService {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

User _user({required bool anonymous, String? email}) {
  final u = _MockUser();
  when(() => u.id).thenReturn(_oldUid);
  when(() => u.email).thenReturn(email);
  when(() => u.newEmail).thenReturn(null);
  when(() => u.isAnonymous).thenReturn(anonymous);
  when(() => u.emailConfirmedAt).thenReturn(null);
  return u;
}

UserResponse _userResponse(User user) {
  final r = _MockUserResponse();
  when(() => r.user).thenReturn(user);
  return r;
}

/// What the old install's phone holds: the athlete's onboarded profile under
/// the anonymous uid, as the pre-paywall app wrote it.
UserProfile _oldInstallProfile() => UserFixtures.completedUser(
  id: _oldUid,
  deviceId: 'old-device-0001',
).copyWith(authUserId: _oldUid);

AppExternalDeps _deps(SupabaseClient client) {
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  return AppExternalDeps(
    analytics: analytics,
    supabaseClient: client,
    sentry: mockSentryReporter(),
    logger: MockAppLogger(),
    sharedPreferences: MockSharedPreferences(),
  );
}

// ---------------------------------------------------------------------------
// Screen doubles
// ---------------------------------------------------------------------------

class _LinkingController extends PostOnboardingAuthController {
  static final List<String> calls = [];

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> linkGoogleAccount() async {
    calls.add('linkGoogle');
    return true;
  }

  @override
  Future<bool> signInWithGoogle() async {
    calls.add('signInGoogle');
    return true;
  }
}

/// The old install arrives with no onboarding draft (it onboarded long ago).
class _NoDraftOnboardingController extends OnboardingController {
  @override
  FutureOr<void> build() {}

  @override
  bool get hasCompletedProfileDraft => false;

  @override
  Future<bool> saveAllOnboardingData({required String authProvider}) async =>
      false;

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

GoRouter _router() => GoRouter(
  initialLocation: '/auth',
  routes: [
    GoRoute(
      path: '/auth',
      builder: (_, __) => const PostOnboardingAuthScreen(),
    ),
    GoRoute(
      path: '/main',
      builder: (_, __) => const Scaffold(body: Text('MAIN')),
    ),
    GoRoute(
      path: '/paywall',
      builder: (_, __) => const Scaffold(body: Text('PAYWALL')),
    ),
  ],
);

({_MockFunctions functions, _MockSubscriptions subs, GraceClaimService claim})
_graceClaim(SupabaseClient client) {
  final functions = _MockFunctions();
  when(() => client.functions).thenReturn(functions);
  // As grace-claim answers an old install that signed up after the flip.
  when(() => functions.invoke('grace-claim')).thenAnswer(
    (_) async => FunctionResponse(
      status: 200,
      data: {'ok': true, 'status': 'granted', 'pro_days': 30},
    ),
  );
  final subs = _MockSubscriptions();
  when(() => subs.forgetCachedStatus()).thenAnswer((_) async {});
  return (
    functions: functions,
    subs: subs,
    claim: GraceClaimService(
      supabase: client,
      subscriptions: subs,
      logger: MockAppLogger(),
    ),
  );
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required SupabaseClient client,
  required GraceClaimService claim,
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final db = AppDatabase.memory();
  addTearDown(db.close);

  final authService = _MockAuthService();
  when(
    () => authService.getCurrentUser(),
  ).thenAnswer((_) async => _oldInstallProfile());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        inMemoryDatabaseOverride(db),
        mockSharedPreferences(),
        appExternalDepsProvider.overrideWithValue(_deps(client)),
        authServiceProvider.overrideWithValue(authService),
        postOnboardingAuthControllerProvider.overrideWith(
          _LinkingController.new,
        ),
        onboardingControllerProvider.overrideWith(
          _NoDraftOnboardingController.new,
        ),
        syncCoordinatorProvider.overrideWith(_NoopSyncCoordinator.new),
        graceClaimServiceProvider.overrideWithValue(claim),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (_, __) => MaterialApp.router(routerConfig: _router()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapGoogle(WidgetTester tester) async {
  final google = find.byKey(const ValueKey('post_onboarding.google_button'));
  await tester.scrollUntilVisible(google, 200);
  await tester.tap(google);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
  });

  setUp(_LinkingController.calls.clear);

  group('the link keeps the old install\'s data', () {
    test(
      'with no server row (or offline), the athlete\'s own profile stays, now registered',
      () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);
        await db.userDao.saveUserProfile(_oldInstallProfile());

        // GoTrue: the old anonymous session; the email lands at once (dev
        // auto-confirm), same uid.
        final auth = _MockGoTrue();
        final anon = _user(anonymous: true);
        final linked = _user(anonymous: false, email: 'ava@example.com');
        var call = 0;
        when(
          () => auth.currentUser,
        ).thenAnswer((_) => call == 0 ? anon : linked);
        when(() => auth.currentSession).thenReturn(_MockSession());
        when(
          () => auth.onAuthStateChange,
        ).thenAnswer((_) => const Stream.empty());
        when(() => auth.signOut()).thenAnswer((_) async {});
        when(() => auth.updateUser(any())).thenAnswer((_) async {
          call++;
          return _userResponse(linked);
        });
        // The server is unreachable: every PostgREST call fails, as offline.
        final client = _MockSupabase();
        when(() => client.auth).thenReturn(auth);
        when(
          () => client.from(any()),
        ).thenThrow(const SocketExceptionLike('Failed host lookup'));

        final sentry = mockSentryReporter();
        final repo = UserRepository(
          database: db,
          supabase: client,
          sentry: sentry,
        );
        final migration = AuthMigrationService(
          userRepository: repo,
          database: db,
          supabase: client,
          sentry: sentry,
        );
        final deps = _deps(client);
        final container = ProviderContainer(
          overrides: [
            appExternalDepsProvider.overrideWithValue(deps),
            analyticsTrackerProvider.overrideWithValue(deps.analytics),
            authMigrationServiceProvider.overrideWith((ref) async => migration),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(emailAuthServiceProvider.notifier)
            .linkEmailAccount(
              email: 'ava@example.com',
              password: 'password123',
            );

        final rows = await db.select(db.userProfilesTable).get();
        expect(rows.map((r) => r.id), [_oldUid], reason: 'uid survives');
        final after = (await db.userDao.getUserProfileById(_oldUid))!;
        // The athlete's answers, not a default profile.
        expect(after.onboardingCompleted, isTrue);
        expect(after.gender, Gender.female);
        expect(after.weightPounds, 140.0);
        expect(after.gutTraining, GutTraining.high);
        expect(after.deviceId, 'old-device-0001');
        // Registered now, and queued to reach the server.
        expect(after.isAnonymous, isFalse);
        expect(after.authProvider, 'email');
        expect(after.authUserId, _oldUid);
        expect(after.email, 'ava@example.com');
        final row = await (db.select(
          db.userProfilesTable,
        )..where((t) => t.id.equals(_oldUid))).getSingle();
        expect(row.needsUpload, isTrue);
      },
    );
  });

  group('the account screen claims the grace month', () {
    testWidgets('after linking onto the old anonymous user', (tester) async {
      final auth = _MockGoTrue();
      final anon = _user(anonymous: true);
      when(() => auth.currentUser).thenReturn(anon);
      when(() => auth.currentSession).thenReturn(_MockSession());
      when(
        () => auth.onAuthStateChange,
      ).thenAnswer((_) => const Stream.empty());
      final client = _MockSupabase();
      when(() => client.auth).thenReturn(auth);
      final grace = _graceClaim(client);

      await _pumpScreen(tester, client: client, claim: grace.claim);
      await _tapGoogle(tester);

      expect(_LinkingController.calls, ['linkGoogle']);
      verify(() => grace.functions.invoke('grace-claim')).called(1);
      // The SDK's locked answer from before the grant is dropped, so the gate
      // asks RevenueCat again.
      verify(() => grace.subs.forgetCachedStatus()).called(1);
      expect(find.text('MAIN'), findsOneWidget);
    });

    testWidgets('never for a sign-in with no old anonymous user', (
      tester,
    ) async {
      final signedOut = fakeGoTrueClient();
      final client = _MockSupabase();
      when(() => client.auth).thenReturn(signedOut);
      final grace = _graceClaim(client);

      await _pumpScreen(tester, client: client, claim: grace.claim);
      await _tapGoogle(tester);

      expect(_LinkingController.calls, ['signInGoogle']);
      verifyNever(() => grace.functions.invoke(any()));
    });

    testWidgets('the old install sent here by the router has no back button', (
      tester,
    ) async {
      final auth = _MockGoTrue();
      final anon = _user(anonymous: true);
      when(() => auth.currentUser).thenReturn(anon);
      when(() => auth.currentSession).thenReturn(_MockSession());
      when(
        () => auth.onAuthStateChange,
      ).thenAnswer((_) => const Stream.empty());
      final client = _MockSupabase();
      when(() => client.auth).thenReturn(auth);

      final grace = _graceClaim(client);
      await _pumpScreen(tester, client: client, claim: grace.claim);

      expect(
        find.byKey(const ValueKey('create_account.back_button')),
        findsNothing,
      );
    });
  });
}

/// A network failure as PostgREST surfaces it offline.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike(this.message);
  final String message;
  @override
  String toString() => 'SocketException: $message';
}
