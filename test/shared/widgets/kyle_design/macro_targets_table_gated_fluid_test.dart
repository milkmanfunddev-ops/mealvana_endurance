// N1 (test plan pre-workout-before-card §2 "bugs absorbed"): "Adjust Your
// Macros" → Your Nutritional Targets must render the hydration-v6 GATE as an
// em dash on PRE · FLUIDS — never "0oz" — the way PRE · SODIUM already does.
// fuel-stat F-1 / hydration inv. 11: null ≠ 0.
//
// Ops bug: 2026-08-26-adjust-macros-renders-gated-fluid-as-0oz.md.
// Mutation check: put `?? 0` back on `preFluids` in adjust_macros_screen.dart
// or `'${macroData.preFluids}$fluidUnit'` back in the table → 'gated' fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/cards/macro_targets_table.dart';

MacroTableData _data({int? preFluids}) => MacroTableData(
  preCarbs: 60,
  duringCarbs: 90,
  postCarbs: 60,
  preProtein: 10,
  duringProtein: 0,
  postProtein: 20,
  preFluids: preFluids,
  duringFluids: 25,
  postFluids: 17,
  preSodium: null,
  duringSodium: 450,
  postSodium: 300,
);

Future<void> _pump(WidgetTester tester, MacroTableData data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: MacroTargetsTable(
            title: 'Your Nutritional Targets',
            useMetric: false,
            macroData: data,
          ),
        ),
      ),
    ),
  );
}

String _cell(WidgetTester tester, Key row, int index) {
  final texts = find.descendant(
    of: find.byKey(row),
    matching: find.byType(Text),
  );
  return tester.widget<Text>(texts.at(index)).data!;
}

void main() {
  const fluidsRow = ValueKey('adjust_macros.row_fluids');
  const sodiumRow = ValueKey('adjust_macros.row_sodium');

  testWidgets('gated plan: PRE · FLUIDS renders "—", never 0oz', (
    tester,
  ) async {
    await _pump(tester, _data(preFluids: null));
    expect(_cell(tester, fluidsRow, 1), '—');
    expect(find.text('0oz'), findsNothing);
    // DURING / POST untouched.
    expect(_cell(tester, fluidsRow, 2), '25oz');
    expect(_cell(tester, fluidsRow, 3), '17oz');
    // Same treatment sodium already had.
    expect(_cell(tester, sodiumRow, 1), '—');
  });

  testWidgets('ungated plan: PRE · FLUIDS renders the target', (tester) async {
    await _pump(tester, _data(preFluids: 16));
    expect(_cell(tester, fluidsRow, 1), '16oz');
  });

  testWidgets('a real 0 ml target still renders 0oz (0 ≠ null)', (
    tester,
  ) async {
    await _pump(tester, _data(preFluids: 0));
    expect(_cell(tester, fluidsRow, 1), '0oz');
  });
}
