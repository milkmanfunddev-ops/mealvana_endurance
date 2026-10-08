// Ticket 70: `plan_generated` carries the device id `app_opened` sends
// (deviceInfoServiceProvider), not the user id. The generate-macros request
// keeps the user id in its own `device_id` field: the edge function reads it
// as the user, so it must not change.
//
// Driven through the real ActivityDetailController.regeneratePlan() (seeded
// build, same pattern as regenerate_plan_no_fasted_field_test.dart). The edge
// call fails with a host-lookup error, so the service takes its production
// offline fallback and then tracks `plan_generated`; no server response is
// fabricated.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/nutrition_plan/data/macro_repository.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/macro_targets.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/activity_detail_state.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/device_info_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/fakes/recording_analytics_tracker.dart';
import '../../../../helpers/fixtures/user_fixtures.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockSharedPreferences extends Mock implements SharedPreferences {}

/// Accepts the cache writes the service makes after generation.
class _FakeMacroRepository implements MacroRepository {
  @override
  Future<void> saveMacroTargets(MacroTargets macroTargets) async {}

  @override
  Future<void> saveMacroTargetsForActivity(
    String activityId,
    MacroTargets macroTargets,
  ) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDeviceInfo implements DeviceInfoService {
  @override
  String get deviceId => _deviceId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

const _activityId = 'activity-plan-device-id-1';
const _userId = '4dbde602-69d1-48cb-b984-2ca707702256';
const _deviceId = 'C8EEF12E-60FE-49A1-80F8-6C51A4BE767D';

void main() {
  test(
    'regeneratePlan: plan_generated carries the device id; the edge request '
    'keeps the user id',
    () async {
      final authService = _MockAuthService();
      final supabaseClient = _MockSupabaseClient();
      final functionsClient = _MockFunctionsClient();
      final analytics = RecordingAnalyticsTracker();

      final user = UserFixtures.completedUser(id: _userId, deviceId: 'legacy');
      when(() => authService.getCurrentUser()).thenAnswer((_) async => user);
      when(() => authService.getLikedFoods(any())).thenAnswer((_) async => []);
      when(
        () => authService.getDislikedFoods(any()),
      ).thenAnswer((_) async => []);
      when(
        () => authService.getWillingToTryFoods(any()),
      ).thenAnswer((_) async => []);
      when(() => supabaseClient.functions).thenReturn(functionsClient);
      when(
        () => functionsClient.invoke(any(), body: any(named: 'body')),
      ).thenThrow(const SocketException('Failed host lookup'));

      final activity = Activity(
        id: _activityId,
        userId: _userId,
        activityType: ActivityType.running,
        title: 'Tempo Run',
        scheduledDateTime: DateTime(2026, 10, 9, 6),
        distanceMiles: 6,
        paceTargetMinutesPerMile: 9,
        timeBeforeMinutes: 45,
        createdAt: DateTime(2026, 10, 8),
        updatedAt: DateTime(2026, 10, 8),
      );

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          analyticsTrackerProvider.overrideWithValue(analytics),
          macroRepositoryProvider.overrideWithValue(_FakeMacroRepository()),
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: analytics,
              supabaseClient: supabaseClient,
              sharedPreferences: _MockSharedPreferences(),
            ),
          ),
          deviceInfoServiceProvider.overrideWithValue(_FakeDeviceInfo()),
          activityDetailControllerProvider(
            activityId: _activityId,
            isNewActivity: false,
          ).overrideWith(
            () => _SeededActivityDetailController(
              ActivityDetailState(
                activity: activity,
                scheduledDateTime: activity.scheduledDateTime,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final provider = activityDetailControllerProvider(
        activityId: _activityId,
        isNewActivity: false,
      );
      container.read(provider);
      await container.read(provider.notifier).regeneratePlan();

      final body =
          (verify(
                    () => functionsClient.invoke(
                      any(),
                      body: captureAny(named: 'body'),
                    ),
                  ).captured.single
                  as Map)
              .cast<String, dynamic>();
      expect(body['device_id'], _userId);

      final generated = analytics.events.where(
        (e) => e.name == 'plan_generated',
      );
      expect(generated, hasLength(1));
      expect(generated.single.properties?['device_id'], _deviceId);
    },
  );
}
