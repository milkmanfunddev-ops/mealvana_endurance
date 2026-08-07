import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/onboarding/application/training_insight_service.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

Activity _activity({
  required String id,
  required ActivityType type,
  required DateTime when,
  int? durationMinutes,
  int? actualDurationMinutes,
  double? distanceMiles,
  ActivityStatus status = ActivityStatus.planned,
  DateTime? deletedAt,
}) {
  final now = DateTime(2026, 8, 1);
  return Activity(
    id: id,
    userId: 'user-1',
    activityType: type,
    title: '${type.displayName} $id',
    scheduledDateTime: when,
    status: status,
    durationMinutes: durationMinutes,
    actualDurationMinutes: actualDurationMinutes,
    distanceMiles: distanceMiles,
    deletedAt: deletedAt,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  final monday = DateTime(2026, 7, 20);

  group('TrainingInsightService.digest', () {
    test('empty list is the unreliable none digest', () {
      final insights = TrainingInsightService.digest(const []);
      expect(insights.isReliable, isFalse);
      expect(insights.sessionCount, 0);
      expect(insights.longestRun, isNull);
      expect(insights.longestRide, isNull);
    });

    test('full reliable week: longest run/ride and heavy days correct', () {
      final insights = TrainingInsightService.digest([
        _activity(
          id: 'a',
          type: ActivityType.running,
          when: monday,
          durationMinutes: 45,
        ),
        _activity(
          id: 'b',
          type: ActivityType.cycling,
          when: monday.add(const Duration(days: 2)),
          durationMinutes: 130,
        ),
        _activity(
          id: 'c',
          type: ActivityType.running,
          when: monday.add(const Duration(days: 4)),
          durationMinutes: 60,
        ),
        _activity(
          id: 'd',
          type: ActivityType.running,
          when: monday.add(const Duration(days: 6)),
          durationMinutes: 150,
          distanceMiles: 15,
        ),
      ]);

      expect(insights.isReliable, isTrue);
      expect(insights.windowDays, 7);
      expect(insights.sessionCount, 4);
      expect(insights.heavyDayCount, 4);

      // The digest reports the real span it read, and keeps every session
      // that fed it (earliest first) for the reveal card's debug sheet.
      expect(insights.windowStart, monday);
      expect(insights.windowEnd, monday.add(const Duration(days: 6)));
      expect(insights.windowRangeLabel, 'Jul 20 to Jul 26');
      expect(insights.sessions.length, 4);
      expect(insights.sessions.first.scheduledDateTime, monday);
      expect(
        insights.sessions.last.scheduledDateTime,
        monday.add(const Duration(days: 6)),
      );
      expect(insights.longestRun!.durationMinutes, 150);
      expect(insights.longestRun!.descriptor, 'your 15-mile long run');
      expect(insights.longestRide!.durationMinutes, 130);
      // 385 min over exactly 7 days → 6.4 h/week (rounded to 1dp).
      expect(insights.weeklyDurationHours, closeTo(6.4, 0.05));

      // Weekday load pattern: 4 distinct weekdays clears the ≥4 minimum.
      // By minutes — d(+6,150) > b(+2,130) > c(+4,60) > a(+0,45) — the top
      // two (+6, +2) are heavy, the bottom two (+0, +4) are light.
      expect(insights.hasWeekdayPattern, isTrue);
      expect(
        insights.heavyWeekdays,
        [monday.add(const Duration(days: 6)).weekday,
            monday.add(const Duration(days: 2)).weekday]
          ..sort(),
      );
      expect(
        insights.lightWeekdays,
        [monday.weekday, monday.add(const Duration(days: 4)).weekday]..sort(),
      );
    });

    test(
      'distance-prescribed plan (Final Surge shape) is digested, not dropped',
      () {
        // Final Surge writes durationMinutes: null whenever the workout
        // carries distance or pace — see
        // FinalSurgeTransformer._getFallbackDurationMinutes. A whole
        // running block therefore arrives distance-only, and used to
        // digest to nothing: 21 synced workouts, "no scheduled sessions
        // to read yet", empty diagnostic list.
        final insights = TrainingInsightService.digest([
          _activity(
            id: 'a',
            type: ActivityType.running,
            when: monday,
            distanceMiles: 5,
          ),
          _activity(
            id: 'b',
            type: ActivityType.running,
            when: monday.add(const Duration(days: 2)),
            distanceMiles: 8,
          ),
          _activity(
            id: 'c',
            type: ActivityType.running,
            when: monday.add(const Duration(days: 4)),
            distanceMiles: 6,
          ),
          _activity(
            id: 'd',
            type: ActivityType.running,
            when: monday.add(const Duration(days: 6)),
            distanceMiles: 15,
          ),
        ]);

        expect(insights.sessionCount, 4);
        expect(insights.sessions, hasLength(4));
        expect(insights.windowRangeLabel, 'Jul 20 to Jul 26');

        // The 15-miler is the long run, and the reveal quotes its
        // distance — the estimated minutes never reach the copy.
        expect(insights.longestRun, isNotNull);
        expect(insights.longestRun!.descriptor, 'your 15-mile long run');
        // 15 mi × 9.5 min/mi ≈ 143 min, clearing the 90-min long-session
        // bar, so a distance-only block is reliable like any other.
        expect(insights.longestRun!.durationMinutes, closeTo(143, 2));
        expect(insights.longestRun!.durationIsEstimated, isTrue);
        expect(insights.isReliable, isTrue);

        // Load still ranks correctly by distance: the 15 and 8 mile days
        // are heavy, the 5 and 6 mile days light.
        expect(insights.heavyWeekdays, [
          monday.add(const Duration(days: 2)).weekday,
          monday.add(const Duration(days: 6)).weekday,
        ]..sort());
        expect(insights.lightWeekdays, [
          monday.weekday,
          monday.add(const Duration(days: 4)).weekday,
        ]..sort());
      },
    );

    test('explicit duration is never overwritten by a distance estimate', () {
      final insights = TrainingInsightService.digest([
        _activity(
          id: 'a',
          type: ActivityType.running,
          when: monday,
          durationMinutes: 30,
          distanceMiles: 10, // would estimate 95 min if it took over
        ),
      ]);

      expect(insights.sessions.single.durationMinutes, 30);
      expect(insights.sessions.single.durationIsEstimated, isFalse);
    });

    test('rows with neither duration nor distance are still ignored', () {
      final insights = TrainingInsightService.digest([
        _activity(id: 'a', type: ActivityType.running, when: monday),
      ]);

      expect(insights.sessionCount, 0);
      expect(insights.sessions, isEmpty);
    });

    test('weekday load is averaged per occurrence, not summed', () {
      // A 10-day window contains two Fridays but only one Wednesday.
      // Ranking by totals would promote Friday purely for coming round
      // twice; averaging per occurrence is what makes the comparison fair.
      //
      // Fri: 40 + 40 = 80 over 2 Fridays → avg 40
      // Wed: 70 over 1 Wednesday        → avg 70
      // Mon: 30 over 1                  → avg 30
      // Thu: 60 over 1                  → avg 60
      final insights = TrainingInsightService.digest([
        // Fri Jul 24 and Fri Jul 31 — same weekday, twice.
        _activity(
          id: 'f1',
          type: ActivityType.running,
          when: DateTime(2026, 7, 24),
          durationMinutes: 40,
        ),
        _activity(
          id: 'f2',
          type: ActivityType.running,
          when: DateTime(2026, 7, 31),
          durationMinutes: 40,
        ),
        _activity(
          id: 'w',
          type: ActivityType.running,
          when: DateTime(2026, 7, 29),
          durationMinutes: 70,
        ),
        _activity(
          id: 'm',
          type: ActivityType.running,
          when: DateTime(2026, 7, 27),
          durationMinutes: 30,
        ),
        _activity(
          id: 't',
          type: ActivityType.running,
          when: DateTime(2026, 7, 30),
          durationMinutes: 60,
        ),
      ]);

      // By SUM Friday (80) would top the list; by average it sits third.
      expect(insights.heavyWeekdays, [
        DateTime.wednesday,
        DateTime.thursday,
      ]);
      expect(insights.lightWeekdays, [DateTime.monday, DateTime.friday]);
    });

    test('fewer than 4 distinct weekdays yields no weekday pattern', () {
      final insights = TrainingInsightService.digest([
        _activity(
          id: 'a',
          type: ActivityType.running,
          when: monday,
          durationMinutes: 45,
        ),
        _activity(
          id: 'b',
          type: ActivityType.running,
          when: monday.add(const Duration(days: 2)),
          durationMinutes: 90,
        ),
        _activity(
          id: 'c',
          type: ActivityType.running,
          when: monday.add(const Duration(days: 6)),
          durationMinutes: 60,
        ),
      ]);

      // Only 3 distinct weekdays — below minWeekdaysForPattern (4), so the
      // card should quietly omit the heavy/light line rather than guess.
      expect(insights.hasWeekdayPattern, isFalse);
      expect(insights.heavyDayNames, isNull);
      expect(insights.lightDayNames, isNull);
    });

    test('window under 7 days is unreliable even with many sessions', () {
      final insights = TrainingInsightService.digest([
        for (var day = 0; day < 5; day++)
          _activity(
            id: 'run-$day',
            type: ActivityType.running,
            when: monday.add(Duration(days: day)),
            durationMinutes: 120,
          ),
      ]);
      expect(insights.windowDays, 5);
      expect(insights.isReliable, isFalse);
    });

    test('sparse week without a long session is unreliable', () {
      final insights = TrainingInsightService.digest([
        _activity(
          id: 'a',
          type: ActivityType.running,
          when: monday,
          durationMinutes: 40,
        ),
        _activity(
          id: 'b',
          type: ActivityType.running,
          when: monday.add(const Duration(days: 7)),
          durationMinutes: 40,
        ),
      ]);
      expect(insights.windowDays, 8);
      expect(insights.sessionCount, 2);
      expect(insights.isReliable, isFalse);
    });

    test('sparse week WITH a qualifying long run is reliable', () {
      final insights = TrainingInsightService.digest([
        _activity(
          id: 'a',
          type: ActivityType.running,
          when: monday,
          durationMinutes: 40,
        ),
        _activity(
          id: 'b',
          type: ActivityType.running,
          when: monday.add(const Duration(days: 7)),
          durationMinutes: TrainingInsightService.longRunMinMinutes,
        ),
      ]);
      expect(insights.isReliable, isTrue);
    });

    test(
      'Runna-style planned workouts (no biometrics, no distance) digest fine',
      () {
        final insights = TrainingInsightService.digest([
          for (var day = 0; day < 8; day++)
            _activity(
              id: 'runna-$day',
              type: ActivityType.running,
              when: monday.add(Duration(days: day)),
              durationMinutes: 50 + day * 10,
            ),
        ]);
        expect(insights.isReliable, isTrue);
        expect(insights.longestRun!.distanceMiles, isNull);
        // No distance → duration-based descriptor.
        expect(insights.longestRun!.descriptor, 'your 2-hour long run');
      },
    );

    test('completed activities fall back to actual duration', () {
      final insights = TrainingInsightService.digest([
        _activity(
          id: 'done',
          type: ActivityType.running,
          when: monday,
          status: ActivityStatus.completed,
          actualDurationMinutes: 95,
        ),
        _activity(
          id: 'later',
          type: ActivityType.running,
          when: monday.add(const Duration(days: 7)),
          durationMinutes: 40,
        ),
      ]);
      expect(insights.longestRun!.durationMinutes, 95);
      expect(insights.isReliable, isTrue);
    });

    test('deleted, skipped, other-typed and zero-duration are ignored', () {
      final insights = TrainingInsightService.digest([
        _activity(
          id: 'deleted',
          type: ActivityType.running,
          when: monday,
          durationMinutes: 200,
          deletedAt: DateTime(2026, 7, 21),
        ),
        _activity(
          id: 'skipped',
          type: ActivityType.running,
          when: monday,
          durationMinutes: 200,
          status: ActivityStatus.skipped,
        ),
        _activity(
          id: 'yoga',
          type: ActivityType.other,
          when: monday,
          durationMinutes: 200,
        ),
        _activity(id: 'no-duration', type: ActivityType.running, when: monday),
      ]);
      expect(insights.sessionCount, 0);
      expect(insights.isReliable, isFalse);
    });

    test('brick counts toward load but not the run/ride cards', () {
      final insights = TrainingInsightService.digest([
        _activity(
          id: 'brick',
          type: ActivityType.brick,
          when: monday,
          durationMinutes: 180,
        ),
        _activity(
          id: 'run',
          type: ActivityType.running,
          when: monday.add(const Duration(days: 6)),
          durationMinutes: 60,
        ),
        _activity(
          id: 'ride',
          type: ActivityType.cycling,
          when: monday.add(const Duration(days: 3)),
          durationMinutes: 70,
        ),
      ]);
      expect(insights.sessionCount, 3);
      expect(insights.longestRun!.durationMinutes, 60);
      expect(insights.longestRide!.durationMinutes, 70);
    });
  });
}
