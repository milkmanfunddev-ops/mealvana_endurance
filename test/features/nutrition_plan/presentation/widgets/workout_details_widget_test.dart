import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/new_activity/shared/workout_details_widget.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';

void main() {
  group('WorkoutDetailsWidget', () {
    testWidgets('renders with all required elements', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 18.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: const Duration(hours: 2, minutes: 38),
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // Section title
      expect(find.text('WORKOUT DETAILS'), findsOneWidget);

      // Distance label (rendered via RichText: "Distance " + "*") and value.
      expect(_findRichText('Distance *'), findsOneWidget);
      expect(find.widgetWithText(TextField, '18.0'), findsOneWidget);
      expect(find.text('mi'), findsOneWidget);

      // Toggle buttons
      expect(find.text('By Duration'), findsOneWidget);
      expect(find.text('By Pace'), findsOneWidget);

      // Estimated Duration uses split hr/mins fields (2h 38m).
      expect(find.text('Estimated Duration'), findsOneWidget);
      expect(find.widgetWithText(TextField, '2'), findsOneWidget); // hours
      expect(find.widgetWithText(TextField, '38'), findsOneWidget); // minutes
    });

    testWidgets('shows Average Speed for cycling in By Pace mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.cycling,
              distance: 40.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byPace,
              estimatedDuration: null,
              pace: 18.5,
              paceUnit: 'mph',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // Should show "Average Speed" for cycling
      expect(find.text('Average Speed'), findsOneWidget);
      expect(find.text('18.5'), findsOneWidget);
      expect(find.text('mph'), findsOneWidget);
    });

    testWidgets('shows Average Pace for running in By Pace mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 13.1,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byPace,
              estimatedDuration: null,
              pace: 8.5,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // Should show "Average Pace" for running, split into min/sec fields
      // (8.5 min = 8 min 30 sec) with the unit shown as "(min/mi)".
      expect(find.text('Average Pace'), findsOneWidget);
      expect(find.widgetWithText(TextField, '8'), findsOneWidget); // minutes
      expect(find.widgetWithText(TextField, '30'), findsOneWidget); // seconds
      expect(find.text('(min/mi)'), findsOneWidget);
    });

    testWidgets('shows Average Pace for swimming in By Pace mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.swimming,
              distance: 3000,
              distanceUnit: 'm',
              mode: DurationPaceMode.byPace,
              estimatedDuration: null,
              pace: 1.75,
              paceUnit: 'min/100m',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // Should show "Average Pace" for swimming, split into min/sec fields
      // (1.75 min = 1 min 45 sec) with the unit shown as "(min/100m)".
      expect(find.text('Average Pace'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1'), findsOneWidget); // minutes
      expect(find.widgetWithText(TextField, '45'), findsOneWidget); // seconds
      expect(find.text('(min/100m)'), findsOneWidget);
    });

    testWidgets('formats duration correctly with hours', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 26.2,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: const Duration(hours: 3, minutes: 45),
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // 3h 45m renders as separate hour and minute fields.
      expect(find.widgetWithText(TextField, '3'), findsOneWidget); // hours
      expect(find.widgetWithText(TextField, '45'), findsOneWidget); // minutes
    });

    testWidgets('formats duration correctly without hours', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 5.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: const Duration(minutes: 42),
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // 42 minutes renders as hour "0" and minute "42" segment fields.
      expect(_segmentFieldTexts(tester), <String>['0', '42']);
    });

    testWidgets('shows empty duration fields with hints when duration is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 10.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: null,
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // Null duration leaves both hr/mins fields empty, showing their hints.
      expect(find.text('Estimated Duration'), findsOneWidget);
      expect(_segmentHints(tester), containsAll(<String>['0', '00']));
      expect(_segmentFieldTexts(tester), everyElement(isEmpty));
    });

    testWidgets('shows empty pace fields with hints when pace is null',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 10.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byPace,
              estimatedDuration: null,
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // Null pace leaves both min/sec fields empty, showing their hints.
      expect(find.text('Average Pace'), findsOneWidget);
      expect(_segmentHints(tester), containsAll(<String>['0', '00']));
      expect(_segmentFieldTexts(tester), everyElement(isEmpty));
    });

    testWidgets('calls onDistanceChanged when distance is edited', (tester) async {
      double? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 18.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: const Duration(hours: 2, minutes: 38),
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (value) => changedValue = value,
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // Find distance text field and enter new value
      final distanceField = find.widgetWithText(TextField, '18.0');
      expect(distanceField, findsOneWidget);

      await tester.enterText(distanceField, '20.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(changedValue, 20.5);
    });

    testWidgets('calls onModeChanged when toggle is pressed', (tester) async {
      DurationPaceMode? changedMode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 18.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: const Duration(hours: 2, minutes: 38),
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (mode) => changedMode = mode,
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // Tap "By Pace" button
      await tester.tap(find.text('By Pace'));
      await tester.pump();

      expect(changedMode, DurationPaceMode.byPace);
    });

    testWidgets('calls onPaceChanged when pace is edited in By Pace mode', (tester) async {
      double? changedPace;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 13.1,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byPace,
              estimatedDuration: null,
              pace: 8.5,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (pace) => changedPace = pace,
            ),
          ),
        ),
      );

      // Pace is split into separate minute/second fields (8 min 30 sec).
      final minuteField = find.widgetWithText(TextField, '8');
      final secondField = find.widgetWithText(TextField, '30');
      expect(minuteField, findsOneWidget);
      expect(secondField, findsOneWidget);

      // Editing to 9 min 15 sec should report 9.25 minutes.
      await tester.enterText(minuteField, '9');
      await tester.enterText(secondField, '15');
      await tester.pump();

      expect(changedPace, closeTo(9.25, 0.01)); // 9:15 = 9.25 minutes
    });

    testWidgets('pace field accepts decimal format', (tester) async {
      double? changedPace;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.cycling,
              distance: 40.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byPace,
              estimatedDuration: null,
              pace: 18.5,
              paceUnit: 'mph',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (pace) => changedPace = pace,
            ),
          ),
        ),
      );

      // Find speed field and enter new value
      final speedField = find.widgetWithText(TextField, '18.5');
      expect(speedField, findsOneWidget);

      await tester.enterText(speedField, '20.0');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(changedPace, 20.0);
    });

    testWidgets('reverts invalid distance input', (tester) async {
      double? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 18.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: const Duration(hours: 2, minutes: 38),
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (value) => changedValue = value,
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // Find distance text field and enter invalid value. The numeric input
      // formatter strips non-numeric characters, so no garbage value is ever
      // propagated and the field reverts to its original value on submit.
      final distanceField = find.widgetWithText(TextField, '18.0');
      await tester.enterText(distanceField, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // Only the original valid value is ever reported (never a parsed garbage
      // value), and the field shows the original value.
      expect(changedValue, anyOf(isNull, 18.0));
      expect(find.widgetWithText(TextField, '18.0'), findsOneWidget);
    });

    testWidgets('reverts invalid pace input', (tester) async {
      double? changedPace;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 13.1,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byPace,
              estimatedDuration: null,
              pace: 8.5,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (pace) => changedPace = pace,
            ),
          ),
        ),
      );

      // Enter an out-of-range seconds value (>= 60) into the seconds field.
      final secondField = find.widgetWithText(TextField, '30');
      expect(secondField, findsOneWidget);
      await tester.enterText(secondField, '99');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      // The out-of-range "99 seconds" entry is rejected: it never produces a
      // pace that reflects 99 seconds (~9.65 min), and on submit the fields
      // revert to the original 8 min 30 sec.
      expect(changedPace ?? 8.5, lessThan(9.0));
      expect(_segmentFieldTexts(tester), <String>['8', '30']);
    });

    testWidgets('respects enabled parameter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 18.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: const Duration(hours: 2, minutes: 38),
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
              enabled: false,
            ),
          ),
        ),
      );

      // Find text fields
      final distanceField = find.widgetWithText(TextField, '18.0').first;
      final textField = tester.widget<TextField>(distanceField);

      expect(textField.enabled, false);
    });

    testWidgets('secondary field is read-only in By Duration mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 18.0,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: const Duration(hours: 2, minutes: 38),
              pace: null,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // In By Duration mode without an onDurationChanged callback, the
      // hr/mins segment fields are read-only.
      final hourField = find.widgetWithText(TextField, '2');
      final minuteField = find.widgetWithText(TextField, '38');
      expect(hourField, findsOneWidget);
      expect(minuteField, findsOneWidget);
      expect(tester.widget<TextField>(hourField).enabled, false);
      expect(tester.widget<TextField>(minuteField).enabled, false);
    });

    testWidgets('secondary field is editable in By Pace mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 13.1,
              distanceUnit: 'mi',
              mode: DurationPaceMode.byPace,
              estimatedDuration: null,
              pace: 8.5,
              paceUnit: 'min/mi',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      // In By Pace mode the min/sec segment fields are editable.
      final minuteField = find.widgetWithText(TextField, '8');
      final secondField = find.widgetWithText(TextField, '30');
      expect(minuteField, findsOneWidget);
      expect(secondField, findsOneWidget);
      expect(tester.widget<TextField>(minuteField).enabled, true);
      expect(tester.widget<TextField>(secondField).enabled, true);
    });

    testWidgets('uses correct distance unit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkoutDetailsWidget(
              sport: ActivityType.running,
              distance: 10.0,
              distanceUnit: 'km',
              mode: DurationPaceMode.byDuration,
              estimatedDuration: const Duration(minutes: 50),
              pace: null,
              paceUnit: 'min/km',
              onDistanceChanged: (_) {},
              onModeChanged: (_) {},
              onPaceChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('km'), findsOneWidget);
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

/// The segment (hr/mins or min/sec) fields are the ones with a hint set; the
/// distance/speed fields have no hint. Returns their hint strings.
List<String> _segmentHints(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .map((tf) => tf.decoration?.hintText)
      .whereType<String>()
      .toList();
}

/// Returns the current text of the segment (hinted) fields.
List<String> _segmentFieldTexts(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .where((tf) => tf.decoration?.hintText != null)
      .map((tf) => tf.controller?.text ?? '')
      .toList();
}
