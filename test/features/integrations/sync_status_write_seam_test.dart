// Ticket 138 (Findings 118-002, 118-007, 117-001): what a sync status write
// leaves on the integrations row and sends to the server.
//
// Seam: a provider's answer → TrainingPeaksSyncService → the REAL
// IntegrationsRepository on in-memory Drift → the REAL postgrest builder
// against an in-memory PostgREST (FakePostgrest), which records every write.
// Nothing between the HTTP answer and the recorded upsert is a double.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/http_retry_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/widget_test_harness.dart';

const _userId = 'u-138';

IntegrationModel _tp({String status = 'success', String? error}) =>
    IntegrationModel(
      id: 'i-tp',
      userId: _userId,
      provider: 'training_peaks',
      accessToken: 'stale-access',
      refreshToken: 'stale-refresh',
      tokenExpiresAt: DateTime.now().subtract(const Duration(hours: 3)),
      providerAthleteId: 'ath-1',
      isActive: true,
      lastSyncStatus: status,
      lastSyncError: error,
      createdAt: DateTime(2026, 9, 1, 8),
      updatedAt: DateTime(2026, 9, 1, 8),
    );

/// TP's token endpoint unreachable: the refresh throws before any answer.
TrainingPeaksApiClient _tpOffline() => TrainingPeaksApiClient(
  clientId: 'cid',
  clientSecret: 'secret',
  appVersion: 'test',
  httpClient: MockClient((request) async {
    if (request.url.path.endsWith('/oauth/token')) {
      throw SocketException(
        'Connection failed',
        osError: const OSError('Network is unreachable', 51),
        address: InternetAddress('203.0.113.7'),
        port: 443,
      );
    }
    return http.Response('[]', 200);
  }),
  retryConfig: const RetryConfig(
    maxRetries: 1,
    initialDelayMs: 0,
    maxDelayMs: 0,
  ),
);

void main() {
  late AppDatabase db;
  late FakePostgrest server;
  late IntegrationsRepository repository;
  final statusWrites = <(String, String)>[];

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    server = FakePostgrest();
    // The eager push runs only once the athlete's users row is remote.
    server.tables['users'] = [
      {'id': _userId},
    ];
    statusWrites.clear();
    repository = IntegrationsRepository(
      database: db,
      supabase: server.client,
      logger: MockAppLogger(),
      sentry: mockSentryReporter(),
      onSyncStatusWritten: (provider, status) =>
          statusWrites.add((provider, status)),
    );
  });

  TrainingPeaksSyncService syncService(TrainingPeaksApiClient api) =>
      TrainingPeaksSyncService(
        apiClient: api,
        integrationsRepository: repository,
        activitiesRepository: ActivitiesRepository(
          supabase: server.client,
          database: db,
          logger: MockAppLogger(),
          sentry: mockSentryReporter(),
          deduplicationService: ActivityDeduplicationService(
            logger: MockAppLogger(),
          ),
        ),
        transformer: const TrainingPeaksTransformer(),
        changeDetectionService: ChangeDetectionService(),
      );

  Map<String, dynamic> lastIntegrationUpsert() {
    final write = server.writes.lastWhere((w) => w.table == 'integrations');
    final body = write.body;
    final row = body is List ? body.single : body;
    return (row as Map).cast<String, dynamic>();
  }

  group('118-002: a network error keeps requires_reauth', () {
    test('the workout sync leaves the stored status and message alone',
        () async {
      await repository.upsertIntegration(
        _tp(
          status: requiresReauthStatus,
          error: 'Token refresh refused. Please reconnect.',
        ),
      );

      final result = await syncService(_tpOffline()).syncWorkouts(_userId);

      expect(result.success, isFalse);
      final row = await repository.getIntegration(_userId, 'training_peaks');
      expect(row!.lastSyncStatus, requiresReauthStatus);
      expect(row.needsReconnect, isTrue);
      expect(row.lastSyncError, 'Token refresh refused. Please reconnect.');
      // The hook hears the status the row KEEPS, never the overwritten one.
      expect(statusWrites, isNotEmpty);
      expect(statusWrites.every((w) => w.$2 == requiresReauthStatus), isTrue);
    });

    test('on an ordinary row the same error is stored as a plain message',
        () async {
      await repository.upsertIntegration(_tp());

      await syncService(_tpOffline()).syncWorkouts(_userId);

      final row = await repository.getIntegration(_userId, 'training_peaks');
      expect(row!.lastSyncStatus, 'error');
      expect(row.lastSyncError, isNotNull);
      expect(row.lastSyncError, isNot(contains('SocketException')));
      expect(row.lastSyncError, isNot(contains('203.0.113.7')));
      expect(row.lastSyncError, isNot(contains('443')));
      expect(row.lastSyncError, contains('TrainingPeaks'));
    });
  });

  group('118-007: Last synced is the last successful sync', () {
    test('a failed attempt does not stamp lastSyncAt', () async {
      await repository.upsertIntegration(_tp());
      expect(
        (await repository.getIntegration(_userId, 'training_peaks'))!
            .lastSyncAt,
        isNull,
      );

      await repository.updateSyncStatus(
        _userId,
        'training_peaks',
        status: 'error',
        error: 'Could not reach TrainingPeaks.',
      );
      expect(
        (await repository.getIntegration(_userId, 'training_peaks'))!
            .lastSyncAt,
        isNull,
      );

      final before = DateTime.now();
      await repository.updateSyncStatus(
        _userId,
        'training_peaks',
        status: 'success',
      );
      final row = await repository.getIntegration(_userId, 'training_peaks');
      expect(row!.lastSyncAt, isNotNull);
      expect(
        row.lastSyncAt!.isBefore(before.subtract(const Duration(seconds: 1))),
        isFalse,
      );

      // A later failure keeps the successful stamp.
      await repository.updateSyncStatus(
        _userId,
        'training_peaks',
        status: 'error',
        error: 'Could not reach TrainingPeaks.',
      );
      final after = await repository.getIntegration(_userId, 'training_peaks');
      expect(after!.lastSyncAt, row.lastSyncAt);
      expect(statusWrites, [
        ('training_peaks', 'error'),
        ('training_peaks', 'success'),
        ('training_peaks', 'error'),
      ]);
    });
  });

  group('117-001: timestamps reach the server in UTC', () {
    test('last_sync_at and the other stamps carry a Z offset', () async {
      await repository.upsertIntegration(_tp());
      await repository.updateSyncStatus(
        _userId,
        'training_peaks',
        status: 'success',
      );

      final sent = lastIntegrationUpsert();
      final row = await repository.getIntegration(_userId, 'training_peaks');
      for (final key in [
        'last_sync_at',
        'token_expires_at',
        'created_at',
        'updated_at',
      ]) {
        final value = sent[key] as String?;
        expect(value, isNotNull, reason: key);
        expect(value, endsWith('Z'), reason: '$key must be a UTC instant');
      }
      // The instant is unchanged: parsing the wire value gives the local
      // stamp back, so the server does not read wall clock as UTC.
      expect(
        DateTime.parse(sent['last_sync_at'] as String).toLocal(),
        row!.lastSyncAt,
      );
      expect(
        DateTime.parse(sent['token_expires_at'] as String).toLocal(),
        row.tokenExpiresAt,
      );
    });
  });
}
