// Tests for the Runna ICS event → Activity transformer.
//
// Coverage goals:
// 1. Bullet-separated SUMMARY parsing (name / distance / duration range)
// 2. Duration priority: X-WORKOUT-ESTIMATED-DURATION > DTEND−DTSTART >
//    DURATION > SUMMARY text
// 3. Strength/mobility/cross-training skip (returns null)
// 4. Subtype + intensity heuristics
// 5. Field mapping onto Activity (provider sync fields, status, notes)

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/integrations/application/runna_ics_parser.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_transformer.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';

const _transformer = RunnaTransformer();
const _userId = 'user-123';

RunnaIcsEvent _event({
  String uid = 'evt-1',
  DateTime? start,
  bool isAllDay = true,
  String? summary,
  String? description,
  String? url,
  DateTime? end,
  Duration? duration,
  int? estimatedDurationSeconds,
}) => RunnaIcsEvent(
  uid: uid,
  start: start ?? DateTime(2026, 7, 24, 6),
  isAllDay: isAllDay,
  summary: summary,
  description: description,
  url: url,
  end: end,
  duration: duration,
  estimatedDurationSeconds: estimatedDurationSeconds,
);

void main() {
  group('SUMMARY parsing', () {
    test(
      'splits bullet segments: emoji-stripped name, distance, duration range',
      () {
        final result = _transformer.transform(
          _event(summary: '🏃 Easy Run • 6mi • 50m - 55m'),
          _userId,
        );

        expect(result, isNotNull);
        final activity = result!.activity;
        expect(activity.title, 'Easy Run');
        expect(activity.distanceMiles, 6.0);
        // No estimated duration / DTEND, so the range midpoint wins.
        expect(activity.durationMinutes, 53);
      },
    );

    test('converts km distance segments to miles', () {
      final result = _transformer.transform(
        _event(summary: '🏃 Tempo Run • 10km • 50m'),
        _userId,
      );

      expect(result!.activity.distanceMiles, closeTo(6.21371, 0.001));
    });

    test('handles "5k" style distance segments', () {
      final result = _transformer.transform(
        _event(summary: '🏃 Race Day • 5k'),
        _userId,
      );

      expect(result!.activity.distanceMiles, closeTo(3.107, 0.01));
    });

    test('keeps a leading digit in the name ("6mi Easy Run")', () {
      final result = _transformer.transform(
        _event(summary: '6mi Easy Run'),
        _userId,
      );

      expect(result!.activity.title, '6mi Easy Run');
    });

    test('falls back to "Runna workout" when SUMMARY is missing', () {
      final result = _transformer.transform(_event(summary: null), _userId);

      expect(result!.activity.title, 'Runna workout');
    });

    test('parses "45 mins" style single duration segments', () {
      final result = _transformer.transform(
        _event(summary: 'Tempo Run • 45 mins'),
        _userId,
      );

      expect(result!.activity.durationMinutes, 45);
    });

    test('parses "1h 10m" style duration segments', () {
      final result = _transformer.transform(
        _event(summary: 'Long Run • 1h 10m'),
        _userId,
      );

      expect(result!.activity.durationMinutes, 70);
    });
  });

  group('duration priority', () {
    test('X-WORKOUT-ESTIMATED-DURATION wins over everything else', () {
      final result = _transformer.transform(
        _event(
          summary: 'Easy Run • 50m - 55m',
          isAllDay: false,
          start: DateTime(2026, 7, 24, 6),
          end: DateTime(2026, 7, 24, 7),
          estimatedDurationSeconds: 3120, // 52 minutes
        ),
        _userId,
      );

      expect(result!.activity.durationMinutes, 52);
    });

    test('DTEND − DTSTART wins when no estimated duration', () {
      final result = _transformer.transform(
        _event(
          summary: 'Easy Run • 50m - 55m',
          isAllDay: false,
          start: DateTime(2026, 7, 24, 6),
          end: DateTime(2026, 7, 24, 6, 45),
        ),
        _userId,
      );

      expect(result!.activity.durationMinutes, 45);
    });

    test('DURATION property wins over SUMMARY text', () {
      final result = _transformer.transform(
        _event(
          summary: 'Easy Run • 50m - 55m',
          duration: const Duration(minutes: 40),
        ),
        _userId,
      );

      expect(result!.activity.durationMinutes, 40);
    });

    test('SUMMARY duration range is the all-day fallback (midpoint)', () {
      final result = _transformer.transform(
        _event(summary: 'Easy Run • 50m - 55m'),
        _userId,
      );

      expect(result!.activity.durationMinutes, 53);
    });

    test('no duration source at all leaves durationMinutes null', () {
      final result = _transformer.transform(
        _event(summary: 'Easy Run • 6mi'),
        _userId,
      );

      expect(result!.activity.durationMinutes, isNull);
    });
  });

  group('strength/mobility/cross-training skip', () {
    for (final summary in [
      '💪 Strength & Conditioning • 30m',
      'Mobility Session • 15m',
      'S&C Workout',
      'Yoga Flow • 20m',
      'Pilates • 30m',
      'Cross Training • 40m',
      'Cross-Training Bike',
    ]) {
      test('skips "$summary"', () {
        expect(
          _transformer.transform(_event(summary: summary), _userId),
          isNull,
        );
      });
    }

    test('does not skip a plain run', () {
      expect(
        _transformer.transform(_event(summary: '🏃 Easy Run • 6mi'), _userId),
        isNotNull,
      );
    });
  });

  group('subtype and intensity heuristics', () {
    final cases = <String, (String, IntensityLevel)>{
      '🏃 Long Run • 10mi': ('Long Run', IntensityLevel.moderate),
      'Tempo Run • 45m': ('Tempo', IntensityLevel.hard),
      'Pyramid Intervals • 45m': ('Intervals', IntensityLevel.hard),
      'Easy Run • 6mi': ('Easy', IntensityLevel.easy),
      'Recovery Run • 30m': ('Recovery', IntensityLevel.easy),
      'Race Day: Half Marathon': ('Race', IntensityLevel.race),
      'Speed Session • 40m': ('Speed', IntensityLevel.hard),
      'Hill Repeats • 40m': ('Hills', IntensityLevel.hard),
      'Threshold Run • 35m': ('Threshold', IntensityLevel.hard),
      'Fartlek Run • 40m': ('Fartlek', IntensityLevel.hard),
      'Progression Run • 50m': ('Progression', IntensityLevel.moderate),
    };

    cases.forEach((summary, expected) {
      test('"$summary" → ${expected.$1}', () {
        final result = _transformer.transform(
          _event(summary: summary),
          _userId,
        );
        expect(result!.workoutSubtype, expected.$1);
        expect(result.activity.workoutSubtype, expected.$1);
        expect(result.activity.intensityLevel, expected.$2);
      });
    });

    test('unrecognized name gets no subtype and moderate intensity', () {
      final result = _transformer.transform(
        _event(summary: 'Shakeout'),
        _userId,
      );
      expect(result!.workoutSubtype, isNull);
      expect(result.activity.intensityLevel, IntensityLevel.moderate);
    });
  });

  group('field mapping', () {
    test('maps provider sync fields, status, and notes', () {
      final start = DateTime(2026, 7, 24, 6);
      final result = _transformer.transform(
        _event(
          uid: 'runna-uid-42',
          start: start,
          summary: '🏃 Easy Run • 6mi • 50m - 55m',
          description: 'Warm up: 10 mins easy\nMain: 4mi at 8:30/mi',
          url: 'https://runna.com/workout/42',
          estimatedDurationSeconds: 3120,
        ),
        _userId,
      );

      final activity = result!.activity;
      expect(activity.userId, _userId);
      expect(activity.activityType, ActivityType.running);
      expect(activity.status, ActivityStatus.planned);
      expect(activity.scheduledDateTime, start);
      expect(activity.syncedFromProvider, 'runna');
      expect(activity.providerWorkoutId, 'runna-uid-42');
      expect(activity.providerWorkoutUrl, 'https://runna.com/workout/42');
      expect(activity.providerScheduledAt, start);
      expect(activity.needsUpload, isTrue);
      expect(activity.notes, 'Warm up: 10 mins easy\nMain: 4mi at 8:30/mi');
      expect(activity.lastSyncedAt, isNotNull);
      expect(result.providerWorkoutId, 'runna-uid-42');
    });

    test('derives pace from duration + distance within the sanity window', () {
      final result = _transformer.transform(
        _event(
          summary: 'Easy Run • 6mi',
          estimatedDurationSeconds: 3120, // 52 min → 8.67 min/mi
        ),
        _userId,
      );

      expect(
        result!.activity.paceTargetMinutesPerMile,
        closeTo(52 / 6.0, 0.01),
      );
    });

    test('rejects implausible derived pace', () {
      final result = _transformer.transform(
        _event(
          summary: 'Easy Run • 6mi',
          estimatedDurationSeconds: 600, // 10 min for 6mi → 1.67 min/mi
        ),
        _userId,
      );

      expect(result!.activity.paceTargetMinutesPerMile, isNull);
    });
  });
}
