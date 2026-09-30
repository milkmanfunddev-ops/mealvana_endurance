// The night-before long-workout nudge (ruled 2026-09-30, Xuan).
//
// These pin the DURABLE parts — >= 90 min, 19:00 local the evening before,
// skipped entirely when a plan exists — and the copy, which is approved "for
// now" and revisable. A test that fails because the copy changed is doing its
// job: it forces the change to be deliberate rather than incidental.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/nutrition_plan/application/night_before_nudge_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/night_before_nudge_engine.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';

class _FakeGateway implements NightBeforeNudgeGateway {
  final scheduled = <({int id, String title, String body, DateTime fireAt, String payload})>[];
  final cancelled = <int>[];

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required String payload,
  }) async =>
      scheduled.add((id: id, title: title, body: body, fireAt: fireAt, payload: payload));

  @override
  Future<void> cancel(int id) async => cancelled.add(id);
}

class _RecordingTracker extends NoopAnalyticsTracker {
  const _RecordingTracker(this.events);
  final List<({String name, Map<String, dynamic>? props})> events;

  @override
  Future<void> track(String name, {Map<String, dynamic>? properties}) async =>
      events.add((name: name, props: properties));
}

void main() {
  group('the ruled thresholds', () {
    test('LONG is >= 90 minutes, inclusive', () {
      expect(NightBeforeNudgeEngine.isLong(89), isFalse);
      expect(NightBeforeNudgeEngine.isLong(90), isTrue, reason: 'inclusive');
      expect(NightBeforeNudgeEngine.isLong(240), isTrue);
    });

    test('a workout with no planned duration is not long', () {
      // Guessing here would nudge people about easy workouts, which is how a
      // nudge gets muted.
      expect(NightBeforeNudgeEngine.isLong(null), isFalse);
    });

    test('fires at 19:00 local the evening BEFORE, by calendar date', () {
      // Both workouts sit on the 3rd, hours apart. They share one nudge on the
      // evening of the 2nd — a naive minus-24h would put the morning one's
      // nudge at 06:00 on the 2nd.
      final morning = DateTime(2026, 10, 3, 6, 0);
      final evening = DateTime(2026, 10, 3, 22, 0);
      expect(
        NightBeforeNudgeEngine.fireInstantFor(morning),
        DateTime(2026, 10, 2, 19, 0),
      );
      expect(
        NightBeforeNudgeEngine.fireInstantFor(evening),
        DateTime(2026, 10, 2, 19, 0),
      );
    });

    test('an evening already past is never back-scheduled', () {
      final workout = DateTime(2026, 10, 3, 6, 0);
      expect(
        NightBeforeNudgeEngine.isFireAhead(
          workoutStart: workout,
          now: DateTime(2026, 10, 2, 18, 59),
        ),
        isTrue,
      );
      expect(
        NightBeforeNudgeEngine.isFireAhead(
          workoutStart: workout,
          now: DateTime(2026, 10, 2, 19, 1),
        ),
        isFalse,
      );
    });
  });

  group('copy, approved 2026-09-30', () {
    test('reads as the ruled sentence once title and body are joined', () {
      expect(NightBeforeNudgeEngine.title, 'Long run tomorrow');
      expect(
        NightBeforeNudgeEngine.body('2 h 15 m'),
        '2 h 15 m planned. Set your fueling plan tonight.',
      );
      expect(
        '${NightBeforeNudgeEngine.title} — ${NightBeforeNudgeEngine.body("2 h 15 m")}',
        'Long run tomorrow — 2 h 15 m planned. Set your fueling plan tonight.',
      );
    });

    test('duration formats as the ruling s example', () {
      expect(NightBeforeNudgeEngine.formatDuration(135), '2 h 15 m');
      expect(NightBeforeNudgeEngine.formatDuration(120), '2 h',
          reason: 'a whole hour drops the empty minutes');
      expect(NightBeforeNudgeEngine.formatDuration(90), '1 h 30 m');
    });

    test('the payload carries the intent, not a screen', () {
      expect(NightBeforeNudgeEngine.payload('abc'), 'plan_workout:abc');
    });
  });

  group('service', () {
    late _FakeGateway gateway;
    late SharedPreferences prefs;
    late List<({String name, Map<String, dynamic>? props})> events;

    final now = DateTime(2026, 10, 1, 9, 0);
    final tomorrowLong = (
      id: 'act-long',
      start: DateTime(2026, 10, 2, 7, 0),
      durationMinutes: 135 as int?,
      hasPlan: false,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      gateway = _FakeGateway();
      events = [];
    });

    NightBeforeNudgeService build() => NightBeforeNudgeService(
      gateway: gateway,
      prefs: prefs,
      analytics: _RecordingTracker(events),
      clock: () => now,
    );

    test('arms a long unplanned workout and reports it sent', () async {
      await build().evaluate([tomorrowLong]);

      expect(gateway.scheduled, hasLength(1));
      final s = gateway.scheduled.single;
      expect(s.fireAt, DateTime(2026, 10, 1, 19, 0));
      expect(s.title, 'Long run tomorrow');
      expect(s.body, '2 h 15 m planned. Set your fueling plan tonight.');
      expect(s.payload, 'plan_workout:act-long');
      expect(events.map((e) => e.name), contains('night_before_nudge_sent'));
    });

    test('SKIPS ENTIRELY when a plan already exists — no variant, no nag',
        () async {
      await build().evaluate([(
        id: 'act-long',
        start: tomorrowLong.start,
        durationMinutes: 135,
        hasPlan: true,
      )]);

      expect(gateway.scheduled, isEmpty);
      expect(events.where((e) => e.name == 'night_before_nudge_sent'), isEmpty);
    });

    test('a plan created AFTER arming cancels the pending nudge', () async {
      await build().evaluate([tomorrowLong]);
      expect(gateway.scheduled, hasLength(1));

      // Same workout, now planned. The athlete must not be told to do
      // something they have already done.
      await build().evaluate([(
        id: 'act-long',
        start: tomorrowLong.start,
        durationMinutes: 135,
        hasPlan: true,
      )]);

      expect(
        gateway.cancelled,
        contains(NightBeforeNudgeEngine.notificationId('act-long')),
      );
    });

    test('a short workout is never armed', () async {
      await build().evaluate([(
        id: 'act-short',
        start: tomorrowLong.start,
        durationMinutes: 60,
        hasPlan: false,
      )]);
      expect(gateway.scheduled, isEmpty);
    });

    test('re-sweeping does not double-report sent', () async {
      await build().evaluate([tomorrowLong]);
      await build().evaluate([tomorrowLong]);

      expect(
        events.where((e) => e.name == 'night_before_nudge_sent'),
        hasLength(1),
        reason: 'arming is idempotent; the funnel denominator must not inflate',
      );
    });

    test('a plan created after a tap is attributed to the nudge', () async {
      final service = build();
      await service.recordTap('act-long');
      expect(events.map((e) => e.name), contains('night_before_nudge_tapped'));

      await service.evaluate([(
        id: 'act-long',
        start: tomorrowLong.start,
        durationMinutes: 135,
        hasPlan: true,
      )]);

      expect(
        events.map((e) => e.name),
        contains('night_before_nudge_plan_created'),
      );
    });

    test('a plan created outside the attribution window is not attributed',
        () async {
      await build().evaluate([tomorrowLong]);
      await NightBeforeNudgeService(
        gateway: gateway,
        prefs: prefs,
        analytics: _RecordingTracker(events),
        clock: () => now,
      ).recordTap('act-long');

      // Two days later.
      final late = NightBeforeNudgeService(
        gateway: gateway,
        prefs: prefs,
        analytics: _RecordingTracker(events),
        clock: () => now.add(const Duration(days: 2)),
      );
      await late.evaluate([(
        id: 'act-long',
        start: tomorrowLong.start,
        durationMinutes: 135,
        hasPlan: true,
      )]);

      expect(
        events.where((e) => e.name == 'night_before_nudge_plan_created'),
        isEmpty,
      );
    });
  });
}
