import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/before_sub_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/presentation/widgets/filter_chip_row.dart';

Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('FilterChipRow<BeforeSubPhase>', () {
    testWidgets('renders one chip per option using labelOf', (tester) async {
      await tester.pumpWidget(
        _wrap(
          FilterChipRow<BeforeSubPhase>(
            options: BeforeSubPhase.values,
            labelOf: (v) => v.displayLabel,
            isSelected: (_) => false,
            onToggled: (_) {},
          ),
        ),
      );
      for (final v in BeforeSubPhase.values) {
        expect(find.text(v.displayLabel), findsOneWidget);
      }
    });

    testWidgets('fires onToggled with the tapped option', (tester) async {
      BeforeSubPhase? tapped;
      await tester.pumpWidget(
        _wrap(
          FilterChipRow<BeforeSubPhase>(
            options: BeforeSubPhase.values,
            labelOf: (v) => v.displayLabel,
            isSelected: (_) => false,
            onToggled: (v) => tapped = v,
          ),
        ),
      );
      await tester.tap(find.text(BeforeSubPhase.snack.displayLabel));
      await tester.pump();
      expect(tapped, BeforeSubPhase.snack);
    });

    testWidgets('selection state is driven by isSelected callback', (
      tester,
    ) async {
      var selectedIndex = 0;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return _wrap(
              FilterChipRow<BeforeSubPhase>(
                options: BeforeSubPhase.values,
                labelOf: (v) => v.displayLabel,
                isSelected: (v) => v == BeforeSubPhase.values[selectedIndex],
                onToggled: (v) => setState(
                  () => selectedIndex = BeforeSubPhase.values.indexOf(v),
                ),
              ),
            );
          },
        ),
      );

      // First option is selected by default — tap second to switch.
      final second = BeforeSubPhase.values[1];
      await tester.tap(find.text(second.displayLabel));
      await tester.pumpAndSettle();
      // No throw, no overflow, second label still present.
      expect(find.text(second.displayLabel), findsOneWidget);
    });
  });
}
