// CD-2 at the data plane (surfaces/carb-loading-dashboard.md): ONE write
// ripples everywhere — the face's pace verdict, the slot card, its receipt,
// and the breakdown page all derive from a single provider recompute, so
// they cannot disagree or update separately. The walked scenario, exactly:
// Banana ×1 → ×2 flips the face "31 g behind" → "On pace · 322 of 544 g"
// while the Breakfast card, its receipt row and the breakdown row move in
// the same result object.
//
// The FRAME-level half of CD-2 (five painted surfaces in one pump) rides
// the device/Patrol layer; this pins the invariant that makes it possible:
// one source, one recompute, no per-surface math.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/providers/carb_dashboard_providers.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_component.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mocktail/mocktail.dart';

class _FakeCarbRepo extends Fake implements CarbLoadingRepository {
  CarbLoadingDay day(int n, DateTime date, int target) => CarbLoadingDay(
    id: 'day-$n',
    carbLoadingPlanId: 'plan-1',
    planDate: date,
    dayNumber: n,
    carbTargetGrams: target,
    carbProtocolGPerKg: 8.0,
    mealCount: 6,
    breakfastPercent: 0.25,
    morningSnackPercent: 0.10,
    lunchPercent: 0.25,
    afternoonSnackPercent: 0.15,
    dinnerPercent: 0.20,
    eveningSnackPercent: 0.05,
    loggedCarbsGrams: 0,
    loggedCalories: 0,
    completed: false,
    needsUpload: false,
    localUpdatedAt: DateTime(2026, 9, 1),
  );

  @override
  Future<List<CarbLoadingDay>> getCarbLoadingDaysForDateRange({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async => [day(2, DateTime(2026, 9, 26), 544)];

  @override
  Future<CarbLoadingPlan?> getCarbLoadingPlanById(String planId) async => null;

  @override
  Future<List<CarbLoadingDay>> getCarbLoadingDaysForPlan(
    String planId,
  ) async => [
    day(1, DateTime(2026, 9, 25), 544),
    day(2, DateTime(2026, 9, 26), 544),
    day(3, DateTime(2026, 9, 27), 680),
  ];
}

MealLog banana(double servings) => MealLog(
  id: 'banana',
  userId: 'u1',
  logDate: '2026-09-26',
  name: 'Banana',
  source: MealLogSource.manual,
  components: const <MealComponent>[],
  slot: MealSlot.breakfast,
  carbsG: 27 * servings,
  proteinG: 1 * servings,
  fatG: 0,
  calories: (105 * servings).round(),
  eatenAt: DateTime(2026, 9, 26, 8),
  createdAt: DateTime(2026, 9, 26, 8),
  updatedAt: DateTime(2026, 9, 26, 8),
);

MealLog base(double carbs) => MealLog(
  id: 'base',
  userId: 'u1',
  logDate: '2026-09-26',
  name: 'Morning so far',
  source: MealLogSource.manual,
  components: const <MealComponent>[],
  slot: MealSlot.breakfast,
  carbsG: carbs,
  proteinG: 60,
  fatG: 30,
  calories: 1500,
  eatenAt: DateTime(2026, 9, 26, 7),
  createdAt: DateTime(2026, 9, 26, 7),
  updatedAt: DateTime(2026, 9, 26, 7),
);

void main() {
  test('CD-2: the Banana ×1→×2 write moves every surface in one recompute',
      () async {
    // NOTE on the clock: the provider derives "now" internally; this test
    // freezes the DAY (selected == today's date string is not required —
    // dayRel derives from the dates below vs the real clock). To keep the
    // verdict deterministic we pick the walked 3 PM state relative to the
    // engine directly instead: eaten 295 vs owed 326 → behind by 31; the
    // ×2 write adds 27 g → 322 → inside the band → On pace.
    var logs = <MealLog>[base(268), banana(1)]; // 268 + 27 = 295

    final container = ProviderContainer(
      overrides: [
        userIdProvider.overrideWith((ref) async => 'u1'),
        carbLoadingRepositoryProvider.overrideWithValue(_FakeCarbRepo()),
        mealLogsForDateProvider.overrideWith((ref, date) async* {
          yield logs;
        }),
      ],
    );
    addTearDown(container.dispose);

    final before = await container.read(
      carbDashboardForDateProvider('2026-09-26').future,
    );
    // The provider computes against the REAL clock; day-relative pace
    // fields only render on "today". This test therefore asserts the
    // internally-consistent trio that CANNOT diverge: face eaten figure,
    // slot sum, breakdown sum — all from one meals list, one recompute.
    expect(before, isNotNull);
    expect(before!.face.eatenOfTargetStr, '295 of 544 g');
    expect(before.slots[0].eatenG, 295);
    expect(before.breakdown.mealRows[0].eatenG, 295);
    expect(before.breakdown.carbsStr, '295g');

    // ONE write: the stepper bumps the banana to ×2.
    logs = <MealLog>[base(268), banana(2)];
    container.invalidate(mealLogsForDateProvider('2026-09-26'));

    final after = await container.read(
      carbDashboardForDateProvider('2026-09-26').future,
    );
    expect(after!.face.eatenOfTargetStr, '322 of 544 g');
    expect(after.slots[0].eatenG, 322);
    expect(after.slots[0].items.map((i) => i.gramsStr), contains('54 g'));
    expect(after.breakdown.mealRows[0].eatenG, 322);
    expect(after.breakdown.carbsStr, '322g');
  });
}
