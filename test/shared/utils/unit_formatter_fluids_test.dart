/// Fluid formatting and the `useMetric` / `useImperial` dual-flag trap.
///
/// [UnitFormatter.formatFluids] accepts two flags that mean opposite things and
/// resolves them as `useMetric || !useImperial`. Because both default to
/// `false`, that expression is `true` whenever `useImperial` is not explicitly
/// set — so a caller that reaches for the *positively named* flag and passes
/// `useMetric: false` still gets millilitres.
///
/// That is the same failure mode as the brick-fluids bug in bf0b591f, where a
/// table rendered raw millilitres under an "oz" header (a 3.5 h brick read
/// "3105oz"). The number and the unit label have to be decided by the same
/// input, so any API that lets them disagree will eventually be misused.
///
/// The unit label helper [UnitFormatter.fluidUnitLabel] takes only `useMetric`,
/// so these tests also pin label/value agreement across both flag styles.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/utils/unit_formatter.dart';

void main() {
  // 1000 mL is 33.814 fl oz.
  const oneLitreMl = 1000.0;

  group('formatFluids honours whichever flag the caller reached for', () {
    test('useImperial: true yields ounces', () {
      expect(
        UnitFormatter.formatFluids(oneLitreMl, useImperial: true),
        '34 oz',
      );
    });

    test('useImperial: false yields millilitres', () {
      expect(
        UnitFormatter.formatFluids(oneLitreMl, useImperial: false),
        '1000 mL',
      );
    });

    test('useMetric: true yields millilitres', () {
      expect(
        UnitFormatter.formatFluids(oneLitreMl, useMetric: true),
        '1000 mL',
      );
    });

    test('useMetric: false yields ounces', () {
      // The trap: with `useMetric || !useImperial` this returned "1000 mL",
      // because useImperial defaulted to false and negated to true. A caller
      // that only ever passes useMetric could never get imperial output.
      expect(UnitFormatter.formatFluids(oneLitreMl, useMetric: false), '34 oz');
    });

    test('a useMetric-only caller can reach both unit systems', () {
      String render(bool metric) =>
          UnitFormatter.formatFluids(oneLitreMl, useMetric: metric);

      expect(
        render(true),
        isNot(render(false)),
        reason:
            'Flipping useMetric must change the output. If both branches '
            'render the same string, the flag is being ignored.',
      );
    });

    test('defaults to metric when neither flag is supplied', () {
      expect(UnitFormatter.formatFluids(oneLitreMl), '1000 mL');
    });
  });

  group('value and label never disagree', () {
    // The brick bug in prose: label said oz, number was millilitres.
    for (final metric in [true, false]) {
      test('useMetric: $metric — the number matches its own label', () {
        final label = UnitFormatter.fluidUnitLabel(useMetric: metric);
        final rendered = UnitFormatter.formatFluids(
          oneLitreMl,
          useMetric: metric,
        );

        expect(
          rendered.endsWith(label),
          isTrue,
          reason:
              'fluidUnitLabel says "$label" but formatFluids rendered '
              '"$rendered" for the same useMetric: $metric.',
        );
      });
    }

    test('an imperial reading is far smaller than the metric one', () {
      // 3105 mL is 105 oz. Rendering the mL figure under an oz label
      // overstated the target ~30x, which is what made the bug obvious.
      final metric = UnitFormatter.formatFluids(3105, useMetric: true);
      final imperial = UnitFormatter.formatFluids(3105, useMetric: false);

      expect(metric, '3105 mL');
      expect(imperial, '105 oz');
    });
  });

  group('rounding', () {
    test('rounds to whole units rather than truncating', () {
      // 500 mL = 16.907 oz -> 17, not 16.
      expect(UnitFormatter.formatFluids(500, useImperial: true), '17 oz');
    });

    test('handles zero', () {
      expect(UnitFormatter.formatFluids(0, useImperial: true), '0 oz');
      expect(UnitFormatter.formatFluids(0, useMetric: true), '0 mL');
    });
  });
}
