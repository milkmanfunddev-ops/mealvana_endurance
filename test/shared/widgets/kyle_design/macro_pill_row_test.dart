// macro-pill-row.md v1 (PROPOSED) — the L2 widget vectors:
//   MP-1  all four pills, exact short-form strings, fixed order
//   MP-2  a null macro drops its pill (never "0"); a real 0 renders "0g"
//   MP-3  kcal and carbs both null → nothing (no pill, no size)
//   both themes build without exception
//
// Mutation check: make a null protein render `0g P`, or make the empty case
// paint a padded box → the matching test fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/macro_pill_row.dart';

Future<void> _pump(
  WidgetTester tester,
  MacroPillRow row, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: SizedBox(width: 240, child: Center(child: row)),
      ),
    ),
  );
}

List<String> _pillTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(MacroPillRow), matching: find.byType(Text)),
    )
    .map((t) => t.data!)
    .toList();

void main() {
  testWidgets('MP-1: renders all four pills in the short form, in order', (
    tester,
  ) async {
    await _pump(
      tester,
      const MacroPillRow(kcal: 412, carbsG: 58.4, proteinG: 30.6, fatG: 12),
    );
    expect(_pillTexts(tester), ['412 kcal', '58g C', '31g P', '12g F']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MP-2: a null macro drops its pill, never renders 0', (
    tester,
  ) async {
    await _pump(tester, const MacroPillRow(kcal: 412, carbsG: 58, fatG: 12));
    expect(_pillTexts(tester), ['412 kcal', '58g C', '12g F']);
    expect(find.textContaining('P'), findsNothing);
  });

  testWidgets('MP-2: a real 0 renders "0g" (null ≠ 0)', (tester) async {
    await _pump(tester, const MacroPillRow(kcal: 90, carbsG: 0, proteinG: 4));
    expect(_pillTexts(tester), ['90 kcal', '0g C', '4g P']);
  });

  testWidgets('MP-3: kcal and carbs both null → nothing, zero size', (
    tester,
  ) async {
    await _pump(tester, const MacroPillRow(kcal: null, proteinG: 30, fatG: 12));
    expect(find.byType(Text), findsNothing);
    expect(tester.getSize(find.byType(MacroPillRow)), Size.zero);
    expect(const MacroPillRow(kcal: null).isEmpty, isTrue);
  });

  testWidgets('kcal alone still renders (MP-3 is an AND)', (tester) async {
    await _pump(tester, const MacroPillRow(kcal: 412));
    expect(_pillTexts(tester), ['412 kcal']);
  });

  for (final brightness in Brightness.values) {
    testWidgets('builds in ${brightness.name} theme, regular and compact', (
      tester,
    ) async {
      await _pump(
        tester,
        const MacroPillRow(kcal: 412, carbsG: 58, proteinG: 31, fatG: 12),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsNWidgets(4));

      await _pump(
        tester,
        const MacroPillRow(
          kcal: 412,
          carbsG: 58,
          proteinG: 31,
          fatG: 12,
          compact: true,
        ),
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(Text), findsNWidgets(4));
    });
  }
}
