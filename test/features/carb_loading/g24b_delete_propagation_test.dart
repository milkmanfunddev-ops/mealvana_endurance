// G24b `delete-propagates-immediately` (1.30.0, Xuan's live bug, 2026-10-07 —
// E-3 instant-propagation): removing a plan through the REAL controller must
// flip Event Details' carb row from "Carb Loading Plan" to "Set Up Carb
// Loading" in the same pumped frame, with ZERO navigation. The live defect:
// `_invalidateCarbSurfaces` invalidated every carb family but NOT
// `eventDetailProvider`, whose cached `event.hasCarbLoading == true` kept the
// plan door open; tapping it landed on a summary that rendered
// `SizedBox.shrink()` — a blank page with no way back.
//
// Surfaces under test, bound the way the real ones are:
//  * event row — a probe watching eventDetailProvider(eventId), the SAME
//    family event_action_buttons_card reads `hasCarbLoading` from, stubbed
//    TRUTHFULLY (the flag comes from the in-memory Drift events row the
//    service writes, not a constant);
//  * entry row — a probe watching carbLoadingPlanProvider(eventId);
//  * summary — the REAL CarbPlanSummaryScreen, painted, which after the
//    delete must show its header + back control + the empty state rather
//    than nothing.
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
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_nudge_coordinator.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/screens/carb_plan_summary_screen.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
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

/// G27's re-arm sweep is fire-and-forget off the delete path and reads
/// allEventsProvider; it is not under test here, so it stands down.
class _NoopCarbNudgeCoordinator extends CarbNudgeCoordinator {
  @override
  Future<void> run() async {}
}

const userId = 'user-g24b';
const eventId = 'event-g24b';
const weightLb = 149.9;

UserProfile _profile() => UserProfile(
  id: userId,
  deviceId: 'd-g24b',
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
  late DateTime race;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    race = today.add(const Duration(days: 5));

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
        error: any(named: 'error'),
        stackTrace: any(named: 'stackTrace'),
        data: any(named: 'data'),
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

    await db
        .into(db.eventsTable)
        .insert(
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
      protocolDays: 3,
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
          carbNudgeCoordinatorProvider.overrideWith(
            () => _NoopCarbNudgeCoordinator(),
          ),
          mealLogsForDateProvider.overrideWith((ref, date) async* {
            yield const [];
          }),
          // Truthful stub: hasCarbLoading comes from the in-memory Drift
          // events row the service writes, not a constant.
          // Riverpod 3 hands the family its whole argument record
          // `(eventId, forUserId: ...)`; the row is keyed by the event id.
          eventDetailProvider.overrideWith((ref, args) async {
            final row = await (db.select(
              db.eventsTable,
            )..where((t) => t.id.equals(args.$1))).getSingle();
            return (
              activity: null,
              event: Event(
                id: row.id,
                userId: row.userId,
                eventType: ActivityType.running,
                eventDate: race,
                hasCarbLoading: row.hasCarbLoading,
                createdAt: row.createdAt,
                updatedAt: row.updatedAt,
              ),
            );
          }),
          currentUserProvider.overrideWith((ref) async => _profile()),
        ],
        child: MaterialApp(
          home: Column(
            children: [
              const Expanded(child: CarbPlanSummaryScreen(eventId: eventId)),
              // Event Details' carb row binding: the SAME family
              // event_action_buttons_card branches `hasCarbLoading` on.
              Consumer(
                builder: (context, ref, _) {
                  final event = ref
                      .watch(eventDetailProvider(eventId))
                      .value
                      ?.event;
                  return Text(
                    event == null
                        ? 'carb_row:loading'
                        : (event.hasCarbLoading
                              ? 'carb_row:plan'
                              : 'carb_row:setup'),
                  );
                },
              ),
              Consumer(
                builder: (context, ref, _) {
                  final plan = ref
                      .watch(carbLoadingPlanProvider(eventId))
                      .value;
                  return Text(
                    'entry:${plan == null ? 'none' : (plan as dynamic).totalDays}',
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

  Finder backButton() => find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == 'Back',
  );

  testWidgets(
    'G24b delete: the event row flips plan → setup and the summary shows '
    'its empty state with a back control, same frame, zero navigation',
    (tester) async {
      final container = await pump(tester);

      // The 3-day plan is on every surface.
      expect(find.text('carb_row:plan'), findsOneWidget);
      expect(find.text('entry:3'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('carb_summary.day_row_1')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('carb_summary.empty')), findsNothing);

      await container
          .read(carbLoadingControllerProvider.notifier)
          .deleteCarbLoadingPlan(eventId);
      await tester.pumpAndSettle();

      expect(
        find.text('carb_row:setup'),
        findsOneWidget,
        reason: 'eventDetail family must be invalidated by the delete write',
      );
      expect(find.text('carb_row:plan'), findsNothing);
      expect(find.text('entry:none'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('carb_summary.day_row_1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('carb_summary.empty')),
        findsOneWidget,
        reason: 'a resolved-empty summary says so instead of going blank',
      );
      expect(find.text('Carb Loading Plan'), findsOneWidget);
      expect(
        backButton(),
        findsOneWidget,
        reason: 'the back control survives the empty state',
      );
    },
  );
}
