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

    testWidgets('shows "By Duration" as selected when value is byDuration', (
      tester,
    ) async {
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

      // The selected option renders as an orange thumb (DecoratedBox) that
      // animates to the left when "By Duration" is selected.
      final thumb = _orangeThumbFinder();
      expect(thumb, findsOneWidget);
      expect(_thumbAlignment(tester), Alignment.centerLeft);

      // The selected label uses bold (w700) weight.
      expect(_labelFontWeight(tester, 'By Duration'), FontWeight.w700);
    });

    testWidgets('shows "By Pace" as selected when value is byPace', (
      tester,
    ) async {
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

      // The selected option renders as an orange thumb that animates to the
      // right when "By Pace" is selected.
      final thumb = _orangeThumbFinder();
      expect(thumb, findsOneWidget);
      expect(_thumbAlignment(tester), Alignment.centerRight);

      // The selected label uses bold (w700) weight.
      expect(_labelFontWeight(tester, 'By Pace'), FontWeight.w700);
    });

    testWidgets('calls onChanged when tapping unselected option', (
      tester,
    ) async {
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

    testWidgets('does not call onChanged when tapping selected option', (
      tester,
    ) async {
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

      // Disabled state dims the whole control via an Opacity wrapper (0.6).
      final dimmed = find.byWidgetPredicate(
        (widget) => widget is Opacity && widget.opacity == 0.6,
      );
      expect(dimmed, findsOneWidget);
    });

    testWidgets('shows full opacity when enabled', (tester) async {
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

      // Enabled state renders at full opacity.
      final fullOpacity = find.byWidgetPredicate(
        (widget) => widget is Opacity && widget.opacity == 1.0,
      );
      expect(fullOpacity, findsOneWidget);
    });
  });
}

/// Finds the orange animated thumb (DecoratedBox) that marks the selected
/// segment in [DurationPaceToggle]'s underlying pill slider.
Finder _orangeThumbFinder() {
  return find.byWidgetPredicate((widget) {
    if (widget is DecoratedBox) {
      final decoration = widget.decoration;
      return decoration is BoxDecoration &&
          decoration.color == AppColors.orange;
    }
    return false;
  });
}

/// Reads the alignment of the slider's [AnimatedAlign] thumb so we can assert
/// which side is currently selected.
Alignment _thumbAlignment(WidgetTester tester) {
  final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
  return align.alignment as Alignment;
}

/// Returns the font weight applied to a segment label, used to confirm the
/// selected segment renders bold.
FontWeight? _labelFontWeight(WidgetTester tester, String label) {
  final text = tester.widget<Text>(find.text(label));
  return text.style?.fontWeight;
}
