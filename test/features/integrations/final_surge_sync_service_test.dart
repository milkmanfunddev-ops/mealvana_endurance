// Tests for provider-sync business logic.
//
// Coverage goals:
// 1. Provider re-delete churn regression (the fix in ChangeDetectionService)
// 2. FinalSurgeSyncService — successful sync path with mocked collaborators
// 3. FinalSurgeSyncService — token-expired path
// 4. FinalSurgeSyncService — network-error path
// 5. FinalSurgeSyncService — not-connected guard
//
// The re-delete regression (#1) is tested directly against ChangeDetectionService
// because the guard lives there.  The FinalSurgeSyncService tests (#2-5) use
// mocktail mocks for every collaborator and stub the change-detection service
// so we isolate the service's own orchestration logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/final_surge_api_client.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/features/integrations/domain/sync_change_result.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';

// ---------------------------------------------------------------------------
// Mocks and fakes
// ---------------------------------------------------------------------------

class MockFinalSurgeApiClient extends Mock implements FinalSurgeApiClient {}

class MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

class MockActivitiesRepository extends Mock implements ActivitiesRepository {}

class MockFinalSurgeTransformer extends Mock implements FinalSurgeTransformer {}

class MockChangeDetectionService extends Mock
    implements ChangeDetectionService {}

class _FakeActivity extends Fake implements Activity {}

class _FakeIntegrationModel extends Fake implements IntegrationModel {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _userId = 'test-user-123';
const _provider = 'final_surge';

IntegrationModel _activeIntegration({
  DateTime? tokenExpiresAt,
  String? refreshToken = 'refresh-token',
}) => IntegrationModel(
  userId: _userId,
  provider: _provider,
  accessToken: 'access-token',
  refreshToken: refreshToken,
  tokenExpiresAt: tokenExpiresAt,
  providerAthleteId: 'athlete-1',
  providerAthleteName: 'Jane Doe',
  isActive: true,
);

Activity _activity({
  required String id,
  required String providerWorkoutId,
  DateTime? scheduledDateTime,
  DateTime? providerDeletedAt,
  ActivityStatus status = ActivityStatus.planned,
}) => Activity(
  id: id,
  userId: _userId,
  activityType: ActivityType.running,
  title: 'Test Run',
  scheduledDateTime: scheduledDateTime ?? DateTime(2026, 6, 1, 8),
  status: status,
  providerWorkoutId: providerWorkoutId,
  syncedFromProvider: _provider,
  providerDeletedAt: providerDeletedAt,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

FinalSurgeSyncService _buildService({
  required MockFinalSurgeApiClient apiClient,
  required MockIntegrationsRepository integrationsRepo,
  required MockActivitiesRepository activitiesRepo,
  required MockFinalSurgeTransformer transformer,
  required MockChangeDetectionService changeDetection,
  RecordingAnalyticsTracker? analytics,
}) => FinalSurgeSyncService(
  apiClient: apiClient,
  integrationsRepository: integrationsRepo,
  activitiesRepository: activitiesRepo,
  transformer: transformer,
  changeDetectionService: changeDetection,
  analytics: analytics,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivity());
    registerFallbackValue(_FakeIntegrationModel());
  });

  late MockFinalSurgeApiClient mockApiClient;
  late MockIntegrationsRepository mockIntegrationsRepo;
  late MockActivitiesRepository mockActivitiesRepo;
  late MockFinalSurgeTransformer mockTransformer;
  late MockChangeDetectionService mockChangeDetection;
  late RecordingAnalyticsTracker analytics;
  late FinalSurgeSyncService service;

  setUp(() {
    mockApiClient = MockFinalSurgeApiClient();
    mockIntegrationsRepo = MockIntegrationsRepository();
    mockActivitiesRepo = MockActivitiesRepository();
    mockTransformer = MockFinalSurgeTransformer();
    mockChangeDetection = MockChangeDetectionService();
    analytics = RecordingAnalyticsTracker();

    service = _buildService(
      apiClient: mockApiClient,
      integrationsRepo: mockIntegrationsRepo,
      activitiesRepo: mockActivitiesRepo,
      transformer: mockTransformer,
      changeDetection: mockChangeDetection,
      analytics: analytics,
    );

    // Default stubs for side-effect methods.
    final stubActivity = _activity(id: 'stub', providerWorkoutId: 'stub-pid');
    final stubIntegration = _activeIntegration();

    when(
      () => mockActivitiesRepo.insertActivity(any()),
    ).thenAnswer((_) async => stubActivity);

    when(
      () => mockActivitiesRepo.updateActivityFromProvider(any()),
    ).thenAnswer((_) async => stubActivity);

    when(
      () => mockActivitiesRepo.softDeleteFromProvider(any()),
    ).thenAnswer((_) async {});

    when(
      () => mockActivitiesRepo.getActivitiesByUserAndProvider(any(), any()),
    ).thenAnswer((_) async => []);

    when(
      () => mockActivitiesRepo.cleanupDuplicateProviderActivities(
        userId: any(named: 'userId'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer((_) async => 0);

    when(
      () => mockIntegrationsRepo.updateSyncStatus(
        any(),
        any(),
        status: any(named: 'status'),
        error: any(named: 'error'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockIntegrationsRepo.upsertIntegration(any()),
    ).thenAnswer((_) async => stubIntegration);

    when(
      () => mockTransformer.extractWorkoutId(any()),
    ).thenReturn('workout-default');
  });

  // -------------------------------------------------------------------------
  // 1. Not-connected guard
  // -------------------------------------------------------------------------

  group('not connected', () {
    test('returns notConnected result when no integration row found', () async {
      when(
        () => mockIntegrationsRepo.getIntegration(_userId, _provider),
      ).thenAnswer((_) async => null);

      final result = await service.syncWorkouts(_userId);

      // notConnected() factory sets success: false, errorType: notConnected.
      expect(result.success, isFalse);
      expect(result.needsReauth, isFalse);
      expect(result.isNetworkError, isFalse);
      expect(result.newWorkouts, 0);
    });

    test('returns notConnected result when integration is inactive', () async {
      final inactive = IntegrationModel(
        userId: _userId,
        provider: _provider,
        accessToken: 'token',
        providerAthleteId: 'a1',
        isActive: false,
      );
      when(
        () => mockIntegrationsRepo.getIntegration(_userId, _provider),
      ).thenAnswer((_) async => inactive);

      final result = await service.syncWorkouts(_userId);

      expect(result.success, isFalse);
      expect(result.newWorkouts, 0);
    });
  });

  // -------------------------------------------------------------------------
  // 2. Successful sync — inserts new activities and records them
  // -------------------------------------------------------------------------

  group('successful sync', () {
    setUp(() {
      when(
        () => mockIntegrationsRepo.getIntegration(_userId, _provider),
      ).thenAnswer((_) async => _activeIntegration());
    });

    test('inserts new activities and reports correct count', () async {
      final remoteActivity = _activity(
        id: 'remote-1',
        providerWorkoutId: 'p-1',
      );

      // Minimal valid API response — no structured workout
      final fakeResponse = FinalSurgeWorkoutsResponse(
        success: true,
        workouts: [
          {'WorkoutId': 'p-1', 'HasStructuredWorkout': false},
        ],
      );

      when(
        () => mockApiClient.getUpcomingWorkouts(
          any(),
          numDays: any(named: 'numDays'),
          numWorkouts: any(named: 'numWorkouts'),
        ),
      ).thenAnswer((_) async => fakeResponse);

      when(() => mockTransformer.extractWorkoutId(any())).thenReturn('p-1');
      when(
        () => mockTransformer.transform(
          any(),
          any(),
          structuredData: any(named: 'structuredData'),
        ),
      ).thenReturn(
        FinalSurgeTransformResult(
          activity: remoteActivity,
          syncedFromProvider: _provider,
          providerWorkoutId: 'p-1',
          lastSyncedAt: DateTime(2026, 6, 1),
        ),
      );

      when(
        () => mockChangeDetection.detectChanges(
          localActivities: any(named: 'localActivities'),
          remoteWorkouts: any(named: 'remoteWorkouts'),
          provider: any(named: 'provider'),
        ),
      ).thenReturn(
        SyncChangeResult(
          newActivities: [remoteActivity],
          updatedActivities: [],
          deletedActivityIds: [],
          unchangedCount: 0,
        ),
      );

      final result = await service.syncWorkouts(_userId, numDays: 7);

      expect(result.success, isTrue);
      expect(result.newWorkouts, 1);
      expect(result.deleted, 0);

      verify(() => mockActivitiesRepo.insertActivity(any())).called(1);
      verifyNever(() => mockActivitiesRepo.softDeleteFromProvider(any()));

      // A provider-synced workout is still "a workout planned" — it just did
      // not come through ActivitiesController, which is the only other place
      // that fires this. Without a fire here, `source` could only ever read
      // 'manual' and the manual-vs-synced split would be unmeasurable.
      final planned = analytics.findEvents('workout_planned');
      expect(planned, hasLength(1));
      expect(planned.single.properties!['source'], 'synced');
      expect(planned.single.properties!['provider'], 'final_surge');
      expect(planned.single.properties!['activity_id'], 'remote-1');
    });

    test('does not report a synced workout as manually planned', () async {
      // Guards the specific regression: a hardcoded source: 'manual' at the
      // controller call site.
      final remoteActivity = _activity(
        id: 'remote-2',
        providerWorkoutId: 'p-2',
      );

      when(
        () => mockApiClient.getUpcomingWorkouts(
          any(),
          numDays: any(named: 'numDays'),
          numWorkouts: any(named: 'numWorkouts'),
        ),
      ).thenAnswer(
        (_) async => FinalSurgeWorkoutsResponse(
          success: true,
          workouts: [
            {'WorkoutId': 'p-2', 'HasStructuredWorkout': false},
          ],
        ),
      );
      when(() => mockTransformer.extractWorkoutId(any())).thenReturn('p-2');
      when(
        () => mockTransformer.transform(
          any(),
          any(),
          structuredData: any(named: 'structuredData'),
        ),
      ).thenReturn(
        FinalSurgeTransformResult(
          activity: remoteActivity,
          syncedFromProvider: _provider,
          providerWorkoutId: 'p-2',
          lastSyncedAt: DateTime(2026, 6, 1),
        ),
      );
      when(
        () => mockChangeDetection.detectChanges(
          localActivities: any(named: 'localActivities'),
          remoteWorkouts: any(named: 'remoteWorkouts'),
          provider: any(named: 'provider'),
        ),
      ).thenReturn(
        SyncChangeResult(
          newActivities: [remoteActivity],
          updatedActivities: [],
          deletedActivityIds: [],
          unchangedCount: 0,
        ),
      );

      await service.syncWorkouts(_userId, numDays: 7);

      final sources = analytics
          .findEvents('workout_planned')
          .map((e) => e.properties!['source'])
          .toList();
      expect(sources, isNotEmpty);
      expect(sources, everyElement('synced'));
      expect(sources, isNot(contains('manual')));
    });

    test(
      'syncWorkoutsByDateRange also reports synced workouts as synced',
      () async {
        // The date-range path inserts through the same seam and must not be the
        // one place the manual/synced split silently reverts to 'manual'.
        final remoteActivity = _activity(
          id: 'remote-3',
          providerWorkoutId: 'p-3',
        );

        when(
          () => mockApiClient.getWorkoutsByDateRange(
            any(),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer(
          (_) async => FinalSurgeWorkoutsResponse(
            success: true,
            workouts: [
              {'WorkoutId': 'p-3', 'HasStructuredWorkout': false},
            ],
          ),
        );
        when(() => mockTransformer.extractWorkoutId(any())).thenReturn('p-3');
        when(
          () => mockTransformer.transform(
            any(),
            any(),
            structuredData: any(named: 'structuredData'),
          ),
        ).thenReturn(
          FinalSurgeTransformResult(
            activity: remoteActivity,
            syncedFromProvider: _provider,
            providerWorkoutId: 'p-3',
            lastSyncedAt: DateTime(2026, 6, 1),
          ),
        );
        when(
          () => mockChangeDetection.detectChanges(
            localActivities: any(named: 'localActivities'),
            remoteWorkouts: any(named: 'remoteWorkouts'),
            provider: any(named: 'provider'),
          ),
        ).thenReturn(
          SyncChangeResult(
            newActivities: [remoteActivity],
            updatedActivities: [],
            deletedActivityIds: [],
            unchangedCount: 0,
          ),
        );

        await service.syncWorkoutsByDateRange(
          _userId,
          startDate: DateTime(2026, 6, 1),
          endDate: DateTime(2026, 6, 30),
        );

        final planned = analytics.findEvents('workout_planned');
        expect(planned, hasLength(1));
        expect(planned.single.properties!['source'], 'synced');
        expect(planned.single.properties!['provider'], 'final_surge');
        expect(planned.single.properties!['activity_id'], 'remote-3');
      },
    );

    test(
      'soft-deletes activities flagged as deleted by change detection',
      () async {
        final fakeEmptyResponse = FinalSurgeWorkoutsResponse(
          success: true,
          workouts: [],
        );

        when(
          () => mockApiClient.getUpcomingWorkouts(
            any(),
            numDays: any(named: 'numDays'),
            numWorkouts: any(named: 'numWorkouts'),
          ),
        ).thenAnswer((_) async => fakeEmptyResponse);

        when(
          () => mockChangeDetection.detectChanges(
            localActivities: any(named: 'localActivities'),
            remoteWorkouts: any(named: 'remoteWorkouts'),
            provider: any(named: 'provider'),
          ),
        ).thenReturn(
          SyncChangeResult(
            newActivities: [],
            updatedActivities: [],
            deletedActivityIds: ['local-1'],
            unchangedCount: 0,
          ),
        );

        final result = await service.syncWorkouts(_userId, numDays: 7);

        expect(result.success, isTrue);
        expect(result.deleted, 1);
        verify(
          () => mockActivitiesRepo.softDeleteFromProvider('local-1'),
        ).called(1);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 3. Token-expiry path
  // -------------------------------------------------------------------------

  group('token expiry', () {
    test('returns requiresReauth when no refresh token is available and '
        'the API throws TokenExpiredException', () async {
      // Integration without a refresh token — refresh will fail immediately.
      final expiredIntegration = _activeIntegration(
        refreshToken: null,
        tokenExpiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );

      when(
        () => mockIntegrationsRepo.getIntegration(_userId, _provider),
      ).thenAnswer((_) async => expiredIntegration);

      // The first API call throws TokenExpiredException; the service will then
      // try to refresh the token. With no refreshToken the service should catch
      // TokenRefreshException(requiresReauth: true) and return requiresReauth.
      when(
        () => mockApiClient.getUpcomingWorkouts(
          any(),
          numDays: any(named: 'numDays'),
          numWorkouts: any(named: 'numWorkouts'),
        ),
      ).thenThrow(const TokenExpiredException('Token expired'));

      when(
        () => mockIntegrationsRepo.updateSyncStatus(
          _userId,
          _provider,
          status: 'requires_reauth',
          error: any(named: 'error'),
        ),
      ).thenAnswer((_) async {});

      final result = await service.syncWorkouts(_userId, numDays: 7);

      expect(result.success, isFalse);
      expect(result.needsReauth, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // 4. Network-error path
  // -------------------------------------------------------------------------

  group('network errors', () {
    test('returns isNetworkError=true on NetworkException', () async {
      when(
        () => mockIntegrationsRepo.getIntegration(_userId, _provider),
      ).thenAnswer((_) async => _activeIntegration());

      when(
        () => mockApiClient.getUpcomingWorkouts(
          any(),
          numDays: any(named: 'numDays'),
          numWorkouts: any(named: 'numWorkouts'),
        ),
      ).thenThrow(const NetworkException('Connection timed out'));

      final result = await service.syncWorkouts(_userId, numDays: 7);

      expect(result.success, isFalse);
      expect(result.isNetworkError, isTrue);
    });
  });

  // =========================================================================
  // 5. Provider re-delete churn regression
  //    ChangeDetectionService.detectChanges() must skip rows that already have
  //    providerDeletedAt set — otherwise they get re-queued for soft-delete on
  //    every no-op sync, churning needs_upload and uploading empty diff sets.
  // =========================================================================

  group('provider re-delete churn regression (ChangeDetectionService)', () {
    // These tests use the REAL ChangeDetectionService (the bug fix lives there).
    late ChangeDetectionService cds;

    setUp(() {
      cds = ChangeDetectionService();
    });

    test('already-soft-deleted activity is NOT re-added to deletedActivityIds '
        'when absent from the remote list', () {
      final alreadyDeleted = _activity(
        id: 'local-already-deleted',
        providerWorkoutId: 'p-already-gone',
        providerDeletedAt: DateTime(2026, 5, 1), // guard field is set
      );

      final result = cds.detectChanges(
        localActivities: [alreadyDeleted],
        remoteWorkouts: [],
        provider: _provider,
      );

      expect(
        result.deletedActivityIds,
        isEmpty,
        reason:
            'An activity already soft-deleted from the provider should be '
            'skipped, not re-flagged for deletion on every sync. '
            '(Regression: this was causing constant needs_upload churn.)',
      );
      expect(result.hasChanges, isFalse);
    });

    test('only genuinely-new deletions appear in deletedActivityIds '
        'when mixed with already-deleted rows', () {
      final alreadyDeleted = _activity(
        id: 'local-already-deleted',
        providerWorkoutId: 'p-already-gone',
        providerDeletedAt: DateTime(2026, 5, 1),
      );
      final genuinelyPresent = _activity(
        id: 'local-still-exists',
        providerWorkoutId: 'p-still-here',
      );
      final genuinelyRemoved = _activity(
        id: 'local-newly-removed',
        providerWorkoutId: 'p-newly-gone',
        // providerDeletedAt is null — first time this is being deleted
      );

      final remoteActivity = _activity(
        id: 'remote-1',
        providerWorkoutId: 'p-still-here',
      );

      final result = cds.detectChanges(
        localActivities: [alreadyDeleted, genuinelyPresent, genuinelyRemoved],
        remoteWorkouts: [remoteActivity],
        provider: _provider,
      );

      expect(
        result.deletedActivityIds,
        equals(['local-newly-removed']),
        reason:
            'Only the genuinely-removed activity should appear, not '
            'the one already marked providerDeletedAt.',
      );
    });

    test('all-already-deleted local rows produce zero changes '
        '(no spurious upload churn on no-op syncs)', () {
      final rows = List.generate(
        5,
        (i) => _activity(
          id: 'local-$i',
          providerWorkoutId: 'p-$i',
          providerDeletedAt: DateTime(2026, 3, i + 1),
        ),
      );

      final result = cds.detectChanges(
        localActivities: rows,
        remoteWorkouts: [],
        provider: _provider,
      );

      expect(result.deletedActivityIds, isEmpty);
      expect(result.newActivities, isEmpty);
      expect(result.updatedActivities, isEmpty);
      expect(
        result.hasChanges,
        isFalse,
        reason:
            'A no-op sync against a fully-deleted local set should produce '
            'zero changes, which means zero dirty uploads.',
      );
    });

    test('activity with providerDeletedAt null IS still flagged when missing '
        'from remote (normal deletion flow still works)', () {
      final normalActivity = _activity(
        id: 'local-normal',
        providerWorkoutId: 'p-normal',
        // providerDeletedAt is null — standard case
      );

      final result = cds.detectChanges(
        localActivities: [normalActivity],
        remoteWorkouts: [],
        provider: _provider,
      );

      expect(
        result.deletedActivityIds,
        equals(['local-normal']),
        reason: 'Normal soft-delete flow must still work after the guard fix.',
      );
    });
  });
}
