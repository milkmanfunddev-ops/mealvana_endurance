// ignore_for_file: unused_local_variable
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_loading_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
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
  late MockAppLogger mockLogger;
  late MockSentryReporter mockSentry;
  late MockCoachRepository mockCoachRepo;
  late MockEventsRepository mockEventsRepo;
  late CarbLoadingRepository carbLoadingRepository;
  late CarbLoadingService service;

  const testUserId = 'user-carb-123';
  const testDeviceId = 'device-carb-123';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    mockLogger = MockAppLogger();
    mockSentry = MockSentryReporter();
    mockCoachRepo = MockCoachRepository();
    mockEventsRepo = MockEventsRepository();

    // Stub all logger calls
    when(() => mockLogger.info(any(), context: any(named: 'context'), data: any(named: 'data'))).thenReturn(null);
    when(() => mockLogger.debug(any(), context: any(named: 'context'), data: any(named: 'data'))).thenReturn(null);
    when(() => mockLogger.warning(any(), context: any(named: 'context'), data: any(named: 'data'), error: any(named: 'error'))).thenReturn(null);
    when(() => mockLogger.error(any(), context: any(named: 'context'), error: any(named: 'error'), stackTrace: any(named: 'stackTrace'), data: any(named: 'data'))).thenReturn(null);

    // Stub uploadDirtyRecords on events repo (called after carb loading plan created/deleted)
    when(() => mockEventsRepo.uploadDirtyRecords(any()))
        .thenAnswer((_) async => UploadResult.nothingToUpload());

    carbLoadingRepository = CarbLoadingRepository(
      supabase: MockSupabaseClient(),
      database: db,
      logger: mockLogger,
      sentry: mockSentry,
    );

    service = CarbLoadingService(
      db,
      mockLogger,
      carbLoadingRepository,
      mockCoachRepo,
      mockEventsRepo,
    );
  });

  tearDown(() async {
    await db.close();
  });

  // ---------------------------------------------------------------------------
  // getCarbProtocolForDay – public method on CarbLoadingService
  // ---------------------------------------------------------------------------

  group('getCarbProtocolForDay', () {
    // 2-day protocol
    test('2-day: day -2 → 9g/kg', () {
      expect(
        service.getCarbProtocolForDay(protocolDays: 2, daysBeforeRace: 2),
        9.0,
      );
    });

    test('2-day: day -1 → 11g/kg', () {
      expect(
        service.getCarbProtocolForDay(protocolDays: 2, daysBeforeRace: 1),
        11.0,
      );
    });

    // 3-day protocol
    test('3-day: day -3 → 8g/kg', () {
      expect(
        service.getCarbProtocolForDay(protocolDays: 3, daysBeforeRace: 3),
        8.0,
      );
    });

    test('3-day: day -2 → 8g/kg', () {
      expect(
        service.getCarbProtocolForDay(protocolDays: 3, daysBeforeRace: 2),
        8.0,
      );
    });

    test('3-day: day -1 → 10g/kg', () {
      expect(
        service.getCarbProtocolForDay(protocolDays: 3, daysBeforeRace: 1),
        10.0,
      );
    });

    test('unknown protocol falls back to 8g/kg', () {
      expect(
        service.getCarbProtocolForDay(protocolDays: 5, daysBeforeRace: 3),
        8.0,
      );
    });

    // NOTE BUG CHECK: The 2-day protocol uses daysBeforeRace == 2 → 9g/kg, else → 11g/kg.
    // If you accidentally pass daysBeforeRace: 0 (the race day itself) it falls through
    // to the else branch and returns 11g/kg instead of 8g/kg default.
    // This verifies the else-branch behaviour.
    test('2-day: daysBeforeRace=0 falls to else → returns 11g/kg (documents current behaviour)', () {
      // This is not a valid call but documents that there is no guard for race-day.
      final result = service.getCarbProtocolForDay(protocolDays: 2, daysBeforeRace: 0);
      expect(result, 11.0); // documents current (possibly surprising) behaviour
    });
  });

  // ---------------------------------------------------------------------------
  // getCarbLoadingDaysForRange – via service
  // ---------------------------------------------------------------------------

  group('getCarbLoadingDaysForRange', () {
    Future<void> _seedPlan({
      required int days,
      required DateTime raceDate,
      required double weightPounds,
    }) async {
      // We call through the CalendarService's createCarbLoadingPlan because
      // CarbLoadingService.createCarbLoadingPlan calls an edge function via repo.
      // Insert plan + days directly to avoid Supabase dependency.
      final weightKg = weightPounds * 0.453592;
      final startDate = raceDate.subtract(Duration(days: days));
      final endDate = raceDate.subtract(const Duration(days: 1));
      final avg = ((() {
        double total = 0;
        for (int i = 0; i < days; i++) {
          final dbr = days - i;
          total += service.getCarbProtocolForDay(protocolDays: days, daysBeforeRace: dbr);
        }
        return (total / days * weightKg).round();
      })());

      final plan = await db.into(db.carbLoadingPlansTable).insertReturning(
            CarbLoadingPlansTableCompanion.insert(
              userId: testUserId,
              totalDays: days,
              startDate: startDate,
              endDate: endDate,
              dailyCarbTargetGrams: avg,
              generatedAt: DateTime.now(),
            ),
          );

      for (int i = 0; i < days; i++) {
        final dayDate = startDate.add(Duration(days: i));
        final daysBeforeRace = days - i;
        final protocol = service.getCarbProtocolForDay(
          protocolDays: days,
          daysBeforeRace: daysBeforeRace,
        );
        await db.into(db.carbLoadingDaysTable).insert(
              CarbLoadingDaysTableCompanion.insert(
                carbLoadingPlanId: plan.id,
                planDate: dayDate,
                dayNumber: i + 1,
                carbTargetGrams: (protocol * weightKg).round(),
              ),
            );
      }
    }

    test('returns empty list when no plans exist', () async {
      final days = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 10),
      );
      expect(days, isEmpty);
    });

    test('returns days within range in ascending date order', () async {
      await _seedPlan(days: 3, raceDate: DateTime(2026, 10, 5), weightPounds: 154.3236);

      // Range covers all 3 days: Oct 2, 3, 4
      final result = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: DateTime(2026, 10, 2),
        endDate: DateTime(2026, 10, 4, 23, 59, 59),
      );

      expect(result.length, 3);
      // Check ascending order
      for (int i = 1; i < result.length; i++) {
        expect(result[i].planDate.isAfter(result[i - 1].planDate), isTrue);
      }
    });

    test('scopes to userId – prevents cross-user leakage', () async {
      await _seedPlan(days: 2, raceDate: DateTime(2026, 10, 5), weightPounds: 154.3236);

      final result = await service.getCarbLoadingDaysForRange(
        userId: 'attacker-user-999',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 10),
      );

      expect(result, isEmpty);
    });

    test('boundary: exactly on startDate is included (isBiggerOrEqualValue)', () async {
      await _seedPlan(days: 2, raceDate: DateTime(2026, 10, 5), weightPounds: 154.3236);
      // Oct 3 should be in the results
      final result = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: DateTime(2026, 10, 3, 0, 0, 0),
        endDate: DateTime(2026, 10, 3, 23, 59, 59),
      );
      expect(result.length, 1);
      expect(result.first.planDate.day, 3);
    });

    test('boundary: exactly on endDate is included (isSmallerOrEqualValue)', () async {
      await _seedPlan(days: 2, raceDate: DateTime(2026, 10, 5), weightPounds: 154.3236);
      // Oct 4 should be in the results
      final result = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: DateTime(2026, 10, 4, 0, 0, 0),
        endDate: DateTime(2026, 10, 4, 23, 59, 59),
      );
      expect(result.length, 1);
      expect(result.first.planDate.day, 4);
    });

    test('race day (endDate+1) is NOT included', () async {
      await _seedPlan(days: 2, raceDate: DateTime(2026, 10, 5), weightPounds: 154.3236);
      final result = await service.getCarbLoadingDaysForRange(
        userId: testUserId,
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 5, 23, 59, 59),
      );
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // getCarbLoadingPlan – query by eventId
  // ---------------------------------------------------------------------------

  group('getCarbLoadingPlan', () {
    test('returns null when no plan exists for event', () async {
      final result = await service.getCarbLoadingPlan('no-such-event-id');
      expect(result, equals(null));
    });

    test('returns plan when one is found', () async {
      final insertedPlan = await db.into(db.carbLoadingPlansTable).insertReturning(
            CarbLoadingPlansTableCompanion.insert(
              userId: testUserId,
              eventId: Value('event-001'),
              totalDays: 2,
              startDate: DateTime(2026, 10, 3),
              endDate: DateTime(2026, 10, 4),
              dailyCarbTargetGrams: 700,
              generatedAt: DateTime.now(),
            ),
          );

      final result = await service.getCarbLoadingPlan('event-001');
      expect(result, isNot(equals(null)));
      expect(result!.id, insertedPlan.id);
      expect(result.totalDays, 2);
    });

    // Regression: a race between two protocol selections could insert two plans
    // for one event, and getSingleOrNull() then threw 'Bad state: Too many
    // elements'. That crash cascaded and left the event with no days, no
    // calendar dots, nothing. getCarbLoadingPlan must now tolerate duplicates.
    test('does NOT throw on duplicate plans — returns the newest', () async {
      final older = await db.into(db.carbLoadingPlansTable).insertReturning(
            CarbLoadingPlansTableCompanion.insert(
              userId: testUserId,
              eventId: const Value('dup-event'),
              totalDays: 2,
              startDate: DateTime(2026, 10, 3),
              endDate: DateTime(2026, 10, 4),
              dailyCarbTargetGrams: 700,
              generatedAt: DateTime(2026, 9, 1, 10, 0),
            ),
          );
      final newer = await db.into(db.carbLoadingPlansTable).insertReturning(
            CarbLoadingPlansTableCompanion.insert(
              userId: testUserId,
              eventId: const Value('dup-event'),
              totalDays: 3,
              startDate: DateTime(2026, 10, 2),
              endDate: DateTime(2026, 10, 4),
              dailyCarbTargetGrams: 600,
              generatedAt: DateTime(2026, 9, 1, 10, 5), // newer
            ),
          );

      final result = await service.getCarbLoadingPlan('dup-event');
      expect(result, isNot(equals(null)));
      expect(result!.id, newer.id, reason: 'should keep the newest plan');
      expect(result.totalDays, 3);
      // Sanity: the older one existed and is distinct.
      expect(older.id, isNot(newer.id));
    });

    test('self-heals — deletes the duplicate so only one plan remains', () async {
      for (final gen in [
        DateTime(2026, 9, 1, 10, 0),
        DateTime(2026, 9, 1, 10, 5),
        DateTime(2026, 9, 1, 10, 3),
      ]) {
        await db.into(db.carbLoadingPlansTable).insert(
              CarbLoadingPlansTableCompanion.insert(
                userId: testUserId,
                eventId: const Value('heal-event'),
                totalDays: 3,
                startDate: DateTime(2026, 10, 2),
                endDate: DateTime(2026, 10, 4),
                dailyCarbTargetGrams: 600,
                generatedAt: gen,
              ),
            );
      }

      await service.getCarbLoadingPlan('heal-event');

      final remaining = await (db.select(db.carbLoadingPlansTable)
            ..where((t) => t.eventId.equals('heal-event')))
          .get();
      expect(remaining.length, 1, reason: 'duplicates should be cleaned up');
      expect(remaining.single.generatedAt, DateTime(2026, 9, 1, 10, 5),
          reason: 'the survivor should be the newest');
    });
  });

  // ---------------------------------------------------------------------------
  // getCarbLoadingDays – query by planId
  // ---------------------------------------------------------------------------

  group('getCarbLoadingDays', () {
    test('returns empty when no days exist for plan', () async {
      final result = await service.getCarbLoadingDays('nonexistent-plan-id');
      expect(result, isEmpty);
    });

    test('returns days in ascending dayNumber order', () async {
      final plan = await db.into(db.carbLoadingPlansTable).insertReturning(
            CarbLoadingPlansTableCompanion.insert(
              userId: testUserId,
              totalDays: 3,
              startDate: DateTime(2026, 10, 2),
              endDate: DateTime(2026, 10, 4),
              dailyCarbTargetGrams: 600,
              generatedAt: DateTime.now(),
            ),
          );

      // Insert days out of order to verify ordering
      for (final dayNum in [3, 1, 2]) {
        await db.into(db.carbLoadingDaysTable).insert(
              CarbLoadingDaysTableCompanion.insert(
                carbLoadingPlanId: plan.id,
                planDate: DateTime(2026, 10, 1 + dayNum),
                dayNumber: dayNum,
                carbTargetGrams: 500,
              ),
            );
      }

      final days = await service.getCarbLoadingDays(plan.id);
      expect(days.length, 3);
      expect(days.map((d) => d.dayNumber).toList(), [1, 2, 3]);
    });
  });

  // ---------------------------------------------------------------------------
  // deleteCarbLoadingDay – cascade meals
  // ---------------------------------------------------------------------------

  group('deleteCarbLoadingDay', () {
    test('removes the carb loading day record', () async {
      final plan = await db.into(db.carbLoadingPlansTable).insertReturning(
            CarbLoadingPlansTableCompanion.insert(
              userId: testUserId,
              totalDays: 1,
              startDate: DateTime(2026, 10, 4),
              endDate: DateTime(2026, 10, 4),
              dailyCarbTargetGrams: 700,
              generatedAt: DateTime.now(),
            ),
          );

      final day = await db.into(db.carbLoadingDaysTable).insertReturning(
            CarbLoadingDaysTableCompanion.insert(
              carbLoadingPlanId: plan.id,
              planDate: DateTime(2026, 10, 4),
              dayNumber: 1,
              carbTargetGrams: 700,
            ),
          );

      await service.deleteCarbLoadingDay(day.id);

      final remaining = await db.select(db.carbLoadingDaysTable).get();
      expect(remaining, isEmpty);
    });

    test('also deletes meals associated with the day', () async {
      final plan = await db.into(db.carbLoadingPlansTable).insertReturning(
            CarbLoadingPlansTableCompanion.insert(
              userId: testUserId,
              totalDays: 1,
              startDate: DateTime(2026, 10, 4),
              endDate: DateTime(2026, 10, 4),
              dailyCarbTargetGrams: 700,
              generatedAt: DateTime.now(),
            ),
          );

      final day = await db.into(db.carbLoadingDaysTable).insertReturning(
            CarbLoadingDaysTableCompanion.insert(
              carbLoadingPlanId: plan.id,
              planDate: DateTime(2026, 10, 4),
              dayNumber: 1,
              carbTargetGrams: 700,
            ),
          );

      // Insert a meal for this day (must provide exactly one of carbLoadingFoodId or carbLoadingUserFoodId)
      await db.into(db.carbLoadingDayMealsTable).insert(
            CarbLoadingDayMealsTableCompanion.insert(
              carbLoadingDayId: day.id,
              mealTypeId: 1,
              carbLoadingFoodId: Value('food-uuid-001'), // required: exactly one food FK
              carbsConsumed: 50.0,
            ),
          );

      expect((await db.select(db.carbLoadingDayMealsTable).get()).length, 1);

      await service.deleteCarbLoadingDay(day.id);

      expect((await db.select(db.carbLoadingDayMealsTable).get()), isEmpty);
      expect((await db.select(db.carbLoadingDaysTable).get()), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Coach authorization checks
  // ---------------------------------------------------------------------------

  group('createCarbLoadingPlan – coach-athlete authorization', () {
    test('throws when coach has no active relationship with athlete', () async {
      when(() => mockCoachRepo.isActiveCoachAthleteRelationship(
            coachUserId: testUserId,
            athleteUserId: 'athlete-456',
          )).thenAnswer((_) async => false);

      expect(
        () => service.createCarbLoadingPlan(
          deviceId: testDeviceId,
          userId: testUserId,
          forUserId: 'athlete-456',
          protocolDays: 2,
          raceDate: DateTime(2026, 10, 5),
          bodyWeightPounds: 154.0,
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Not authorized'),
        )),
      );
    });
  });

  group('deleteCarbLoadingPlan – coach-athlete authorization', () {
    test('throws when coach has no active relationship with athlete', () async {
      when(() => mockCoachRepo.isActiveCoachAthleteRelationship(
            coachUserId: testUserId,
            athleteUserId: 'athlete-456',
          )).thenAnswer((_) async => false);

      expect(
        () => service.deleteCarbLoadingPlan(
          deviceId: testDeviceId,
          eventId: 'some-event-id',
          currentUserId: testUserId,
          planOwnerId: 'athlete-456',
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Not authorized'),
        )),
      );
    });
  });
}
