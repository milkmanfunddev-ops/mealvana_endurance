import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/macro_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fixtures/user_fixtures.dart';

// Regression test for the is_fasted persistence fix: `regeneratePlan()` (run
// after an inline sweat-profile edit) used to hardcode `isFasted: false` /
// rely on the generation services' `isFasted = false` defaults, so a
// genuinely fasted activity silently regenerated as non-fasted.
//
// The fix persists the flag on the Activity (activities.is_fasted) and
// `regeneratePlan()` now forwards `activity.isFasted` into macro generation.
//
// Mutation check: revert the `isFasted: activity.isFasted` arguments in
// `activity_detail_controller.dart`'s `regeneratePlan()` and these tests fail
// (the captured edge-function body carries `is_fasted: false`).

class MockAuthService extends Mock implements AuthService {}

class MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class MockMacroRepository extends Mock implements MacroRepository {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockFunctionsClient extends Mock implements FunctionsClient {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockSharedPreferences extends Mock implements SharedPreferences {}

/// Seeds a fixed initial state but defers to the real controller for
/// `regeneratePlan()` (same pattern as
/// fuel_log_reopen_and_save_regression_test.dart).
class _SeededActivityDetailController extends ActivityDetailController {
  _SeededActivityDetailController(this._seed);

  final ActivityDetailState _seed;

  @override
  FutureOr<ActivityDetailState> build({
    required String activityId,
    bool isNewActivity = false,
  }) {
    return _seed;
  }
}

const _activityId = 'activity-fasted-regen-1';
const _userId = 'user-fasted-regen-1';

Activity _fastedActivity({required ActivityType activityType}) {
  return Activity(
    id: _activityId,
    userId: _userId,
    activityType: activityType,
    title: 'Fasted Workout',
    scheduledDateTime: DateTime(2026, 7, 21, 6),
    distanceMiles: 6,
    paceTargetMinutesPerMile: 9,
    cyclingSpeedMph: 16,
    cyclingTerrain: 'flat',
    timeBeforeMinutes: 45,
    // The persisted flag under test.
    isFasted: true,
    createdAt: DateTime(2026, 7, 20),
    updatedAt: DateTime(2026, 7, 20),
  );
}

void main() {
  late MockAuthService authService;
  late MockAnalyticsTracker analytics;
  late MockMacroRepository macroRepository;
  late MockSupabaseClient supabaseClient;
  late MockFunctionsClient functionsClient;

  setUp(() {
    authService = MockAuthService();
    analytics = MockAnalyticsTracker();
    macroRepository = MockMacroRepository();
    supabaseClient = MockSupabaseClient();
    functionsClient = MockFunctionsClient();

    final user = UserFixtures.completedUser(id: _userId);
    when(() => authService.getCurrentUser()).thenAnswer((_) async => user);
    when(() => authService.getLikedFoods(any())).thenAnswer((_) async => []);
    when(() => authService.getDislikedFoods(any())).thenAnswer((_) async => []);
    when(
      () => authService.getWillingToTryFoods(any()),
    ).thenAnswer((_) async => []);

    when(() => supabaseClient.functions).thenReturn(functionsClient);
    // Capture point: throw a sentinel so the test never has to fabricate a
    // full generate-macros response. The message deliberately avoids the
    // network-failure substrings that would trigger the offline fallback, so
    // the service rethrows and regeneratePlan lands in its catch block.
    when(
      () => functionsClient.invoke(any(), body: any(named: 'body')),
    ).thenThrow(Exception('sentinel: request captured'));
  });

  ProviderContainer buildContainer(ActivityDetailState seed) {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(authService),
        analyticsTrackerProvider.overrideWithValue(analytics),
        macroRepositoryProvider.overrideWithValue(macroRepository),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: supabaseClient,
            sentry: MockSentryReporter(),
            logger: NoopAppLogger(),
            sharedPreferences: MockSharedPreferences(),
          ),
        ),
        activityDetailControllerProvider(
          activityId: _activityId,
          isNewActivity: false,
        ).overrideWith(() => _SeededActivityDetailController(seed)),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<Map<String, dynamic>> capturedGenerateBody(
    ActivityType activityType,
  ) async {
    final activity = _fastedActivity(activityType: activityType);
    final container = buildContainer(
      ActivityDetailState(
        activity: activity,
        scheduledDateTime: activity.scheduledDateTime,
      ),
    );

    // Prime the seeded provider, then run the real regeneratePlan().
    container.read(
      activityDetailControllerProvider(
        activityId: _activityId,
        isNewActivity: false,
      ),
    );
    await container
        .read(
          activityDetailControllerProvider(
            activityId: _activityId,
            isNewActivity: false,
          ).notifier,
        )
        .regeneratePlan();

    final captured = verify(
      () => functionsClient.invoke(any(), body: captureAny(named: 'body')),
    ).captured;
    expect(captured, hasLength(1));
    return (captured.single as Map).cast<String, dynamic>();
  }

  group('regeneratePlan forwards the persisted isFasted flag', () {
    test('running: edge-function body carries is_fasted true', () async {
      final body = await capturedGenerateBody(ActivityType.running);

      // Pre-fix, regeneratePlan omitted isFasted and the service default
      // (false) was sent — this assertion is the mutation check.
      expect(
        body['is_fasted'],
        isTrue,
        reason:
            'regeneratePlan must forward activity.isFasted to running macro '
            'generation instead of the non-fasted default.',
      );
    });

    test('cycling: edge-function body carries is_fasted true', () async {
      final body = await capturedGenerateBody(ActivityType.cycling);

      expect(
        body['is_fasted'],
        isTrue,
        reason:
            'regeneratePlan must forward activity.isFasted to cycling macro '
            'generation instead of the non-fasted default.',
      );
    });
  });
}
