// Regression tests for deviation D-016: the pre-workout fueling window
// ("time before workout") input domain is 0–240 minutes in 15-minute steps
// (docs/ssot/spec/fueling/pre-workout-carbs.md "Inputs";
// docs/ssot/DEVIATIONS.md D-016). The app previously shipped a 480-minute
// stepper, which silently pushed the carb band to 4.5 g/kg above t−240.
//
// Two behaviors are pinned here, for all four sport input controllers:
//  1. A stale persisted lead time (e.g. 480 min saved before the cap) is
//     clamped to 240 at load — NewActivityScreen prefills edits through the
//     same updatePreXMinutes setters exercised below.
//  2. The 240 ceiling holds against increments past the cap (the steppers
//     also disable the + button at 240 via FuelingWindowLimits).
//
// Mutation check: removing clampFuelingWindowMinutes() from any of the four
// setters fails the corresponding test with 480 left in form state.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mealvana_endurance/features/nutrition_plan/domain/fueling_window_limits.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/running_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/cycling_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/swimming_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/brick_input_controller.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../../../helpers/widget_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        mockSharedPreferences(),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('FuelingWindowLimits (D-016 SSOT domain)', () {
    test('ratified bounds: 0–240 in 15-minute steps', () {
      expect(FuelingWindowLimits.minMinutes, 0);
      expect(FuelingWindowLimits.maxMinutes, 240);
      expect(FuelingWindowLimits.stepMinutes, 15);
    });

    test('clampFuelingWindowMinutes clamps both ends and passes in-domain', () {
      expect(clampFuelingWindowMinutes(480), 240);
      expect(clampFuelingWindowMinutes(255), 240);
      expect(clampFuelingWindowMinutes(240), 240);
      expect(clampFuelingWindowMinutes(90), 90);
      expect(clampFuelingWindowMinutes(0), 0);
      expect(clampFuelingWindowMinutes(-15), 0);
    });
  });

  group('stale persisted lead time > 240 is clamped on load', () {
    test('RunningInputController', () {
      final container = makeContainer();
      final notifier = container.read(runningInputControllerProvider.notifier);

      // Simulates NewActivityScreen prefilling from an activity saved with
      // the old 480-minute ceiling.
      notifier.updatePreRunMinutes(480);
      expect(container.read(runningInputControllerProvider).preRunMinutes, 240);
    });

    test('CyclingInputController', () {
      final container = makeContainer();
      final notifier = container.read(cyclingInputControllerProvider.notifier);

      notifier.updatePreRideMinutes(480);
      expect(
        container.read(cyclingInputControllerProvider).preRideMinutes,
        240,
      );
    });

    test('SwimmingInputController', () {
      final container = makeContainer();
      final notifier = container.read(swimmingInputControllerProvider.notifier);

      notifier.updatePreSwimMinutes(480);
      expect(
        container.read(swimmingInputControllerProvider).preSwimMinutes,
        240,
      );
    });

    test('BrickInputController', () {
      final container = makeContainer();
      final notifier = container.read(brickInputControllerProvider.notifier);

      notifier.updatePreActivityMinutes(480);
      expect(
        container.read(brickInputControllerProvider).preActivityMinutes,
        240,
      );
    });
  });

  group('240 cap is respected on increment', () {
    test('RunningInputController holds 240 when stepped past the cap', () {
      final container = makeContainer();
      final notifier = container.read(runningInputControllerProvider.notifier);

      notifier.updatePreRunMinutes(240);
      // The stepper disables + at 240; even if a raw +15 slips through, the
      // controller must not leave the ratified domain.
      notifier.updatePreRunMinutes(240 + FuelingWindowLimits.stepMinutes);
      expect(container.read(runningInputControllerProvider).preRunMinutes, 240);
    });

    test('BrickInputController holds 240 when stepped past the cap', () {
      final container = makeContainer();
      final notifier = container.read(brickInputControllerProvider.notifier);

      notifier.updatePreActivityMinutes(240);
      notifier.updatePreActivityMinutes(240 + FuelingWindowLimits.stepMinutes);
      expect(
        container.read(brickInputControllerProvider).preActivityMinutes,
        240,
      );
    });

    test('in-domain values pass through unchanged (floor 0, 15-min grid)', () {
      final container = makeContainer();
      final notifier = container.read(runningInputControllerProvider.notifier);

      notifier.updatePreRunMinutes(0);
      expect(container.read(runningInputControllerProvider).preRunMinutes, 0);

      notifier.updatePreRunMinutes(135);
      expect(container.read(runningInputControllerProvider).preRunMinutes, 135);
    });
  });
}
