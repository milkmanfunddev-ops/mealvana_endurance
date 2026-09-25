// G24 L2 `repick-propagates-immediately` (qa 4e23d25, Xuan's live bug #3 —
// E-3 instant-propagation): a protocol re-pick through the REAL controller
// must land on EVERY carb surface in the same pumped frame, with ZERO
// navigation. The live defect: applyRepickProtocol invalidated only
// self + carbLoadingDaysForRangeProvider, while the plan summary watches
// carbLoadingPlanProvider + carbLoadingDaysForPlanProvider and the
// loading-day dashboard watches carbDashboardForDateProvider — all three
// kept their cached (old-protocol) values until unrelated navigation
// rebuilt them.
//
// Surfaces under test, bound the way the real ones are:
//  * summary rows — the REAL CarbPlanSummaryScreen, painted;
//  * entry row — a probe watching carbLoadingPlanProvider(eventId), the
//    same family the event page's carb row watches (its own row rendering
//    is pinned by event_carb_entry_row_test);
//  * loading-day timeline — a probe watching carbDashboardForDateProvider,
//    the single source every dashboard carb surface derives from (surface
//    binding pinned by carb_dashboard_ripple_test / the CD-2 Patrol flow).
//
// Both ruled repick paths run: the QUIET repick (no edits anywhere) and
// KEEP (an edited target rides the keep choice through the same frame).
import 'package:drift/drift.dart' hide isNull, isNotNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_loading_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_loading_controller.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_plan_summary_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/features/macro_dashboard/presentation/providers/carb_dashboard_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    hide Event;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockAppLogger extends Mock implements AppLogger {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockCoachRepository extends Mock implements CoachRepository {}

class MockEventsRepository extends Mock implements EventsRepository {}

const userId = 'user-g24';
const eventId = 'event-g24';
const weightLb = 149.9; // canonical oracle athlete: 612/748 · 748

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

UserProfile _profile() => UserProfile(
  id: userId,
  deviceId: 'd-g24',
  gender: Gender.male,
  birthday: DateTime(1985, 3, 20),
  heightFeet: 5,
  heightInches: 11,
  weightPounds: weightLb,
  runsWithWaterBottle: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  appVersion: '1.0.0',
);

void main() {
  late AppDatabase db;
  late CarbLoadingRepository repository;
  late CarbLoadingService service;
  late DateTime today;
  late DateTime race;
  late String todayStr;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.now();
    today = DateTime(now.year, now.month, now.day);
    // Live-repro shape: the plan was created while a 2-day pick was
    // feasible; by NOW the race is tomorrow, so today is day 2 of 2 and the
    // athlete re-picks to 1-Day (feasible at daysUntilRace == 1).
    race = today.add(const Duration(days: 1));
    todayStr = _ymd(today);

    final logger = MockAppLogger();
    when(() => logger.info(any(),
        context: any(named: 'context'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => logger.debug(any(),
        context: any(named: 'context'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => logger.warning(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);
    when(() => logger.error(any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'))).thenReturn(null);
    final sentry = MockSentryReporter();
    when(() => sentry.reportNetworkError(any<Object>(),
        url: any(named: 'url'),
        method: any(named: 'method'),
        stackTrace: any(named: 'stackTrace'))).thenAnswer((_) async {});
    final eventsRepo = MockEventsRepository();
    when(() => eventsRepo.uploadDirtyRecords(any()))
        .thenAnswer((_) async => UploadResult.nothingToUpload());
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

    await db.into(db.eventsTable).insert(
          EventsTableCompanion.insert(
            id: const Value(eventId),
            userId: userId,
            eventType: 'running',
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
    await service.createCarbLoadingPlan(
      deviceId: userId,
      userId: userId,
      eventId: eventId,
      protocolDays: 2,
      raceDate: race,
      bodyWeightPounds: weightLb,
    );
    addTearDown(db.close);
  });

  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          carbLoadingServiceProvider.overrideWithValue(service),
          carbLoadingRepositoryProvider.overrideWithValue(repository),
          userIdProvider.overrideWith((ref) async => userId),
          mealLogsForDateProvider.overrideWith((ref, date) async* {
            yield const [];
          }),
          eventDetailProvider.overrideWith(
            (ref, _, {forUserId}) async => (
              activity: null,
              event: Event(
                id: eventId,
                userId: userId,
                eventType: ActivityType.running,
                eventDate: race,
                hasCarbLoading: true,
                createdAt: DateTime(2026, 9, 1),
                updatedAt: DateTime(2026, 9, 1),
              ),
            ),
          ),
          currentUserProvider.overrideWith((ref) async => _profile()),
        ],
        child: MaterialApp(
          home: Column(
            children: [
              const Expanded(
                child: CarbPlanSummaryScreen(eventId: eventId),
              ),
              // The entry row's binding: the SAME family the event page's
              // carb row watches.
              Consumer(
                builder: (context, ref, _) {
                  final plan =
                      ref.watch(carbLoadingPlanProvider(eventId)).value;
                  return Text(
                    'entry:${plan == null ? 'none' : (plan as dynamic).totalDays}',
                  );
                },
              ),
              // The loading-day timeline's binding: the single provider
              // every dashboard carb surface derives from.
              Consumer(
                builder: (context, ref, _) {
                  final carb =
                      ref.watch(carbDashboardForDateProvider(todayStr)).value;
                  return Text(
                    'timeline:${carb?.face.labelLine ?? 'none'}',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(CarbPlanSummaryScreen)),
      listen: false,
    );
  }

  testWidgets(
      'G24 quiet repick: summary rows, entry row and timeline all flip to '
      'the new plan in the same pumped frame — zero navigation', (
    tester,
  ) async {
    final container = await pump(tester);

    // The 2-day plan is on every surface (612/748; today = day 2 of 2).
    expect(find.byKey(const ValueKey('carb_summary.day_row_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('carb_summary.day_row_2')), findsOneWidget);
    expect(find.text('entry:2'), findsOneWidget);
    expect(find.textContaining('timeline:'), findsOneWidget);
    expect(find.textContaining('DAY 2 OF 2'), findsOneWidget);

    // The QUIET path: no edited targets anywhere → no dialog choice rides.
    await container
        .read(carbLoadingControllerProvider.notifier)
        .applyRepickProtocol(
          eventId: eventId,
          targetProtocolDays: 1,
          raceDate: race,
          bodyWeightPounds: weightLb,
          keepEdits: false,
        );
    await tester.pumpAndSettle();

    // Same tree, no navigation: every surface is on the 1-day plan.
    expect(find.byKey(const ValueKey('carb_summary.day_row_1')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('carb_summary.day_row_2')),
      findsNothing,
      reason: 'the dropped day-2 row cannot survive the frame',
    );
    expect(find.text('entry:1'), findsOneWidget,
        reason: 'entry-row family sees the new protocol');
    expect(find.textContaining('DAY 1 OF 1'), findsOneWidget,
        reason: 'the loading-day timeline family sees the new plan');
    expect(find.textContaining('DAY 2 OF 2'), findsNothing);
  });

  testWidgets(
      'G24 keep path: an edited target rides the repick and lands on the '
      'surfaces in the same frame', (tester) async {
    // Edit today's target first (the CE-10 write), so the repick shows the
    // keep/reset fork; keepEdits=true migrates the edit by DATE.
    final plan = await service.getCarbLoadingPlan(eventId);
    final days = await repository.getCarbLoadingDaysForPlan(plan!.id);
    final todayRow = days.firstWhere((d) => d.planDate == today);
    final container = await pump(tester);
    await container
        .read(carbLoadingControllerProvider.notifier)
        .updateDayTarget(
          carbLoadingDayId: todayRow.id,
          carbsPerKg: 9.2,
          dailyTargetG: 626,
        );
    await tester.pumpAndSettle();
    expect(find.textContaining('626'), findsWidgets,
        reason: 'the edit itself propagates (same G24 contract)');

    await container
        .read(carbLoadingControllerProvider.notifier)
        .applyRepickProtocol(
          eventId: eventId,
          targetProtocolDays: 1,
          raceDate: race,
          bodyWeightPounds: weightLb,
          keepEdits: true,
        );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('carb_summary.day_row_2')), findsNothing);
    expect(find.text('entry:1'), findsOneWidget);
    expect(find.textContaining('DAY 1 OF 1'), findsOneWidget);
    expect(find.textContaining('626'), findsWidgets,
        reason: 'the kept edit survives on the new plan, same frame');
  });
}
