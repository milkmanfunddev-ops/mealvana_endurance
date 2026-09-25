// Ticket 104 (Finding 86-006): `user_registered` carries the device id that
// `app_opened` sends (DeviceInfoService), not the new account's user id, so
// Mixpanel can tie the registration to the device's earlier events.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/features/onboarding/application/onboarding_service.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/device_info_service.dart';

import '../../../helpers/fakes/recording_analytics_tracker.dart';
import '../../../helpers/fixtures/user_fixtures.dart';
import '../../../helpers/widget_test_harness.dart';

const _userId = '4dbde602-69d1-48cb-b984-2ca707702256';
const _deviceId = 'C8EEF12E-60FE-49A1-80F8-6C51A4BE767D';

/// The account `createUser` returns: its id is the auth user's, and its
/// legacy `deviceId` column is deliberately neither id, so only the device
/// info service can supply the expected value.
class _FakeAuthService implements AuthService {
  @override
  Future<UserProfile> createUser({
    required Gender gender,
    required DateTime birthday,
    required int heightFeet,
    required int heightInches,
    required double weightPounds,
    required bool runsWithWaterBottle,
    GutTraining? gutTraining,
    SweatRateCat? sweatRate,
    UnitSystem unitSystem = UnitSystem.imperial,
    Map<String, FoodPreference>? foodPreferences,
    required String authProvider,
    String? firstName,
    String? lastName,
    String? email,
  }) async => UserFixtures.completedUser(id: _userId, deviceId: 'legacy');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeDeviceInfo implements DeviceInfoService {
  @override
  String get deviceId => _deviceId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('trackUserRegistered receives the device id, not the user id', () async {
    final analytics = RecordingAnalyticsTracker();
    final container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: fakeSupabaseClient(),
            sentry: mockSentryReporter(),
            logger: MockAppLogger(),
            sharedPreferences: MockSharedPreferences(),
          ),
        ),
        authServiceProvider.overrideWithValue(_FakeAuthService()),
        deviceInfoServiceProvider.overrideWithValue(_FakeDeviceInfo()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(onboardingServiceProvider)
        .createUserProfile(
          gender: Gender.female,
          birthday: DateTime(1990, 1, 1),
          heightFeet: 5,
          heightInches: 6,
          weightPounds: 130,
          runsWithWaterBottle: false,
          authProvider: 'email',
        );

    final registered = analytics.events.where(
      (e) => e.name == 'user_registered',
    );
    expect(registered, hasLength(1));
    expect(registered.single.properties?['device_id'], _deviceId);
  });
}
