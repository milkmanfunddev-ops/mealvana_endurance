import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

/// Pins the soft-delete tombstone half of the sync matcher (ruled 2026-08-14,
/// docs/ssot/spec/daily-macros/platform-resolution.md, intraday-display §4b):
/// an incoming platform workout that matches a status='deleted' row is
/// DROPPED — deleted workouts must not reappear after sync, and deletion is
/// not un-doable by sync. Vector siblings: tombstone-matcher* in
/// docs/ssot/vectors/daily-macros/platform-resolution.json (TS side).
void main() {
  final service = ChangeDetectionService();

  Activity activity({
    required String id,
    required String providerId,
    ActivityStatus status = ActivityStatus.planned,
    DateTime? deletedAt,
  }) {
    final now = DateTime(2026, 8, 14, 12);
    return Activity(
      id: id,
      userId: 'user-1',
      activityType: ActivityType.running,
      title: 'Morning run',
      scheduledDateTime: DateTime(2026, 8, 20, 7),
      status: status,
      syncedFromProvider: 'training_peaks',
      providerWorkoutId: providerId,
      deletedAt: deletedAt,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('tombstone matching (soft-delete ruling)', () {
    test('an incoming workout matching a tombstone is dropped, not re-imported',
        () {
      final tombstone = activity(
        id: 'a1',
        providerId: 'tp-100',
        status: ActivityStatus.deleted,
        deletedAt: DateTime(2026, 8, 14, 11),
      );
      final incoming = activity(id: 'remote-a1', providerId: 'tp-100');

      final result = service.detectChanges(
        localActivities: [tombstone],
        remoteWorkouts: [incoming],
        provider: 'training_peaks',
      );

      expect(result.newActivities, isEmpty,
          reason: 'a tombstone hit must never re-import');
      expect(result.updatedActivities, isEmpty,
          reason: 'sync must not resurrect or edit a deleted workout');
      expect(result.tombstoneDroppedCount, 1);
    });

    test('a tombstone is never re-flagged for deletion when absent remotely',
        () {
      final tombstone = activity(
        id: 'a1',
        providerId: 'tp-gone',
        status: ActivityStatus.deleted,
        deletedAt: DateTime(2026, 8, 14, 11),
      );

      final result = service.detectChanges(
        localActivities: [tombstone],
        remoteWorkouts: const [],
        provider: 'training_peaks',
      );

      expect(result.deletedActivityIds, isEmpty);
      expect(result.hasChanges, isFalse);
    });

    test('a live workout with a different provider id still imports normally',
        () {
      final tombstone = activity(
        id: 'a1',
        providerId: 'tp-100',
        status: ActivityStatus.deleted,
        deletedAt: DateTime(2026, 8, 14, 11),
      );
      final genuineNew = activity(id: 'remote-b2', providerId: 'tp-200');

      final result = service.detectChanges(
        localActivities: [tombstone],
        remoteWorkouts: [genuineNew],
        provider: 'training_peaks',
      );

      expect(result.newActivities, hasLength(1),
          reason: 'the tombstone must not swallow unrelated workouts');
      expect(result.tombstoneDroppedCount, 0);
    });
  });
}
