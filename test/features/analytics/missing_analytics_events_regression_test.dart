/// Regression tests for missing analytics events:
/// - food_added (addFoodItem)
/// - fuel_log_started (enterFuelLogMode)
/// - first_activity_added (createActivity when list was empty)
///
/// Bug: 398e3fdb-754c-81e3-b224-d244e6550ca3
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
// supabase_flutter exports its own AuthUser; hide it so `AuthUser` unambiguously
// means the app's domain type (what currentUserProvider is typed against).
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;
import 'package:mealvana_endurance/features/auth/domain/auth_user.dart';

import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/auth/application/supabase_auth_service.dart';
import 'package:mealvana_endurance/features/integrations/application/integration_sync_coordinator.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';

class _MockActivitiesService extends Mock implements ActivitiesService {}

class _MockActivitiesRepository extends Mock implements ActivitiesRepository {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSentryReporter extends Mock implements SentryReporter {}

class _MockAppLogger extends Mock implements AppLogger {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

const _testUserId = 'test-user-123';

Activity _makeActivity({
  String id = 'activity-1',
  ActivityType type = ActivityType.running,
}) {
  return Activity(
    id: id,
    userId: _testUserId,
    activityType: type,
    title: 'Test Run',
    scheduledDateTime: DateTime(2026, 7, 9),
    createdAt: DateTime(2026, 7, 9),
    updatedAt: DateTime(2026, 7, 9),
  );
}

void main() {
  // mocktail needs a fallback instance before any() can match a parameter of a
  // non-primitive type. Without it, createActivity's `activityType: any(...)`
  // stub throws and leaves a dangling matcher that corrupts the next test.
  setUpAll(() {
    registerFallbackValue(ActivityType.running);
  });

  group('first_activity_added analytics event', () {
    late RecordingAnalyticsTracker analytics;
    late _MockActivitiesService mockService;
    late _MockActivitiesRepository mockRepo;
    late _MockAppLogger mockLogger;
    late ProviderContainer container;

    setUp(() {
      analytics = RecordingAnalyticsTracker();
      mockService = _MockActivitiesService();
      mockRepo = _MockActivitiesRepository();
      mockLogger = _MockAppLogger();

      // Stub logger calls
      when(
        () => mockLogger.info(
          any(),
          context: any(named: 'context'),
          data: any(named: 'data'),
        ),
      ).thenReturn(null);
      when(
        () => mockLogger.error(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
        ),
      ).thenReturn(null);
      when(
        () => mockLogger.warning(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
        ),
      ).thenReturn(null);

      // Stub service calls used in build()
      when(
        () => mockService.cleanupDraftActivities(any()),
      ).thenAnswer((_) async => 0);
      when(
        () => mockService.getAllActivities(any()),
      ).thenAnswer((_) async => <Activity>[]);

      // Stub repo for background sync (fire-and-forget)
      when(() => mockRepo.isStale()).thenAnswer((_) async => false);

      container = ProviderContainer(
        overrides: [
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: analytics,
              supabaseClient: _MockSupabaseClient(),
              sentry: _MockSentryReporter(),
              logger: mockLogger,
              sharedPreferences: _MockSharedPreferences(),
            ),
          ),
          appLoggerProvider.overrideWithValue(mockLogger),
          activitiesServiceProvider.overrideWithValue(mockService),
          activitiesRepositoryProvider.overrideWithValue(mockRepo),
          userIdProvider.overrideWith((ref) async => _testUserId),
          // currentUserProvider is a StreamProvider<AuthUser?>, so the override
          // must yield a stream — not a bare null.
          currentUserProvider.overrideWith(
            (ref) => Stream<AuthUser?>.value(null),
          ),
          syncCoordinatorProvider.overrideWith(() => _FakeSyncCoordinator()),
          integrationSyncCoordinatorProvider.overrideWith(
            () => _FakeIntegrationSyncCoordinator(),
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    test('fires first_activity_added when activity list was empty', () async {
      final createdActivity = _makeActivity();
      when(
        () => mockService.createActivity(
          deviceId: any(named: 'deviceId'),
          userId: any(named: 'userId'),
          forUserId: any(named: 'forUserId'),
          activityType: any(named: 'activityType'),
          title: any(named: 'title'),
          scheduledDateTime: any(named: 'scheduledDateTime'),
          distanceMiles: any(named: 'distanceMiles'),
          durationMinutes: any(named: 'durationMinutes'),
          paceTargetMinutesPerMile: any(named: 'paceTargetMinutesPerMile'),
          intensityLevel: any(named: 'intensityLevel'),
          notes: any(named: 'notes'),
          cyclingSpeedMph: any(named: 'cyclingSpeedMph'),
          cyclingTerrain: any(named: 'cyclingTerrain'),
          cyclingIndoorOutdoor: any(named: 'cyclingIndoorOutdoor'),
          cyclingElevationGainFt: any(named: 'cyclingElevationGainFt'),
          cyclingSessionGoal: any(named: 'cyclingSessionGoal'),
          swimmingPacePer100mSeconds: any(named: 'swimmingPacePer100mSeconds'),
          swimmingPoolOrOpenWater: any(named: 'swimmingPoolOrOpenWater'),
          swimmingWaterTempC: any(named: 'swimmingWaterTempC'),
          intensityTarget: any(named: 'intensityTarget'),
          timeBeforeMinutes: any(named: 'timeBeforeMinutes'),
          nutritionPlanData: any(named: 'nutritionPlanData'),
          brickMetadata: any(named: 'brickMetadata'),
          brickId: any(named: 'brickId'),
        ),
      ).thenAnswer((_) async => createdActivity);

      // Wait for build to complete (returns empty list)
      await container.read(activitiesControllerProvider.future);
      final controller = container.read(activitiesControllerProvider.notifier);

      // First create: list was empty, should fire first_activity_added
      await controller.createActivity(
        title: 'Morning Run',
        scheduledDateTime: DateTime(2026, 7, 10),
        activityType: ActivityType.running,
      );

      final events = analytics.findEvents('first_activity_added');
      expect(events, hasLength(1));
      expect(events.first.properties?['activity_type'], 'running');
      expect(events.first.properties?['activity_id'], 'activity-1');
    });

    test(
      'does NOT fire first_activity_added when list was non-empty',
      () async {
        // Return a non-empty list from build
        when(
          () => mockService.getAllActivities(any()),
        ).thenAnswer((_) async => [_makeActivity(id: 'existing-1')]);

        final newActivity = _makeActivity(id: 'activity-2');
        when(
          () => mockService.createActivity(
            deviceId: any(named: 'deviceId'),
            userId: any(named: 'userId'),
            forUserId: any(named: 'forUserId'),
            activityType: any(named: 'activityType'),
            title: any(named: 'title'),
            scheduledDateTime: any(named: 'scheduledDateTime'),
            distanceMiles: any(named: 'distanceMiles'),
            durationMinutes: any(named: 'durationMinutes'),
            paceTargetMinutesPerMile: any(named: 'paceTargetMinutesPerMile'),
            intensityLevel: any(named: 'intensityLevel'),
            notes: any(named: 'notes'),
            cyclingSpeedMph: any(named: 'cyclingSpeedMph'),
            cyclingTerrain: any(named: 'cyclingTerrain'),
            cyclingIndoorOutdoor: any(named: 'cyclingIndoorOutdoor'),
            cyclingElevationGainFt: any(named: 'cyclingElevationGainFt'),
            cyclingSessionGoal: any(named: 'cyclingSessionGoal'),
            swimmingPacePer100mSeconds: any(
              named: 'swimmingPacePer100mSeconds',
            ),
            swimmingPoolOrOpenWater: any(named: 'swimmingPoolOrOpenWater'),
            swimmingWaterTempC: any(named: 'swimmingWaterTempC'),
            intensityTarget: any(named: 'intensityTarget'),
            timeBeforeMinutes: any(named: 'timeBeforeMinutes'),
            nutritionPlanData: any(named: 'nutritionPlanData'),
            brickMetadata: any(named: 'brickMetadata'),
            brickId: any(named: 'brickId'),
          ),
        ).thenAnswer((_) async => newActivity);

        await container.read(activitiesControllerProvider.future);
        final controller = container.read(
          activitiesControllerProvider.notifier,
        );

        await controller.createActivity(
          title: 'Second Run',
          scheduledDateTime: DateTime(2026, 7, 11),
          activityType: ActivityType.running,
        );

        expect(analytics.hasEvent('first_activity_added'), isFalse);
      },
    );

    // `workout_planned` is the "used the core function" activation signal —
    // unlike `first_activity_added` it must fire on EVERY manual create, not
    // just the first, or the activation funnel only ever counts one per user.
    test('fires workout_planned on every create, not just the first', () async {
      when(
        () => mockService.getAllActivities(any()),
      ).thenAnswer((_) async => [_makeActivity(id: 'existing-1')]);

      _stubCreateActivity(mockService, _makeActivity(id: 'activity-2'));

      await container.read(activitiesControllerProvider.future);
      final controller = container.read(activitiesControllerProvider.notifier);

      await controller.createActivity(
        title: 'Second Run',
        scheduledDateTime: DateTime(2026, 7, 11),
        activityType: ActivityType.cycling,
        durationMinutes: 90,
      );

      // Fires even though this is NOT the user's first activity.
      expect(analytics.hasEvent('first_activity_added'), isFalse);

      final events = analytics.findEvents('workout_planned');
      expect(events, hasLength(1));
      expect(events.first.properties?['sport'], 'cycling');
      expect(events.first.properties?['duration_min'], 90);
      expect(events.first.properties?['source'], 'manual');
      expect(events.first.properties?['activity_id'], 'activity-2');
    });

    test('workout_planned marks coach-created activities', () async {
      _stubCreateActivity(mockService, _makeActivity());

      await container.read(activitiesControllerProvider.future);
      final controller = container.read(activitiesControllerProvider.notifier);

      await controller.createActivity(
        title: 'Athlete Run',
        scheduledDateTime: DateTime(2026, 7, 12),
        activityType: ActivityType.running,
        forUserId: 'athlete-9',
      );

      final events = analytics.findEvents('workout_planned');
      expect(events, hasLength(1));
      expect(events.first.properties?['is_coach_created'], isTrue);
    });
  });
}

/// `createActivity` has ~22 named parameters; stubbing them inline three times
/// over drowns the assertions.
void _stubCreateActivity(_MockActivitiesService mockService, Activity result) {
  when(
    () => mockService.createActivity(
      deviceId: any(named: 'deviceId'),
      userId: any(named: 'userId'),
      forUserId: any(named: 'forUserId'),
      activityType: any(named: 'activityType'),
      title: any(named: 'title'),
      scheduledDateTime: any(named: 'scheduledDateTime'),
      distanceMiles: any(named: 'distanceMiles'),
      durationMinutes: any(named: 'durationMinutes'),
      paceTargetMinutesPerMile: any(named: 'paceTargetMinutesPerMile'),
      intensityLevel: any(named: 'intensityLevel'),
      notes: any(named: 'notes'),
      cyclingSpeedMph: any(named: 'cyclingSpeedMph'),
      cyclingTerrain: any(named: 'cyclingTerrain'),
      cyclingIndoorOutdoor: any(named: 'cyclingIndoorOutdoor'),
      cyclingElevationGainFt: any(named: 'cyclingElevationGainFt'),
      cyclingSessionGoal: any(named: 'cyclingSessionGoal'),
      swimmingPacePer100mSeconds: any(named: 'swimmingPacePer100mSeconds'),
      swimmingPoolOrOpenWater: any(named: 'swimmingPoolOrOpenWater'),
      swimmingWaterTempC: any(named: 'swimmingWaterTempC'),
      intensityTarget: any(named: 'intensityTarget'),
      timeBeforeMinutes: any(named: 'timeBeforeMinutes'),
      nutritionPlanData: any(named: 'nutritionPlanData'),
      brickMetadata: any(named: 'brickMetadata'),
      brickId: any(named: 'brickId'),
    ),
  ).thenAnswer((_) async => result);
}

class _FakeSyncCoordinator extends SyncCoordinator {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeIntegrationSyncCoordinator extends IntegrationSyncCoordinator {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
