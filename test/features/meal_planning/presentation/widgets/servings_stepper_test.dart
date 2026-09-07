import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/stepper.dart';

/// The compact − value + stepper every dense row uses (plan tiles, plan bar,
/// tile/review sheets): reports steps, clamps at its bounds, and goes fully
/// inert when disabled.
void main() {
  Finder glyph(FaIconData icon) => find.byWidgetPredicate(
    (w) => w is FaIcon && w.icon?.codePoint == icon.codePoint,
  );

  IconButton buttonOf(WidgetTester tester, FaIconData icon) =>
      tester.widget<IconButton>(
        find.ancestor(of: glyph(icon), matching: find.byType(IconButton)),
      );

  Future<void> pump(
    WidgetTester tester, {
    required int value,
    ValueChanged<int>? onChanged,
    int min = 1,
    int max = 12,
    bool enabled = true,
  }) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: ServingsStepper(
            value: value,
            onChanged: onChanged ?? (_) {},
            min: min,
            max: max,
            enabled: enabled,
          ),
        ),
      ),
    ),
  );

  testWidgets('shows the value and steps in both directions', (tester) async {
    final seen = <int>[];
    await pump(tester, value: 4, onChanged: seen.add);

    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('meal_planning.stepper_value')),
          )
          .data,
      '4',
    );

    await tester.tap(glyph(FontAwesomeIcons.plus));
    await tester.tap(glyph(FontAwesomeIcons.minus));
    expect(seen, [5, 3]);
  });

  testWidgets('clamps at min: − is disabled and reports nothing', (
    tester,
  ) async {
    final seen = <int>[];
    await pump(tester, value: 1, onChanged: seen.add);

    expect(buttonOf(tester, FontAwesomeIcons.minus).onPressed, isNull);
    expect(buttonOf(tester, FontAwesomeIcons.plus).onPressed, isNotNull);

    await tester.tap(glyph(FontAwesomeIcons.minus), warnIfMissed: false);
    expect(seen, isEmpty);
  });

  testWidgets('clamps at max: + is disabled and reports nothing', (
    tester,
  ) async {
    final seen = <int>[];
    await pump(tester, value: 12, onChanged: seen.add);

    expect(buttonOf(tester, FontAwesomeIcons.plus).onPressed, isNull);
    expect(buttonOf(tester, FontAwesomeIcons.minus).onPressed, isNotNull);

    await tester.tap(glyph(FontAwesomeIcons.plus), warnIfMissed: false);
    expect(seen, isEmpty);
  });

  testWidgets('enabled: false makes both ends inert regardless of value', (
    tester,
  ) async {
    final seen = <int>[];
    await pump(tester, value: 4, onChanged: seen.add, enabled: false);

    expect(buttonOf(tester, FontAwesomeIcons.minus).onPressed, isNull);
    expect(buttonOf(tester, FontAwesomeIcons.plus).onPressed, isNull);
    expect(seen, isEmpty);
  });
}
