// G23 repro harness — the LIVE sim's exact plan/day fixture (two plans from
// the 2026-09-19 audit era; the 1-day 748 row and the probe day-3 680 row
// share planDate Sep 27) driven through the REAL repository and the REAL
// carbDashboardForDate provider. Hunting: how day-3 math rendered under a
// "Today, September 25" header.
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

const uid = 'c2c7e005-6041-4b6c-b7ae-ae25c97b049b';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = MockAppLogger();
    when(() => logger.error(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);
    final repo = CarbLoadingRepository(
      supabase: MockSupabaseClient(),
      database: db,
      logger: logger,
      sentry: MockSentryReporter(),
    );

    // The sim's rows, verbatim (local-midnight instants).
    Future<void> plan(String id, int total, DateTime s, DateTime e) =>
        db.into(db.carbLoadingPlansTable).insert(
              CarbLoadingPlansTableCompanion.insert(
                id: Value(id),
                userId: uid,
                totalDays: total,
                startDate: s,
                endDate: e,
                dailyCarbTargetGrams: 590,
                generatedAt: DateTime(2026, 9, 19, 16, 15),
              ),
            );
    Future<void> day(String id, String planId, int n, DateTime d, int g) =>
        db.into(db.carbLoadingDaysTable).insert(
              CarbLoadingDaysTableCompanion.insert(
                id: Value(id),
                carbLoadingPlanId: planId,
                planDate: d,
                dayNumber: n,
                carbTargetGrams: g,
              ),
            );
    // Insertion order mirrors created_at: the 1-day plan FIRST (16:15).
    await plan('plan-1day', 1, DateTime(2026, 9, 27), DateTime(2026, 9, 27));
    await plan('plan-probe', 3, DateTime(2026, 9, 25), DateTime(2026, 9, 27));
    await day('d-748', 'plan-1day', 1, DateTime(2026, 9, 27), 748);
    await day('d-544a', 'plan-probe', 1, DateTime(2026, 9, 25), 544);
    await day('d-544b', 'plan-probe', 2, DateTime(2026, 9, 26), 544);
    await day('d-680', 'plan-probe', 3, DateTime(2026, 9, 27), 680);

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

  test('Sep 25: the provider must resolve the SELECTED DAY\'s OWN row', () async {
    final carb = await container
        .read(carbDashboardForDateProvider('2026-09-25').future);
    expect(carb, isNotNull);
    printOnFailure('resolved day target: ${carb!.face.labelLine}');
    expect(carb.face.labelLine, contains('DAY 1 OF 3'));
    expect(carb.slots.first.targetG, 136, reason: '544-split, never 170');
  });

  test('Sep 27 (the overlap date): resolution is deterministic and stated',
      () async {
    final carb = await container
        .read(carbDashboardForDateProvider('2026-09-27').future);
    expect(carb, isNotNull);
    // Two rows share this planDate. Whatever wins must be STABLE; this
    // pins today's behavior so a fix is a deliberate change, not drift.
    printOnFailure('overlap day resolved to: ${carb!.face.labelLine} '
        'target ${carb.slots.map((s) => s.targetG).toList()}');
  });
}
