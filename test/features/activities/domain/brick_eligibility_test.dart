import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_eligibility.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Brick redesign (Notion 3a7e3fdb): only the three triathlon disciplines are
/// groupable, and the Brick entry point only appears when 2+ eligible workouts
/// are adjacent.
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

  group('hasAdjacentBrickCandidates', () {
    test('false for a single eligible workout', () {
      expect(
        hasAdjacentBrickCandidates([act('a', ActivityType.running)]),
        isFalse,
      );
    });

    test('true for two adjacent eligible workouts', () {
      expect(
        hasAdjacentBrickCandidates([
          act('a', ActivityType.swimming),
          act('b', ActivityType.running),
        ]),
        isTrue,
      );
    });

    test('false when an ineligible workout separates the two', () {
      expect(
        hasAdjacentBrickCandidates([
          act('a', ActivityType.swimming),
          act('b', ActivityType.other),
          act('c', ActivityType.running),
        ]),
        isFalse,
      );
    });

    test('false for two ineligible workouts — strength cannot brick', () {
      expect(
        hasAdjacentBrickCandidates([
          act('a', ActivityType.other),
          act('b', ActivityType.other),
        ]),
        isFalse,
      );
    });

    test(
      'true when a later pair is adjacent even if an earlier one is not',
      () {
        expect(
          hasAdjacentBrickCandidates([
            act('a', ActivityType.running),
            act('b', ActivityType.other),
            act('c', ActivityType.swimming),
            act('d', ActivityType.cycling),
          ]),
          isTrue,
        );
      },
    );

    test('false for two adjacent workouts of the SAME sport', () {
      // A brick is a change of discipline; canCreateBrick rejects duplicate
      // sports, so offering the pill here would be a dead end.
      expect(
        hasAdjacentBrickCandidates([
          act('a', ActivityType.running),
          act('b', ActivityType.running),
        ]),
        isFalse,
      );
    });

    test('null rows (non-workout timeline entries) break a run', () {
      expect(
        hasAdjacentBrickCandidates([
          act('a', ActivityType.swimming),
          null,
          act('b', ActivityType.running),
        ]),
        isFalse,
      );
    });
  });

  group('adjacentBrickCandidateIds', () {
    test('returns only ids inside a run of 2+', () {
      final ids = adjacentBrickCandidateIds([
        act('lonely', ActivityType.running),
        act('blocker', ActivityType.other),
        act('leg1', ActivityType.swimming),
        act('leg2', ActivityType.cycling),
      ]);
      expect(ids, {'leg1', 'leg2'});
    });

    test('same-sport run is not selectable', () {
      expect(
        adjacentBrickCandidateIds([
          act('r1', ActivityType.running),
          act('r2', ActivityType.running),
        ]),
        isEmpty,
      );
    });

    test('returns empty when nothing is adjacent', () {
      final ids = adjacentBrickCandidateIds([
        act('a', ActivityType.running),
        act('b', ActivityType.other),
      ]);
      expect(ids, isEmpty);
    });

    test('collects two separate runs', () {
      final ids = adjacentBrickCandidateIds([
        act('a1', ActivityType.swimming),
        act('a2', ActivityType.running),
        act('gap', ActivityType.other),
        act('b1', ActivityType.cycling),
        act('b2', ActivityType.running),
      ]);
      expect(ids, {'a1', 'a2', 'b1', 'b2'});
    });
  });
}
