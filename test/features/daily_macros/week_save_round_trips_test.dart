// Ticket 24 (Sentry MEALVANA-ENDURANCE-DEV-97, "N+1 Query" on `main`).
//
// The event: after one week calculation the `main` transaction carried
//   INSERT OR REPLACE INTO daily_macro_targets ...      (once per day)
//   POST /rest/v1/daily_macro_targets?on_conflict=...   (once per day)
// because `_calculateWeekOnce` saved each computed day on its own.
//
// Seam: the real DailyMacroService and DailyMacroTargetsRepository, a real
// SupabaseClient whose HTTP is answered in memory (the edge function's week
// response, PostgREST's 201), and a real in-memory Drift database whose
// executor counts statements.
import 'dart:convert';

import 'package:drift/drift.dart' show ApplyInterceptor, Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/application/daily_macro_service.dart';
import 'package:mealvana_endurance/features/daily_macros/data/daily_macro_targets_repository.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/fakes/recording_report.dart';
import '../../helpers/query_counter.dart';

void main() {
  const userId = 'u-week';

  final profile = UserProfile(
    id: userId,
    deviceId: 'd',
    gender: Gender.female,
    birthday: DateTime(1990, 5, 1),
    heightFeet: 5,
    heightInches: 6,
    weightPounds: 130,
    runsWithWaterBottle: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    appVersion: '1.0.0',
    lifestyle: Lifestyle.mixed,
    trainingPhase: TrainingPhase.base,
  );

  /// One day as `calculate-daily-macros-v6` answers it (scope: week).
  Map<String, dynamic> engineDay(int i) => {
    'carb_g': 310.4 + i,
    'prot_g': 112.0,
    'fat_g': 71.3,
    'tdee': 2480.0,
    'rmr': 1390.0,
    'session_kcal': 420.0 + 10 * i,
    'neat_kcal': 310.0,
    'tef_kcal': 220.0,
    'mode': 'prospective',
    'ea': 41.2,
    'ea_status': 'adequate',
    'algorithm_version': 'v6.1.0',
    'weight_kg': 58.97,
    'energy_basis': 'as_computed',
  };

  test('a computed week is saved in ONE local batch and ONE remote upsert, '
      'not one of each per day', () async {
    final counter = QueryCounter();
    final database = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(counter),
    );
    addTearDown(database.close);

    final restWrites = <http.Request>[];
    final supabase = SupabaseClient(
      'https://test.supabase.co',
      'anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        final path = request.url.path;
        if (path == '/functions/v1/calculate-daily-macros-v6') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final days = (body['days'] as List).length;
          return http.Response(
            jsonEncode({
              'days': [for (var i = 0; i < days; i++) engineDay(i)],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path == '/rest/v1/daily_macro_targets') {
          restWrites.add(request);
          return http.Response('', 201, request: request);
        }
        return http.Response('unexpected $path', 404);
      }),
    );
    addTearDown(supabase.dispose);

    final report = RecordingReport();
    final service = DailyMacroService(
      repository: DailyMacroTargetsRepository(
        database: database,
        supabase: supabase,
        report: report,
      ),
      database: database,
      supabase: supabase,
      report: report,
    );

    counter.reset();
    final week = await service.calculateWeek(
      userId,
      DateTime(2026, 9, 23),
      profile,
    );
    // The remote save is fire-and-forget; let it land.
    for (var i = 0; i < 50 && restWrites.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(week.whereType<Object>(), hasLength(7));

    // Local: one batch carrying the seven upserts, no per-day statements.
    expect(
      counter.customsMatching('INSERT OR REPLACE INTO daily_macro_targets'),
      0,
      reason: 'no per-day INSERT outside the batch',
    );
    expect(counter.batches, hasLength(1));
    expect(counter.batches.single.arguments, hasLength(7));

    // Remote: one POST carrying the seven rows.
    expect(restWrites, hasLength(1));
    expect(restWrites.single.method, 'POST');
    expect(
      restWrites.single.url.queryParameters['on_conflict'],
      'user_id,target_date',
    );
    final rows = jsonDecode(restWrites.single.body) as List<dynamic>;
    expect(rows, hasLength(7));
    expect(
      rows.map((r) => (r as Map)['target_date']).toSet(),
      hasLength(7),
      reason: 'one row per day of the week',
    );

    // And the batch really wrote them.
    final stored = await database
        .customSelect(
          'SELECT COUNT(*) AS n FROM daily_macro_targets WHERE user_id = ?',
          variables: [Variable.withString(userId)],
        )
        .getSingle();
    expect(stored.read<int>('n'), 7);
    expect(report.faults, isEmpty);
  });
}
