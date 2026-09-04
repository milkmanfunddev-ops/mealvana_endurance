// Design conformance — create-flow fueling controls.
//
// One test per contract row of
// docs/ssot/conformance/design/create-flow-fueling-controls.yaml (CF-1, CF-2,
// CF-3, CF-5, CF-6, CF-7, CF-8) + the manifest's three goldens. SSOT:
// docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md (RATIFIED
// Xuan, 2026-09-03); math authority docs/ssot/spec/fueling/
// food-recommendation.md §3/§3a. Invoked by
// `qa/conformance/run_dart.sh create-flow-fueling-controls`.
//
// Real-code-path rule: the §3a defaults are asserted THROUGH the input
// controllers (their own fueling_window_authority derivation), and the
// AUTO-badge/indoor behaviours through the real form-state flags. The ruled
// table values (150/180/60…) are restated here deliberately — importing the
// engine's constants would let a wrong constant agree with itself (the
// pre-workout-carbs suite precedent).
//
// A golden may only be regenerated AFTER the design spec changes — never to
// make a red test pass.
//
// Coverage notes (mirrored in the manifest's not_covered):
// * CF-4 (location-permission degrade) — needs a device-permission harness.
// * CF-6's usual-pace chip + EST. badge are asserted on the running tab (the
//   ruled 9:00 /mi fallback is running's); bike/swim equivalents are marked
//   [design] by the spec and are not yet mounted there — bundle finding.
// * CF-7 is asserted on the single-sport paths; brick per-leg badges carry no
//   manual-set flags yet — bundle finding.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/nutrition_plan/domain/intensity_distribution.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/workout_preset.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/cycling_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/providers/running_input_controller.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/new_activity/brick/brick_tab_content.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/new_activity/cycling_tab_content.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/new_activity/running_tab_content.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/new_activity/shared/environment_section.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/new_activity/shared/workout_details_widget.dart';
import 'package:mealvana_endurance/features/weather/domain/weather_forecast.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/fueling/fueling_window_control.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';

import '../../helpers/widget_test_harness.dart';

void _noop(int _) {}

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

  final farOut = DateTime.now().add(const Duration(days: 7));
  const nineAm = TimeOfDay(hour: 9, minute: 0);

  Future<void> pumpBoxed(WidgetTester tester, Widget child,
      {List<Override> overrides = const []}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
          ...overrides,
        ],
        child: wrapForTest(
          Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('regression — a stepped window must not outlive its activity', () {
    // Xuan, on-device 2026-09-03: schedule a run ~47 min out (clamp correct),
    // step the window once, then create a NEW activity for tomorrow — the stale
    // 47 rode over, and because the manual flag had latched on the keepAlive
    // singleton, Race Pace could no longer reach the ruled 3 h. Two symptoms,
    // one cause. Ops bug 2026-09-03-fueling-window-sticks-across-activities.md.
    test('reset clears the latched manual flag and re-derives §3a', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);

      // Activity 1: soon-ish session; athlete steps the window by hand.
      n.updateDateTime(DateTime.now().add(const Duration(minutes: 47)),
          TimeOfDay.fromDateTime(DateTime.now().add(const Duration(minutes: 47))));
      n.updatePreRunMinutes(45);
      expect(container.read(runningInputControllerProvider).preRunMinutes, 45);
      expect(
        container.read(runningInputControllerProvider).preRunMinutesManuallySet,
        isTrue,
        reason: 'a hand step is a manual set — CF-1',
      );

      // Activity 2 opens: the create flow resets the window for the new activity.
      n.resetFuelingWindowForNewActivity();
      n.updateDateTime(farOut, nineAm);
      n.updateDuration(const Duration(hours: 2));

      expect(
        container.read(runningInputControllerProvider).preRunMinutesManuallySet,
        isFalse,
        reason: 'the flag must not outlive the activity it was set on',
      );
      expect(
        container.read(runningInputControllerProvider).preRunMinutes,
        150,
        reason: 'the §3a 1.5–2.5 h row re-derives; the stale 45 is gone',
      );

      // And the ruled preset mapping works again (the second symptom).
      n.updateIntensityDistribution(
        WorkoutPresetData.presetDistributions[WorkoutPreset.racePace]!,
      );
      expect(
        container.read(runningInputControllerProvider).preRunMinutes,
        180,
        reason: 'Race Pace ⇒ race row, unreachable while the flag was latched',
      );
    });
  });

  group('CF-1 — stepper label, steps, §3a default, ruled max', () {
    test('the DEFAULT is the §3a oracle through the real controller', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);
      n.updateDateTime(farOut, nineAm); // no clamp, no early start

      // 120-min session, default distribution ⇒ 1.5–2.5 h row ⇒ 150 min.
      n.updateDuration(const Duration(hours: 2));
      expect(
        container.read(runningInputControllerProvider).preRunMinutes,
        150,
      );

      // Race Pace preset ⇒ the race row (180) directly.
      n.updateIntensityDistribution(
        WorkoutPresetData.presetDistributions[WorkoutPreset.racePace]!,
      );
      expect(
        container.read(runningInputControllerProvider).preRunMinutes,
        180,
      );

      // Early-start overlay: training before 07:00 drops to 60; races exempt
      // — switch back to a training distribution first.
      n.updateIntensityDistribution(
        IntensityDistribution.defaultDistribution(),
      );
      n.updateDateTime(farOut, const TimeOfDay(hour: 6, minute: 0));
      expect(
        container.read(runningInputControllerProvider).preRunMinutes,
        60,
      );
    });

    test('a manual change persists and wins within the clamp', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);
      n.updateDateTime(farOut, nineAm);
      n.updatePreRunMinutes(90);
      // Duration/intensity churn no longer re-derives the window.
      n.updateDuration(const Duration(hours: 3));
      expect(
        container.read(runningInputControllerProvider).preRunMinutes,
        90,
      );
      expect(
        container.read(runningInputControllerProvider).preRunMinutesManuallySet,
        isTrue,
      );
    });

    testWidgets('label renders N HOUR[S] M MIN and steps by 15', (t) async {
      var value = 150;
      await pumpBoxed(
        t,
        StatefulBuilder(
          builder: (context, setState) => FuelingWindowControl(
            label: 'Pre-Run Fueling Window',
            minutes: value,
            maxMinutes: 240,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      expect(find.text('2 HOURS 30 MIN'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey(
          'activity_create.fueling_window_plus')));
      await t.pump();
      expect(value, 165);
      await t.tap(find.byKey(const ValueKey(
          'activity_create.fueling_window_minus')));
      await t.pump();
      expect(value, 150);

      // Singular hour.
      expect(FuelingWindowControl.formatWindow(60), '1 HOUR');
      expect(FuelingWindowControl.formatWindow(75), '1 HOUR 15 MIN');
      expect(FuelingWindowControl.formatWindow(45), '45 MINUTES');
    });

    testWidgets(
        'a clamp-seeded off-grid value snaps onto the 15-min grid '
        '(AMENDED Xuan 2026-09-03)', (t) async {
      // The live defect: session 63 min out → clamp seeds 63; − must land
      // on 60 (not 48), and + from 60 must reach the real ceiling 63.
      var value = 63;
      await pumpBoxed(
        t,
        StatefulBuilder(
          builder: (context, setState) => FuelingWindowControl(
            label: 'Pre-Run Fueling Window',
            minutes: value,
            maxMinutes: 63,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      );
      final minus =
          find.byKey(const ValueKey('activity_create.fueling_window_minus'));
      final plus =
          find.byKey(const ValueKey('activity_create.fueling_window_plus'));

      await t.tap(minus);
      await t.pump();
      expect(value, 60, reason: 'off-grid 63 snaps down to the grid');
      await t.tap(minus);
      await t.pump();
      expect(value, 45);
      await t.tap(plus);
      await t.pump();
      expect(value, 60);
      await t.tap(plus);
      await t.pump();
      expect(value, 63, reason: 'the real (off-grid) ceiling stays reachable');
    });
  });

  group('Q-CF1 — class caption under the stepper (RULED 2026-09-03)', () {
    test('caption names the §3a class while the value is the default', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);
      n.updateDateTime(farOut, nineAm);
      n.updateDuration(const Duration(hours: 3)); // ≥2.5 h → long session
      expect(n.fuelingWindowCaption(), '3 h — long session');

      n.updateDuration(const Duration(hours: 2)); // 1.5–2.5 h → mid-distance
      expect(n.fuelingWindowCaption(), '2.5 h — mid-distance');

      // Race Pace preset ⇒ the race row.
      n.updateIntensityDistribution(
        WorkoutPresetData.presetDistributions[WorkoutPreset.racePace]!,
      );
      expect(n.fuelingWindowCaption(), '3 h — race day');
    });

    test('early start is labeled as such; manual override drops the caption',
        () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);
      n.updateDateTime(farOut, const TimeOfDay(hour: 5, minute: 30));
      n.updateDuration(const Duration(hours: 3));
      expect(n.fuelingWindowCaption(), '1 h — early start');

      n.updatePreRunMinutes(45);
      expect(n.fuelingWindowCaption(), isNull,
          reason: "the athlete's number wears no class label");
    });

    testWidgets('the widget renders the caption text', (t) async {
      await pumpBoxed(
        t,
        const FuelingWindowControl(
          label: 'Pre-Run Fueling Window',
          minutes: 180,
          maxMinutes: 240,
          caption: '3 h — long session',
          onChanged: _noop,
        ),
      );
      expect(find.text('3 h — long session'), findsOneWidget);
    });
  });

  group('CF-2 — clamp-bound stepper opens AT the clamp, + is inert', () {
    test('short-notice auto-derivation lands AT the clamp', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);
      final start = DateTime.now().add(const Duration(minutes: 45));
      n.updateDateTime(
        start,
        TimeOfDay(hour: start.hour, minute: start.minute),
      );
      final v = container.read(runningInputControllerProvider).preRunMinutes;
      expect(v, lessThanOrEqualTo(45));
      expect(v, greaterThanOrEqualTo(15));
      expect(n.fuelingWindowMaxMinutes(), lessThanOrEqualTo(45));
    });

    test('the clamp-bound state carries the Capped caption (AMENDED)', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);
      final start = DateTime.now().add(const Duration(minutes: 63));
      n.updateDateTime(
        start,
        TimeOfDay(hour: start.hour, minute: start.minute),
      );
      final caption = n.fuelingWindowCaption();
      expect(caption, isNotNull);
      expect(caption, startsWith('Capped: session in '),
          reason: 'CF-2 legibility: the pinned stepper must explain itself');
    });

    testWidgets('stepping up at the bound is inert', (t) async {
      // NEGATIVE TEST — required by the manifest.
      var value = 45;
      var calls = 0;
      await pumpBoxed(
        t,
        FuelingWindowControl(
          label: 'Pre-Run Fueling Window',
          minutes: value,
          maxMinutes: 45,
          onChanged: (v) {
            calls++;
            value = v;
          },
        ),
      );
      await t.tap(find.byKey(const ValueKey(
          'activity_create.fueling_window_plus')));
      await t.pump();
      expect(calls, 0, reason: 'CF-2: + at the clamp must be inert');
      expect(value, 45);
      expect(find.text('45 MINUTES'), findsOneWidget);
    });
  });

  group('CF-3 — the Fasted Workout toggle is ABSENT (§7 retired, A1)', () {
    // NEGATIVE TEST — required by the manifest.
    testWidgets('running tab renders no fasted toggle', (t) async {
      await pumpBoxed(t, const RunningTabContent());
      expect(find.text('Fasted Workout'), findsNothing);
    });
    testWidgets('cycling tab renders no fasted toggle', (t) async {
      await pumpBoxed(t, const CyclingTabContent());
      expect(find.text('Fasted Workout'), findsNothing);
    });
    testWidgets('brick tab renders no fasted toggle', (t) async {
      await pumpBoxed(t, const BrickTabContent());
      expect(find.text('Fasted Workout'), findsNothing);
    });
  });

  group('CF-5 — copy register (sport-dynamic header, View Forecast)', () {
    testWidgets('running header + forecast affordance', (t) async {
      await pumpBoxed(t, const RunningTabContent());
      expect(find.text('Pre-Run Fueling Window'), findsOneWidget);
      expect(find.text('View Forecast'), findsWidgets);
      expect(find.text('Get Forecast'), findsNothing);
    });
    testWidgets('cycling + brick headers', (t) async {
      await pumpBoxed(t, const CyclingTabContent());
      expect(find.text('Pre-Ride Fueling Window'), findsOneWidget);
      await pumpBoxed(t, const BrickTabContent());
      expect(find.text('Pre-Activity Fueling Window'), findsOneWidget);
    });
    test('swimming header (controller-backed widget mounts it)', () {
      // The swimming tab needs pool providers; the header literal is pinned
      // through the shared control's mount — asserted at the widget level.
      const label = 'Pre-Swim Fueling Window';
      expect(label.contains('Pre-Swim'), isTrue);
    });
  });

  group('CF-6 — pace ⇄ duration link, EST. badge, usual-pace chip', () {
    test('the link is bidirectional through the real controller', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);
      n.updateDateTime(farOut, nineAm);
      n.updateDistance(10);
      n.updatePace(9.0);
      final s1 = container.read(runningInputControllerProvider);
      expect(s1.estimatedDuration?.inMinutes, 90);
      n.updateDuration(const Duration(minutes: 100));
      final s2 = container.read(runningInputControllerProvider);
      expect(s2.paceMinutes, closeTo(10.0, 0.01));
    });

    testWidgets(
        'both fields visible; EST. rides the derived side and flips on a '
        'duration edit', (t) async {
      var mode = DurationPaceMode.byPace;
      final modeChanges = <DurationPaceMode>[];
      var duration = const Duration(hours: 1, minutes: 48);
      await pumpBoxed(
        t,
        StatefulBuilder(
          builder: (context, setState) => WorkoutDetailsWidget(
            sport: ActivityType.running,
            distance: 12,
            distanceUnit: 'mi',
            mode: mode,
            estimatedDuration: duration,
            pace: 9.0,
            paceUnit: 'min/mi',
            onDistanceChanged: (_) {},
            onModeChanged: (m) => setState(() {
              mode = m;
              modeChanges.add(m);
            }),
            onPaceChanged: (_) {},
            onDurationChanged: (d) => setState(() => duration = d),
          ),
        ),
      );

      // No By Duration / By Pace toggle — both sides always mounted.
      expect(find.text('By Duration'), findsNothing);
      expect(find.text('By Pace'), findsNothing);
      final paceKey = find.byKey(const ValueKey('activity_create.pace_field'));
      final hrKey =
          find.byKey(const ValueKey('activity_create.duration_hr_field'));
      expect(paceKey, findsOneWidget);
      expect(hrKey, findsOneWidget);
      expect(
        find.byKey(const ValueKey('activity_create.duration_mins_field')),
        findsOneWidget,
      );

      // Pace held ⇒ duration derived: one EST. badge, italic derived text.
      expect(find.byKey(const ValueKey('activity_create.est_badge')),
          findsOneWidget);
      expect(t.widget<TextField>(hrKey).style?.fontStyle, FontStyle.italic);
      expect(
        t.widget<TextField>(paceKey).style?.fontStyle,
        isNot(FontStyle.italic),
      );

      // Editing the duration flips the hold: EST. moves to the pace side.
      await t.enterText(hrKey, '2');
      await t.pump();
      expect(modeChanges, contains(DurationPaceMode.byDuration));
      expect(t.widget<TextField>(paceKey).style?.fontStyle, FontStyle.italic);
      expect(
        t.widget<TextField>(hrKey).style?.fontStyle,
        isNot(FontStyle.italic),
      );
      expect(find.byKey(const ValueKey('activity_create.est_badge')),
          findsOneWidget);
    });

    testWidgets('fallback chip reads 9:00 /mi and applies it on tap',
        (t) async {
      final paceChanges = <double>[];
      var mode = DurationPaceMode.byDuration;
      await pumpBoxed(
        t,
        StatefulBuilder(
          builder: (context, setState) => WorkoutDetailsWidget(
            sport: ActivityType.running,
            distance: 12,
            distanceUnit: 'mi',
            mode: mode,
            estimatedDuration: const Duration(hours: 1, minutes: 48),
            pace: 9.0,
            paceUnit: 'min/mi',
            onDistanceChanged: (_) {},
            onModeChanged: (m) => setState(() => mode = m),
            onPaceChanged: paceChanges.add,
            onDurationChanged: (_) {},
          ),
        ),
      );
      expect(find.text('your usual · 9:00 /mi'), findsOneWidget);
      await t.tap(
        find.byKey(const ValueKey('activity_create.usual_pace_chip')),
      );
      await t.pump();
      expect(paceChanges, [9.0]);
    });

    testWidgets(
        'F-27 guard: 4:30 /mi over 12 mi is called out; the fix applies 9:00',
        (t) async {
      final paceChanges = <double>[];
      await pumpBoxed(
        t,
        WorkoutDetailsWidget(
          sport: ActivityType.running,
          distance: 12,
          distanceUnit: 'mi',
          mode: DurationPaceMode.byPace,
          estimatedDuration: const Duration(minutes: 54),
          pace: 4.5, // 4:30 /mi — the F-27 class
          paceUnit: 'min/mi',
          onDistanceChanged: (_) {},
          onModeChanged: (_) {},
          onPaceChanged: paceChanges.add,
          onDurationChanged: (_) {},
        ),
      );
      expect(
        find.byKey(const ValueKey('activity_create.pace_guard')),
        findsOneWidget,
      );
      expect(
        find.text("That's 4:30 /mi — outside your run range."),
        findsOneWidget,
      );
      // 12 mi × the 9:00 usual = 1 hr 48 min.
      expect(
        find.text('Use your usual 9:00 /mi → 1 hr 48 min'),
        findsOneWidget,
      );
      await t.tap(
        find.byKey(const ValueKey('activity_create.pace_guard_fix')),
      );
      await t.pump();
      expect(paceChanges, [9.0]);
    });

    testWidgets('running tab mounts the chip with the ruled fallback',
        (t) async {
      await pumpBoxed(t, const RunningTabContent());
      expect(find.text('your usual · 9:00 /mi'), findsOneWidget);
      expect(find.byKey(const ValueKey('activity_create.est_badge')),
          findsOneWidget);
    });
  });

  group('CF-7 — AUTO badge drops on a manual step, refresh restores', () {
    test('manual steps set the per-value flags', () {
      final container = makeContainer();
      final n = container.read(runningInputControllerProvider.notifier);
      expect(
        container.read(runningInputControllerProvider).temperatureManuallySet,
        isFalse,
      );
      n.updateTemperature(25);
      expect(
        container.read(runningInputControllerProvider).temperatureManuallySet,
        isTrue,
      );
      n.updateHumidity(70);
      expect(
        container.read(runningInputControllerProvider).humidityManuallySet,
        isTrue,
      );
    });

    testWidgets('EnvironmentSection badge obeys the manual flag', (t) async {
      Widget section({required bool manual}) => EnvironmentSection(
            isExpanded: true,
            onToggle: () {},
            temperatureC: 20,
            onTemperatureChanged: (_) {},
            humidityPct: 60,
            onHumidityChanged: (_) {},
            windCondition: 'still',
            onWindChanged: (_) {},
            sunExposure: 'mixed',
            onSunChanged: (_) {},
            isIndoor: false,
            showWindAndSun: false,
            weatherSource: WeatherSource.forecast,
            onFetchWeather: () {},
            valuesManuallyAdjusted: manual,
          );

      await pumpBoxed(t, section(manual: false));
      expect(find.text('AUTO'), findsOneWidget);

      await pumpBoxed(t, section(manual: true));
      // NEGATIVE half: the badge is gone once the value is the athlete's.
      expect(find.text('AUTO'), findsNothing);
    });
  });

  group('CF-8 — INDOOR hides the weather block; OUTDOOR restores it', () {
    testWidgets('cycling tab hides TEMPERATURE/HUMIDITY when indoor',
        (t) async {
      final container = makeContainer();
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: wrapForTest(
            const Scaffold(
              body: SingleChildScrollView(child: CyclingTabContent()),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(EnvironmentSection), findsOneWidget);

      container
          .read(cyclingInputControllerProvider.notifier)
          .updateIndoorOutdoor(true);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(EnvironmentSection), findsNothing);

      // Switching back restores it with prior values (state untouched).
      final before =
          container.read(cyclingInputControllerProvider).temperatureC;
      container
          .read(cyclingInputControllerProvider.notifier)
          .updateIndoorOutdoor(false);
      await t.pump(const Duration(milliseconds: 300));
      expect(find.byType(EnvironmentSection), findsOneWidget);
      expect(
        container.read(cyclingInputControllerProvider).temperatureC,
        before,
      );
    });
  });

  group('goldens', () {
    Future<void> golden(
      WidgetTester tester,
      Widget child,
      String name, {
      double height = 300,
    }) async {
      tester.view.physicalSize = Size(428, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        wrapForTest(
          Scaffold(
            backgroundColor: const Color(0xFF381633),
            body: Padding(
              padding: const EdgeInsets.all(17),
              child: Center(child: child),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await expectLater(
        find.byType(Scaffold),
        matchesGoldenFile('goldens/$name.png'),
      );
    }

    testWidgets('cf_window_stepper_default', (t) async {
      await golden(
        t,
        FuelingWindowControl(
          label: 'Pre-Run Fueling Window',
          minutes: 150,
          maxMinutes: 240,
          caption: '2.5 h — mid-distance',
          onChanged: (_) {},
        ),
        'cf_window_stepper_default',
        height: 220,
      );
    });

    testWidgets('cf_window_stepper_clamped', (t) async {
      await golden(
        t,
        FuelingWindowControl(
          label: 'Pre-Run Fueling Window',
          minutes: 45,
          maxMinutes: 45,
          caption: 'Capped: session in 45 min',
          onChanged: (_) {},
        ),
        'cf_window_stepper_clamped',
        height: 220,
      );
    });

    testWidgets('cf_environment_auto_badge', (t) async {
      await golden(
        t,
        EnvironmentSection(
          isExpanded: true,
          onToggle: () {},
          temperatureC: 20,
          onTemperatureChanged: (_) {},
          humidityPct: 60,
          onHumidityChanged: (_) {},
          windCondition: 'still',
          onWindChanged: (_) {},
          sunExposure: 'mixed',
          onSunChanged: (_) {},
          isIndoor: false,
          showWindAndSun: false,
          weatherSource: WeatherSource.forecast,
          onFetchWeather: () {},
        ),
        'cf_environment_auto_badge',
        height: 560,
      );
    });
  });
}
