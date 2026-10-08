// The startup snapshot follows an in-session auth change (round
// develop-2026-10, ticket 56: Findings 49-001, 50-005).
//
// `AppStartup.build` used to be the only reader of the session, so a login in
// the same session left the launch-time "no user" in place and every later
// go('/') landed on Welcome. These tests drive the REAL notifier: startup is
// resolved through `build` with its services mocked, the local profile is
// seeded as the server row would arrive (`UserProfile.fromSupabaseRow`, the
// download mapping), and `refreshSession` is called the way the auth listener
// calls it.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/app_startup/application/app_startup_provider.dart';
import 'package:mealvana_endurance/features/app_startup/application/app_startup_service.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/shared/core/app_router.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/models/version_check_result.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/services/privacy/analytics_consent.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/version_check_service.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/test_content.dart';
import '../../helpers/widget_test_harness.dart' show mockSharedPreferences;

class _MockVersionCheck extends Mock implements VersionCheckService {}

class _MockStartupService extends Mock implements AppStartupService {}

class _MockRegion extends Mock implements PrivacyRegionService {}

class _MockAnalytics extends Mock implements AnalyticsTracker {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _FakeUser extends Fake implements User {
  _FakeUser(this.id);
  @override
  final String id;
}

class _FakeSession extends Fake implements Session {
  _FakeSession(String userId) : user = _FakeUser(userId);
  @override
  final User user;
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

const _athleteId = 'a7b1e2c3-0000-4000-8000-000000000056';

/// The athlete's `users` row as PostgREST returns it.
Map<String, dynamic> _serverRow({required bool onboarded}) => {
  'id': _athleteId,
  'device_id': 'device-56',
  'auth_user_id': _athleteId,
  'auth_provider': 'email',
  'is_anonymous': false,
  'gender': 'female',
  'birthday': '1990-01-01',
  'height_feet': 5,
  'height_inches': 6,
  'weight_pounds': 140.5,
  'runs_with_water_bottle': true,
  'onboarding_completed': onboarded,
  'app_version': '1.30.0',
  'created_at': '2026-10-01T09:00:00.000000+00:00',
  'updated_at': '2026-10-08T09:00:00.000000+00:00',
};

Future<void> _seedFromServer(AppDatabase db, {required bool onboarded}) =>
    db.userDao.saveUserProfile(
      UserProfile.fromSupabaseRow(
        _serverRow(onboarded: onboarded),
        fallbackId: _athleteId,
      ),
    );

class _Harness {
  _Harness({Future<String> Function(Ref ref)? userId}) {
    db = AppDatabase.memory();
    final auth = MockGoTrueClient();
    when(() => auth.currentSession).thenAnswer((_) => session);
    when(() => auth.currentUser).thenAnswer((_) => session?.user);
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());

    final version = _MockVersionCheck();
    when(version.checkVersion).thenAnswer((_) => versionGate.future);
    final startup = _MockStartupService();
    when(startup.endAbandonedRecovery).thenAnswer((_) async {});
    when(startup.pendingSignupAtLaunch).thenAnswer((_) async => null);
    when(startup.initializeDatabase).thenAnswer((_) async {});
    when(startup.setSentryUserContext).thenAnswer((_) async {});
    when(startup.initializeDeferredServices).thenAnswer((_) async {});
    final region = _MockRegion();
    when(region.ensureResolved).thenAnswer((_) async {});
    final analytics = _MockAnalytics();
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: fakeSupabaseClient(auth: auth),
            sharedPreferences: _MockPrefs(),
            report: report,
          ),
        ),
        reportProvider.overrideWithValue(report),
        appDatabaseProvider.overrideWithValue(db),
        versionCheckServiceProvider.overrideWithValue(version),
        appStartupServiceProvider.overrideWithValue(startup),
        privacyRegionServiceProvider.overrideWithValue(region),
        if (userId != null) userIdProvider.overrideWith(userId),
        // Router-only reads.
        mockSharedPreferences(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        contentServiceProvider.overrideWith(testContentService),
        analyticsConsentProvider.overrideWith(_ConsentDecided.new),
      ],
    );
    // Held the way AppStartupWidget holds it in the app, recording every
    // state it passes through.
    holder = container.listen<AsyncValue<AppStartupData>>(
      appStartupProvider,
      (_, next) => states.add(next),
    );
  }

  late final AppDatabase db;
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<AppStartupData>> holder;
  final report = RecordingReport();
  final states = <AsyncValue<AppStartupData>>[];
  final versionGate = Completer<VersionCheckResult>();
  Session? session;

  AppStartup get notifier => container.read(appStartupProvider.notifier);
  AppStartupData get data => container.read(appStartupProvider).requireValue;

  Future<AppStartupData> launch() {
    if (!versionGate.isCompleted) {
      versionGate.complete(const VersionCheckResult.ok());
    }
    return container.read(appStartupProvider.future);
  }

  List<String> get startupCrumbs => report.calls
      .where((c) => c.severity == 'breadcrumb' && c.area == 'startup')
      .map((c) => c.message!)
      .toList();

  Future<void> dispose() async {
    holder.close();
    container.dispose();
    await db.close();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LaunchTrail.debugReset();
  });

  test('a login in the same session: the snapshot gains the onboarded user, '
      'AsyncData to AsyncData, and the trail says so', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    // Launched signed out on Welcome.
    final atLaunch = await h.launch();
    expect(atLaunch.user, isNull);
    expect(
      AppRouter.rootRedirect(
        atLaunch,
        pendingSignupOpen: () => false,
        needsConsentPrompt: () => false,
      ),
      '/welcome',
    );

    // Logged in by email: the session exists and the profile pull landed.
    h.session = _FakeSession(_athleteId);
    await _seedFromServer(h.db, onboarded: true);
    h.states.clear();

    await h.notifier.refreshSession(reason: 'signed_in');

    expect(h.data.user?.id, _athleteId);
    expect(h.data.hasCompletedOnboarding, isTrue);
    expect(h.data.isLoggedOut, isFalse);
    expect(h.states, hasLength(1));
    expect(h.states.single, isA<AsyncData<AppStartupData>>());
    expect(
      AppRouter.rootRedirect(
        h.data,
        pendingSignupOpen: () => false,
        needsConsentPrompt: () => false,
      ),
      '/main',
    );
    expect(
      LaunchTrail.text,
      contains('startup snapshot refreshed (signed_in): user=true onboarded=true'),
    );
    expect(h.startupCrumbs, contains('Startup snapshot refreshed'));
    expect(h.report.faults, isEmpty);
  });

  test('a fresh login on this device: waits for the profile pull, then reads '
      'it', () async {
    late _Harness h;
    h = _Harness(
      userId: (ref) async {
        // userIdProvider pulls the remote row and saves it locally.
        await _seedFromServer(h.db, onboarded: true);
        return _athleteId;
      },
    );
    addTearDown(h.dispose);
    await h.launch();

    h.session = _FakeSession(_athleteId);
    await h.notifier.refreshSession(reason: 'signed_in');

    expect(h.data.user?.id, _athleteId);
    expect(h.data.hasCompletedOnboarding, isTrue);
  });

  test('sign-out: the snapshot reads logged out, and launch-only fields are '
      'kept', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    h.session = _FakeSession(_athleteId);
    await _seedFromServer(h.db, onboarded: true);
    final atLaunch = await h.launch();
    expect(atLaunch.hasCompletedOnboarding, isTrue);

    h.session = null;
    await h.notifier.refreshSession(reason: 'signed_out');

    expect(h.data.user, isNull);
    expect(h.data.hasCompletedOnboarding, isFalse);
    expect(h.data.forceUpgradeRequired, isFalse);
    expect(h.data.resyncRequired, isFalse);
    expect(
      AppRouter.rootRedirect(
        h.data,
        pendingSignupOpen: () => false,
        needsConsentPrompt: () => false,
      ),
      '/welcome',
    );
    expect(
      LaunchTrail.text,
      contains(
        'startup snapshot refreshed (signed_out): user=false onboarded=false',
      ),
    );
  });

  test('two overlapping refreshes: the later one wins; the earlier one skips '
      'its write and says so', () async {
    final pull = Completer<String>();
    final h = _Harness(userId: (ref) => pull.future);
    addTearDown(h.dispose);
    await h.launch();

    // First refresh: a session with no local profile yet, so it waits on the
    // profile pull.
    h.session = _FakeSession(_athleteId);
    final first = h.notifier.refreshSession(reason: 'signed_in');
    await Future<void>.delayed(Duration.zero);

    // Meanwhile onboarding saves the profile and refreshes.
    await _seedFromServer(h.db, onboarded: true);
    await h.notifier.refreshSession(reason: 'onboarding_saved');
    expect(h.data.hasCompletedOnboarding, isTrue);

    // The first refresh's late read would say "not onboarded".
    await _seedFromServer(h.db, onboarded: false);
    pull.complete(_athleteId);
    await first;

    expect(h.data.hasCompletedOnboarding, isTrue);
    expect(
      LaunchTrail.text,
      contains(
        'startup snapshot refresh skipped (signed_in): '
        'superseded by a later refresh or rebuild',
      ),
    );
  });

  test('the session user changes during the refresh: no write', () async {
    final pull = Completer<String>();
    final h = _Harness(userId: (ref) => pull.future);
    addTearDown(h.dispose);
    await h.launch();

    h.session = _FakeSession(_athleteId);
    final refresh = h.notifier.refreshSession(reason: 'signed_in');
    await Future<void>.delayed(Duration.zero);
    h.session = null;
    pull.complete(_athleteId);
    await refresh;

    expect(h.data.user, isNull);
    expect(
      LaunchTrail.text,
      contains('session user changed during refresh'),
    );
  });

  test('startup still loading: the refresh skips and writes it down', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    // Startup is held at the version check.
    final pending = h.container.read(appStartupProvider.future);

    h.session = _FakeSession(_athleteId);
    await h.notifier.refreshSession(reason: 'signed_in');

    expect(
      LaunchTrail.text,
      contains('startup snapshot refresh skipped (signed_in): '
          'startup has no data yet'),
    );
    expect(
      h.startupCrumbs,
      contains('Startup snapshot refresh skipped: startup has no data yet'),
    );

    // build reads the same session itself.
    await _seedFromServer(h.db, onboarded: true);
    h.versionGate.complete(const VersionCheckResult.ok());
    final data = await pending;
    expect(data.hasCompletedOnboarding, isTrue);
  });

  test('a failed read is reported and the old snapshot kept, never an error '
      'state (#118)', () async {
    final h = _Harness(
      userId: (ref) async => throw StateError('profile pull exploded'),
    );
    addTearDown(h.dispose);
    final atLaunch = await h.launch();
    h.states.clear();

    h.session = _FakeSession(_athleteId);
    await h.notifier.refreshSession(reason: 'signed_in');

    expect(h.states, isEmpty);
    expect(identical(h.data, atLaunch), isTrue);
    expect(h.report.faults, hasLength(1));
    expect(h.report.faults.single.area, 'startup');
    expect(
      LaunchTrail.text,
      contains('read failed, old snapshot kept'),
    );
  });

  test('refreshStartupSnapshot does not start a startup nobody holds', () async {
    final report = RecordingReport();
    final container = ProviderContainer(
      overrides: [reportProvider.overrideWithValue(report)],
    );
    addTearDown(container.dispose);
    final probe = Provider<Future<void>>(
      (ref) => refreshStartupSnapshot(ref, reason: 'signed_in'),
    );

    await container.read(probe);

    expect(container.exists(appStartupProvider), isFalse);
    expect(
      report.calls.map((c) => c.message),
      contains('Startup snapshot refresh skipped: startup provider not alive'),
    );
  });

  testWidgets('after the in-session login, go(\'/\') on the real router lands '
      'on /main', (tester) async {
    final h = _Harness();
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.runAsync(() async {
      await h.launch();
      h.session = _FakeSession(_athleteId);
      await _seedFromServer(h.db, onboarded: true);
      await h.notifier.refreshSession(reason: 'signed_in');
    });

    final router = h.container.read(AppRouter.routerProvider);
    addTearDown(router.dispose);
    router.go('/');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/main');
    await tester.pumpWidget(const SizedBox());
    // Riverpod schedules auto-dispose work on a zero-length timer; let it run
    // inside the test body (#110).
    await tester.pump(const Duration(milliseconds: 1));
  });
}
