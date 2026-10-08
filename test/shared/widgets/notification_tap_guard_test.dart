// A notification tap after an in-session login routes at once; a tap held
// across a session change is dropped (round develop-2026-10, ticket 59,
// Finding 50-001).
//
// The root widget used to decide routability from a launch-time "no user"
// that nothing refreshed, so after an in-session login every backgrounded
// tap was HELD and never released. The guard now asks the router's own
// `rootRedirect` on the live startup snapshot (kept live by ticket 56) plus
// the live session. Lee's ruling (2026-10-08): a held tap is replayed only
// when its reason clears in the SAME session; a sign-in or sign-out drops it.
//
// Three layers: the pure guard, the held-tap bookkeeping (no widget pumped),
// and a seam through the real `AppStartup` notifier and its
// `refreshSession`, wired the way the root widget wires its listener.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/app_startup/application/app_startup_provider.dart';
import 'package:mealvana_endurance/features/app_startup/application/app_startup_service.dart';
import 'package:mealvana_endurance/features/auth/domain/pending_signup.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/models/version_check_result.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/services/notification_intent_routes.dart';
import 'package:mealvana_endurance/shared/services/privacy/analytics_consent.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region.dart';
import 'package:mealvana_endurance/shared/services/privacy/privacy_region_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/version_check_service.dart';
import 'package:mealvana_endurance/shared/widgets/root_app_widget.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart' show mockSharedPreferences;

const _athleteId = 'a7b1e2c3-0000-4000-8000-000000000059';
const _otherId = 'b8c2f3d4-0000-4000-8000-000000000059';
const _activityId = '3a7e3fdb-754c-812c-85f2-eb86d213c859';

/// The athlete's `users` row as PostgREST returns it.
Map<String, dynamic> _serverRow({required bool onboarded}) => {
  'id': _athleteId,
  'device_id': 'device-59',
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

UserProfile _profile({required bool onboarded}) => UserProfile.fromSupabaseRow(
  _serverRow(onboarded: onboarded),
  fallbackId: _athleteId,
);

/// What the launch path builds after a signed-out launch (50-001's state).
const _signedOutLaunch = AppStartupData(
  user: null,
  hasCompletedOnboarding: false,
);

/// The same snapshot after ticket 56's refresh on an in-session login.
AppStartupData _afterLogin() => _signedOutLaunch.copyWith(
  user: () => _profile(onboarded: true),
  hasCompletedOnboarding: true,
  isLoggedOut: false,
);

String? _reason(
  AsyncValue<AppStartupData> startup, {
  bool hasSession = true,
  bool pendingSignupOpen = false,
  bool needsConsentPrompt = false,
}) => notificationTapHoldReason(
  startup,
  hasSession: hasSession,
  pendingSignupOpen: () => pendingSignupOpen,
  needsConsentPrompt: () => needsConsentPrompt,
);

List<RecordedReport> _pushCrumbs(RecordingReport r) => r.calls
    .where((c) => c.severity == 'breadcrumb' && c.area == 'push')
    .toList();

void main() {
  setUp(LaunchTrail.debugReset);
  tearDown(LaunchTrail.debugReset);

  group('notificationTapHoldReason / notificationTapRoutable', () {
    test('50-001: the signed-out launch snapshot is not routable even with a '
        'session (the state before ticket 56)', () {
      expect(_reason(const AsyncData(_signedOutLaunch)), '/welcome');
      expect(
        notificationTapRoutable(
          const AsyncData(_signedOutLaunch),
          hasSession: true,
          pendingSignupOpen: () => false,
          needsConsentPrompt: () => false,
        ),
        isFalse,
      );
    });

    test(
      'the same snapshot refreshed after an in-session login is routable',
      () {
        expect(_reason(AsyncData(_afterLogin())), isNull);
        expect(
          notificationTapRoutable(
            AsyncData(_afterLogin()),
            hasSession: true,
            pendingSignupOpen: () => false,
            needsConsentPrompt: () => false,
          ),
          isTrue,
        );
      },
    );

    test('no live session is never routable', () {
      expect(
        _reason(AsyncData(_afterLogin()), hasSession: false),
        'no session',
      );
    });

    test('not onboarded, logged out and a failed resync answer /welcome', () {
      final notOnboarded = _signedOutLaunch.copyWith(
        user: () => _profile(onboarded: false),
        hasCompletedOnboarding: false,
      );
      expect(_reason(AsyncData(notOnboarded)), '/welcome');
      expect(
        _reason(AsyncData(_afterLogin().copyWith(isLoggedOut: true))),
        '/welcome',
      );
      expect(
        _reason(
          const AsyncData(
            AppStartupData(
              user: null,
              hasCompletedOnboarding: false,
              resyncRequired: true,
            ),
          ),
        ),
        '/welcome',
      );
    });

    test('force upgrade answers /force-upgrade', () {
      expect(
        _reason(
          const AsyncData(
            AppStartupData(
              user: null,
              hasCompletedOnboarding: false,
              forceUpgradeRequired: true,
            ),
          ),
        ),
        '/force-upgrade',
      );
    });

    test('an open pending signup answers the verify resume', () {
      final logged = _afterLogin();
      final withPending = AppStartupData(
        user: logged.user,
        hasCompletedOnboarding: true,
        pendingSignup: PendingSignup(
          email: 'athlete@example.com',
          otpType: PendingSignup.otpSignup,
          codeSentAt: DateTime.utc(2026, 10, 8, 9),
        ),
      );
      expect(
        _reason(AsyncData(withPending), pendingSignupOpen: true),
        '/auth/post-onboarding?resume=verify',
      );
      expect(_reason(AsyncData(withPending)), isNull);
    });

    test('a pending consent prompt answers /privacy-consent', () {
      expect(
        _reason(AsyncData(_afterLogin()), needsConsentPrompt: true),
        '/privacy-consent',
      );
    });

    test('startup loading and failed are not routable', () {
      expect(_reason(const AsyncLoading<AppStartupData>()), 'startup loading');
      expect(
        _reason(AsyncError<AppStartupData>('boom', StackTrace.empty)),
        'startup failed',
      );
    });
  });

  group('HeldNotificationTap', () {
    late RecordingReport report;
    late HeldNotificationTap held;

    NotificationTapGate gate(String? reason, String? user) =>
        (holdReason: reason, sessionUserId: user);

    setUp(() {
      report = RecordingReport();
      held = HeldNotificationTap(report);
    });

    void expectWritten(String line) {
      expect(LaunchTrail.text, contains(line));
      expect(_pushCrumbs(report).map((c) => c.message), contains(line));
    }

    test('hold, still not routable: still held, nothing routed', () {
      held.hold(
        _activityId,
        'reminder',
        reason: 'startup loading',
        sessionUserId: _athleteId,
      );
      expectWritten('HELD id=$_activityId type=reminder (startup loading)');
      final crumb = _pushCrumbs(report).single;
      expect(crumb.data, {'id': _activityId, 'type': 'reminder'});

      expect(held.takeIfRoutable(gate('startup loading', _athleteId)), isNull);
      expect(held.heldId, _activityId);
      expect(_pushCrumbs(report), hasLength(1));
    });

    // The reasons a tap is REPLAYED for: they clear without a session change.
    for (final reason in [
      'startup loading',
      'startup failed',
      '/privacy-consent',
      '/welcome',
      '/auth/post-onboarding?resume=verify',
    ]) {
      test('REPLAY: held for "$reason", cleared in the same session', () {
        held.hold(
          _activityId,
          'reminder',
          reason: reason,
          sessionUserId: _athleteId,
        );
        final tap = held.takeIfRoutable(gate(null, _athleteId));

        expect(tap, (id: _activityId, type: 'reminder'));
        expect(held.isHeld, isFalse);
        expectWritten('REPLAY id=$_activityId type=reminder');
        // Once: a second check finds nothing.
        expect(held.takeIfRoutable(gate(null, _athleteId)), isNull);
        expect(
          LaunchTrail.text.split('\n').where((l) => l.contains('REPLAY')),
          hasLength(1),
        );
      });
    }

    test('DROP: held with no session, then a sign-in (50-001 with the '
        'ruling): dropped, never replayed', () {
      held.hold(
        _activityId,
        'reminder',
        reason: 'no session',
        sessionUserId: null,
      );
      expect(held.takeIfRoutable(gate(null, _athleteId)), isNull);
      expect(held.isHeld, isFalse);
      expectWritten(
        'DROPPED id=$_activityId type=reminder (session changed: signed in)',
      );
      expect(LaunchTrail.text, isNot(contains('REPLAY')));
    });

    test('DROP: held signed in (consent pending), then a sign-out', () {
      held.hold(
        _activityId,
        'reminder',
        reason: '/privacy-consent',
        sessionUserId: _athleteId,
      );
      expect(held.takeIfRoutable(gate('no session', null)), isNull);
      expect(held.isHeld, isFalse);
      expectWritten(
        'DROPPED id=$_activityId type=reminder (session changed: signed out)',
      );
    });

    test('DROP: held under one account, another account signs in', () {
      held.hold(
        _activityId,
        'reminder',
        reason: '/welcome',
        sessionUserId: _athleteId,
      );
      expect(held.takeIfRoutable(gate(null, _otherId)), isNull);
      expectWritten(
        'DROPPED id=$_activityId type=reminder (session changed: account '
        'changed)',
      );
    });

    test('a second hold replaces the first with one DROPPED line and one '
        'breadcrumb; the newest is kept', () {
      held.hold('old', 'reminder', reason: 'no session', sessionUserId: null);
      report.calls.clear();
      held.hold('new', 'activity', reason: 'no session', sessionUserId: null);

      expect(held.heldId, 'new');
      final dropped = _pushCrumbs(
        report,
      ).where((c) => c.message!.startsWith('DROPPED')).toList();
      expect(dropped, hasLength(1));
      expect(dropped.single.message, 'DROPPED id=old (replaced by id=new)');
      expect(dropped.single.data, {'id': 'old', 'type': 'reminder'});
      expect(LaunchTrail.text, contains('DROPPED id=old (replaced by id=new)'));
    });

    test('a newer tap that routes at once supersedes a held one', () {
      held.hold('old', 'reminder', reason: 'no session', sessionUserId: null);
      held.dropReplacedBy('new');
      expect(held.isHeld, isFalse);
      expectWritten('DROPPED id=old (replaced by id=new)');
    });

    test('dispose with a held tap writes DROPPED', () {
      held.hold(
        _activityId,
        null,
        reason: 'startup loading',
        sessionUserId: _athleteId,
      );
      held.dropOnDispose();
      expect(held.isHeld, isFalse);
      expectWritten(
        'DROPPED id=$_activityId type=null (root disposed while held)',
      );
    });

    test('dispose with nothing held writes nothing', () {
      held.dropOnDispose();
      expect(report.calls, isEmpty);
      expect(LaunchTrail.isEmpty, isTrue);
    });

    test('the empty-id and unmounted paths write DROPPED', () {
      held.dropIncoming('', 'reminder', why: 'empty id');
      held.dropIncoming(_activityId, 'reminder', why: 'root unmounted');
      expectWritten('DROPPED id= type=reminder (empty id)');
      expectWritten('DROPPED id=$_activityId type=reminder (root unmounted)');
      expect(held.isHeld, isFalse);
    });
  });

  group('seam: the real AppStartup and refreshSession', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'a tap held while signed out is DROPPED when the in-session login '
      'refreshes the snapshot; a tap after the login routes at once',
      () async {
        final h = _Harness();
        addTearDown(h.dispose);
        await h.launch();

        // A backgrounded tap collected while signed out: held.
        h.tap(_activityId, 'reminder');
        expect(h.held.heldId, _activityId);
        expect(LaunchTrail.text, contains('(no session)'));

        // The athlete logs in in-session; the auth listener refreshes startup.
        h.session = _FakeSession(_athleteId);
        await _seed(h.db, onboarded: true);
        await h.notifier.refreshSession(reason: 'signed_in');

        expect(h.routed, isEmpty);
        expect(h.held.isHeld, isFalse);
        expect(
          LaunchTrail.text,
          contains(
            'DROPPED id=$_activityId type=reminder (session changed: signed in)',
          ),
        );

        // The next tap reads the live snapshot and routes without being held.
        h.tap(_activityId, 'reminder');
        expect(h.routed, hasLength(1));
        expect(
          h.routed.single.location,
          destinationForIntent('reminder', _activityId).location,
        );
        expect(
          LaunchTrail.text.split('\n').where((l) => l.contains('HELD')),
          hasLength(1),
        );
      },
    );

    test('a cold-start tap held while startup loads, with the restored '
        'session, is REPLAYED once when startup resolves', () async {
      final h = _Harness();
      addTearDown(h.dispose);
      h.session = _FakeSession(_athleteId);
      await _seed(h.db, onboarded: true);
      // Startup is held at the version check.
      final pending = h.container.read(appStartupProvider.future);

      h.tap(_activityId, 'reminder');
      expect(LaunchTrail.text, contains('(startup loading)'));

      h.versionGate.complete(const VersionCheckResult.ok());
      await pending;
      await Future<void>.delayed(Duration.zero);

      expect(h.routed, hasLength(1));
      expect(
        h.routed.single.location,
        destinationForIntent('reminder', _activityId).location,
      );
      expect(LaunchTrail.text, contains('REPLAY id=$_activityId'));

      // A later refresh in the same session finds nothing held.
      await h.notifier.refreshSession(reason: 'onboarding_saved');
      expect(h.routed, hasLength(1));
    });

    test('a tap held signed in is DROPPED on an in-session sign-out', () async {
      final h = _Harness(consent: _ConsentOwed.new);
      addTearDown(h.dispose);
      h.session = _FakeSession(_athleteId);
      await _seed(h.db, onboarded: true);
      await h.launch();

      h.tap(_activityId, 'reminder');
      expect(LaunchTrail.text, contains('(/privacy-consent)'));

      h.session = null;
      await h.notifier.refreshSession(reason: 'signed_out');

      expect(h.routed, isEmpty);
      expect(
        LaunchTrail.text,
        contains(
          'DROPPED id=$_activityId type=reminder (session changed: signed out)',
        ),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Seam harness: the real AppStartup with its services mocked, as in
// test/features/app_startup/startup_snapshot_refresh_test.dart (ticket 56).

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

class _ConsentDecided extends AnalyticsConsentNotifier {
  @override
  AnalyticsConsent build() => const AnalyticsConsent(
    status: ConsentStatus.granted,
    regime: ConsentRegime.standard,
    source: RegionSource.geo,
  );
}

/// A strict-region athlete onboarded before the prompt existed.
class _ConsentOwed extends AnalyticsConsentNotifier {
  @override
  AnalyticsConsent build() => const AnalyticsConsent(
    status: ConsentStatus.unknown,
    regime: ConsentRegime.strict,
    source: RegionSource.geo,
  );
}

Future<void> _seed(AppDatabase db, {required bool onboarded}) =>
    db.userDao.saveUserProfile(_profile(onboarded: onboarded));

class _Harness {
  _Harness({
    AnalyticsConsentNotifier Function() consent = _ConsentDecided.new,
  }) {
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
        mockSharedPreferences(),
        analyticsConsentProvider.overrideWith(consent),
      ],
    );
    held = HeldNotificationTap(report);
    // Wired the way RootAppWidget.build wires it: every snapshot change
    // re-checks the held tap.
    holder = container.listen<AsyncValue<AppStartupData>>(
      appStartupProvider,
      (_, __) => _release(),
    );
  }

  late final AppDatabase db;
  late final ProviderContainer container;
  late final ProviderSubscription<AsyncValue<AppStartupData>> holder;
  late final HeldNotificationTap held;
  final report = RecordingReport();
  final versionGate = Completer<VersionCheckResult>();
  final routed = <NotificationDestination>[];
  Session? session;

  AppStartup get notifier => container.read(appStartupProvider.notifier);

  Future<AppStartupData> launch() {
    if (!versionGate.isCompleted) {
      versionGate.complete(const VersionCheckResult.ok());
    }
    return container.read(appStartupProvider.future);
  }

  /// The root widget's tap handler, minus the navigation itself.
  void tap(String id, String? type) {
    final gate = notificationTapGate(container.read);
    final reason = gate.holdReason;
    if (reason != null) {
      held.hold(id, type, reason: reason, sessionUserId: gate.sessionUserId);
      return;
    }
    held.dropReplacedBy(id);
    routed.add(destinationForIntent(type, id));
  }

  void _release() {
    if (!held.isHeld) return;
    final tap = held.takeIfRoutable(notificationTapGate(container.read));
    if (tap != null) this.tap(tap.id, tap.type);
  }

  Future<void> dispose() async {
    holder.close();
    container.dispose();
    await db.close();
  }
}
