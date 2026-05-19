import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/before_sub_phase.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/during_filter_options.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_filter_state.dart';
import 'package:mealvana_endurance/features/formula_kit/domain/formula_phase.dart';

void main() {
  group('FormulaFilterState', () {
    test('defaults are sensible — Before phase, no filters active', () {
      const state = FormulaFilterState();
      expect(state.phase, FormulaPhase.before);
      expect(state.beforeSubPhase, isNull);
      expect(state.beforeDigestionSpeed, isNull);
      expect(state.duringActivity, isNull);
      expect(state.duringDuration, isNull);
      expect(state.duringGutLevel, isNull);
      expect(state.ignoreDietaryProfile, isFalse);
      expect(state.activeChipFilterCount, 0);
      expect(state.activeMoreFilterCount, 0);
    });

    test('activeChipFilterCount counts only the chips for the active phase',
        () {
      const before = FormulaFilterState(
        phase: FormulaPhase.before,
        beforeSubPhase: BeforeSubPhase.snack,
      );
      expect(before.activeChipFilterCount, 1);

      const during = FormulaFilterState(
        phase: FormulaPhase.during,
        duringActivity: DuringActivity.cycling,
        duringDuration: DuringDuration.ninetyTo150,
      );
      expect(during.activeChipFilterCount, 2);
    });

    test('activeMoreFilterCount counts sheet-level filters per phase', () {
      const before = FormulaFilterState(
        phase: FormulaPhase.before,
        beforeDigestionSpeed: FormulaDigestionSpeed.fast,
        ignoreDietaryProfile: true,
      );
      expect(before.activeMoreFilterCount, 2);

      const during = FormulaFilterState(
        phase: FormulaPhase.during,
        duringGutLevel: DuringGutLevel.high,
      );
      expect(during.activeMoreFilterCount, 1);
    });

    test('copyWith with no args returns an equal-but-not-same instance', () {
      const original = FormulaFilterState(
        phase: FormulaPhase.during,
        duringActivity: DuringActivity.running,
      );
      final copy = original.copyWith();
      expect(copy, equals(original));
      expect(identical(copy, original), isFalse);
    });

    test('copyWith with a sentinel function can clear a nullable field', () {
      const original = FormulaFilterState(
        phase: FormulaPhase.before,
        beforeSubPhase: BeforeSubPhase.meal,
      );
      final cleared = original.copyWith(beforeSubPhase: () => null);
      expect(cleared.beforeSubPhase, isNull);
    });

    test('omitting a sentinel function preserves the existing nullable value',
        () {
      const original = FormulaFilterState(
        phase: FormulaPhase.before,
        beforeSubPhase: BeforeSubPhase.topUp,
      );
      final preserved =
          original.copyWith(ignoreDietaryProfile: true); // no subPhase sentinel
      expect(preserved.beforeSubPhase, BeforeSubPhase.topUp);
      expect(preserved.ignoreDietaryProfile, isTrue);
    });

    test('equality is value-based across all fields', () {
      const a = FormulaFilterState(
        phase: FormulaPhase.during,
        duringActivity: DuringActivity.cycling,
        duringDuration: DuringDuration.over240,
        duringGutLevel: DuringGutLevel.high,
        ignoreDietaryProfile: true,
      );
      const b = FormulaFilterState(
        phase: FormulaPhase.during,
        duringActivity: DuringActivity.cycling,
        duringDuration: DuringDuration.over240,
        duringGutLevel: DuringGutLevel.high,
        ignoreDietaryProfile: true,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('BeforeSubPhase storage mapping', () {
    test('storage values are stable analytics buckets', () {
      // No longer a column value in pre_workout_templates — keep these strings
      // stable so existing Mixpanel funnels don't break.
      expect(BeforeSubPhase.meal.storageValue, 'full_meal');
      expect(BeforeSubPhase.snack.storageValue, 'snack');
      expect(BeforeSubPhase.topUp.storageValue, 'top_up');
    });

    test('fromStorageValue is the inverse of storageValue', () {
      for (final sp in BeforeSubPhase.values) {
        expect(BeforeSubPhase.fromStorageValue(sp.storageValue), sp);
      }
      expect(BeforeSubPhase.fromStorageValue('unknown'), isNull);
      expect(BeforeSubPhase.fromStorageValue(null), isNull);
    });

    test('fromTimeWindow maps live pre_workout_templates time_window values',
        () {
      expect(
        BeforeSubPhase.fromTimeWindow('1.5-3 hours'),
        BeforeSubPhase.meal,
      );
      expect(BeforeSubPhase.fromTimeWindow('30-90 min'), BeforeSubPhase.snack);
      expect(BeforeSubPhase.fromTimeWindow('< 30 min'), BeforeSubPhase.topUp);
      expect(BeforeSubPhase.fromTimeWindow('whatever'), isNull);
      expect(BeforeSubPhase.fromTimeWindow(null), isNull);
    });
  });

  group('DuringDuration storage mapping', () {
    test('storage values match Postgres seed strings', () {
      expect(DuringDuration.underNinety.storageValue, '< 90 min');
      expect(DuringDuration.ninetyTo150.storageValue, '90-150 min');
      expect(DuringDuration.oneFiftyTo240.storageValue, '150-240 min');
      expect(DuringDuration.over240.storageValue, '> 240 min');
    });
  });

  group('DuringActivity storage mapping', () {
    test('storage values use snake_case for triathlon variants', () {
      expect(DuringActivity.running.storageValue, 'running');
      expect(DuringActivity.cycling.storageValue, 'cycling');
      expect(DuringActivity.triathlonBike.storageValue, 'triathlon_bike');
      expect(DuringActivity.triathlonRun.storageValue, 'triathlon_run');
      expect(
        DuringActivity.triathlonTransition.storageValue,
        'triathlon_transition',
      );
    });
  });
}
