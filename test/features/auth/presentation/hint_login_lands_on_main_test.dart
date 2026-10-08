/// A login from Verify's hint lands on the Timeline (develop-2026-10 ticket
/// 57, Finding 48-003).
///
/// The stack is post-onboarding → Sign Up with Email → Verify your email.
/// Verify's "Log in" used to push Log In on the router itself, so the
/// login's `pop(true)` went to a push nobody awaited and the athlete stayed
/// on Sign Up, signed in. Now Verify pops `logIn`, the signup screen runs
/// the login and pops `EmailSignupResult.loggedIn`, and post-onboarding
/// finishes it as a login (the draft policy) with `go('/main')`.
///
/// Runs through the real `AppRouter.routerProvider` and the real screens,
/// controllers and `EmailAuthService`. GoTrue answers as it does: a
/// confirmation-required signup is a user with no session; a password login
/// is A's session.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/app_startup/application/app_startup_provider.dart';
import 'package:mealvana_endurance/features/auth/application/auth_migration_service.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/auth/data/pending_signup_store.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_login_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_signup_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/post_onboarding_auth_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/services/privacy/analytics_consent.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

import '../../../helpers/fakes/recording_report.dart';
import '../../../helpers/fixtures/user_fixtures.dart';
import '../../../helpers/test_content.dart';
import '../../../helpers/widget_test_harness.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockFunctions extends Mock implements FunctionsClient {}

class _MockMigration extends Mock implements AuthMigrationService {}

class _MockAuthService extends Mock implements AuthService {}

const _addressB = 'new-b@example.com';
const _addressA = 'athlete-a@example.com';
const _uidB = 'b0000000-0000-4000-8000-000000000048';
const _uidA = 'a0000000-0000-4000-8000-000000000048';
const _anonUid = '656d8eb7-0000-4000-8000-000000000048';

Map<String, dynamic> _userJson({
  required String id,
  String email = '',
  String? newEmail,
  bool anonymous = false,
  String? confirmedAt,
}) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': email,
  'new_email': newEmail,
  'email_change_sent_at': newEmail == null ? null : '2026-10-08T14:01:00Z',
  'email_confirmed_at': confirmedAt,
  'is_anonymous': anonymous,
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'created_at': '2026-10-08T14:00:00Z',
};

Map<String, dynamic> _sessionJson(Map<String, dynamic> user) => {
  'access_token': 'access',
  'token_type': 'bearer',
  'expires_in': 3600,
  'refresh_token': 'refresh',
  'user': user,
};

/// The onboarding controller with a finished draft; the save is counted and
/// the upload is quiet.
class _DraftOnboardingController extends OnboardingController {
  static int saveCalls = 0;

  @override
  Future<bool> saveAllOnboardingData({
    String authProvider = 'anonymous',
    bool isAnonymous = true,
  }) async {
    saveCalls++;
    return true;
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

/// Startup already finished for the launch that reached onboarding.
class _FinishedStartup extends AppStartup {
  @override
  Future<AppStartupData> build() async =>
      const AppStartupData(user: null, hasCompletedOnboarding: false);
}

class _ConsentDecided extends AnalyticsConsentNotifier {
  @override
  AnalyticsConsent build() => const AnalyticsConsent(
    status: ConsentStatus.granted,
    regime: ConsentRegime.standard,
    source: RegionSource.geo,
  );
}

/// GoTrue as the run saw it. [anonymous]: the anonymous session of Build My
/// Plan (the upgrade path, `emailChange`); otherwise no session (a fresh
/// signup). A's login replaces whichever it was.
_MockGoTrue _goTrue({required bool anonymous}) {
  final goTrue = _MockGoTrue();
  var user = anonymous
      ? User.fromJson(_userJson(id: _anonUid, anonymous: true))
      : null;
  var session = anonymous
      ? Session.fromJson(_sessionJson(_userJson(id: _anonUid, anonymous: true)))
      : null;
  when(() => goTrue.currentUser).thenAnswer((_) => user);
  when(() => goTrue.currentSession).thenAnswer((_) => session);
  when(() => goTrue.onAuthStateChange).thenAnswer((_) => const Stream.empty());
  when(() => goTrue.signOut()).thenAnswer((_) async {});
  // A confirmation-required signup: the user, no session.
  when(
    () => goTrue.signUp(
      email: any(named: 'email'),
      password: any(named: 'password'),
      emailRedirectTo: any(named: 'emailRedirectTo'),
      data: any(named: 'data'),
      captchaToken: any(named: 'captchaToken'),
    ),
  ).thenAnswer(
    (_) async => AuthResponse.fromJson(_userJson(id: _uidB, email: _addressB)),
  );
  // The upgrade path parks B in `new_email` and keeps the anonymous uid.
  when(() => goTrue.updateUser(any())).thenAnswer(
    (_) async => UserResponse.fromJson(
      _userJson(id: _anonUid, anonymous: true, newEmail: _addressB),
    ),
  );
  when(
    () => goTrue.signInWithPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
      captchaToken: any(named: 'captchaToken'),
    ),
  ).thenAnswer((_) async {
    final a = _userJson(
      id: _uidA,
      email: _addressA,
      confirmedAt: '2026-01-01T00:00:00Z',
    );
    user = User.fromJson(a);
    session = Session.fromJson(_sessionJson(a));
    return AuthResponse.fromJson(_sessionJson(a));
  });
  return goTrue;
}

class _FakeUserAttributes extends Fake implements UserAttributes {}

late SharedPreferences _prefs;
late RecordingReport _report;

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
    registerFallbackValue(OtpType.signup);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    _prefs = await SharedPreferences.getInstance();
    FlutterSecureStorage.setMockInitialValues({});
    LaunchTrail.debugReset();
    _report = RecordingReport();
    _DraftOnboardingController.saveCalls = 0;
  });

  /// The real router on `/auth/post-onboarding`, with A's profile as
  /// [existingA] (null: A has no profile yet).
  Future<({GoRouter router, ProviderContainer container})> pumpPostOnboarding(
    WidgetTester tester, {
    required UserProfile? existingA,
    bool anonymous = false,
    String location = '/auth/post-onboarding',
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final goTrue = _goTrue(anonymous: anonymous);
    final functions = _MockFunctions();
    when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenAnswer((_) async => FunctionResponse(status: 200));
    final client = _MockSupabase();
    when(() => client.auth).thenReturn(goTrue);
    when(() => client.functions).thenReturn(functions);

    final analytics = MockAnalyticsTracker();
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    final migration = _MockMigration();
    when(
      () => migration.completeAuthentication(
        previousUserId: any(named: 'previousUserId'),
        wasAnonymous: any(named: 'wasAnonymous'),
        newUserId: any(named: 'newUserId'),
        authProvider: any(named: 'authProvider'),
        preservedUserId: any(named: 'preservedUserId'),
      ),
    ).thenAnswer((_) async => false);

    final authService = _MockAuthService();
    when(() => authService.getCurrentUser()).thenAnswer((_) async => existingA);

    final db = AppDatabase.memory();
    addTearDown(db.close);

    final container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: client,
            sharedPreferences: _prefs,
            report: _report,
          ),
        ),
        analyticsTrackerProvider.overrideWithValue(analytics),
        reportProvider.overrideWithValue(_report),
        sharedPreferencesProvider.overrideWithValue(_prefs),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        contentServiceProvider.overrideWith(testContentService),
        inMemoryDatabaseOverride(db),
        authMigrationServiceProvider.overrideWith((ref) async => migration),
        authServiceProvider.overrideWithValue(authService),
        syncCoordinatorProvider.overrideWith(_NoopSyncCoordinator.new),
        onboardingControllerProvider.overrideWith(
          _DraftOnboardingController.new,
        ),
        appStartupProvider.overrideWith(_FinishedStartup.new),
        analyticsConsentProvider.overrideWith(_ConsentDecided.new),
      ],
    );
    addTearDown(container.dispose);

    // The athlete's finished onboarding answers, in memory.
    container.read(onboardingControllerProvider.notifier)
      ..updateSports({OnboardingSport.running})
      ..updatePersonalInfo(gender: Gender.female, birthYear: 1990)
      ..updateBodyComposition(weightPounds: 141);
    expect(
      container
          .read(onboardingControllerProvider.notifier)
          .hasCompletedProfileDraft,
      isTrue,
    );

    final router = container.read(AppRouter.routerProvider);
    addTearDown(router.dispose);
    router.go(location);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, __) => MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PostOnboardingAuthScreen), findsOneWidget);
    return (router: router, container: container);
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final finder = find.byKey(ValueKey(key));
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Sign up with Email → Create Account with B → Verify your email.
  Future<void> signUpWithB(WidgetTester tester) async {
    await tapKey(tester, 'post_onboarding.email_button');
    expect(find.byType(EmailSignupScreen), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('signup_email.email_field')),
      _addressB,
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup_email.password_field')),
      'password-b1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup_email.confirm_password_field')),
      'password-b1',
    );
    await tapKey(tester, 'signup_email.create_account_button');
    expect(find.byType(VerifyEmailScreen), findsOneWidget);
  }

  /// Log In (B prefilled) → A's address and password → Log In. Pumps frames
  /// rather than settling: /main's tabs are not under test here.
  Future<void> logInAsA(
    WidgetTester tester, {
    String prefilled = _addressB,
  }) async {
    expect(find.byType(EmailLoginScreen), findsOneWidget);
    final emailField = find.byKey(const ValueKey('login.email_field'));
    expect(
      tester.widget<TextFormField>(emailField).controller?.text,
      prefilled,
    );
    await tester.enterText(emailField, _addressA);
    await tester.enterText(
      find.byKey(const ValueKey('login.password_field')),
      'password-a1',
    );
    final logIn = find.byKey(const ValueKey('login.log_in_button'));
    await tester.ensureVisible(logIn);
    await tester.tap(logIn);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  String path(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.path;

  void expectLandedOnMain(GoRouter router) {
    expect(path(router), '/main');
    expect(find.byType(EmailSignupScreen), findsNothing);
    expect(find.byType(VerifyEmailScreen), findsNothing);
    expect(find.byType(EmailLoginScreen), findsNothing);
    expect(find.byType(PostOnboardingAuthScreen), findsNothing);
    expect(router.canPop(), isFalse);
  }

  /// Unmounts /main so its timers go with it, inside the test body.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('A already set up: Verify → Log in as A lands on /main, A\'s '
      'settings win and say so', (tester) async {
    final w = await pumpPostOnboarding(
      tester,
      existingA: UserFixtures.completedUser(id: _uidA),
    );

    await signUpWithB(tester);
    await tapKey(tester, 'auth.verify_log_in');
    await logInAsA(tester);

    expectLandedOnMain(w.router);
    expect(_DraftOnboardingController.saveCalls, 0);
    expect(find.textContaining('existing account'), findsOneWidget);
    expect(w.container.read(pendingSignupStoreProvider).isOpen, isFalse);
    expect(_prefs.getString(PendingSignupStore.prefsKey), isNull);
    await leave(tester);
  });

  testWidgets('A has no profile: Verify → Log in as A saves the draft onto A '
      'and lands on /main', (tester) async {
    final w = await pumpPostOnboarding(tester, existingA: null);

    await signUpWithB(tester);
    await tapKey(tester, 'auth.verify_log_in');
    await logInAsA(tester);

    expectLandedOnMain(w.router);
    expect(_DraftOnboardingController.saveCalls, 1);
    expect(w.container.read(pendingSignupStoreProvider).isOpen, isFalse);
    expect(_prefs.getString(PendingSignupStore.prefsKey), isNull);
    await leave(tester);
  });

  testWidgets('the upgrade path (anonymous session, emailChange): Verify → '
      'Log in as A lands on /main with the draft policy', (tester) async {
    final w = await pumpPostOnboarding(
      tester,
      existingA: UserFixtures.completedUser(id: _uidA),
      anonymous: true,
    );

    await signUpWithB(tester);
    expect(
      tester.widget<VerifyEmailScreen>(find.byType(VerifyEmailScreen)).otpType,
      OtpType.emailChange,
    );
    await tapKey(tester, 'auth.verify_log_in');
    await logInAsA(tester);

    expectLandedOnMain(w.router);
    expect(_DraftOnboardingController.saveCalls, 0);
    expect(find.textContaining('existing account'), findsOneWidget);
    expect(_prefs.getString(PendingSignupStore.prefsKey), isNull);
    await leave(tester);
  });

  testWidgets('Log In of an unconfirmed address → Verify → Log in leaves '
      'exactly one Log In screen, the address still filled', (tester) async {
    final w = await pumpPostOnboarding(
      tester,
      existingA: null,
      location: '/auth/post-onboarding?mode=login',
    );
    final goTrue = w.container
        .read(appExternalDepsProvider)
        .supabaseClient
        .auth;
    when(
      () => goTrue.signInWithPassword(
        email: any(named: 'email'),
        password: any(named: 'password'),
        captchaToken: any(named: 'captchaToken'),
      ),
    ).thenThrow(
      AuthApiException(
        'Email not confirmed',
        statusCode: '400',
        code: 'email_not_confirmed',
      ),
    );
    when(
      () => goTrue.resend(
        type: any(named: 'type'),
        email: any(named: 'email'),
        emailRedirectTo: any(named: 'emailRedirectTo'),
        captchaToken: any(named: 'captchaToken'),
      ),
    ).thenAnswer((_) async => ResendResponse());

    await tapKey(tester, 'login_options.email_button');
    await tester.enterText(
      find.byKey(const ValueKey('login.email_field')),
      _addressA,
    );
    await tester.enterText(
      find.byKey(const ValueKey('login.password_field')),
      'password-a1',
    );
    await tapKey(tester, 'login.log_in_button');
    expect(find.byType(VerifyEmailScreen), findsOneWidget);

    await tapKey(tester, 'auth.verify_log_in');

    expect(find.byType(VerifyEmailScreen), findsNothing);
    expect(find.byType(EmailLoginScreen), findsOneWidget);
    final emailField = find.byKey(const ValueKey('login.email_field'));
    expect(
      tester.widget<TextFormField>(emailField).controller?.text,
      _addressA,
    );
    // One pop from Log In goes back to the login options, not to a second
    // Log In.
    w.router.pop();
    await tester.pumpAndSettle();
    expect(find.byType(EmailLoginScreen), findsNothing);
    expect(find.byType(PostOnboardingAuthScreen), findsOneWidget);
  });

  testWidgets('Log in left without signing in: back on the Sign Up form', (
    tester,
  ) async {
    await pumpPostOnboarding(tester, existingA: null);

    await signUpWithB(tester);
    await tapKey(tester, 'auth.verify_log_in');
    expect(find.byType(EmailLoginScreen), findsOneWidget);
    await tapKey(tester, 'login.back_button');

    expect(find.byType(EmailLoginScreen), findsNothing);
    expect(find.byType(EmailSignupScreen), findsOneWidget);
    expect(_DraftOnboardingController.saveCalls, 0);
  });

  testWidgets('Sign Up\'s account-exists dialog → Sign In → a login lands on '
      '/main', (tester) async {
    final w = await pumpPostOnboarding(
      tester,
      existingA: UserFixtures.completedUser(id: _uidA),
    );
    // GoTrue refuses B as an existing account this time.
    final goTrue = w.container
        .read(appExternalDepsProvider)
        .supabaseClient
        .auth;
    when(
      () => goTrue.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        emailRedirectTo: any(named: 'emailRedirectTo'),
        data: any(named: 'data'),
        captchaToken: any(named: 'captchaToken'),
      ),
    ).thenThrow(
      AuthApiException(
        'User already registered',
        statusCode: '422',
        code: 'user_already_exists',
      ),
    );

    await tapKey(tester, 'post_onboarding.email_button');
    await tester.enterText(
      find.byKey(const ValueKey('signup_email.email_field')),
      _addressB,
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup_email.password_field')),
      'password-b1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup_email.confirm_password_field')),
      'password-b1',
    );
    await tapKey(tester, 'signup_email.create_account_button');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    await logInAsA(tester, prefilled: '');

    expectLandedOnMain(w.router);
    expect(_DraftOnboardingController.saveCalls, 0);
    await leave(tester);
  });
}
