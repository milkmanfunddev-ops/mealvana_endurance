/// Ticket 22 (Sentry MEALVANA-ENDURANCE-CY, C7; dev DEV-AA, DEV-AD):
/// TrainingPeaks answered `PUT /v2/workouts/plan/{id}` with a 400.
///
/// Root cause: TP refuses a plan write once `WorkoutDay` is more than 7 days
/// past (writeback.md § Constraints). CY saved a plan on 2026-09-26 for a
/// workout dated 2026-09-12; C7 was the disconnect strip walking workouts
/// back to February.
///
/// Seam: the REAL `TrainingPeaksApiClient` and the REAL Supabase client, both
/// over a fake HTTP transport that answers the way TP and PostgREST do, so
/// the 400 body travels the producer's path (HTTP response -> exception ->
/// Report `extra`). The OAuth service is real in the refresh test.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/tp_writeback_formatter.dart';
import 'package:mealvana_endurance/features/integrations/application/tp_writeback_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/data/http_retry_client.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    hide Activity;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../../helpers/fakes/recording_report.dart';

class MockTpOAuthService extends Mock implements TrainingPeaksOAuthService {}

class MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

const _workoutId = '3711546423';

/// The 400 envelope TP documents for a plan write it refuses
/// (docs/integration/api-exploration/training-peaks/examples/error-400-bad-request.json).
const _tp400Body =
    '{"error":"invalid_request","error_description":"WorkoutDay is outside '
    'the editable range"}';

/// A planned workout as `GET /v2/workouts/id/{id}?includeDescription=true`
/// returns it: naive local `WorkoutDay`, PascalCase, decimal hours, metres.
Map<String, dynamic> _tpWorkout(String workoutDay) => {
  'Id': int.parse(_workoutId),
  'AthleteId': 54321,
  'WorkoutDay': workoutDay,
  'StartTimePlanned': null,
  'WorkoutType': 'Run',
  'Title': 'Base run',
  // The athlete's own text plus the block an earlier push stored.
  'Description': TpWritebackFormatter.mergeBlockIntoDescription(
    'Easy aerobic',
    TpWritebackFormatter.formatPlanBlock(_plan(), durationMinutes: 60),
  ),
  'TotalTimePlanned': 1.0,
  'DistancePlanned': 10000.0,
  'TSSPlanned': null,
  'IFPlanned': null,
  'Tags': null,
  'Structure': null,
  'Locked': false,
  'Hidden': false,
};

/// Fake transport for TP's API and PostgREST.
class _Transport {
  _Transport({required this.workoutDay, this.putStatus = 400});

  final String workoutDay;
  final int putStatus;
  final List<http.Request> tpGets = [];
  final List<http.Request> tpPuts = [];
  final List<Map<String, dynamic>> ledgerCloses = [];
  final List<http.Request> ledgerDeletes = [];

  late final http.Client client = MockClient((req) async {
    final path = req.url.path;
    if (req.url.host.contains('trainingpeaks.com')) {
      if (req.method == 'GET' && path == '/v2/workouts/id/$_workoutId') {
        tpGets.add(req);
        return http.Response(
          jsonEncode(_tpWorkout(workoutDay)),
          200,
          request: req,
        );
      }
      if (req.method == 'PUT' && path == '/v2/workouts/plan/$_workoutId') {
        tpPuts.add(req);
        if (putStatus != 400) {
          return http.Response(req.body, putStatus, request: req);
        }
        return http.Response(_tp400Body, 400, request: req);
      }
    }
    if (path == '/rest/v1/tp_writeback_ledger') {
      if (req.method == 'POST') {
        return http.Response(
          jsonEncode({'id': 'ledger-1'}),
          201,
          headers: {'content-type': 'application/json'},
          request: req,
        );
      }
      if (req.method == 'PATCH') {
        ledgerCloses.add(jsonDecode(req.body) as Map<String, dynamic>);
        return http.Response('', 204, request: req);
      }
      if (req.method == 'DELETE') {
        ledgerDeletes.add(req);
        return http.Response('', 204, request: req);
      }
    }
    return http.Response(
      'unexpected ${req.method} ${req.url}',
      599,
      request: req,
    );
  });
}

const _noRetry = RetryConfig(maxRetries: 0, initialDelayMs: 0, maxDelayMs: 0);

Activity _tpActivity() => Activity(
  id: '68f60175-c2b0-457d-b2d1-fe7663dd30d6',
  userId: 'u1',
  activityType: ActivityType.running,
  title: 'Base run',
  scheduledDateTime: DateTime(2026, 9, 12, 7),
  syncedFromProvider: 'training_peaks',
  providerWorkoutId: _workoutId,
  durationMinutes: 60,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

NutritionPlan _plan() => NutritionPlan(
  id: 'p1',
  name: 'Plan',
  sections: [
    PlanSection(
      id: 'before',
      title: 'Before',
      foodItems: const [],
      carbsTarget: 60,
      fluidsTarget: 500,
    ),
  ],
);

void main() {
  setUpAll(() => registerFallbackValue(DateTime(2026)));

  /// The row as the server sends it for a live connection.
  IntegrationModel liveRow() => IntegrationModel(
    id: 'i-tp',
    userId: 'u1',
    provider: 'training_peaks',
    accessToken: 'tok',
    refreshToken: 'refresh',
    tokenExpiresAt: DateTime.now().add(const Duration(minutes: 59)),
    providerAthleteId: '54321',
    isActive: true,
    lastSyncStatus: 'success',
  );

  Future<
    ({
      TpWritebackService service,
      RecordingReport report,
      AppDatabase db,
      MockTpOAuthService oauth,
    })
  >
  build(
    _Transport transport, {
    required DateTime now,
    IntegrationModel? row,
    bool useLiveRow = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesService(await SharedPreferences.getInstance());
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final report = RecordingReport();
    final oauth = MockTpOAuthService();
    when(() => oauth.getValidAccessToken(any())).thenAnswer((_) async => 'tok');
    // Ticket 47: handleDisconnect reads the row before any token call.
    when(
      () => oauth.getIntegration(any()),
    ).thenAnswer((_) async => useLiveRow ? (row ?? liveRow()) : row);
    final api = TrainingPeaksApiClient(
      clientId: 'mealvana',
      clientSecret: 'secret',
      appVersion: '1.28.0',
      httpClient: transport.client,
      retryConfig: _noRetry,
      report: report,
    );
    final supabase = SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      httpClient: transport.client,
    );
    addTearDown(supabase.dispose);
    final service = TpWritebackService(
      apiClient: api,
      oauthService: oauth,
      preferencesService: prefs,
      database: db,
      supabase: supabase,
      report: report,
      clock: () => now,
    );
    return (service: service, report: report, db: db, oauth: oauth);
  }

  Future<void> seedLedger(AppDatabase db, {required int count}) async {
    for (var i = 0; i < count; i++) {
      await db
          .into(db.tpWritebackTable)
          .insert(
            TpWritebackTableCompanion(
              userId: const Value('u1'),
              activityId: Value('a-$i'),
              tpWorkoutId: Value(int.parse(_workoutId) + i),
              planHash: const Value('h'),
              pushedAt: Value(DateTime(2026, 9, 20)),
              status: const Value('active'),
            ),
          );
    }
  }

  group(
    'MEALVANA-ENDURANCE-CY: plan push for a workout past TP edit window',
    () {
      test('a plan saved 14 days after WorkoutDay is never PUT; the skip is '
          'noted and the ledger row closes as outside_edit_window', () async {
        final transport = _Transport(workoutDay: '2026-09-12T00:00:00');
        final h = await build(transport, now: DateTime(2026, 9, 26, 21, 52));

        await h.service.pushPlanToWorkout(
          userId: 'u1',
          activity: _tpActivity(),
          plan: _plan(),
        );

        expect(transport.tpPuts, isEmpty);
        expect(h.report.faults, isEmpty);
        expect(h.report.degradeds, isEmpty);
        expect(
          h.report.notes.map((n) => n.message),
          contains('TP write-back skipped: workout outside TP edit window'),
        );
        expect(transport.ledgerCloses, [
          {'status': 'failure', 'error': 'outside_edit_window'},
        ]);
      });

      test('a 400 inside the window is Degraded with the TP response body in '
          'extra, never a Fault', () async {
        final transport = _Transport(workoutDay: '2026-09-12T00:00:00');
        final h = await build(transport, now: DateTime(2026, 9, 14, 9));

        await h.service.pushPlanToWorkout(
          userId: 'u1',
          activity: _tpActivity(),
          plan: _plan(),
        );

        expect(transport.tpPuts, hasLength(1));
        expect(h.report.faults, isEmpty);
        expect(h.report.degradeds, hasLength(1));
        final extra = h.report.degradeds.single.extra!;
        expect(extra['statusCode'], 400);
        expect(extra['responseBody'], _tp400Body);
        expect(extra['workoutId'], _workoutId);
        expect(transport.ledgerCloses.single['error'], 'api_400');
      });
    },
  );

  group('MEALVANA-ENDURANCE-C7: disconnect strip over old workouts', () {
    test('a workout months past its day is not PUT; the local log is still '
        'purged and nothing is reported as a failure', () async {
      final transport = _Transport(workoutDay: '2026-02-07T00:00:00');
      final h = await build(transport, now: DateTime(2026, 9, 18, 20, 43));
      await h.db
          .into(h.db.tpWritebackTable)
          .insert(
            TpWritebackTableCompanion(
              userId: const Value('u1'),
              activityId: const Value('a-old'),
              tpWorkoutId: Value(int.parse(_workoutId)),
              planHash: const Value('h'),
              pushedAt: Value(DateTime(2026, 2, 6)),
              status: const Value('active'),
            ),
          );

      await h.service.handleDisconnect(userId: 'u1');

      expect(transport.tpPuts, isEmpty);
      expect(h.report.faults, isEmpty);
      expect(h.report.degradeds, isEmpty);
      expect(h.report.notes.single.data, containsPair('op', 'disconnect'));
      expect(await h.db.select(h.db.tpWritebackTable).get(), isEmpty);
    });
  });

  group('ticket 47 (32-005): disconnect of a refused connection', () {
    const skipNote =
        'TP write-back: disconnect strip skipped; connection needs reconnect';

    test('a requires_reauth row makes no token or TP call, notes the skip, '
        'and still purges the local log and the server ledger', () async {
      final transport = _Transport(workoutDay: '2026-09-25T00:00:00');
      // As 37 leaves a refused refresh on the row.
      final refused = IntegrationModel(
        id: 'i-tp',
        userId: 'u1',
        provider: 'training_peaks',
        accessToken: 'expired',
        refreshToken: 'dead-refresh',
        tokenExpiresAt: DateTime.now().subtract(const Duration(hours: 2)),
        providerAthleteId: '54321',
        isActive: true,
        lastSyncStatus: requiresReauthStatus,
        lastSyncError: reauthRequiredCode,
      );
      final h = await build(
        transport,
        now: DateTime(2026, 9, 26, 12),
        row: refused,
      );
      await seedLedger(h.db, count: 2);

      await h.service.handleDisconnect(userId: 'u1');

      verifyNever(() => h.oauth.getValidAccessToken(any()));
      expect(transport.tpGets, isEmpty, reason: 'no getWorkoutById');
      expect(transport.tpPuts, isEmpty, reason: 'no updatePlannedWorkout');
      expect(h.report.faults, isEmpty);
      expect(h.report.degradeds, isEmpty);
      final note = h.report.notes.singleWhere((n) => n.message == skipNote);
      expect(note.data, containsPair('entries', 2));
      expect(await h.db.select(h.db.tpWritebackTable).get(), isEmpty);
      expect(transport.ledgerDeletes, hasLength(1));
    });

    for (final (label, rowOf) in <(String, IntegrationModel? Function())>[
      ('a missing row', () => null),
      ('an inactive row', () => liveRow().copyWith(isActive: false)),
    ]) {
      test('$label is skipped the same way', () async {
        final row = rowOf();
        final transport = _Transport(workoutDay: '2026-09-25T00:00:00');
        final h = await build(
          transport,
          now: DateTime(2026, 9, 26, 12),
          row: row,
          useLiveRow: row != null,
        );
        await seedLedger(h.db, count: 1);

        await h.service.handleDisconnect(userId: 'u1');

        verifyNever(() => h.oauth.getValidAccessToken(any()));
        expect(transport.tpGets, isEmpty);
        expect(h.report.notes.map((n) => n.message), contains(skipNote));
        expect(await h.db.select(h.db.tpWritebackTable).get(), isEmpty);
        expect(transport.ledgerDeletes, hasLength(1));
      });
    }

    test('a live row still strips the block as before', () async {
      final transport = _Transport(
        workoutDay: '2026-09-25T00:00:00',
        putStatus: 200,
      );
      final h = await build(transport, now: DateTime(2026, 9, 26, 12));
      await seedLedger(h.db, count: 1);

      await h.service.handleDisconnect(userId: 'u1');

      verify(() => h.oauth.getValidAccessToken('u1')).called(1);
      expect(transport.tpGets, hasLength(1));
      expect(transport.tpPuts, hasLength(1));
      final put = jsonDecode(transport.tpPuts.single.body) as Map;
      expect(put['Description'], 'Easy aerobic');
      expect(h.report.notes.map((n) => n.message), isNot(contains(skipNote)));
      expect(await h.db.select(h.db.tpWritebackTable).get(), isEmpty);
      expect(transport.ledgerDeletes, hasLength(1));
    });
  });

  group('edit window boundaries', () {
    final now = DateTime(2026, 9, 26, 23, 59);
    bool inside(String day) =>
        TpWritebackService.isWithinTpEditWindow({'WorkoutDay': day}, now: now);

    test('7 days past is inside, 8 is outside', () {
      expect(inside('2026-09-19T00:00:00'), isTrue);
      expect(inside('2026-09-18T00:00:00'), isFalse);
    });

    test('a year ahead is inside, a year and a day is outside', () {
      expect(inside('2027-09-26T00:00:00'), isTrue);
      expect(inside('2027-09-27T00:00:00'), isFalse);
    });

    test('a missing or unreadable WorkoutDay lets TP decide', () {
      expect(
        TpWritebackService.isWithinTpEditWindow(const {}, now: now),
        isTrue,
      );
      expect(inside('not a date'), isTrue);
    });
  });

  group('DEV-AA / DEV-AD: token refresh 400 (invalid_grant)', () {
    test(
      'is Degraded with the response body, and parks the integration in '
      'requires_reauth so Connected Apps shows Reconnect (ticket 64)',
      () async {
        final report = RecordingReport();
        final repo = MockIntegrationsRepository();
        when(() => repo.getIntegration('u1', 'training_peaks')).thenAnswer(
          (_) async => IntegrationModel(
            userId: 'u1',
            provider: 'training_peaks',
            accessToken: 'old',
            refreshToken: 'dead-refresh',
            tokenExpiresAt: DateTime.now().subtract(const Duration(hours: 1)),
            providerAthleteId: '54321',
          ),
        );
        when(
          () => repo.updateSyncStatus(
            any(),
            any(),
            status: any(named: 'status'),
            error: any(named: 'error'),
          ),
        ).thenAnswer((_) async {});
        final api = TrainingPeaksApiClient(
          clientId: 'mealvana',
          clientSecret: 'secret',
          appVersion: '1.29.0',
          retryConfig: _noRetry,
          report: report,
          httpClient: MockClient((req) async {
            if (req.url.path == '/oauth/token') {
              return http.Response('{"error":"invalid_grant"}', 400);
            }
            return http.Response('unexpected', 599);
          }),
        );
        final oauth = TrainingPeaksOAuthService(
          apiClient: api,
          repository: repo,
          clientId: 'mealvana',
          report: report,
        );

        final token = await oauth.getValidAccessToken('u1');

        expect(token, isNull);
        expect(report.faults, isEmpty);
        final extra = report.degradeds.single.extra!;
        expect(extra['statusCode'], 400);
        expect(extra['responseBody'], '{"error":"invalid_grant"}');
        verify(
          () => repo.updateSyncStatus(
            'u1',
            'training_peaks',
            status: requiresReauthStatus,
            error: any(named: 'error'),
          ),
        ).called(1);
      },
    );
  });
}
