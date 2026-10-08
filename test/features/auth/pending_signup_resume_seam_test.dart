/// A pending signup survives a relaunch (develop-2026-10 ticket 42, 30-007).
///
/// Seam: GoTrue's own answers as gotrue 2.16 parses them (`UserResponse` /
/// `AuthResponse.fromJson` over run 30's shapes: the anonymous uid, the
/// address parked in `new_email`), never the app's mapped types. The first
/// container is the launch where Create Account sent the code; it is thrown
/// away, and a fresh container over the same SharedPreferences and secure
/// storage is the relaunch: the real `AppStartup.build`, the real root
/// redirect decision, the real controllers.
library;


import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/app_startup/application/app_startup_provider.dart';
import 'package:mealvana_endurance/features/app_startup/application/app_startup_service.dart';
import 'package:mealvana_endurance/features/auth/application/auth_migration_service.dart';
import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/data/pending_signup_store.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/domain/pending_signup.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_signup_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/models/version_check_result.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/version_check_service.dart';

import '../../helpers/fakes/recording_report.dart';
import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockVersionCheck extends Mock implements VersionCheckService {}

class _MockRegion extends Mock implements PrivacyRegionService {}

class _MockMigration extends Mock implements AuthMigrationService {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

/// The startup service with the steps that need a device (database open,
/// Sentry identity, deferred services) quiet. The recovery check and the
/// pending-signup check are the real ones.
class _QuietStartupService extends AppStartupService {
  _QuietStartupService(super.ref);

  @override
  Future<void> initializeDatabase() async {}

  @override
  Future<void> setSentryUserContext() async {}

  @override
  Future<void> initializeDeferredServices() async {}
}

/// Run 30's anonymous uid (Welcome → Build My Plan).
const _anonUid = '1ffc8851-0000-4000-8000-000000000030';
const _email = 'athlete@example.com';
const _password = 'secret-pw1';

Map<String, dynamic> _userJson({
  String id = _anonUid,
  bool anonymous = true,
  String email = '',
  String? newEmail,
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

/// GoTrue with run 30's anonymous session restored from storage.
_MockGoTrue _goTrue({String uid = _anonUid}) {
  final goTrue = _MockGoTrue();
  final user = User.fromJson(_userJson(id: uid))!;
  when(() => goTrue.currentUser).thenReturn(user);
  when(
    () => goTrue.currentSession,
  ).thenReturn(Session.fromJson(_sessionJson(_userJson(id: uid))));
  return goTrue;
}

late SharedPreferences _prefs;
late RecordingReport _report;

MockAnalyticsTracker _analytics() {
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  return analytics;
}

List<Override> _deps(GoTrueClient goTrue) {
  final client = _MockSupabase();
  when(() => client.auth).thenReturn(goTrue);
  final analytics = _analytics();
  return [
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
  ];
}

/// A launch: the real [AppStartup.build] over [goTrue] and the shared
/// stores. The caller disposes it.
ProviderContainer _launch(GoTrueClient goTrue) {
  final versionCheck = _MockVersionCheck();
  when(
    () => versionCheck.checkVersion(),
  ).thenAnswer((_) async => const VersionCheckResult.ok());
  final region = _MockRegion();
  when(() => region.ensureResolved()).thenAnswer((_) async {});
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  return ProviderContainer(
    overrides: [
      ..._deps(goTrue),
      versionCheckServiceProvider.overrideWithValue(versionCheck),
      privacyRegionServiceProvider.overrideWithValue(region),
      appDatabaseProvider.overrideWithValue(database),
      appStartupServiceProvider.overrideWith(_QuietStartupService.new),
    ],
  );
}

String? _rootRedirect(ProviderContainer c, AppStartupData data) =>
    AppRouter.rootRedirect(
      data,
      pendingSignupOpen: () => c.read(pendingSignupStoreProvider).isOpen,
      needsConsentPrompt: () => false,
    );

/// The first launch: answers given, Create Account on the upgrade path, the
/// code sent. Returns the draft the athlete had.
Future<OnboardingDraft> _sendCodeThenQuit() async {
  final goTrue = _goTrue();
  // GoTrue parks the address in `new_email` and mails the code; the
  // session stays anonymous with the same uid.
  when(
    () => goTrue.updateUser(any()),
  ).thenAnswer((_) async => UserResponse.fromJson(_userJson(newEmail: _email)));
  final first = ProviderContainer(overrides: _deps(goTrue));
  first.listen(postOnboardingAuthControllerProvider, (_, _) {});
  first.read(onboardingControllerProvider.notifier)
    ..updateSports({OnboardingSport.running, OnboardingSport.triathlon})
    ..updateGoals({OnboardingGoal.performance, OnboardingGoal.eatHealthier})
    ..updatePersonalInfo(gender: Gender.female, birthYear: 1990)
    ..updateBodyComposition(weightPounds: 141);
  final draft = first.read(onboardingControllerProvider.notifier).draft;

  final ok = await first
      .read(postOnboardingAuthControllerProvider.notifier)
      .linkEmailAccount(email: _email, password: _password);

  expect(ok, isFalse);
  expect(
    first.read(postOnboardingAuthControllerProvider).error,
    isA<EmailVerificationRequiredException>(),
  );
  // The app is killed on Verify your email.
  first.dispose();
  return draft;
}

Future<String?> _storedPassword() =>
    const FlutterSecureStorage().read(key: PendingSignupStore.passwordKey);

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
  });

  group('the code went out, the app was killed, the app relaunched', () {
    test('Create Account writes the record with the answers before Verify '
        'opens; the password goes to secure storage only', () async {
      await _sendCodeThenQuit();

      final raw = _prefs.getString(PendingSignupStore.prefsKey);
      expect(raw, isNotNull);
      expect(raw, isNot(contains(_password)));
      final lookup = await PendingSignupStore(
        prefs: _prefs,
        report: RecordingReport(),
      ).read();
      final record = lookup.record!;
      expect(record.otpType, PendingSignup.otpEmailChange);
      expect(record.anonymousUserId, _anonUid);
      expect(record.email, _email);
      expect(record.draft['sports'], containsAll(['running', 'triathlon']));
      expect(await _storedPassword(), _password);
    });

    test('the relaunch resumes Verify with the same answers', () async {
      final draftBefore = await _sendCodeThenQuit();

      final relaunch = _launch(_goTrue());
      addTearDown(relaunch.dispose);
      final data = await relaunch.read(appStartupProvider.future);

      expect(data.pendingSignup, isNotNull);
      expect(
        _rootRedirect(relaunch, data),
        '/auth/post-onboarding?resume=verify',
      );
      expect(
        LaunchTrail.text,
        contains('pending signup: resuming verify (emailChange)'),
      );

      // PostOnboardingAuthScreen's resume, through the real controller.
      relaunch.listen(postOnboardingAuthControllerProvider, (_, _) {});
      final controller = relaunch.read(
        postOnboardingAuthControllerProvider.notifier,
      );
      final record = await controller.resumePendingSignup();
      final restored = relaunch.read(onboardingControllerProvider.notifier);

      expect(record?.codeSentAt, data.pendingSignup!.codeSentAt);
      expect(restored.draft.sports, draftBefore.sports);
      expect(restored.draft.goals, draftBefore.goals);
      expect(restored.draft.birthYear, 1990);
      expect(restored.hasCompletedProfileDraft, isTrue);
      expect(await controller.resumedPassword(record!), _password);
    });

    test('a different anonymous session: the record is cleared and the '
        'launch lands on Welcome', () async {
      await _sendCodeThenQuit();

      final relaunch = _launch(_goTrue(uid: 'a-new-anonymous-uid'));
      addTearDown(relaunch.dispose);
      final data = await relaunch.read(appStartupProvider.future);

      expect(data.pendingSignup, isNull);
      expect(_rootRedirect(relaunch, data), '/welcome');
      expect(_prefs.getString(PendingSignupStore.prefsKey), isNull);
      expect(await _storedPassword(), isNull);
    });

    test('a record verified or abandoned since launch is not reopened by a '
        "later go('/')", () async {
      await _sendCodeThenQuit();
      final relaunch = _launch(_goTrue());
      addTearDown(relaunch.dispose);
      final data = await relaunch.read(appStartupProvider.future);

      relaunch.listen(emailAuthServiceProvider, (_, _) {});
      await relaunch
          .read(emailAuthServiceProvider.notifier)
          .abandonPendingSignup(reason: 'different_email');

      expect(data.pendingSignup, isNotNull);
      expect(_rootRedirect(relaunch, data), '/welcome');
    });
  });

  testWidgets('the form reopens Verify from the record; a code sent 70 s '
      'ago shows Resend enabled', (tester) async {
    final sentAt = DateTime.now().toUtc().subtract(const Duration(seconds: 70));
    final record = PendingSignup(
      email: _email,
      otpType: PendingSignup.otpEmailChange,
      codeSentAt: sentAt,
      anonymousUserId: _anonUid,
    );
    FlutterSecureStorage.setMockInitialValues({
      PendingSignupStore.passwordKey: _password,
    });

    await smokeScreen(
      tester,
      EmailSignupScreen(resume: record),
      // This test's own deps (the shared prefs, the session) instead of the
      // harness's mocks.
      withAppDeps: false,
      overrides: [
        ..._deps(_goTrue()),
        sharedPreferencesProvider.overrideWithValue(_prefs),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        contentServiceProvider.overrideWith(testContentService),
      ],
    );

    final verify = tester.widget<VerifyEmailScreen>(
      find.byType(VerifyEmailScreen),
    );
    expect(verify.email, _email);
    expect(verify.otpType, OtpType.emailChange);
    expect(verify.codeSentAt, sentAt.toLocal());
    expect(verify.pendingPassword, _password);
    expect(verify.pendingUserId, isNull);
    final resend = find.byKey(const ValueKey('auth.verify_resend'));
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
  });

  group('the record follows the code', () {
    ({ProviderContainer container, _MockGoTrue goTrue}) wired() {
      final goTrue = _goTrue();
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
      final container = ProviderContainer(
        overrides: [
          ..._deps(goTrue),
          authMigrationServiceProvider.overrideWith((ref) async => migration),
        ],
      );
      addTearDown(container.dispose);
      container.listen(emailAuthServiceProvider, (_, _) {});
      return (container: container, goTrue: goTrue);
    }

    Future<PendingSignupStore> seeded(ProviderContainer c) async {
      final store = c.read(pendingSignupStoreProvider);
      await store.write(
        PendingSignup(
          email: _email,
          otpType: PendingSignup.otpEmailChange,
          codeSentAt: DateTime.utc(2026, 10, 8, 14, 1),
          anonymousUserId: _anonUid,
        ),
        password: _password,
      );
      return store;
    }

    test('a used code clears the record and the password', () async {
      final w = wired();
      final store = await seeded(w.container);
      final confirmed = _userJson(
        anonymous: false,
        email: _email,
        confirmedAt: '2026-10-08T14:03:00Z',
      );
      when(
        () => w.goTrue.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => AuthResponse.fromJson(_sessionJson(confirmed)));
      when(
        () => w.goTrue.updateUser(any()),
      ).thenAnswer((_) async => UserResponse.fromJson(confirmed));

      await w.container
          .read(emailAuthServiceProvider.notifier)
          .verifyEmailOtp(
            email: _email,
            token: '123456',
            type: OtpType.emailChange,
            pendingPassword: _password,
          );

      expect(_prefs.getString(PendingSignupStore.prefsKey), isNull);
      expect(await _storedPassword(), isNull);
      expect(store.isOpen, isFalse);
      expect(
        _report.notes.where((n) => n.data?['reason'] == 'verified'),
        hasLength(1),
      );
    });

    test('Use a different email clears them, and says so', () async {
      final w = wired();
      await seeded(w.container);

      await w.container
          .read(emailAuthServiceProvider.notifier)
          .abandonPendingSignup(reason: 'different_email');

      expect(_prefs.getString(PendingSignupStore.prefsKey), isNull);
      expect(await _storedPassword(), isNull);
      expect(
        _report.notes.where((n) => n.data?['reason'] == 'different_email'),
        hasLength(1),
      );
    });

    test('a Resend that went out moves the send time', () async {
      final w = wired();
      final store = await seeded(w.container);
      when(
        () => w.goTrue.resend(
          type: any(named: 'type'),
          email: any(named: 'email'),
        ),
      ).thenAnswer((_) async => ResendResponse());
      final before = DateTime.now().toUtc();

      await w.container
          .read(emailAuthServiceProvider.notifier)
          .resendVerificationCode(email: _email, type: OtpType.emailChange);

      final moved = (await store.read()).record!;
      expect(moved.codeSentAt.isBefore(before), isFalse);
      // Only the time moved.
      expect(moved.anonymousUserId, _anonUid);
      expect(await _storedPassword(), _password);
    });

    test('the plain path records the new user and no password', () async {
      final goTrue = _MockGoTrue();
      when(() => goTrue.currentUser).thenReturn(null);
      // Confirmation on: GoTrue returns the user and no session.
      when(
        () => goTrue.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => AuthResponse.fromJson(
          _userJson(id: 'new-user-id', anonymous: false, email: _email),
        ),
      );
      final c = ProviderContainer(overrides: _deps(goTrue));
      addTearDown(c.dispose);
      c.listen(postOnboardingAuthControllerProvider, (_, _) {});

      await c
          .read(postOnboardingAuthControllerProvider.notifier)
          .signUpWithEmail(email: _email, password: _password);

      final record = (await c.read(pendingSignupStoreProvider).read()).record!;
      expect(record.otpType, PendingSignup.otpSignup);
      expect(record.pendingUserId, 'new-user-id');
      expect(record.anonymousUserId, isNull);
      expect(await _storedPassword(), isNull);
    });
  });
}
