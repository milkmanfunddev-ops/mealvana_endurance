// Ticket 73 (testing-wave develop-2026-10): every provider's sync failure
// goes through one step (`recordSyncFailure`), so the same failure leaves the
// same status and code on the integration row:
//   offline → error / network;  a refused refresh (401) → requires_reauth /
//   reauth_required;  a 404 → error / http_404;  a Runna page that is not a
//   calendar → error / not_a_calendar;  a row the athlete disconnected while
//   the sync ran → no write (ticket 64's guard, noted to Sentry).
// A following successful sync writes success and clears the error.
//
// Seam: the provider's HTTP answer → the REAL API client → the REAL sync
// service → the REAL IntegrationsRepository on in-memory Drift → the REAL
// postgrest builder against an in-memory PostgREST (FakePostgrest), which
// records every write. Nothing between the HTTP answer and the recorded
// upsert is a double. The answers are shaped as each provider sends them
// (token endpoint JSON, Final Surge's `Success`/`Workouts` envelope, an ICS
// body), never built from the code under test.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_ics_parser.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_transformer.dart';
import 'package:mealvana_endurance/features/integrations/application/sync_failure_recorder.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/features/integrations/application/vdot_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/vdot_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/final_surge_api_client.dart';
import 'package:mealvana_endurance/features/integrations/data/http_retry_client.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/runna_ics_client.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/data/vdot_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';

const _userId = 'u-73';
const _noRetry = RetryConfig(maxRetries: 0, initialDelayMs: 0, maxDelayMs: 0);
const _skipNote = 'Sync status not written: integration inactive or missing';

/// How the provider answers the next request.
enum _Answer { ok, offline, refusedRefresh, notFound, notACalendar }

/// One provider under test: its row, its sync, and its producer-shaped
/// answer for a data request that succeeds.
class _Provider {
  const _Provider(this.id, this.okBody);

  final String id;
  final String okBody;
}

const _tp = _Provider('training_peaks', '[]');
const _fs = _Provider('final_surge', '{"Success":true,"Workouts":[]}');
const _vdot = _Provider('vdot', '[]');
const _runna = _Provider(
  'runna',
  'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//Runna//EN\r\nEND:VCALENDAR\r\n',
);

/// The token endpoint's answer to a refresh, as TP, Final Surge and V.O2
/// send it (snake_case; FS adds the athlete id at the root).
const _tokenJson =
    '{"access_token":"fresh-access","refresh_token":"fresh-refresh",'
    '"expires_in":3600,"token_type":"Bearer","id":"ath-1"}';

const _runnaFeed = 'https://cal.runna.test/feed/tok-73/calendar.ics';

IntegrationModel _row(_Provider p, {required bool expired}) => IntegrationModel(
  id: 'i-${p.id}',
  userId: _userId,
  provider: p.id,
  accessToken: p == _runna ? _runnaFeed : 'stale-access',
  refreshToken: p == _runna ? null : 'stale-refresh',
  tokenExpiresAt: p == _runna
      ? null
      : expired
      ? DateTime.now().subtract(const Duration(hours: 3))
      : DateTime.now().add(const Duration(days: 1)),
  providerAthleteId: 'ath-1',
  isActive: true,
  lastSyncStatus: 'success',
  createdAt: DateTime(2026, 9, 1, 8),
  updatedAt: DateTime(2026, 9, 1, 8),
);

void main() {
  late AppDatabase db;
  late FakePostgrest server;
  late IntegrationsRepository repository;
  late RecordingReport report;
  late _Answer answer;

  /// Per-provider answers, over [answer] (two providers failing at once).
  final answerFor = <String, _Answer>{};

  /// Runs before the provider answers (the athlete taps Disconnect while
  /// the request is in flight).
  Future<void> Function()? beforeAnswer;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    server = FakePostgrest();
    server.tables['users'] = [
      {'id': _userId},
    ];
    await server.signIn(_userId);
    report = RecordingReport();
    repository = IntegrationsRepository(
      database: db,
      supabase: server.client,
      report: report,
    );
    answer = _Answer.ok;
    answerFor.clear();
    beforeAnswer = null;
  });

  http.Client providerHttp(_Provider p) => MockClient((request) async {
    final hook = beforeAnswer;
    if (hook != null) await hook();
    final isToken = request.url.path.endsWith('/oauth/token');
    switch (answerFor[p.id] ?? answer) {
      case _Answer.offline:
        // package:http on IO surfaces the socket failure; Runna's client
        // sees it as a ClientException, the retry client as a socket error.
        if (p == _runna) {
          throw http.ClientException(
            'Connection failed: Network is unreachable',
            request.url,
          );
        }
        throw SocketException(
          'Connection failed',
          osError: const OSError('Network is unreachable', 51),
          address: InternetAddress('203.0.113.7'),
          port: 443,
        );
      case _Answer.refusedRefresh:
        if (isToken) {
          return http.Response('{"error":"invalid_grant"}', 401);
        }
        return http.Response(p.okBody, 200);
      case _Answer.notFound:
        if (isToken) return http.Response(_tokenJson, 200);
        return http.Response('Not Found', 404);
      case _Answer.notACalendar:
        return http.Response('<html><body>Sign in to Runna</body></html>', 200);
      case _Answer.ok:
        if (isToken) return http.Response(_tokenJson, 200);
        return http.Response(p.okBody, 200);
    }
  });

  ActivitiesRepository activities() => ActivitiesRepository(
    supabase: server.client,
    database: db,
    deduplicationService: ActivityDeduplicationService(),
  );

  /// Runs [p]'s real sync once and returns whether it succeeded.
  Future<bool> sync(_Provider p) async {
    final httpClient = providerHttp(p);
    switch (p) {
      case _tp:
        final r = await TrainingPeaksSyncService(
          apiClient: TrainingPeaksApiClient(
            clientId: 'cid',
            clientSecret: 'secret',
            appVersion: 'test',
            httpClient: httpClient,
            retryConfig: _noRetry,
          ),
          integrationsRepository: repository,
          activitiesRepository: activities(),
          transformer: const TrainingPeaksTransformer(),
          changeDetectionService: ChangeDetectionService(),
          report: report,
        ).syncWorkouts(_userId);
        return r.success;
      case _fs:
        final r = await FinalSurgeSyncService(
          apiClient: FinalSurgeApiClient(
            clientId: 'cid',
            clientSecret: 'secret',
            httpClient: httpClient,
            retryConfig: _noRetry,
          ),
          integrationsRepository: repository,
          activitiesRepository: activities(),
          transformer: const FinalSurgeTransformer(),
          changeDetectionService: ChangeDetectionService(),
          report: report,
        ).syncWorkouts(_userId);
        return r.success;
      case _vdot:
        final r = await VdotSyncService(
          apiClient: VdotApiClient(
            clientId: 'vdot',
            clientSecret: 'secret',
            authBaseUrl: 'https://vdot.test',
            apiBaseUrl: 'https://vdot.test/api',
            httpClient: httpClient,
            retryConfig: _noRetry,
          ),
          integrationsRepository: repository,
          activitiesRepository: activities(),
          transformer: const VdotTransformer(),
          changeDetectionService: ChangeDetectionService(),
          report: report,
        ).syncWorkouts(_userId);
        return r.success;
      default:
        final r = await RunnaSyncService(
          icsClient: RunnaIcsClient(httpClient: httpClient),
          parser: const RunnaIcsParser(),
          integrationsRepository: repository,
          activitiesRepository: activities(),
          transformer: const RunnaTransformer(),
          changeDetectionService: ChangeDetectionService(),
          report: report,
        ).syncWorkouts(_userId);
        return r.success;
    }
  }

  Map<String, dynamic> lastUpsert(String provider) {
    final rows = [
      for (final w in server.writes.where((w) => w.table == 'integrations'))
        for (final row in (w.body is List ? w.body as List : [w.body]))
          (row as Map).cast<String, dynamic>(),
    ].where((r) => r['provider'] == provider);
    return rows.last;
  }

  /// The row and the server both hold [status] / [code].
  Future<void> expectStored(_Provider p, String status, String? code) async {
    final row = await repository.getIntegration(_userId, p.id);
    expect(row!.lastSyncStatus, status, reason: '${p.id} local status');
    expect(row.lastSyncError, code, reason: '${p.id} local code');
    final sent = lastUpsert(p.id);
    expect(sent['last_sync_status'], status, reason: '${p.id} sent status');
    expect(sent['last_sync_error'], code, reason: '${p.id} sent code');
  }

  /// A following successful sync clears both columns.
  Future<void> expectSuccessClears(_Provider p) async {
    answer = _Answer.ok;
    expect(await sync(p), isTrue, reason: '${p.id} follow-up sync');
    await expectStored(p, 'success', null);
  }

  for (final p in [_tp, _fs, _vdot, _runna]) {
    group(p.id, () {
      test('offline → error / network, then a success clears it', () async {
        await repository.upsertIntegration(_row(p, expired: false));
        answer = _Answer.offline;

        expect(await sync(p), isFalse);

        await expectStored(p, 'error', 'network');
        await expectSuccessClears(p);
      });

      test('a 404 → error / http_404, then a success clears it', () async {
        await repository.upsertIntegration(_row(p, expired: false));
        answer = _Answer.notFound;

        expect(await sync(p), isFalse);

        await expectStored(p, 'error', 'http_404');
        await expectSuccessClears(p);
      });

      if (p != _runna) {
        test('a refused refresh (401) → requires_reauth / reauth_required, '
            'then a success clears it', () async {
          await repository.upsertIntegration(_row(p, expired: true));
          answer = _Answer.refusedRefresh;

          expect(await sync(p), isFalse);

          await expectStored(p, requiresReauthStatus, 'reauth_required');
          final row = await repository.getIntegration(_userId, p.id);
          expect(row!.needsReconnect, isTrue);
          await expectSuccessClears(p);
        });
      }

      if (p == _runna) {
        test('a page that is not a calendar → error / not_a_calendar, then '
            'a success clears it', () async {
          await repository.upsertIntegration(_row(p, expired: false));
          answer = _Answer.notACalendar;

          expect(await sync(p), isFalse);

          await expectStored(p, 'error', 'not_a_calendar');
          await expectSuccessClears(p);
        });

        test('a link that is not a URL → error / not_a_calendar', () async {
          await repository.upsertIntegration(
            _row(p, expired: false).copyWith(accessToken: 'not a link'),
          );

          expect(await sync(p), isFalse);

          await expectStored(p, 'error', 'not_a_calendar');
        });
      }

      // #77: a sync that fails after the athlete tapped Disconnect.
      test('disconnected while the sync ran → no write, noted', () async {
        await repository.upsertIntegration(_row(p, expired: false));
        answer = _Answer.offline;
        IntegrationModel? disconnected;
        var writesAfterDisconnect = 0;
        beforeAnswer = () async {
          beforeAnswer = null;
          await repository.deactivateIntegration(_userId, p.id);
          disconnected = await repository.getIntegration(_userId, p.id);
          writesAfterDisconnect = server.writes.length;
        };

        expect(await sync(p), isFalse);

        final row = await repository.getIntegration(_userId, p.id);
        expect(row!.isActive, isFalse);
        expect(row.lastSyncStatus, disconnected!.lastSyncStatus);
        expect(row.lastSyncError, disconnected!.lastSyncError);
        expect(row.updatedAt, disconnected!.updatedAt);
        expect(server.writes.length, writesAfterDisconnect);
        final notes = report.notes.where((n) => n.message == _skipNote);
        expect(notes, hasLength(1));
        expect(notes.single.data, {
          'provider': p.id,
          'status': 'error',
          'rowFound': true,
        });
      });
    });
  }

  group('garmin (the controller mirror of the server requires_reauth)', () {
    IntegrationModel garmin() => IntegrationModel(
      id: 'i-garmin',
      userId: _userId,
      provider: 'garmin',
      accessToken: '',
      providerAthleteId: 'garmin-1',
      isActive: true,
      lastSyncStatus: 'success',
      createdAt: DateTime(2026, 9, 1, 8),
      updatedAt: DateTime(2026, 9, 1, 8),
    );

    test('recordReauthRequired → requires_reauth / reauth_required', () async {
      await repository.upsertIntegration(garmin());

      final code = await repository.recordReauthRequired(_userId, 'garmin');

      expect(code, 'reauth_required');
      await expectStored(
        const _Provider('garmin', ''),
        requiresReauthStatus,
        'reauth_required',
      );
    });

    test('on a disconnected row it writes nothing and is noted', () async {
      await repository.upsertIntegration(garmin());
      await repository.deactivateIntegration(_userId, 'garmin');
      final writesBefore = server.writes.length;

      await repository.recordReauthRequired(_userId, 'garmin');

      expect(server.writes.length, writesBefore);
      expect(report.notes.where((n) => n.message == _skipNote), hasLength(1));
    });
  });

  // #77: two providers failing at once write their own rows, each its code.
  test('two providers failing at once each keep their own code', () async {
    await repository.upsertIntegration(_row(_vdot, expired: false));
    await repository.upsertIntegration(_row(_runna, expired: false));
    answerFor[_vdot.id] = _Answer.offline;
    answerFor[_runna.id] = _Answer.notACalendar;

    await Future.wait([sync(_vdot), sync(_runna)]);

    await expectStored(_vdot, 'error', 'network');
    await expectStored(_runna, 'error', 'not_a_calendar');
  });
}
