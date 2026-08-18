// Q-016 — "Manual profile edits: which cached days recalculate" (RULED Xuan
// 2026-08-17, platform-resolution.md post-ratification addition):
//
//   any MANUAL write to an engine input invalidates TODAY and every FUTURE
//   cached daily plan; PAST days are never touched.
//
// The spec owns the policy; the app owns the mechanism. This suite pins the
// mechanism at three seams, against a REAL in-memory Drift database:
//   1. the repository window (`invalidateFromDate`) — inclusive of today,
//      forward-only, per-user;
//   2. the service entry point every manual write site calls
//      (`DailyMacroService.invalidateForManualInputChange`);
//   3. the engine-input diff that decides whether a profile save is a
//      manual engine-input write at all (`engineInputsDiffer`) — so unit
//      or gear changes never cost the athlete a recompute.
// The screen-level chain (Settings → Nutrition Profile → Save) is pinned in
// test/features/settings/nutrition_profile_save_invalidation_test.dart.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/application/daily_macro_service.dart';
import 'package:mealvana_endurance/features/daily_macros/data/daily_macro_targets_repository.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late AppDatabase database;
  late DailyMacroTargetsRepository repository;
  late DailyMacroService service;

  const userId = 'user-1';
  const otherUserId = 'user-2';

  // "Today" is a Wednesday mid-afternoon; the window is keyed by midnight.
  final today = DateTime(2026, 8, 19, 15, 30);
  final yesterday = DateTime(2026, 8, 18);
  final lastWeek = DateTime(2026, 8, 12);
  final todayMidnight = DateTime(2026, 8, 19);
  final tomorrow = DateTime(2026, 8, 20);
  final nextMonth = DateTime(2026, 9, 15);

  Future<void> seedCachedDay(String uid, DateTime date) async {
    final day = DateTime(date.year, date.month, date.day);
    await database.customStatement(
      '''INSERT OR REPLACE INTO daily_macro_targets
         (id, user_id, target_date, carb_g, prot_g, fat_g, tdee, rmr,
          session_kcal, neat_kcal, tef_kcal, mode, ea, ea_status,
          algorithm_version, needs_upload, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        '$uid-${day.millisecondsSinceEpoch}', uid, day.millisecondsSinceEpoch,
        300.0, 150.0, 70.0, 2600.0, 1600.0, 600.0, 300.0, 100.0,
        'prospective', 40.0, null, 'v6.0.0', 0, 0, 0,
      ],
    );
  }

  Future<Set<DateTime>> cachedDaysFor(String uid) async {
    final rows = await database
        .customSelect(
          'SELECT target_date FROM daily_macro_targets WHERE user_id = ?',
          variables: [Variable.withString(uid)],
        )
        .get();
    return rows
        .map((r) =>
            DateTime.fromMillisecondsSinceEpoch(r.read<int>('target_date')))
        .toSet();
  }

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DailyMacroTargetsRepository(
      database: database,
      supabase: MockSupabaseClient(),
    );
    service = DailyMacroService(
      repository: repository,
      database: database,
      supabase: MockSupabaseClient(),
    );
  });

  tearDown(() async => database.close());

  group('repository window — invalidateFromDate', () {
    test('drops today and every future day; leaves the past intact', () async {
      for (final d in [lastWeek, yesterday, todayMidnight, tomorrow, nextMonth]) {
        await seedCachedDay(userId, d);
      }
      await repository.invalidateFromDate(userId, today);
      expect(
        await cachedDaysFor(userId),
        equals({lastWeek, yesterday}),
        reason: 'past days are the historical record — never recalculated',
      );
    });

    test('is inclusive of today even when called mid-day', () async {
      await seedCachedDay(userId, todayMidnight);
      await repository.invalidateFromDate(userId, DateTime(2026, 8, 19, 23, 59));
      expect(await cachedDaysFor(userId), isEmpty);
    });

    test('never touches another user\'s cache', () async {
      await seedCachedDay(userId, tomorrow);
      await seedCachedDay(otherUserId, tomorrow);
      await repository.invalidateFromDate(userId, today);
      expect(await cachedDaysFor(otherUserId), equals({tomorrow}));
    });
  });

  group('service entry point — invalidateForManualInputChange (Q-016)', () {
    test('today + future gone, past kept — the ruled window', () async {
      for (final d in [lastWeek, yesterday, todayMidnight, tomorrow, nextMonth]) {
        await seedCachedDay(userId, d);
      }
      await service.invalidateForManualInputChange(userId, now: today);
      expect(await cachedDaysFor(userId), equals({lastWeek, yesterday}));
    });
  });

  group('engineInputsDiffer — what counts as a manual engine-input write', () {
    final base = UserProfile(
      id: userId,
      deviceId: 'd',
      gender: Gender.female,
      birthday: DateTime(1990, 5, 1),
      heightFeet: 5,
      heightInches: 6,
      weightPounds: 140,
      runsWithWaterBottle: false,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      appVersion: '1.0.0',
      bodyFatPct: 22,
      lifestyle: Lifestyle.mixed,
      typicalWeeklyHours: 8,
      carbCycleOptIn: false,
      trainingPhase: TrainingPhase.base,
    );

    test('every engine input counts', () {
      final cases = <String, UserProfile>{
        'sex': base.copyWith(gender: Gender.male),
        'age': base.copyWith(birthday: DateTime(1980, 5, 1)),
        'height': base.copyWith(heightInches: 9),
        'weight': base.copyWith(weightPounds: 150),
        'body fat': base.copyWith(bodyFatPct: 18),
        'lifestyle': base.copyWith(lifestyle: Lifestyle.active),
        'weekly hours': base.copyWith(typicalWeeklyHours: 12),
        'carb-cycle opt-in': base.copyWith(carbCycleOptIn: true),
        'training phase': base.copyWith(trainingPhase: TrainingPhase.build),
      };
      cases.forEach((field, changed) {
        expect(DailyMacroService.engineInputsDiffer(base, changed), isTrue,
            reason: '$field feeds the engine and must invalidate');
      });
    });

    test('non-engine edits never invalidate', () {
      final gear = base.copyWith(
        runsWithWaterBottle: true,
        unitSystem: UnitSystem.metric,
        firstName: 'Ravi',
        sweatRate: SweatRateCat.heavy,
      );
      expect(DailyMacroService.engineInputsDiffer(base, gear), isFalse,
          reason: 'units / gear / sweat / name never reach the engine');
      expect(DailyMacroService.engineInputsDiffer(base, base), isFalse);
    });
  });
}
