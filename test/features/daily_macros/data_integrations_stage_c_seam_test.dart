// Stage C seams — data-integrations@v1 (DI-12 day-bucketing + DI-7 pair rule).
//
// Producer→consumer discipline: rows are written through a REAL Drift insert
// (the shape activity_mapper persists) and read back by the REAL queries
// inside DailyMacroService; assertions are on the wire payload the service
// hands the edge function — never on the engine's own output.
//
// DI-12 (bucketing ruling, intake 2026-08-20 opt 1): the engine buckets a
// session by `actual_time ?? planned_time ?? scheduled_date_time` — the same
// key the workout card uses (Activity.displayTime) — so the engine day and
// the card day can never disagree (the ~25 kcal divergent-row repro).
//
// DI-7 (L-2 split): consumers read actual ?? planned AS A PAIR — a measured
// duration is never priced beside a planned distance.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart'
    as domain;
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/application/daily_macro_service.dart';
import 'package:mealvana_endurance/features/daily_macros/data/daily_macro_targets_repository.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/domain/session_input_resolver.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  late AppDatabase database;
  late MockFunctionsClient functions;
  late DailyMacroService service;

  const userId = 'u1';

  final profile = UserProfile(
    id: userId,
    deviceId: 'd',
    gender: Gender.female,
    birthday: DateTime(1990, 5, 1),
    heightFeet: 5,
    heightInches: 6,
    weightPounds: 110,
    runsWithWaterBottle: false,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    appVersion: '1.0.0',
    lifestyle: Lifestyle.mixed,
    trainingPhase: TrainingPhase.base,
  );

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    functions = MockFunctionsClient();
    final supabase = MockSupabaseClient();
    when(() => supabase.functions).thenReturn(functions);
    when(
      () => functions.invoke(any(), body: any(named: 'body')),
    ).thenAnswer(
      (_) async => FunctionResponse(status: 500, data: {'error': 'seam'}),
    );
    service = DailyMacroService(
      repository: DailyMacroTargetsRepository(
        database: database,
        supabase: supabase,
      ),
      database: database,
      supabase: supabase,
    );
  });

  tearDown(() async => database.close());

  Future<List<dynamic>> sentSessions(DateTime day) async {
    await expectLater(
      service.calculateForDate(userId, day, profile),
      throwsA(isA<DailyMacroCalculationException>()),
    );
    final body =
        verify(
              () => functions.invoke(any(), body: captureAny(named: 'body')),
            ).captured.single
            as Map<String, dynamic>;
    return body['sessions'] as List<dynamic>;
  }

  group('DI-12 — engine day == card day for every session', () {
    test('a row completed on a DIFFERENT day than scheduled moves to the '
        'actual day on BOTH surfaces', () async {
      final scheduled = DateTime(2026, 9, 5, 23, 30);
      final actual = DateTime(2026, 9, 6, 0, 10);

      await database.into(database.activitiesTable).insert(
            ActivitiesTableCompanion.insert(
              id: const Value('divergent-1'),
              userId: userId,
              activityType: 'running',
              title: 'Late-night run',
              scheduledDateTime: scheduled,
              status: const Value('completed'),
              plannedTime: Value(scheduled),
              actualTime: Value(actual),
              durationMinutes: const Value(45),
              actualDurationMinutes: const Value(44),
              createdAt: scheduled,
              updatedAt: actual,
            ),
          );

      // Engine: the session belongs to Sept 6 (the actual day) — the
      // scheduled day is EMPTY.
      final sept6 = await sentSessions(DateTime(2026, 9, 6));
      expect(sept6, hasLength(1), reason: 'engine buckets by actual_time');

      // Card surface: the same activity's day key (displayTime) is the same
      // Sept 6 — the PAIRED half of the assertion (DI-12): engine day and
      // card day derive from the same actual ?? planned ?? scheduled rule.
      final cardDay = domain.Activity(
        id: 'divergent-1',
        userId: userId,
        activityType: ActivityType.running,
        title: 'Late-night run',
        scheduledDateTime: scheduled,
        status: domain.ActivityStatus.completed,
        plannedTime: scheduled,
        actualTime: actual,
        createdAt: scheduled,
        updatedAt: actual,
      ).displayTime;
      expect(
        DateTime(cardDay.year, cardDay.month, cardDay.day),
        DateTime(2026, 9, 6),
      );
    });

    test('the scheduled day no longer double-counts the moved session',
        () async {
      final scheduled = DateTime(2026, 9, 5, 23, 30);
      final actual = DateTime(2026, 9, 6, 0, 10);

      await database.into(database.activitiesTable).insert(
            ActivitiesTableCompanion.insert(
              id: const Value('divergent-2'),
              userId: userId,
              activityType: 'running',
              title: 'Late-night run',
              scheduledDateTime: scheduled,
              status: const Value('completed'),
              plannedTime: Value(scheduled),
              actualTime: Value(actual),
              durationMinutes: const Value(45),
              createdAt: scheduled,
              updatedAt: actual,
            ),
          );

      final sept5 = await sentSessions(DateTime(2026, 9, 5));
      expect(
        sept5,
        isEmpty,
        reason: 'the session moved to its actual day; pricing it on the '
            'scheduled day too would double-count it',
      );
    });
  });

  group('DI-7 — the engine reads actual ?? planned AS A PAIR', () {
    test('a measured session prices on the measured pair, not a mixed one',
        () async {
      final day = DateTime(2026, 9, 5);
      await database.into(database.activitiesTable).insert(
            ActivitiesTableCompanion.insert(
              id: const Value('measured-1'),
              userId: userId,
              activityType: 'running',
              title: 'Verified run',
              scheduledDateTime: DateTime(2026, 9, 5, 6),
              status: const Value('completed'),
              actualTime: Value(DateTime(2026, 9, 5, 6, 3)),
              // Planned 8 mi / 60 min; measured 44 min / 5.1 mi — the
              // DI-DEV-1 shape. The engine must price 44 min, and must not
              // derive anything from the PLANNED 8 mi.
              durationMinutes: const Value(60),
              distanceMiles: const Value(8.0),
              actualDurationMinutes: const Value(44),
              actualDistanceMiles: const Value(5.1),
              createdAt: day,
              updatedAt: day,
            ),
          );

      final sessions = await sentSessions(day);
      expect(sessions, hasLength(1));
      expect(
        (sessions.single as Map)['duration_hr'],
        closeTo(44 / 60.0, 1e-9),
        reason: 'measured pair: actual_duration_minutes, never the planned 60',
      );
    });

    test('a planned session still prices on the planned family (ladder '
        'unchanged)', () async {
      final day = DateTime(2026, 9, 5);
      await database.into(database.activitiesTable).insert(
            ActivitiesTableCompanion.insert(
              id: const Value('planned-1'),
              userId: userId,
              activityType: 'running',
              title: 'Planned run',
              scheduledDateTime: DateTime(2026, 9, 5, 6),
              durationMinutes: const Value(60),
              distanceMiles: const Value(8.0),
              createdAt: day,
              updatedAt: day,
            ),
          );

      final sessions = await sentSessions(day);
      expect(sessions, hasLength(1));
      expect((sessions.single as Map)['duration_hr'], closeTo(1.0, 1e-9));
    });

    test('resolveMetricsPair never mixes families', () {
      final measured = SessionInputResolver.resolveMetricsPair(
        actualDurationMinutes: 44,
        actualDistanceMiles: null,
        durationMinutes: 60,
        distanceMiles: 8.0,
      );
      expect(measured.measured, isTrue);
      expect(measured.durationMinutes, 44);
      expect(
        measured.distanceMiles,
        isNull,
        reason: 'the planned 8 mi must NOT leak into the measured pair',
      );

      final planned = SessionInputResolver.resolveMetricsPair(
        actualDurationMinutes: null,
        actualDistanceMiles: null,
        durationMinutes: 60,
        distanceMiles: 8.0,
      );
      expect(planned.measured, isFalse);
      expect(planned.durationMinutes, 60);
      expect(planned.distanceMiles, 8.0);
    });
  });

  group('brick_metadata still round-trips through the seam', () {
    test('a brick row with stamped legs keeps expanding per leg', () async {
      final day = DateTime(2026, 9, 5);
      await database.into(database.activitiesTable).insert(
            ActivitiesTableCompanion.insert(
              id: const Value('brick-1'),
              userId: userId,
              activityType: 'brick',
              title: 'Brick',
              scheduledDateTime: DateTime(2026, 9, 5, 7),
              createdAt: day,
              updatedAt: day,
              brickMetadata: Value(
                jsonEncode({
                  'segment_order': ['cycling', 'running'],
                  'created_from_existing': false,
                  'total_duration_minutes': 90,
                  'segments': [
                    {
                      'sport': 'cycling',
                      'order': 1,
                      'duration_minutes': 60,
                      'intensity': 'moderate',
                      'garmin': {'summary_id': 'gb1'},
                    },
                    {
                      'sport': 'running',
                      'order': 2,
                      'duration_minutes': 30,
                      'intensity': 'moderate',
                    },
                  ],
                }),
              ),
            ),
          );

      final sessions = await sentSessions(day);
      expect(sessions, hasLength(2));
      expect(sessions.map((s) => (s as Map)['sport']), [
        'cycling',
        'running',
      ]);
    });
  });
}
