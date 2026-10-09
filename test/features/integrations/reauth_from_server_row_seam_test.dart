// Ticket 77 (develop-2026-10, Findings 68-008 and 69-010): Reconnect is read
// from the server's integrations row on every device, and a dead Garmin
// token stops the automatic backfill.
//
// Run 68: device A moved the Garmin row to requires_reauth on the server.
// Device B, same account, relaunched six minutes later: no Timeline notice,
// and Connected Apps still offered Sync Now. Its own sync never ran into the
// dead token (Garmin is push-only), the hour-staleness guard skipped the
// integrations pull, and the notice only listened to this device's writes.
// Run 69: every first open of Connected Apps fired garmin-backfill on the dead
// token and reported the 409 as `error_reported` degraded.
//
// Seam: the REAL ReconnectNoticeController, launch pull and Drift watch, the
// REAL ConnectTrainingController, the REAL SyncCoordinator, the REAL
// IntegrationsRepository on in-memory Drift, and the REAL postgrest builder
// against FakePostgrest. The server row is shaped the way PostgREST sends it.
// Only the edge-function wire is a recording MockClient, and connectivity's
// platform channel answers "wifi".
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/reconnect_notice_controller.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/launch_trail.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

const _userId = '00000000-0000-0000-0000-000000000077';
const _skipLine = 'garmin auto backfill skipped: requires_reauth';
const _skipCrumb = 'Garmin auto backfill skipped: integration requires_reauth';

/// The Garmin row as PostgREST sends it.
Map<String, dynamic> _garminRow({
  required String status,
  String? error,
  required String updatedAt,
}) => {
  'id': 'i-garmin',
  'user_id': _userId,
  'provider': 'garmin',
  'access_token': 'garmin-access',
  'refresh_token': 'garmin-refresh',
  'token_expires_at': '2026-10-09T23:38:08.123+00:00',
  'provider_athlete_id': 'garmin-user-1',
  'provider_athlete_name': 'Lee Martin',
  'is_active': true,
  'last_sync_at': '2026-10-08T20:00:00.000+00:00',
  'last_sync_status': status,
  'last_sync_error': error,
  'created_at': '2026-09-01T08:00:00.000+00:00',
  'updated_at': updatedAt,
};

/// Device A's write at 23:38:08Z (run 69).
Map<String, dynamic> _deadTokenRow() => _garminRow(
  status: requiresReauthStatus,
  error: reauthRequiredCode,
  updatedAt: '2026-10-08T23:38:08.123+00:00',
);

/// Device A reconnected Garmin.
Map<String, dynamic> _reconnectedRow() => _garminRow(
  status: 'success',
  updatedAt: '2026-10-08T23:50:00.000+00:00',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePostgrest server;
  late IntegrationsRepository repository;
  late ActivitiesRepository activitiesRepository;
  late SupabaseClient deps;
  late List<http.Request> functionCalls;
  late SharedPreferences prefs;
  late RecordingReport report;

  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUp(() async {
    LaunchTrail.debugReset();
    ConnectTrainingController.debugResetGarminAutoBackfillSkip();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, (call) async => ['wifi']);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(connectivity, null),
    );

    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    addTearDown(db.close);

    server = FakePostgrest();
    server.tables['users'] = [
      {'id': _userId},
    ];
    // Device B signed in while the row was `success`.
    server.tables['integrations'] = [
      _garminRow(
        status: 'success',
        updatedAt: '2026-10-08T22:00:00.000+00:00',
      ),
    ];
    await server.signIn(_userId);

    report = RecordingReport();
    repository = IntegrationsRepository(
      database: db,
      supabase: server.client,
      report: RecordingReport(),
    );
    await repository.syncFromRemote(_userId);
    // The integrations pull stamp is six minutes old: inside the hour, so
    // ensureSynced would skip the pull (run 68 relaunched at 23:44:39Z).
    await repository.setLastSyncTime(
      DateTime.now().subtract(const Duration(minutes: 6)),
    );

    activitiesRepository = ActivitiesRepository(
      supabase: server.client,
      database: db,
      report: RecordingReport(),
      deduplicationService: ActivityDeduplicationService(),
    );

    // The controller's session and edge functions: auth is the server's real
    // signed-in session; functions is a recording wire.
    functionCalls = [];
    final functions = FunctionsClient(
      'https://fake.supabase.co/functions/v1',
      const {},
      httpClient: MockClient((request) async {
        functionCalls.add(request);
        return http.Response(
          '{"success":true,"queued":{"body_composition":202}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(functions.dispose);
    deps = fakeSupabaseClient(auth: server.client.auth);
    when(() => deps.functions).thenReturn(functions);
  });

  /// A fresh process: a new container is a new launch.
  ProviderContainer launch() {
    final container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: deps),
        sharedPreferencesProvider.overrideWithValue(prefs),
        inMemoryDatabaseOverride(db),
        reportProvider.overrideWithValue(report),
        integrationsRepositoryProvider.overrideWithValue(repository),
        activitiesRepositoryProvider.overrideWithValue(activitiesRepository),
        userIdProvider.overrideWith((ref) async => _userId),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> until(bool Function() done, String what) async {
    for (var i = 0; i < 200; i++) {
      if (done()) return;
      await pumpEventQueue();
    }
    fail('timed out waiting for $what');
  }

  /// The Timeline mounts the notice; nothing else starts the pull. Waits
  /// until the server's Garmin status has reached Drift, then for the notice.
  Future<void> timelineShows(ProviderContainer c, String? expected) async {
    c.listen(reconnectNoticeControllerProvider, (_, _) {});
    final serverStatus =
        server.tables['integrations']!.single['last_sync_status'];
    for (var i = 0; i < 200; i++) {
      final row = await repository.getIntegration(_userId, 'garmin');
      if (row!.lastSyncStatus == serverStatus) break;
      if (i == 199) fail('the launch pull never brought $serverStatus');
      await pumpEventQueue();
    }
    await until(
      () => c.read(reconnectNoticeControllerProvider) == expected,
      'notice == $expected',
    );
  }

  /// The athlete opens Connected Apps (the controller is auto-dispose).
  Future<(ConnectTrainingState, List<AsyncValue<ConnectTrainingState>>)>
  openConnectedApps(ProviderContainer c) async {
    final seen = <AsyncValue<ConnectTrainingState>>[];
    final sub = c.listen(
      connectTrainingControllerProvider,
      (_, next) => seen.add(next),
    );
    addTearDown(sub.close);
    final state = await c.read(connectTrainingControllerProvider.future);
    await pumpEventQueue();
    return (state, seen);
  }

  int skipCrumbs() => report.calls
      .where((c) => c.severity == 'breadcrumb' && c.message == _skipCrumb)
      .length;

  void cooldownStampedNow() => prefs.setInt(
    'garmin_backfill_last_at_$_userId',
    DateTime.now().millisecondsSinceEpoch,
  );

  test('device B: a requires_reauth row another device wrote reaches the '
      'notice and the card on launch, and the backfill does not fire', () async {
    // Device A's write lands on the server after B's last pull.
    server.tables['integrations'] = [_deadTokenRow()];

    final c = launch();
    await timelineShows(c, 'garmin');

    final local = await repository.getIntegration(_userId, 'garmin');
    expect(local!.lastSyncStatus, requiresReauthStatus);

    final (state, _) = await openConnectedApps(c);
    expect(state.isGarminConnected, isTrue);
    expect(state.garminNeedsReauth, isTrue);

    // No automatic backfill on the dead token, and the skip is written down.
    expect(
      functionCalls.where((r) => r.url.path.endsWith('/garmin-backfill')),
      isEmpty,
    );
    expect(skipCrumbs(), 1);
    final crumb = report.calls.firstWhere((c) => c.message == _skipCrumb);
    expect(crumb.area, 'garmin.expected');
    expect(crumb.data, {'reason': 'token_expired'});
    expect(LaunchTrail.text, contains(_skipLine));
    expect(report.degradeds, isEmpty);
    expect(report.faults, isEmpty);

    // A second open of Connected Apps in the same launch records nothing new.
    c.invalidate(connectTrainingControllerProvider);
    final (again, _) = await openConnectedApps(c);
    expect(again.garminNeedsReauth, isTrue);
    expect(skipCrumbs(), 1);
    expect(_skipLine.allMatches(LaunchTrail.text), hasLength(1));
    expect(functionCalls, isEmpty);
  });

  test('a reconnect on device A clears the notice and the card on the next '
      'launch', () async {
    cooldownStampedNow();
    server.tables['integrations'] = [_deadTokenRow()];
    final first = launch();
    await timelineShows(first, 'garmin');
    first.dispose();

    server.tables['integrations'] = [_reconnectedRow()];
    final second = launch();
    await timelineShows(second, null);
    final (state, _) = await openConnectedApps(second);
    expect(state.garminNeedsReauth, isFalse);
    expect(state.isGarminConnected, isTrue);
  });

  test('a dismissed notice comes back on the next launch', () async {
    cooldownStampedNow();
    server.tables['integrations'] = [_deadTokenRow()];
    final first = launch();
    await timelineShows(first, 'garmin');
    first.read(reconnectNoticeControllerProvider.notifier).dismiss();
    expect(first.read(reconnectNoticeControllerProvider), isNull);
    first.dispose();

    final second = launch();
    await timelineShows(second, 'garmin');
  });

  test('the row turning success under an open screen clears the card with no '
      'rebuild', () async {
    cooldownStampedNow();
    server.tables['integrations'] = [_deadTokenRow()];
    final c = launch();
    await timelineShows(c, 'garmin');
    final (state, seen) = await openConnectedApps(c);
    expect(state.garminNeedsReauth, isTrue);
    seen.clear();

    // A pull brings device A's reconnect while Connected Apps is open.
    server.tables['integrations'] = [_reconnectedRow()];
    await repository.syncFromRemote(_userId);

    await until(
      () => c.read(connectTrainingControllerProvider).value?.garminNeedsReauth ==
          false,
      'garminNeedsReauth false',
    );
    expect(seen.where((s) => s.isLoading), isEmpty, reason: 'no rebuild');
    expect(c.read(connectTrainingControllerProvider).value!.isGarminConnected,
        isTrue);
    expect(c.read(reconnectNoticeControllerProvider), isNull);
  });
}
