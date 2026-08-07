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
