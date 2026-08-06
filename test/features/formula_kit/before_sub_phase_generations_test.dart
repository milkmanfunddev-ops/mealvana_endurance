/// Catalog-generation guard for [BeforeSubPhase.fromTimeWindow].
///
/// The `pre_workout_templates.time_window` labels moved with the ratified
/// 120-minute meal boundary (D-017): the dev catalog was bulk-migrated on
/// 2026-08-05 to `2-4 hours` / `30-120 min`, while prod still carries
/// `1.5-3 hours` / `30-90 min`. This app syncs its local table from whichever
/// backend the flavor points at, so the mapper must classify BOTH generations
/// — a single-generation mapping makes the Before tab's Meal/Snack filter
/// chips silently match nothing on the other catalog. That is the client-side
/// twin of the engine failure that flattened every before-phase to 50 g.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/before_sub_phase.dart';

void main() {
  group('BeforeSubPhase.fromTimeWindow', () {
    test('classifies the current generation (dev catalog, post 2026-08-05)', () {
      expect(BeforeSubPhase.fromTimeWindow('2-4 hours'), BeforeSubPhase.meal);
      expect(BeforeSubPhase.fromTimeWindow('30-120 min'), BeforeSubPhase.snack);
      expect(BeforeSubPhase.fromTimeWindow('< 30 min'), BeforeSubPhase.topUp);
    });

    test('still classifies the previous generation (prod catalog)', () {
      expect(BeforeSubPhase.fromTimeWindow('1.5-3 hours'), BeforeSubPhase.meal);
      expect(BeforeSubPhase.fromTimeWindow('30-90 min'), BeforeSubPhase.snack);
    });

    test('unknown windows return null — shown in All, excluded from filters', () {
      expect(BeforeSubPhase.fromTimeWindow('2-4 hrs'), isNull);
      // En-dash, not hyphen: catalogs are hand-migrated, so near-misses are
      // the realistic failure and must not be silently bucketed.
      expect(BeforeSubPhase.fromTimeWindow('30–120 min'), isNull);
      expect(BeforeSubPhase.fromTimeWindow(null), isNull);
      expect(BeforeSubPhase.fromTimeWindow(''), isNull);
    });
  });
}
