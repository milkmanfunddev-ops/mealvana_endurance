// Ticket 135 (testing-wave; Finding 112-012, Lee 2026-09-26): a Recent row
// keeps the meal's per-serving numbers, so 1 serving always means the
// original amount, and same-named meals with different items both show.
//
// Before: Recent kept the newest row per lowercase name. A re-log of
// "Oatmeal + raisins" at 2 servings (408 kcal) became the row Recent showed
// and re-logged at "1 serving", doubling again; and the two-item "Rice cake
// and Almond butter" vanished behind a later one-line copy of the same name.
//
// Seam test (docs/test/README.md): rows are written through the real
// repository into a real in-memory Drift and read back through
// [MealLogRepository.getRecentLogs] / [watchRecentLogs], the Recent tab's
// reads. Only the wire is a no-op.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _user = '607f9dd5-6fa7-48ee-a628-720d4a0506a1';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _QuietWire extends MealLogRepository {
  _QuietWire({required super.database})
    : super(
        supabase: _MockSupabaseClient(),
        logger: const NoopAppLogger(),
        sentry: const NoopSentryReporter(),
      );

  @override
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {}
}

const _oats = MealComponent(
  name: 'Rolled oats',
  portion: '1/2 cup dry',
  calories: 150,
  carbG: 27,
  proteinG: 5,
  fatG: 2.5,
  sodiumMg: 0,
);
const _raisins = MealComponent(
  name: 'Raisins',
  portion: '2 tbsp',
  calories: 54,
  carbG: 14,
  proteinG: 0.6,
  fatG: 0.1,
);

MealLog _log({
  required String name,
  required List<MealComponent> components,
  required int calories,
  double servings = 1,
  MealSlot? slot,
  required DateTime at,
}) => MealLog(
  id: '',
  userId: _user,
  logDate: '2026-09-25',
  slot: slot,
  name: name,
  source: MealLogSource.manual,
  components: components,
  calories: calories,
  carbsG: 41,
  proteinG: 5.6,
  fatG: 2.6,
  sodiumMg: 0,
  servings: servings,
  createdAt: at,
  updatedAt: at,
);

void main() {
  late AppDatabase db;
  late _QuietWire repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = _QuietWire(database: db);
  });

  tearDown(() async {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await db.close();
  });

  test(
    'a re-log at 2 servings folds into one Recent row at the base',
    () async {
      await repo.insertLog(
        _log(
          name: 'Oatmeal + raisins',
          components: const [_oats, _raisins],
          calories: 204,
          slot: MealSlot.breakfast,
          at: DateTime.utc(2026, 9, 25, 8),
        ),
      );
      // The 2-serving re-log, as relogMeal writes it: items doubled, totals
      // doubled, servings 2.
      await repo.insertLog(
        _log(
          name: 'Oatmeal + raisins',
          components: const [
            MealComponent(
              name: 'Rolled oats',
              portion: '1 cup dry',
              calories: 300,
              carbG: 54,
              proteinG: 10,
              fatG: 5,
              sodiumMg: 0,
            ),
            MealComponent(
              name: 'Raisins',
              portion: '4 tbsp',
              calories: 108,
              carbG: 28,
              proteinG: 1.2,
              fatG: 0.2,
            ),
          ],
          calories: 408,
          servings: 2,
          slot: MealSlot.dinner,
          at: DateTime.utc(2026, 9, 25, 23, 24),
        ).copyWith(carbsG: 82, proteinG: 11.2, fatG: 5.2),
      );

      final recent = await repo.getRecentLogs(_user);

      expect(recent, hasLength(1), reason: 'same meal, same items');
      final row = recent.single;
      expect(row.servings, 1);
      expect(row.calories, 204, reason: '1 serving is the original amount');
      expect(row.carbsG, 41);
      expect(row.components.map((c) => c.portion), ['0.5 cup dry', '2 tbsp']);
      expect(row.components.first.calories, 150);
      expect(
        row.slot,
        MealSlot.dinner,
        reason: 'the newest log is the source; only its numbers are divided',
      );
    },
  );

  test('two same-named meals with different items both show', () async {
    await repo.insertLog(
      _log(
        name: 'Rice cake and Almond butter',
        components: const [
          MealComponent(name: 'Rice cake', portion: '2 cakes', calories: 70),
          MealComponent(name: 'Almond butter', portion: '1 tbsp', calories: 98),
        ],
        calories: 168,
        at: DateTime.utc(2026, 9, 23, 13, 46),
      ),
    );
    // The one-line copy from 26-002 that used to hide the two-item meal.
    await repo.insertLog(
      _log(
        name: 'Rice cake and Almond butter',
        components: const [
          MealComponent(
            name: 'Rice cake and Almond butter',
            portion: '1 serving',
            calories: 168,
          ),
        ],
        calories: 168,
        at: DateTime.utc(2026, 9, 25, 9),
      ),
    );

    final recent = await repo.getRecentLogs(_user);

    expect(recent, hasLength(2));
    expect(recent.map((l) => l.components.length), [1, 2]);
  });

  test('the case-insensitive name fold is kept for identical items', () async {
    for (final name in ['Oatmeal', 'oatmeal', 'Banana']) {
      await repo.insertLog(
        _log(
          name: name,
          components: const [],
          calories: 100,
          at: DateTime.utc(2026, 9, 25, 9),
        ),
      );
    }

    final names = (await repo.getRecentLogs(
      _user,
    )).map((l) => l.name.toLowerCase());
    expect(names.where((n) => n == 'oatmeal'), hasLength(1));
    expect(names, contains('banana'));
  });

  test('the Recent stream emits the same base rows', () async {
    await repo.insertLog(
      _log(
        name: 'Egg',
        components: const [
          MealComponent(
            name: 'Egg',
            portion: '1.5 large',
            calories: 108,
            carbG: 0.6,
            proteinG: 9.5,
            fatG: 7.5,
            sodiumMg: 107,
          ),
        ],
        calories: 108,
        servings: 1.5,
        at: DateTime.utc(2026, 9, 25, 23, 27),
      ),
    );

    final first = await repo.watchRecentLogs(_user).first;
    final egg = first.single;
    expect(egg.servings, 1);
    expect(egg.calories, 72);
    expect(egg.components.single.portion, '1 large');
    expect(egg.components.single.carbG, 0.4);
    expect(egg.components.single.sodiumMg, 71);
  });
}
