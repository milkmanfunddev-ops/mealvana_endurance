// CE-4/CE-4a — the protocol re-pick (carb-loading@v1, handback G10 +
// CE-5's L2 row). Pins, against a real in-memory Drift database:
//  * stable day-row identity: a re-pick UPDATES rows in place keyed by
//    plan+date — surviving dates keep their IDs (CE-4a);
//  * keep-migrates-by-date: an edited target rides into the new window under
//    "Keep my targets" (F3 data verified via previewRepickProtocol);
//  * the F4 single-notice case drops out-of-window edits WITH disclosure and
//    both outcomes coincide with the derivation;
//  * delete-plan-food-survives: slot logs are ordinary meal_logs rows
//    (Path A) — deleting the plan leaves them untouched.
//
// Weight 149.9 lb throughout — the conformance oracle's canonical athlete
// (67.9934 kg → 544/544/680 · 612/748 · 748).
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_loading_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_loading_entryway_engine.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockCoachRepository extends Mock implements CoachRepository {}

class MockEventsRepository extends Mock implements EventsRepository {}

void main() {
  late AppDatabase db;
  late CarbLoadingRepository repository;
  late CarbLoadingService service;

  const userId = 'user-repick-1';
  const deviceId = 'device-repick-1';
  const weightLb = 149.9;
  final raceDate = DateTime(2026, 10, 5);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final logger = MockAppLogger();
    when(
      () => logger.info(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => logger.debug(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    when(
      () => logger.warning(
        any(),
        context: any(named: 'context'),
        data: any(named: 'data'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);
    when(
      () => logger.error(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
      ),
    ).thenReturn(null);
    final sentry = MockSentryReporter();
    when(
      () => sentry.reportNetworkError(
        any<Object>(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});
    final eventsRepo = MockEventsRepository();
    when(
      () => eventsRepo.uploadDirtyRecords(any()),
    ).thenAnswer((_) async => UploadResult.nothingToUpload());
    repository = CarbLoadingRepository(
      supabase: MockSupabaseClient(),
      database: db,
      logger: logger,
      sentry: sentry,
    );
    service = CarbLoadingService(
      db,
      logger,
      repository,
      MockCoachRepository(),
      eventsRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<String> createEventWithPlan(int protocolDays) async {
    await db
        .into(db.eventsTable)
        .insert(
          EventsTableCompanion.insert(
            id: const Value('event-repick'),
            userId: userId,
            eventType: 'running',
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
    await service.createCarbLoadingPlan(
      deviceId: deviceId,
      userId: userId,
      eventId: 'event-repick',
      protocolDays: protocolDays,
      raceDate: raceDate,
      bodyWeightPounds: weightLb,
    );
    return 'event-repick';
  }

  Future<Map<DateTime, CarbLoadingDay>> daysByDate() async {
    final rows = await db.select(db.carbLoadingDaysTable).get();
    return {
      for (final r in rows)
        DateTime(r.planDate.year, r.planDate.month, r.planDate.day): r,
    };
  }

  test('CE-4a: surviving dates keep their row IDs across a re-pick', () async {
    final eventId = await createEventWithPlan(3); // Oct 2, 3, 4
    final before = await daysByDate();
    expect(before.length, 3);
    final oct3IdBefore = before[DateTime(2026, 10, 3)]!.id;
    final oct4IdBefore = before[DateTime(2026, 10, 4)]!.id;

    await service.applyRepickProtocol(
      deviceId: deviceId,
      userId: userId,
      eventId: eventId,
      targetProtocolDays: 2, // window Oct 3–4; Oct 2 drops
      raceDate: raceDate,
      bodyWeightPounds: weightLb,
      keepEdits: false,
    );

    final after = await daysByDate();
    expect(after.length, 2, reason: 'Oct 2 leaves the window');
    expect(after[DateTime(2026, 10, 2)], isNull);
    expect(
      after[DateTime(2026, 10, 3)]!.id,
      oct3IdBefore,
      reason: 'CE-4a: same date → same row, updated in place',
    );
    expect(after[DateTime(2026, 10, 4)]!.id, oct4IdBefore);
    // 2-Day Quick at 149.9 lb: 9.0 / 11.0 g/kg → 612 / 748.
    expect(after[DateTime(2026, 10, 3)]!.carbTargetGrams, 612);
    expect(after[DateTime(2026, 10, 4)]!.carbTargetGrams, 748);
    expect(after[DateTime(2026, 10, 3)]!.dayNumber, 1);
    expect(after[DateTime(2026, 10, 4)]!.dayNumber, 2);

    final plans = await db.select(db.carbLoadingPlansTable).get();
    expect(plans.length, 1, reason: 'never delete+recreate');
    expect(plans.single.totalDays, 2);
  });

  test('CE-4 keep: an edited target migrates by DATE into the new window',
      () async {
    final eventId = await createEventWithPlan(3);
    final before = await daysByDate();
    final oct3 = before[DateTime(2026, 10, 3)]!;
    await repository.updateCarbLoadingDay(
      deviceId: deviceId,
      carbLoadingDayId: oct3.id,
      updates: {'carbTargetGrams': 620},
    );

    final decision = await service.previewRepickProtocol(
      eventId: eventId,
      targetProtocolDays: 2,
      raceDate: raceDate,
      bodyWeightPounds: weightLb,
    );
    expect(decision.dialogType, RepickDialogType.keepReset);
    expect(decision.listedEdits, hasLength(1));
    // F3 DATA: relabeled per the TARGET protocol's window.
    expect(decision.listedEdits.single.targetDayNumber, 1);
    expect(decision.listedEdits.single.storedG, 620);
    expect(decision.droppedDates, isEmpty);
    expect(decision.keepPlanG, [620, 748]);
    expect(decision.resetPlanG, [612, 748]);

    await service.applyRepickProtocol(
      deviceId: deviceId,
      userId: userId,
      eventId: eventId,
      targetProtocolDays: 2,
      raceDate: raceDate,
      bodyWeightPounds: weightLb,
      keepEdits: true,
    );
    final after = await daysByDate();
    expect(after[DateTime(2026, 10, 3)]!.carbTargetGrams, 620);
    expect(after[DateTime(2026, 10, 3)]!.id, oct3.id);
    expect(after[DateTime(2026, 10, 4)]!.carbTargetGrams, 748);
  });

  test('F4 notice: every edit outside the window drops with disclosure',
      () async {
    final eventId = await createEventWithPlan(3);
    final before = await daysByDate();
    final oct2 = before[DateTime(2026, 10, 2)]!;
    await repository.updateCarbLoadingDay(
      deviceId: deviceId,
      carbLoadingDayId: oct2.id,
      updates: {'carbTargetGrams': 600},
    );

    final decision = await service.previewRepickProtocol(
      eventId: eventId,
      targetProtocolDays: 1,
      raceDate: raceDate,
      bodyWeightPounds: weightLb,
    );
    expect(decision.dialogType, RepickDialogType.notice);
    expect(decision.droppedDates, [DateTime(2026, 10, 2)]);
    expect(decision.keepPlanG, [748]);
    expect(decision.resetPlanG, [748]);

    await service.applyRepickProtocol(
      deviceId: deviceId,
      userId: userId,
      eventId: eventId,
      targetProtocolDays: 1,
      raceDate: raceDate,
      bodyWeightPounds: weightLb,
      keepEdits: false,
    );
    final after = await daysByDate();
    expect(after.length, 1);
    expect(after[DateTime(2026, 10, 4)]!.carbTargetGrams, 748);
  });

  test('CE-5: deleting the plan leaves slot-tagged meal logs untouched',
      () async {
    final eventId = await createEventWithPlan(3);
    final now = DateTime(2026, 10, 2, 8);
    await db
        .into(db.mealLogsTable)
        .insert(
          MealLogsTableCompanion.insert(
            id: const Value('meal-slot-1'),
            userId: userId,
            logDate: '2026-10-02',
            name: 'Everything Bagel',
            source: 'manual',
            slot: const Value('breakfast'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    await service.deleteCarbLoadingPlan(
      deviceId: deviceId,
      eventId: eventId,
      currentUserId: userId,
    );

    expect(await db.select(db.carbLoadingPlansTable).get(), isEmpty);
    expect(await db.select(db.carbLoadingDaysTable).get(), isEmpty);
    final meals = await db.select(db.mealLogsTable).get();
    expect(
      meals,
      hasLength(1),
      reason: 'Path A: food already logged stays in the log',
    );
    expect(meals.single.id, 'meal-slot-1');
  });
}
