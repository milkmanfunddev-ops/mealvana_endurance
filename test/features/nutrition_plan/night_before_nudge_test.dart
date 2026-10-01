// The night-before long-workout nudge (ruled 2026-09-30, Xuan).
//
// These pin the DURABLE parts — >= 90 min, 19:00 local the evening before,
// skipped entirely when a plan exists — and the copy, which is approved "for
// now" and revisable. A test that fails because the copy changed is doing its
// job: it forces the change to be deliberate rather than incidental.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/nutrition_plan/application/night_before_nudge_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/night_before_nudge_engine.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';

class _FakeGateway implements NightBeforeNudgeGateway {
  final scheduled =
      <
        ({int id, String title, String body, DateTime fireAt, String payload})
      >[];
  final cancelled = <int>[];

  @override
  Future<void> schedule({
    required int id,
    required String title,
    required String body,
    required DateTime fireAt,
    required String payload,
  }) async => scheduled.add((
    id: id,
    title: title,
    body: body,
    fireAt: fireAt,
    payload: payload,
  ));

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
        NightBeforeNudgeEngine.fireInstantFor(
          morning,
          NightBeforeVariant.noPlan,
        ),
        DateTime(2026, 10, 2, 19, 0),
      );
      expect(
        NightBeforeNudgeEngine.fireInstantFor(
          evening,
          NightBeforeVariant.noPlan,
        ),
        DateTime(2026, 10, 2, 19, 0),
      );
    });

    test('an evening already past is never back-scheduled', () {
      final workout = DateTime(2026, 10, 3, 6, 0);
      expect(
        NightBeforeNudgeEngine.isFireAhead(
          workoutStart: workout,
          now: DateTime(2026, 10, 2, 18, 59),
          variant: NightBeforeVariant.noPlan,
        ),
        isTrue,
      );
      expect(
        NightBeforeNudgeEngine.isFireAhead(
          workoutStart: workout,
          now: DateTime(2026, 10, 2, 19, 1),
          variant: NightBeforeVariant.noPlan,
        ),
        isFalse,
      );
    });
  });

  test('rehearse fires 30 minutes after the no-plan nudge, never together', () {
    // Ruled 2026-09-30: an athlete with a mixed calendar can earn both on one
    // evening; stacked at one instant they read as a duplicate.
    final workout = DateTime(2026, 10, 3, 6, 0);
    final noPlan = NightBeforeNudgeEngine.fireInstantFor(
      workout,
      NightBeforeVariant.noPlan,
    );
    final rehearse = NightBeforeNudgeEngine.fireInstantFor(
      workout,
      NightBeforeVariant.rehearse,
    );

    expect(noPlan, DateTime(2026, 10, 2, 19, 0));
    expect(rehearse, DateTime(2026, 10, 2, 19, 30));
    expect(rehearse.difference(noPlan), const Duration(minutes: 30));
    expect(rehearse, isNot(noPlan));
  });

  group('no-plan copy, RE-RULED 2026-09-30 (duration removed)', () {
    test('the ruled sentence, per sport', () {
      expect(
        NightBeforeNudgeEngine.titleFor(ActivityType.running),
        'Plan fueling for your long run tomorrow!',
      );
      expect(
        NightBeforeNudgeEngine.titleFor(ActivityType.cycling),
        'Plan fueling for your long ride tomorrow!',
      );
      expect(
        NightBeforeNudgeEngine.titleFor(ActivityType.swimming),
        'Plan fueling for your long swim tomorrow!',
      );
      expect(
        NightBeforeNudgeEngine.titleFor(ActivityType.brick),
        'Plan fueling for your long brick workout tomorrow!',
      );
    });

    test('an unmapped sport says workout, never another sport', () {
      for (final t in [
        ActivityType.triathlon,
        ActivityType.duathlon,
        ActivityType.other,
        null,
      ]) {
        expect(
          NightBeforeNudgeEngine.titleFor(t),
          'Plan fueling for your long workout tomorrow!',
          reason: '$t must not borrow a sport word',
        );
      }
    });

    test('NO DURATION appears anywhere in the copy', () {
      // The whole point of the re-ruling: "long brick is enough".
      for (final t in [
        ActivityType.running,
        ActivityType.cycling,
        ActivityType.brick,
        null,
      ]) {
        final title = NightBeforeNudgeEngine.titleFor(t);
        expect(
          RegExp(r'\d').hasMatch(title),
          isFalse,
          reason: 'no digits: $title',
        );
        expect(title.contains(' h '), isFalse);
        expect(title.contains(' m '), isFalse);
      }
      expect(NightBeforeNudgeEngine.noPlanBody, isEmpty);
    });

    test('each variant carries its own intent, not a screen', () {
      expect(
        NightBeforeNudgeEngine.payloadFor('abc', NightBeforeVariant.noPlan),
        'plan_workout:abc',
      );
      expect(
        NightBeforeNudgeEngine.payloadFor('abc', NightBeforeVariant.rehearse),
        'rehearse_plan:abc',
      );
    });

    test('the rehearse line is UNCHANGED and keeps its own phrasing', () {
      // Ruled separately: rehearse says "your long brick", the no-plan
      // sentence says "your long brick workout". Not a typo — two rulings.
      expect(
        NightBeforeNudgeEngine.rehearseBody(ActivityType.brick),
        "Rehearse your nutrition plan for your long brick. Get 'em ready!",
      );
      expect(
        NightBeforeNudgeEngine.titleFor(ActivityType.brick),
        contains('brick workout'),
      );
      expect(
        NightBeforeNudgeEngine.rehearseBody(ActivityType.cycling),
        "Rehearse your nutrition plan for your long ride. Get 'em ready!",
      );
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
      type: ActivityType.running,
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
      expect(s.title, 'Plan fueling for your long run tomorrow!');
      expect(s.body, isEmpty);
      expect(s.payload, 'plan_workout:act-long');
      expect(events.map((e) => e.name), contains('night_before_nudge_sent'));
    });

    test('a planned workout gets the REHEARSE variant, not silence', () async {
      // Ruled 2026-09-30 (second pass), replacing "skip entirely".
      await build().evaluate([
        (
          id: 'act-long',
          start: tomorrowLong.start,
          durationMinutes: 135,
          hasPlan: true,
          type: ActivityType.running,
        ),
      ]);

      final s = gateway.scheduled.single;
      expect(s.fireAt, DateTime(2026, 10, 1, 19, 30));
      expect(s.title, "Rehearse tomorrow's fueling");
      expect(
        s.body,
        "Rehearse your nutrition plan for your long run. Get 'em ready!",
      );
      expect(s.payload, 'rehearse_plan:act-long');
      expect(
        events
            .firstWhere((e) => e.name == 'night_before_nudge_sent')
            .props?['variant'],
        'rehearse',
      );
    });

    test(
      'a plan created AFTER arming SWAPS the variant at the same slot',
      () async {
        await build().evaluate([tomorrowLong]);
        expect(gateway.scheduled.single.payload, 'plan_workout:act-long');

        await build().evaluate([
          (
            id: 'act-long',
            start: tomorrowLong.start,
            durationMinutes: 135,
            hasPlan: true,
            type: ActivityType.running,
          ),
        ]);

        // Same notification id (so it replaces rather than duplicating), but the
        // fire time MOVES with the variant: 19:00 -> 19:30.
        expect(gateway.scheduled, hasLength(2));
        expect(gateway.scheduled.last.payload, 'rehearse_plan:act-long');
        expect(gateway.scheduled.last.id, gateway.scheduled.first.id);
        expect(gateway.scheduled.first.fireAt, DateTime(2026, 10, 1, 19, 0));
        expect(gateway.scheduled.last.fireAt, DateTime(2026, 10, 1, 19, 30));
      },
    );

    test('the swap reports sent again — the funnel must not lose it', () async {
      // Keyed by id alone this would be suppressed, firing a notification no
      // event ever recorded.
      await build().evaluate([tomorrowLong]);
      await build().evaluate([
        (
          id: 'act-long',
          start: tomorrowLong.start,
          durationMinutes: 135,
          hasPlan: true,
          type: ActivityType.running,
        ),
      ]);

      final sent = events.where((e) => e.name == 'night_before_nudge_sent');
      expect(sent, hasLength(2));
      expect(sent.map((e) => e.props?['variant']), ['no_plan', 'rehearse']);
    });

    test('a rehearse tap does not seed plan attribution', () async {
      final service = build();
      await service.recordTap('act-long', variant: NightBeforeVariant.rehearse);

      await service.evaluate([
        (
          id: 'act-long',
          start: tomorrowLong.start,
          durationMinutes: 135,
          hasPlan: true,
          type: ActivityType.running,
        ),
      ]);

      // The plan already existed; "a plan appeared after the tap" is
      // meaningless for this variant.
      expect(
        events.where((e) => e.name == 'night_before_nudge_plan_created'),
        isEmpty,
      );
      expect(
        events
            .firstWhere((e) => e.name == 'night_before_nudge_tapped')
            .props?['variant'],
        'rehearse',
      );
    });

    test('a short workout is never armed', () async {
      await build().evaluate([
        (
          id: 'act-short',
          start: tomorrowLong.start,
          durationMinutes: 60,
          hasPlan: false,
          type: ActivityType.running,
        ),
      ]);
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

      await service.evaluate([
        (
          id: 'act-long',
          start: tomorrowLong.start,
          durationMinutes: 135,
          hasPlan: true,
          type: ActivityType.running,
        ),
      ]);

      expect(
        events.map((e) => e.name),
        contains('night_before_nudge_plan_created'),
      );
    });

    test(
      'a plan created outside the attribution window is not attributed',
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
        await late.evaluate([
          (
            id: 'act-long',
            start: tomorrowLong.start,
            durationMinutes: 135,
            hasPlan: true,
            type: ActivityType.running,
          ),
        ]);

        expect(
          events.where((e) => e.name == 'night_before_nudge_plan_created'),
          isEmpty,
        );
      },
    );
  });

  /// THE DEV OVERRIDE, which was quietly making device testing impossible.
  ///
  /// `evaluate` re-arms unconditionally on every open and resume — correct,
  /// because a workout's time, duration or plan state may have moved. Under
  /// `fastFire` the instant used to be recomputed as `now + 2min` each time, so
  /// every touch of the app pushed every pending nudge two minutes further
  /// away. Observed on device 2026-10-01: resumes at 10:45:58, 10:46:02 and
  /// 10:52:16 re-lit a two-minute fuse before it could burn down, and the ride
  /// and brick nudges never fired at all.
  ///
  /// Production is deliberately untouched: `fireInstantFor` derives the instant
  /// from the WORKOUT's start, so re-arming reschedules the same 19:00.
  group('fastFire (dev override)', () {
    late _FakeGateway gateway;
    late SharedPreferences prefs;

    final t0 = DateTime(2026, 10, 1, 10, 45, 48);

    ({
      String id,
      DateTime start,
      int? durationMinutes,
      bool hasPlan,
      ActivityType type,
    })
    workout(String id, ActivityType type) => (
      id: id,
      start: DateTime(2026, 10, 2, 7, 0),
      durationMinutes: 135 as int?,
      hasPlan: false,
      type: type,
    );

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      gateway = _FakeGateway();
    });

    NightBeforeNudgeService at(DateTime now) => NightBeforeNudgeService(
      gateway: gateway,
      prefs: prefs,
      analytics: const NoopAnalyticsTracker(),
      clock: () => now,
      fastFire: true,
    );

    test('a resume does NOT push the fire instant away', () async {
      final run = workout('act-run', ActivityType.running);

      await at(t0).evaluate([run]);
      final first = gateway.scheduled.single.fireAt;

      // His actual usage, the part that broke it: resumes 10 and 14 seconds
      // apart, each one previously re-lighting the fuse from scratch. (The
      // later resume at +388s is PAST the fire instant, so arming fresh there
      // is correct — that case is its own test below.)
      await at(t0.add(const Duration(seconds: 10))).evaluate([run]);
      await at(t0.add(const Duration(seconds: 14))).evaluate([run]);
      await at(t0.add(const Duration(seconds: 100))).evaluate([run]);

      expect(
        gateway.scheduled.map((e) => e.fireAt).toSet(),
        {first},
        reason: 'the fuse is lit once and then held, not re-lit per resume',
      );
    });

    test('three candidates do not all fire at the same instant', () async {
      // The old offsets separated the two VARIANTS but not the WORKOUTS, so
      // three no-plan candidates shared one instant — which is also what made
      // "does iOS coalesce same-second notifications?" unanswerable.
      await at(t0).evaluate([
        workout('act-run', ActivityType.running),
        workout('act-ride', ActivityType.cycling),
        workout('act-brick', ActivityType.brick),
      ]);

      final instants = gateway.scheduled.map((e) => e.fireAt).toList();
      expect(instants, hasLength(3));
      expect(
        instants.toSet(),
        hasLength(3),
        reason: 'staggered, so a dropped banner cannot be blamed on coalescing',
      );
      expect(
        gateway.scheduled.map((e) => e.id).toSet(),
        hasLength(3),
        reason: 'and three distinct notification ids, so none replaces another',
      );
    });

    test('a held instant is released once it has passed', () async {
      final run = workout('act-run', ActivityType.running);

      await at(t0).evaluate([run]);
      final first = gateway.scheduled.single.fireAt;

      // Well after the fire: that nudge has had its moment, so a later sweep
      // must be free to arm a fresh one rather than holding a dead instant.
      final later = first.add(const Duration(minutes: 5));
      await at(later).evaluate([run]);

      expect(gateway.scheduled.last.fireAt.isAfter(later), isTrue);
      expect(gateway.scheduled.last.fireAt, isNot(first));
    });

    test('production timing is untouched by the hold', () async {
      final run = workout('act-run', ActivityType.running);
      final service = NightBeforeNudgeService(
        gateway: gateway,
        prefs: prefs,
        analytics: const NoopAnalyticsTracker(),
        clock: () => t0,
      );

      await service.evaluate([run]);
      await service.evaluate([run]);

      // 19:00 the evening before, both times — derived from the workout, so
      // there was never any churn to fix here.
      expect(gateway.scheduled.map((e) => e.fireAt).toSet(), {
        DateTime(2026, 10, 1, 19, 0),
      });
    });
  });
}
