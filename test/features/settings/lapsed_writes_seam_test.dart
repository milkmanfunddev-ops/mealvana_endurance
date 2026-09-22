/// A lapsed account cannot edit its profile or sweat profile (mp-457 §4,
/// mp-491, ticket 12).
///
/// Through the real SettingsController and SweatProfileController: each
/// profile edit asks the write guard first; refused, it opens the paywall
/// once and never constructs the user repository, so nothing is written or
/// queued. Sign-out and account deletion are not edits and stay open to a
/// lapsed account (mp-280 §2), so they are not here.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/features/onboarding/domain/allergy.dart';
import 'package:mealvana_endurance/features/onboarding/domain/dietary_preference.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/sweat_profile_controller.dart';

import 'package:mealvana_endurance/features/subscription/domain/write_access_denied.dart';

import '../../helpers/write_access.dart';

/// The settings state is content-heavy; a refused edit never reads it.
class _FakeSettingsState extends Fake implements SettingsState {}

class _SeededSettings extends SettingsController {
  @override
  FutureOr<SettingsState> build() => _FakeSettingsState();
}

/// What save() validates before it asks to write: nothing entered by hand.
class _FakeSweatState extends Fake implements SweatProfileState {
  @override
  int? get knownSweatRateMlPerHour => null;
  @override
  int? get knownSodiumConcentrationMgPerLiter => null;
}

class _SeededSweat extends SweatProfileController {
  @override
  FutureOr<SweatProfileState> build() => _FakeSweatState();
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        userRepositoryProvider.overrideWith(untouched('userRepository')),
        settingsControllerProvider.overrideWith(_SeededSettings.new),
        sweatProfileControllerProvider.overrideWith(_SeededSweat.new),
      ],
    );
    addTearDown(container.dispose);
  });

  group('SettingsController, lapsed', () {
    SettingsController ctrl() =>
        container.read(settingsControllerProvider.notifier);
    final paths = <String, Future<Object?> Function()>{
      'updateGender': () => ctrl().updateGender(Gender.male),
      'updateBirthday': () => ctrl().updateBirthday(DateTime(1990, 1, 1)),
      'updateHeight': () => ctrl().updateHeight(5, 10),
      'updateWeight': () => ctrl().updateWeight(160),
      'updateWaterBottle': () => ctrl().updateWaterBottle(true),
      'updateUnitSystem': () => ctrl().updateUnitSystem(UnitSystem.imperial),
      'updateGutTraining': () => ctrl().updateGutTraining(GutTraining.low),
      'updateSweatRate': () => ctrl().updateSweatRate(SweatRateCat.light),
      'saveAllPreferences': () => ctrl().saveAllPreferences(weightPounds: 160),
      'updateGISensitivity': () => ctrl().updateGISensitivity(true),
      'updateCyclingPreferences': () =>
          ctrl().updateCyclingPreferences(ftpWatts: 200),
      'updateSwimmingPreferences': () =>
          ctrl().updateSwimmingPreferences(typicalWetsuit: true),
      'saveSportSettings': () => ctrl().saveSportSettings(),
      'updateDietaryPreference': () =>
          ctrl().updateDietaryPreference(DietaryPreference.none),
      'updateAllergies': () => ctrl().updateAllergies(const [Allergy.dairy]),
      'saveNutritionTargetOverrides': () =>
          ctrl().saveNutritionTargetOverrides(null),
    };
    for (final entry in paths.entries) {
      test('${entry.key} opens the paywall and writes nothing', () async {
        await container.read(settingsControllerProvider.future);
        await expectWriteRefused(opens, entry.value);
        expect(container.read(settingsControllerProvider).hasError, isFalse);
      });
    }
  });

  test('SweatProfileController.save, lapsed: refused, never a save', () async {
    await container.read(sweatProfileControllerProvider.future);
    await expectLater(
      container.read(sweatProfileControllerProvider.notifier).save(),
      throwsA(isA<WriteAccessDenied>()),
      reason: 'the screen must not report a save',
    );
    expect(opens.count, 1);
  });
}
