/// Fluid formatting: the number and its unit label must always agree.
///
/// History, because the shape of this API changed twice for the same reason.
/// [UnitFormatter.formatFluids] originally took BOTH `useImperial` and
/// `useMetric`, each defaulting to `false`, and resolved
/// `useMetric || !useImperial`. That expression is `true` whenever
/// `useImperial` is omitted, so the natural-looking
/// `formatFluids(ml, useMetric: false)` returned **millilitres** — the exact
/// opposite of what the caller asked for — and a caller reaching only for the
/// positively-named flag could never get imperial output at all.
///
/// The signature is now a single `required bool useMetric`, which is the
/// stronger fix: there is no second flag to disagree with, and no default to
/// fall through to. These tests keep the behavioural guarantee that motivated
/// the change — flipping the flag flips the output, and the rendered number
/// always matches the unit it is labelled with.
///
/// That pairing is the thing that actually bites. The brick bug in bf0b591f
/// rendered raw millilitres under an "oz" header, so a 3.5 h brick read
/// "3105oz": the value and the label were decided by different inputs.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/utils/unit_formatter.dart';

void main() {
  // 1000 mL is 33.814 fl oz.
  const oneLitreMl = 1000.0;

  group('formatFluids honours the flag it is given', () {
    test('useMetric: true yields millilitres', () {
      expect(
        UnitFormatter.formatFluids(oneLitreMl, useMetric: true),
        '1000 mL',
      );
    });

    test('useMetric: false yields ounces', () {
      // The regression that motivated both rewrites: this used to return
      // "1000 mL" because the two flags resolved against each other.
      expect(UnitFormatter.formatFluids(oneLitreMl, useMetric: false), '34 oz');
    });

    test('flipping the flag changes the output', () {
      String render(bool metric) =>
          UnitFormatter.formatFluids(oneLitreMl, useMetric: metric);

      expect(
        render(true),
        isNot(render(false)),
        reason:
            'If both branches render the same string, the flag is being '
            'ignored and one unit system is unreachable.',
      );
    });
  });

  group('value and label never disagree', () {
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
      // overstated the target ~30x, which is what made the brick bug visible.
      expect(UnitFormatter.formatFluids(3105, useMetric: true), '3105 mL');
      expect(UnitFormatter.formatFluids(3105, useMetric: false), '105 oz');
    });

    test('the imperial figure is always the smaller number', () {
      for (final ml in [50.0, 250.0, 591.0, 1500.0, 3105.0]) {
        final metric = int.parse(
          UnitFormatter.formatFluids(ml, useMetric: true).split(' ').first,
        );
        final imperial = int.parse(
          UnitFormatter.formatFluids(ml, useMetric: false).split(' ').first,
        );
        expect(
          imperial,
          lessThan(metric),
          reason:
              '$ml mL rendered as $imperial oz, which is not smaller than '
              '$metric mL — the conversion ran the wrong way.',
        );
      }
    });
  });

  group('rounding', () {
    test('rounds to whole units rather than truncating', () {
      // 500 mL = 16.907 oz -> 17, not 16.
      expect(UnitFormatter.formatFluids(500, useMetric: false), '17 oz');
    });

    test('handles zero in both systems', () {
      expect(UnitFormatter.formatFluids(0, useMetric: false), '0 oz');
      expect(UnitFormatter.formatFluids(0, useMetric: true), '0 mL');
    });
  });
}
