/// Stage B client-side wiring — data-integrations@v1.
///
/// Pins the Dart executor behaviors around the matcher tier:
///  - M-1.3 in change detection: a completion-carrying keyed signal
///    REVIVES a tombstone; a plan re-import still drops (producer-shaped
///    FS payloads through the real transformer — never engine output).
///  - B-3 verified predicate: a brick shows DONE_VERIFIED only when the
///    parent is stamped AND every endurance leg carries its Garmin stamp.
///  - Brick metadata round-trip: server-written leg stamps + folded
///    transitions survive a client fromJson -> toJson cycle (the drop bug
///    this suite exists to prevent).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/domain/brick_metadata.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/dashboard_models.dart';
import 'package:mealvana_endurance/features/macro_dashboard/domain/workout_state_resolver.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

Activity _tombstone(String providerId) => Activity(
      id: 'local-1',
      userId: 'u1',
      activityType: ActivityType.running,
      title: 'Deleted Run',
      scheduledDateTime: DateTime(2026, 9, 10, 6, 30),
      status: ActivityStatus.deleted,
      syncedFromProvider: 'final_surge',
      providerWorkoutId: providerId,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
      deletedAt: DateTime(2026, 9, 9),
    );

/// Producer-shaped FS payload (wire field names, wire value shapes).
Map<String, dynamic> _fsWorkout({
  required String key,
  bool completed = false,
  int? actualTimeSeconds,
}) =>
    {
      'WorkoutKey': key,
      'WorkoutDate': '2026-09-10T00:00:00',
      'WorkoutTitle': 'Morning Run',
      'WorkoutTypeName': 'Run',
      'WorkoutCompleted': completed,
      'PlannedTime': 2700,
      'PlannedDistance': 5.0,
      'PlannedDistanceType': 'mi',
      'ActualTime': actualTimeSeconds,
      'ActualDistanceMeters': null,
    };

void main() {
  final transformer = FinalSurgeTransformer();
  final detection = ChangeDetectionService();

  group('M-1.3 keyed signals vs tombstones (change detection)', () {
    test('a completion signal revives the tombstone', () {
      final result = transformer.transform(
        _fsWorkout(key: 'FS-90', completed: true, actualTimeSeconds: 2712),
        'u1',
      )!;
      expect(result.providerReportsCompletion, isTrue);

      final changes = detection.detectChanges(
        localActivities: [_tombstone('FS-90')],
        remoteWorkouts: [result.activity],
        provider: 'final_surge',
        completionSignalIds: {
          if (result.providerReportsCompletion) result.providerWorkoutId,
        },
      );

      expect(changes.revivedActivities, hasLength(1));
      expect(changes.revivedActivities.single.activityId, 'local-1');
      expect(changes.tombstoneDroppedCount, 0);
      expect(changes.newActivities, isEmpty);
    });

    test('a plan re-import (keyed or not) still drops', () {
      final result = transformer.transform(_fsWorkout(key: 'FS-90'), 'u1')!;
      expect(result.providerReportsCompletion, isFalse);

      final changes = detection.detectChanges(
        localActivities: [_tombstone('FS-90')],
        remoteWorkouts: [result.activity],
        provider: 'final_surge',
        completionSignalIds: const {},
      );

      expect(changes.tombstoneDroppedCount, 1);
      expect(changes.revivedActivities, isEmpty);
      expect(changes.newActivities, isEmpty);
    });
  });

  group('B-3 brick verified predicate (workout_state_resolver)', () {
    BrickMetadata meta({bool leg1Stamped = false, bool leg2Stamped = false}) =>
        BrickMetadata(
          segmentOrder: const ['cycling', 'running'],
          createdFromExisting: false,
          totalDurationMinutes: 90,
          segments: [
            BrickSegment(
              sport: 'cycling',
              order: 1,
              durationMinutes: 60,
              intensity: 'moderate',
              garminStamp: leg1Stamped
                  ? const {
                      'summary_id': 'gb1',
                      'start': '2026-09-10T07:00:00',
                      'duration_minutes': 58,
                    }
                  : null,
            ),
            BrickSegment(
              sport: 'running',
              order: 2,
              durationMinutes: 30,
              intensity: 'moderate',
              garminStamp: leg2Stamped
                  ? const {
                      'summary_id': 'gb2',
                      'start': '2026-09-10T08:10:00',
                      'duration_minutes': 29,
                    }
                  : null,
            ),
          ],
        );

    Activity brick({
      required BrickMetadata metadata,
      String? garminSummaryId,
    }) =>
        Activity(
          id: 'br1',
          userId: 'u1',
          activityType: ActivityType.brick,
          title: 'Brick',
          scheduledDateTime: DateTime(2026, 9, 10, 7),
          status: ActivityStatus.completed,
          actualTime: DateTime(2026, 9, 10, 7),
          garminSummaryId: garminSummaryId,
          brickMetadata: metadata,
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 10),
        );

    final day = DateTime(2026, 9, 10);
    final now = DateTime(2026, 9, 10, 20);

    test('parent stamped + one of two legs -> confirmed, never verified', () {
      final state = resolveWorkoutCardState(
        brick(metadata: meta(leg1Stamped: true), garminSummaryId: 'gb1'),
        day: day,
        now: now,
      );
      expect(state, WorkoutCardState.doneConfirmed);
    });

    test('parent stamped + all endurance legs stamped -> verified', () {
      final state = resolveWorkoutCardState(
        brick(
          metadata: meta(leg1Stamped: true, leg2Stamped: true),
          garminSummaryId: 'gb1',
        ),
        day: day,
        now: now,
      );
      expect(state, WorkoutCardState.doneVerified);
    });

    test('all legs stamped but no parent stamp -> confirmed only', () {
      final state = resolveWorkoutCardState(
        brick(metadata: meta(leg1Stamped: true, leg2Stamped: true)),
        day: day,
        now: now,
      );
      expect(state, WorkoutCardState.doneConfirmed);
    });

    test('single-sport rows keep the summary-id predicate', () {
      final run = Activity(
        id: 'r1',
        userId: 'u1',
        activityType: ActivityType.running,
        title: 'Run',
        scheduledDateTime: DateTime(2026, 9, 10, 7),
        status: ActivityStatus.completed,
        garminSummaryId: 'g1',
        createdAt: DateTime(2026, 9, 1),
        updatedAt: DateTime(2026, 9, 10),
      );
      expect(
        resolveWorkoutCardState(run, day: day, now: now),
        WorkoutCardState.doneVerified,
      );
    });
  });

  group('brick_metadata round-trip preserves server-written state', () {
    test('leg stamps and folded transitions survive fromJson -> toJson', () {
      final serverJson = {
        'segment_order': ['cycling', 'running'],
        'created_from_existing': false,
        'total_duration_minutes': 90,
        'segments': [
          {
            'sport': 'cycling',
            'order': 1,
            'duration_minutes': 60,
            'intensity': 'moderate',
            'garmin': {
              'summary_id': 'gb1',
              'start': '2026-09-10T07:00:00',
              'duration_minutes': 58,
            },
          },
          {
            'sport': 'running',
            'order': 2,
            'duration_minutes': 30,
            'intensity': 'moderate',
          },
        ],
        'transitions': {
          'T1': {
            'duration_minutes': 2,
            'summary_id': 'gbT',
            'start': '2026-09-10T07:58:00',
          },
        },
      };

      final roundTripped = BrickMetadata.fromJson(serverJson).toJson();

      expect(
        (roundTripped['segments'] as List).first['garmin']['summary_id'],
        'gb1',
      );
      expect(
        (roundTripped['transitions'] as Map)['T1']['summary_id'],
        'gbT',
      );
    });

    test('allEnduranceLegsStamped answers the B-3 all-legs half', () {
      final partial = BrickMetadata.fromJson({
        'segment_order': ['cycling', 'running'],
        'created_from_existing': false,
        'total_duration_minutes': 90,
        'segments': [
          {
            'sport': 'cycling',
            'order': 1,
            'duration_minutes': 60,
            'intensity': 'moderate',
            'garmin': {'summary_id': 'gb1'},
          },
          {
            'sport': 'running',
            'order': 2,
            'duration_minutes': 30,
            'intensity': 'moderate',
          },
        ],
      });
      expect(partial.allEnduranceLegsStamped, isFalse);

      final full = BrickMetadata.fromJson({
        'segment_order': ['cycling', 'running'],
        'created_from_existing': false,
        'total_duration_minutes': 90,
        'segments': [
          {
            'sport': 'cycling',
            'order': 1,
            'duration_minutes': 60,
            'intensity': 'moderate',
            'garmin': {'summary_id': 'gb1'},
          },
          {
            'sport': 'running',
            'order': 2,
            'duration_minutes': 30,
            'intensity': 'moderate',
            'garmin': {'summary_id': 'gb2'},
          },
        ],
      });
      expect(full.allEnduranceLegsStamped, isTrue);
    });
  });
}
