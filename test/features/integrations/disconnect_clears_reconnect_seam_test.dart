// Ticket 47 (develop-2026-10, Finding 32-005): disconnecting a connection
// the provider refused clears its reconnect state everywhere, and makes no
// token call on the way out.
//
// Run 32: TrainingPeaks and V.O2 rows sat at `requires_reauth`. Disconnect
// left the status on the row (so a later read showed Reconnect again), the
// card kept its Reconnect pill until the screen rebuilt, and the
// TrainingPeaks write-back strip refreshed the dead token first (a 400 and an
// `error_reported` one second before `integration_disconnected`).
//
// Seam: the REAL ConnectTrainingController through its provider, the REAL
// IntegrationsRepository on in-memory Drift, the REAL OAuth services and
// TpWritebackService, and the REAL postgrest builder against FakePostgrest,
// which records every write. Rows are seeded the way the server sends them,
// through `syncFromRemote` (the download mapping). The TP OAuth service is a
// spy only so a refresh attempt fails the test loudly.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/tp_writeback_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/application/vdot_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/data/http_retry_client.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/data/vdot_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/tp_writeback_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

const _userId = '00000000-0000-0000-0000-000000000047';

/// The real OAuth service; any refresh attempt is recorded and refused.
class _NoRefreshTpOAuth extends TrainingPeaksOAuthService {
  _NoRefreshTpOAuth({required super.apiClient, required super.repository})
    : super(clientId: 'mealvana');

  int refreshCalls = 0;

  @override
  Future<IntegrationModel?> refreshTokenIfNeeded(String userId) {
    refreshCalls++;
    throw StateError('a refused connection must not be refreshed');
  }
}

/// A server row after a refused refresh, as ticket 37 leaves it.
Map<String, dynamic> _refusedRow(String id, String provider) => {
  'id': id,
  'user_id': _userId,
  'provider': provider,
  'access_token': 'expired-$provider',
  'refresh_token': 'dead-refresh-$provider',
  'token_expires_at': DateTime.now()
      .subtract(const Duration(hours: 3))
      .toUtc()
      .toIso8601String(),
  'provider_athlete_id': 'ath-$provider',
  'provider_athlete_name': 'Lee Martin',
  'is_active': true,
  'last_sync_at': '2026-09-28T12:00:00Z',
  'last_sync_status': requiresReauthStatus,
  'last_sync_error': reauthRequiredCode,
  'created_at': '2026-09-01T08:00:00Z',
  'updated_at': '2026-10-07T13:26:00Z',
};

void main() {
  late AppDatabase db;
  late FakePostgrest server;
  late IntegrationsRepository repository;
  late _NoRefreshTpOAuth tpOAuth;
  late RecordingReport writebackReport;
  late List<http.Request> providerRequests;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    server = FakePostgrest();
    // The eager push runs only once the athlete's users row is remote, and
    // only for rows the session owns (DEV-A2).
    server.tables['users'] = [
      {'id': _userId},
    ];
    server.tables['integrations'] = [
      _refusedRow('i-tp', 'training_peaks'),
      _refusedRow('i-vdot', 'vdot'),
    ];
    await server.signIn(_userId);

    repository = IntegrationsRepository(
      database: db,
      supabase: server.client,
      report: RecordingReport(),
    );
    // Seed through the download mapping, as the server sends the rows.
    await repository.syncFromRemote(_userId);

    providerRequests = [];
    final providerHttp = MockClient((req) async {
      providerRequests.add(req);
      if (req.url.path.endsWith('/oauth/token')) {
        throw StateError('no token call on a refused connection');
      }
      return http.Response('unexpected ${req.method} ${req.url}', 599);
    });
    const noRetry = RetryConfig(
      maxRetries: 0,
      initialDelayMs: 0,
      maxDelayMs: 0,
    );
    final tpApi = TrainingPeaksApiClient(
      clientId: 'mealvana',
      clientSecret: 'secret',
      appVersion: '1.29.0',
      httpClient: providerHttp,
      retryConfig: noRetry,
    );
    tpOAuth = _NoRefreshTpOAuth(apiClient: tpApi, repository: repository);
    final vdotOAuth = VdotOAuthService(
      apiClient: VdotApiClient(
        clientId: 'vdot',
        clientSecret: 'secret',
        authBaseUrl: 'https://vdot.test',
        apiBaseUrl: 'https://vdot.test/api',
        httpClient: providerHttp,
        retryConfig: noRetry,
      ),
      repository: repository,
      clientId: 'vdot',
      authBaseUrl: 'https://vdot.test',
      redirectUri: 'com.milkman.mealvanaendurance://vdot',
      report: RecordingReport(),
    );

    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesService(await SharedPreferences.getInstance());
    writebackReport = RecordingReport();
    final writeback = TpWritebackService(
      apiClient: tpApi,
      oauthService: tpOAuth,
      preferencesService: prefs,
      database: db,
      supabase: server.client,
      report: writebackReport,
    );
    // Two pushed blocks the strip would walk on a live connection.
    for (var i = 0; i < 2; i++) {
      await db
          .into(db.tpWritebackTable)
          .insert(
            TpWritebackTableCompanion(
              userId: const Value(_userId),
              activityId: Value('a-$i'),
              tpWorkoutId: Value(3711546420 + i),
              planHash: const Value('h'),
              pushedAt: Value(DateTime(2026, 9, 20)),
              status: const Value('active'),
            ),
          );
    }

    final activitiesRepository = ActivitiesRepository(
      supabase: server.client,
      database: db,
      report: RecordingReport(),
      deduplicationService: ActivityDeduplicationService(),
    );

    container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: server.client),
        mockSharedPreferences(),
        inMemoryDatabaseOverride(db),
        integrationsRepositoryProvider.overrideWithValue(repository),
        activitiesRepositoryProvider.overrideWithValue(activitiesRepository),
        userIdProvider.overrideWith((ref) async => _userId),
        trainingPeaksOAuthServiceProvider.overrideWith((ref) async => tpOAuth),
        vdotOAuthServiceProvider.overrideWithValue(vdotOAuth),
        tpWritebackServiceProvider.overrideWith((ref) async => writeback),
      ],
    );
    addTearDown(container.dispose);
  });

  List<Map<String, dynamic>> integrationUpserts(String provider) => [
    for (final w in server.writes)
      if (w.table == 'integrations')
        for (final row in (w.body is List ? w.body as List : [w.body]))
          if ((row as Map)['provider'] == provider) row.cast<String, dynamic>(),
  ];

  test('disconnecting refused TrainingPeaks and V.O2 connections clears '
      'reconnect state in the card, on the row and on the server, with no '
      'token call', () async {
    // Precondition: the seeded rows read as needing a reconnect.
    final before = await container.read(
      connectTrainingControllerProvider.future,
    );
    expect(before.trainingPeaksNeedsReauth, isTrue);
    expect(before.vdotNeedsReauth, isTrue);
    expect(before.isTrainingPeaksConnected, isTrue);
    expect(before.isVdotConnected, isTrue);

    final notifier = container.read(connectTrainingControllerProvider.notifier);
    await notifier.disconnectVdot();
    await notifier.disconnectTrainingPeaks();

    // 1. The card flips to Connect at once, before any rebuild.
    final after = container.read(connectTrainingControllerProvider).value!;
    expect(after.errorMessage, isNull);
    expect(after.isVdotConnected, isFalse);
    expect(after.vdotNeedsReauth, isFalse);
    expect(after.isTrainingPeaksConnected, isFalse);
    expect(after.trainingPeaksNeedsReauth, isFalse);

    // 2. The local rows are inactive with the sync outcome wiped.
    for (final provider in ['vdot', 'training_peaks']) {
      final row = await repository.getIntegration(_userId, provider);
      expect(row!.isActive, isFalse, reason: provider);
      expect(row.lastSyncStatus, isNull, reason: provider);
      expect(row.lastSyncError, isNull, reason: provider);
      expect(row.accessToken, isEmpty, reason: provider);
    }

    // 3. The server got the cleared values.
    for (final provider in ['vdot', 'training_peaks']) {
      final upserts = integrationUpserts(provider);
      expect(upserts, isNotEmpty, reason: '$provider was pushed');
      final last = upserts.last;
      expect(last['is_active'], isFalse, reason: provider);
      expect(last.containsKey('last_sync_status'), isTrue);
      expect(last['last_sync_status'], isNull, reason: provider);
      expect(last['last_sync_error'], isNull, reason: provider);
    }

    // 4. A rebuild reading the rows agrees.
    container.invalidate(connectTrainingControllerProvider);
    final rebuilt = await container.read(
      connectTrainingControllerProvider.future,
    );
    expect(rebuilt.vdotNeedsReauth, isFalse);
    expect(rebuilt.trainingPeaksNeedsReauth, isFalse);
    expect(rebuilt.isVdotConnected, isFalse);
    expect(rebuilt.isTrainingPeaksConnected, isFalse);

    // 5. No refresh, no provider call; the skip is written down (D9) and
    // both write-back ledgers are still purged.
    expect(tpOAuth.refreshCalls, 0);
    expect(providerRequests, isEmpty);
    expect(writebackReport.degradeds, isEmpty);
    expect(writebackReport.faults, isEmpty);
    expect(
      writebackReport.notes.map((n) => n.message),
      contains(
        'TP write-back: disconnect strip skipped; connection needs reconnect',
      ),
    );
    expect(await db.select(db.tpWritebackTable).get(), isEmpty);
    expect(
      server.writes.where(
        (w) => w.table == 'tp_writeback_ledger' && w.method == 'DELETE',
      ),
      hasLength(1),
    );
  });
}
