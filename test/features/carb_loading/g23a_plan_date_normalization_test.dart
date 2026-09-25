// G23a (carb-loading@v1 live-build red, pinned 2026-09-25): a plan created
// from an event whose startTime carries a gun time (2026-09-27T07:30) must
// store day rows at LOCAL MIDNIGHTS and render on its loading day. The live
// defect: raceDate = DateTime.parse(event.startTime!) leaked 07:30 into
// carb_loading_days.plan_date, which the dashboard's midnight-keyed date
// reads could never match — the plan never rendered anywhere.
//
// Evidence fixture: avery's live-created "Ironman 70.3 Augusta" 1-day plan
// (dbe80e8d, day row 2026-09-26 07:30:00, target 748) from the sim DB.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/providers/carb_dashboard_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

const uid = 'user-g23a';

void main() {
  late AppDatabase db;
  late CarbLoadingRepository repo;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = MockAppLogger();
    when(() => logger.error(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => logger.warning(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);
    final sentry = MockSentryReporter();
    when(() => sentry.reportNetworkError(any(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        stackTrace: any(named: 'stackTrace'))).thenAnswer((_) async {});
    repo = CarbLoadingRepository(
      supabase: MockSupabaseClient(),
      database: db,
      logger: logger,
      sentry: sentry,
    );

    container = ProviderContainer(overrides: [
      userIdProvider.overrideWith((ref) async => uid),
      carbLoadingRepositoryProvider.overrideWithValue(repo),
      mealLogsForDateProvider.overrideWith((ref, date) async* {
        yield const [];
      }),
    ]);
    addTearDown(container.dispose);
    addTearDown(db.close);
  });

  test(
      'G23a: gun-time raceDate stores midnight planDates AND the plan '
      'renders on its loading day', () async {
    // The live repro: 1-day protocol against a race with a 07:30 gun time.
    await repo.createCarbLoadingPlan(
      deviceId: 'test-device',
      userId: uid,
      protocolDays: 1,
      raceDate: DateTime(2026, 9, 27, 7, 30),
      bodyWeightPounds: 149.9,
    );

    // (a) Every stored day row sits at a local midnight — no time-of-day.
    final rows = await db.select(db.carbLoadingDaysTable).get();
    expect(rows, hasLength(1));
    for (final row in rows) {
      expect(
        row.planDate,
        DateTime(row.planDate.year, row.planDate.month, row.planDate.day),
        reason: 'planDate is a LOCAL DATE — the gun time must not leak in',
      );
    }
    expect(rows.single.planDate, DateTime(2026, 9, 26));
    expect(rows.single.carbTargetGrams, 748, reason: '11 g/kg × 67.99 kg');

    // (b) The dashboard provider resolves the loading day — the defect was
    // exactly this read returning null forever for gun-time-created plans.
    final carb = await container
        .read(carbDashboardForDateProvider('2026-09-26').future);
    expect(carb, isNotNull, reason: 'the plan renders on its loading day');
    expect(carb!.face.labelLine, contains('DAY 1 OF 1'));
  });

  test(
      'legacy defense: a pre-G23a row carrying 07:30 still resolves, '
      'normalized, on its local day', () async {
    // A row shaped like the live evidence (dbe80e8d), written before the
    // create path normalized. Devices already carry these.
    await db.into(db.carbLoadingPlansTable).insert(
          CarbLoadingPlansTableCompanion.insert(
            id: const Value('plan-legacy'),
            userId: uid,
            totalDays: 1,
            startDate: DateTime(2026, 9, 26),
            endDate: DateTime(2026, 9, 26),
            dailyCarbTargetGrams: 748,
            generatedAt: DateTime(2026, 9, 25, 7, 58),
          ),
        );
    await db.into(db.carbLoadingDaysTable).insert(
          CarbLoadingDaysTableCompanion.insert(
            id: const Value('day-legacy'),
            carbLoadingPlanId: 'plan-legacy',
            planDate: DateTime(2026, 9, 26, 7, 30),
            dayNumber: 1,
            carbTargetGrams: 748,
          ),
        );

    final days = await repo.getCarbLoadingDaysForDateRange(
      userId: uid,
      startDate: DateTime(2026, 9, 26),
      endDate: DateTime(2026, 9, 26),
    );
    expect(days, hasLength(1), reason: 'the day-span read finds the row');
    expect(days.single.planDate, DateTime(2026, 9, 26),
        reason: 'callers see the normalized local date');

    final carb = await container
        .read(carbDashboardForDateProvider('2026-09-26').future);
    expect(carb, isNotNull);
    expect(carb!.face.labelLine, contains('DAY 1 OF 1'));
  });
}
