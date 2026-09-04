// WorkoutDetailsWidget — the CF-6 dual-field pace ⇄ duration block.
// SSOT: docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md (CF-6),
// reference rendering prototypes/create-activity-plan/v1.html. There is no
// By Duration / By Pace toggle: both fields are always visible, the side last
// edited is HELD and the other DERIVED (EST. badge, italic, dashed border).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/new_activity/shared/workout_details_widget.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';

void main() {
  final paceField = find.byKey(const ValueKey('activity_create.pace_field'));
  final hrField =
      find.byKey(const ValueKey('activity_create.duration_hr_field'));
  final minField =
      find.byKey(const ValueKey('activity_create.duration_mins_field'));

  Widget build({
    ActivityType sport = ActivityType.running,
    double distance = 12.0,
    String distanceUnit = 'mi',
    DurationPaceMode mode = DurationPaceMode.byPace,
    Duration? estimatedDuration = const Duration(hours: 1, minutes: 48),
    double? pace = 9.0,
    String paceUnit = 'min/mi',
    double? usualPace,
    bool enabled = true,
    ValueChanged<double>? onDistanceChanged,
    ValueChanged<DurationPaceMode>? onModeChanged,
    ValueChanged<double>? onPaceChanged,
    ValueChanged<Duration>? onDurationChanged,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: WorkoutDetailsWidget(
            sport: sport,
            distance: distance,
            distanceUnit: distanceUnit,
            mode: mode,
            estimatedDuration: estimatedDuration,
            pace: pace,
            paceUnit: paceUnit,
            usualPace: usualPace,
            enabled: enabled,
            onDistanceChanged: onDistanceChanged ?? (_) {},
            onModeChanged: onModeChanged ?? (_) {},
            onPaceChanged: onPaceChanged ?? (_) {},
            onDurationChanged: onDurationChanged ?? (_) {},
          ),
        ),
      ),
    );
  }

  group('WorkoutDetailsWidget', () {
    testWidgets('renders heading, distance and both linked fields', (
      tester,
    ) async {
      await tester.pumpWidget(build());

      expect(find.text('WORKOUT DETAILS'), findsOneWidget);
      expect(_findRichText('Distance *'), findsOneWidget);
      expect(find.widgetWithText(TextField, '12.0'), findsOneWidget);
      expect(find.text('mi'), findsOneWidget);

      // Both halves are always mounted — no By Duration / By Pace toggle.
      expect(find.text('By Duration'), findsNothing);
      expect(find.text('By Pace'), findsNothing);
      expect(find.text('Avg Pace'), findsOneWidget);
      expect(find.text('Duration'), findsOneWidget);
      expect(paceField, findsOneWidget);
      expect(hrField, findsOneWidget);
      expect(minField, findsOneWidget);

      // Run pace renders M:SS; duration splits into hr/min.
      expect(tester.widget<TextField>(paceField).controller?.text, '9:00');
      expect(tester.widget<TextField>(hrField).controller?.text, '1');
      expect(tester.widget<TextField>(minField).controller?.text, '48');
    });

    testWidgets('cycling shows Avg Speed with a decimal value and mph', (
      tester,
    ) async {
      await tester.pumpWidget(build(
        sport: ActivityType.cycling,
        distance: 40,
        mode: DurationPaceMode.byPace,
        pace: 18.5,
        paceUnit: 'mph',
      ));

      expect(find.text('Avg Speed'), findsOneWidget);
      expect(tester.widget<TextField>(paceField).controller?.text, '18.5');
      expect(find.text('mph'), findsOneWidget);
    });

    testWidgets('swimming shows M:SS pace with the /100m unit', (
      tester,
    ) async {
      await tester.pumpWidget(build(
        sport: ActivityType.swimming,
        distance: 3000,
        distanceUnit: 'meters',
        pace: 1.75,
        paceUnit: 'min/100m',
      ));

      expect(find.text('Avg Pace'), findsOneWidget);
      expect(tester.widget<TextField>(paceField).controller?.text, '1:45');
      expect(find.text('/100m'), findsOneWidget);
    });

    testWidgets('the derived side wears EST. + italic; the held side the pin', (
      tester,
    ) async {
      // Pace held ⇒ duration derived.
      await tester.pumpWidget(build(mode: DurationPaceMode.byPace));
      expect(find.byKey(const ValueKey('activity_create.est_badge')),
          findsOneWidget);
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
      expect(
        tester.widget<TextField>(hrField).style?.fontStyle,
        FontStyle.italic,
      );
      expect(
        tester.widget<TextField>(paceField).style?.fontStyle,
        isNot(FontStyle.italic),
      );

      // Duration held ⇒ pace derived.
      await tester.pumpWidget(build(mode: DurationPaceMode.byDuration));
      expect(find.byKey(const ValueKey('activity_create.est_badge')),
          findsOneWidget);
      expect(
        tester.widget<TextField>(paceField).style?.fontStyle,
        FontStyle.italic,
      );
    });

    testWidgets('editing pace reports parsed M:SS minutes', (tester) async {
      double? changedPace;
      await tester.pumpWidget(build(
        onPaceChanged: (v) => changedPace = v,
      ));

      await tester.enterText(paceField, '8:30');
      await tester.pump();
      expect(changedPace, closeTo(8.5, 0.01));
    });

    testWidgets(
        'pace field formats bare digits into M:SS and commits the pace '
        '(numeric keypad has no colon — bug 2026-09-04)', (tester) async {
      final paceChanges = <double>[];
      await tester.pumpWidget(build(
        onPaceChanged: paceChanges.add,
      ));

      // The mm:ss field must NOT ask for the decimal pad — plain digits.
      expect(
        tester.widget<TextField>(paceField).keyboardType,
        TextInputType.number,
      );

      // Keystroke by keystroke: 9 → 93 → 930 renders "9:30".
      await tester.enterText(paceField, '9');
      await tester.enterText(paceField, '93');
      await tester.enterText(paceField, '930');
      await tester.pump();
      expect(tester.widget<TextField>(paceField).controller?.text, '9:30');
      expect(paceChanges.last, closeTo(9.5, 0.01));

      // Four digits split as MM:SS.
      await tester.enterText(paceField, '1045');
      await tester.pump();
      expect(tester.widget<TextField>(paceField).controller?.text, '10:45');
      expect(paceChanges.last, closeTo(10.75, 0.01));
    });

    testWidgets('swim pace field shares the colon-free digit entry', (
      tester,
    ) async {
      final paceChanges = <double>[];
      await tester.pumpWidget(build(
        sport: ActivityType.swimming,
        distance: 3000,
        distanceUnit: 'meters',
        pace: null,
        paceUnit: 'min/100m',
        onPaceChanged: paceChanges.add,
      ));

      expect(
        tester.widget<TextField>(paceField).keyboardType,
        TextInputType.number,
      );
      await tester.enterText(paceField, '145');
      await tester.pump();
      expect(tester.widget<TextField>(paceField).controller?.text, '1:45');
      expect(paceChanges.last, closeTo(1.75, 0.01));
    });

    testWidgets('cycling speed field accepts decimal input', (tester) async {
      double? changedPace;
      await tester.pumpWidget(build(
        sport: ActivityType.cycling,
        pace: 18.5,
        paceUnit: 'mph',
        onPaceChanged: (v) => changedPace = v,
      ));

      await tester.enterText(paceField, '20.0');
      await tester.pump();
      expect(changedPace, 20.0);
    });

    testWidgets('editing hr/min reports the duration', (tester) async {
      Duration? changed;
      await tester.pumpWidget(build(
        mode: DurationPaceMode.byDuration,
        onDurationChanged: (d) => changed = d,
      ));

      await tester.enterText(hrField, '2');
      await tester.pump();
      expect(changed, const Duration(hours: 2, minutes: 48));
    });

    testWidgets('editing a derived field flips the hold to that side', (
      tester,
    ) async {
      final modeChanges = <DurationPaceMode>[];

      // Pace held: touching the duration side must report byDuration.
      await tester.pumpWidget(build(
        mode: DurationPaceMode.byPace,
        onModeChanged: modeChanges.add,
      ));
      await tester.enterText(hrField, '2');
      await tester.pump();
      expect(modeChanges, contains(DurationPaceMode.byDuration));

      // Duration held: touching the pace side must report byPace.
      modeChanges.clear();
      await tester.pumpWidget(build(
        mode: DurationPaceMode.byDuration,
        onModeChanged: modeChanges.add,
      ));
      await tester.enterText(paceField, '8:00');
      await tester.pump();
      expect(modeChanges, contains(DurationPaceMode.byPace));
    });

    testWidgets('invalid pace text (seconds ≥ 60) reports nothing', (
      tester,
    ) async {
      double? changedPace;
      await tester.pumpWidget(build(
        onPaceChanged: (v) => changedPace = v,
      ));

      await tester.enterText(paceField, '8:75');
      await tester.pump();
      expect(changedPace, isNull);
    });

    testWidgets('null pace and duration show hints', (tester) async {
      await tester.pumpWidget(build(pace: null, estimatedDuration: null));

      expect(tester.widget<TextField>(paceField).controller?.text, isEmpty);
      expect(
        tester.widget<TextField>(paceField).decoration?.hintText,
        '0:00',
      );
      expect(tester.widget<TextField>(hrField).controller?.text, isEmpty);
      expect(tester.widget<TextField>(hrField).decoration?.hintText, '0');
      expect(tester.widget<TextField>(minField).decoration?.hintText, '00');
    });

    testWidgets('usual-pace chip renders the sport fallback and applies it', (
      tester,
    ) async {
      final paceChanges = <double>[];
      await tester.pumpWidget(build(
        mode: DurationPaceMode.byDuration,
        onPaceChanged: paceChanges.add,
      ));

      expect(find.text('your usual · 9:00 /mi'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('activity_create.usual_pace_chip')),
      );
      await tester.pump();
      expect(paceChanges, [9.0]);
    });

    testWidgets(
        'tapping the chip TEXT (not the pencil) applies the usual pace, '
        'and the tap target is at least 44px tall (bug 2026-09-04)', (
      tester,
    ) async {
      final paceChanges = <double>[];
      await tester.pumpWidget(build(
        mode: DurationPaceMode.byDuration,
        onPaceChanged: paceChanges.add,
      ));

      // Tap dead-center on the label text — nowhere near the pencil icon.
      await tester.tap(find.text('your usual · 9:00 /mi'));
      await tester.pump();
      expect(paceChanges, [9.0]);

      // The gesture surface, not the ~21px pill, defines the hit target.
      final chipSize = tester.getSize(
        find.byKey(const ValueKey('activity_create.usual_pace_chip')),
      );
      expect(chipSize.height, greaterThanOrEqualTo(44));
    });

    testWidgets(
        'applying the chip while the pace field is FOCUSED updates the '
        'visible text, not just the committed value (bug 2026-09-04: field '
        'kept showing 7:45 after the chip set 9:00)', (tester) async {
      // Stateful harness: the parent feeds committed pace back in, exactly
      // like the real screen.
      double pace = 9.0;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WorkoutDetailsWidget(
                sport: ActivityType.running,
                distance: 12.0,
                distanceUnit: 'mi',
                mode: DurationPaceMode.byPace,
                estimatedDuration: const Duration(hours: 1, minutes: 48),
                pace: pace,
                paceUnit: 'min/mi',
                enabled: true,
                onDistanceChanged: (_) {},
                onModeChanged: (_) {},
                onPaceChanged: (v) => setState(() => pace = v),
                onDurationChanged: (_) {},
              ),
            ),
          ),
        ),
      ));

      // Type a pace — field is focused and stays focused.
      await tester.enterText(paceField, '745');
      await tester.pump();
      expect(tester.widget<TextField>(paceField).controller?.text, '7:45');
      expect(pace, closeTo(7.75, 0.01));

      // Chip applies the usual pace while focus is still on the field.
      await tester.tap(find.text('your usual · 9:00 /mi'));
      await tester.pump();
      expect(pace, 9.0);
      expect(
        tester.widget<TextField>(paceField).controller?.text,
        '9:00',
        reason: 'the display must follow an external set even when focused',
      );

      // And live typing is still not clobbered: "8" commits 8.0 but the
      // text must stay "8" mid-entry, not snap to "8:00".
      await tester.enterText(paceField, '8');
      await tester.pump();
      expect(pace, 8.0);
      expect(tester.widget<TextField>(paceField).controller?.text, '8');
    });

    testWidgets('a saved usualPace overrides the sport base', (tester) async {
      await tester.pumpWidget(build(usualPace: 8.25));
      expect(find.text('your usual · 8:15 /mi'), findsOneWidget);
    });

    testWidgets('no guard within the sport band', (tester) async {
      await tester.pumpWidget(build(pace: 9.0));
      expect(
        find.byKey(const ValueKey('activity_create.pace_guard')),
        findsNothing,
      );
    });

    testWidgets('guard fires outside the band and the fix applies the usual', (
      tester,
    ) async {
      final paceChanges = <double>[];
      await tester.pumpWidget(build(
        pace: 4.5, // 4:30 /mi — the ruled F-27 class
        onPaceChanged: paceChanges.add,
      ));

      expect(
        find.byKey(const ValueKey('activity_create.pace_guard')),
        findsOneWidget,
      );
      expect(
        find.text("That's 4:30 /mi — outside your run range."),
        findsOneWidget,
      );
      expect(
        find.text('Use your usual 9:00 /mi → 1 hr 48 min'),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('activity_create.pace_guard_fix')),
      );
      await tester.pump();
      expect(paceChanges, [9.0]);
    });

    testWidgets('cycling guard uses the speed band', (tester) async {
      await tester.pumpWidget(build(
        sport: ActivityType.cycling,
        distance: 40,
        pace: 35.0, // ≥ 30 mph — outside the ride band
        paceUnit: 'mph',
      ));
      expect(
        find.byKey(const ValueKey('activity_create.pace_guard')),
        findsOneWidget,
      );
      expect(find.textContaining('outside your ride range'), findsOneWidget);
    });

    testWidgets('respects enabled parameter', (tester) async {
      await tester.pumpWidget(build(enabled: false));

      expect(tester.widget<TextField>(paceField).enabled, false);
      expect(tester.widget<TextField>(hrField).enabled, false);
      final distanceField = find.widgetWithText(TextField, '12.0');
      expect(tester.widget<TextField>(distanceField).enabled, false);
    });

    testWidgets('calls onDistanceChanged when distance is edited', (
      tester,
    ) async {
      double? changedValue;
      await tester.pumpWidget(build(
        distance: 18.0,
        onDistanceChanged: (v) => changedValue = v,
      ));

      final distanceField = find.widgetWithText(TextField, '18.0');
      await tester.enterText(distanceField, '20.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(changedValue, 20.5);
    });

    testWidgets('uses the provided distance unit', (tester) async {
      await tester.pumpWidget(build(
        distance: 10.0,
        distanceUnit: 'km',
        paceUnit: 'min/km',
      ));
      expect(find.text('km'), findsOneWidget);
      expect(find.text('/km'), findsOneWidget);
    });
  });
}

/// Finds a [RichText] whose concatenated spans equal [text]. The distance
/// label is rendered with a styled asterisk via TextSpans, so it can't be
/// matched with the plain-text finder.
Finder _findRichText(String text) {
  return find.byWidgetPredicate((widget) {
    if (widget is RichText) {
      return widget.text.toPlainText() == text;
    }
    return false;
  });
}
