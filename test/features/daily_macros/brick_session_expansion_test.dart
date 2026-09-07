// The engine feed for a BRICK — producer→consumer seam.
//
// A brick is stored as ONE activity row whose `brick_metadata` JSON carries
// the legs. Until 2026-09-04 `_sessionFromActivityRow` sent the whole brick
// to `calculate-daily-macros-v6` as a single `running` session over the
// summed duration (`engineSport`'s `_ =>` default), so a run→bike→run brick
// priced every leg at the running rate — while the dashboard priced the same
// brick at the interim conservative rate, a ~2× on-screen contradiction
// (9,486 kcal intake target beside a 1,980 kcal projected burn).
// Bug: ops/data/bug-reports/2026-09-04-brick-priced-as-one-conservative-session.md
// INTERIM ruling request: qa/intake/2026-09-04-brick-per-leg-pricing-ratification.md
//
// Per the producer→consumer rule, the row under test is written through the
// REAL persistence path (a Drift insert with `brick_metadata` encoded exactly
// as `activity_mapper` writes it) and read back by the REAL query inside
// `DailyMacroService`; the assertion is on the wire payload the service hands
// the edge function.
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/features/daily_macros/application/daily_macro_service.dart';
import 'package:mealvana_endurance/features/daily_macros/data/daily_macro_targets_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

void main() {
  late AppDatabase database;
  late MockFunctionsClient functions;
  late DailyMacroService service;

  const userId = 'u1';
  final day = DateTime(2026, 9, 5);

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
    // Status 500 stops the flow right after the request is built — the
    // payload is what's under test, not the response handling.
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

  Future<void> insertActivity({
    required String id,
    required String activityType,
    int? durationMinutes,
    BrickMetadata? brick,
    String? brickMetadataRaw,
  }) async {
    await database.into(database.activitiesTable).insert(
          ActivitiesTableCompanion.insert(
            id: Value(id),
            userId: userId,
            activityType: activityType,
            title: '$id workout',
            scheduledDateTime: DateTime(day.year, day.month, day.day, 6),
            durationMinutes: Value(durationMinutes),
            // Exactly what activity_mapper persists: jsonEncode(toJson()).
            brickMetadata: Value(
              brickMetadataRaw ??
                  (brick != null ? jsonEncode(brick.toJson()) : null),
            ),
            createdAt: day,
            updatedAt: day,
          ),
        );
  }

  Future<List<dynamic>> sentSessions() async {
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

  BrickMetadata brickOf(List<(String, int)> legs) => BrickMetadata.fromJson({
        'segment_order': [for (final (sport, _) in legs) sport],
        'segments': [
          for (final (i, (sport, minutes)) in legs.indexed)
            {
              'sport': sport,
              'order': i + 1,
              'duration_minutes': minutes,
              'intensity': 'moderate',
            },
        ],
        'created_from_existing': false,
        'total_duration_minutes': legs.fold<int>(0, (s, l) => s + l.$2),
      });

  test('a brick row expands into one session PER LEG, each at its own sport',
      () async {
    // The reported Sept 5 brick: run 65 → bike 100 → run 144.
    await insertActivity(
      id: 'brick1',
      activityType: 'brick',
      durationMinutes: 309,
      brick: brickOf([('running', 65), ('cycling', 100), ('running', 144)]),
    );

    final sessions = await sentSessions();

    expect(sessions, hasLength(3));
    expect(
      sessions.map((s) => s['sport']),
      ['running', 'cycling', 'running'],
      reason: 'a bike leg must price at the cycling rate, not running',
    );
    expect(
      sessions.map((s) => s['duration_hr']),
      [65 / 60.0, 100 / 60.0, 144 / 60.0],
      reason: 'each leg carries its OWN duration, never the brick total',
    );
  });

  test('legs carry NO activity_id — whole-brick Garmin kcal must not attach '
      'to every leg', () async {
    // The server attaches per-session Garmin completion by activity_id; a
    // measured WHOLE-brick total attached to N legs would count N times on a
    // retrospective recalc. Allocation of a measured brick across formula
    // legs is an open ratification question (see the intake file).
    await insertActivity(
      id: 'brick1',
      activityType: 'brick',
      brick: brickOf([('swimming', 30), ('cycling', 67), ('running', 27)]),
    );

    final sessions = await sentSessions();

    expect(sessions.map((s) => s['activity_id']), everyElement(isNull));
  });

  test('the brick-level TSS is carried once, on the first leg only', () async {
    await insertActivity(
      id: 'brick1',
      activityType: 'brick',
      brick: brickOf([('running', 65), ('cycling', 100)]),
    );
    await database.customStatement(
      'UPDATE activities SET tss = 180.0 WHERE id = ?',
      ['brick1'],
    );

    final sessions = await sentSessions();

    expect(sessions.first['tss'], 180.0);
    expect(sessions.skip(1).map((s) => s['tss']), everyElement(isNull));
  });

  test('archived brick originals do NOT feed the engine — no double count '
      '(bug 2026-09-04: Daily Budget 8,313 vs 2,672 Active Energy)', () async {
    // Brick creation archives the grouped originals as status
    // 'archivedForBrick'. The activities service hides them everywhere, but
    // this service's raw SQL only excluded 'skipped' — so the engine was fed
    // the brick's legs PLUS the archived originals, pricing the workout
    // twice and inflating the intake target (fat is the TDEE residual, so
    // every double-counted kcal landed in the fat gram target).
    await insertActivity(
      id: 'brick1',
      activityType: 'brick',
      brick: brickOf([('running', 108), ('cycling', 100)]),
    );
    await insertActivity(
      id: 'run-orig',
      activityType: 'running',
      durationMinutes: 108,
    );
    await insertActivity(
      id: 'ride-orig',
      activityType: 'cycling',
      durationMinutes: 100,
    );
    await database.customStatement(
      "UPDATE activities SET status = 'archivedForBrick', brick_id = 'brick1' "
      "WHERE id IN ('run-orig', 'ride-orig')",
    );

    final sessions = await sentSessions();

    expect(sessions, hasLength(2),
        reason: 'only the brick legs — the archived originals are the same '
            'workout and must not be priced again');
    expect(sessions.map((s) => s['duration_hr']), [108 / 60.0, 100 / 60.0]);
  });

  test('a single-sport row is untouched: one session, its own activity_id',
      () async {
    await insertActivity(
      id: 'run1',
      activityType: 'running',
      durationMinutes: 60,
    );

    final sessions = await sentSessions();

    expect(sessions, hasLength(1));
    expect(sessions.single['sport'], 'running');
    expect(sessions.single['activity_id'], 'run1');
  });

  test('a brick with unparseable metadata falls back to ONE session rather '
      'than dropping the workout', () async {
    await insertActivity(
      id: 'brick1',
      activityType: 'brick',
      durationMinutes: 90,
      brickMetadataRaw: '{not valid json',
    );

    final sessions = await sentSessions();

    expect(sessions, hasLength(1));
    expect(sessions.single['duration_hr'], 1.5);
    expect(sessions.single['activity_id'], 'brick1');
  });
}
