// Ticket 60 (testing-wave develop-2026-10), 50-010 and 32-005's device_id
// note: Sync Now tracks a sync, not a connect, and every integration event
// carries the device id, not the user id.
//
// Run 50: TrainingPeaks Sync Now sent `integration_connect_started` before
// `integration_sync_success`, so Mixpanel's connect funnel counted each
// manual sync as an unfinished connect, and both events carried the user id
// as `device_id`.
//
// Seam: the REAL ConnectTrainingController through its provider, the REAL
// IntegrationsRepository on in-memory Drift seeded through the download
// mapping (as `disconnect_clears_reconnect_seam_test.dart`), the REAL
// ActivitiesRepository against FakePostgrest. The provider sync services are
// fakes answering an empty success, as the server-backed services do on a
// sync with nothing new. Analytics is a RecordingAnalyticsTracker; the device
// id comes from a fake DeviceInfoService, as `app_opened` reads it.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/vdot_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/application/vdot_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/data/http_retry_client.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/vdot_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/device_info_service.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

const _userId = '00000000-0000-0000-0000-000000000060';
const _deviceId = 'C8EEF12E-6B1A-4E52-9C1F-0A7D3B2E5F60';

class _FakeDeviceInfo implements DeviceInfoService {
  @override
  String get deviceId => _deviceId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ticket 73: when set, every fake sync throws it (a failure past the
/// service's own catches, which the controller's catch handles).
Object? _syncThrows;

Never _throwIt() => throw _syncThrows!;

class _EmptyTpSync implements TrainingPeaksSyncService {
  @override
  Future<TrainingPeaksFullSyncResult> syncAll(
    String userId, {
    int workoutDays = 45,
    int eventDays = 90,
  }) async => _syncThrows != null
      ? _throwIt()
      : const TrainingPeaksFullSyncResult(
          workoutResult: TrainingPeaksSyncResult(success: true),
          eventResult: TrainingPeaksEventSyncResult(success: true),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyFsSync implements FinalSurgeSyncService {
  @override
  Future<SyncResult> syncWorkouts(
    String userId, {
    int numDays = 14,
    int numWorkouts = 21,
    int lookbackDays = 7,
  }) async =>
      _syncThrows != null ? _throwIt() : const SyncResult(success: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyVdotSync implements VdotSyncService {
  @override
  Future<VdotSyncResult> syncWorkouts(
    String userId, {
    int lookbackDays = 14,
    int lookaheadDays = 45,
  }) async =>
      _syncThrows != null ? _throwIt() : const VdotSyncResult(success: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _EmptyRunnaSync implements RunnaSyncService {
  @override
  Future<RunnaSyncResult> syncWorkouts(String userId) async =>
      _syncThrows != null ? _throwIt() : const RunnaSyncResult(success: true);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The real V.O2 OAuth service; authenticate answers with the stored row, as
/// the service does once the browser round trip has upserted it.
class _StoredRowVdotOAuth extends VdotOAuthService {
  _StoredRowVdotOAuth({required super.apiClient, required super.repository})
    : _repository = repository,
      super(
        clientId: 'vdot',
        authBaseUrl: 'https://vdot.test',
        redirectUri: 'com.milkman.mealvanaendurance://vdot',
        report: RecordingReport(),
      );

  final IntegrationsRepository _repository;

  @override
  Future<IntegrationModel> authenticate(String userId) async =>
      (await _repository.getIntegration(userId, 'vdot'))!;
}

/// A healthy connected row as the server sends it.
Map<String, dynamic> _connectedRow(String provider) => {
  'id': 'i-$provider',
  'user_id': _userId,
  'provider': provider,
  'access_token': 'token-$provider',
  'refresh_token': 'refresh-$provider',
  'token_expires_at': DateTime.now()
      .add(const Duration(hours: 3))
      .toUtc()
      .toIso8601String(),
  'provider_athlete_id': 'ath-$provider',
  'provider_athlete_name': 'Lee Martin',
  'is_active': true,
  'last_sync_at': '2026-10-07T12:00:00Z',
  'last_sync_status': 'success',
  'last_sync_error': null,
  'created_at': '2026-09-01T08:00:00Z',
  'updated_at': '2026-10-07T13:26:00Z',
};

void main() {
  late RecordingAnalyticsTracker analytics;
  late ProviderContainer container;

  setUp(() async {
    _syncThrows = null;
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final server = FakePostgrest();
    server.tables['users'] = [
      {'id': _userId},
    ];
    server.tables['integrations'] = [
      for (final p in ['training_peaks', 'final_surge', 'vdot', 'runna'])
        _connectedRow(p),
    ];
    await server.signIn(_userId);

    final repository = IntegrationsRepository(
      database: db,
      supabase: server.client,
      report: RecordingReport(),
    );
    await repository.syncFromRemote(_userId);

    final noNetwork = MockClient(
      (req) async => throw StateError('no provider call: ${req.url}'),
    );
    final vdotOAuth = _StoredRowVdotOAuth(
      apiClient: VdotApiClient(
        clientId: 'vdot',
        clientSecret: 'secret',
        authBaseUrl: 'https://vdot.test',
        apiBaseUrl: 'https://vdot.test/api',
        httpClient: noNetwork,
        retryConfig: const RetryConfig(
          maxRetries: 0,
          initialDelayMs: 0,
          maxDelayMs: 0,
        ),
      ),
      repository: repository,
    );

    analytics = RecordingAnalyticsTracker();
    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: server.client,
            sharedPreferences: MockSharedPreferences(),
          ),
        ),
        mockSharedPreferences(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        inMemoryDatabaseOverride(db),
        deviceInfoServiceProvider.overrideWithValue(_FakeDeviceInfo()),
        integrationsRepositoryProvider.overrideWithValue(repository),
        activitiesRepositoryProvider.overrideWithValue(
          ActivitiesRepository(
            supabase: server.client,
            database: db,
            report: RecordingReport(),
            deduplicationService: ActivityDeduplicationService(),
          ),
        ),
        userIdProvider.overrideWith((ref) async => _userId),
        trainingPeaksSyncServiceProvider.overrideWith(
          (ref) async => _EmptyTpSync(),
        ),
        finalSurgeSyncServiceProvider.overrideWithValue(_EmptyFsSync()),
        vdotSyncServiceProvider.overrideWithValue(_EmptyVdotSync()),
        runnaSyncServiceProvider.overrideWithValue(_EmptyRunnaSync()),
        vdotOAuthServiceProvider.overrideWithValue(vdotOAuth),
      ],
    );
    addTearDown(container.dispose);
    // Keep the auto-dispose controller alive across the awaits.
    final sub = container.listen(connectTrainingControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(connectTrainingControllerProvider.future);
  });

  List<AnalyticsEvent> integrationEvents() => [
    for (final e in analytics.events)
      if (e.name.startsWith('integration_')) e,
  ];

  final syncs = <String, Future<Object?> Function(ConnectTrainingController)>{
    'training_peaks': (c) => c.importTrainingPeaksWorkouts(),
    'final_surge': (c) => c.importFinalSurgeWorkouts(),
    'vdot': (c) => c.importVdotWorkouts(),
    'runna': (c) => c.importRunnaWorkouts(),
  };

  for (final MapEntry(key: provider, value: sync) in syncs.entries) {
    test('$provider Sync Now: sync_started then sync_success, no '
        'connect_started, both with the device id', () async {
      final notifier = container.read(
        connectTrainingControllerProvider.notifier,
      );
      expect(notifier.currentUserId, _userId);

      await sync(notifier);

      final events = integrationEvents();
      expect(events.map((e) => e.name), [
        'integration_sync_started',
        'integration_sync_success',
      ]);
      for (final e in events) {
        expect(e.properties!['provider'], provider, reason: e.name);
        expect(e.properties!['device_id'], _deviceId, reason: e.name);
        expect(e.properties!['device_id'], isNot(_userId), reason: e.name);
      }
    });
  }

  // Ticket 73 (52 item 2): the controller's own catch sent `e.toString()`,
  // which carries addresses and ports; the event now carries the row's code.
  for (final MapEntry(key: provider, value: sync) in syncs.entries) {
    test('$provider Sync Now that throws: sync_failed carries the code, '
        'never the exception text', () async {
      _syncThrows = SocketException(
        'Connection failed',
        osError: const OSError('Network is unreachable', 51),
        address: InternetAddress('203.0.113.7'),
        port: 443,
      );
      final notifier = container.read(
        connectTrainingControllerProvider.notifier,
      );

      await sync(notifier);

      final failed = integrationEvents().singleWhere(
        (e) => e.name == 'integration_sync_failed',
      );
      expect(failed.properties!['provider'], provider);
      expect(failed.properties!['error_type'], 'exception');
      expect(failed.properties!['error_message'], 'network');
    });
  }

  test('connectVdot still sends integration_connect_started, with the '
      'device id', () async {
    final notifier = container.read(connectTrainingControllerProvider.notifier);

    final connected = await notifier.connectVdot();

    expect(connected, isTrue);
    final events = integrationEvents();
    expect(events.map((e) => e.name), [
      'integration_connect_started',
      'integration_connect_success',
    ]);
    for (final e in events) {
      expect(e.properties!['provider'], 'vdot', reason: e.name);
      expect(e.properties!['device_id'], _deviceId, reason: e.name);
    }
  });
}
