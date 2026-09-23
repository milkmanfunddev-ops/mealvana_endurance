// Q-CA2 — the lifetime of create-flow form state.
//
// RULED Xuan, 2026-09-21, option (a) PER-ACTIVITY:
//   * opening the create flow for a NEW activity resets the values AND the
//     `*ManuallySet` flags;
//   * "a manual change persists" (CF-1/CF-7) means *within the activity being
//     edited*;
//   * editing an EXISTING activity re-hydrates from that activity;
//   * ONE lifetime for ALL form state — title, temperature and humidity follow
//     the same rule as the fueling window.
//
// The window half shipped first (app 7418566f, pinned by
// create_flow_fueling_controls_conformance_test.dart); this suite pins the
// other half and the invariants the widening must not break.
//
// Ruling request: qa/intake/2026-09-03-form-state-reset-semantics.md.
// Ops bug: ops/data/bug-reports/
// 2026-09-03-fueling-window-sticks-across-activities.md.
//
// Real-code-path rule: every assertion runs through the real notifier
// (`container.read(...notifier)`), never a hand-built state object.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/activities/domain/activity_title_formatter.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/brick_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/cycling_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/running_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/swimming_input_controller.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../../helpers/widget_test_harness.dart';

class _MockUserRepository extends Mock implements UserRepository {}

/// A metric athlete — the only profile detail these tests care about.
UserProfile _metricProfile() => UserProfile(
      id: '00000000-0000-4000-8000-00000000qca2',
      deviceId: 'device-q-ca2',
      gender: Gender.female,
      birthday: DateTime(1990, 1, 1),
      heightFeet: 5,
      heightInches: 6,
      weightPounds: 140,
      runsWithWaterBottle: false,
      unitSystem: UnitSystem.metric,
      createdAt: DateTime(2026, 9, 21),
      updatedAt: DateTime(2026, 9, 21),
      appVersion: '1.0.0',
    );

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

  group('Q-CA2 — running: form state does not outlive its activity', () {
    test('a manual temperature / humidity / title does not leak into the '
        'NEXT activity', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);

      // ── Activity A: the athlete overrides the environment and names the run.
      n.updateDistance(6.0);
      n.updateTemperature(31.0);
      n.updateHumidity(88.0);
      n.updateActivityTitle('Hill Repeats With Coach');

      var s = container.read(runningInputControllerProvider);
      expect(s.temperatureManuallySet, isTrue);
      expect(s.humidityManuallySet, isTrue);
      expect(s.activityTitleManuallySet, isTrue);

      // ── Activity B opens: the create flow resets form state for a NEW one.
      n.resetFormStateForNewActivity();

      s = container.read(runningInputControllerProvider);
      expect(
        s.temperatureManuallySet,
        isFalse,
        reason: 'a manual temperature belongs to the activity it was set on',
      );
      expect(
        s.humidityManuallySet,
        isFalse,
        reason: 'a manual humidity belongs to the activity it was set on',
      );
      expect(
        s.activityTitleManuallySet,
        isFalse,
        reason: "yesterday's activity name must not title tomorrow's",
      );
      expect(
        s.temperatureC,
        20.0,
        reason: 'the value returns to its auto source, not the stale 31',
      );
      expect(
        s.humidityPct,
        60.0,
        reason: 'the value returns to its auto source, not the stale 88',
      );
      expect(
        s.activityTitle,
        '6 mi Run',
        reason: 'the derived default is back; the old event name is gone',
      );
    });

    test('after the reset the title tracks distance again', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);

      n.updateActivityTitle('Sunday Long Run');
      n.updateDistance(8.0);
      expect(
        container.read(runningInputControllerProvider).activityTitle,
        'Sunday Long Run',
        reason: 'CF-1 — a manual title wins WITHIN the activity being edited',
      );

      n.resetFormStateForNewActivity();
      n.updateDistance(4.0);
      expect(
        container.read(runningInputControllerProvider).activityTitle,
        '4 mi Run',
        reason: 'the latched title flag no longer suppresses re-derivation',
      );
    });

    test('a manual change still persists WITHIN the activity being edited', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);

      n.resetFormStateForNewActivity();
      n.updateTemperature(31.0);
      n.updateHumidity(88.0);
      n.updateActivityTitle('Tempo');

      // Ordinary edits inside the same activity must not undo the overrides.
      n.updateDistance(10.0);
      n.updateDuration(const Duration(minutes: 80));

      final s = container.read(runningInputControllerProvider);
      expect(s.temperatureC, 31.0);
      expect(s.humidityPct, 88.0);
      expect(s.activityTitle, 'Tempo');
      expect(s.temperatureManuallySet, isTrue);
      expect(s.humidityManuallySet, isTrue);
      expect(s.activityTitleManuallySet, isTrue);
    });

    test('an explicit title seed applied after the reset still wins', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);

      // Editing an EXISTING activity: reset fires at entry, then the screen
      // re-hydrates from that activity. The hydration must survive.
      n.resetFormStateForNewActivity();
      n.seedActivityTitle('Boston Marathon', markManuallySet: true);

      final s = container.read(runningInputControllerProvider);
      expect(s.activityTitle, 'Boston Marathon');
      expect(s.activityTitleManuallySet, isTrue);
    });
  });

  group('Q-CA2 — cycling: form state does not outlive its activity', () {
    test('a manual temperature / humidity / title does not leak into the '
        'NEXT activity', () async {
      final container = makeContainer();
      final n = container.read(cyclingInputControllerProvider.notifier);
      await n.waitForPreferencesLoaded();

      n.updateDistance(20.0);
      n.updateTemperature(33.0);
      n.updateHumidity(90.0);
      n.updateActivityTitle('Gravel Grinder');

      var s = container.read(cyclingInputControllerProvider);
      expect(s.temperatureManuallySet, isTrue);
      expect(s.humidityManuallySet, isTrue);
      expect(s.activityTitleManuallySet, isTrue);

      n.resetFormStateForNewActivity();

      s = container.read(cyclingInputControllerProvider);
      expect(s.temperatureManuallySet, isFalse);
      expect(s.humidityManuallySet, isFalse);
      expect(s.activityTitleManuallySet, isFalse);
      expect(s.temperatureC, 20.0);
      expect(s.humidityPct, 60.0);
      expect(
        s.activityTitle,
        '20 mi Ride',
        reason: 'the derived default is back; the old ride name is gone',
      );
    });

    test('a manual change still persists WITHIN the activity being edited',
        () async {
      final container = makeContainer();
      final n = container.read(cyclingInputControllerProvider.notifier);
      await n.waitForPreferencesLoaded();

      n.resetFormStateForNewActivity();
      n.updateTemperature(33.0);
      n.updateActivityTitle('Gravel Grinder');
      n.updateDistance(42.0);

      final s = container.read(cyclingInputControllerProvider);
      expect(s.temperatureC, 33.0);
      expect(s.temperatureManuallySet, isTrue);
      expect(s.activityTitle, 'Gravel Grinder');
    });

    // The reset now fires at screen entry, BEFORE preferences land, and the
    // cycling title is derived in miles — so the preference load has to
    // re-derive it. A pinned title is still never touched.
    test('a metric preference load re-derives the unpinned title', () async {
      final repository = _MockUserRepository();
      when(repository.getCurrentUser).thenAnswer((_) async => _metricProfile());

      final container = ProviderContainer(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
          userRepositoryProvider.overrideWith((_) async => repository),
        ],
      );
      addTearDown(container.dispose);

      final n = container.read(cyclingInputControllerProvider.notifier);
      n.resetFormStateForNewActivity();
      await n.waitForPreferencesLoaded();

      final s = container.read(cyclingInputControllerProvider);
      expect(s.distanceUnit, DistanceUnit.kilometers);
      expect(
        s.activityTitle,
        ActivityTitleFormatter.formatCyclingTitle(s.distance * 0.621371),
        reason: 'the derived title follows the athlete\'s unit, not the '
            'pre-preferences default',
      );
      expect(s.activityTitleManuallySet, isFalse);
    });

    test('a metric preference load leaves a PINNED title alone', () async {
      final repository = _MockUserRepository();
      when(repository.getCurrentUser).thenAnswer((_) async => _metricProfile());

      final container = ProviderContainer(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
          userRepositoryProvider.overrideWith((_) async => repository),
        ],
      );
      addTearDown(container.dispose);

      final n = container.read(cyclingInputControllerProvider.notifier);
      n.updateActivityTitle('Alpe du Zwift');
      await n.waitForPreferencesLoaded();

      final s = container.read(cyclingInputControllerProvider);
      expect(s.activityTitle, 'Alpe du Zwift');
      expect(s.activityTitleManuallySet, isTrue);
    });
  });

  group('Q-CA2 — swimming: form state does not outlive its activity', () {
    test('a manual title does not leak into the NEXT activity', () {
      final container = makeContainer();
      final n = container.read(swimmingInputControllerProvider.notifier);

      n.updateDistance(1500);
      n.updateActivityTitle('Masters Set');
      expect(
        container.read(swimmingInputControllerProvider).activityTitleManuallySet,
        isTrue,
      );

      n.resetFormStateForNewActivity();

      final s = container.read(swimmingInputControllerProvider);
      expect(s.activityTitleManuallySet, isFalse);
      expect(s.activityTitle, '1500 m Swim');
    });

    test('a manual title still persists WITHIN the activity being edited', () {
      final container = makeContainer();
      final n = container.read(swimmingInputControllerProvider.notifier);

      n.resetFormStateForNewActivity();
      n.updateActivityTitle('Masters Set');
      n.updateDistance(2500);

      final s = container.read(swimmingInputControllerProvider);
      expect(s.activityTitle, 'Masters Set');
      expect(s.activityTitleManuallySet, isTrue);
    });
  });

  group('Q-CA2 — brick: form state does not outlive its activity', () {
    test('a manual title does not leak into the NEXT activity', () {
      final container = makeContainer();
      final n = container.read(brickInputControllerProvider.notifier);

      final derivedTitle = n.getBrickType();
      n.updateActivityTitle('Ironman Rehearsal');
      expect(
        container.read(brickInputControllerProvider).activityTitleManuallySet,
        isTrue,
      );

      n.resetFormStateForNewActivity();

      final s = container.read(brickInputControllerProvider);
      expect(s.activityTitleManuallySet, isFalse);
      expect(
        s.activityTitle,
        derivedTitle,
        reason: 'the leg-derived default is back',
      );
    });

    test('a manual title still persists WITHIN the activity being edited', () {
      final container = makeContainer();
      final n = container.read(brickInputControllerProvider.notifier);

      n.resetFormStateForNewActivity();
      n.updateActivityTitle('Ironman Rehearsal');
      n.reorderLegs(0, 1);

      final s = container.read(brickInputControllerProvider);
      expect(s.activityTitle, 'Ironman Rehearsal');
      expect(s.activityTitleManuallySet, isTrue);
    });
  });

  group('Q-CA2 — the window half stays reset by the same call', () {
    // One lifetime for ALL form state: widening the reset must not drop the
    // behaviour 7418566f shipped.
    test('running: the latched window flag is still cleared', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);

      n.updatePreRunMinutes(45);
      expect(
        container.read(runningInputControllerProvider).preRunMinutesManuallySet,
        isTrue,
      );

      n.resetFormStateForNewActivity();
      expect(
        container.read(runningInputControllerProvider).preRunMinutesManuallySet,
        isFalse,
      );
    });

    test('cycling / swimming / brick: the latched window flag is cleared',
        () async {
      final container = makeContainer();

      final cycling = container.read(cyclingInputControllerProvider.notifier);
      await cycling.waitForPreferencesLoaded();
      cycling.updatePreRideMinutes(45);
      cycling.resetFormStateForNewActivity();
      expect(
        container.read(cyclingInputControllerProvider).preRideMinutesManuallySet,
        isFalse,
      );

      final swimming = container.read(swimmingInputControllerProvider.notifier);
      swimming.updatePreSwimMinutes(45);
      swimming.resetFormStateForNewActivity();
      expect(
        container.read(swimmingInputControllerProvider).preSwimMinutesManuallySet,
        isFalse,
      );

      final brick = container.read(brickInputControllerProvider.notifier);
      brick.updatePreActivityMinutes(45);
      brick.resetFormStateForNewActivity();
      expect(
        container
            .read(brickInputControllerProvider)
            .preActivityMinutesManuallySet,
        isFalse,
      );
    });
  });
}
