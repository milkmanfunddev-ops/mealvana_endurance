import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart'
    as domain;
import 'package:mealvana_endurance/features/nutrition_plan/application/draft_activity_cleanup_service.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

class MockActivitiesService extends Mock implements ActivitiesService {}

void main() {
  late MockActivitiesService mockActivitiesService;
  late DraftActivityCleanupService cleanupService;

  const testUserId = 'user-abc-123';
  const testActivityId = 'activity-draft-001';

  domain.Activity _makeActivity({
    required domain.ActivityStatus status,
  }) {
    return domain.Activity(
      id: testActivityId,
      userId: testUserId,
      activityType: ActivityType.running,
      title: 'Test Run',
      scheduledDateTime: DateTime(2026, 7, 10),
      status: status,
      createdAt: DateTime(2026, 7, 9),
      updatedAt: DateTime(2026, 7, 9),
    );
  }

  setUp(() {
    mockActivitiesService = MockActivitiesService();
    cleanupService =
        DraftActivityCleanupService(activitiesService: mockActivitiesService);
  });

  group('DraftActivityCleanupService.cleanupIfNeeded', () {
    test('deletes activity when status is draft', () async {
      final draftActivity =
          _makeActivity(status: domain.ActivityStatus.draft);
      when(() => mockActivitiesService.getActivityById(testUserId, testActivityId))
          .thenAnswer((_) async => draftActivity);
      when(() => mockActivitiesService.deleteActivity(
            deviceId: any(named: 'deviceId'),
            activityId: any(named: 'activityId'),
          )).thenAnswer((_) async {});

      await cleanupService.cleanupIfNeeded(
        activityId: testActivityId,
        userId: testUserId,
      );

      verify(() => mockActivitiesService.deleteActivity(
            deviceId: testUserId,
            activityId: testActivityId,
          )).called(1);
    });

    test('skips deletion when status is planned', () async {
      final plannedActivity =
          _makeActivity(status: domain.ActivityStatus.planned);
      when(() => mockActivitiesService.getActivityById(testUserId, testActivityId))
          .thenAnswer((_) async => plannedActivity);

      await cleanupService.cleanupIfNeeded(
        activityId: testActivityId,
        userId: testUserId,
      );

      verifyNever(() => mockActivitiesService.deleteActivity(
            deviceId: any(named: 'deviceId'),
            activityId: any(named: 'activityId'),
          ));
    });

    test('skips deletion when activity is not found', () async {
      when(() => mockActivitiesService.getActivityById(testUserId, testActivityId))
          .thenAnswer((_) async => null);

      await cleanupService.cleanupIfNeeded(
        activityId: testActivityId,
        userId: testUserId,
      );

      verifyNever(() => mockActivitiesService.deleteActivity(
            deviceId: any(named: 'deviceId'),
            activityId: any(named: 'activityId'),
          ));
    });
  });
}
