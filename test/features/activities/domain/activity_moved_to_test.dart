// Unit tests for `Activity.movedTo` — the single home of the rule "an in-app
// date/time edit moves plannedTime with scheduledDateTime, because
// `displayTime` (actualTime ?? plannedTime ?? scheduledDateTime) prefers
// plannedTime and would otherwise keep the workout on the old day while the
// plan screen shows the new one" (prod 1.29.0, activity c0c76488).
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  final original = DateTime(2026, 10, 12, 7, 30);
  final target = DateTime(2026, 10, 15, 7, 30);

  Activity base({DateTime? plannedTime, DateTime? actualTime}) {
    return Activity(
      id: 'a1',
      userId: 'u1',
      activityType: ActivityType.running,
      title: 'Tempo',
      scheduledDateTime: original,
      plannedTime: plannedTime,
      actualTime: actualTime,
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
  }

  group('Activity.movedTo', () {
    test(
      'moves plannedTime with scheduledDateTime when plannedTime is set',
      () {
        final moved = base(plannedTime: original).movedTo(target);

        expect(moved.scheduledDateTime, target);
        expect(moved.plannedTime, target);
        expect(moved.displayTime, target);
      },
    );

    test('keeps plannedTime null when it was null', () {
      final moved = base().movedTo(target);

      expect(moved.scheduledDateTime, target);
      expect(moved.plannedTime, isNull);
      expect(moved.displayTime, target);
    });

    test('leaves actualTime untouched', () {
      final performed = DateTime(2026, 10, 12, 8, 2);
      final moved = base(
        plannedTime: original,
        actualTime: performed,
      ).movedTo(target);

      expect(moved.actualTime, performed);
      expect(moved.plannedTime, target);
      expect(moved.scheduledDateTime, target);
    });

    test('does not mutate the receiver', () {
      final source = base(plannedTime: original);
      source.movedTo(target);

      expect(source.scheduledDateTime, original);
      expect(source.plannedTime, original);
    });
  });
}
