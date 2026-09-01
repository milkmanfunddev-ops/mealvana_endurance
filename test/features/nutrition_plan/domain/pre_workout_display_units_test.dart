// R-01 (fl oz) and M-5 (whole grams) — the BEFORE card's display units.
//
// Contract: docs/ssot/spec/design/components/fuel-stat.md v1 M-5 and the
// R-01 ruling (Xuan 2026-08-26): target `round(ml / 29.5735)`, band ends
// `[floor, ceil]`, carbs to the gram. The worked pairs the handoff names —
// 487.5 ml → 16 oz, 756 ml → 26 oz — are pinned here; the visual pin is the
// `oz_conversion` golden.

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/pre_workout_display_units.dart';

void main() {
  group('R-01 fl oz', () {
    test('487.5 ml → 16 oz target (the 63-kg meal dose)', () {
      expect(flOzTarget(487.5), 16); // 16.48 → 16
      expect(flOzTarget(472.5), 16); // 15.98 → 16 (7.5 ml/kg · 63)
    });

    test('756 ml → 26 oz ceiling (12 ml/kg · 63, ceil)', () {
      expect(flOzCeil(756), 26); // 25.56 → 26
      expect(flOzTarget(756), 26);
    });

    test(
      'band floor rounds DOWN, ceiling rounds UP — the band never narrows',
      () {
        // 315 ml = 5 ml/kg · 63 → 10.65 oz
        expect(flOzFloor(315), 10);
        expect(flOzCeil(315), 11);
        expect(flOzFloor(0), 0);
        expect(flOzCeil(0), 0);
        // An exact ounce stays put at both ends.
        expect(flOzFloor(29.5735 * 12), 12);
        expect(flOzCeil(29.5735 * 12), 12);
      },
    );

    test(
      'the dark top-up at 63 kg: 724.5 ml → 24 oz (not the illustrative 25)',
      () {
        // 472.5 + 4·63 = 724.5 ml → 24.498 → 24. The spec's "25 oz" is the
        // 63-kg mock's illustration; real copy interpolates this value.
        expect(flOzTarget(724.5), 24);
      },
    );

    test('the constant is R-01\'s, verbatim', () {
      expect(kMlPerFlOz, 29.5735);
    });
  });

  group('M-5 whole grams', () {
    test('carbs to the gram on this surface (not 5 g)', () {
      expect(wholeUnits(113.4), 113);
      expect(wholeUnits(56.7), 57);
      expect(wholeUnits(18.9), 19);
      expect(wholeUnits(52.0), 52);
    });
  });
}
