import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_eligibility.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// SSOT: docs/ssot/spec/domain/brick.md (RATIFIED v1, Xuan 2026-08-31).
/// R1 offer threshold, R2 same-sport, R3 sport set, R4 count gates, R5
/// skipped-leg exclusion (fixes D-007), R6 leg order = pick order. The full
/// conformance sweep runs via qa run_dart.sh brick-eligibility against
/// docs/ssot/vectors/domain/brick-eligibility.json; these unit tests keep the
/// same rules red-green inside the app's own suite.
void main() {
  Activity act(
    String id,
    ActivityType type, {
    ActivityStatus status = ActivityStatus.planned,
  }) => Activity(
    id: id,
    userId: 'u1',
    title: id,
    activityType: type,
    status: status,
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

    test('R5: a skipped leg is not eligible (fixes D-007)', () {
      expect(
        act('s', ActivityType.running, status: ActivityStatus.skipped)
            .isBrickEligible,
        isFalse,
      );
    });

    test('Q-BR1 characterization: completed legs stay linkable', () {
      // Open question — current behaviour pinned, not ratified truth.
      expect(
        act('d', ActivityType.running, status: ActivityStatus.completed)
            .isBrickEligible,
        isTrue,
      );
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

    test('R5: a skipped workout blocks the offer when only 1 remains', () {
      expect(
        hasBrickCandidates([
          act('run', ActivityType.running),
          act('bike', ActivityType.cycling, status: ActivityStatus.skipped),
        ]),
        isFalse,
      );
    });

    test('R5: a skipped workout is excluded from candidates', () {
      expect(
        brickCandidateIds([
          act('run', ActivityType.running),
          act('sk', ActivityType.cycling, status: ActivityStatus.skipped),
          act('bike', ActivityType.cycling),
        ]),
        {'run', 'bike'},
      );
    });
  });

  group('evaluateBrickCreate (brick.md R3–R6)', () {
    test('allows 2 eligible legs; legOrder is pick order (R6)', () {
      final v = evaluateBrickCreate([
        act('b', ActivityType.cycling),
        act('a', ActivityType.running),
      ]);
      expect(v.createAllowed, isTrue);
      expect(v.gate, isNull);
      expect(v.legOrder, ['b', 'a']);
    });

    test('R4: one leg → min-legs gate', () {
      final v = evaluateBrickCreate([act('a', ActivityType.running)]);
      expect(v.createAllowed, isFalse);
      expect(v.gate, BrickCreateGate.minLegs);
      expect(v.legOrder, isNull);
    });

    test('R4: four legs → max-legs gate (the cap stands — ruled)', () {
      final v = evaluateBrickCreate([
        act('a', ActivityType.running),
        act('b', ActivityType.cycling),
        act('c', ActivityType.running),
        act('d', ActivityType.swimming),
      ]);
      expect(v.createAllowed, isFalse);
      expect(v.gate, BrickCreateGate.maxLegs);
    });

    test('R5: picking a skipped leg → ineligible-leg gate (fixes D-007)', () {
      final v = evaluateBrickCreate([
        act('a', ActivityType.running),
        act('b', ActivityType.cycling, status: ActivityStatus.skipped),
      ]);
      expect(v.createAllowed, isFalse);
      expect(v.gate, BrickCreateGate.ineligibleLeg);
    });
  });
}
