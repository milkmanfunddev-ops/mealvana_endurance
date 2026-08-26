import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_eligibility.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Only the three triathlon disciplines are groupable (Notion 3a7e3fdb), and
/// the Brick entry point appears whenever the day holds 2+ eligible workouts
/// — adjacency withdrawn, same-sport allowed, pick order free (Lee, 2026-08-26;
/// logic-SSOT record: qa/intake/2026-08-26-brick-eligibility-logic-ssot.md).
void main() {
  Activity act(String id, ActivityType type) => Activity(
    id: id,
    userId: 'u1',
    title: id,
    activityType: type,
    scheduledDateTime: DateTime(2026, 7, 25, 8),
    createdAt: DateTime(2026, 7, 25),
    updatedAt: DateTime(2026, 7, 25),
  );

  group('isBrickEligible', () {
    test('accepts the three triathlon disciplines', () {
      expect(act('a', ActivityType.swimming).isBrickEligible, isTrue);
      expect(act('b', ActivityType.cycling).isBrickEligible, isTrue);
      expect(act('c', ActivityType.running).isBrickEligible, isTrue);
    });

    test('rejects strength / imported "other" work — the bug Xuan flagged', () {
      expect(act('d', ActivityType.other).isBrickEligible, isFalse);
    });

    test('rejects an existing brick and other multi-sport types', () {
      expect(act('e', ActivityType.brick).isBrickEligible, isFalse);
      expect(act('f', ActivityType.triathlon).isBrickEligible, isFalse);
      expect(act('g', ActivityType.duathlon).isBrickEligible, isFalse);
      expect(act('h', ActivityType.multisport).isBrickEligible, isFalse);
    });
  });

  group('hasBrickCandidates', () {
    test('false for a single eligible workout', () {
      expect(hasBrickCandidates([act('a', ActivityType.running)]), isFalse);
    });

    test('true for two eligible workouts of different sports', () {
      expect(
        hasBrickCandidates([
          act('a', ActivityType.swimming),
          act('b', ActivityType.running),
        ]),
        isTrue,
      );
    });

    test('adjacency withdrawn: true with an ineligible workout between', () {
      expect(
        hasBrickCandidates([
          act('a', ActivityType.swimming),
          act('b', ActivityType.other),
          act('c', ActivityType.running),
        ]),
        isTrue,
      );
    });

    test('adjacency withdrawn: true with a non-workout row between', () {
      expect(
        hasBrickCandidates([
          act('a', ActivityType.swimming),
          null,
          act('b', ActivityType.running),
        ]),
        isTrue,
      );
    });

    test('false for two ineligible workouts — strength cannot brick', () {
      expect(
        hasBrickCandidates([
          act('a', ActivityType.other),
          act('b', ActivityType.other),
        ]),
        isFalse,
      );
    });

    test('same-sport legs allowed: true for two runs (Lee, 2026-08-26)', () {
      expect(
        hasBrickCandidates([
          act('a', ActivityType.running),
          act('b', ActivityType.running),
        ]),
        isTrue,
      );
    });

    test('an existing brick does not count toward the two', () {
      expect(
        hasBrickCandidates([
          act('a', ActivityType.brick),
          act('b', ActivityType.running),
        ]),
        isFalse,
      );
    });
  });

  group('brickCandidateIds', () {
    test('every eligible workout on the day is selectable', () {
      final ids = brickCandidateIds([
        act('run', ActivityType.running),
        act('blocker', ActivityType.other),
        act('swim', ActivityType.swimming),
        act('bike', ActivityType.cycling),
      ]);
      expect(ids, {'run', 'swim', 'bike'});
    });

    test('same-sport day is selectable', () {
      expect(
        brickCandidateIds([
          act('r1', ActivityType.running),
          act('r2', ActivityType.running),
        ]),
        {'r1', 'r2'},
      );
    });

    test('returns empty when fewer than two are eligible', () {
      expect(
        brickCandidateIds([
          act('a', ActivityType.running),
          act('b', ActivityType.other),
        ]),
        isEmpty,
      );
    });

    test('an existing brick is never selectable', () {
      expect(
        brickCandidateIds([
          act('old', ActivityType.brick),
          act('swim', ActivityType.swimming),
          act('run', ActivityType.running),
        ]),
        {'swim', 'run'},
      );
    });
  });
}
