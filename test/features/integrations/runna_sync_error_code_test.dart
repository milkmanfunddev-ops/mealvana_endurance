// Ticket 52 (develop-2026-10): Runna writes a sync-error code to
// `integrations.last_sync_error`, never the exception text. Ticket 37 moved
// the other providers onto `SyncErrorCode`; Runna still stored `e.message` /
// `e.toString()`, and that text can carry the calendar URL (the feed's token).
//
// Seam: the feed's HTTP answer → the REAL RunnaIcsClient → RunnaSyncService
// → the REAL IntegrationsRepository on in-memory Drift → the REAL postgrest
// builder against an in-memory PostgREST (FakePostgrest), which records every
// write. Nothing between the HTTP answer and the recorded upsert is a double.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_ics_parser.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/runna_ics_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../helpers/fakes/fake_postgrest.dart';

const _userId = 'u-52';
const _feedToken = 'tok-5f2a9c0e';
const _feedUrl = 'https://cal.runna.test/feed/$_feedToken/calendar.ics';

IntegrationModel _runna() => IntegrationModel(
  id: 'i-runna',
  userId: _userId,
  provider: 'runna',
  accessToken: _feedUrl,
  providerAthleteId: 'runna-${RunnaSyncService.stableFeedFingerprint(_feedUrl)}',
  isActive: true,
  lastSyncStatus: 'success',
  createdAt: DateTime(2026, 9, 1, 8),
  updatedAt: DateTime(2026, 9, 1, 8),
);

void main() {
  late AppDatabase db;
  late FakePostgrest server;
  late IntegrationsRepository repository;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    server = FakePostgrest();
    server.tables['users'] = [
      {'id': _userId},
    ];
    await server.signIn(_userId);
    repository = IntegrationsRepository(
      database: db,
      supabase: server.client,
    );
    await repository.upsertIntegration(_runna());
  });

  RunnaSyncService syncService(http.Client feed) => RunnaSyncService(
    icsClient: RunnaIcsClient(httpClient: feed),
    parser: const RunnaIcsParser(),
    integrationsRepository: repository,
    activitiesRepository: ActivitiesRepository(
      supabase: server.client,
      database: db,
      deduplicationService: ActivityDeduplicationService(),
    ),
    transformer: const RunnaTransformer(),
    changeDetectionService: ChangeDetectionService(),
  );

  List<String?> sentErrors() => [
    for (final w in server.writes.where((w) => w.table == 'integrations'))
      for (final row in (w.body is List ? w.body as List : [w.body]))
        (row as Map)['last_sync_error'] as String?,
  ];

  /// The stored value is a wire code and carries nothing of the feed URL.
  void expectCode(String? stored, String code) {
    expect(stored, code);
    expect(SyncError.tryParse(stored), isNotNull);
    expect(stored, isNot(contains(_feedToken)));
    expect(stored, isNot(contains('runna.test')));
  }

  test('a calendar URL that answers 404 stores http_404', () async {
    final result = await syncService(
      MockClient((_) async => http.Response('Not Found', 404)),
    ).syncWorkouts(_userId);

    expect(result.success, isFalse);
    expectCode(result.error, 'http_404');
    final row = await repository.getIntegration(_userId, 'runna');
    expect(row!.lastSyncStatus, 'error');
    expectCode(row.lastSyncError, 'http_404');
    expectCode(sentErrors().last, 'http_404');
    expect(
      SyncError.tryParse(row.lastSyncError),
      const SyncError(SyncErrorCode.httpStatus, status: 404),
    );
  });

  test('a feed that is not a calendar stores unknown, never its message',
      () async {
    final result = await syncService(
      MockClient((_) async => http.Response('<html>login</html>', 200)),
    ).syncWorkouts(_userId);

    expect(result.success, isFalse);
    expectCode(result.error, 'unknown');
    final row = await repository.getIntegration(_userId, 'runna');
    expectCode(row!.lastSyncError, 'unknown');
    expectCode(sentErrors().last, 'unknown');
  });

  test('offline: the result carries network and the row is left alone',
      () async {
    // package:http wraps the socket failure in a ClientException whose
    // message names the URI; the client turns it into a NetworkException.
    final result = await syncService(
      MockClient((request) async {
        throw http.ClientException(
          'Connection failed: Network is unreachable',
          request.url,
        );
      }),
    ).syncWorkouts(_userId);

    expect(result.success, isFalse);
    expect(result.isNetworkError, isTrue);
    expectCode(result.error, 'network');
    // Transient, as for every other provider: no error stamped on the row.
    final row = await repository.getIntegration(_userId, 'runna');
    expect(row!.lastSyncStatus, 'success');
    expect(row.lastSyncError, isNull);
    for (final sent in sentErrors()) {
      expect(sent, isNull);
    }
  });

  test('a socket failure that escapes the client stores network', () async {
    final result = await syncService(
      MockClient((_) async {
        throw SocketException(
          'Connection failed $_feedUrl',
          osError: const OSError('Network is unreachable', 51),
        );
      }),
    ).syncWorkouts(_userId);

    expect(result.success, isFalse);
    expectCode(result.error, 'network');
    final row = await repository.getIntegration(_userId, 'runna');
    expect(row!.lastSyncStatus, 'error');
    expectCode(row.lastSyncError, 'network');
    expectCode(sentErrors().last, 'network');
  });
}
