import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

void main() {
  group('DurationPaceToggle', () {
    testWidgets('renders both options', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byDuration,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('By Duration'), findsOneWidget);
      expect(find.text('By Pace'), findsOneWidget);
    });

    testWidgets('shows "By Duration" as selected when value is byDuration',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byDuration,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Find the containers with orange background (selected state)
      final selectedButton = find.byWidgetPredicate((widget) {
        if (widget is AnimatedContainer) {
          final decoration = widget.decoration as BoxDecoration?;
          return decoration?.color == AppColors.orange;
        }
        return false;
      });

      expect(selectedButton, findsOneWidget);
    });

    testWidgets('shows "By Pace" as selected when value is byPace',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byPace,
              onChanged: (_) {},
            ),
          ),
        ),
      );

      // Find the containers with orange background (selected state)
      final selectedButton = find.byWidgetPredicate((widget) {
        if (widget is AnimatedContainer) {
          final decoration = widget.decoration as BoxDecoration?;
          return decoration?.color == AppColors.orange;
        }
        return false;
      });

      expect(selectedButton, findsOneWidget);
    });

    testWidgets('calls onChanged when tapping unselected option',
        (tester) async {
      DurationPaceMode? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byDuration,
              onChanged: (value) => changedValue = value,
            ),
          ),
        ),
      );

      // Tap "By Pace" button
      await tester.tap(find.text('By Pace'));
      await tester.pumpAndSettle();

      expect(changedValue, DurationPaceMode.byPace);
    });

    testWidgets('does not call onChanged when tapping selected option',
        (tester) async {
      var callCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byDuration,
              onChanged: (_) => callCount++,
            ),
          ),
        ),
      );

      // Tap "By Duration" button (already selected)
      await tester.tap(find.text('By Duration'));
      await tester.pumpAndSettle();

      // onChanged is called, but with same value
      expect(callCount, 1);
    });

    testWidgets('shows "By Speed" for cycling sport', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byDuration,
              onChanged: (_) {},
              sport: ActivityType.cycling,
            ),
          ),
        ),
      );

      expect(find.text('By Duration'), findsOneWidget);
      expect(find.text('By Speed'), findsOneWidget);
      expect(find.text('By Pace'), findsNothing);
    });

    testWidgets('shows "By Pace" for running sport', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byDuration,
              onChanged: (_) {},
              sport: ActivityType.running,
            ),
          ),
        ),
      );

      expect(find.text('By Duration'), findsOneWidget);
      expect(find.text('By Pace'), findsOneWidget);
      expect(find.text('By Speed'), findsNothing);
    });

    testWidgets('shows "By Pace" for swimming sport', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byDuration,
              onChanged: (_) {},
              sport: ActivityType.swimming,
            ),
          ),
        ),
      );

      expect(find.text('By Duration'), findsOneWidget);
      expect(find.text('By Pace'), findsOneWidget);
      expect(find.text('By Speed'), findsNothing);
    });

    testWidgets('respects enabled state', (tester) async {
      DurationPaceMode? changedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byDuration,
              onChanged: (value) => changedValue = value,
              enabled: false,
            ),
          ),
        ),
      );

      // Try to tap "By Pace" button
      await tester.tap(find.text('By Pace'));
      await tester.pumpAndSettle();

      // onChanged should not be called
      expect(changedValue, isNull);
    });

    testWidgets('shows disabled styling when enabled is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DurationPaceToggle(
              value: DurationPaceMode.byDuration,
              onChanged: (_) {},
              enabled: false,
            ),
          ),
        ),
      );

      // Find the containers with disabled color
      final disabledButtons = find.byWidgetPredicate((widget) {
        if (widget is AnimatedContainer) {
          final decoration = widget.decoration as BoxDecoration?;
          // Disabled buttons should not have orange background
          return decoration?.color != AppColors.orange;
        }
        return false;
      });

      expect(disabledButtons, findsAtLeastNWidgets(2));
    });
  });
}
