// Ticket 63 (develop-2026-10, Finding 50-006): a disconnect uploads its hide
// at once, and a same-athlete reconnect unhides every row the disconnect hid
// (not only the rows the next sync fetches) and uploads that at once.
//
// Run 50: TrainingPeaks reconnected as the same athlete got none of its 43
// past workouts back (the sync fetches 45 days ahead), and the hide reached
// the server only at Sign Out.
//
// Seam: the REAL ConnectTrainingController through its provider, the REAL
// IntegrationsRepository and ActivitiesRepository on in-memory Drift, the
// REAL postgrest builder against FakePostgrest, which records every write.
// Activities and integrations are seeded the way the server sends them,
// through `syncFromRemote`. Only the OAuth browser step is replaced: the
// service's `authenticate` writes the row a real connect writes.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_ics_parser.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_transformer.dart';
import 'package:mealvana_endurance/features/integrations/application/tp_writeback_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/data/final_surge_api_client.dart';
import 'package:mealvana_endurance/features/integrations/data/http_retry_client.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/runna_ics_client.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/tp_writeback_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

const _userId = '00000000-0000-0000-0000-000000000063';
const _tpAthlete = '2687398';

const _noRetry = RetryConfig(maxRetries: 0, initialDelayMs: 0, maxDelayMs: 0);

/// The real TP OAuth service with the browser step replaced: `authenticate`
/// writes the row a real connect writes (training_peaks_oauth_service.dart,
/// the IntegrationModel built after the profile call), for [athleteId].
class _TpOAuth extends TrainingPeaksOAuthService {
  _TpOAuth({required super.apiClient, required this.repo})
    : super(clientId: 'mealvana', repository: repo);

  final IntegrationsRepository repo;
  String athleteId = _tpAthlete;

  @override
  Future<IntegrationModel> authenticate(String userId) =>
      repo.upsertIntegration(
        IntegrationModel(
          userId: userId,
          provider: 'training_peaks',
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          tokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
          providerAthleteId: athleteId,
          providerAthleteName: 'Lee Martin',
          isActive: true,
          lastSyncStatus: 'pending',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
}

class _FsOAuth extends FinalSurgeOAuthService {
  _FsOAuth({required super.apiClient, required this.repo})
    : super(clientId: 'fs', repository: repo);

  final IntegrationsRepository repo;

  @override
  Future<IntegrationModel> authenticate(String userId) =>
      repo.upsertIntegration(
        IntegrationModel(
          userId: userId,
          provider: 'final_surge',
          accessToken: 'new-access',
          refreshToken: 'new-refresh',
          tokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
          providerAthleteId: 'fs-1',
          providerAthleteName: 'Lee Martin',
          isActive: true,
          lastSyncStatus: 'pending',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
}

/// A Final Surge sync that finds nothing new and nothing changed, the
/// shape of run 50's Sync Now (0 imported, 0 updated).
class _EmptyFsSync extends FinalSurgeSyncService {
  _EmptyFsSync({
    required super.apiClient,
    required super.integrationsRepository,
    required super.activitiesRepository,
  }) : super(
         transformer: const FinalSurgeTransformer(),
         changeDetectionService: ChangeDetectionService(),
       );

  @override
  Future<SyncResult> syncWorkouts(
    String userId, {
    int numDays = 14,
    int numWorkouts = 21,
    int lookbackDays = 7,
  }) async => const SyncResult(success: true);
}

Map<String, dynamic> _integrationRow(
  String provider,
  String athleteId, {
  bool active = true,
}) => {
  'id': 'i-$provider',
  'user_id': _userId,
  'provider': provider,
  'access_token': active ? 'live-$provider' : '',
  'refresh_token': active ? 'refresh-$provider' : null,
  'token_expires_at': DateTime.now()
      .add(const Duration(hours: 1))
      .toUtc()
      .toIso8601String(),
  'provider_athlete_id': athleteId,
  'provider_athlete_name': 'Lee Martin',
  'is_active': active,
  'last_sync_status': 'success',
  'created_at': '2026-02-01T08:00:00Z',
  'updated_at': '2026-10-01T08:00:00Z',
};

/// A past provider workout as the server sends it (run 50's rows are dated
/// 2026-02-03 to 2026-09-24).
Map<String, dynamic> _activityRow(
  String id,
  String provider, {
  bool? hidden,
  int monthsBack = 3,
}) => {
  'id': id,
  'user_id': _userId,
  'activity_type': 'running',
  'title': 'Easy run $id',
  'scheduled_date_time': DateTime(2026, 9 - monthsBack, 3, 7).toIso8601String(),
  'status': 'planned',
  'synced_from_provider': provider,
  'provider_workout_id': 'pw-$id',
  'hidden_by_disconnect': hidden,
  'created_at': '2026-02-01T08:00:00Z',
  'updated_at': '2026-02-01T08:00:00Z',
};

void main() {
  late AppDatabase db;
  late FakePostgrest server;
  late IntegrationsRepository integrations;
  late ActivitiesRepository activities;
  late RecordingReport report;
  late _TpOAuth tpOAuth;
  late ProviderContainer container;

  final tpIds = [for (var i = 0; i < 5; i++) 'tp-$i'];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.memory();
    addTearDown(db.close);
    server = FakePostgrest();
    server.tables['users'] = [
      {'id': _userId},
    ];
    server.tables['integrations'] = [
      _integrationRow('training_peaks', _tpAthlete),
    ];
    server.tables['activities'] = [
      for (var i = 0; i < 5; i++)
        _activityRow(tpIds[i], 'training_peaks', monthsBack: 1 + i),
    ];
    await server.signIn(_userId);

    // A finished onboarding, so the uploads are not deferred (FK 23503 guard).
    await db
        .into(db.userProfilesTable)
        .insert(
          UserProfilesTableCompanion.insert(
            id: _userId,
            deviceId: 'device-63',
            authUserId: const Value(_userId),
            onboardingCompleted: const Value(true),
            createdAt: Value(DateTime(2026, 1, 1)),
            updatedAt: Value(DateTime(2026, 1, 1)),
          ),
        );

    report = RecordingReport();
    integrations = IntegrationsRepository(
      database: db,
      supabase: server.client,
      report: RecordingReport(),
    );
    activities = ActivitiesRepository(
      supabase: server.client,
      database: db,
      report: RecordingReport(),
      deduplicationService: ActivityDeduplicationService(),
    );
    expect((await integrations.syncFromRemote(_userId)).success, isTrue);
    expect((await activities.syncFromRemote(_userId)).success, isTrue);
    server.writes.clear();

    // Every provider endpoint answers an empty list: no sync runs here.
    final providerHttp = MockClient((req) async => http.Response('[]', 200));
    final tpApi = TrainingPeaksApiClient(
      clientId: 'mealvana',
      clientSecret: 'secret',
      appVersion: '1.29.0',
      httpClient: providerHttp,
      retryConfig: _noRetry,
    );
    tpOAuth = _TpOAuth(apiClient: tpApi, repo: integrations);
    final fsOAuth = _FsOAuth(
      apiClient: FinalSurgeApiClient(
        clientId: 'fs',
        clientSecret: 'secret',
        httpClient: providerHttp,
        retryConfig: _noRetry,
      ),
      repo: integrations,
    );
    final runnaSync = RunnaSyncService(
      icsClient: RunnaIcsClient(
        httpClient: MockClient(
          (req) async => http.Response(
            'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR\r\n',
            200,
          ),
        ),
      ),
      parser: const RunnaIcsParser(),
      integrationsRepository: integrations,
      activitiesRepository: activities,
      transformer: const RunnaTransformer(),
      changeDetectionService: ChangeDetectionService(),
      report: RecordingReport(),
    );
    final sharedPrefs = await SharedPreferences.getInstance();
    final prefs = PreferencesService(sharedPrefs);
    final writeback = TpWritebackService(
      apiClient: tpApi,
      oauthService: tpOAuth,
      preferencesService: prefs,
      database: db,
      supabase: server.client,
      report: RecordingReport(),
    );

    container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: server.client),
        // Real (mock-initialised) prefs: the TP connect writes a flag.
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        inMemoryDatabaseOverride(db),
        integrationsRepositoryProvider.overrideWithValue(integrations),
        activitiesRepositoryProvider.overrideWithValue(activities),
        userIdProvider.overrideWith((ref) async => _userId),
        trainingPeaksOAuthServiceProvider.overrideWith((ref) async => tpOAuth),
        finalSurgeOAuthServiceProvider.overrideWithValue(fsOAuth),
        finalSurgeSyncServiceProvider.overrideWithValue(
          _EmptyFsSync(
            apiClient: FinalSurgeApiClient(
              clientId: 'fs',
              clientSecret: 'secret',
              httpClient: providerHttp,
              retryConfig: _noRetry,
            ),
            integrationsRepository: integrations,
            activitiesRepository: activities,
          ),
        ),
        runnaSyncServiceProvider.overrideWithValue(runnaSync),
        tpWritebackServiceProvider.overrideWith((ref) async => writeback),
        reportProvider.overrideWithValue(report),
      ],
    );
    addTearDown(container.dispose);
    await container.read(connectTrainingControllerProvider.future);
  });

  ConnectTrainingController notifier() =>
      container.read(connectTrainingControllerProvider.notifier);

  Future<Activity> local(String id) => (db.select(
    db.activitiesTable,
  )..where((t) => t.id.equals(id))).getSingle();

  /// Every activities row the server was sent, by id, last write wins.
  Map<String, Map<String, dynamic>> sentActivities() => {
    for (final w in server.writes)
      if (w.table == 'activities')
        for (final row in (w.body is List ? w.body as List : [w.body]))
          (row as Map)['id'] as String: row.cast<String, dynamic>(),
  };

  List<RecordedReport> degradedFor(String provider) =>
      report.degradeds.where((d) => d.extra?['provider'] == provider).toList();

  test('(a) disconnect uploads the hide at once, before any sync', () async {
    await notifier().disconnectTrainingPeaks();

    final sent = sentActivities();
    for (final id in tpIds) {
      expect(sent[id]?['hidden_by_disconnect'], isTrue, reason: id);
      final row = await local(id);
      expect(row.hiddenByDisconnect, isTrue, reason: id);
      expect(row.needsUpload, isFalse, reason: id);
    }
    expect(degradedFor('training_peaks'), isEmpty);
  });

  test('(b) a same-athlete reconnect unhides all five and uploads it, with '
      'no Sync Now', () async {
    await notifier().disconnectTrainingPeaks();
    server.writes.clear();

    final connected = await notifier().connectTrainingPeaks();

    expect(connected, isTrue);
    final sent = sentActivities();
    for (final id in tpIds) {
      final row = await local(id);
      expect(row.hiddenByDisconnect, isFalse, reason: id);
      expect(row.needsUpload, isFalse, reason: id);
      expect(sent[id]?['hidden_by_disconnect'], isFalse, reason: id);
    }
    expect(
      container
          .read(connectTrainingControllerProvider)
          .value!
          .isTrainingPeaksConnected,
      isTrue,
    );

    // (iv) Reconnect twice: the second unhide finds nothing to upload.
    server.writes.clear();
    await notifier().connectTrainingPeaks();
    expect(sentActivities(), isEmpty);
  });

  test('(c) a reconnect as a different athlete leaves the rows hidden and '
      'notes it', () async {
    await notifier().disconnectTrainingPeaks();
    server.writes.clear();
    tpOAuth.athleteId = '9999999';

    expect(await notifier().connectTrainingPeaks(), isTrue);

    for (final id in tpIds) {
      expect((await local(id)).hiddenByDisconnect, isTrue, reason: id);
    }
    expect(sentActivities(), isEmpty);
    final note = report.notes.singleWhere(
      (n) =>
          n.message ==
          'Reconnect as a different athlete; hidden workouts stay hidden',
    );
    expect(note.area, 'training_peaks');
    expect(note.data, {'hidden': 5});
  });

  test('(c2) a reconnect whose new athlete id is unknown counts as the same '
      'athlete and unhides', () async {
    await notifier().disconnectTrainingPeaks();
    server.writes.clear();
    // The profile call gave no athlete id (an empty one); the old row has one.
    tpOAuth.athleteId = '';

    expect(await notifier().connectTrainingPeaks(), isTrue);

    final sent = sentActivities();
    for (final id in tpIds) {
      expect((await local(id)).hiddenByDisconnect, isFalse, reason: id);
      expect(sent[id]?['hidden_by_disconnect'], isFalse, reason: id);
    }
    expect(
      report.notes.where(
        (n) =>
            n.message ==
            'Reconnect as a different athlete; hidden workouts stay hidden',
      ),
      isEmpty,
    );
  });

  test('(d) a refused hide upload keeps the rows dirty and records one '
      'degraded naming the provider', () async {
    server.rejectWrites.add('activities');

    await notifier().disconnectTrainingPeaks();

    for (final id in tpIds) {
      final row = await local(id);
      expect(row.hiddenByDisconnect, isTrue, reason: id);
      expect(row.needsUpload, isTrue, reason: id);
    }
    final degraded = degradedFor('training_peaks');
    expect(degraded, hasLength(1));
    expect(degraded.single.area, 'sync');
    expect(
      degraded.single.message,
      'Disconnect hide upload failed; rows stay dirty for retry',
    );
  });

  test('(e) Final Surge: a reconnect unhides its hidden rows', () async {
    server.tables['integrations'] = [
      _integrationRow('final_surge', 'fs-1', active: false),
    ];
    server.tables['activities'] = [
      _activityRow('fs-0', 'final_surge', hidden: true),
      _activityRow('fs-1', 'final_surge', hidden: true),
    ];
    await integrations.syncFromRemote(_userId);
    await activities.syncFromRemote(_userId);
    server.writes.clear();

    expect(await notifier().connectFinalSurge(), isTrue);

    final sent = sentActivities();
    for (final id in ['fs-0', 'fs-1']) {
      expect((await local(id)).hiddenByDisconnect, isFalse, reason: id);
      expect(sent[id]?['hidden_by_disconnect'], isFalse, reason: id);
    }
    // TrainingPeaks' rows were never hidden and are not touched.
    expect(sent.keys.where((k) => k.startsWith('tp-')), isEmpty);
  });

  test(
    '(e) Runna: a reconnect with no previous row unhides its rows',
    () async {
      server.tables['activities'] = [
        _activityRow('rn-0', 'runna', hidden: true),
        _activityRow('rn-1', 'runna', hidden: true),
      ];
      await activities.syncFromRemote(_userId);
      server.writes.clear();
      expect(await integrations.getIntegration(_userId, 'runna'), isNull);

      expect(
        await notifier().connectRunna('https://cal.runna.com/feed/abc.ics'),
        isTrue,
      );

      final sent = sentActivities();
      for (final id in ['rn-0', 'rn-1']) {
        expect((await local(id)).hiddenByDisconnect, isFalse, reason: id);
        expect(sent[id]?['hidden_by_disconnect'], isFalse, reason: id);
      }
    },
  );

  group('item 5: Sync Now uploads dirty activities every time', () {
    Future<void> leaveDirty(String id) async {
      await (db.update(db.activitiesTable)..where((t) => t.id.equals(id)))
          .write(const ActivitiesTableCompanion(needsUpload: Value(true)));
    }

    test('0 new and 0 updated still uploads a row an earlier write left '
        'dirty', () async {
      await leaveDirty('tp-0');

      final result = await notifier().importFinalSurgeWorkouts();

      expect(result.success, isTrue);
      expect(sentActivities().keys, contains('tp-0'));
      expect((await local('tp-0')).needsUpload, isFalse);
      expect(degradedFor('final_surge'), isEmpty);
    });

    test('a failed upload is recorded as degraded, rows stay dirty', () async {
      await leaveDirty('tp-0');
      server.rejectWrites.add('activities');

      await notifier().importFinalSurgeWorkouts();

      expect((await local('tp-0')).needsUpload, isTrue);
      final degraded = degradedFor('final_surge');
      expect(degraded, hasLength(1));
      expect(degraded.single.area, 'sync');
      expect(
        degraded.single.message,
        'Upload of synced activities failed; rows stay dirty',
      );
    });
  });
}
