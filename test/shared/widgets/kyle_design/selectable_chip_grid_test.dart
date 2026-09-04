// selectable-chip-grid.md v1 (PROPOSED) — the L2 widget vectors:
//   SCG-1   tapping toggles; onChanged carries the whole set
//   SCG-2   `+` opens the entry; non-empty submit calls onAddCustom and
//           closes it; empty submit just closes
//   SCG-3   disabled ignores taps and hides `+`
//   SCG-L1  a long label inside a 320pt host builds without overflow
//   both themes build without exception

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/selectable_chip_grid.dart';

Future<void> _pump(
  WidgetTester tester, {
  required List<String> items,
  required Set<String> selected,
  ValueChanged<Set<String>>? onChanged,
  ValueChanged<String>? onAddCustom,
  bool allowCustom = true,
  bool enabled = true,
  Brightness brightness = Brightness.light,
  double width = 320,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: SelectableChipGrid(
              items: items,
              selected: selected,
              onChanged: onChanged ?? (_) {},
              allowCustom: allowCustom,
              onAddCustom: onAddCustom,
              enabled: enabled,
              customHint: 'Something else…',
            ),
          ),
        ),
      ),
    ),
  );
}

Finder _chip(String label) => find.byKey(ValueKey('selectable_chip_$label'));
final _add = find.byKey(const ValueKey('selectable_chip_add'));
final _entry = find.byKey(const ValueKey('selectable_chip_entry'));
final _submit = find.byKey(const ValueKey('selectable_chip_submit'));

void main() {
  testWidgets('SCG-1: tapping a chip reports the whole toggled set', (
    tester,
  ) async {
    Set<String>? reported;
    await _pump(
      tester,
      items: const ['eggs', 'rice', 'spinach'],
      selected: const {'eggs'},
      onChanged: (s) => reported = s,
      onAddCustom: (_) {},
    );

    await tester.tap(_chip('rice'));
    expect(reported, {'eggs', 'rice'});

    await tester.tap(_chip('eggs'));
    expect(reported, isEmpty, reason: 'toggle off leaves nothing selected');
  });

  testWidgets('SCG-1: a selected chip carries the check glyph', (
    tester,
  ) async {
    await _pump(
      tester,
      items: const ['eggs', 'rice'],
      selected: const {'eggs'},
      onAddCustom: (_) {},
    );
    expect(
      find.descendant(of: _chip('eggs'), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _chip('rice'), matching: find.byIcon(Icons.check)),
      findsNothing,
    );
  });

  testWidgets('SCG-2: + opens the entry; non-empty submit reports and closes', (
    tester,
  ) async {
    String? added;
    await _pump(
      tester,
      items: const ['eggs'],
      selected: const {},
      onAddCustom: (t) => added = t,
    );

    expect(_add, findsOneWidget);
    expect(_entry, findsNothing);

    await tester.tap(_add);
    await tester.pump();
    expect(_entry, findsOneWidget);
    expect(_add, findsNothing, reason: 'the entry takes the + chip\'s place');

    await tester.enterText(_entry, '  tofu ');
    await tester.tap(_submit);
    await tester.pump();

    expect(added, 'tofu', reason: 'trimmed');
    expect(_entry, findsNothing);
    expect(_add, findsOneWidget);
  });

  testWidgets('SCG-2: empty submit closes without reporting', (tester) async {
    var calls = 0;
    await _pump(
      tester,
      items: const ['eggs'],
      selected: const {},
      onAddCustom: (_) => calls++,
    );
    await tester.tap(_add);
    await tester.pump();
    await tester.tap(_submit);
    await tester.pump();
    expect(calls, 0);
    expect(_entry, findsNothing);
  });

  testWidgets('SCG-2: no + without allowCustom or without onAddCustom', (
    tester,
  ) async {
    await _pump(
      tester,
      items: const ['eggs'],
      selected: const {},
      allowCustom: false,
      onAddCustom: (_) {},
    );
    expect(_add, findsNothing);

    await _pump(tester, items: const ['eggs'], selected: const {});
    expect(_add, findsNothing);
  });

  testWidgets('SCG-3: disabled ignores taps, hides +, keeps the check', (
    tester,
  ) async {
    var changes = 0;
    await _pump(
      tester,
      items: const ['eggs', 'rice'],
      selected: const {'eggs'},
      enabled: false,
      onChanged: (_) => changes++,
      onAddCustom: (_) {},
    );
    await tester.tap(_chip('rice'), warnIfMissed: false);
    expect(changes, 0);
    expect(_add, findsNothing);
    expect(
      find.descendant(of: _chip('eggs'), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
  });

  testWidgets('SCG-L1: a long label in a 320pt host does not overflow', (
    tester,
  ) async {
    await _pump(
      tester,
      items: const [
        'a very long pantry item name that would otherwise run past the edge',
        'rice',
      ],
      selected: const {},
      onAddCustom: (_) {},
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('both themes build', (tester) async {
    for (final brightness in Brightness.values) {
      await _pump(
        tester,
        items: const ['eggs', 'rice'],
        selected: const {'rice'},
        onAddCustom: (_) {},
        brightness: brightness,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
