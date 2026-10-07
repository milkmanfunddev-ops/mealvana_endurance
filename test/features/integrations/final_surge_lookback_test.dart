// Ticket 138 (Finding 100-006, Lee 2026-09-26): the Final Surge fetch
// started at today, so a completion that arrived after its day passed was
// never read. The sync now also fetches the past 7 days by date range;
// deletion flagging stays on today onward.
import 'package:flutter_test/flutter_test.dart';
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
import 'package:mocktail/mocktail.dart';

class _MockApi extends Mock implements FinalSurgeApiClient {}

class _MockIntegrations extends Mock implements IntegrationsRepository {}

class _MockActivities extends Mock implements ActivitiesRepository {}

class _MockTransformer extends Mock implements FinalSurgeTransformer {}

class _MockChanges extends Mock implements ChangeDetectionService {}

class _FakeActivity extends Fake implements Activity {}

const _userId = 'u-fs';

IntegrationModel _integration() => IntegrationModel(
  userId: _userId,
  provider: 'final_surge',
  accessToken: 'token',
  refreshToken: 'refresh',
  tokenExpiresAt: DateTime.now().add(const Duration(hours: 2)),
  providerAthleteId: 'a1',
  isActive: true,
);

Activity _activity(String id) => Activity(
  id: id,
  userId: _userId,
  activityType: ActivityType.running,
  title: 'Run',
  scheduledDateTime: DateTime.now(),
  status: ActivityStatus.planned,
  providerWorkoutId: id,
  syncedFromProvider: 'final_surge',
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeActivity()));

  late _MockApi api;
  late _MockIntegrations integrations;
  late _MockActivities activities;
  late _MockTransformer transformer;
  late _MockChanges changes;
  late FinalSurgeSyncService service;

  setUp(() {
    api = _MockApi();
    integrations = _MockIntegrations();
    activities = _MockActivities();
    transformer = _MockTransformer();
    changes = _MockChanges();
    service = FinalSurgeSyncService(
      apiClient: api,
      integrationsRepository: integrations,
      activitiesRepository: activities,
      transformer: transformer,
      changeDetectionService: changes,
    );

    when(
      () => integrations.getIntegration(_userId, 'final_surge'),
    ).thenAnswer((_) async => _integration());
    when(
      () => integrations.updateSyncStatus(
        any(),
        any(),
        status: any(named: 'status'),
        error: any(named: 'error'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => activities.getActivitiesByUserAndProvider(_userId, 'final_surge'),
    ).thenAnswer((_) async => []);
    when(
      () => activities.cleanupDuplicateProviderActivities(
        userId: any(named: 'userId'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer((_) async => 0);
    when(() => activities.insertActivity(any())).thenAnswer(
      (i) async => i.positionalArguments.first as Activity,
    );
    when(() => transformer.extractWorkoutId(any())).thenAnswer(
      (i) => (i.positionalArguments.first as Map)['WorkoutId'] as String,
    );
    when(
      () => transformer.transform(
        any(),
        any(),
        structuredData: any(named: 'structuredData'),
      ),
    ).thenAnswer((i) {
      final id = (i.positionalArguments.first as Map)['WorkoutId'] as String;
      return FinalSurgeTransformResult(
        activity: _activity(id),
        syncedFromProvider: 'final_surge',
        providerWorkoutId: id,
        lastSyncedAt: DateTime.now(),
        providerReportsCompletion: id.startsWith('done'),
      );
    });
    when(
      () => changes.detectChanges(
        localActivities: any(named: 'localActivities'),
        remoteWorkouts: any(named: 'remoteWorkouts'),
        provider: any(named: 'provider'),
        completionSignalIds: any(named: 'completionSignalIds'),
        deletionWindowStart: any(named: 'deletionWindowStart'),
        deletionWindowEnd: any(named: 'deletionWindowEnd'),
      ),
    ).thenReturn(
      const SyncChangeResult(
        newActivities: [],
        updatedActivities: [],
        deletedActivityIds: [],
        unchangedCount: 0,
      ),
    );

    when(
      () => api.getUpcomingWorkouts(
        any(),
        numDays: any(named: 'numDays'),
        numWorkouts: any(named: 'numWorkouts'),
      ),
    ).thenAnswer(
      (_) async => const FinalSurgeWorkoutsResponse(
        success: true,
        workouts: [
          {'WorkoutId': 'up-1', 'HasStructuredWorkout': false},
        ],
      ),
    );
  });

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  test('fetches the past 7 days by date range and reads their completions',
      () async {
    when(
      () => api.getWorkoutsByDateRange(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer(
      (_) async => const FinalSurgeWorkoutsResponse(
        success: true,
        workouts: [
          {'WorkoutId': 'done-past', 'HasStructuredWorkout': false},
        ],
      ),
    );

    final result = await service.syncWorkouts(_userId, numDays: 7);
    expect(result.success, isTrue);

    final range = verify(
      () => api.getWorkoutsByDateRange(
        'token',
        startDate: captureAny(named: 'startDate'),
        endDate: captureAny(named: 'endDate'),
      ),
    ).captured;
    expect(range, hasLength(2), reason: 'one lookback call');
    final start = range[0] as DateTime;
    final end = range[1] as DateTime;
    expect(start, today().subtract(const Duration(days: 7)));
    expect(end, today().subtract(const Duration(days: 1)));

    final detect = verify(
      () => changes.detectChanges(
        localActivities: any(named: 'localActivities'),
        remoteWorkouts: captureAny(named: 'remoteWorkouts'),
        provider: 'final_surge',
        completionSignalIds: captureAny(named: 'completionSignalIds'),
        deletionWindowStart: captureAny(named: 'deletionWindowStart'),
        deletionWindowEnd: any(named: 'deletionWindowEnd'),
      ),
    ).captured;
    final remote = detect[0] as List<Activity>;
    final signals = detect[1] as Set<String>;
    final windowStart = detect[2] as DateTime;
    expect(remote.map((a) => a.providerWorkoutId), containsAll(['up-1', 'done-past']));
    expect(signals, contains('done-past'));
    expect(windowStart, today(), reason: 'deletions are flagged from today on');
  });

  test('a tenant without the date-range endpoint keeps the upcoming window',
      () async {
    when(
      () => api.getWorkoutsByDateRange(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenThrow(
      const IntegrationApiException('Not found', statusCode: 404),
    );

    final result = await service.syncWorkouts(_userId, numDays: 7);
    expect(result.success, isTrue);

    final detect = verify(
      () => changes.detectChanges(
        localActivities: any(named: 'localActivities'),
        remoteWorkouts: captureAny(named: 'remoteWorkouts'),
        provider: 'final_surge',
        completionSignalIds: any(named: 'completionSignalIds'),
        deletionWindowStart: any(named: 'deletionWindowStart'),
        deletionWindowEnd: any(named: 'deletionWindowEnd'),
      ),
    ).captured;
    expect(
      (detect[0] as List<Activity>).map((a) => a.providerWorkoutId),
      ['up-1'],
    );
  });

  test('lookbackDays: 0 makes no date-range call', () async {
    await service.syncWorkouts(_userId, numDays: 7, lookbackDays: 0);
    verifyNever(
      () => api.getWorkoutsByDateRange(
        any(),
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    );
  });
}
