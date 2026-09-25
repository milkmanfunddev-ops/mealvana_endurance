// G27 L2 — the race-window carb-load nudge (CE-11, delivery rev. 2,
// qa 61c881c). Reds, by name:
//   nudge-schedule-three-daily-6h · nudge-cancelled-on-plan-create ·
//   nudge-rearmed-on-plan-delete · nudge-on-open-catchup-max-one-per-day ·
//   nudge-never-on-race-day · nudge-tap-routes-to-event-details ·
//   copy-verbatim
// The REAL CarbLoadNudgeService runs against a recording gateway, real
// SharedPreferences (mock store — the restart-survival cases build a fresh
// service over the same store), and an injected clock.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_load_nudge_service.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_nudge_engine.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';
import 'package:mealvana_endurance/shared/widgets/root_app_widget.dart';

class _Call {
  _Call(this.kind, this.id, {this.fireAt, this.title, this.body, this.payload});
  final String kind; // schedule | cancel | show
  final int id;
  final DateTime? fireAt;
  final String? title;
  final String? body;
  final String? payload;
}

class RecordingGateway implements CarbNudgeGateway {
  final calls = <_Call>[];

  List<_Call> get schedules =>
      calls.where((c) => c.kind == 'schedule').toList();
  List<_Call> get shows => calls.where((c) => c.kind == 'show').toList();
  List<_Call> get cancels => calls.where((c) => c.kind == 'cancel').toList();

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required String payload,
  }) async => calls.add(_Call('schedule', id,
      fireAt: fireAt, title: title, body: body, payload: payload));

  @override
  Future<void> cancel(int id) async => calls.add(_Call('cancel', id));

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async =>
      calls.add(_Call('show', id, title: title, body: body, payload: payload));
}

void main() {
  // Race Sunday; the walked cohort's shape (Augusta).
  final race = DateTime(2026, 9, 27);
  const eventId = 'evt-augusta';
  final event = (id: eventId, name: 'Ironman 70.3 Augusta', raceDate: race);

  late RecordingGateway gateway;
  late SharedPreferences prefs;

  Future<CarbLoadNudgeService> service(DateTime now) async {
    return CarbLoadNudgeService(
      gateway: gateway,
      prefs: prefs,
      clock: () => now,
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gateway = RecordingGateway();
  });

  test('nudge-schedule-three-daily-6h: the scheduled set is exactly '
      'race−3…−1 at 06:00 local', () async {
    final s = await service(DateTime(2026, 9, 20, 12)); // well before window
    await s.armEvent(event);
    expect(
      gateway.schedules.map((c) => c.fireAt).toList(),
      [
        DateTime(2026, 9, 24, 6), // −3
        DateTime(2026, 9, 25, 6), // −2
        DateTime(2026, 9, 26, 6), // −1
      ],
      reason: 'three fires, 06:00 local, never race day',
    );
    // Mid-window arrival (today is −2, after 06:00): only the remaining fire.
    gateway.calls.clear();
    final mid = await service(DateTime(2026, 9, 25, 10, 30));
    await mid.armEvent(event);
    expect(
      gateway.schedules.map((c) => c.fireAt).toList(),
      [DateTime(2026, 9, 26, 6)],
      reason: 'mid-window update schedules only what is still ahead',
    );
  });

  test('nudge-cancelled-on-plan-create: disarm cancels every fire id',
      () async {
    final s = await service(DateTime(2026, 9, 20, 12));
    await s.armEvent(event);
    gateway.calls.clear();
    await s.disarmEvent(eventId);
    expect(
      gateway.cancels.map((c) => c.id).toSet(),
      CarbNudgeEngine.allNotificationIds(eventId).toSet(),
    );
    expect(gateway.schedules, isEmpty);
  });

  test('nudge-rearmed-on-plan-delete: the sweep re-arms the remainder for a '
      'planless event', () async {
    final now = DateTime(2026, 9, 25, 10); // −2, after 06:00
    final s = await service(now);
    await s.disarmEvent(eventId); // plan had cancelled everything
    gateway.calls.clear();
    // Plan deleted → sweep sees no plan → re-arms remaining fires.
    prefs.setString('carb_nudge_last_shown_day', '2026-09-25'); // isolate arming
    await s.evaluateOnOpen(events: [event], eventIdsWithPlan: {});
    expect(
      gateway.schedules.map((c) => c.fireAt).toList(),
      [DateTime(2026, 9, 26, 6)],
      reason: 'only the −1 fire remains at −2 10:00',
    );
  });

  test('nudge-on-open-catchup-max-one-per-day: one show, restart-proof, '
      'scheduled fire dedupes both directions', () async {
    // −2, 05:00 — before today's 06:00 fire, armed yesterday.
    final s0 = await service(DateTime(2026, 9, 24, 12));
    await s0.armEvent(event); // arms −3(past)… wait: −3 fire already past
    gateway.calls.clear();

    final s1 = await service(DateTime(2026, 9, 25, 5));
    await s1.evaluateOnOpen(events: [event], eventIdsWithPlan: {});
    expect(gateway.shows, hasLength(1), reason: 'catch-up shows');
    expect(
      gateway.cancels.map((c) => c.id),
      contains(CarbNudgeEngine.notificationId(eventId, 2)),
      reason: "today's pending 06:00 fire is cancelled — never two in a day",
    );

    // Same day, later, FRESH SERVICE over the same prefs (restart).
    gateway.calls.clear();
    final s2 = await service(DateTime(2026, 9, 25, 9));
    await s2.evaluateOnOpen(events: [event], eventIdsWithPlan: {});
    expect(gateway.shows, isEmpty, reason: 'once per day, surviving restart');

    // Next day (−1) after the 06:00 scheduled fire delivered: no catch-up.
    gateway.calls.clear();
    final s3 = await service(DateTime(2026, 9, 26, 8));
    await s3.evaluateOnOpen(events: [event], eventIdsWithPlan: {});
    expect(gateway.shows, isEmpty,
        reason: "the day's scheduled fire already delivered — suppressed");

    // But a mid-window install at −1 07:00 with NOTHING armed for today
    // (fresh prefs) must catch up — the scheduled path never had a chance.
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    gateway.calls.clear();
    final s4 = await service(DateTime(2026, 9, 26, 7));
    await s4.evaluateOnOpen(events: [event], eventIdsWithPlan: {});
    expect(gateway.shows, hasLength(1),
        reason: 'app arrived mid-window after 06:00 — catch-up covers it');
  });

  test('nudge-never-on-race-day: no fire, no catch-up on race morning',
      () async {
    final s = await service(DateTime(2026, 9, 27, 5)); // race day, pre-6am
    await s.armEvent(event);
    expect(gateway.schedules, isEmpty,
        reason: 'no remaining fires on race day');
    await s.evaluateOnOpen(events: [event], eventIdsWithPlan: {});
    expect(gateway.shows, isEmpty, reason: 'window closed — CE-8 gates all');
    // And the engine can never produce a race-day instant at all.
    expect(
      CarbNudgeEngine.allFires(race).where((f) =>
          f.year == race.year && f.month == race.month && f.day == race.day),
      isEmpty,
    );
  });

  test('nudge-tap-routes-to-event-details: payload round-trips and maps to '
      'the event details route', () {
    final parsed = NotificationService.parseTypedNotificationPayload(
      CarbNudgeEngine.payload(eventId),
    );
    expect(parsed, isNotNull);
    expect(parsed!.type, 'carb_event');
    expect(parsed.activityId, eventId);
    expect(notificationRouteForCarbEvent(parsed.activityId),
        '/events/$eventId');
  });

  test('copy-verbatim: CE-11 register copy, character for character',
      () async {
    expect(CarbNudgeEngine.title, 'Fuel up for race day');
    expect(
      CarbNudgeEngine.body('Ironman 70.3 Augusta'),
      'Your carb load for Ironman 70.3 Augusta can start now — set up your plan.',
    );
    // The gateway receives exactly this copy on both paths.
    final s = await service(DateTime(2026, 9, 25, 5));
    await s.armEvent(event);
    await s.evaluateOnOpen(events: [event], eventIdsWithPlan: {});
    for (final call in [...gateway.schedules, ...gateway.shows]) {
      expect(call.title, CarbNudgeEngine.title);
      expect(
        call.body,
        'Your carb load for Ironman 70.3 Augusta can start now — set up your plan.',
      );
      expect(call.payload, 'carb_event:$eventId');
    }
    expect(gateway.shows, hasLength(1));
  });
}
