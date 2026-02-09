import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/domain/sync_change_result.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  late ChangeDetectionService service;
  const testUserId = 'test-user-id-123';
  const testProvider = 'final_surge';

  setUp(() {
    service = ChangeDetectionService();
  });

  // Helper function to create a basic activity for testing
  Activity createActivity({
    required String id,
    String? providerWorkoutId,
    String? syncedFromProvider,
    ActivityStatus status = ActivityStatus.planned,
    required DateTime scheduledDateTime,
    int? durationMinutes,
    double? distanceMiles,
    String title = 'Test Workout',
  }) {
    return Activity(
      id: id,
      userId: testUserId,
      activityType: ActivityType.running,
      title: title,
      scheduledDateTime: scheduledDateTime,
      status: status,
      providerWorkoutId: providerWorkoutId,
      syncedFromProvider:
          syncedFromProvider ??
          (providerWorkoutId != null ? testProvider : null),
      durationMinutes: durationMinutes,
      distanceMiles: distanceMiles,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('ChangeDetectionService', () {
    // =========================================================================
    // NEW WORKOUT DETECTION TESTS
    // =========================================================================
    group('New workout detection', () {
      test('detects new workout when provider_workout_id not in local', () {
        // Arrange
        final local = <Activity>[];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.newActivities.length, 1);
        expect(result.newActivities.first.providerWorkoutId, 'workout-123');
        expect(result.updatedActivities.length, 0);
        expect(result.deletedActivityIds.length, 0);
        expect(result.unchangedCount, 0);
        expect(result.hasChanges, true);
        expect(result.totalChanges, 1);
      });

      test('detects multiple new workouts', () {
        // Arrange
        final local = <Activity>[];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
          ),
          createActivity(
            id: 'remote-2',
            providerWorkoutId: 'workout-456',
            scheduledDateTime: DateTime(2026, 1, 27, 8, 0),
          ),
          createActivity(
            id: 'remote-3',
            providerWorkoutId: 'workout-789',
            scheduledDateTime: DateTime(2026, 1, 28, 8, 0),
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.newActivities.length, 3);
        expect(result.hasChanges, true);
        expect(result.totalChanges, 3);
      });
    });

    // =========================================================================
    // SCHEDULE CHANGE DETECTION - TIME CHANGES
    // =========================================================================
    group('Schedule change detection - Time changes', () {
      test('detects significant time change (>30 min) as schedule change', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0); // 8:00 AM
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime.add(
              const Duration(minutes: 35),
            ), // 8:35 AM - 35 min change
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.newActivities.length, 0);
        expect(result.updatedActivities.length, 1);
        expect(result.updatedActivities.first.scheduleChanged, true);
        expect(result.updatedActivities.first.activityId, 'local-1');
        expect(result.updatedActivities.first.timeDifferenceMinutes, 35);
        expect(result.hasScheduleChanges, true);
      });

      test('detects minor time change (<30 min) as NOT schedule change', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0); // 8:00 AM
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime.add(
              const Duration(minutes: 15),
            ), // 8:15 AM - 15 min change
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.newActivities.length, 0);
        expect(result.updatedActivities.length, 1);
        expect(result.updatedActivities.first.scheduleChanged, false);
        expect(result.updatedActivities.first.timeDifferenceMinutes, 15);
        expect(result.hasScheduleChanges, false);
      });

      test(
        'detects exactly 30 min time change as NOT schedule change (boundary)',
        () {
          // Arrange
          final baseTime = DateTime(2026, 1, 26, 8, 0);
          final local = [
            createActivity(
              id: 'local-1',
              providerWorkoutId: 'workout-123',
              scheduledDateTime: baseTime,
              durationMinutes: 60,
              distanceMiles: 10.0,
            ),
          ];
          final remote = [
            createActivity(
              id: 'remote-1',
              providerWorkoutId: 'workout-123',
              scheduledDateTime: baseTime.add(
                const Duration(minutes: 30),
              ), // Exactly 30 min
              durationMinutes: 60,
              distanceMiles: 10.0,
            ),
          ];

          // Act
          final result = service.detectChanges(
            localActivities: local,
            remoteWorkouts: remote,
            provider: testProvider,
          );

          // Assert - Should NOT be flagged as significant (> 30 min threshold)
          expect(result.updatedActivities.first.scheduleChanged, false);
        },
      );

      test(
        'detects exactly 31 min time change as schedule change (boundary)',
        () {
          // Arrange
          final baseTime = DateTime(2026, 1, 26, 8, 0);
          final local = [
            createActivity(
              id: 'local-1',
              providerWorkoutId: 'workout-123',
              scheduledDateTime: baseTime,
              durationMinutes: 60,
              distanceMiles: 10.0,
            ),
          ];
          final remote = [
            createActivity(
              id: 'remote-1',
              providerWorkoutId: 'workout-123',
              scheduledDateTime: baseTime.add(
                const Duration(minutes: 31),
              ), // Exactly 31 min
              durationMinutes: 60,
              distanceMiles: 10.0,
            ),
          ];

          // Act
          final result = service.detectChanges(
            localActivities: local,
            remoteWorkouts: remote,
            provider: testProvider,
          );

          // Assert - Should be flagged as significant (> 30 min threshold)
          expect(result.updatedActivities.first.scheduleChanged, true);
        },
      );
    });

    // =========================================================================
    // SCHEDULE CHANGE DETECTION - DATE CHANGES
    // =========================================================================
    group('Schedule change detection - Date changes', () {
      test('detects different day as schedule change', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0), // Jan 26
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(
              2026,
              1,
              27,
              8,
              0,
            ), // Jan 27 - different day
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.length, 1);
        expect(result.updatedActivities.first.scheduleChanged, true);
        expect(result.hasScheduleChanges, true);
      });

      test('detects different month as schedule change', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0), // Jan 26
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(
              2026,
              2,
              26,
              8,
              0,
            ), // Feb 26 - different month
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, true);
      });

      test('detects different year as schedule change', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0), // 2026
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(
              2027,
              1,
              26,
              8,
              0,
            ), // 2027 - different year
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, true);
      });

      test('same day different time (<30 min) is NOT schedule change', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0), // 8:00 AM
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 15), // 8:15 AM same day
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, false);
      });
    });

    // =========================================================================
    // SCHEDULE CHANGE DETECTION - DURATION CHANGES
    // =========================================================================
    group('Schedule change detection - Duration changes', () {
      test('detects duration change >15 min as schedule change', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 80, // 20 min increase
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.length, 1);
        expect(result.updatedActivities.first.scheduleChanged, true);
        expect(result.updatedActivities.first.durationDifferenceMinutes, 20);
      });

      test('detects duration decrease >15 min as schedule change', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 90,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 70, // 20 min decrease
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, true);
        expect(result.updatedActivities.first.durationDifferenceMinutes, 20);
      });

      test('duration change <=15 min is NOT schedule change', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 70, // 10 min increase
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, false);
      });

      test(
        'exactly 15 min duration change is NOT schedule change (boundary)',
        () {
          // Arrange
          final baseTime = DateTime(2026, 1, 26, 8, 0);
          final local = [
            createActivity(
              id: 'local-1',
              providerWorkoutId: 'workout-123',
              scheduledDateTime: baseTime,
              durationMinutes: 60,
              distanceMiles: 10.0,
            ),
          ];
          final remote = [
            createActivity(
              id: 'remote-1',
              providerWorkoutId: 'workout-123',
              scheduledDateTime: baseTime,
              durationMinutes: 75, // Exactly 15 min
              distanceMiles: 10.0,
            ),
          ];

          // Act
          final result = service.detectChanges(
            localActivities: local,
            remoteWorkouts: remote,
            provider: testProvider,
          );

          // Assert
          expect(result.updatedActivities.first.scheduleChanged, false);
        },
      );

      test('exactly 16 min duration change is schedule change (boundary)', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 76, // Exactly 16 min
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, true);
      });
    });

    // =========================================================================
    // SCHEDULE CHANGE DETECTION - DISTANCE CHANGES
    // =========================================================================
    group('Schedule change detection - Distance changes', () {
      test('detects distance change >10% as schedule change', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 12.0, // 20% increase
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.length, 1);
        expect(result.updatedActivities.first.scheduleChanged, true);
        expect(
          result.updatedActivities.first.distanceChangePercentage,
          closeTo(20.0, 0.1),
        );
      });

      test('detects distance decrease >10% as schedule change', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 8.5, // 15% decrease
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, true);
        expect(
          result.updatedActivities.first.distanceChangePercentage,
          closeTo(15.0, 0.1),
        );
      });

      test('distance change <=10% is NOT schedule change', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.5, // 5% increase
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, false);
      });

      test('exactly 10% distance change is NOT schedule change (boundary)', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 11.0, // Exactly 10%
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, false);
      });

      test('exactly 10.1% distance change is schedule change (boundary)', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 11.01, // 10.1%
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.first.scheduleChanged, true);
      });
    });

    // =========================================================================
    // DELETED WORKOUT DETECTION
    // =========================================================================
    group('Deleted workout detection', () {
      test('detects workout deleted from provider', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];
        final remote = <Activity>[]; // Empty - workout deleted

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.newActivities.length, 0);
        expect(result.updatedActivities.length, 0);
        expect(result.deletedActivityIds.length, 1);
        expect(result.deletedActivityIds.first, 'local-1');
        expect(result.hasChanges, true);
        expect(result.totalChanges, 1);
      });

      test('detects multiple deleted workouts', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
          ),
          createActivity(
            id: 'local-2',
            providerWorkoutId: 'workout-456',
            scheduledDateTime: DateTime(2026, 1, 27, 8, 0),
          ),
          createActivity(
            id: 'local-3',
            providerWorkoutId: 'workout-789',
            scheduledDateTime: DateTime(2026, 1, 28, 8, 0),
          ),
        ];
        final remote = <Activity>[]; // All deleted

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.deletedActivityIds.length, 3);
        expect(result.totalChanges, 3);
      });

      test('detects partial deletion (some workouts remain)', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
          ),
          createActivity(
            id: 'local-2',
            providerWorkoutId: 'workout-456',
            scheduledDateTime: DateTime(2026, 1, 27, 8, 0),
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123', // Kept
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
          ),
          // workout-456 is missing - deleted
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.deletedActivityIds.length, 1);
        expect(result.deletedActivityIds.first, 'local-2');
        expect(result.unchangedCount, 1);
      });
    });

    // =========================================================================
    // UNCHANGED WORKOUT DETECTION
    // =========================================================================
    group('Unchanged workout detection', () {
      test('detects unchanged workout (identical schedule)', () {
        // Arrange
        final scheduledTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: scheduledTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
            title: 'Morning Run',
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: scheduledTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
            title: 'Morning Run',
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.newActivities.length, 0);
        expect(result.updatedActivities.length, 0);
        expect(result.deletedActivityIds.length, 0);
        expect(result.unchangedCount, 1);
        expect(result.hasChanges, false);
        expect(result.totalChanges, 0);
      });

      test('counts multiple unchanged workouts', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
          createActivity(
            id: 'local-2',
            providerWorkoutId: 'workout-456',
            scheduledDateTime: DateTime(2026, 1, 27, 8, 0),
            durationMinutes: 45,
            distanceMiles: 5.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
          createActivity(
            id: 'remote-2',
            providerWorkoutId: 'workout-456',
            scheduledDateTime: DateTime(2026, 1, 27, 8, 0),
            durationMinutes: 45,
            distanceMiles: 5.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.unchangedCount, 2);
        expect(result.hasChanges, false);
      });
    });

    // =========================================================================
    // MINOR CHANGE DETECTION (NO SCHEDULE IMPACT)
    // =========================================================================
    group('Minor change detection (no schedule impact)', () {
      test('detects title change as minor update (scheduleChanged: false)', () {
        // Arrange
        final scheduledTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: scheduledTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
            title: 'Morning Run',
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: scheduledTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
            title: 'Easy Morning Run', // Title changed
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.length, 1);
        expect(result.updatedActivities.first.scheduleChanged, false);
        expect(result.hasScheduleChanges, false);
      });
    });

    // =========================================================================
    // MIXED CHANGE SCENARIOS
    // =========================================================================
    group('Mixed change scenarios', () {
      test('detects mix of new, updated, and deleted workouts', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-existing',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
            durationMinutes: 60,
          ),
          createActivity(
            id: 'local-2',
            providerWorkoutId: 'workout-deleted',
            scheduledDateTime: DateTime(2026, 1, 27, 8, 0),
            durationMinutes: 45,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-existing',
            scheduledDateTime: DateTime(
              2026,
              1,
              26,
              9,
              0,
            ), // Time changed (1 hour)
            durationMinutes: 60,
          ),
          createActivity(
            id: 'remote-2',
            providerWorkoutId: 'workout-new',
            scheduledDateTime: DateTime(2026, 1, 28, 8, 0),
            durationMinutes: 90,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.newActivities.length, 1); // workout-new
        expect(
          result.updatedActivities.length,
          1,
        ); // workout-existing (1 hour change)
        expect(result.updatedActivities.first.scheduleChanged, true); // >30 min
        expect(result.deletedActivityIds.length, 1); // workout-deleted
        expect(result.unchangedCount, 0);
        expect(result.totalChanges, 3);
        expect(result.hasChanges, true);
      });

      test('handles empty local and remote lists', () {
        // Arrange
        final local = <Activity>[];
        final remote = <Activity>[];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.newActivities.length, 0);
        expect(result.updatedActivities.length, 0);
        expect(result.deletedActivityIds.length, 0);
        expect(result.unchangedCount, 0);
        expect(result.hasChanges, false);
      });

      test('preserves local activity ID in updated activities', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-abc-123',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
            durationMinutes: 60,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-xyz-789',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: DateTime(2026, 1, 26, 9, 0), // Changed
            durationMinutes: 60,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert
        expect(result.updatedActivities.length, 1);
        expect(
          result.updatedActivities.first.activityId,
          'local-abc-123',
        ); // Preserves local ID
        expect(
          result.updatedActivities.first.updatedActivity.providerWorkoutId,
          'workout-123',
        );
      });
    });

    // =========================================================================
    // NULL/EDGE CASE HANDLING
    // =========================================================================
    group('Null and edge case handling', () {
      test('handles null providerWorkoutId in remote workout gracefully', () {
        // Arrange
        final local = <Activity>[];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: null, // Null provider ID - should be skipped
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert - Should skip workout with null providerWorkoutId
        expect(result.newActivities.length, 0);
        expect(result.totalChanges, 0);
      });

      test('handles null providerWorkoutId in local activity gracefully', () {
        // Arrange
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: null, // Null provider ID - should be skipped
            scheduledDateTime: DateTime(2026, 1, 26, 8, 0),
          ),
        ];
        final remote = <Activity>[];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert - Should skip activity with null providerWorkoutId
        expect(result.deletedActivityIds.length, 0);
        expect(result.totalChanges, 0);
      });

      test('handles null durationMinutes in duration change calculation', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: null, // Null duration
            distanceMiles: 10.0,
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60, // Non-null duration
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert - Should not crash, should not flag as schedule change
        expect(result.updatedActivities.length, 1);
        expect(result.updatedActivities.first.scheduleChanged, false);
      });

      test('handles null distanceMiles in distance change calculation', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: null, // Null distance
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0, // Non-null distance
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert - Should not crash, should not flag as schedule change
        expect(result.updatedActivities.length, 1);
        expect(result.updatedActivities.first.scheduleChanged, false);
      });

      test('handles zero distance in distance percentage calculation', () {
        // Arrange
        final baseTime = DateTime(2026, 1, 26, 8, 0);
        final local = [
          createActivity(
            id: 'local-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 0.0, // Zero distance
          ),
        ];
        final remote = [
          createActivity(
            id: 'remote-1',
            providerWorkoutId: 'workout-123',
            scheduledDateTime: baseTime,
            durationMinutes: 60,
            distanceMiles: 10.0,
          ),
        ];

        // Act
        final result = service.detectChanges(
          localActivities: local,
          remoteWorkouts: remote,
          provider: testProvider,
        );

        // Assert - Should not crash (no divide by zero)
        expect(result.updatedActivities.length, 1);
        // Note: Zero distance case is handled, but since old is 0, percentage calc is skipped
      });
    });

    // =========================================================================
    // COMPUTED PROPERTY TESTS
    // =========================================================================
    group('SyncChangeResult computed properties', () {
      test('totalChanges sums all change types', () {
        // Create a result manually to test computed property
        final result = SyncChangeResult(
          newActivities: [
            createActivity(
              id: '1',
              providerWorkoutId: 'w1',
              scheduledDateTime: DateTime.now(),
            ),
            createActivity(
              id: '2',
              providerWorkoutId: 'w2',
              scheduledDateTime: DateTime.now(),
            ),
          ],
          updatedActivities: [
            ActivityChange(
              activityId: 'local-1',
              updatedActivity: createActivity(
                id: 'r1',
                providerWorkoutId: 'w3',
                scheduledDateTime: DateTime.now(),
              ),
              scheduleChanged: true,
            ),
          ],
          deletedActivityIds: ['local-2', 'local-3', 'local-4'],
          unchangedCount: 5,
        );

        expect(result.totalChanges, 6); // 2 new + 1 updated + 3 deleted
      });

      test('hasChanges returns true when changes exist', () {
        final result = SyncChangeResult(
          newActivities: [
            createActivity(
              id: '1',
              providerWorkoutId: 'w1',
              scheduledDateTime: DateTime.now(),
            ),
          ],
          updatedActivities: [],
          deletedActivityIds: [],
          unchangedCount: 0,
        );

        expect(result.hasChanges, true);
      });

      test('hasChanges returns false when no changes', () {
        final result = SyncChangeResult(
          newActivities: [],
          updatedActivities: [],
          deletedActivityIds: [],
          unchangedCount: 5,
        );

        expect(result.hasChanges, false);
      });

      test('hasScheduleChanges returns true when schedule changed', () {
        final result = SyncChangeResult(
          newActivities: [],
          updatedActivities: [
            ActivityChange(
              activityId: 'local-1',
              updatedActivity: createActivity(
                id: 'r1',
                providerWorkoutId: 'w1',
                scheduledDateTime: DateTime.now(),
              ),
              scheduleChanged: true,
            ),
          ],
          deletedActivityIds: [],
          unchangedCount: 0,
        );

        expect(result.hasScheduleChanges, true);
      });

      test('hasScheduleChanges returns false when no schedule changes', () {
        final result = SyncChangeResult(
          newActivities: [],
          updatedActivities: [
            ActivityChange(
              activityId: 'local-1',
              updatedActivity: createActivity(
                id: 'r1',
                providerWorkoutId: 'w1',
                scheduledDateTime: DateTime.now(),
              ),
              scheduleChanged: false,
            ),
          ],
          deletedActivityIds: [],
          unchangedCount: 0,
        );

        expect(result.hasScheduleChanges, false);
      });
    });

    // =========================================================================
    // ACTIVITY CHANGE COMPUTED PROPERTY TESTS
    // =========================================================================
    group('ActivityChange computed properties', () {
      test('timeDifferenceMinutes calculates absolute difference', () {
        final oldTime = DateTime(2026, 1, 26, 8, 0);
        final newTime = DateTime(2026, 1, 26, 9, 30); // 90 min later

        final change = ActivityChange(
          activityId: 'local-1',
          updatedActivity: createActivity(
            id: 'r1',
            providerWorkoutId: 'w1',
            scheduledDateTime: newTime,
          ),
          scheduleChanged: true,
          oldScheduledAt: oldTime,
          newScheduledAt: newTime,
        );

        expect(change.timeDifferenceMinutes, 90);
      });

      test('durationDifferenceMinutes calculates absolute difference', () {
        final change = ActivityChange(
          activityId: 'local-1',
          updatedActivity: createActivity(
            id: 'r1',
            providerWorkoutId: 'w1',
            scheduledDateTime: DateTime.now(),
          ),
          scheduleChanged: true,
          oldDurationMinutes: 60,
          newDurationMinutes: 90,
        );

        expect(change.durationDifferenceMinutes, 30);
      });

      test('distanceChangePercentage calculates percentage correctly', () {
        final change = ActivityChange(
          activityId: 'local-1',
          updatedActivity: createActivity(
            id: 'r1',
            providerWorkoutId: 'w1',
            scheduledDateTime: DateTime.now(),
          ),
          scheduleChanged: true,
          oldDistanceMiles: 10.0,
          newDistanceMiles: 12.0,
        );

        expect(change.distanceChangePercentage, closeTo(20.0, 0.1));
      });

      test(
        'distanceChangePercentage returns 100% when old distance is zero',
        () {
          final change = ActivityChange(
            activityId: 'local-1',
            updatedActivity: createActivity(
              id: 'r1',
              providerWorkoutId: 'w1',
              scheduledDateTime: DateTime.now(),
            ),
            scheduleChanged: true,
            oldDistanceMiles: 0.0,
            newDistanceMiles: 10.0,
          );

          expect(change.distanceChangePercentage, 100.0);
        },
      );
    });

    group('Brick sync behavior', () {
      test(
        'matches archived brick segment by fingerprint to avoid re-import',
        () {
          final local = [
            createActivity(
              id: 'local-brick-segment',
              providerWorkoutId: null,
              syncedFromProvider: testProvider,
              status: ActivityStatus.archivedForBrick,
              scheduledDateTime: DateTime(2026, 2, 9, 7, 0),
              durationMinutes: 30,
              distanceMiles: 1.25,
              title: 'SS Fast form 15*25s; 1175 yds with new drills',
            ),
          ];

          final remote = [
            createActivity(
              id: 'remote-workout',
              providerWorkoutId: 'workout-123',
              syncedFromProvider: testProvider,
              scheduledDateTime: DateTime(2026, 2, 9, 7, 0),
              durationMinutes: 30,
              distanceMiles: 1.25,
              title: 'SS Fast form 15*25s; 1175 yds with new drills',
            ),
          ];

          final result = service.detectChanges(
            localActivities: local,
            remoteWorkouts: remote,
            provider: testProvider,
          );

          expect(result.newActivities, isEmpty);
          expect(result.updatedActivities.length, 1);
          expect(
            result.updatedActivities.first.activityId,
            'local-brick-segment',
          );
          expect(result.updatedActivities.first.scheduleChanged, false);
        },
      );

      test(
        'imports as new when archived brick workout fingerprint has changed',
        () {
          final local = [
            createActivity(
              id: 'local-brick-segment',
              providerWorkoutId: null,
              syncedFromProvider: testProvider,
              status: ActivityStatus.archivedForBrick,
              scheduledDateTime: DateTime(2026, 2, 9, 7, 0),
              durationMinutes: 30,
              distanceMiles: 1.25,
              title: 'SS Fast form 15*25s; 1175 yds with new drills',
            ),
          ];

          final remote = [
            createActivity(
              id: 'remote-workout',
              providerWorkoutId: 'workout-123',
              syncedFromProvider: testProvider,
              // Fingerprint changed (scheduled time changed)
              scheduledDateTime: DateTime(2026, 2, 9, 8, 0),
              durationMinutes: 30,
              distanceMiles: 1.25,
              title: 'SS Fast form 15*25s; 1175 yds with new drills',
            ),
          ];

          final result = service.detectChanges(
            localActivities: local,
            remoteWorkouts: remote,
            provider: testProvider,
          );

          expect(result.newActivities.length, 1);
          expect(result.updatedActivities, isEmpty);
        },
      );
    });
  });
}
