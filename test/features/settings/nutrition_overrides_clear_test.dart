// The Settings surface's "clear my plan-reveal overrides" path, through the
// real notifier.
//
// It is the one profile write that cannot be expressed with `??` — null means
// "leave them alone", not "clear them" — so it used to rebuild UserProfile
// field by field. That hand-rolled list silently reset every field it did not
// mention: body fat, lifestyle, training phase, the sweat test, and (as of
// v21) home location. copyWith owns the clear now; this pins that clearing
// the overrides touches nothing else.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/domain/enums.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_target_overrides.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';

class _MockUserRepository extends Mock implements UserRepository {}

/// The real controller with a canned build(), so the save path under test is
/// the production one without dragging in content, coach and auth lookups.
class _StubbedBuildController extends SettingsController {
  @override
  FutureOr<SettingsState> build() => const SettingsState(
    title: 'Settings',
    profileSectionTitle: 'Profile',
    preferenceSectionTitle: 'Preferences',
    genderLabel: 'Gender',
    birthdayLabel: 'Birthday',
    heightLabel: 'Height',
    weightLabel: 'Weight',
    waterBottleLabel: 'Water Bottle',
    distanceUnitLabel: 'Distance',
    paceUnitLabel: 'Pace',
    gutTrainingLabel: 'Gut Training',
    saveButtonText: 'Save',
    nutritionTargetOverrides: NutritionTargetOverrides(
      pre: PreActivityOverrides(carbsG: 50.0),
    ),
  );
}

/// Everything the old hand-rolled reconstruction forgot, plus the overrides
/// being cleared.
UserProfile _profile() => UserProfile(
  id: 'u1',
  deviceId: 'd1',
  gender: Gender.male,
  birthday: DateTime(1985, 3, 20),
  heightFeet: 5,
  heightInches: 11,
  weightPounds: 165,
  runsWithWaterBottle: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  appVersion: '1.0.0',
  bodyFatPct: 18.5,
  lifestyle: Lifestyle.active,
  typicalWeeklyHours: 10,
  carbCycleOptIn: true,
  trainingPhase: TrainingPhase.build,
  sweatSodium: SweatSodiumCat.high,
  knownSweatRateMlPerHour: 1200,
  sweatTestSource: 'gatorade_gx',
  homeCity: 'Birmingham, Alabama',
  homeLat: 33.5186,
  homeLon: -86.8104,
  homeTimezone: 'America/Chicago',
  nutritionTargetOverrides: const NutritionTargetOverrides(
    pre: PreActivityOverrides(carbsG: 50.0),
  ),
);

void main() {
  late _MockUserRepository repo;
  late UserProfile saved;

  setUpAll(() => registerFallbackValue(_profile()));

  setUp(() {
    repo = _MockUserRepository();
    when(() => repo.getCurrentUser()).thenAnswer((_) async => _profile());
    when(
      () =>
          repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    ).thenAnswer((inv) async {
      saved = inv.positionalArguments.first as UserProfile;
    });
  });

  Future<SettingsController> controller() async {
    final container = ProviderContainer(
      overrides: [
        userRepositoryProvider.overrideWith((_) async => repo),
        settingsControllerProvider.overrideWith(_StubbedBuildController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsControllerProvider.future);
    return container.read(settingsControllerProvider.notifier);
  }

  test('clearing the overrides keeps every other profile field', () async {
    await (await controller()).saveNutritionTargetOverrides(null);

    expect(saved.nutritionTargetOverrides, isNull);
    // The fields the hand-rolled reconstruction used to wipe.
    expect(saved.bodyFatPct, 18.5);
    expect(saved.lifestyle, Lifestyle.active);
    expect(saved.typicalWeeklyHours, 10);
    expect(saved.carbCycleOptIn, isTrue);
    expect(saved.trainingPhase, TrainingPhase.build);
    expect(saved.sweatSodium, SweatSodiumCat.high);
    expect(saved.knownSweatRateMlPerHour, 1200);
    expect(saved.sweatTestSource, 'gatorade_gx');
    expect(saved.homeCity, 'Birmingham, Alabama');
    expect(saved.homeLat, 33.5186);
    expect(saved.homeLon, -86.8104);
    expect(saved.homeTimezone, 'America/Chicago');
  });

  test('setting new overrides replaces them and keeps the rest', () async {
    const replacement = NutritionTargetOverrides(
      pre: PreActivityOverrides(carbsG: 75.0),
    );

    await (await controller()).saveNutritionTargetOverrides(replacement);

    expect(saved.nutritionTargetOverrides?.pre?.carbsG, 75.0);
    expect(saved.bodyFatPct, 18.5);
    expect(saved.homeCity, 'Birmingham, Alabama');
  });
}
