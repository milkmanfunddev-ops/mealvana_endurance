/// Derived values on the Event domain model.
///
/// `events/` had one test file — a repository CRUD walk — and nothing over the
/// model itself. These getters are what the race card and event detail render,
/// and two of them (goal time, actual time) do their own integer-division
/// formatting rather than going through UnitFormatter, so they are worth
/// pinning independently of the pace formatter that already has coverage.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  Event event({
    int? goalTimeMinutes,
    double? goalPaceMinutesPerMile,
    int? actualFinishTimeMinutes,
    String? eventName = 'Boston Marathon',
    DateTime? eventDate,
  }) => Event(
    id: 'e1',
    userId: 'u1',
    eventType: ActivityType.running,
    eventName: eventName,
    eventDate: eventDate ?? DateTime(2027, 4, 19),
    goalTimeMinutes: goalTimeMinutes,
    goalPaceMinutesPerMile: goalPaceMinutesPerMile,
    actualFinishTimeMinutes: actualFinishTimeMinutes,
    createdAt: DateTime(2026, 8, 4),
    updatedAt: DateTime(2026, 8, 4),
  );

  group('formattedGoalTime', () {
    test('is null when no goal is set', () {
      expect(event().formattedGoalTime, isNull);
    });

    test('under an hour shows minutes only', () {
      expect(event(goalTimeMinutes: 45).formattedGoalTime, '45m');
    });

    test('over an hour shows hours and minutes', () {
      expect(event(goalTimeMinutes: 225).formattedGoalTime, '3h 45m');
    });

    test('an exact hour still shows the zero minutes', () {
      // "3h 0m" rather than a bare "3h" — pinned because a marathon goal of
      // exactly 3 hours is a real and common input.
      expect(event(goalTimeMinutes: 180).formattedGoalTime, '3h 0m');
    });

    test('zero minutes renders as 0m, not as null or empty', () {
      expect(event(goalTimeMinutes: 0).formattedGoalTime, '0m');
    });

    test('a sub-hour value never gains a spurious hour component', () {
      for (final m in [1, 30, 59]) {
        expect(event(goalTimeMinutes: m).formattedGoalTime, '${m}m');
      }
    });

    test('the minute component never reaches 60', () {
      // Integer division + modulo, so this is structurally safe — asserted so
      // that a rewrite into floating-point maths cannot reintroduce the "3:60"
      // family of bugs this branch already fixed five times elsewhere.
      for (final m in [59, 60, 61, 119, 120, 1439, 1440]) {
        final out = event(goalTimeMinutes: m).formattedGoalTime!;
        final mins = int.parse(RegExp(r'(\d+)m$').firstMatch(out)!.group(1)!);
        expect(mins, lessThan(60), reason: '$m min rendered "$out"');
      }
    });

    test('a full day of minutes is 24h 0m', () {
      expect(event(goalTimeMinutes: 1440).formattedGoalTime, '24h 0m');
    });
  });

  group('formattedActualTime', () {
    test('is null before the race is run', () {
      expect(event().formattedActualTime, isNull);
    });

    test('formats the same way as the goal', () {
      expect(event(actualFinishTimeMinutes: 231).formattedActualTime, '3h 51m');
      expect(event(actualFinishTimeMinutes: 42).formattedActualTime, '42m');
    });

    test('its minute component never reaches 60 either', () {
      for (final m in [59, 60, 61, 599, 600]) {
        final out = event(actualFinishTimeMinutes: m).formattedActualTime!;
        final mins = int.parse(RegExp(r'(\d+)m$').firstMatch(out)!.group(1)!);
        expect(mins, lessThan(60), reason: '$m min rendered "$out"');
      }
    });
  });

  group('hasResults', () {
    test('is false until a finish time is recorded', () {
      expect(event().hasResults, isFalse);
    });

    test('is true once a finish time exists', () {
      expect(event(actualFinishTimeMinutes: 231).hasResults, isTrue);
    });

    test('a zero finish time still counts as a result', () {
      // Null and 0 must not be conflated: 0 is a (nonsensical but recorded)
      // result, whereas null means "not raced yet".
      expect(event(actualFinishTimeMinutes: 0).hasResults, isTrue);
    });

    test('agrees with formattedActualTime being non-null', () {
      for (final t in [null, 0, 42, 231]) {
        final e = event(actualFinishTimeMinutes: t);
        expect(
          e.hasResults,
          e.formattedActualTime != null,
          reason:
              'hasResults=${e.hasResults} but formattedActualTime='
              '${e.formattedActualTime} for $t — the card would offer a '
              'results view with nothing to show, or hide one that exists.',
        );
      }
    });
  });

  group('copyWith', () {
    test('changes only the named field', () {
      final base = event(goalTimeMinutes: 200);
      final updated = base.copyWith(eventName: 'London Marathon');
      expect(updated.eventName, 'London Marathon');
      expect(updated.goalTimeMinutes, 200);
      expect(updated.id, base.id);
      expect(updated.eventType, base.eventType);
    });

    test('a no-arg copyWith is equal to the original', () {
      final base = event(goalTimeMinutes: 200, actualFinishTimeMinutes: 231);
      final copy = base.copyWith();
      expect(copy, base);
      expect(copy.goalTimeMinutes, 200);
      expect(copy.actualFinishTimeMinutes, 231);
    });
  });

  group('toJson', () {
    test('writes the event type as its database value', () {
      // eventType maps through `dbValue`, not `.name` — a mismatch here writes
      // a row the backend cannot categorise.
      final json = event().toJson();
      expect(json['eventType'], ActivityType.running.dbValue);
    });

    test('serialises dates as ISO-8601 strings', () {
      final json = event().toJson();
      expect(json['eventDate'], isA<String>());
      expect(DateTime.tryParse(json['eventDate'] as String), isNotNull);
      expect(DateTime.tryParse(json['createdAt'] as String), isNotNull);
    });

    test('carries the goal figures through unchanged', () {
      final json = event(
        goalTimeMinutes: 200,
        goalPaceMinutesPerMile: 7.5,
      ).toJson();
      expect(json['goalTimeMinutes'], 200);
      expect(json['goalPaceMinutesPerMile'], 7.5);
    });
  });
}
