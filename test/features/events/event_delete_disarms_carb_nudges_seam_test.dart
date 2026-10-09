// Ticket 80 (round develop-2026-10, Finding 69-005): deleting an event left
// its three carb-load reminders scheduled, so the OS fired "carb load" at
// 06:00 on days 3, 2 and 1 for a race that no longer existed, and the tap
// deep-linked to the deleted event.
//
// Seam test (docs/test/README.md §Seam tests): the real EventsController,
// EventsService and EventsRepository on an in-memory Drift with a real
// SupabaseClient over FakePostgrest, and the real CarbLoadNudgeService over a
// recording gateway and mock SharedPreferences. The event goes in the way the
// form sends it (`DateTime.toIso8601String()`, naive local) and is armed by
// the real sweep.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_load_nudge_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_nudge_engine.dart';
import 'package:mealvana_endurance/features/carb_loading/presentation/providers/carb_nudge_coordinator.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/events/application/events_service.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/presentation/providers/events_controller.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/fake_postgrest.dart';
import '../../helpers/fakes/recording_report.dart';

const _athlete = '80a0e000-0000-4000-8000-000000000080';

// Today, and a race 30 days out as the form sends it.
final _now = DateTime(2026, 10, 9, 12);
const _raceStart = '2026-11-08T07:00:00.000';

class _MockActivitiesService extends Mock implements ActivitiesService {}

class _MockCoachRepository extends Mock implements CoachRepository {}

class _NoopSyncCoordinator extends SyncCoordinator {
  @override
  SyncState build() => SyncState.idle;

  @override
  Future<void> ensureSynced(
    String repoKey,
    String userId, {
    SyncableRepository? repository,
  }) async {}
}

class _NoopNudge extends CarbNudgeCoordinator {
  @override
  Future<void> run() async {}
}

class _RecordingGateway implements CarbNudgeGateway {
  final scheduled = <int>[];
  final cancelled = <int>[];
  bool cancelThrows = false;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required String payload,
  }) async => scheduled.add(id);

  @override
  Future<void> cancel(int id) async {
    if (cancelThrows) throw StateError('plugin cancel failed');
    cancelled.add(id);
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {}

  @override
  Future<bool> notificationsEnabled() async => true;
}

class _RecordingAnalytics extends Fake implements AnalyticsTracker {
  final events = <({String name, Map<String, dynamic>? props})>[];

  @override
  Future<void> track(
    String eventName, {
    Map<String, dynamic>? properties,
  }) async => events.add((name: eventName, props: properties));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePostgrest server;
  late RecordingReport report;
  late _RecordingGateway gateway;
  late _RecordingAnalytics analytics;
  late SharedPreferences prefs;
  late CarbLoadNudgeService nudges;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    server = FakePostgrest();
    report = RecordingReport();
    gateway = _RecordingGateway();
    analytics = _RecordingAnalytics();
    nudges = CarbLoadNudgeService(
      gateway: gateway,
      prefs: prefs,
      analytics: analytics,
      clock: () => _now,
    );
    final repository = EventsRepository(
      supabase: server.client,
      database: db,
      report: report,
      carbLoadingRepository: CarbLoadingRepository(
        supabase: server.client,
        database: db,
        report: report,
      ),
    );
    final service = EventsService(
      db,
      repository,
      _MockActivitiesService(),
      _MockCoachRepository(),
      report: report,
    );
    container = ProviderContainer(
      overrides: [
        eventsServiceProvider.overrideWithValue(service),
        eventsRepositoryProvider.overrideWithValue(repository),
        reportProvider.overrideWithValue(report),
        syncCoordinatorProvider.overrideWith(_NoopSyncCoordinator.new),
        userIdProvider.overrideWith((ref) async => _athlete),
        carbNudgeCoordinatorProvider.overrideWith(_NoopNudge.new),
        carbLoadNudgeServiceProvider.overrideWithValue(nudges),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  EventsController controller() =>
      container.read(eventsControllerProvider.notifier);

  /// Creates the event through the controller and arms it with the real
  /// open/resume sweep, as the app does after a create.
  Future<String> createArmedEvent() async {
    await container.read(eventsControllerProvider.future);
    final id = await controller().createEvent(
      eventType: ActivityType.running,
      eventName: 'Tw80 Race',
      startTime: _raceStart,
    );
    await nudges.evaluateOnOpen(
      events: [(id: id, name: 'Tw80 Race', raceDate: DateTime(2026, 11, 8))],
      eventIdsWithPlan: const {},
    );
    expect(
      gateway.scheduled.toSet(),
      CarbNudgeEngine.allNotificationIds(id).toSet(),
      reason: 'three reminders armed before the delete',
    );
    expect(prefs.getStringList('carb_nudge_armed_$id'), isNotEmpty);
    gateway.cancelled.clear();
    analytics.events.clear();
    return id;
  }

  test('deleting an event cancels its three carb-load reminders', () async {
    final id = await createArmedEvent();

    await controller().deleteEvent(id);

    expect(
      gateway.cancelled.toSet(),
      CarbNudgeEngine.allNotificationIds(id).toSet(),
      reason: 'every slot id for the event is cancelled',
    );
    expect(prefs.getStringList('carb_nudge_armed_$id'), isNull);
    final cancels = analytics.events.where((e) => e.name == 'notif_cancelled');
    expect(cancels, hasLength(1));
    expect(cancels.single.props?['reason'], 'event_deleted');
    expect(cancels.single.props?['event_id'], id);
    expect(await db.select(db.eventsTable).get(), isEmpty);
    expect(
      server.writes.where((w) => w.table == 'events' && w.method == 'DELETE'),
      hasLength(1),
      reason: 'only the event row is deleted on the server',
    );
    expect(report.faults, isEmpty);
    expect(report.degradeds, isEmpty);
  });

  test('a failed cancel does not fail the delete and is written down', () async {
    final id = await createArmedEvent();
    gateway.cancelThrows = true;

    await controller().deleteEvent(id);

    expect(await db.select(db.eventsTable).get(), isEmpty);
    final degraded = report.degradeds.where((r) => r.area == 'carb_loading');
    expect(degraded, hasLength(1));
    expect(degraded.single.extra?['eventId'], id);
    expect(report.faults, isEmpty);
  });

  test('a delete with nothing armed leaves a note (D9)', () async {
    await container.read(eventsControllerProvider.future);
    final id = await controller().createEvent(
      eventType: ActivityType.running,
      eventName: 'Never armed',
      startTime: _raceStart,
    );

    await controller().deleteEvent(id);

    expect(
      gateway.cancelled.toSet(),
      CarbNudgeEngine.allNotificationIds(id).toSet(),
      reason: 'cancel is still sent; it is idempotent',
    );
    expect(analytics.events.where((e) => e.name == 'notif_cancelled'), isEmpty);
    final notes = report.notes.where((r) => r.area == 'carb_loading');
    expect(notes, hasLength(1));
    expect(notes.single.data?['eventId'], id);
  });

  test('deleting twice: the second disarm sends no second notif_cancelled',
      () async {
    final id = await createArmedEvent();

    await controller().deleteEvent(id);
    await controller().deleteEvent(id);

    expect(
      analytics.events.where((e) => e.name == 'notif_cancelled'),
      hasLength(1),
    );
  });
}
