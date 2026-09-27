// G29 — carb-load nudge telemetry (qa pin 2026-09-27, ops 43714e4).
//
// The 09-17 CTA lifecycle vocabulary verbatim, tagged cta=carb_load /
// cta_transport=local. Detection-power rule (the conformance-vector rule
// applied to analytics): EVERY emit path gets a test that fails if the track
// call is removed — these assert the recorded event stream itself, not the
// behaviour around it.
//
// Deliberately NOT tested, because it must not exist: a `notif_fired` for the
// 06:00 scheduled locals. The OS delivers those with no callback, so any
// "delivered" figure would be the biased proxy the 09-17 item documents (a
// tap opens the app, so tapped fires look delivered and un-tapped ones do
// not — CTR inflates toward 100%). `notif_fired` is catch-up only, and one
// case below pins that absence.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mealvana_endurance/features/carb_loading/application/carb_load_nudge_service.dart';
import 'package:mealvana_endurance/features/carb_loading/domain/carb_nudge_engine.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

/// Records the analytics stream so tests can assert on it directly.
class RecordingAnalytics extends Fake implements AnalyticsTracker {
  final events = <({String name, Map<String, dynamic> props})>[];

  @override
  Future<void> track(String eventName, {Map<String, dynamic>? properties}) async {
    events.add((name: eventName, props: properties ?? const {}));
  }

  List<Map<String, dynamic>> propsFor(String name) =>
      events.where((e) => e.name == name).map((e) => e.props).toList();

  List<String> get names => events.map((e) => e.name).toList();
}

class FakeGateway implements CarbNudgeGateway {
  FakeGateway({this.enabled = true});
  bool enabled;

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required String payload,
  }) async {}

  @override
  Future<void> cancel(int id) async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {}

  @override
  Future<bool> notificationsEnabled() async => enabled;
}

void main() {
  final race = DateTime(2026, 9, 27);
  const eventId = 'evt-augusta';
  final event = (id: eventId, name: 'Ironman 70.3 Augusta', raceDate: race);

  late RecordingAnalytics analytics;
  late FakeGateway gateway;
  late SharedPreferences prefs;

  CarbLoadNudgeService svc(DateTime now) => CarbLoadNudgeService(
        gateway: gateway,
        prefs: prefs,
        analytics: analytics,
        clock: () => now,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    analytics = RecordingAnalytics();
    gateway = FakeGateway();
  });

  test('notif_scheduled: one per armed fire, with the pinned properties',
      () async {
    await svc(DateTime(2026, 9, 20, 12)).armEvent(event);

    final scheduled = analytics.propsFor('notif_scheduled');
    expect(scheduled, hasLength(3), reason: 'race-3, -2, -1');
    for (final p in scheduled) {
      expect(p['cta'], 'carb_load');
      expect(p['cta_transport'], 'local');
      expect(p['event_id'], eventId);
      expect(p['notifications_enabled'], true);
    }
    expect(
      scheduled.map((p) => p['days_before']).toList(),
      [3, 2, 1],
      reason: 'the slot is what makes scheduled->tapped decomposable',
    );
    expect(
      scheduled.map((p) => p['fire_at']).toList(),
      CarbNudgeEngine.allFires(race).map((d) => d.toIso8601String()).toList(),
    );
  });

  test(
      'notif_scheduled carries notifications_enabled=false — the silent '
      'permission bail becomes visible instead of vanishing', () async {
    gateway.enabled = false;
    await svc(DateTime(2026, 9, 20, 12)).armEvent(event);

    final scheduled = analytics.propsFor('notif_scheduled');
    expect(scheduled, hasLength(3),
        reason: 'we still record the intent — otherwise a denied athlete is '
            'indistinguishable from one who was never in a window');
    expect(scheduled.every((p) => p['notifications_enabled'] == false), isTrue);
  });

  test('notif_fired: emitted for the CATCH-UP path only, tagged path=catchup',
      () async {
    // Armed yesterday; opening at 05:00 on race-2, before today's 06:00 fire.
    await svc(DateTime(2026, 9, 24, 12)).armEvent(event);
    analytics.events.clear();

    await svc(DateTime(2026, 9, 25, 5))
        .evaluateOnOpen(events: [event], eventIdsWithPlan: {});

    final fired = analytics.propsFor('notif_fired');
    expect(fired, hasLength(1));
    expect(fired.single['path'], 'catchup');
    expect(fired.single['cta'], 'carb_load');
    expect(fired.single['event_id'], eventId);
    expect(fired.single['days_before'], 2);
  });

  test(
      'no notif_fired is invented for a scheduled 06:00 local the OS '
      'delivered — unobservability is preserved', () async {
    // Armed, then opened AFTER today's 06:00 fire already delivered.
    await svc(DateTime(2026, 9, 24, 12)).armEvent(event);
    analytics.events.clear();

    await svc(DateTime(2026, 9, 25, 9))
        .evaluateOnOpen(events: [event], eventIdsWithPlan: {});

    expect(analytics.propsFor('notif_fired'), isEmpty,
        reason: 'the app cannot observe an OS-delivered local; claiming it '
            'would rebuild the biased delivered-rate proxy');
  });

  test('notif_cancelled(plan_created) when a plan appears', () async {
    await svc(DateTime(2026, 9, 24, 12)).armEvent(event);
    analytics.events.clear();

    await svc(DateTime(2026, 9, 25, 9))
        .evaluateOnOpen(events: [event], eventIdsWithPlan: {eventId});

    final cancelled = analytics.propsFor('notif_cancelled');
    expect(cancelled, hasLength(1));
    expect(cancelled.single['reason'], 'plan_created');
    expect(cancelled.single['event_id'], eventId);
    expect(cancelled.single['cta'], 'carb_load');
  });

  test('notif_cancelled(window_passed) when the race arrives unconverted',
      () async {
    await svc(DateTime(2026, 9, 24, 12)).armEvent(event);
    analytics.events.clear();

    // Race day: window closed, still no plan.
    await svc(DateTime(2026, 9, 27, 9))
        .evaluateOnOpen(events: [event], eventIdsWithPlan: {});

    final cancelled = analytics.propsFor('notif_cancelled');
    expect(cancelled, hasLength(1));
    expect(cancelled.single['reason'], 'window_passed');
  });

  test('a re-arm reports itself as fresh notif_scheduled, not cancel/re-arm',
      () async {
    await svc(DateTime(2026, 9, 24, 12)).armEvent(event);
    analytics.events.clear();

    // Arming again (idempotent clear inside armEvent) must not emit a cancel.
    await svc(DateTime(2026, 9, 24, 13)).armEvent(event);

    expect(analytics.propsFor('notif_cancelled'), isEmpty);
    expect(analytics.propsFor('notif_scheduled'), isNotEmpty);
  });

  test('notif_tapped: the carb_event dispatch branch records the tap',
      () async {
    NotificationService.configure(analytics);
    addTearDown(() => NotificationService.configure(
          const NoopAnalyticsTracker(),
        ));

    NotificationService.handleNotificationPayloadForTest(
      CarbNudgeEngine.payload(eventId),
    );

    final tapped = analytics.propsFor('notif_tapped');
    expect(tapped, hasLength(1),
        reason: 'headline metric is scheduled -> tapped; without this emit '
            'the denominator has no numerator');
    expect(tapped.single['cta'], 'carb_load');
    expect(tapped.single['cta_transport'], 'local');
    expect(tapped.single['event_id'], eventId);
  });
}
