// I7 — the local cache seam round-trip (feature test plan; bug
// 2026-08-20-dashboard-weight-fallback-70kg).
//
// The bug that motivated this suite: the engine returned weight_kg, the
// domain model carried it, but the LOCAL row→domain mapper never populated it
// on the read path — so `targets.weightKg` was null for every athlete on
// every locally-cached day, and the dashboard silently priced all workouts at
// a 70-kg constant. Nothing pinned the seam: save a fully-populated
// DailyMacroTargets, read it back, and demand EVERY field the domain models
// survives. If someone adds a field to the domain and forgets the repository
// (either direction), this file goes red.
//
// The save path exercised here (DailyMacroTargetsRepository.saveToLocal) is
// exactly what DailyMacroService.calculateForDate / _calculateWeekOnce call
// after the edge function answers — this IS the production write seam.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/daily_macros/data/daily_macro_targets_repository.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/daily_macro_targets.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late AppDatabase database;
  late DailyMacroTargetsRepository repository;

  const userId = 'athlete-1';
  final targetDate = DateTime(2026, 8, 20);
  final createdAt = DateTime(2026, 8, 20, 6, 15, 42);
  final updatedAt = DateTime(2026, 8, 20, 7, 30, 5);

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DailyMacroTargetsRepository(
      database: database,
      supabase: MockSupabaseClient(),
    );
  });

  tearDown(() async => database.close());

  /// Every persisted field set to a distinctive, non-default value — so a
  /// dropped mapping can't hide behind a default. weight_kg is Xuan's real
  /// case: a 110-lb (49.9-kg) athlete, the population the 70-kg fallback
  /// hurt most.
  DailyMacroTargets fullTargets() => DailyMacroTargets(
        id: 'row-1',
        userId: userId,
        targetDate: targetDate,
        carbG: 321.5,
        protG: 101.25,
        fatG: 77.75,
        tdee: 2345.6,
        rmr: 1234.5,
        sessionKcal: 456.7,
        neatKcal: 289.1,
        tefKcal: 187.3,
        mode: 'retrospective',
        ea: 31.4,
        eaStatus: EaStatus.softWarning,
        algorithmVersion: 'v6.0.0',
        createdAt: createdAt,
        updatedAt: updatedAt,
        weightKg: 49.9,
        bodyFatPct: 21.5,
        energyBasis: 'pre_override',
      );

  test(
      'I7: every calculation_input field the domain models survives the '
      'save → local read round trip (weight_kg above all)', () async {
    await repository.saveToLocal(fullTargets());

    final read = await repository.getCachedForDate(userId, targetDate);

    expect(read, isNotNull, reason: 'the row we just saved must be served');
    final r = read!;

    // Scalar columns.
    expect(r.id, 'row-1');
    expect(r.userId, userId);
    expect(r.targetDate, DateTime(2026, 8, 20),
        reason: 'target_date is normalized to midnight');
    expect(r.carbG, 321.5);
    expect(r.protG, 101.25);
    expect(r.fatG, 77.75);
    expect(r.tdee, 2345.6);
    expect(r.rmr, 1234.5);
    expect(r.sessionKcal, 456.7);
    expect(r.neatKcal, 289.1);
    expect(r.tefKcal, 187.3);
    expect(r.mode, 'retrospective');
    expect(r.ea, 31.4);
    expect(r.eaStatus, EaStatus.softWarning);
    expect(r.algorithmVersion, 'v6.0.0');
    expect(r.createdAt, createdAt);
    expect(r.updatedAt, updatedAt);

    // calculation_input fields — the seam the 70-kg bug fell through.
    expect(r.weightKg, 49.9,
        reason:
            'weight_kg MUST survive the local cache: F4 session cost is '
            'exactly linear in body weight (I6); losing it here is how every '
            'athlete got priced at 70 kg '
            '(2026-08-20-dashboard-weight-fallback-70kg)');
    expect(r.bodyFatPct, 21.5);
    expect(r.energyBasis, 'pre_override',
        reason:
            'Q-009: a pre_override day must keep suppressing surplus copy on '
            'cached reads, not silently revert to as_computed');

    // Documented fresh-calculation transients — intentionally NOT cached.
    expect(r.sources, isNull,
        reason: 'sources are documented as fresh-calc only (see domain doc)');
    expect(r.delta, isNull,
        reason: 'delta is documented as fresh-calc only (F27 recalc path)');
  });

  test('I7: the batched week read maps calculation_input identically',
      () async {
    await repository.saveToLocal(fullTargets());

    // 2026-08-20 is a Thursday; the Sunday-start week is 2026-08-16.
    final week = await repository.getCachedForWeek(userId, DateTime(2026, 8, 16));
    final r = week[targetDate.millisecondsSinceEpoch];

    expect(r, isNotNull);
    expect(r!.weightKg, 49.9);
    expect(r.bodyFatPct, 21.5);
    expect(r.energyBasis, 'pre_override');
  });

  test(
      'a legacy row with no calculation_input reads back with the fields '
      'ABSENT — never invented', () async {
    // Pre-fix rows were written without the column. Seed one directly.
    await database.customStatement(
      '''INSERT INTO daily_macro_targets
         (id, user_id, target_date, carb_g, prot_g, fat_g, tdee, rmr,
          session_kcal, mode, algorithm_version, needs_upload,
          created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'legacy-1',
        userId,
        targetDate.millisecondsSinceEpoch,
        300.0,
        150.0,
        70.0,
        2600.0,
        1600.0,
        600.0,
        'prospective',
        'v6.0.0',
        0,
        createdAt.millisecondsSinceEpoch,
        updatedAt.millisecondsSinceEpoch,
      ],
    );

    final r = await repository.getCachedForDate(userId, targetDate);

    expect(r, isNotNull);
    expect(r!.weightKg, isNull,
        reason: 'an absent weight must surface as absent, not as a constant');
    expect(r.bodyFatPct, isNull);
    expect(r.energyBasis, 'as_computed');
  });

  test('corrupt calculation_input JSON is tolerated as absent', () async {
    await database.customStatement(
      '''INSERT INTO daily_macro_targets
         (id, user_id, target_date, carb_g, prot_g, fat_g, tdee, rmr,
          session_kcal, mode, calculation_input, algorithm_version,
          needs_upload, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'corrupt-1',
        userId,
        targetDate.millisecondsSinceEpoch,
        300.0,
        150.0,
        70.0,
        2600.0,
        1600.0,
        600.0,
        'prospective',
        '{not valid json',
        'v6.0.0',
        0,
        createdAt.millisecondsSinceEpoch,
        updatedAt.millisecondsSinceEpoch,
      ],
    );

    final r = await repository.getCachedForDate(userId, targetDate);

    expect(r, isNotNull, reason: 'a bad JSON blob must not kill the day');
    expect(r!.weightKg, isNull);
    expect(r.energyBasis, 'as_computed');
  });

  group('I7 remote leg — toJson→fromJson (ops 2026-08-20-…-tojson-drops-calculation-input)', () {
    test('the calculation_input trio survives the Supabase payload round trip',
        () {
      final t = DailyMacroTargets(
        id: 't1',
        userId: 'u1',
        targetDate: DateTime(2026, 8, 20),
        carbG: 500,
        protG: 120,
        fatG: 100,
        tdee: 3200,
        rmr: 1500,
        sessionKcal: 700,
        mode: 'prospective',
        algorithmVersion: 'v6.0.0',
        createdAt: DateTime(2026, 8, 20),
        updatedAt: DateTime(2026, 8, 20),
        weightKg: 49.9,
        bodyFatPct: 21.0,
        energyBasis: 'pre_override',
      );
      final json = t.toJson();
      expect(json['calculation_input'], isA<Map>(),
          reason: 'the upsert payload must carry calculation_input '
              '(the remote table has the jsonb column)');
      final back = DailyMacroTargets.fromEdgeFunctionResponse(
        id: 't1',
        userId: 'u1',
        targetDate: DateTime(2026, 8, 20),
        json: json,
      );
      expect(back.weightKg, 49.9);
      expect(back.bodyFatPct, 21.0);
      expect(back.energyBasis, 'pre_override');
    });

    test('flat engine-response keys still win over nested calculation_input',
        () {
      final back = DailyMacroTargets.fromEdgeFunctionResponse(
        id: 'x',
        userId: 'u1',
        targetDate: DateTime(2026, 8, 20),
        json: {
          'carb_g': 1,
          'prot_g': 1,
          'fat_g': 1,
          'tdee': 1,
          'rmr': 1,
          'session_kcal': 0,
          'weight_kg': 75.0,
          'calculation_input': {
            'weight_kg': 49.9,
            'energy_basis': 'pre_override',
          },
        },
      );
      expect(back.weightKg, 75.0, reason: 'flat (engine) key wins');
      expect(back.energyBasis, 'pre_override',
          reason: 'nested fills what flat omits');
    });
  });
}
